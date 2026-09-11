extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const OUTPUT_DIR: String = "user://probes/foreground_actor_readability"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

# Reproduce the two prior uniform fades only in matched comparison frames.
class ComparisonBoard extends CombatBoardView:
	func _foreground_blocker_tint(tile_id: String, tile: Vector2i, prop_rect: Rect2, obstruction_entries: Array) -> Color:
		var tint: Color = super._foreground_blocker_tint(tile_id, tile, prop_rect, obstruction_entries)
		if tile_id != "pillar" or tint.a >= 1.0:
			return tint
		match str(presentation.get("probe_column_mode", "current")):
			"opaque": return Color.WHITE
			"heavy": return FOREGROUND_OBSTRUCTION_TINT
			"before":
				if tint.a < FOREGROUND_OBSTRUCTION_TINT.a:
					return FOREGROUND_ACTOR_OBSTRUCTION_TINT
		return tint

	func _draw_pillar_body(texture: Texture2D, rect: Rect2, tint: Color) -> void:
		if str(presentation.get("probe_column_mode", "current")) != "current":
			draw_texture_rect(texture, rect, false, tint)
		else:
			super._draw_pillar_body(texture, rect, tint)

	func _pillar_torch_tint(tint: Color) -> Color:
		return super._pillar_torch_tint(tint) if str(presentation.get("probe_column_mode", "current")) == "current" else tint

var _errors: Array[String]
var _viewport: SubViewport
var _board: Control
var _metrics: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.disable_3d = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_board = ComparisonBoard.new()
	_board.size = Vector2(VIEWPORT_SIZE)
	_viewport.add_child(_board)
	await process_frame
	_board.set_process(false)
	_board.set("_idle_elapsed", 0.0)
	var clear: Image = await _render(_fixture(0), "current", true)
	_save(clear, "00_clear_actor")
	var actor: Dictionary = (_board.call("_visible_units") as Array)[0]
	var actor_rect: Rect2 = _board.call("_unit_draw_rect", actor)
	var actor_source: Image = (_board.call("_texture_for_unit", actor) as Texture2D).get_image()
	for count: int in [1, 2, 3]:
		var state: Dictionary = _fixture(count)
		var before: Image = await _render(state, "before", true)
		_save(before, "%d_before" % count)
		var heavy: Image = await _render(state, "heavy", true)
		var opaque: Image = await _render(state, "opaque", true)
		var after: Image = await _render(state, "current", true)
		_save(after, "%d_after" % count)
		var measured: Dictionary = _actor_error(clear, heavy, after, actor_rect, actor_source)
		var blockers: int = _actor_blockers(state)
		measured["actor_blockers"] = blockers
		measured["base"] = _base_error(opaque, before, after)
		_metrics[str(count)] = measured
		_expect(blockers == count, "%d distinct foreground columns must cover the actor" % count)
		_expect(int(measured["samples"]) > 200, "Actor comparison must sample the opaque silhouette")
		# This task deliberately restores column presence. Keep a measurable
		# visibility advantage over the old heavy fade while proving the base too.
		_expect(float(measured["after_error"]) < float(measured["before_error"]) * 0.85, "Actor detail must remain clearer than the former heavy fade")
		var base: Dictionary = measured["base"]
		_expect(float(base["after_error"]) < float(base["before_error"]) * 0.6, "Column foot must be substantially closer to opaque stone than the disappearing baseline")
		if count == 3:
			var normal: Image = await _render(state, "current", false)
			_save(normal, "3_after_normal_motion")
			_expect(_actor_blockers(state) == count, "Reduced motion must preserve identical blocker handling")
	for control: String in ["prop", "loot", "unobstructed", "enemy"]:
		var state: Dictionary = _control_fixture(control)
		var before: Image = await _render(state, "before", true)
		_save(before, control + "_before")
		var after: Image = await _render(state, "current", true)
		_save(after, control + "_after")
		var tints: Array = _pillar_tints(state)
		var expected: float = 1.0 if control == "unobstructed" else (0.32 if control == "enemy" else 0.54)
		_expect(tints.size() == 1 and is_equal_approx(float(tints[0]), expected), control + " obstruction keeps the expected shaft opacity")
		if control == "unobstructed":
			_expect(before.get_data() == after.get_data(), "Unobstructed columns and torches retain identical native pixels")
		_metrics[control] = {"alpha": tints[0], "unchanged_pixels": before.get_data() == after.get_data()}
	var file := FileAccess.open(OUTPUT_DIR.path_join("comparison.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t"))
	file.close()
	print("ACTOR_READABILITY_METRICS ", JSON.stringify(_metrics))
	for error: String in _errors:
		push_error(error)
	print("FOREGROUND ACTOR READABILITY PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(0 if _errors.is_empty() else 1)

func _render(state: Dictionary, mode: String, reduced: bool) -> Image:
	var presentation := {"ambient_time_seconds": 42.0, "umbra_time_seconds": 42.0, "reduced_motion": reduced, "probe_column_mode": mode}
	_board.call("set_combat_state", state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	var result: Image = _viewport.get_texture().get_image()
	_expect(result.get_size() == VIEWPORT_SIZE, "Every comparison must render directly at1920x1080")
	return result

func _actor_error(clear: Image, before: Image, after: Image, rect: Rect2, source: Image) -> Dictionary:
	var samples: int = 0
	var before_error: float = 0.0
	var after_error: float = 0.0
	for y: int in range(ceili(rect.position.y), floori(rect.end.y), 2):
		for x: int in range(ceili(rect.position.x), floori(rect.end.x), 2):
			var uv: Vector2 = (Vector2(x + 0.5, y + 0.5) - rect.position) / rect.size
			var pixel := Vector2i(floori(uv.x * source.get_width()), floori(uv.y * source.get_height()))
			if not _opaque_neighborhood(source, pixel):
				continue
			samples += 1
			before_error += _difference(clear.get_pixel(x, y), before.get_pixel(x, y))
			after_error += _difference(clear.get_pixel(x, y), after.get_pixel(x, y))
	return {"samples": samples, "before_error": before_error / maxf(samples, 1), "after_error": after_error / maxf(samples, 1)}

func _opaque_neighborhood(image: Image, point: Vector2i) -> bool:
	if point.x < 2 or point.y < 2 or point.x >= image.get_width() - 2 or point.y >= image.get_height() - 2:
		return false
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if image.get_pixel(point.x + dx, point.y + dy).a < 0.999:
				return false
	return true

func _difference(a: Color, b: Color) -> float:
	return (absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)) / 3.0

func _actor_blockers(state: Dictionary) -> int:
	var count: int = 0
	for alpha: float in _pillar_tints(state):
		if is_equal_approx(alpha, 0.32):
			count += 1
	var textures: Dictionary = _board.get("_terrain_textures")
	for terrain: Dictionary in state.get("terrain", []):
		var tile: Vector2i = terrain.get("pos")
		var kind: String = terrain.get("kind")
		var rect: Rect2 = _board.call("_terrain_rect_for_tile", tile, textures.get(kind), kind)
		var tint: Color = _board.call("_foreground_blocker_tint", "terrain", tile, rect, _board.get("_foreground_obstruction_entries_cache"))
		if is_equal_approx(tint.a, 0.26):
			count += 1
	return count

func _pillar_tints(state: Dictionary) -> Array:
	var result: Array = []
	var grid: Array = state.get("grid")
	var textures: Dictionary = _board.get("_prop_textures")
	var texture: Texture2D = textures.get("pillar")
	for y: int in range(1, 8):
		for x: int in range(1, 8):
			if str(grid[y][x]) != "wall":
				continue
			var tile := Vector2i(x, y)
			var rect: Rect2 = _board.call("_prop_draw_rect", texture, _board.call("_prop_rect_for_tile", tile))
			var tint: Color = _board.call("_foreground_blocker_tint", "pillar", tile, rect, _board.get("_foreground_obstruction_entries_cache"))
			result.append(tint.a)
	return result

func _fixture(count: int) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 else "stone")
		grid.append(row)
	if count > 0:
		grid[4][4] = "wall"
	if count > 1:
		grid[3][4] = "wall"
	var state := {"room_coord": Vector2i(3, 2), "room_element": "none", "grid": grid, "moss": {}, "player": {"pos": Vector2i(3, 3), "hp": 24, "max_hp": 24}, "enemies": [], "illusions": [], "npcs": [], "traps": [], "terrain": [], "loot": [], "umbra": {"stage": "clear"}}
	if count == 3:
		grid[4][3] = "wall"
	return state

func _control_fixture(kind: String) -> Dictionary:
	var state: Dictionary = _fixture(0)
	state["grid"][4][4] = "wall"
	state["player"]["pos"] = Vector2i(1, 6)
	if kind == "prop":
		state["terrain"] = [{"id": "covered_crate", "kind": "wooden_crate", "pos": Vector2i(3, 3), "hp": 5, "max_hp": 5}]
	elif kind == "loot":
		state["loot"] = [{"id": "covered_embers", "kind": "dropped_embers", "pos": Vector2i(3, 3), "amount": 17}]
	if kind == "enemy":
		state["enemies"] = [{"id": 1, "type": "acolyte", "pos": Vector2i(3, 3), "hp": 24, "max_hp": 24}]
	return state

func _base_error(opaque: Image, before: Image, after: Image) -> Dictionary:
	var textures: Dictionary = _board.get("_prop_textures")
	var texture: Texture2D = textures["pillar"]
	var rect: Rect2 = _board.call("_prop_draw_rect", texture, _board.call("_prop_rect_for_tile", Vector2i(4, 4)))
	var source: Image = texture.get_image()
	var samples: int = 0
	var before_error: float = 0.0
	var after_error: float = 0.0
	for y: int in range(ceili(rect.position.y + rect.size.y * 0.88), floori(rect.end.y)):
		for x: int in range(ceili(rect.position.x), floori(rect.end.x)):
			var uv: Vector2 = (Vector2(x + 0.5, y + 0.5) - rect.position) / rect.size
			if source.get_pixel(int(uv.x * source.get_width()), int(uv.y * source.get_height())).a < 0.95:
				continue
			samples += 1
			before_error += _difference(opaque.get_pixel(x, y), before.get_pixel(x, y))
			after_error += _difference(opaque.get_pixel(x, y), after.get_pixel(x, y))
	_expect(samples > 100, "Base comparison must include visible stone pixels")
	return {"samples": samples, "before_error": before_error / maxf(samples, 1), "after_error": after_error / maxf(samples, 1)}

func _save(image: Image, name: String) -> void:
	_expect(image.save_png(OUTPUT_DIR.path_join(name + ".png")) == OK, "Native comparison must save")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
