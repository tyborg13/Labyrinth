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
	var cursor: Control = instance.get("_controller_cursor") as Control
	_require(cursor != null and cursor.visible, "Controller hand navigation should show a persistent selected-card cursor")
	_assert_prompt_bar(instance.get("_controller_prompt_bar") as Control, "Combat hand")
	_assert_key_handheld_text_floor(instance)
	await _save_screenshot("combat_hand_focus.png")

	instance.call("_controller_enter_board", true)
	await _settle()
	_require(str(instance.get("_controller_region")) == "board", "Up from the hand should enter board navigation")
	_assert_board_cursor_center(instance)
	await _save_screenshot("combat_board_cursor.png")

	instance.call("_controller_set_hand_hidden", true)
	await _settle()
	_require(bool(instance.get("_controller_hand_hidden")), "The X action should collapse the card hand")
	var hand_scroll: Control = instance.get("hand_scroll") as Control
	_require(hand_scroll != null and not hand_scroll.visible, "Hidden-hand mode should reclaim the card area for the board")
	_assert_board_cursor_center(instance)
	await _save_screenshot("combat_hand_hidden.png")

	instance.call("_controller_set_hand_hidden", false)
	instance.call("_open_menu_overlay")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_menu_scrim") as Control, "Pause menu")
	_assert_prompt_above_modal(instance, instance.get("_menu_scrim") as Control, "Pause menu")
	await _save_screenshot("pause_controller_focus.png")
	instance.call("_close_menu_overlay")
	await _settle()

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
	var zoom_event := InputEventJoypadButton.new()
	zoom_event.button_index = JOY_BUTTON_RIGHT_SHOULDER
	zoom_event.pressed = true
	map_view.call("_gui_input", zoom_event)
	_require(float(map_view.call("_camera_zoom_value")) > zoom_before, "Right bumper should zoom the controller map in")
	var map_coord_before: Vector2i = map_view.get("_hover_coord")
	for direction: Vector2 in [Vector2.RIGHT, Vector2.DOWN, Vector2.LEFT, Vector2.UP]:
		map_view.call("_move_controller_focus", direction)
		if map_view.get("_hover_coord") != map_coord_before:
			break
	_require(map_view.get("_hover_coord") != map_coord_before, "Map directional navigation should snap to another visible room node")
	await _save_screenshot("map_controller_focus.png")
	instance.call("_close_large_map")
	await _settle()

	instance.call("_open_character_overlay", "equipment")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_upgrade_scrim") as Control, "Character gear")
	_assert_prompt_above_modal(instance, instance.get("_upgrade_scrim") as Control, "Character gear")
	await _save_screenshot("character_gear_controller_focus.png")
	instance.call("_switch_character_overlay_mode", "magic")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_upgrade_scrim") as Control, "Character magic")
	await _save_screenshot("character_magic_controller_focus.png")
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

	await _exercise_controller_loadout(instance, base_state)
	var room_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, room_state)
	_require(combat_coord != Vector2i(999, 999), "Steam Deck proof needs an available combat room")
	instance.call("_refresh_controller_interface")
	var exits: Dictionary = instance.get("_exit_destinations_by_tile") as Dictionary
	var combat_door: Vector2i = Vector2i(-1, -1)
	for tile_var: Variant in exits.keys():
		if exits[tile_var] == combat_coord:
			combat_door = tile_var as Vector2i
			break
	_require(combat_door.x >= 0, "Room controller navigation should expose the combat route as a board door")
	instance.call("_controller_set_board_tile", combat_door)
	_assert_board_cursor_center(instance)
	_assert_prompt_bar(instance.get("_controller_prompt_bar") as Control, "Room door navigation")
	await _save_screenshot("room_door_cursor.png")
	await instance.call("_controller_activate_current")
	instance.call("_recover_controller_focus")
	await _settle()
	_assert_focus_inside(instance.get("_pre_battle_scrim") as Control, "Pre-battle")
	_assert_control_inside_logical_viewport(instance.get("_pre_battle_panel") as Control, "Pre-battle panel", 16.0)
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
	var gear_tile: Control = gear_tiles.get("iron_cleaver") as Control
	_require(gear_tile != null and gear_tile.focus_mode == Control.FOCUS_ALL, "Spare gear should be controller-focusable outside combat")
	gear_tile.grab_focus()
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
	_require(reserve_tile != null and attuned_tile != null, "Magic swap should expose both controller endpoints")
	reserve_tile.grab_focus()
	reserve_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	_require(str(instance.get("_controller_magic_source_kind")) == "inventory", "First A should hold the reserve spell for a two-step swap")
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

func _load_combat_fixture(instance: Node) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var hand: Array = ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"]
	var layout: Dictionary = _room_layout(Vector2i(2, 4), [Vector2i(5, 4), Vector2i(5, 2)])
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
	var cursor: Control = instance.get("_controller_cursor") as Control
	var expected_center: Vector2 = instance.call("_controller_board_point", tile)
	_require(cursor != null and cursor.visible, "Board navigation should show a visible tile cursor")
	_require(cursor.get_global_rect().get_center().distance_to(expected_center) <= 1.5, "Board cursor should snap to the exact visual center of its tile")

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
