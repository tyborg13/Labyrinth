extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const DEFAULT_OUTPUT_DIR: String = "user://probes/steam_deck_compat_v1"
const DEFAULT_PHYSICAL_SIZE := Vector2i(1280, 800)
const DEFAULT_LOGICAL_SIZE := Vector2i(1503, 939)
const PROGRESSION_PATH: String = "user://steam_deck_compat_progression.json"
const RUN_PATH: String = "user://steam_deck_compat_run.save"
const SETTINGS_PATH: String = "user://steam_deck_compat_settings.json"

var _viewport: SubViewport
var _router: Node
var _output_dir: String
var _physical_size: Vector2i
var _logical_size: Vector2i

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output_dir = _probe_output_dir()
	_physical_size = _probe_physical_size()
	_logical_size = _probe_logical_size()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	_clear_probe_output(ProjectSettings.globalize_path(_output_dir))
	InputRouterScript.ensure_input_map()
	_router = root.get_node_or_null("InputRouter")
	_require(_router != null, "Steam Deck probe requires the global input router")
	_build_handheld_viewport()
	await _capture_main_menu()
	await _capture_run_surfaces()
	_cleanup_storage()
	print(ProjectSettings.globalize_path(_output_dir))
	print("TEST RESULT: PASS")
	quit(0)

func _probe_output_dir() -> String:
	return DEFAULT_OUTPUT_DIR

func _probe_physical_size() -> Vector2i:
	return DEFAULT_PHYSICAL_SIZE

func _probe_logical_size() -> Vector2i:
	return DEFAULT_LOGICAL_SIZE

func _probe_requires_handheld_output() -> bool:
	return true

func _build_handheld_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.name = "SteamDeckViewport"
	_viewport.size = _physical_size
	_viewport.size_2d_override = _logical_size
	_viewport.size_2d_override_stretch = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)

func _capture_main_menu() -> void:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_require(packed != null, "Main menu should load for Steam Deck proof")
	var menu: Node = packed.instantiate()
	_viewport.add_child(menu)
	await _settle()
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	var navigation := InputEventJoypadButton.new()
	navigation.button_index = JOY_BUTTON_DPAD_DOWN
	navigation.pressed = true
	navigation.device = 0
	menu.call("_input", navigation)
	await _settle()
	var start_button: Button = menu.get_node("MenuColumn/StartButton")
	_require(start_button.has_focus(), "First controller navigation should focus the safe default main-menu action")
	_assert_prompt_bar(menu.get("_controller_prompt_bar") as Control, "Main menu")
	_assert_focus_visible(start_button, "Main-menu controller focus")
	await _save_screenshot("main_menu_steam_deck.png")

	_router.call("force_family_for_test", InputRouterScript.FAMILY_XBOX)
	await _settle()
	var glyphs: Array[Node] = menu.find_children("*", "InputGlyph", true, false)
	_require(not glyphs.is_empty(), "Main menu should render controller glyphs")
	for glyph_node: Node in glyphs:
		_require(str(glyph_node.get("family")) == InputRouterScript.FAMILY_XBOX, "Controller prompts should refresh to Xbox glyphs without reopening the screen")
	await _save_screenshot("main_menu_xbox.png")
	var music_player: AudioStreamPlayer = menu.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player != null:
		music_player.stop()
		music_player.stream = null
	menu.queue_free()
	await _settle()

func _capture_run_surfaces() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_require(packed != null, "Run scene should load for Steam Deck proof")
	var instance: Node = packed.instantiate()
	_viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var run_engine = RunEngineScript.new()
	var base_state: Dictionary = run_engine.create_new_run(127800, ProgressionStore.default_data())
	instance.call("_load_run_state", base_state)
	await _settle()
	instance.call("_close_dialogue")
	await _load_combat_fixture(instance)
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_controller_cycle_hand", 1)
	await _settle()
	_require(int(instance.get("_hovered_card_index")) == int(instance.get("_controller_hand_index")), "Controller hand navigation should use the card's authored hover/focus treatment")
	_require(instance.find_child("ControllerGridCursor", true, false) == null, "Controller card focus should not add a debug-style rectangular overlay")
	_assert_forged_cursor_hidden_for_controller()
	_assert_prompt_bar(instance.get("_controller_prompt_bar") as Control, "Combat hand")
	_assert_key_handheld_text_floor(instance)
	_require(bool(instance.get("_controller_hand_focused")), "Controller combat should open with the readable focused hand")
	var controller_board: Control = instance.get("board_view") as Control
	var controller_expansion: float = float(controller_board.call("_controller_viewport_expansion"))
	var expected_expansion: float = 0.0 if _physical_size.y <= 800 else 1.0
	_require(
		is_equal_approx(controller_expansion, expected_expansion),
		"Controller framing should use the physical output envelope (physical=%s viewport_size=%s viewport_rect=%s expansion=%.3f expected=%.1f)" % [
			_physical_size,
			controller_board.get_viewport().size,
			controller_board.get_viewport_rect().size,
			controller_expansion,
			expected_expansion,
		]
	)
	var focused_board_position: Vector2 = controller_board.position
	var focused_board_size: Vector2 = controller_board.size
	await _assert_controller_layout_survives_animation_lock(instance, "Focused controller hand")
	await _save_screenshot("combat_hand_focus.png")
	await _press_controller_button(JOY_BUTTON_X)
	_require(str(instance.get("_controller_region")) == "board" and not bool(instance.get("_controller_hand_focused")), "X should be the sole hand-unfocus action and enter unobstructed board navigation")
	await _press_controller_button(JOY_BUTTON_X)
	_require(str(instance.get("_controller_region")) == "hand" and bool(instance.get("_controller_hand_focused")), "X from the board should focus the hand and immediately restore card selection")
	_require(int(instance.get("_hovered_card_index")) == int(instance.get("_controller_hand_index")), "Focusing the hand with X should immediately emphasize its selected card")

	instance.call("_controller_enter_board", true)
	await _settle()
	_require(str(instance.get("_controller_region")) == "board", "Up from the hand should enter board navigation")
	_require(not bool(instance.get("_controller_hand_focused")), "Entering board targeting should automatically tuck the hand")
	var hand_scroll: ScrollContainer = instance.get("hand_scroll") as ScrollContainer
	_assert_controller_board_envelope(controller_board, instance)
	_require(hand_scroll != null and hand_scroll.visible and not hand_scroll.clip_contents, "Unfocused hand should tuck card bodies below the screen without clipping their crowns at the dock edge")
	_require(int(instance.get("_hovered_card_index")) < 0, "Unfocusing the hand should clear stale card hover ownership")
	var card_tooltips: Control = instance.get("_card_focus_tooltip_stack") as Control
	_require(card_tooltips == null or not card_tooltips.visible, "Unfocusing the hand should hide stale card tooltips")
	_require(
		controller_board.position.is_equal_approx(focused_board_position)
		and controller_board.size.is_equal_approx(focused_board_size),
		"Focusing or tucking the controller hand must not move or resize the board viewport"
	)
	await _assert_controller_layout_survives_animation_lock(instance, "Tucked controller hand")
	await _press_controller_button(JOY_BUTTON_B)
	var menu_scrim: Control = instance.get("_menu_scrim") as Control
	_require(menu_scrim == null or not menu_scrim.visible, "B on an unobstructed controller board should never open the pause menu")
	var right_click := InputEventMouseButton.new()
	right_click.button_index = MOUSE_BUTTON_RIGHT
	right_click.pressed = true
	controller_board.call("_gui_input", right_click)
	await _settle()
	menu_scrim = instance.get("_menu_scrim") as Control
	_require(menu_scrim == null or not menu_scrim.visible, "A contextual board right-click with nothing to cancel should never open the pause menu")
	var board_start_tile: Vector2i = instance.get("_controller_board_tile")
	var board_right_tile: Vector2i = _sweep_controller_cursor_to_new_tile(instance, Vector2.RIGHT, board_start_tile)
	_require(board_right_tile != board_start_tile, "A horizontal stick sweep should move the free board cursor in screen space")
	var board_down_tile: Vector2i = _sweep_controller_cursor_to_new_tile(instance, Vector2.DOWN, board_right_tile)
	_require(str(instance.get("_controller_region")) == "board" and not bool(instance.get("_controller_hand_focused")), "Board-stick movement should never resurrect an unfocused hand")
	_require(board_down_tile != board_right_tile, "A vertical stick sweep should independently move the free board cursor across the isometric board")
	instance.set("_hovered_board_tile", Vector2i(-999999, -999999))
	instance.call("_controller_set_board_tile", board_down_tile, false)
	_require(instance.get("_hovered_board_tile") == Vector2i(-999999, -999999), "A held cursor that remains snapped to one tile should not repeat hover or stage-refresh work every physics tick")
	instance.set("_controller_stick", Vector2.ZERO)
	instance.call("_controller_process_board_cursor", 0.0)
	_assert_board_cursor_center(instance)
	var equipment_tile := Vector2i(4, 3)
	var equipment_trigger: String = str(controller_board.call("controller_tooltip_for_tile", equipment_tile))
	_require(equipment_trigger.begins_with("equipment:"), "Board equipment should expose its rich tooltip trigger to pointer and controller inspection")
	var equipment_loot: Dictionary = ((instance.get("_combat_state") as Dictionary).get("loot", []) as Array)[0] as Dictionary
	var equipment_texture: Texture2D = controller_board.call("_loot_texture", equipment_loot) as Texture2D
	var equipment_rect: Rect2 = controller_board.call("_loot_rect_for_tile", equipment_tile, equipment_texture, equipment_loot) as Rect2
	_require(
		str(controller_board.call("_get_tooltip", equipment_rect.get_center())).begins_with("equipment:"),
		"Pointer hover over the live equipment pickup rect should expose its tooltip without requiring a retained-layer redraw"
	)
	var equipment_candidate: Dictionary = instance.call("_controller_candidate_for_tile", equipment_tile) as Dictionary
	_require(str(equipment_candidate.get("kind", "")) == "equipment", "The free controller cursor should identify an equipment pickup as equipment")
	_require(str(equipment_candidate.get("detail", "")).contains("Adds"), "Focused board equipment should explain the cards it adds without opening Character")
	instance.call("_controller_set_board_tile", equipment_tile)
	await _settle()
	await _save_screenshot("combat_equipment_pickup_tooltip.png")
	await _save_screenshot("combat_board_cursor.png")

	instance.call("_controller_set_hand_focused", false)
	await _settle()
	_require(not bool(instance.get("_controller_hand_focused")), "The X action should unfocus the card hand")
	_require(hand_scroll != null and hand_scroll.visible, "Unfocused-hand mode should never remove the selected card reminder")
	_assert_board_cursor_center(instance)
	await _save_screenshot("combat_hand_unfocused.png")

	instance.call("_controller_set_hand_focused", true)
	await _exercise_controller_combat_events(instance)
	instance.call("_open_menu_overlay")
	instance.call("_recover_controller_focus")
	await _settle()
	var modal_cursor: Control = instance.get("_controller_analog_cursor") as Control
	_require(modal_cursor != null and not modal_cursor.visible, "Opening a controller modal should immediately hide the analog cursor and its stale detail")
	_assert_focus_inside(instance.get("_menu_scrim") as Control, "Pause menu")
	_assert_prompt_above_modal(instance, instance.get("_menu_scrim") as Control, "Pause menu")
	await _save_screenshot("pause_controller_focus.png")
	instance.call("_close_menu_overlay")
	await _settle()

	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_refresh_controller_interface")
	instance.call("_open_large_map")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_large_map_scrim") as Control, "Large map")
	_assert_prompt_above_modal(instance, instance.get("_large_map_scrim") as Control, "Large map")
	var map_view: Control = instance.get("_large_map_view") as Control
	_require(map_view != null and map_view.has_focus(), "Controller map opening should focus the room-node canvas rather than Close")
	var map_hint: Label = instance.get("_large_map_navigation_hint") as Label
	_require(map_hint != null and not map_hint.visible, "Controller map should hide redundant mouse and touch instructions")
	var zoom_before: float = float(map_view.call("_camera_zoom_value"))
	var zoom_event := InputEventJoypadMotion.new()
	zoom_event.axis = JOY_AXIS_TRIGGER_RIGHT
	zoom_event.axis_value = 0.78
	map_view.call("_gui_input", zoom_event)
	map_view.call("_process_controller_zoom", 0.24)
	var first_zoom: float = float(map_view.call("_camera_zoom_value"))
	map_view.call("_process_controller_zoom", 0.24)
	_require(first_zoom > zoom_before and float(map_view.call("_camera_zoom_value")) > first_zoom, "Holding the right trigger should smoothly continue zooming the controller map")
	zoom_event.axis_value = 0.0
	map_view.call("_gui_input", zoom_event)
	var map_coord_before: Vector2i = map_view.get("_hover_coord")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		map_view.set("_controller_stick", direction)
		map_view.call("_process_controller_cursor", 0.24)
		if map_view.get("_hover_coord") != map_coord_before:
			break
	map_view.set("_controller_stick", Vector2.ZERO)
	_require(map_view.get("_hover_coord") != map_coord_before, "Map analog navigation should move a free screen cursor and snap to another visible room node")
	await _save_screenshot("map_controller_focus.png")
	instance.call("_close_large_map")
	await _settle()

	instance.call("_open_character_overlay", "equipment")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_upgrade_scrim") as Control, "Character gear")
	_assert_prompt_above_modal(instance, instance.get("_upgrade_scrim") as Control, "Character gear")
	await _save_screenshot("character_gear_controller_focus.png")
	await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _settle()
	_require(str(instance.get("_progression_overlay_mode")) == "magic", "Right shoulder should switch Character from Gear to Magic")
	_assert_focus_inside(instance.get("_upgrade_scrim") as Control, "Character magic")
	await _save_screenshot("character_magic_controller_focus.png")
	await _press_controller_button(JOY_BUTTON_LEFT_SHOULDER)
	await _settle()
	_require(str(instance.get("_progression_overlay_mode")) == "equipment", "Left shoulder should return Character from Magic to Gear")
	instance.call("_close_card_upgrade_overlay")
	await _settle()

	instance.call("_open_grimoire_overlay")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_grimoire_scrim") as Control, "Grimoire")
	_assert_prompt_above_modal(instance, instance.get("_grimoire_scrim") as Control, "Grimoire")
	await _save_screenshot("grimoire_controller_focus.png")
	instance.call("_close_grimoire_overlay")
	await _settle()

	await _exercise_controller_merchant(instance, run_engine, base_state)
	await _exercise_controller_loadout(instance, base_state)
	var room_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, room_state)
	_require(combat_coord != Vector2i(999, 999), "Steam Deck proof needs an available combat room")
	instance.call("_controller_clear_focus_candidate")
	instance.set("_controller_virtual_board_position", Vector2.INF)
	instance.call("_refresh_controller_interface")
	_require((instance.get("_controller_focus_candidate") as Dictionary).is_empty(), "Room navigation should start with a genuinely free cursor and no implicit door target")
	_require(instance.get("_controller_board_tile") == Vector2i(-1, -1), "Room navigation should not assign the first door before the cursor reaches one")
	var room_coord_before_accept: Vector2i = (instance.get("_run_state") as Dictionary).get("current_room", Vector2i(-1, -1))
	await instance.call("_controller_activate_current")
	_require((instance.get("_run_state") as Dictionary).get("current_room", Vector2i(-2, -2)) == room_coord_before_accept, "A in free room space should not open any door")
	var exits: Dictionary = instance.get("_exit_destinations_by_tile") as Dictionary
	var combat_door: Vector2i = Vector2i(-1, -1)
	for tile_var: Variant in exits.keys():
		if exits[tile_var] == combat_coord:
			combat_door = tile_var as Vector2i
			break
	_require(combat_door.x >= 0, "Room controller navigation should expose the combat route as a board door")
	instance.call("_controller_set_board_tile", combat_door)
	var loadout_control: Control = instance.get("loadout_button") as Control
	var loadout_candidate: Dictionary = instance.call("_controller_candidate_for_control", loadout_control) as Dictionary
	instance.call("_controller_set_focus_candidate", loadout_candidate, true)
	await instance.call("_controller_activate_current")
	await _settle()
	_require((instance.get("_upgrade_scrim") as Control).visible, "A on the Character button during room navigation should open Character, not a focused door")
	_require((instance.get("_run_state") as Dictionary).get("current_room", Vector2i(-2, -2)) == room_coord_before_accept, "Opening Character from room navigation must not travel through the previously focused door")
	instance.call("_close_card_upgrade_overlay")
	await _settle()
	instance.call("_controller_set_board_tile", combat_door)
	_assert_board_cursor_center(instance)
	_assert_prompt_bar(instance.get("_controller_prompt_bar") as Control, "Room door navigation")
	await _save_screenshot("room_door_cursor.png")
	await instance.call("_controller_activate_current")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_pre_battle_scrim") as Control, "Pre-battle")
	_assert_control_inside_logical_viewport(instance.get("_pre_battle_panel") as Control, "Pre-battle panel", 16.0)
	var pre_battle_prompts: Array = (instance.get("_controller_prompt_bar") as Control).call("prompts_snapshot")
	for prompt_var: Variant in pre_battle_prompts:
		_require(str((prompt_var as Dictionary).get("action", "")) != str(InputRouterScript.ACTION_CANCEL), "Committed pre-battle should not advertise a cancel action that cannot return to the previous room")
	await _save_screenshot("pre_battle_controller_focus.png")

	var reward_state: Dictionary = base_state.duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngineScript.REWARD_HEAL,
		"ember_amount": 0,
	}
	instance.call("_load_run_state", reward_state)
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_relic_choice_overlay") as Control, "Card reward")
	await _save_screenshot("reward_controller_focus.png")

	instance.queue_free()
	await _settle()

func _exercise_controller_combat_events(instance: Node) -> void:
	# A GUI probe runs beside the host Mac pointer. Keep incidental host-mouse
	# jitter from changing modality during long authored action waits; explicit
	# pointer/controller handoff cases below still call set_modality directly.
	_router.set("_last_controller_activity_msec", Time.get_ticks_msec() + 60000)
	await _load_combat_fixture(instance)
	instance.set("_controller_region", "hand")
	instance.set("_controller_hand_index", 0)
	instance.call("_refresh_controller_interface")
	instance.set("_controller_stick", Vector2(0.82, 0.0))
	instance.call("_physics_process", 0.016)
	_require(int(instance.get("_controller_hand_index")) == 1, "A fresh stick push should advance exactly one card")
	instance.set("_controller_stick", Vector2(0.82, 0.58))
	instance.call("_physics_process", 0.016)
	_require(int(instance.get("_controller_hand_index")) == 1, "The second axis event from one angled push should not skip another card")
	instance.set("_controller_stick", Vector2.ZERO)
	instance.call("_controller_reset_stick_repeat")
	instance.call("_controller_set_hand_index", 0)
	await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	_require(int(instance.get("_controller_hand_index")) == 1, "A routed shoulder event should advance hand focus")
	await _press_controller_button(JOY_BUTTON_LEFT_SHOULDER)
	_require(int(instance.get("_controller_hand_index")) == 0, "The opposite shoulder should return hand focus to the first card")
	await _press_controller_button(JOY_BUTTON_A)
	_require(str(instance.get("_controller_region")) == "card_mode", "A routed confirm event should enter the card's Printed/Attack/Move selector")
	_require(int(instance.get("_card_action_choice_index")) == 0, "Controller card selection should preserve the chosen hand index")
	await _save_screenshot("combat_card_mode_focus.png")
	var selector: Control = instance.get("_card_action_mode_selector") as Control
	for option_var: Variant in selector.get_children() if selector != null else []:
		var option: Button = option_var as Button
		if option != null:
			_require(option.get_theme_stylebox("focus") is StyleBoxEmpty, "Card modes should never use the old debug focus rectangle")
	var controller_board: Control = instance.get("board_view") as Control
	var controller_navigation_snapshot: Dictionary = controller_board.call("navigation_snapshot") if controller_board != null else {}
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_refresh_controller_interface")
	await _settle()
	_require(instance.find_child("ControllerGridCursor", true, false) == null, "Mouse and keyboard card choice should remain free of controller-only frames")
	_assert_pointer_board_rect_restored(instance, controller_navigation_snapshot)
	await _save_screenshot("combat_card_mode_pointer.png")
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_refresh_controller_interface")
	await _settle()
	var initial_mode: String = str(instance.get("_controller_card_mode"))
	await _press_controller_button(JOY_BUTTON_DPAD_DOWN)
	var fallback_mode: String = str(instance.get("_controller_card_mode"))
	_require(fallback_mode != initial_mode, "D-pad should move between playable card modes")
	await _press_controller_button(JOY_BUTTON_A)
	_require(str(instance.get("_controller_region")) == "board", "A on a card mode should enter snapped board targeting")
	_require(str(instance.get("_card_action_choice_mode")) == fallback_mode, "The focused fallback mode should become the active card action")
	_require(not bool(instance.get("_controller_hand_focused")), "Entering card targeting should automatically tuck the hand out of the board's way")
	_require(int(instance.get("_selected_card_index")) == 0, "The tucked targeting hand should retain the selected card as a memory cue")
	var targeting_hand_scroll: ScrollContainer = instance.get("hand_scroll") as ScrollContainer
	_require(
		targeting_hand_scroll != null and targeting_hand_scroll.visible and not targeting_hand_scroll.clip_contents,
		"Targeting should keep the selected card crown visible while tucking its body below the screen"
	)
	await _save_screenshot("combat_targeting_tucked_hand.png")
	await _press_controller_button(JOY_BUTTON_B)
	_require(str(instance.get("_controller_region")) == "card_mode", "B from card targeting should return to mode selection before cancelling the card")
	await _press_controller_button(JOY_BUTTON_B)
	_require(str(instance.get("_controller_region")) == "hand" and int(instance.get("_selected_card_index")) < 0, "B from mode selection should cancel back to the hand")

	await _load_combat_fixture(instance)
	instance.set("_controller_region", "hand")
	instance.set("_controller_hand_index", 4)
	var fallback_only_options: Dictionary = (instance.call("_card_play_options_for_index", 4) as Dictionary).duplicate(false)
	_require(bool(fallback_only_options.get("attack_playable", false)) and bool(fallback_only_options.get("move_playable", false)), "Fallback-only regression setup requires legal Attack and Move options")
	# Model the reachable selector shape directly: Printed is disabled while more
	# than one fallback is legal. Core combat legality is already exercised above;
	# this isolates controller normalization from any one card's evolving rules.
	fallback_only_options["play"] = {"playable": false}
	fallback_only_options["printed_playable"] = false
	instance.call("_show_card_action_choices", 4, fallback_only_options)
	instance.call("_refresh_ui")
	instance.call("_controller_enter_card_mode")
	await _settle()
	var fallback_only_modes: Array = instance.call("_controller_available_card_modes")
	var fallback_only_mode: String = str(instance.get("_controller_card_mode"))
	_require(not fallback_only_modes.has("play") and fallback_only_modes.size() >= 2, "Fallback-only controller setup should expose multiple modes without Printed")
	_require(fallback_only_modes.has(fallback_only_mode), "Controller card-mode entry should normalize an unavailable Printed default to a playable fallback")
	var fallback_focus: Control = _viewport.gui_get_focus_owner()
	_require(fallback_focus != null and str(fallback_focus.get_meta("play_kind", "")) == fallback_only_mode, "Fallback-only mode entry should visibly focus the normalized playable placard")
	await _press_controller_button(JOY_BUTTON_A)
	_require(str(instance.get("_controller_region")) == "board", "A should activate the normalized fallback mode instead of exiting to the hand")
	await _press_controller_button(JOY_BUTTON_B)
	await _press_controller_button(JOY_BUTTON_B)

	await _load_combat_fixture(instance)
	instance.set("_controller_region", "hand")
	instance.set("_controller_hand_index", 0)
	instance.call("_refresh_controller_interface")
	for _step: int in range(3):
		await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	_require(int(instance.get("_controller_hand_index")) == 3, "Routed shoulder events should reach Guarded Step for optional-step coverage")
	await _press_controller_button(JOY_BUTTON_A)
	await _press_controller_button(JOY_BUTTON_A)
	_require(str(instance.get("_controller_region")) == "board" and bool(instance.call("_current_action_can_skip")), "Guarded Step should expose its optional movement step through controller targeting")
	var cards_played_before: int = int((instance.get("_combat_state") as Dictionary).get("cards_played_this_turn", 0))
	var player_before_skip: Dictionary = ((instance.get("_combat_state") as Dictionary).get("player", {}) as Dictionary).duplicate(true)
	var animated_board: Control = instance.get("board_view") as Control
	var animated_board_position: Vector2 = animated_board.position
	var animated_board_size: Vector2 = animated_board.size
	await _press_controller_button(JOY_BUTTON_Y)
	await _wait_for_combat_animation(instance)
	var combat_after_skip: Dictionary = instance.get("_combat_state") as Dictionary
	_require(int(combat_after_skip.get("cards_played_this_turn", 0)) > cards_played_before, "Y should skip the optional action and finish the card instead of passing the turn")
	var player_after_skip: Dictionary = combat_after_skip.get("player", {}) as Dictionary
	_require(player_after_skip.get("pos", Vector2i(-1, -1)) == player_before_skip.get("pos", Vector2i(-2, -2)), "Skipping Guarded Step's optional movement should leave the player on the original tile")
	_require(int(player_after_skip.get("block", 0)) > int(player_before_skip.get("block", 0)), "Skipping movement should still resolve Guarded Step's automatic block effect")
	_require(str((combat_after_skip.get("current_actor", {}) as Dictionary).get("kind", "")) == "player", "Skipping a card step must not end the player's turn")
	_require(str(instance.get("_controller_region")) == "hand", "Completing a card through Skip should return controller focus to the remaining hand")
	_require(
		animated_board.position.is_equal_approx(animated_board_position) and animated_board.size.is_equal_approx(animated_board_size),
		"Player action animation renders must preserve the fixed controller board framing (before pos=%s size=%s, after pos=%s size=%s, modality=%s, region=%s, hand_focused=%s)" % [
			animated_board_position,
			animated_board_size,
			animated_board.position,
			animated_board.size,
			_router.call("modality"),
			instance.get("_controller_region"),
			instance.get("_controller_hand_focused"),
		]
	)
	var animation_presentation: Dictionary = animated_board.get("presentation") as Dictionary
	_require(bool(animation_presentation.get("controller_combat_navigation", false)), "Animation board submissions should retain the controller combat framing flag (modality=%s, presentation=%s)" % [_router.call("modality"), animation_presentation.get("controller_combat_navigation", null)])

	await _load_combat_fixture(instance)
	instance.set("_controller_region", "hand")
	instance.set("_controller_hand_index", 0)
	instance.call("_refresh_controller_interface")
	await _settle()
	instance.call("_controller_enter_board", true)
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var enemies: Array = combat_state.get("enemies", []) as Array
	_require(not enemies.is_empty(), "Controller enemy-intent proof requires a visible enemy")
	if not enemies.is_empty():
		var enemy_tile: Vector2i = (enemies[0] as Dictionary).get("pos", Vector2i(-1, -1))
		instance.call("_controller_set_board_tile", enemy_tile)
		await _settle()
		# Reassert after deferred board/hand layout work. In live play the physics
		# cursor does this continuously; the probe drives the private seam directly.
		instance.call("_controller_set_board_tile", enemy_tile)
		await process_frame
		var board: Control = instance.get("board_view") as Control
		var focused_enemy: Dictionary = {}
		for unit_var: Variant in board.call("_visible_units") as Array:
			if typeof(unit_var) == TYPE_DICTIONARY and str((unit_var as Dictionary).get("role", "")) == "enemy" and (unit_var as Dictionary).get("pos", Vector2i(-2, -2)) == enemy_tile:
				focused_enemy = unit_var as Dictionary
				break
		_require(not focused_enemy.is_empty(), "Focused enemy tile should resolve to the rendered enemy unit")
		if not focused_enemy.is_empty():
			var intent: Dictionary = focused_enemy.get("intent", {}) as Dictionary
			_require(
				bool(board.call("_enemy_intent_expanded", focused_enemy)),
				"Controller focus should expand the enemy's full intent HUD (enemy %s, board focus %s, scene tile %s)" % [
					enemy_tile,
					board.get("_controller_focus_tile"),
					instance.get("_controller_board_tile"),
				]
			)
			_require(not (board.call("_enemy_intent_rows_for_display", focused_enemy, intent) as Array).is_empty(), "Expanded controller intent should include named action/value rows")
		await _save_screenshot("combat_enemy_intent_controller.png")

	var menu_control: Control = instance.get("menu_button") as Control
	var menu_candidate: Dictionary = instance.call("_controller_candidate_for_control", menu_control) as Dictionary
	_require(not menu_candidate.is_empty(), "The analog board cursor should be able to target the corner menu button")
	if not menu_candidate.is_empty():
		instance.call("_controller_set_focus_candidate", menu_candidate, true)
		await _settle()
		_require(instance.get("_controller_board_tile") == Vector2i(-1, -1), "Moving the free cursor to a header control should leave board-tile focus")
		_require(_viewport.gui_get_focus_owner() == menu_control, "The cursor should give actual controller focus to the hovered menu button")
		_require(instance.get("_hovered_board_tile") == Vector2i(-1, -1), "Moving the cursor to header chrome should clear the prior board hover")
		_require(not bool(instance.get("_board_hover_threat_active")), "Header focus should clear the prior enemy threat-preview state")
		var header_board: Control = instance.get("board_view") as Control
		var header_presentation: Dictionary = header_board.get("presentation") as Dictionary
		_require((header_presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Header focus should not retain the enemy's projected movement or actions")
		var header_prompt_labels: Array[String] = []
		for prompt: Dictionary in (instance.get("_controller_prompt_bar") as Control).call("prompts_snapshot") as Array[Dictionary]:
			header_prompt_labels.append(str(prompt.get("label", "")))
		_require(header_prompt_labels.has("Open"), "An actionable header target should advertise A / Open; got %s for %s (base=%s disabled=%s)" % [header_prompt_labels, instance.get("_controller_focus_candidate"), menu_control is BaseButton, menu_control.disabled])
		var cursor: Control = instance.get("_controller_analog_cursor") as Control
		var detail_panel: Control = cursor.get_node_or_null("ControllerCursorDetail") as Control
		var cursor_detail_text: String = str((cursor.call("cursor_snapshot") as Dictionary).get("detail_text", ""))
		if not cursor_detail_text.is_empty():
			_require(detail_panel != null and bool(detail_panel.get_meta("tooltip_surface", false)), "Header cursor detail should reuse the shared game tooltip presentation")
		await _save_screenshot("combat_header_cursor.png")

	await _load_combat_fixture(instance)
	instance.set("_controller_region", "hand")
	instance.call("_controller_set_hand_focused", true)
	# Async GDScript executes synchronously until its first await, so this checks
	# the presentation state at the exact moment the enemy phase begins.
	instance.call("_on_pass_turn_pressed")
	_require(str(instance.get("_controller_region")) == "board" and not bool(instance.get("_controller_hand_focused")), "Pass should tuck the controller hand before the first enemy action frame")
	await _wait_for_combat_animation(instance)
	_require(not bool(instance.get("_controller_hand_focused")), "Pass should leave the hand tucked when control returns to the player")

func _exercise_controller_merchant(instance: Node, run_engine, restore_state: Dictionary) -> void:
	var merchant_state: Dictionary = _blacksmith_controller_state(run_engine)
	_require(not merchant_state.is_empty(), "Controller proof should find a deterministic blacksmith room")
	instance.call("_load_run_state", merchant_state)
	instance.call("_close_dialogue")
	await _settle()
	instance.call("_recover_controller_focus")
	await _settle()
	_require(not bool(instance.call("_controller_custom_room_available")), "An open merchant should use GUI focus rather than intercepting input for room doors")
	_assert_focus_inside(instance.get("_relic_choice_overlay") as Control, "Merchant shop")
	var buy_button: Button = _visible_button_with_text(instance, "Buy")
	_require(buy_button != null and not buy_button.disabled, "Merchant controller proof should expose an affordable Buy action")
	buy_button.grab_focus()
	await _save_screenshot("merchant_controller_focus.png")
	var embers_before: int = int((instance.get("_run_state") as Dictionary).get("held_embers", 0))
	await _press_controller_button(JOY_BUTTON_A)
	await create_timer(0.55).timeout
	var embers_after: int = int((instance.get("_run_state") as Dictionary).get("held_embers", 0))
	_require(embers_after < embers_before, "A on a focused merchant Buy button should complete a controller trade")
	await _press_controller_button(JOY_BUTTON_B)
	_require(not bool(instance.get("_merchant_shop_open")) and bool(instance.call("_controller_custom_room_available")), "B should hide the merchant and restore controller door navigation")
	await _press_controller_button(JOY_BUTTON_X)
	_require(bool(instance.get("_merchant_shop_open")), "X should reopen a hidden merchant shop without requiring a pointer")
	instance.call("_load_run_state", restore_state)
	instance.call("_close_dialogue")
	await _settle()

func _blacksmith_controller_state(run_engine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 600)
	for seed: int in range(1, 90):
		var state: Dictionary = run_engine.create_new_run(seed, progression)
		var coord: Vector2i = _first_room_coord_of_type(run_engine, state, "blacksmith")
		if coord.x >= 900:
			continue
		var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = true
		var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
		rooms[_coord_key(coord)] = room
		state["rooms"] = rooms
		state["current_room"] = coord
		state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
		state["mode"] = "room"
		state["combat_state"] = {}
		state["held_embers"] = 600
		state["unbanked_embers"] = 600
		state["equipment_inventory"] = ["ward_kite"]
		var collected: Array = (state.get("collected_equipment", []) as Array).duplicate()
		if not collected.has("ward_kite"):
			collected.append("ward_kite")
		state["collected_equipment"] = collected
		return state
	return {}

func _first_room_coord_of_type(run_engine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, RunEngineScript.MAX_DEPTH + 1):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) == radius and str(run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i(999, 999)

func _coord_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _visible_button_with_text(root_node: Node, text: String) -> Button:
	for child: Node in root_node.find_children("*", "Button", true, false):
		var button: Button = child as Button
		if button != null and button.text == text and button.is_visible_in_tree():
			return button
	return null

func _exercise_controller_loadout(instance: Node, base_state: Dictionary) -> void:
	var state: Dictionary = base_state.duplicate(true)
	var equipment_inventory: Array = (state.get("equipment_inventory", []) as Array).duplicate()
	if not equipment_inventory.has("iron_cleaver"):
		equipment_inventory.append("iron_cleaver")
	state["equipment_inventory"] = equipment_inventory
	var collected_equipment: Array = (state.get("collected_equipment", []) as Array).duplicate()
	if not collected_equipment.has("iron_cleaver"):
		collected_equipment.append("iron_cleaver")
	state["collected_equipment"] = collected_equipment
	var item_inventory: Array = (state.get("item_inventory", []) as Array).duplicate()
	if not item_inventory.has("mossglass_elixir"):
		item_inventory.append("mossglass_elixir")
	state["item_inventory"] = item_inventory
	var magic_inventory: Array = (state.get("magic_inventory", []) as Array).duplicate()
	if not magic_inventory.has("bone_dart"):
		magic_inventory.append("bone_dart")
	state["magic_inventory"] = magic_inventory
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()

	instance.call("_open_character_overlay", "equipment")
	await _settle()
	var gear_tiles: Dictionary = instance.get("_equipment_inventory_tiles") as Dictionary
	var gear_slots: Dictionary = instance.get("_equipment_slot_panels") as Dictionary
	var initial_gear_focus: Control = _viewport.gui_get_focus_owner()
	_require(
		gear_slots.values().has(initial_gear_focus) or gear_tiles.values().has(initial_gear_focus),
		"Opening Character with a controller should immediately focus a meaningful gear tile instead of the Close button"
	)
	var gear_tile: Control = gear_tiles.get("iron_cleaver") as Control
	_require(gear_tile != null and gear_tile.focus_mode == Control.FOCUS_ALL, "Spare gear should be controller-focusable outside combat")
	gear_tile.grab_focus()
	await _settle()
	var gear_tooltip: Control = instance.get("_controller_loadout_tooltip") as Control
	_require(gear_tooltip != null and gear_tooltip.visible, "Focused gear should reveal its full controller mechanics tooltip")
	await _save_screenshot("character_room_loadout_focus.png")
	gear_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.35).timeout
	var equipped: Dictionary = (instance.get("_run_state") as Dictionary).get("equipped_equipment", {}) as Dictionary
	_require(str(equipped.get("weapon", "")) == "iron_cleaver", "A on spare gear should equip it with no pointer drag")

	var current_items: Array = (instance.get("_run_state") as Dictionary).get("item_inventory", []) as Array
	var item_index: int = current_items.find("mossglass_elixir")
	_require(item_index >= 0, "Controller loadout fixture should retain its consumable")
	var item_tiles: Dictionary = instance.get("_item_inventory_tiles") as Dictionary
	var item_tile: Control = item_tiles.get(item_index) as Control
	_require(item_tile != null and item_tile.focus_mode == Control.FOCUS_ALL, "Consumables should be controller-focusable")
	item_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.25).timeout
	var equipped_items: Array = (instance.get("_run_state") as Dictionary).get("equipped_items", []) as Array
	_require(equipped_items.has("mossglass_elixir"), "A on a consumable should equip it with no pointer drag")

	instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	var reserve: Array = (instance.get("_run_state") as Dictionary).get("magic_inventory", []) as Array
	var reserve_index: int = reserve.find("bone_dart")
	_require(reserve_index >= 0, "Controller magic fixture should retain its reserve spell")
	var reserve_tiles: Dictionary = instance.get("_magic_inventory_tiles") as Dictionary
	var reserve_tile: Control = reserve_tiles.get(reserve_index) as Control
	var attuned_tiles: Dictionary = instance.get("_magic_attuned_tiles") as Dictionary
	var attuned_tile: Control = attuned_tiles.get(0) as Control
	var initial_magic_focus: Control = _viewport.gui_get_focus_owner()
	_require(
		attuned_tiles.values().has(initial_magic_focus) or reserve_tiles.values().has(initial_magic_focus),
		"Switching to Magic with a controller should immediately focus a spell tile instead of an unrelated control"
	)
	_require(reserve_tile != null and attuned_tile != null, "Magic swap should expose both controller endpoints")
	reserve_tile.grab_focus()
	# Establish the pre-handoff inspection deterministically even if a deferred
	# modal focus recovery from rebuilding this tab lands in the same frame.
	instance.call("_restore_controller_loadout_tooltip_for_focus_owner")
	await _settle()
	_require(reserve_tile.has_focus(), "Magic tooltip handoff proof requires the reserve spell to own focus")
	var magic_tooltip: Control = instance.get("_controller_loadout_tooltip") as Control
	_require(magic_tooltip != null and magic_tooltip.visible, "Focused magic should reveal its full card mechanics tooltip")
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_STEAM_DECK)
	await _settle()
	_require(instance.get("_controller_loadout_tooltip") == null, "Switching to pointer modality should clear controller-only loadout tooltips")
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	await _settle()
	magic_tooltip = instance.get("_controller_loadout_tooltip") as Control
	_require(reserve_tile.has_focus(), "Pointer/controller handoff should preserve the already-focused magic tile")
	_require(magic_tooltip != null and magic_tooltip.visible, "Returning to controller modality should restore the focused magic mechanics tooltip without extra navigation")
	reserve_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	_require(str(instance.get("_controller_magic_source_kind")) == "inventory", "First A should hold the reserve spell for a two-step swap")
	var swap_prompt_labels: Array[String] = []
	for prompt: Dictionary in (instance.get("_controller_prompt_bar") as Control).call("prompts_snapshot") as Array[Dictionary]:
		swap_prompt_labels.append(str(prompt.get("label", "")))
	_require(
		swap_prompt_labels == ["Swap", "Cancel Swap", "Choose Slot"],
		"Selected magic should advertise Swap / Cancel Swap / Choose Slot; got %s" % [swap_prompt_labels]
	)
	await _save_screenshot("character_magic_swap_selected.png")
	attuned_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.25).timeout
	var attuned: Array = (instance.get("_run_state") as Dictionary).get("attuned_magic_cards", []) as Array
	_require(not attuned.is_empty() and str(attuned[0]) == "bone_dart", "Second A on an attuned slot should complete the controller magic swap")
	instance.call("_close_card_upgrade_overlay")
	await _settle()
	var clean_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	clean_state["notice"] = ""
	instance.set("_run_state", clean_state)
	instance.call("_refresh_ui")
	await _settle()

func _controller_accept_event() -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = true
	event.device = 0
	return event

func _press_controller_button(button_index: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	press.device = 0
	_viewport.push_input(press, true)
	await _settle()
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	release.device = 0
	_viewport.push_input(release, true)
	await process_frame

func _wait_for_combat_animation(instance: Node) -> void:
	# GUI probes render uncapped, so frame counts do not approximate wall time.
	# Poll on a real timer to let authored tweens and card-resolution timers elapse.
	for _poll: int in range(200):
		if not bool(instance.get("_animation_lock")):
			await _settle()
			return
		await create_timer(0.05).timeout
	_require(false, "Controller-triggered combat animation should complete within ten seconds")

func _assert_controller_layout_survives_animation_lock(instance: Node, label: String) -> void:
	var board: Control = instance.get("board_view") as Control
	var row: Control = instance.get("hand_row") as Control
	var scroll: ScrollContainer = instance.get("hand_scroll") as ScrollContainer
	var hand_count: int = int((((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).size())
	var expected_board_position: Vector2 = board.position
	var expected_board_size: Vector2 = board.size
	var expected_row_minimum: Vector2 = row.custom_minimum_size
	var expected_clip: bool = scroll.clip_contents
	var expected_card_size: Vector2 = instance.call("_hand_card_size", hand_count, false)

	instance.set("_animation_lock", true)
	instance.call("_refresh_animation_lock_ui")
	instance.call("_apply_controller_hand_layout")
	instance.call("_sync_board_view_rect")
	await _settle()
	_require(board.position.is_equal_approx(expected_board_position) and board.size.is_equal_approx(expected_board_size), "%s board framing should remain fixed while animation input is locked" % label)
	_require(row.custom_minimum_size.is_equal_approx(expected_row_minimum) and scroll.clip_contents == expected_clip, "%s dock geometry should remain fixed while animation input is locked" % label)
	var locked_card_size: Vector2 = instance.call("_hand_card_size", hand_count, false)
	_require(locked_card_size.is_equal_approx(expected_card_size), "%s card sizing should remain fixed while animation input is locked" % label)

	instance.set("_animation_lock", false)
	instance.call("_refresh_animation_lock_ui")
	instance.call("_apply_controller_hand_layout")
	instance.call("_sync_board_view_rect")
	instance.call("_refresh_controller_interface")
	await _settle()
	_require(board.position.is_equal_approx(expected_board_position) and board.size.is_equal_approx(expected_board_size), "%s board framing should remain fixed after animation input unlocks" % label)
	_require(row.custom_minimum_size.is_equal_approx(expected_row_minimum) and scroll.clip_contents == expected_clip, "%s dock geometry should remain fixed after animation input unlocks" % label)

func _load_combat_fixture(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"]
	# Keep one enemy adjacent so Quick Stab's printed action and the fallback
	# attack/move modes are all genuinely playable during event-level navigation.
	var layout: Dictionary = _room_layout(Vector2i(2, 4), [Vector2i(3, 4), Vector2i(5, 2)])
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(127801, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": hand.duplicate(),
		"relics": [],
		"hand_size": hand.size(),
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
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
	combat_state["loot"] = [{
		"id": "steam_deck_probe_equipment",
		"kind": "equipment",
		"equipment_id": "training_sword",
		"pos": Vector2i(4, 3),
		"claimed": false,
	}]
	var restrictions: Dictionary = (combat_state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	restrictions["immobilized"] = false
	restrictions["frozen"] = false
	restrictions["shocked"] = false
	combat_state["player_turn_restrictions"] = restrictions
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle()

func _room_layout(player_pos: Vector2i, enemy_positions: Array) -> Dictionary:
	var enemies: Array = []
	for index: int in range(enemy_positions.size()):
		enemies.append({
			"id": index + 1,
			"type": "crawler",
			"pos": enemy_positions[index],
			"hp": 140,
			"max_hp": 140,
			"block": 0,
		})
	return {
		"name": "Steam Deck Controller Probe",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": player_pos,
		"enemies": enemies,
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

func _first_available_combat_coord(run_engine, state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(state):
		var preview_state: Dictionary = run_engine.move_to_room(state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat":
			return coord
	return Vector2i(999, 999)

func _assert_prompt_bar(prompt_bar: Control, label: String) -> void:
	_require(prompt_bar != null and prompt_bar.visible, "%s should show controller prompts in controller modality" % label)
	_assert_control_inside_logical_viewport(prompt_bar, "%s prompt bar" % label, 8.0)
	var prompts: Array = prompt_bar.call("prompts_snapshot") if prompt_bar != null else []
	_require(not prompts.is_empty(), "%s should expose at least one contextual controller command" % label)

func _assert_prompt_above_modal(instance: Node, modal: Control, label: String) -> void:
	var prompt_bar: Control = instance.get("_controller_prompt_bar") as Control
	_require(prompt_bar != null and modal != null, "%s should have prompt and modal surfaces" % label)
	if prompt_bar == null or modal == null:
		return
	_require(not prompt_bar.z_as_relative and prompt_bar.z_index > modal.z_index, "%s prompts should render above its modal scrim" % label)
	_assert_prompt_bar(prompt_bar, label)

func _assert_board_cursor_center(instance: Node) -> void:
	var tile: Vector2i = instance.get("_controller_board_tile")
	var board: Control = instance.get("board_view") as Control
	_require(board != null and board.get("_controller_focus_tile") == tile, "Board navigation should render focus through the board's projected tile overlay")
	var run_state: Dictionary = instance.get("_run_state") as Dictionary
	var include_doors: bool = str(run_state.get("mode", "room")) == "room"
	var navigable: Array = board.call("controller_navigable_tiles", include_doors) if board != null else []
	_require(navigable.has(tile), "Board cursor should snap only to rendered, player-visible board geometry")
	var cursor: Control = instance.get("_controller_analog_cursor") as Control
	_require(cursor != null and cursor.visible, "Board navigation should keep the true analog circle cursor visible")
	if cursor != null:
		var snapshot: Dictionary = cursor.call("cursor_snapshot")
		var pointer_position: Vector2 = snapshot.get("pointer_position", Vector2.INF)
		var snapped_position: Vector2 = snapshot.get("snapped_position", Vector2.INF)
		var display_position: Vector2 = snapshot.get("display_position", Vector2.INF)
		_require(is_finite(pointer_position.x) and is_finite(pointer_position.y), "Analog cursor should expose its continuous screen-space pointer position")
		_require(
			display_position.distance_to(snapped_position) <= 0.5
			and is_equal_approx(float(snapshot.get("snap_strength", 0.0)), 1.0),
			"Releasing the stick on a selected tile should settle the visible puck at that tile's center"
		)

func _assert_controller_board_envelope(board: Control, instance: Node) -> void:
	var tiles: Array = board.call("controller_navigable_tiles", false) as Array
	var bounds := Rect2()
	var has_bounds: bool = false
	var board_transform: Transform2D = board.get_global_transform()
	for tile_var: Variant in tiles:
		var tile: Vector2i = tile_var as Vector2i
		var polygon: PackedVector2Array = board.call("_tile_polygon", tile) as PackedVector2Array
		for local_point: Vector2 in polygon:
			var point: Vector2 = board_transform * local_point
			bounds = Rect2(point, Vector2.ZERO) if not has_bounds else bounds.expand(point)
			has_bounds = true
	_require(has_bounds, "Controller framing proof should find visible floor geometry")
	if not has_bounds:
		return
	var viewport_height: float = board.get_viewport_rect().size.y
	var top_ratio: float = bounds.position.y / viewport_height
	var bottom_ratio: float = bounds.end.y / viewport_height
	_require(
		top_ratio >= 0.14 and top_ratio <= 0.27,
		"The fixed controller board should reserve only the authored worst-case top actor/prop envelope (bounds=%s viewport_h=%.1f ratio=%.3f)" % [bounds, viewport_height, top_ratio]
	)
	_require(bottom_ratio >= 0.84, "The fixed controller board should use the available height instead of floating above the tucked hand (bounds=%s viewport_h=%.1f ratio=%.3f)" % [bounds, viewport_height, bottom_ratio])
	var first_card: Control = instance.call("_hand_card_control", 0) as Control
	_require(first_card != null, "Controller board-envelope proof should find the tucked hand's first card")
	if first_card != null:
		var card_top: float = first_card.get_global_rect().position.y
		_require(
			bounds.end.y <= card_top + 1.0,
			"The bottom visible tile must finish above the tucked card crowns (board_bottom=%.1f card_top=%.1f)" % [bounds.end.y, card_top]
		)

func _sweep_controller_cursor_to_new_tile(instance: Node, direction: Vector2, previous_tile: Vector2i) -> Vector2i:
	instance.set("_controller_stick", direction)
	var board: Control = instance.get("board_view") as Control
	var visible_tiles: Array = board.call("controller_navigable_tiles", true) as Array
	for _step: int in range(12):
		instance.call("_controller_process_board_cursor", 0.08)
		var tile: Vector2i = instance.get("_controller_board_tile")
		if tile != previous_tile and visible_tiles.has(tile):
			return tile
	var current_tile: Vector2i = instance.get("_controller_board_tile")
	return current_tile

func _assert_forged_cursor_hidden_for_controller() -> void:
	var cursor_feedback: Node = root.get_node_or_null("CursorFeedback")
	_require(cursor_feedback != null, "Controller proof requires the global forged cursor controller")
	if cursor_feedback == null:
		return
	cursor_feedback.call("_process", 0.01)
	var glyph: Control = cursor_feedback.call("glyph_for_test") as Control
	_require(glyph != null and not glyph.visible, "Controller modality should hide the forged mouse cursor instead of leaving it in a screen corner")

func _assert_focus_inside(scope: Control, label: String) -> void:
	_require(scope != null and scope.visible, "%s should be visible" % label)
	var focus_owner: Control = _viewport.gui_get_focus_owner()
	_require(focus_owner != null and (focus_owner == scope or scope.is_ancestor_of(focus_owner)), "%s should recover controller focus inside its own surface" % label)
	_assert_focus_visible(focus_owner, "%s focus" % label)

func _assert_focus_visible(control: Control, label: String) -> void:
	_require(control != null and control.is_visible_in_tree(), "%s should be visibly focused" % label)
	_assert_control_inside_logical_viewport(control, label, 0.0)

func _assert_control_inside_logical_viewport(control: Control, label: String, margin: float) -> void:
	_require(control != null, "%s should exist" % label)
	if control == null:
		return
	var bounds := Rect2(Vector2.ONE * margin, Vector2(_logical_size) - Vector2.ONE * margin * 2.0)
	var rect: Rect2 = control.get_global_rect()
	_require(bounds.encloses(rect), "%s should fit the 1280x800 display; rect=%s logical_bounds=%s" % [label, rect, bounds])

func _assert_pointer_board_rect_restored(instance: Node, controller_navigation_snapshot: Dictionary = {}) -> void:
	var board: Control = instance.get("board_view") as Control
	var stage: Control = instance.get("stage_root") as Control
	_require(board != null and stage != null, "Pointer board framing proof requires the board and stage controls")
	if board == null or stage == null:
		return
	var expected_position: Vector2 = stage.global_position - Vector2(0.0, 56.0)
	var expected_size: Vector2 = stage.size + Vector2(0.0, 56.0)
	_require(
		board.position.is_equal_approx(expected_position) and board.size.is_equal_approx(expected_size),
		"Returning to pointer input must restore the original PC board rect; got pos=%s size=%s expected pos=%s size=%s"
		% [board.position, board.size, expected_position, expected_size]
	)
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_require(
		not bool(presentation.get("controller_combat_navigation", false)),
		"Returning to pointer input must rebuild board content without controller framing"
	)
	var pointer_navigation: Dictionary = board.call("navigation_snapshot") as Dictionary
	var expected_pointer_zoom: float = float(board.call("_default_navigation_zoom_for_viewport"))
	_require(
		is_equal_approx(float(pointer_navigation.get("zoom", -1.0)), expected_pointer_zoom),
		"Pointer handoff must restore the native pointer navigation zoom instead of retaining the controller zoom"
	)
	if not controller_navigation_snapshot.is_empty():
		var controller_content: Rect2 = controller_navigation_snapshot.get("content_rect", Rect2()) as Rect2
		var pointer_content: Rect2 = pointer_navigation.get("content_rect", Rect2()) as Rect2
		_require(
			float(pointer_navigation.get("zoom", 0.0)) < float(controller_navigation_snapshot.get("zoom", 0.0))
			and pointer_content.size.x < controller_content.size.x
			and pointer_content.size.y < controller_content.size.y,
			"Pointer board content should return to its native framing envelope instead of remaining controller-enlarged"
		)
	var prompt_host: Control = instance.get("_contextual_combat_prompt_host") as Control
	if prompt_host != null and prompt_host.visible:
		var prompt_rect: Rect2 = prompt_host.get_global_rect()
		for blocker_name: String in ["_play_meter", "_pass_preview_overlay"]:
			var blocker: Control = instance.get(blocker_name) as Control
			if blocker == null or not blocker.visible:
				continue
			_require(
				not prompt_rect.intersects(blocker.get_global_rect()),
				"Pointer handoff must keep the Combat Note clear of %s" % blocker_name
			)

func _assert_key_handheld_text_floor(instance: Node) -> void:
	var prompt_bar: Control = instance.get("_controller_prompt_bar") as Control
	for label_node: Node in prompt_bar.find_children("*", "Label", true, false):
		var label := label_node as Label
		var logical_font_size: int = label.get_theme_font_size("font_size")
		var physical_font_size: float = float(logical_font_size) * float(_physical_size.y) / float(_logical_size.y)
		_require(physical_font_size >= 12.0, "Controller prompt text should render at a 12px physical floor on Steam Deck; got %.2fpx" % physical_font_size)
	if _probe_requires_handheld_output():
		_require(UiTypography.is_handheld_output(instance.get("ui_root") as Control), "The production-stretch probe should engage the handheld type profile")

func _save_screenshot(filename: String) -> void:
	await _settle()
	var image: Image = _viewport.get_texture().get_image()
	_require(image != null and image.get_size() == _physical_size, "%s should render at exact target resolution" % filename)
	if image != null:
		var error: Error = image.save_png(ProjectSettings.globalize_path("%s/%s" % [_output_dir, filename]))
		_require(error == OK, "Steam Deck screenshot should save: %s" % filename)

func _settle() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PROGRESSION_PATH))

func _clear_probe_output(absolute_dir: String) -> void:
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
			_clear_probe_output(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()

func _require(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
