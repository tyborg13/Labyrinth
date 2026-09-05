extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const OUTPUT_DIR: String = "user://pillar_torch_lighting_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
var _errors: Array[String] = []

# Preserve the former solid slab edge only for the matched before screenshot.
class UnpolishedFloor extends CombatBoardView:
	func _draw_floor_tile_depth(tile: Vector2i) -> void:
		var faces: Array[PackedVector2Array] = _tile_depth_faces(tile)
		for face_index: int in range(faces.size()):
			var face: PackedVector2Array = faces[face_index]
			var face_color := Color("33231b") if face_index == 0 else Color("241914")
			draw_colored_polygon(face, face_color)
			if face.size() >= 4:
				draw_polyline(PackedVector2Array([face[0], face[1], face[2], face[3], face[0]]), TILE_DEPTH_EDGE, 1.5, true)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://pillar_lighting_progression.json")
	ProgressionStore.set_run_storage_path("user://pillar_lighting_run.save")
	SettingsStore.set_storage_path("user://pillar_lighting_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = VIEWPORT_SIZE
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	root.add_child(viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_load_run_state", RunEngine.new().create_new_run(62001, ProgressionStore.default_data()))
	instance.call("_close_dialogue")
	await _load_combat_fixture(instance, 62001)
	await _settle()
	var board: Control = instance.get_node("BoardUnderlay/CombatBoard")
	board.set_process(false)
	var lighting: Texture2D = board.get("_pillar_torch_light_texture") as Texture2D
	_expect(lighting != null, "The floor and fixture light texture must be available")
	var static_layer: Control = board.get("_static_render_cache_layer") as Control
	static_layer.set_script(UnpolishedFloor)
	static_layer.set("_is_static_render_cache_layer", true)
	_set_lighting(board, null)
	await _capture(viewport, "01_before.png")
	static_layer.set_script(CombatBoardView)
	static_layer.set("_is_static_render_cache_layer", true)
	_set_lighting(board, lighting)
	await _capture(viewport, "02_after_normal.png")
	settings["reduced_motion"] = true
	instance.set("_settings", settings)
	instance.call("_refresh_ui")
	await _capture(viewport, "03_after_reduced_motion.png")
	instance.call("_on_card_pressed", 0)
	await _settle()
	var preview: Dictionary = instance.call("_active_card_preview") as Dictionary
	var target_tiles: Array = preview.get("target_tiles", []) as Array
	_expect(not target_tiles.is_empty(), "The lit board must still expose legal targets")
	if not target_tiles.is_empty():
		instance.call("_on_board_tile_hovered", target_tiles[0])
		var target_point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", target_tiles[0]) as Vector2)
		instance.call("_sync_click_targeting_arrow", target_point)
		_expect((board.get("attack_tiles") as Array).has(target_tiles[0]), "Lighting must preserve the target overlay")
	await _capture(viewport, "04_after_targeting.png")
	instance.call("_on_cancel_requested")
	board.call("set_static_render_cache_enabled", false)
	await _capture(viewport, "05_after_direct_floor.png")
	for error: String in _errors:
		push_error(error)
	print("PILLAR TORCH LIGHTING PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _set_lighting(board: Control, texture: Texture2D) -> void:
	board.set("_pillar_torch_light_texture", texture)
	board.call("_sync_dynamic_render_assets")
	board.call("_sync_static_render_cache")
	board.call("_queue_dynamic_redraw")
	board.queue_redraw()

func _settle() -> void:
	for frame: int in range(5):
		await process_frame

func _capture(viewport: SubViewport, filename: String) -> void:
	await _settle()
	await RenderingServer.frame_post_draw
	var screenshot: Image = viewport.get_texture().get_image()
	_expect(screenshot.get_size() == VIEWPORT_SIZE, "Every proof image must be 1920x1080")
	_expect(screenshot.save_png("%s/%s" % [OUTPUT_DIR, filename]) == OK, "Proof screenshot must save")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)

func _load_combat_fixture(instance: Node, seed: int) -> void:
	var layout: Dictionary = {
		"name": "Sealed Hall",
		"coord": Vector2i(2, 0),
		"type": "combat",
		"element": "ice",
		"grid": _combat_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 22, "max_hp": 22, "block": 0},
			{"id": 2, "type": "acolyte", "pos": Vector2i(6, 2), "hp": 24, "max_hp": 24, "block": 0}
		],
		"loot": [{"id": "vial", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(5, 4)}],
		"traps": [{"id": "trap", "element": "ice", "pos": Vector2i(4, 3), "damage": 3, "armed": true}],
		"terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(5, 2), "hp": 8, "max_hp": 8}]
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(seed, layout, {
		"hp": 30,
		"max_hp": 30,
		"deck_cards": ["quick_stab", "guarded_step", "lantern_shot", "brace", "bone_dart"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "guarded_step", "lantern_shot", "brace", "bone_dart"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["player_turn_restrictions"] = {"frozen": false, "shocked": false, "immobilized": false}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	var rooms: Dictionary = (run_state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["2,0"] = {"type": "combat", "coord": Vector2i(2, 0), "revealed": true, "visited": true}
	run_state["rooms"] = rooms
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")

func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	for tile: Vector2i in [Vector2i(1, 1), Vector2i(7, 1), Vector2i(1, 5), Vector2i(7, 5), Vector2i(4, 2)]:
		grid[tile.y][tile.x] = "pillar"
	return grid

