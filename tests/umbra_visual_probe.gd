extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/umbra_visual"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const UMBRA_SUBTITLE_PATH: String = "UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/TitleBox/UmbraSubtitle"
const STAGES: Array[String] = ["clear", "fringe", "advancing", "pressing", "deep", "heart", "eclipse"]
const EXPECTED_VISIBLE: Dictionary = {
	"clear": 6,
	"fringe": 6,
	"advancing": 5,
	"pressing": 4,
	"deep": 3,
	"heart": 2,
	"eclipse": 1
}
const EXPECTED_SUBTITLE: Dictionary = {
	"clear": "",
	"fringe": "Fringe Umbra",
	"advancing": "Advancing Umbra",
	"pressing": "Pressing Umbra",
	"deep": "Deep Umbra",
	"heart": "Heart Umbra",
	"eclipse": "Eclipse Umbra"
}
const RADIANCE_CARDS: Array[String] = [
	"lantern_shot",
	"guiding_flare",
	"dawnstep",
	"prism_sight",
	"storm_beacon",
	"glowstone_ward",
	"daybreak"
]
const CHANGED_RADIANCE_CARDS = [
	"ember_rain",
	"trapdoor",
	"firebrand_volley",
	"icebound_chains",
	"spark_dart",
	"spark_focus",
	"threaded_path",
	"root_snare",
	"dawnstep",
	"prism_sight"
]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://umbra_visual_progression.json")
	ProgressionStore.set_run_storage_path("user://umbra_visual_run.save")
	ProgressionStore.clear_saved_run()
	await _capture_umbra_stages_and_cards()
	for _frame: int in range(3):
		await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("UMBRA VISUAL PROBE: PASS")
	quit(0)

func _capture_umbra_stages_and_cards() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for Umbra visual proof")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _capture_umbra_warning_dialogue(instance)
	for stage: String in STAGES:
		await _load_stage(instance, stage)
		var board: Control = instance.get_node(BOARD_PATH) as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var visible_enemy_ids: Array = presentation.get("visible_enemy_ids", [])
		_assert(visible_enemy_ids.size() == int(EXPECTED_VISIBLE.get(stage, -1)), "%s should expose exactly %d enemies" % [stage, int(EXPECTED_VISIBLE.get(stage, -1))])
		var umbra_subtitle: Label = instance.get_node(UMBRA_SUBTITLE_PATH) as Label
		var expected_subtitle: String = str(EXPECTED_SUBTITLE.get(stage, ""))
		_assert(umbra_subtitle != null and umbra_subtitle.text == expected_subtitle, "%s should show its dedicated Umbra room subtitle" % stage)
		_assert(umbra_subtitle.visible == not expected_subtitle.is_empty(), "%s should use the expected Umbra subtitle visibility" % stage)
		if stage != "clear":
			_assert(umbra_subtitle.tooltip_text.contains("Hidden enemies cannot be targeted"), "%s should explain its targeting and intent rules on hover" % stage)
		_assert(not (instance.get("_intensity_labels") as Dictionary).has("umbra"), "Umbra should not be represented as an elemental intensity")
		_assert((instance.get("_intensity_bar") as Control).get_child_count() == 5, "Intensity bar should contain only the five elements")
		await _save_root_screenshot("%s/stage_%s.png" % [OUTPUT_DIR, stage])
		if stage == "deep":
			await create_timer(0.65).timeout
			RenderingServer.force_draw()
			await process_frame
			await _save_root_screenshot("%s/stage_deep_billow.png" % OUTPUT_DIR)
	await _capture_grimoire_entries(instance)
	await _capture_active_effect_feedback(instance)
	await _capture_redesign_spatial_effects(instance)
	await _capture_card_gallery(instance)
	await _capture_action_group_gallery(instance)
	await _capture_token_suffix_stress_gallery(instance)
	instance.queue_free()
	await process_frame

func _capture_umbra_warning_dialogue(instance: Node) -> void:
	instance.call("_close_dialogue")
	var discovery_progression: Dictionary = ProgressionStore.prepare_for_new_run(ProgressionStore.default_data())
	discovery_progression = ProgressionStore.record_first_umbra_reach(discovery_progression, int(discovery_progression.get("run_counter", 0)))
	var warning_progression: Dictionary = ProgressionStore.prepare_for_new_run(discovery_progression)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "room"
	run_state["current_room"] = Vector2i.ZERO
	run_state["combat_state"] = {}
	run_state["run_index"] = int(warning_progression.get("run_counter", 0))
	run_state["progression"] = warning_progression.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", {})
	instance.set("_progression", warning_progression)
	instance.set("_last_auto_dialogue_key", "")
	instance.call("_refresh_ui")
	await _settle_ui()
	_assert(bool(instance.get("_dialogue_active")), "The run after first reaching Umbra should open with the Emaciated Man's warning")
	var dialogue_script: Dictionary = instance.get("_dialogue_script") as Dictionary
	var dialogue_lines: Array = dialogue_script.get("lines", [])
	_assert(bool(dialogue_script.get("marks_umbra_warning_seen", false)) and dialogue_lines.size() == 3, "The Umbra warning should remain a one-time three-line dialogue")
	var text_label: RichTextLabel = instance.get("_dialogue_text_label") as RichTextLabel
	_assert(text_label != null and text_label.text.contains("[i]his[/i] shadow"), "The warning should visually emphasize his in italics")
	instance.call("_complete_current_dialogue_line")
	await _settle_ui()
	await _save_root_screenshot("%s/umbra_warning_dialogue.png" % OUTPUT_DIR)
	instance.call("_close_dialogue")
	await _settle_ui()

func _load_stage(instance: Node, stage: String) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var combat := CombatEngine.new()
	var layout: Dictionary = _room_layout()
	var combat_state: Dictionary = combat.create_combat(97113, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": RADIANCE_CARDS,
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["lantern_shot", "dawnstep", "prism_sight", "glowstone_ward", "daybreak"]
	deck["draw"] = ["guiding_flare", "storm_beacon"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["traps"] = []
	combat_state["terrain"] = []
	combat_state["elemental_intensity"] = {"fire": 3, "ice": 3, "lightning": 3, "air": 3, "earth": 3}
	var umbra: Dictionary = (combat_state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = stage
	umbra["stage_reduction"] = 0
	combat_state["umbra"] = umbra
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle_ui()

func _capture_grimoire_entries(instance: Node) -> void:
	var discovery_ids: Array[String] = GrimoireLibrary.entry_ids_for_card_ids(RADIANCE_CARDS)
	if not discovery_ids.has("combat:umbra"):
		discovery_ids.append("combat:umbra")
	instance.call("_unlock_grimoire_entries", discovery_ids)
	await _capture_grimoire_entry(instance, "combat:umbra", "The Umbra", "Enemies concealed within it", "grimoire_umbra.png")
	await _capture_grimoire_entry(instance, "keyword:radiance", "Radiance", "Illuminate, Vision, Truesight", "grimoire_radiance.png")
	await _capture_grimoire_entry(instance, "keyword:truesight", "Truesight", "permits direct attacks", "grimoire_truesight.png")
	await _capture_grimoire_entry(instance, "equipment_card:lantern_shot", "Lantern Shot", "School: Radiance", "grimoire_lantern_shot.png")

func _capture_grimoire_entry(instance: Node, entry_id: String, expected_title: String, expected_body: String, file_name: String) -> void:
	instance.call("_open_grimoire_overlay")
	await _settle_ui()
	instance.call("_on_grimoire_entry_pressed", entry_id)
	await _settle_ui()
	var title: Label = instance.get("_grimoire_detail_title") as Label
	var body: RichTextLabel = instance.get("_grimoire_detail_body") as RichTextLabel
	_assert(title != null and title.text == expected_title, "%s should render its Grimoire title" % entry_id)
	var definition: Dictionary = GrimoireLibrary.entry_def(entry_id)
	var catalog_body: String = "\n".join(definition.get("body", []) as Array)
	_assert(catalog_body.contains(expected_body), "%s should carry its explanatory Grimoire body" % entry_id)
	if str(definition.get("card_id", "")).is_empty():
		_assert(body != null and body.visible and body.text.contains(expected_body), "%s should render its explanatory Grimoire body" % entry_id)
	else:
		var detail_content: VBoxContainer = instance.get("_grimoire_detail_content") as VBoxContainer
		_assert(detail_content != null and detail_content.get_child_count() > 0, "%s should render its card preview in the Grimoire" % entry_id)
	await _save_root_screenshot("%s/%s" % [OUTPUT_DIR, file_name])
	instance.call("_close_grimoire_overlay")
	await _settle_ui()

func _capture_active_effect_feedback(instance: Node) -> void:
	await _load_stage(instance, "heart")
	var active_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var active_umbra: Dictionary = (active_state.get("umbra", {}) as Dictionary).duplicate(true)
	active_umbra["light_sources"] = [{
		"id": 901,
		"pos": Vector2i(5, 5),
		"radius": 2,
		"remaining_activations": 2
	}]
	active_umbra["truesight_activations"] = 2
	active_state["umbra"] = active_umbra
	_set_combat_state(instance, active_state)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_assert(int(presentation.get("umbra_truesight_activations", 0)) == 2, "True Sight should expose its remaining activation count to the player HUD")
	_assert((presentation.get("umbra_light_sources", []) as Array).size() == 1, "Active light sources should be exposed to the board presentation")
	var source_footprint: Array[Vector2i] = _vector2i_array(board.call("_umbra_light_source_tiles", active_umbra["light_sources"][0]))
	_assert(source_footprint.size() == 13, "A radius-2 light reach treatment should cover the same 13-tile Manhattan footprint as Illuminate")
	_assert(source_footprint.has(Vector2i(5, 5)) and source_footprint.has(Vector2i(7, 5)), "Light reach treatment should include its source and radius edge")
	_assert(not source_footprint.has(Vector2i(7, 6)), "Light reach treatment should exclude tiles beyond Illuminate's Manhattan radius")
	var breath_min: float = INF
	var breath_max: float = -INF
	var bob_min: float = INF
	var bob_max: float = -INF
	for sample_index: int in range(12):
		var breath_time: float = float(sample_index) * TAU / (2.15 * 12.0)
		var bob_time: float = float(sample_index) * TAU / (1.45 * 12.0)
		var breath_sample: float = float(board.call("_umbra_light_orb_breath", 901.0, breath_time))
		var center_sample: Vector2 = board.call("_umbra_light_orb_center", Vector2i(5, 5), 901.0, bob_time)
		breath_min = minf(breath_min, breath_sample)
		breath_max = maxf(breath_max, breath_sample)
		bob_min = minf(bob_min, center_sample.y)
		bob_max = maxf(bob_max, center_sample.y)
	_assert(breath_max - breath_min >= 0.10, "Light orb should visibly breathe through a gentle animated scale range")
	_assert(bob_max - bob_min >= 2.0, "Light orb should gently bob instead of remaining static on its tile")
	_assert(_has_board_tooltip_containing(board, "Light Source"), "The glowing light-source marker should have a hover tooltip")
	_assert(_has_board_tooltip_containing(board, "True Sight"), "The player True Sight badge should have a hover tooltip")
	await _save_root_screenshot("%s/active_effect_feedback.png" % OUTPUT_DIR)
	await create_timer(0.54).timeout
	RenderingServer.force_draw()
	await process_frame
	await _save_root_screenshot("%s/active_effect_feedback_pulse.png" % OUTPUT_DIR)

	var expired_state: Dictionary = active_state.duplicate(true)
	var expired_umbra: Dictionary = (expired_state.get("umbra", {}) as Dictionary).duplicate(true)
	expired_umbra["light_sources"] = []
	expired_umbra["truesight_activations"] = 0
	expired_state["umbra"] = expired_umbra
	expired_state["turn"] = int(active_state.get("turn", 0)) + 1
	_set_combat_state(instance, expired_state)
	await process_frame
	_assert(not (board.get("_umbra_return_start_by_tile") as Dictionary).is_empty(), "Expired light should start a staggered Umbra return instead of snapping")
	RenderingServer.force_draw()
	await process_frame
	await _save_root_screenshot("%s/umbra_return_start.png" % OUTPUT_DIR)
	await create_timer(0.48).timeout
	RenderingServer.force_draw()
	await process_frame
	await _save_root_screenshot("%s/umbra_return_mid.png" % OUTPUT_DIR)
	await create_timer(0.65).timeout
	RenderingServer.force_draw()
	await process_frame
	_assert((board.get("_umbra_return_start_by_tile") as Dictionary).is_empty(), "Umbra return should finish in about one second")
	await _save_root_screenshot("%s/umbra_return_end.png" % OUTPUT_DIR)

func _set_combat_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_refresh_ui")

func _has_tooltip_containing(regions: Array, text: String) -> bool:
	for region_var: Variant in regions:
		if typeof(region_var) == TYPE_DICTIONARY and str((region_var as Dictionary).get("tooltip", "")).contains(text):
			return true
	return false

func _has_board_tooltip_containing(board: Control, text: String) -> bool:
	if _has_tooltip_containing(board.get("_tooltip_regions") as Array, text):
		return true
	for layer_var: Variant in board.call("_retained_render_layers"):
		var layer: Node = layer_var as Node
		if layer != null and _has_tooltip_containing(layer.get("_tooltip_regions") as Array, text):
			return true
	return false

func _hover_board_tooltip(board: Control, text: String) -> void:
	var tooltip_sources: Array = board.call("_retained_render_layers")
	tooltip_sources.append(board)
	for source_var: Variant in tooltip_sources:
		var source: Control = source_var as Control
		if source == null:
			continue
		for region_var: Variant in source.get("_tooltip_regions") as Array:
			if typeof(region_var) != TYPE_DICTIONARY:
				continue
			var region: Dictionary = region_var
			if not str(region.get("tooltip", "")).contains(text):
				continue
			var rect: Rect2 = region.get("rect", Rect2()) as Rect2
			var hover_position: Vector2 = board.get_global_transform_with_canvas() * rect.get_center()
			var motion := InputEventMouseMotion.new()
			motion.position = hover_position
			motion.global_position = hover_position
			root.push_input(motion, true)
			await create_timer(0.75).timeout
			RenderingServer.force_draw()
			await process_frame
			return
	_assert(false, "Could not find board tooltip containing %s" % text)

func _capture_redesign_spatial_effects(instance: Node) -> void:
	var combat := CombatEngine.new()
	var long_dawn_state: Dictionary = _radiance_visual_state(combat, [], ["long_dawn"])
	long_dawn_state = combat.apply_player_action(long_dawn_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(3, 4))
	long_dawn_state = combat.apply_player_action(long_dawn_state, {"type": "truesight", "duration": 2})
	_assert(int((long_dawn_state.get("umbra", {}) as Dictionary).get("truesight_activations", 0)) == 3, "Long Dawn visual fixture should expose its extended duration")
	_set_combat_state(instance, long_dawn_state)
	await _settle_ui()
	await _save_root_screenshot("%s/ability_long_dawn.png" % OUTPUT_DIR)

	var sunpath_state: Dictionary = _radiance_visual_state(combat, [], ["long_dawn", "sunpath"])
	sunpath_state = combat.apply_player_action(sunpath_state, {"type": "move", "range": 4}, Vector2i(5, 4))
	_assert(((sunpath_state.get("umbra", {}) as Dictionary).get("light_sources", []) as Array).size() == 3, "Sunpath visual fixture should leave Light on every entered tile")
	_set_combat_state(instance, sunpath_state)
	await _settle_ui()
	await _save_root_screenshot("%s/ability_sunpath_trail.png" % OUTPUT_DIR)

	var pilgrim_state: Dictionary = _radiance_visual_state(combat, ["pilgrim_boots"], [])
	pilgrim_state = combat.apply_player_action(pilgrim_state, {"type": "move", "range": 4, "_card_action_types": ["move"]}, Vector2i(5, 4))
	_set_combat_state(instance, pilgrim_state)
	await _settle_ui()
	await _save_root_screenshot("%s/relic_pilgrim_boots_trail.png" % OUTPUT_DIR)

	var witchlight_state: Dictionary = _radiance_visual_state(combat, [], ["witchlight"])
	witchlight_state["illusions"] = [{"id": 51, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	_set_combat_state(instance, witchlight_state)
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var witchlight_sources: Array = (board.get("presentation") as Dictionary).get("umbra_light_sources", []) as Array
	_assert(witchlight_sources.size() == 1 and bool((witchlight_sources[0] as Dictionary).get("tethered", false)), "Witchlight should reach the live board as tethered Light")
	_assert(_has_board_tooltip_containing(board, "Tethered Light"), "Tethered illusion Light should explain its actor-bound lifetime on hover")
	await _save_root_screenshot("%s/ability_witchlight_tether.png" % OUTPUT_DIR)

	var lantern_state: Dictionary = _radiance_visual_state(combat, ["witchglass_lantern"], [])
	lantern_state["illusions"] = [{"id": 61, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	_set_combat_state(instance, lantern_state)
	await _settle_ui()
	await _save_root_screenshot("%s/relic_witchglass_lantern_tether.png" % OUTPUT_DIR)

	var stacked_light_state: Dictionary = _radiance_visual_state(combat, ["witchglass_lantern"], ["witchlight"])
	stacked_light_state["illusions"] = [{"id": 62, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	_set_combat_state(instance, stacked_light_state)
	await _settle_ui()
	var stacked_sources: Array = (board.get("presentation") as Dictionary).get("umbra_light_sources", []) as Array
	_assert(stacked_sources.size() == 1 and int((stacked_sources[0] as Dictionary).get("radius", 0)) == 3, "Witchlight and Witchglass Lantern should render as radius-three tethered Light together")
	_assert(_has_board_tooltip_containing(board, "Witchlight: +1") and _has_board_tooltip_containing(board, "Witchglass Lantern: +2"), "Stacked tethered Light should explain both additive sources contextually")
	await _hover_board_tooltip(board, "Witchlight: +1")
	await _save_root_screenshot("%s/illusion_light_additive_stack.png" % OUTPUT_DIR)

	var dawnbrand_state: Dictionary = _radiance_visual_state(combat, [], ["dawnbrand"])
	dawnbrand_state = combat.apply_player_action(dawnbrand_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(7, 4))
	dawnbrand_state = combat.apply_player_action(dawnbrand_state, {"type": "ranged", "damage": 1, "range": 6}, Vector2i(7, 4))
	_assert(int(((dawnbrand_state.get("enemies", []) as Array)[0] as Dictionary).get("expose", 0)) == 1, "Dawnbrand visual fixture should expose the enemy standing in Light")
	_set_combat_state(instance, dawnbrand_state)
	await _settle_ui()
	await _save_root_screenshot("%s/ability_dawnbrand.png" % OUTPUT_DIR)

	var afterglow_state: Dictionary = _radiance_visual_state(combat, [], ["afterglow"])
	afterglow_state["illusions"] = [{"id": 52, "pos": Vector2i(4, 4), "hp": 2, "max_hp": 2}]
	afterglow_state = combat._damage_illusion(afterglow_state, 52, 2)
	_set_combat_state(instance, afterglow_state)
	await _settle_ui()
	await _save_root_screenshot("%s/ability_afterglow.png" % OUTPUT_DIR)

	var open_sky_state: Dictionary = _radiance_visual_state(combat, [], ["open_sky"])
	open_sky_state = combat.apply_player_action(open_sky_state, {"type": "illuminate", "range": 6, "radius": 1, "duration": 2}, Vector2i(2, 4))
	_assert(combat.player_has_truesight(open_sky_state), "Open Sky visual fixture should gain Truesight in Light")
	_set_combat_state(instance, open_sky_state)
	await _settle_ui()
	_assert(bool((board.get("presentation") as Dictionary).get("umbra_truesight_conditional", false)), "Open Sky should expose its conditional Truesight to the live HUD")
	await _save_root_screenshot("%s/ability_open_sky.png" % OUTPUT_DIR)

	var chain_state: Dictionary = _radiance_visual_state(combat, ["voltaic_tuning_fork"], [])
	chain_state["enemies"] = [_visual_enemy(1, Vector2i(6, 4)), _visual_enemy(2, Vector2i(7, 4))]
	chain_state = combat.apply_player_action(chain_state, {"type": "ranged", "damage": 1, "range": 6, "chain": 2, "_card_action_types": ["ranged"]}, Vector2i(6, 4))
	_set_combat_state(instance, chain_state)
	await _settle_ui()
	await _save_root_screenshot("%s/relic_stormglass_chain_light.png" % OUTPUT_DIR)

	var noon_state: Dictionary = _radiance_visual_state(combat, ["tectonic_abacus"], [])
	for source_pos: Vector2i in [Vector2i(2, 2), Vector2i(4, 2), Vector2i(6, 2), Vector2i(3, 5), Vector2i(5, 5), Vector2i(7, 5)]:
		noon_state = combat.call("_create_umbra_light_source", noon_state, source_pos, {"radius": 1, "duration": 2, "silent": true})
	_assert(combat.effective_umbra_stage(noon_state) == CombatEngine.UMBRA_STAGE_FRINGE, "Captured Noon visual fixture should reversibly suppress two Umbra stages")
	_set_combat_state(instance, noon_state)
	await _settle_ui()
	await _save_root_screenshot("%s/relic_captured_noon_suppression.png" % OUTPUT_DIR)

	await _capture_squall_orientation(instance, combat)

func _capture_squall_orientation(instance: Node, combat: CombatEngine) -> void:
	instance.call("_reset_card_resolution")
	var squall_state: Dictionary = _radiance_visual_state(combat, [], [])
	squall_state["player"] = {"pos": Vector2i(2, 4), "hp": 24, "max_hp": 24, "block": 0, "stoneskin": 0}
	squall_state["enemies"] = [
		_visual_enemy(1, Vector2i(4, 4)),
		_visual_enemy(2, Vector2i(4, 2)),
		_visual_enemy(3, Vector2i(6, 4)),
		_visual_enemy(4, Vector2i(4, 6))
	]
	var deck: Dictionary = (squall_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["squall_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	squall_state["deck"] = deck
	_set_combat_state(instance, squall_state)
	await _settle_ui()
	var preview: Dictionary = instance.call("_card_preview_for_index", 0)
	await instance.call("_begin_card_preview", 0, preview)
	instance.call("_on_board_tile_hovered", Vector2i(4, 4))
	instance.call("_rotate_aoe_aim", -1)
	instance.call("_on_board_tile_hovered", Vector2i(4, 4))
	await _settle_ui()
	var board: Control = instance.get_node(BOARD_PATH) as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var focus_tiles: Array = presentation.get("focus_tiles", []) as Array
	_assert(focus_tiles.has(Vector2i(4, 2)) and focus_tiles.has(Vector2i(6, 4)) and not focus_tiles.has(Vector2i(4, 6)), "Squall visual fixture should show its north-rotated odd pattern")
	await _save_root_screenshot("%s/card_squall_simplified_orientation_v4.png" % OUTPUT_DIR)
	instance.call("_reset_card_resolution")

func _radiance_visual_state(combat: CombatEngine, relic_ids: Array, skill_ids: Array) -> Dictionary:
	var state: Dictionary = combat.create_combat(97841, _room_layout(), {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab"],
		"relics": relic_ids,
		"skill_ids": skill_ids,
		"hand_size": 1,
		"heal_bonus": 0
	})
	state["enemies"] = [_visual_enemy(1, Vector2i(7, 4))]
	state["traps"] = []
	state["terrain"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	var umbra: Dictionary = (state.get("umbra", {}) as Dictionary).duplicate(true)
	umbra["stage"] = CombatEngine.UMBRA_STAGE_PRESSING
	umbra["stage_reduction"] = 0
	state["umbra"] = umbra
	return state

func _visual_enemy(enemy_id: int, pos: Vector2i) -> Dictionary:
	return {"id": enemy_id, "type": "crawler", "pos": pos, "hp": 20, "max_hp": 20, "block": 0, "stoneskin": 0}

func _capture_card_gallery(instance: Node) -> void:
	var gallery_layer := CanvasLayer.new()
	gallery_layer.layer = 1000
	root.add_child(gallery_layer)
	var gallery := Control.new()
	gallery.set_anchors_preset(Control.PRESET_FULL_RECT)
	gallery.anchor_right = 1.0
	gallery.anchor_bottom = 1.0
	gallery_layer.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("16111d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	gallery.add_child(background)
	var title := Label.new()
	title.text = "RADIANCE · LIGHT AGAINST THE UMBRA"
	title.position = Vector2(42.0, 18.0)
	title.size = Vector2(1836.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("f4dfb8"))
	gallery.add_child(title)
	for index: int in range(CHANGED_RADIANCE_CARDS.size()):
		var card_id: String = CHANGED_RADIANCE_CARDS[index]
		var slot := Control.new()
		slot.position = Vector2(90.0 + float(index % 5) * 360.0, 78.0 + float(index / 5) * 450.0)
		slot.custom_minimum_size = Vector2(250.0, 352.0)
		slot.size = Vector2(250.0, 352.0)
		gallery.add_child(slot)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = slot.size
		widget.size = slot.size
		slot.add_child(widget)
		var display: Dictionary = instance.call("_card_widget_display", card_id, instance.get("_combat_state"))
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	await _settle_ui()
	await _save_root_screenshot("%s/radiance_changed_cards_grouped_v4.png" % OUTPUT_DIR)
	gallery_layer.queue_free()
	await process_frame

func _capture_action_group_gallery(instance: Node) -> void:
	var combat := CombatEngine.new()
	var gallery_state: Dictionary = _radiance_visual_state(combat, [], [])
	var gallery_layer := CanvasLayer.new()
	gallery_layer.layer = 1000
	root.add_child(gallery_layer)
	var gallery := Control.new()
	gallery.set_anchors_preset(Control.PRESET_FULL_RECT)
	gallery.anchor_right = 1.0
	gallery.anchor_bottom = 1.0
	gallery_layer.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("16111d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	gallery.add_child(background)
	_add_gallery_title(gallery, "ONE ACTION · GROUPED CONTINUATION · NATIVE 250 × 352", 18.0)
	_add_gallery_title(gallery, "COMPACT 190 × 268 · SAME ACTION STRUCTURE", 494.0)
	var group_cards: Array = ["root_snare", "threaded_path", "squall_shot"]
	for index: int in range(group_cards.size()):
		_add_gallery_card(gallery, instance, gallery_state, group_cards[index], Vector2(350.0 + float(index) * 485.0, 76.0), Vector2(250.0, 352.0))
		_add_gallery_card(gallery, instance, gallery_state, group_cards[index], Vector2(450.0 + float(index) * 415.0, 542.0), Vector2(190.0, 268.0))
	await _settle_ui()
	await _save_root_screenshot("%s/card_action_continuation_groups_v4.png" % OUTPUT_DIR)
	gallery_layer.queue_free()
	await process_frame

func _capture_token_suffix_stress_gallery(instance: Node) -> void:
	var combat := CombatEngine.new()
	var stress_state: Dictionary = _radiance_visual_state(combat, ["duelist_whetstone"], [])
	stress_state["elemental_intensity"] = {
		"fire": 3,
		"ice": 0,
		"lightning": 0,
		"air": 0,
		"earth": 0
	}
	var gallery_layer := CanvasLayer.new()
	gallery_layer.layer = 1000
	root.add_child(gallery_layer)
	var gallery := Control.new()
	gallery.set_anchors_preset(Control.PRESET_FULL_RECT)
	gallery.anchor_right = 1.0
	gallery.anchor_bottom = 1.0
	gallery_layer.add_child(gallery)
	var background := ColorRect.new()
	background.color = Color("16111d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	gallery.add_child(background)
	_add_gallery_title(gallery, "ATTACHED VALUE SUFFIXES · NATIVE 250 × 352", 18.0)
	_add_gallery_title(gallery, "COMPACT 190 × 268 · SAME RULES, SAME FONT FLOORS", 494.0)
	var stress_cards: Array[String] = ["blood_price", "glowstone_ward", "sidestep_slash", "firebrand_volley", "storm_beacon"]
	for index: int in range(stress_cards.size()):
		_add_gallery_card(gallery, instance, stress_state, stress_cards[index], Vector2(115.0 + float(index) * 350.0, 76.0), Vector2(250.0, 352.0))
		_add_gallery_card(gallery, instance, stress_state, stress_cards[index], Vector2(350.0 + float(index) * 245.0, 542.0), Vector2(190.0, 268.0))
	await _settle_ui()
	await _save_root_screenshot("%s/card_value_suffix_contrast_v4.png" % OUTPUT_DIR)
	gallery_layer.queue_free()
	await process_frame

func _add_gallery_title(gallery: Control, text: String, y: float) -> void:
	var title := Label.new()
	title.text = text
	title.position = Vector2(42.0, y)
	title.size = Vector2(1836.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("f4dfb8"))
	gallery.add_child(title)

func _add_gallery_card(gallery: Control, instance: Node, combat_state: Dictionary, card_id: String, position: Vector2, card_size: Vector2) -> void:
	var slot := Control.new()
	slot.position = position
	slot.custom_minimum_size = card_size
	slot.size = card_size
	gallery.add_child(slot)
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = card_size
	widget.size = card_size
	slot.add_child(widget)
	var display: Dictionary = instance.call("_card_widget_display", card_id, combat_state)
	widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))

func _room_layout() -> Dictionary:
	var positions: Array[Vector2i] = _vector2i_array([
		Vector2i(3, 4),
		Vector2i(2, 2),
		Vector2i(4, 3),
		Vector2i(6, 4),
		Vector2i(7, 4),
		Vector2i(7, 3)
	])
	var enemy_types: Array[String] = ["warden", "harrier", "lightning_wisp", "acolyte", "crawler", "grave_surgeon"]
	var enemies: Array = []
	for index: int in range(positions.size()):
		var enemy_def: Dictionary = GameData.enemy_def(enemy_types[index])
		enemies.append({
			"id": index + 1,
			"type": enemy_types[index],
			"pos": positions[index],
			"hp": int(enemy_def.get("max_hp", 20)),
			"max_hp": int(enemy_def.get("max_hp", 20)),
			"block": 0
		})
	return {
		"name": "Umbra Visual Proof",
		"coord": Vector2i(21, 0),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": [{
			"kind": "equipment",
			"equipment_id": "iron_cleaver",
			"pos": Vector2i(6, 5)
		}]
	}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 8 else "stone")
		grid.append(row)
	return grid

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		result.append(value as Vector2i)
	return result

func _settle_ui() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != Vector2i(1920, 1080):
		# Native Metal exposes the Retina backing texture on macOS. Downsample the
		# real render to the single review resolution required by the UI rubric.
		image.resize(1920, 1080, Image.INTERPOLATE_LANCZOS)
	_assert(image.save_png(output_path) == OK, "Could not save %s" % output_path)

func _clear_probe_output(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
