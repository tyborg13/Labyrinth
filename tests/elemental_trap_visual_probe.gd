extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://elemental_trap_visual_probe"
const SCREENSHOT_PATH: String = OUTPUT_DIR + "/elemental_traps_1920x1080_ui100.png"
const IDLE_LATER_PATH: String = OUTPUT_DIR + "/elemental_traps_idle_later_1920x1080_ui100.png"
const CONTACT_PATH: String = OUTPUT_DIR + "/elemental_traps_contact_1920x1080_ui100.png"
const ACTIVATION_PATH: String = OUTPUT_DIR + "/elemental_traps_activation_1920x1080_ui100.png"
const AFTERMATH_PATH: String = OUTPUT_DIR + "/elemental_traps_aftermath_1920x1080_ui100.png"
const POST_REMOVAL_PATH: String = OUTPUT_DIR + "/elemental_traps_post_removal_1920x1080_ui100.png"
const REDUCED_MOTION_PATH: String = OUTPUT_DIR + "/elemental_traps_reduced_motion_1920x1080_ui100.png"
const SCREENSHOT_SIZE: Vector2i = Vector2i(1920, 1080)
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const ELEMENTS: PackedStringArray = ["fire", "ice", "lightning", "air", "earth"]

var _errors: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://labyrinth_progression_elemental_trap_visual_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_elemental_trap_visual_probe.save")
	SettingsStore.set_storage_path("user://labyrinth_settings_elemental_trap_visual_probe.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(SCREENSHOT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SCREENSHOT_SIZE
	root.size = SCREENSHOT_SIZE
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle_ui()
	await _capture_trap_board()

	if _errors.is_empty():
		print("ELEMENTAL TRAP VISUAL PROBE: PASS")
		print("ELEMENTAL_TRAP_PROOF=%s" % ProjectSettings.globalize_path(SCREENSHOT_PATH))
		print("ELEMENTAL_TRAP_IDLE_LATER_PROOF=%s" % ProjectSettings.globalize_path(IDLE_LATER_PATH))
		print("ELEMENTAL_TRAP_CONTACT_PROOF=%s" % ProjectSettings.globalize_path(CONTACT_PATH))
		print("ELEMENTAL_TRAP_ACTIVATION_PROOF=%s" % ProjectSettings.globalize_path(ACTIVATION_PATH))
		print("ELEMENTAL_TRAP_AFTERMATH_PROOF=%s" % ProjectSettings.globalize_path(AFTERMATH_PATH))
		print("ELEMENTAL_TRAP_POST_REMOVAL_PROOF=%s" % ProjectSettings.globalize_path(POST_REMOVAL_PATH))
		print("ELEMENTAL_TRAP_REDUCED_MOTION_PROOF=%s" % ProjectSettings.globalize_path(REDUCED_MOTION_PATH))
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("ELEMENTAL TRAP VISUAL PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)


func _capture_trap_board() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "The elemental trap probe should load the run scene")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle_ui()
	instance.call("_load_run_state", RunEngine.new().create_new_run(82007, ProgressionStore.default_data()))
	if bool(instance.get("_dialogue_active")):
		instance.call("_close_dialogue")
	await _load_combat_fixture(instance)
	await _settle_ui(10)

	var board: Control = instance.get_node(BOARD_PATH) as Control
	_expect(board != null, "The elemental trap probe should find the live CombatBoardView")
	if board != null:
		_validate_live_traps(board)
		await _capture_animation_states(board, instance)
	instance.queue_free()
	await _settle_ui()


func _capture_animation_states(board: Control, instance: Node) -> void:
	var original_state: Dictionary = (board.get("combat_state") as Dictionary).duplicate(true)
	var original_traps: Array = (original_state.get("traps", []) as Array).duplicate(true)
	var original_terrain: Array = (original_state.get("terrain", []) as Array).duplicate(true)
	var idle_presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	idle_presentation["reduced_motion"] = false
	board.set("presentation", idle_presentation)
	board.set("_idle_elapsed", 0.0)
	board.set("_idle_frame_key", "")
	board.call("_sync_dynamic_render_state", false)
	board.call("reset_render_instrumentation")
	board.call("_queue_active_idle_redraws")
	await _settle_ui(3)
	var first_idle_image: Image = await _save_screenshot(SCREENSHOT_PATH)
	var first_idle_key: String = str(board.call("_active_idle_frame_key"))
	var first_draw_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var first_layer_counts: Dictionary = first_draw_snapshot.get("layer_draw_counts", {}) as Dictionary
	var first_world_draw_count: int = int(first_layer_counts.get("world", 0))
	# Do not synthesize input or manually advance the frame. This wait reproduces
	# the live thinking state where the traps must continue animating on their own.
	await create_timer(0.42).timeout
	await _settle_ui(2)
	var later_idle_image: Image = await _save_screenshot(IDLE_LATER_PATH)
	var later_idle_key: String = str(board.call("_active_idle_frame_key"))
	var later_draw_snapshot: Dictionary = board.call("render_instrumentation_snapshot") as Dictionary
	var later_layer_counts: Dictionary = later_draw_snapshot.get("layer_draw_counts", {}) as Dictionary
	var later_world_draw_count: int = int(later_layer_counts.get("world", 0))
	_expect(first_idle_key != later_idle_key, "Trap idle frames should advance without mouse or keyboard input")
	_expect(later_world_draw_count > first_world_draw_count, "The retained world layer should redraw as trap idle frames advance")
	_expect(
		_trap_pixels_changed_without_input(board, original_traps, first_idle_image, later_idle_image),
		"At least one live trap should visibly change frames without pointer movement"
	)

	var activated_state: Dictionary = original_state.duplicate(true)
	activated_state["traps"] = []
	activated_state["terrain"] = []
	var player_tile: Vector2i = ((original_state.get("player", {}) as Dictionary).get("pos", Vector2i(-1, -1)))
	var trap_damage_entries: Array = [
		FloatingCombatText.damage_entry(player_tile, "-7", Color("f39779")),
	]
	var activation_presentation: Dictionary = _trap_eruption_presentation(
		instance,
		idle_presentation,
		original_traps,
		original_terrain,
		0.04,
		false
	)
	activation_presentation["impact_actor_keys"] = ["player"]
	activation_presentation["floating_texts"] = FloatingCombatText.animate_entries(
		trap_damage_entries,
		0.04,
		false
	)
	board.call("set_combat_state", activated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, activation_presentation)
	await _settle_ui(3)
	await _save_screenshot(CONTACT_PATH)

	var peak_presentation: Dictionary = _trap_eruption_presentation(
		instance,
		idle_presentation,
		original_traps,
		original_terrain,
		0.18,
		false
	)
	peak_presentation["impact_actor_keys"] = ["player"]
	peak_presentation["floating_texts"] = FloatingCombatText.animate_entries(
		trap_damage_entries,
		0.18,
		false
	)
	board.call(
		"set_combat_state",
		activated_state,
		[],
		[],
		Vector2i(-1, -1),
		"",
		"",
		{},
		{},
		peak_presentation
	)
	await _settle_ui(3)
	await _save_screenshot(ACTIVATION_PATH)
	var aftermath_presentation: Dictionary = _trap_eruption_presentation(
		instance,
		idle_presentation,
		original_traps,
		original_terrain,
		0.42,
		false
	)
	aftermath_presentation["impact_actor_keys"] = ["player"]
	aftermath_presentation["floating_texts"] = FloatingCombatText.animate_entries(
		trap_damage_entries,
		0.42,
		false
	)
	board.call("set_combat_state", activated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, aftermath_presentation)
	await _settle_ui(3)
	await _save_screenshot(AFTERMATH_PATH)

	var removed_presentation: Dictionary = idle_presentation.duplicate(true)
	removed_presentation.erase("trap_effects")
	removed_presentation.erase("effect_progress")
	board.call("set_combat_state", activated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, removed_presentation)
	await _settle_ui(3)
	await _save_screenshot(POST_REMOVAL_PATH)

	var reduced_presentation: Dictionary = idle_presentation.duplicate(true)
	reduced_presentation["reduced_motion"] = true
	var reduced_traps: Array = instance.call("_trap_effects_for_elapsed", original_traps, 0.0, true)
	reduced_presentation["trap_effects"] = reduced_traps
	reduced_presentation["terrain_destruction_units"] = instance.call(
		"_terrain_destruction_units_for_traps",
		original_terrain,
		reduced_traps
	)
	reduced_presentation["impact_actor_keys"] = ["player"]
	reduced_presentation["floating_texts"] = FloatingCombatText.animate_entries(trap_damage_entries, 0.0, true)
	board.call("set_combat_state", activated_state, [], [], Vector2i(-1, -1), "", "", {}, {}, reduced_presentation)
	await _settle_ui(3)
	await _save_screenshot(REDUCED_MOTION_PATH)


func _trap_eruption_presentation(
	instance: Node,
	base_presentation: Dictionary,
	traps: Array,
	terrain: Array,
	elapsed_seconds: float,
	reduced_motion: bool
) -> Dictionary:
	var result: Dictionary = base_presentation.duplicate(true)
	result["reduced_motion"] = reduced_motion
	var animated_traps: Array = instance.call(
		"_trap_effects_for_elapsed",
		traps,
		elapsed_seconds,
		reduced_motion
	)
	result["trap_effects"] = animated_traps
	result["terrain_destruction_units"] = instance.call(
		"_terrain_destruction_units_for_traps",
		terrain,
		animated_traps
	)
	return result


func _load_combat_fixture(instance: Node) -> void:
	var layout: Dictionary = _trap_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(82007, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "guarded_step", "lantern_shot"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "guarded_step", "lantern_shot"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {
		"frozen": false,
		"shocked": false,
		"immobilized": false
	}
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	if not enemies.is_empty():
		var enemy: Dictionary = (enemies[0] as Dictionary).duplicate(true)
		enemy["intent"] = {
			"name": "Brace",
			"time": 4,
			"actions": [{"type": "block", "amount": 2}]
		}
		enemies[0] = enemy
	combat_state["enemies"] = enemies

	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var room_coord: Vector2i = layout.get("coord", Vector2i.ZERO)
	var rooms: Dictionary = (run_state.get("rooms", {}) as Dictionary).duplicate(true)
	var room_key: String = "%d,%d" % [room_coord.x, room_coord.y]
	var room: Dictionary = (rooms.get(room_key, {}) as Dictionary).duplicate(true)
	room["type"] = "combat"
	room["npcs"] = []
	rooms[room_key] = room
	run_state["rooms"] = rooms
	run_state["mode"] = "combat"
	run_state["current_room"] = room_coord
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")


func _trap_layout() -> Dictionary:
	return {
		"name": "Elemental Pressure Plate Gallery",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"element": "fire",
		"grid": _combat_grid(),
		"player_start": Vector2i(2, 2),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 6),
			"hp": 22,
			"max_hp": 22,
			"block": 0
		}],
		"loot": [],
		"traps": [
			{"id": "fire_plate", "element": "fire", "pos": Vector2i(2, 6), "damage": 4, "armed": true},
			{"id": "ice_plate", "element": "ice", "pos": Vector2i(3, 5), "damage": 4, "armed": true},
			{"id": "lightning_plate", "element": "lightning", "pos": Vector2i(4, 4), "damage": 4, "armed": true},
			{"id": "air_plate", "element": "air", "pos": Vector2i(5, 3), "damage": 4, "armed": true},
			{"id": "earth_plate", "element": "earth", "pos": Vector2i(6, 2), "damage": 4, "armed": true}
		],
		"terrain": [
			{"id": "fire_crate", "kind": "wooden_crate", "pos": Vector2i(1, 6), "hp": 3, "max_hp": 3},
			{"id": "ice_crate", "kind": "wooden_crate", "pos": Vector2i(3, 6), "hp": 3, "max_hp": 3},
			{"id": "lightning_crate", "kind": "wooden_crate", "pos": Vector2i(4, 5), "hp": 3, "max_hp": 3},
			{"id": "air_crate", "kind": "wooden_crate", "pos": Vector2i(5, 4), "hp": 3, "max_hp": 3},
			{"id": "earth_crate", "kind": "wooden_crate", "pos": Vector2i(6, 3), "hp": 3, "max_hp": 3}
		]
	}


func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 8 else "stone")
		grid.append(row)
	return grid


func _validate_live_traps(board: Control) -> void:
	var state: Dictionary = board.get("combat_state") as Dictionary
	var traps: Array = state.get("traps", []) as Array
	_expect(traps.size() == ELEMENTS.size(), "The live board should contain all five elemental traps")
	var textures: Dictionary = board.get("_trap_textures") as Dictionary
	var last_center := Vector2(-INF, -INF)
	for element: String in ELEMENTS:
		var texture: Texture2D = textures.get(element, null)
		_expect(texture != null, "%s should resolve through the live trap texture registry" % element)
		var used_rect := Rect2i()
		if texture != null:
			_expect(texture.get_size() == Vector2(122, 80), "%s should load the canonical 122x80 asset" % element)
			used_rect = texture.get_image().get_used_rect()
			_expect(
				used_rect.size == Vector2i(90, 45),
				"%s should keep its visible plate inside the approved 90x45 stone-margin envelope" % element
			)
			_expect(
				used_rect.size.x == used_rect.size.y * 2,
				"%s should use the same 2:1 isometric perspective as the board tile" % element
			)
		var trap: Dictionary = _trap_for_element(traps, element)
		_expect(not trap.is_empty(), "%s should be present in the deterministic combat fixture" % element)
		if trap.is_empty():
			continue
		var rect: Rect2 = board.call("_trap_visual_draw_rect", trap) as Rect2
		_expect(rect.size.x > 0.0 and rect.size.y > 0.0, "%s should have a visible live draw rectangle" % element)
		_expect(
			is_equal_approx(rect.size.x / rect.size.y, 122.0 / 80.0),
			"%s should preserve the canonical trap texture aspect ratio" % element
		)
		if used_rect.size.x > 0 and used_rect.size.y > 0:
			var visible_size := Vector2(
				rect.size.x * float(used_rect.size.x) / 122.0,
				rect.size.y * float(used_rect.size.y) / 80.0
			)
			var tile_width: float = float(board.call("_tile_width"))
			var tile_height: float = float(board.call("_tile_height"))
			_expect(
				visible_size.x <= tile_width * 0.75 and visible_size.y <= tile_height * 0.75,
				"%s should leave a visible stone margin on every tile edge" % element
			)
		if last_center.x > -INF:
			_expect(rect.get_center().x > last_center.x, "%s should appear to the right of the previous element" % element)
			_expect(is_equal_approx(rect.get_center().y, last_center.y), "%s should share the readable inspection row" % element)
		last_center = rect.get_center()


func _trap_for_element(traps: Array, element: String) -> Dictionary:
	for trap_var: Variant in traps:
		if typeof(trap_var) == TYPE_DICTIONARY:
			var trap: Dictionary = trap_var
			if str(trap.get("element", "")) == element:
				return trap
	return {}


func _trap_pixels_changed_without_input(board: Control, traps: Array, first_image: Image, later_image: Image) -> bool:
	if first_image.is_empty() or later_image.is_empty() or first_image.get_size() != later_image.get_size():
		return false
	var board_transform: Transform2D = board.get_global_transform()
	var image_bounds := Rect2i(Vector2i.ZERO, first_image.get_size())
	for trap_var: Variant in traps:
		if typeof(trap_var) != TYPE_DICTIONARY:
			continue
		var local_rect: Rect2 = board.call("_trap_visual_draw_rect", trap_var as Dictionary) as Rect2
		var global_bounds := Rect2(board_transform * local_rect.position, Vector2.ZERO)
		global_bounds = global_bounds.expand(board_transform * Vector2(local_rect.end.x, local_rect.position.y))
		global_bounds = global_bounds.expand(board_transform * local_rect.end)
		global_bounds = global_bounds.expand(board_transform * Vector2(local_rect.position.x, local_rect.end.y))
		var sample_start := Vector2i(floori(global_bounds.position.x), floori(global_bounds.position.y))
		var sample_end := Vector2i(ceili(global_bounds.end.x), ceili(global_bounds.end.y))
		var sample_rect := Rect2i(sample_start, sample_end - sample_start).intersection(image_bounds)
		for y: int in range(sample_rect.position.y, sample_rect.end.y):
			for x: int in range(sample_rect.position.x, sample_rect.end.x):
				if not first_image.get_pixel(x, y).is_equal_approx(later_image.get_pixel(x, y)):
					return true
	return false


func _save_screenshot(path: String) -> Image:
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = root.get_texture().get_image()
	if image.get_size() != SCREENSHOT_SIZE:
		# macOS exposes the Retina backing texture even though content_scale_size is
		# the requested logical proof viewport. Preserve that real Metal render and
		# downsample it to the exact review resolution.
		image.resize(SCREENSHOT_SIZE.x, SCREENSHOT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	_expect(image.save_png(path) == OK, "The trap proof screenshot should save successfully")
	return image


func _settle_ui(frames: int = 5) -> void:
	for _frame: int in range(frames):
		await process_frame


func _clear_probe_output(output_dir: String) -> void:
	var dir := DirAccess.open(output_dir)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
