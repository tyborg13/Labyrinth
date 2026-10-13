extends SceneTree

## Proof-only gallery through the production board and cutout renderers.
## Logical hero position keeps every idle facing front toward the hero; proof
## camera slots place the hero alongside them. No combat actions or saves.
## --validate-only checks roster/registration headlessly without claiming pixels.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const BoardBase = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Biomes = preload("res://scripts/biome_library.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/bestiary_lineup"
# Non-player-facing fixture/camera defaults.
const PROOF_SEED: int = 1202026
const PROOF_TILE_WIDTH: float = 157.0
const PROOF_HERO_TILE: Vector2i = Vector2i(0, 40)
const PROOF_SETTLE_FRAMES: int = 8
const PROOF_PLAYER_HP: int = 100
const PROOF_EMPTY_PLAYER_HP: int = 0
const PROOF_LAYOUTS: Dictionary = {
	"empty": {"columns": 6, "rows": 2, "origin": Vector2(160, 400), "step": Vector2(320, 330)},
	"normals": {"columns": 11, "rows": 4, "origin": Vector2(110, 220), "step": Vector2(168, 240)},
	"bosses": {"columns": 4, "rows": 2, "origin": Vector2(220, 420), "step": Vector2(480, 470)},
}

var _canvas: SubViewport
var _board: Control
var _failures: Array[String]
var _captures: Array[Dictionary]
var _validate_only: bool = false

class LineupBoard extends BoardBase:
	func _tile_width_for_extents(_extents: Dictionary) -> float:
		return PROOF_TILE_WIDTH

	func _tiles_in_draw_order(_grid: Array) -> Array[Vector2i]:
		var tiles: Array[Vector2i]
		tiles.assign(presentation.get("proof_tiles", []))
		return tiles

	func _tile_center(tile: Vector2i) -> Vector2:
		return (presentation.get("proof_centres", {}) as Dictionary).get(tile, Vector2(-400, -400))

	func _tile_polygon(tile: Vector2i) -> PackedVector2Array:
		var centre: Vector2 = _tile_center(tile)
		return PackedVector2Array([centre + Vector2(0, -PROOF_TILE_WIDTH / 4),
			centre + Vector2(PROOF_TILE_WIDTH / 2, 0), centre + Vector2(0, PROOF_TILE_WIDTH / 4),
			centre + Vector2(-PROOF_TILE_WIDTH / 2, 0), centre + Vector2(0, -PROOF_TILE_WIDTH / 4)])

	func world_position_for_unit_origin(_unit: Dictionary, origin: Vector2i) -> Vector2:
		return _tile_center(origin)

	func draw_tile_for_unit_origin(_unit: Dictionary, origin: Vector2i) -> Vector2i:
		return origin

	func _draw_hud_render_layer() -> void:
		pass # Gallery contract hides health, statuses, intents and chips.

	func _draw_enemy_intent_compass(_unit: Dictionary) -> void:
		pass

	func _draw_unit_focus(_unit: Dictionary, _centre: Vector2) -> void:
		pass

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_validate_only = OS.get_cmdline_user_args().has("--validate-only")
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	Settings.set_storage_path("user://bestiary_lineup_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	_expect(Settings.save_settings(settings), "Isolated settings use 100% UI scale")
	Biomes.set_inspection_override("stone")
	_run.call_deferred()

func _run() -> void:
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.disable_3d = true
	_canvas.world_2d = World2D.new()
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.gui_disable_input = true
	root.add_child(_canvas)
	_expect(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR)) == OK, "Create capture directory")
	var normals: Array[String]
	var bosses: Array[String]
	for id: String in GameData.enemies():
		if bool(GameData.enemy_def(id).get("boss_bar", false)):
			bosses.append(id)
		else:
			normals.append(id)
	normals.sort()
	bosses.sort()
	var no_enemies: Array[String]
	await _prepare("empty", no_enemies)
	var slots: Dictionary = _slots()
	_write_json("slots.json", slots)
	if not _validate_only:
		await _capture("00_empty_board", {"actors": 0, "props": 0, "rows": slots["rows"]})
	await _prepare("normals", normals)
	var normal_semantics: Dictionary = _roster_semantics(normals)
	if not _validate_only:
		await _capture("01_lineup_normals", normal_semantics)
	await _prepare("bosses", bosses)
	var boss_semantics: Dictionary = _roster_semantics(bosses)
	if not _validate_only:
		await _capture("02_lineup_bosses", boss_semantics)
	_write_json("semantic-proof.json", {"size": [1920, 1080], "ui_scale": 1.0, "biome": "stone",
		"seed": PROOF_SEED, "phase_seconds": 0.0, "normals": normals, "bosses": bosses,
		"captures": _captures, "failures": _failures, "validate_only": _validate_only,
		"normal_semantics": normal_semantics, "boss_semantics": boss_semantics})
	for failure: String in _failures:
		push_error(failure)
	print("BESTIARY LINEUP HEADLESS VALIDATION: " + ("PASS" if _failures.is_empty() else "FAIL") if _validate_only
		else "BESTIARY LINEUP PROBE RESULT: " + ("PASS" if _failures.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _failures.is_empty() else 1)

func _prepare(layout_id: String, roster: Array[String]) -> void:
	if is_instance_valid(_board):
		_board.queue_free()
		await process_frame
	var layout: Dictionary = PROOF_LAYOUTS[layout_id]
	var columns: int = int(layout["columns"])
	_expect(roster.size() + 1 <= columns * int(layout["rows"]), "Whole roster fits proof slots")
	var tiles: Array[Vector2i]
	var centres: Dictionary = {}
	var enemies: Array[Dictionary]
	var grid: Array = []
	for y: int in range(PROOF_HERO_TILE.y + 1):
		var row: Array = []
		for x: int in range(columns):
			row.append("wall")
		grid.append(row)
	for index: int in range(columns * int(layout["rows"])):
		var tile: Vector2i = PROOF_HERO_TILE if index == 0 else Vector2i(index % columns, index / columns)
		var centre: Vector2 = layout["origin"] + Vector2(index % columns, index / columns) * (layout["step"] as Vector2)
		tiles.append(tile)
		centres[tile] = centre
		grid[tile.y][tile.x] = "stone"
		if index > 0 and index <= roster.size():
			var id: String = roster[index - 1]
			var definition: Dictionary = GameData.enemy_def(id)
			enemies.append({"id": index, "type": id, "pos": tile,
				"hp": int(definition["max_hp"]), "max_hp": int(definition["max_hp"]), "block": 0})
	var combat: RefCounted = Combat.new()
	var state: Dictionary = combat.create_combat(PROOF_SEED, {"grid": grid, "player_start": PROOF_HERO_TILE,
		"enemies": enemies, "loot": [], "traps": [], "terrain": [], "element": "none"},
		{"hp": PROOF_PLAYER_HP, "max_hp": PROOF_PLAYER_HP, "deck_cards": [], "relics": []})
	if layout_id == "empty":
		# Retained scene layers consume the submission cache, not just
		# _visible_units(). Remove the actor from that source state as well.
		state["player"]["hp"] = PROOF_EMPTY_PLAYER_HP
	_board = LineupBoard.new()
	_board.size = Vector2(VIEWPORT_SIZE)
	_canvas.add_child(_board)
	_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {},
		{"proof_tiles": tiles, "proof_centres": centres, "proof_columns": columns,
		"room_biome_id": "stone", "scene_props": [], "ambient_time_seconds": 0.0, "reduced_motion": false,
		"protagonist_motion": {"clip": "idle", "direction": Vector2i(0, 1)}, "pulse_exit_tiles": false})
	for frame: int in range(PROOF_SETTLE_FRAMES):
		await process_frame
	if layout_id == "empty":
		_expect((_board.get("_visible_units_cache") as Array).is_empty(), "Empty board retained cache contains no actors")
		_expect((_board.call("_visible_units") as Array).is_empty(), "Empty board visible roster contains no actors")
	_freeze(_board)
	_board.set("_idle_elapsed", 0.0)
	_board.set("_idle_frame_by_source", {})
	for unit: Dictionary in _board.call("_visible_units"):
		var renderer: Node = _board.call("unit_cutout_renderer", unit)
		if is_instance_valid(renderer):
			renderer.set("_idle_seconds", 0.0)
			renderer.call("_apply_pose")
			var snapshot: Dictionary = renderer.call("snapshot")
			_expect(str(snapshot.get("facing", "")) == "front", "Front idle facing: " + str(unit["type"]))
			_expect(str(snapshot.get("clip", "")) == "idle", "Idle clip: " + str(unit["type"]))
		var rect: Rect2 = _board.call("_unit_draw_rect", unit)
		_expect(Rect2(Vector2.ZERO, Vector2(VIEWPORT_SIZE)).encloses(rect), "Actor canvas inside capture: " + str(unit["type"]))
	var treatment: RefCounted = _board.get("_art_treatment")
	if treatment != null:
		treatment.set("_clock", 0.0)
		treatment.call("advance", 0.0, false)
	_board.call("_sync_static_render_cache")
	_board.call("_queue_dynamic_redraw")
	_board.queue_redraw()
	for frame: int in range(PROOF_SETTLE_FRAMES):
		await process_frame

func _freeze(node: Node) -> void:
	node.set_process(false)
	node.set_physics_process(false)
	for child: Node in node.get_children():
		_freeze(child)

func _slots() -> Dictionary:
	var rows: Array = []
	var tiles: Array = (_board.get("presentation") as Dictionary)["proof_tiles"]
	for row_index: int in range(2):
		var row: Array = []
		for column: int in range(6):
			var tile: Vector2i = tiles[row_index * 6 + column]
			var centre: Vector2 = _board.get_global_transform() * (_board.call("_tile_center", tile) as Vector2)
			var scale_at_one: float = float(_board.call("source_pixel_scale_for_type", "player"))
			row.append({"tile": [tile.x, tile.y], "centre": [centre.x, centre.y], "screen_px_per_canvas_px": scale_at_one})
		rows.append(row)
	return {"size": [1920, 1080], "ui_scale": 1.0, "rows": rows, "empty_board_capture": "00_empty_board.png"}

func _roster_semantics(roster: Array[String]) -> Dictionary:
	var actors: Array = []
	for unit: Dictionary in _board.call("_visible_units"):
		var renderer: Node = _board.call("unit_cutout_renderer", unit)
		var rect: Rect2 = _board.call("_unit_draw_rect", unit)
		actors.append({"type": unit["type"], "rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
			"art_scale": _board.call("_unit_art_scale", unit), "pose": renderer.call("snapshot") if is_instance_valid(renderer) else {"static_idle": true}})
	_expect(actors.size() == roster.size() + 1, "Hero and every roster actor are present")
	return {"roster": roster, "actors": actors, "hud_hidden": true, "props": 0, "phase_seconds": 0.0}

func _capture(name: String, semantics: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _canvas.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE, "Exact 1920x1080 SubViewport capture")
	var path: String = OUTPUT_DIR.path_join(name + ".png")
	_expect(image.save_png(ProjectSettings.globalize_path(path)) == OK, "Save " + name)
	_captures.append({"path": path, "semantics": semantics})
	print("BESTIARY LINEUP CAPTURE: " + ProjectSettings.globalize_path(path))

func _write_json(name: String, data: Dictionary) -> void:
	var file := FileAccess.open(OUTPUT_DIR.path_join(name), FileAccess.WRITE)
	_expect(file != null, "Open " + name)
	if file != null:
		file.store_string(JSON.stringify(data, "\t", true))
		file.close()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
