extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const GuidedCombatScenario = preload("res://scripts/guided_combat_scenario.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const SectionMapGraph = preload("res://scripts/section_map_graph.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const PATH_FIXTURE_SEED: int = 22017
const PATH_SMALL_VIEWPORT: Vector2i = Vector2i(1280, 800)
const PATH_SMALL_UI_SCALE: float = 1.15
const PATH_PAN_PIXELS: float = 40.0
const PATH_TRAVEL_TIMEOUT_MSEC: int = 15000
const PATH_SETTINGS_PATH: String = "user://ui-25-settings.json"
const PATH_OUTPUT_ROOT: String = "user://probes/ui-25"

const OUTPUT_DIR: String = "user://probes/contextual_combat_tutorial_v4"
const STORAGE_PATH: String = "user://contextual_combat_tutorial_probe_progression.json"
const RUN_STORAGE_PATH: String = "user://contextual_combat_tutorial_probe_run.save"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)
const INVALID_TILE: Vector2i = Vector2i(-999, -999)

var _failed: bool = false
var _path_viewport: Vector2i = PROBE_VIEWPORT
var _path_output: String = ""
var _path_captures: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if OS.get_cmdline_user_args().has("--path-only"):
		_capture_path_lesson.call_deferred()
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	var active_progression: Dictionary = ProgressionStore.default_data()
	active_progression[ContextualCombatTutorial.PROGRESSION_KEY] = ContextualCombatTutorial.default_state()
	_assert(ProgressionStore.save_data(active_progression), "Probe should persist an explicit first-run tutorial profile")
	await _capture_authored_guided_run(active_progression)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("GUIDED COMBAT TUTORIAL PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_path_lesson() -> void:
	var logic_only: bool = OS.get_cmdline_user_args().has("--logic-only")
	if not logic_only and DisplayServer.get_name() == "headless":
		_fail("Path captures require the windowed visual probe runner; use --logic-only for headless checks")
		quit(1)
		return
	var small: bool = OS.get_cmdline_user_args().has("--small")
	_path_viewport = PATH_SMALL_VIEWPORT if small else PROBE_VIEWPORT
	var ui_scale: float = PATH_SMALL_UI_SCALE if small else 1.0
	var build: String = "demo" if DemoBuild.is_demo() else "full"
	_path_output = PATH_OUTPUT_ROOT.path_join("%s-%dx%d" % [build, _path_viewport.x, _path_viewport.y])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_path_output))
	SettingsStore.set_storage_path(PATH_SETTINGS_PATH)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["display_mode"] = "windowed"
	_assert(SettingsStore.save_settings(settings), "Path proof settings should save")
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	_remove_if_present(STORAGE_PATH)
	_remove_if_present(RUN_STORAGE_PATH)
	var progression: Dictionary = ProgressionStore.default_data()
	_assert(ProgressionStore.save_data(progression), "Path proof should start with a fresh profile")
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await _settle_ui()
	if not logic_only:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(_path_viewport)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = _path_viewport
	root.size = _path_viewport
	root.content_scale_factor = ui_scale
	# Advance only the invisible fixture: the scene renders the real generated
	# first combat room after its reward, with the path milestone still pending.
	for milestone: String in ContextualCombatTutorial.milestone_ids():
		if milestone != ContextualCombatTutorial.MILESTONE_PATH:
			progression = ContextualCombatTutorial.complete_milestone(progression, milestone)
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(PATH_FIXTURE_SEED, progression)
	state = engine.move_to_room(state, engine.available_moves(state)[0])
	state["mode"] = "room"
	state["combat_state"] = {}
	state["progression"] = progression
	SectionMapGraph.room(state, state["current_room"])["cleared"] = true
	scene.call("_load_run_state", state)
	scene.call("_close_dialogue")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")
	await _settle_ui()
	var panel: Control = scene.get("_large_map_view")
	var prompt: Control = scene.get("_contextual_combat_prompt")
	var scrim: Control = scene.get("_large_map_scrim")
	print("UI-25 PATH STATE: phase=%s mode=%s suppressed=%s map=%s exits=%s rooms=%s" % [scene.get("_guided_tutorial_phase_id"), scene.get("_run_state")["mode"], scene.call("_contextual_combat_tutorial_suppressed"), scrim.visible, scene.get("_exit_destinations_by_tile"), panel.call("selectable_room_global_rects", scene.call("_guided_tutorial_path_destinations"))])
	_assert(scrim.visible, "The last guided lesson should automatically open over the generated post-combat room")
	_assert_path_geometry(scene, true)
	await _capture_path_state(scene, "01_map_pointer", logic_only)
	var before_scroll: Array = (prompt.get_meta("spotlight_rects", []) as Array).duplicate()
	panel.call("scroll_to", PATH_PAN_PIXELS)
	await _settle_short()
	_assert_path_geometry(scene, true)
	_assert(before_scroll != prompt.get_meta("spotlight_rects", []), "Borders should move with the scrolling map")
	await _capture_path_state(scene, "02_map_scrolled", logic_only)
	panel.call("center_on_current", true)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	scene.call("_guided_tutorial_prepare_controller_focus")
	await _settle_ui()
	_assert_path_geometry(scene, true)
	var focused: Control = root.gui_get_focus_owner()
	var focused_room: Vector2i = SectionMapGraph.INVALID
	for coord: Vector2i in panel.get("node_buttons"):
		if panel.get("node_buttons")[coord] == focused: focused_room = coord
	_assert((scene.call("_guided_tutorial_path_destinations") as Array).has(focused_room), "Controller focus should land on a highlighted destination when the lesson starts")
	_assert(bool(prompt.get_meta("controller_active", false)), "Controller capture should use the active controller copy")
	await _capture_path_state(scene, "03_map_controller", logic_only)
	scene.call("_close_large_map")
	_assert_path_geometry(scene, false)
	await _settle_short()
	await _capture_path_state(scene, "04_doors_controller", logic_only)
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_XBOX)
	await _settle_short()
	_assert_path_geometry(scene, false)
	await _capture_path_state(scene, "05_doors_pointer", logic_only)
	# M is the existing pointer/keyboard map path. Test synchronous copy/target
	# switching before a frame can hide a stale doorway border.
	var map_key := InputEventKey.new()
	map_key.keycode = KEY_M
	map_key.pressed = true
	scene.call("_input", map_key)
	_assert(scrim.visible, "M should reopen the map during the last guided lesson")
	_assert_path_geometry(scene, true)
	await _settle_ui()
	await _capture_path_state(scene, "06_map_reopened", logic_only)
	var before: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	await scene.call("_on_large_map_room_selected", state["current_room"])
	_assert(scrim.visible and scene.get("_run_state") == before, "An unhighlighted room must not travel or close the map")
	# Exercise native pointer/controller room activation and the ordinary travel
	# transaction, including the existing path milestone and analytics boundary.
	var destination: Vector2i = (scene.call("_guided_tutorial_path_destinations") as Array)[0]
	if small:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
		scene.call("_guided_tutorial_prepare_controller_focus")
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = true
		root.push_input(accept, true)
		await process_frame
		accept = accept.duplicate()
		accept.pressed = false
		root.push_input(accept, true)
	else:
		await _click_control(panel.get("node_buttons")[destination])
	var deadline: int = Time.get_ticks_msec() + PATH_TRAVEL_TIMEOUT_MSEC
	while Time.get_ticks_msec() < deadline and not ContextualCombatTutorial.has_completed(scene.get("_progression"), ContextualCombatTutorial.MILESTONE_PATH):
		await process_frame
	_assert(ContextualCombatTutorial.has_completed(scene.get("_progression"), ContextualCombatTutorial.MILESTONE_PATH), "Native room activation should commit the existing path milestone")
	_assert(scene.get("_run_state")["current_room"] == destination, "Travel should enter exactly the highlighted destination")
	var semantics := FileAccess.open(_path_output.path_join("semantic-proof.json"), FileAccess.WRITE)
	semantics.store_string(JSON.stringify({"build": build, "viewport": str(_path_viewport), "ui_scale": ui_scale, "cel_look": OS.get_environment("LABYRINTH_CEL_LOOK"), "captures": _path_captures, "passed": not _failed, "logic_only": logic_only}, "\t"))
	semantics.close()
	print(ProjectSettings.globalize_path(_path_output))
	print("UI-25 PATH PROBE: %s (%s, %dx%d, %d%%; %s)" % ["FAIL" if _failed else "PASS", build, _path_viewport.x, _path_viewport.y, roundi(ui_scale * 100), "logic only; no captures" if logic_only else "native captures"])
	router.call("clear_forced_state_for_test")
	scene.queue_free()
	await _settle_short()
	quit(1 if _failed else 0)

func _assert_path_geometry(scene: Node, map_open: bool) -> void:
	var prompt: Control = scene.get("_contextual_combat_prompt")
	_assert(scene.get("_contextual_combat_prompt_host").visible, "Path lesson should remain visible on the active travel surface")
	var expected: Array = []
	if map_open:
		var native_rects: Dictionary = scene.get("_large_map_view").call("selectable_room_global_rects", scene.call("_guided_tutorial_path_destinations"))
		for rect: Rect2 in native_rects.values(): expected.append(rect.grow(8.0))
		_assert((scene.call("_guided_tutorial_allowed_board_tiles") as Array).is_empty(), "Hidden board doors must be gated while the map is open")
	else:
		for tile: Vector2i in scene.get("_exit_destinations_by_tile"):
			expected.append(scene.call("_guided_tutorial_tile_global_rect", tile))
	_assert(not expected.is_empty() and prompt.get_meta("spotlight_rects", []) == expected, "Spotlights should match exactly the active travel surface")
	_assert(prompt.get_meta("prompt_text", "") == ("Select a glowing room on the map to travel there." if map_open else "Select a glowing doorway. The map previews where each route leads."), "Path copy should match the active surface immediately")

func _capture_path_state(scene: Node, label: String, logic_only: bool) -> void:
	var prompt: Control = scene.get("_contextual_combat_prompt")
	var callout: Rect2 = prompt.get_meta("callout_rect", Rect2())
	var viewport_rect: Rect2 = scene.get_viewport_rect()
	_assert(callout.has_area() and viewport_rect.encloses(callout), "Path callout should fit the live viewport: %s in %s" % [callout, viewport_rect])
	for rect: Rect2 in prompt.get_meta("spotlight_rects", []):
		_assert(viewport_rect.intersects(rect), "Each highlighted room or door should intersect the viewport")
		_assert(not callout.intersects(rect.grow(4.0)), "Path callout must not cover the highlighted travel action")
	_path_captures.append({"state": label, "map_open": scene.get("_large_map_scrim").visible, "copy": prompt.get_meta("prompt_text", ""), "rects": str(prompt.get_meta("spotlight_rects", [])), "controller": prompt.get_meta("controller_active", false), "callout": str(callout)})
	if logic_only: return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	_assert(image != null and image.get_size() == _path_viewport, "Path proof must capture the requested native viewport size")
	if image == null or image.get_size() != _path_viewport: return
	_assert(image.save_png(_path_output.path_join(label + ".png")) == OK, "Path capture should save")

func _capture_authored_guided_run(active_progression: Dictionary) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for authored tutorial visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_authored_combat_fixture(instance, 11601, active_progression)
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	var board: Control = instance.get("board_view") as Control
	var combat = instance.get("_combat_engine")

	# Camp contains ordinary run controls only; tutorial management stays in the
	# contextual callout where it is relevant.
	instance.call("_open_menu_overlay")
	await _settle_ui()
	var menu_texts: Array[String] = _button_texts(instance.get("_menu_dialog") as Node)
	for button_text: String in menu_texts:
		_assert(not button_text.to_lower().contains("tutorial") and not button_text.to_lower().contains("guided"), "Camp should not expose persistent tutorial-management buttons: %s" % button_text)
	await _save_root_screenshot("%s/00_camp_without_tutorial_buttons.png" % OUTPUT_DIR)
	instance.call("_close_menu_overlay")
	await _settle_ui()

	# Lesson 1: every instruction exposes exactly one conspicuous click target.
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_PLAYER, true, "select the glowing Wanderer")
	_assert(bool(prompt.get_meta("attention_pulse", false)), "The player tile should opt into the authored attention pulse")
	_assert(int(prompt.get_meta("spotlight_glow_count", -1)) == 0, "Tutorial emphasis should never tint the target with a filled gold wash")
	_assert(int(prompt.get_meta("spotlight_pulse_border_count", 0)) == 1, "The player tile should render one tight pulsing border")
	await _save_root_screenshot("%s/01_select_player_pulse.png" % OUTPUT_DIR)
	var player_tile: Vector2i = _player_tile(instance)
	await instance.call("_on_board_tile_clicked", player_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_MOVE, true, "take the exact authored step")
	var move_tile: Vector2i = GuidedCombatScenario.move_tile(instance.get("_combat_state") as Dictionary)
	_assert((instance.call("_guided_tutorial_allowed_board_tiles") as Array) == [move_tile], "Movement rail should allow exactly the authored destination")
	await _save_root_screenshot("%s/02_exact_move_pulse.png" % OUTPUT_DIR)

	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert(bool(prompt.get_meta("reduced_motion", false)), "Reduced Motion should switch the required tile to static emphasis")
	_assert(int(prompt.get_meta("spotlight_glow_count", -1)) == 0, "Reduced Motion should preserve an untinted target")
	_assert(int(prompt.get_meta("spotlight_pulse_border_count", 0)) == 1, "Reduced Motion should preserve the static target border")
	await _save_root_screenshot("%s/03_exact_move_reduced_motion.png" % OUTPUT_DIR)
	reduced_settings["reduced_motion"] = false
	instance.set("_settings", reduced_settings)
	instance.call("_refresh_contextual_combat_tutorial")
	await instance.call("_on_board_tile_clicked", move_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_INSPECT_ENEMY, true, "inspect the authored crawler")
	var support_tile: Vector2i = GuidedCombatScenario.support_tile(instance.get("_combat_state") as Dictionary)
	_assert((instance.call("_guided_tutorial_allowed_board_tiles") as Array) == [support_tile], "Intent rail should isolate the crawler that will later attack")
	var support_actor_key: String = "enemy_%d" % GuidedCombatScenario.SUPPORT_ENEMY_ID
	var support_inspection_rect: Rect2 = board.call("enemy_inspection_visual_global_rect", support_actor_key) as Rect2
	var inspect_spotlights: Array = prompt.get_meta("spotlight_rects", []) as Array
	_assert(inspect_spotlights.size() == 1 and (inspect_spotlights[0] as Rect2).encloses(support_inspection_rect), "The initial crawler border should contain its complete silhouette and Health")
	await _save_root_screenshot("%s/04_exact_enemy_intent.png" % OUTPUT_DIR)
	instance.call("_on_board_tile_hovered", support_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CONFIRM_INTENT, true, "confirm the crawler intent")
	var intent_evidence: Array = prompt.get_meta("evidence_rects", []) as Array
	_assert(intent_evidence.size() == 1 and (intent_evidence[0] as Rect2).has_area(), "Intent confirmation should keep the complete move-and-attack panel undimmed")
	var intent_rect: Rect2 = intent_evidence[0] as Rect2 if not intent_evidence.is_empty() else Rect2()
	var intent_callout_rect: Rect2 = prompt.get_meta("callout_rect", Rect2()) as Rect2
	_assert(not intent_callout_rect.intersects(intent_rect), "Tutorial copy should not cover the enemy intent evidence it explains")
	var expanded_inspection_rect: Rect2 = board.call("enemy_inspection_visual_global_rect", support_actor_key) as Rect2
	var expanded_spotlights: Array = prompt.get_meta("spotlight_rects", []) as Array
	_assert(
		expanded_spotlights.size() == 1
		and (expanded_spotlights[0] as Rect2).encloses(expanded_inspection_rect)
		and (expanded_spotlights[0] as Rect2).encloses(intent_rect),
		"The expanded step-two border should contain the complete crawler and its full move-and-attack intent"
	)
	await _save_root_screenshot("%s/05_intent_confirmation.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()

	# Lesson 3: teach the two-play meter before asking for a card, then practice a
	# reversible preview with one prescribed card.
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CARD_PLAYS, true, "read the two-play counter")
	_assert(int(combat.call("cards_remaining_this_turn", instance.get("_combat_state") as Dictionary)) == 2, "The explanation should be backed by a real 2-play counter")
	await _save_root_screenshot("%s/06_two_card_plays.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_CARD_FOR_CANCEL, true, "preview Pale Spark")
	var bone_index: int = _card_index(instance, GuidedCombatScenario.PREVIEW_CARD_ID)
	_assert((instance.call("_guided_tutorial_playable_card_indices") as Array) == [bone_index], "Only Pale Spark should be selectable during its authored rail")
	var bone_control: Control = instance.call("_hand_card_control", bone_index) as Control
	instance.call("_on_card_hover_started", bone_index)
	await _settle_ui()
	var live_bone_rect: Rect2 = instance.call("_control_visual_global_rect", bone_control) as Rect2
	var guided_card_rects: Array = prompt.get_meta("spotlight_rects", []) as Array
	var guided_bone_rect: Rect2 = guided_card_rects[0] as Rect2 if not guided_card_rects.is_empty() else Rect2()
	_assert(
		guided_card_rects.size() == 1
		and guided_bone_rect.position.distance_to(live_bone_rect.position) <= 1.0
		and guided_bone_rect.size.distance_to(live_bone_rect.size) <= 1.0,
		"The Pale Spark border should follow the card's live hovered position and size (border=%s, card=%s)" % [guided_bone_rect, live_bone_rect]
	)
	await _save_root_screenshot("%s/07_bone_dart_live_border.png" % OUTPUT_DIR)
	await instance.call("_on_card_pressed", bone_index)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CANCEL_CARD, true, "cancel Pale Spark safely")
	await _save_root_screenshot("%s/08_bone_dart_cancel.png" % OUTPUT_DIR)
	var blocked_before: int = int(prompt.get_meta("blocked_count", 0))
	await instance.call("_on_board_tile_clicked", Vector2i(1, 1))
	await _settle_short()
	_assert(int(prompt.get_meta("blocked_count", 0)) > blocked_before, "A wrong target should produce visible feedback without mutation")
	await _save_root_screenshot("%s/09_wrong_click_feedback.png" % OUTPUT_DIR)
	await instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_FIRST_CARD, true, "play Pale Spark for real")

	# First attack: 2 -> 1 play and 12 -> 9 HP.
	bone_index = _card_index(instance, GuidedCombatScenario.PREVIEW_CARD_ID)
	await instance.call("_on_card_pressed", bone_index)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_FIRST_TARGET, true, "aim Pale Spark at the authored crawler")
	var target_tile: Vector2i = GuidedCombatScenario.target_tile(instance.get("_combat_state") as Dictionary)
	await _save_root_screenshot("%s/10_bone_dart_target.png" % OUTPUT_DIR)
	await instance.call("_on_board_tile_clicked", target_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_FIRST_PLAY, true, "read the one-play counter")
	var first_state: Dictionary = instance.get("_combat_state") as Dictionary
	_assert(int(combat.call("cards_remaining_this_turn", first_state)) == 1, "Pale Spark should spend exactly one real card play")
	_assert(_enemy_hp(first_state, GuidedCombatScenario.TARGET_ENEMY_ID) == 9, "Pale Spark should leave the authored crawler at 9 HP")
	await _save_root_screenshot("%s/11_first_play_spent.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()

	# Controller presentation must focus the same one legal Quick Stab card.
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
		instance.call("_refresh_contextual_combat_tutorial")
		await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_KILL_CARD, true, "controller Quick Stab rail")
	_assert(bool(prompt.get_meta("controller_active", false)), "Controller proof should use controller-native tutorial copy and glyphs")
	await _save_root_screenshot("%s/12_controller_quick_stab.png" % OUTPUT_DIR)
	if router != null:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_XBOX)
		instance.call("_refresh_contextual_combat_tutorial")
		await _settle_ui()

	# Second attack kills at exact damage, spends the second base play, and lets the
	# engine's ordinary death reward return one play.
	var stab_index: int = _card_index(instance, GuidedCombatScenario.KILL_CARD_ID)
	_assert((instance.call("_guided_tutorial_playable_card_indices") as Array) == [stab_index], "Only Quick Stab should be selectable for the lethal rail")
	await instance.call("_on_card_pressed", stab_index)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_KILL_TARGET, true, "target the lethal Quick Stab")
	await _save_root_screenshot("%s/13_quick_stab_lethal.png" % OUTPUT_DIR)
	await instance.call("_on_board_tile_clicked", target_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_KILL_REFUND, true, "read the kill refund")
	var kill_state: Dictionary = instance.get("_combat_state") as Dictionary
	_assert(_enemy_hp(kill_state, GuidedCombatScenario.TARGET_ENEMY_ID) == 0, "Quick Stab should kill the scripted crawler")
	_assert(int(kill_state.get("death_bonus_card_plays_this_turn", 0)) == 1, "The kill should earn the engine's real +1 card-play reward")
	_assert(int(combat.call("cards_remaining_this_turn", kill_state)) == 1, "The counter should visibly return to 1 after the kill")
	await _save_root_screenshot("%s/14_kill_refund.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()

	# Spend the returned play on Brace, then teach timing and Pass before release.
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_REFUND_CARD, true, "spend the refund on Brace")
	var brace_index: int = _card_index(instance, GuidedCombatScenario.REFUND_CARD_ID)
	_assert((instance.call("_guided_tutorial_playable_card_indices") as Array) == [brace_index], "Only Brace should be selectable for the refunded play")
	await instance.call("_on_card_pressed", brace_index)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_FINISH_REFUND_CARD, true, "confirm Brace")
	await _save_root_screenshot("%s/15_brace_confirmation.png" % OUTPUT_DIR)
	await instance.call("_on_board_tile_clicked", _player_tile(instance))
	await _settle_ui()
	var brace_state: Dictionary = instance.get("_combat_state") as Dictionary
	_assert(int((brace_state.get("player", {}) as Dictionary).get("block", 0)) == 6, "Brace should grant its real 6 Block")
	_assert(int(combat.call("cards_remaining_this_turn", brace_state)) == 0, "Brace should spend the refunded play")
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_TURN_CLOCK, true, "read the Turn Clock")
	await _save_root_screenshot("%s/16_turn_clock.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_PASS_TURN, true, "Pass after spending the authored turn")
	await _save_root_screenshot("%s/17_pass_preview.png" % OUTPUT_DIR)
	var hp_before_pass: int = int((brace_state.get("player", {}) as Dictionary).get("hp", 0))
	var support_before_pass: Vector2i = (_enemy_for_id(brace_state, GuidedCombatScenario.SUPPORT_ENEMY_ID)).get("pos", INVALID_TILE)
	await instance.call("_on_pass_turn_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CORE_COMPLETE, false, "free-play handoff")
	var after_pass_state: Dictionary = instance.get("_combat_state") as Dictionary
	var player_after_pass: Dictionary = after_pass_state.get("player", {}) as Dictionary
	var support_after_pass: Vector2i = (_enemy_for_id(after_pass_state, GuidedCombatScenario.SUPPORT_ENEMY_ID)).get("pos", INVALID_TILE)
	_assert(int(player_after_pass.get("hp", 0)) == hp_before_pass, "Brace should prevent the crawler's real attack from reducing Health")
	_assert(support_after_pass != support_before_pass and support_after_pass.distance_to(_player_tile(instance)) == 1.0, "The inspected crawler should visibly move into melee range before attacking")
	_assert((prompt.get_meta("spotlight_rects", []) as Array).is_empty(), "The free-play handoff should not draw a board-sized gold frame")
	await _save_root_screenshot("%s/18_block_result_handoff.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_no_prompt(instance, "free-play combat after authored rails")

	# Preserve the existing production reward/path/completion proof.
	var reward_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["combat_state"] = {}
	reward_state["pending_reward"] = {"cards": ["quick_stab", "bone_dart", "sidestep_slash"], "heal_amount": RunEngine.REWARD_HEAL, "ember_amount": 0, "intro_pending": false}
	reward_state["progression"] = (instance.get("_progression") as Dictionary).duplicate(true)
	instance.call("_load_run_state", reward_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_CHOOSE_REWARD)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_REWARD, true, "choose a combat reward")
	await _save_root_screenshot("%s/19_reward_choice.png" % OUTPUT_DIR)
	instance.call("_guided_tutorial_complete_milestone", ContextualCombatTutorial.MILESTONE_REWARD)

	var run_engine := RunEngine.new()
	var room_state: Dictionary = run_engine.create_new_run(22017, instance.get("_progression") as Dictionary)
	room_state["progression"] = (instance.get("_progression") as Dictionary).duplicate(true)
	instance.call("_load_run_state", room_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_CHOOSE_PATH)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_PATH, true, "choose the next room")
	_assert_path_geometry(instance, instance.get("_large_map_scrim").visible)
	await _save_root_screenshot("%s/20_path_choice.png" % OUTPUT_DIR)
	var exit_destinations: Dictionary = instance.get("_exit_destinations_by_tile") as Dictionary
	var door_tile: Vector2i = exit_destinations.keys()[0] as Vector2i
	if instance.get("_large_map_scrim").visible:
		await instance.call("_on_large_map_room_selected", exit_destinations[door_tile] as Vector2i)
	else:
		await instance.call("_on_map_view_room_selected", exit_destinations[door_tile] as Vector2i, door_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_COMPLETE, false, "guided-run completion")
	await _save_root_screenshot("%s/21_completion.png" % OUTPUT_DIR)
	var begin_button: Button = prompt.get("_continue_button") as Button
	_assert(begin_button != null and begin_button.visible and begin_button.text == "Begin", "The final acknowledgement should expose an interactive Begin button")
	await _click_control(begin_button)
	await _settle_ui()
	_assert_no_prompt(instance, "completed tutorial")
	_assert(ContextualCombatTutorial.is_completed(ProgressionStore.load_data()), "Begin should persist the completed authored tutorial")
	instance.queue_free()
	await _settle_short()
	if router != null:
		router.call("clear_forced_state_for_test")

func _capture_guided_run(active_progression: Dictionary) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for guided tutorial visual proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_combat_fixture(instance, 11601, active_progression)

	# Lesson 1: the real board owns selection and movement targeting.
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_SELECT_PLAYER)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_PLAYER, true, "select the Wanderer")
	await _save_root_screenshot("%s/01_select_player_pointer.png" % OUTPUT_DIR)

	var player_tile: Vector2i = _player_tile(instance)
	await instance.call("_on_board_tile_clicked", player_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_MOVE, true, "choose a movement tile")
	_assert(not (instance.get("_player_movement_target_tiles") as Array).is_empty(), "Movement lesson should expose real legal movement tiles")
	await _save_root_screenshot("%s/02_choose_move_pointer.png" % OUTPUT_DIR)
	instance.call("_guided_tutorial_complete_milestone", ContextualCombatTutorial.MILESTONE_MOVE)
	instance.call("_cancel_player_movement_selection")

	# Lesson 2: hovering a real enemy must leave a persistent confirmation step.
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_INSPECT_ENEMY)
	var enemy_tile: Vector2i = _first_enemy_tile(instance)
	instance.call("_on_board_tile_hovered", enemy_tile)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CONFIRM_INTENT, true, "confirm enemy intent")
	_assert(instance.get("_hovered_board_tile") == enemy_tile, "Intent confirmation should preserve the inspected enemy as visible evidence")
	await _save_root_screenshot("%s/03_enemy_intent_confirmation.png" % OUTPUT_DIR)

	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_CARD_FOR_CANCEL, true, "begin card preview lesson")

	# Lesson 3: use the production click-to-preview path and retain Cancel until used.
	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert(int(instance.get("_selected_card_index")) == 0, "Card-preview lesson should select the real hand card")
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CANCEL_CARD, true, "cancel a card preview")
	await _save_root_screenshot("%s/04_card_preview_cancel.png" % OUTPUT_DIR)

	var blocked_before: int = int(prompt.get_meta("blocked_count", 0))
	await instance.call("_on_board_tile_clicked", Vector2i(1, 1))
	await _settle_short()
	_assert(int(prompt.get_meta("blocked_count", 0)) > blocked_before, "A non-highlighted action should produce visible blocked feedback")
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CANCEL_CARD, true, "blocked action feedback")
	await _save_root_screenshot("%s/05_blocked_feedback.png" % OUTPUT_DIR)

	await instance.call("_on_cancel_requested")
	await _settle_ui()
	_assert(int(instance.get("_selected_card_index")) == -1, "Cancel lesson should return the previewed card without spending it")
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_CARD_TO_PLAY, true, "reselect a card after cancellation")

	# Lesson 4: a compound card exposes its real movement and attack steps.
	await instance.call("_on_card_pressed", 0)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_TARGET, true, "select the card target")
	_assert(int(prompt.get("_blocked_until_msec")) == 0, "A successful next phase should clear the blocked-action red accent")
	var first_targets: Array = instance.get("_pending_target_tiles") as Array
	_assert(not first_targets.is_empty(), "Target lesson should expose real legal card targets")
	await _save_root_screenshot("%s/06_card_target.png" % OUTPUT_DIR)

	# Stage the second action directly instead of using the compound-card shortcut,
	# which intentionally resolves movement + its only adjacent strike in one click.
	# The selected card, production action tracker, board preview, and target controls
	# remain the real RunScene controls rendered by the normal refresh path.
	var setup_target: Vector2i = Vector2i(4, 4) if first_targets.has(Vector2i(4, 4)) else first_targets[0]
	var preview_state: Dictionary = (instance.get("_preview_combat_state") as Dictionary).duplicate(true)
	var preview_player: Dictionary = (preview_state.get("player", {}) as Dictionary).duplicate(true)
	preview_player["pos"] = setup_target
	preview_state["player"] = preview_player
	instance.set("_preview_combat_state", preview_state)
	instance.set("_pending_action_index", 1)
	instance.set("_pending_selected_targets", instance.call("_vector2i_array", [setup_target]))
	instance.call("_mark_preview_selection_changed")
	instance.call("_refresh_card_preview_ui")
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_FINISH_CARD)
	# The production compound shortcut normally authors this second-step target
	# after the first preview refresh. Mirror that order so the proof captures the
	# melee action rather than retaining the movement step's broad target set.
	instance.set("_pending_target_tiles", instance.call("_vector2i_array", [enemy_tile]))
	instance.call("_refresh_stage_view")
	instance.call("_refresh_action_step_tracker")
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_FINISH_CARD, true, "finish the compound card")
	_assert((prompt.get_meta("spotlight_rects", []) as Array).size() == 1, "Compound-card finish proof should isolate its one remaining melee target")
	_assert(int(instance.get("_selected_card_index")) == 0, "Compound-card finish step should preserve the selected card")
	await _save_root_screenshot("%s/07_card_finish.png" % OUTPUT_DIR)

	# The same production callout must swap to controller-native copy and glyphs.
	instance.call("_cancel_card_selection")
	var router: Node = root.get_node_or_null("InputRouter")
	if router == null:
		_fail("InputRouter should exist for controller tutorial proof")
	else:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_SELECT_CARD_TO_PLAY)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_SELECT_CARD_TO_PLAY, true, "controller card selection")
	_assert(bool(prompt.get_meta("controller_active", false)), "Controller capture should render controller-specific tutorial presentation")
	_assert(str(prompt.get_meta("prompt_text", "")).contains("Select a lit card"), "Controller tutorial copy should remain concise and action-specific")
	await _save_root_screenshot("%s/08_controller_card_selection.png" % OUTPUT_DIR)
	if router != null:
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_XBOX)

	# Reduced motion keeps the spotlight readable while removing its pulse.
	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_begin_player_movement_selection")
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_CHOOSE_MOVE)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_MOVE, true, "reduced-motion movement")
	_assert(bool(prompt.get_meta("reduced_motion", false)), "Reduced-motion capture should render the static spotlight treatment")
	await _save_root_screenshot("%s/09_reduced_motion_move.png" % OUTPUT_DIR)
	instance.call("_cancel_player_movement_selection")
	var normal_settings: Dictionary = reduced_settings.duplicate(true)
	normal_settings["reduced_motion"] = false
	instance.set("_settings", normal_settings)

	# Lessons 5 and 6 retain the real turn-order and Pass consequence evidence.
	instance.call("_guided_tutorial_complete_milestone", ContextualCombatTutorial.MILESTONE_CARD)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_TURN_CLOCK)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_TURN_CLOCK, true, "read the Turn Clock")
	await _save_root_screenshot("%s/10_turn_clock.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_PASS_TURN, true, "Pass consequence preview")
	var pass_preview: Control = instance.get("_pass_preview_overlay") as Control
	_assert(pass_preview != null and pass_preview.is_visible_in_tree(), "Pass lesson should keep the production consequence preview visible")
	await _save_root_screenshot("%s/11_pass_preview.png" % OUTPUT_DIR)

	await instance.call("_on_pass_turn_pressed")
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CORE_COMPLETE, false, "core combat handoff")
	await _save_root_screenshot("%s/12_core_handoff.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_no_prompt(instance, "free-play combat after the core lesson")

	# Lesson 7: render the genuine post-combat card decision surface.
	var reward_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["combat_state"] = {}
	reward_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0,
		"intro_pending": false,
	}
	reward_state["progression"] = (instance.get("_progression") as Dictionary).duplicate(true)
	instance.call("_load_run_state", reward_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_CHOOSE_REWARD)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_REWARD, true, "choose a combat reward")
	var reward_bar: Control = instance.get("_relic_choice_bar") as Control
	_assert(reward_bar != null and reward_bar.is_visible_in_tree() and reward_bar.get_child_count() > 0, "Reward lesson should spotlight the real production reward choices")
	await _save_root_screenshot("%s/13_reward_choice.png" % OUTPUT_DIR)
	instance.call("_guided_tutorial_complete_milestone", ContextualCombatTutorial.MILESTONE_REWARD)

	# Lesson 8: the active travel surface owns the generated room/door choices.
	var run_engine := RunEngine.new()
	var room_state: Dictionary = run_engine.create_new_run(22017, instance.get("_progression") as Dictionary)
	room_state["progression"] = (instance.get("_progression") as Dictionary).duplicate(true)
	instance.call("_load_run_state", room_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_guided_tutorial_set_phase", ContextualCombatTutorial.PHASE_CHOOSE_PATH)
	await _settle_ui()
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_CHOOSE_PATH, true, "choose the next room")
	var exit_destinations: Dictionary = instance.get("_exit_destinations_by_tile") as Dictionary
	_assert(not exit_destinations.is_empty(), "Path lesson should spotlight real generated travel destinations")
	_assert_path_geometry(instance, instance.get("_large_map_scrim").visible)
	await _save_root_screenshot("%s/14_path_choice.png" % OUTPUT_DIR)

	# Commit a real doorway choice. The final acknowledgement must sit above the
	# production pre-battle dossier, exactly where the first-run flow lands.
	var door_tile: Vector2i = exit_destinations.keys()[0] as Vector2i
	var destination: Vector2i = exit_destinations[door_tile] as Vector2i
	await instance.call("_on_map_view_room_selected", destination, door_tile)
	await _settle_ui()
	_assert(str((instance.get("_run_state") as Dictionary).get("mode", "")) == RunEngine.MODE_PRE_BATTLE, "The guided path choice should enter the real pre-battle state")
	var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
	var prompt_host: Control = instance.get("_contextual_combat_prompt_host") as Control
	_assert(pre_battle_scrim != null and pre_battle_scrim.is_visible_in_tree(), "The completion proof should retain the production pre-battle dossier")
	_assert(prompt_host != null and prompt_host.z_index > pre_battle_scrim.z_index, "The completion prompt should render above the pre-battle dossier")
	_assert_prompt(instance, ContextualCombatTutorial.PHASE_COMPLETE, false, "guided-run completion over pre-battle")
	_assert((prompt.get_meta("spotlight_rects", []) as Array).is_empty(), "The final Begin acknowledgement should fully dim the underlying pre-battle dossier")
	_assert(int(prompt.get_meta("spotlight_hole_count", -1)) == 0, "The final acknowledgement should cut no spotlight holes through the dimmer")
	_assert(int(prompt.get_meta("spotlight_frame_count", -1)) == 0, "The final acknowledgement should draw no competing spotlight frames")
	var begin_button: Button = prompt.get("_continue_button") as Button
	var final_skip_button: Button = prompt.get("_skip_button") as Button
	_assert(begin_button.visible and begin_button.text == "Begin", "The completion callout should expose Begin as its primary action")
	_assert(not final_skip_button.visible, "The completed curriculum should not offer a competing Skip action")
	await _save_root_screenshot("%s/15_completion_pre_battle.png" % OUTPUT_DIR)
	prompt.call("_on_completed_pressed")
	await _settle_ui()
	_assert_no_prompt(instance, "completed tutorial immediately after Begin")
	var completed_progression: Dictionary = ProgressionStore.load_data()
	_assert(ContextualCombatTutorial.is_completed(completed_progression), "Begin should persist the completed tutorial profile")

	instance.queue_free()
	await _settle_short()

	# A newly mounted RunScene with the persisted profile must stay tutorial-free.
	var returning_instance: Node = packed.instantiate()
	root.add_child(returning_instance)
	await _settle_ui()
	await _load_combat_fixture(returning_instance, 11602, completed_progression)
	_assert_no_prompt(returning_instance, "completed profile on a later combat")
	returning_instance.call("_on_board_tile_hovered", _first_enemy_tile(returning_instance))
	await _settle_ui()
	_assert_no_prompt(returning_instance, "completed profile after enemy inspection")
	await _save_root_screenshot("%s/16_completed_profile_absent.png" % OUTPUT_DIR)
	returning_instance.queue_free()
	await _settle_short()
	if router != null:
		router.call("clear_forced_state_for_test")

func _load_combat_fixture(instance: Node, seed: int, progression: Dictionary) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["sidestep_slash"],
		"relics": [],
		"hand_size": 1,
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["sidestep_slash"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["traps"] = []
	combat_state["terrain"] = []

	var progression_copy: Dictionary = progression.duplicate(true)
	instance.set("_progression", progression_copy)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	run_state["progression"] = progression_copy
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_ui()

func _load_authored_combat_fixture(instance: Node, seed: int, progression: Dictionary) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace", "pale_spark", "guarded_step", "shadow_step"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0,
	})
	var progression_copy: Dictionary = progression.duplicate(true)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["progression"] = progression_copy
	run_state = GuidedCombatScenario.mark_run_eligible(run_state)
	combat_state = GuidedCombatScenario.prepare_for_run(run_state, combat_state)
	run_state["combat_state"] = combat_state
	instance.set("_progression", progression_copy)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_ui()

func _card_index(instance: Node, card_id: String) -> int:
	return (((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).find(card_id)

func _enemy_hp(state: Dictionary, enemy_id: int) -> int:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			return int((enemy_var as Dictionary).get("hp", 0))
	return -1

func _enemy_for_id(state: Dictionary, enemy_id: int) -> Dictionary:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) == TYPE_DICTIONARY and int((enemy_var as Dictionary).get("id", -1)) == enemy_id:
			return enemy_var as Dictionary
	return {}

func _click_control(control: Control) -> void:
	var viewport: Viewport = control.get_viewport()
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = point
		event.global_position = point
		viewport.push_input(event, true)
		await process_frame

func _button_texts(node: Node) -> Array[String]:
	var result: Array[String] = []
	if node == null:
		return result
	if node is Button:
		result.append((node as Button).text)
	for child: Node in node.get_children():
		result.append_array(_button_texts(child))
	return result

func _combat_layout() -> Dictionary:
	return {
		"name": "First Combat Lesson",
		"coord": Vector2i(1, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 4),
			"hp": 140,
			"max_hp": 140,
			"block": 0,
		}],
		"traps": [],
		"terrain": [],
		"loot": [],
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _player_tile(instance: Node) -> Vector2i:
	return ((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", INVALID_TILE)

func _first_enemy_tile(instance: Node) -> Vector2i:
	var enemies: Array = (instance.get("_combat_state") as Dictionary).get("enemies", []) as Array
	if enemies.is_empty():
		_fail("Combat tutorial fixture should contain a visible enemy")
		return INVALID_TILE
	return (enemies[0] as Dictionary).get("pos", INVALID_TILE)

func _assert_prompt(instance: Node, expected_phase: String, spotlight_required: bool, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	if host == null or prompt == null or not host.is_visible_in_tree() or not prompt.is_visible_in_tree():
		_fail("Expected visible %s tutorial phase for %s" % [expected_phase, label])
		return
	_assert(str(instance.get("_active_contextual_combat_prompt_id")) == expected_phase, "%s should own the active RunScene phase" % label)
	_assert(str(prompt.get_meta("prompt_id", "")) == expected_phase, "%s should configure the rendered callout with the same phase" % label)
	_assert(not str(prompt.get_meta("prompt_text", "")).strip_edges().is_empty(), "%s should include concise action copy" % label)
	_assert(host.get_global_rect().size.distance_to(Vector2(PROBE_VIEWPORT)) <= 1.0, "%s should use a fixed full-screen spotlight layer" % label)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(PROBE_VIEWPORT))
	var callout_rect: Rect2 = prompt.get_meta("callout_rect", Rect2())
	_assert(callout_rect.has_area() and viewport_rect.encloses(callout_rect), "%s callout should remain fully inside the 1920x1080 viewport: %s" % [label, callout_rect])
	var spotlight_rects: Array = prompt.get_meta("spotlight_rects", []) as Array
	if spotlight_required:
		_assert(not spotlight_rects.is_empty(), "%s should expose at least one real spotlight target" % label)
	var frame_count: int = int(prompt.get_meta("spotlight_frame_count", -1))
	_assert(frame_count > 0 or spotlight_rects.is_empty(), "%s should render a frame for every spotlight group" % label)
	_assert(frame_count == spotlight_rects.size(), "%s should keep one tight border per exact target" % label)
	for rect_var: Variant in spotlight_rects:
		if typeof(rect_var) != TYPE_RECT2:
			_fail("%s spotlight metadata should contain only Rect2 values" % label)
			continue
		var spotlight: Rect2 = rect_var
		_assert(spotlight.has_area() and viewport_rect.intersects(spotlight), "%s spotlight should intersect the live viewport: %s" % [label, spotlight])
		if spotlight_required:
			_assert(not callout_rect.intersects(spotlight.grow(4.0)), "%s callout should not cover its highlighted action" % label)

func _assert_no_prompt(instance: Node, label: String) -> void:
	var host: Control = instance.get("_contextual_combat_prompt_host") as Control
	var prompt: Control = instance.get("_contextual_combat_prompt") as Control
	_assert(host != null and not host.visible, "%s should not show the tutorial host" % label)
	_assert(prompt != null and not prompt.visible, "%s should not leave a tutorial callout visible" % label)
	_assert(str(instance.get("_active_contextual_combat_prompt_id")).is_empty(), "%s should clear the active phase id" % label)

func _settle_ui() -> void:
	await process_frame
	await process_frame
	await process_frame
	await create_timer(0.18).timeout
	await process_frame

func _settle_short() -> void:
	await process_frame
	await process_frame
	await create_timer(0.05).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("Guided tutorial proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(PROBE_VIEWPORT.x)
	var scale_y: float = float(source_size.y) / float(PROBE_VIEWPORT.y)
	var valid_backing_size: bool = (
		is_equal_approx(scale_x, scale_y)
		and is_equal_approx(float(source_size.x) / float(source_size.y), 16.0 / 9.0)
	)
	if not valid_backing_size:
		_fail("Guided tutorial proof must keep a 16:9 backing, got %s (scale %.4f x %.4f)" % [source_size, scale_x, scale_y])
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(output_path)
	_assert(error == OK, "Guided tutorial proof should save %s" % output_path)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	push_error(message)
	_failed = true

func _remove_if_present(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
