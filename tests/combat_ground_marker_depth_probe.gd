extends SceneTree

const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const OUTPUT_DIR: String = "user://probes/combat_ground_marker_depth"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

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
	_board = CombatBoardView.new()
	_board.size = Vector2(VIEWPORT_SIZE)
	_viewport.add_child(_board)
	# _ready() enables processing, so freeze after the scene has entered its tree.
	# Only the ground markers may vary between each opaque-body pixel pair.
	await process_frame
	_board.set_process(false)
	_board.set("_idle_elapsed", 0.0)
	var state: Dictionary = _fixture()
	var tiles: Array = []
	for y: int in range(2, 7):
		for x: int in range(2, 7):
			tiles.append(Vector2i(x, y))
	var base := {"ambient_time_seconds": 42.0, "umbra_time_seconds": 42.0, "reduced_motion": true}
	var preview: Dictionary = base.duplicate(true)
	preview["focus_tiles"] = tiles
	preview["player_aoe_preview_active"] = true
	await _capture_case("01_aoe_preview", state, base, preview)
	for reduced_motion: bool in [false, true]:
		var empty: Dictionary = base.duplicate(true)
		empty["reduced_motion"] = reduced_motion
		empty["effect"] = {"kind": "aoe", "element": "none", "from": Vector2i(2, 5), "to": Vector2i(4, 4), "tiles": []}
		empty["effect_progress"] = 0.6
		var marked: Dictionary = empty.duplicate(true)
		marked["effect"]["tiles"] = tiles
		await _capture_case("02_aoe_impact_reduced" if reduced_motion else "02_aoe_impact", state, empty, marked)
	for is_preview: bool in [true, false]:
		var empty: Dictionary = base.duplicate(true)
		empty["effect"] = {"kind": "ranged", "action_type": "push", "element": "none", "from": Vector2i(2, 5), "to": Vector2i(5, 4), "preview": is_preview, "force_tiles": []}
		empty["effect_progress"] = 0.75
		var marked: Dictionary = empty.duplicate(true)
		marked["effect"]["force_tiles"] = tiles
		await _capture_case("03_force_preview" if is_preview else "03_force_resolution", state, empty, marked)
	var shadow: Dictionary = base.duplicate(true)
	shadow["umbra_stage"] = "pressing"
	shadow["umbra_visible_tiles"] = [Vector2i(2, 4), Vector2i(2, 5), Vector2i(3, 5), Vector2i(3, 4), Vector2i(4, 4), Vector2i(4, 5), Vector2i(4, 3), Vector2i(5, 4), Vector2i(5, 5)]
	shadow["visible_enemy_ids"] = [1]
	shadow["effect"] = {"kind": "aoe", "element": "none", "from": Vector2i(2, 5), "to": Vector2i(4, 4), "tiles": []}
	shadow["effect_progress"] = 0.6
	var shadow_marked: Dictionary = shadow.duplicate(true)
	shadow_marked["effect"]["tiles"] = [Vector2i(4, 4), Vector2i(3, 4), Vector2i(5, 4), Vector2i(4, 3), Vector2i(4, 5)]
	await _capture_case("05_aoe_umbra", state, shadow, shadow_marked)
	var large: Dictionary = state.duplicate(true)
	large["enemies"] = [{"id": 3, "type": "tharokh", "pos": Vector2i(4, 3), "hp": 64, "max_hp": 64, "footprint": Vector2i(2, 2)}]
	await _capture_case("04_large_enemy_target", large, base, base, [Vector2i(4, 3)])
	var path: String = ProjectSettings.globalize_path(OUTPUT_DIR.path_join("pixel-proof.json"))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _errors.is_empty():
		print("COMBAT GROUND MARKER DEPTH PROBE: PASS")
		quit(0)
	else:
		for error: String in _errors:
			push_error(error)
		print("COMBAT GROUND MARKER DEPTH PROBE: FAIL")
		quit(1)

func _capture_case(label: String, state: Dictionary, base: Dictionary, marked: Dictionary, attack_tiles: Array = []) -> void:
	var baseline: Image = await _render(state, base)
	var occluders: Array[Dictionary] = _opaque_occluders()
	var result: Image = await _render(state, marked, attack_tiles)
	_expect(result.save_png(ProjectSettings.globalize_path(OUTPUT_DIR.path_join(label + ".png"))) == OK, label + " must save native pixels")
	var changed_floor_pixels: int = 0
	for y: int in range(0, VIEWPORT_SIZE.y, 3):
		for x: int in range(0, VIEWPORT_SIZE.x, 3):
			if _difference(baseline.get_pixel(x, y), result.get_pixel(x, y)) > 0.04:
				changed_floor_pixels += 1
	_expect(changed_floor_pixels > 80, label + " must retain visible ground targeting")
	var occluder_metrics: Dictionary = {}
	for occluder: Dictionary in occluders:
		var texture: Texture2D = occluder["texture"] as Texture2D
		var source: Image = texture.get_image()
		var rect: Rect2 = occluder["rect"] as Rect2
		var samples: int = 0
		var overwritten: int = 0
		for y: int in range(maxi(0, ceili(rect.position.y)), mini(VIEWPORT_SIZE.y, floori(rect.end.y)), 2):
			for x: int in range(maxi(0, ceili(rect.position.x)), mini(VIEWPORT_SIZE.x, floori(rect.end.x)), 2):
				var uv: Vector2 = (Vector2(x + 0.5, y + 0.5) - rect.position) / rect.size
				var pixel := Vector2i(floori(uv.x * source.get_width()), floori(uv.y * source.get_height()))
				if not _opaque_neighborhood(source, pixel):
					continue
				samples += 1
				if _difference(baseline.get_pixel(x, y), result.get_pixel(x, y)) > 0.02:
					overwritten += 1
		var key: String = str(occluder["key"])
		occluder_metrics[key] = {"opaque_samples": samples, "overwritten": overwritten}
		_expect(samples > 50, label + "/" + key + " must expose a substantial opaque silhouette")
		_expect(overwritten <= 2, "%s/%s floor markings painted over %d opaque body pixels" % [label, key, overwritten])
	_metrics[label] = {"visible_marker_samples": changed_floor_pixels, "occluders": occluder_metrics}
	print("DEPTH_PIXEL_PROOF %s %s" % [label, JSON.stringify(_metrics[label])])

func _render(state: Dictionary, presentation: Dictionary, attack_tiles: Array = []) -> Image:
	_board.call("set_combat_state", state, [], attack_tiles, Vector2i(-1, -1), "", "", {}, {}, presentation)
	await process_frame
	await process_frame
	var result: Image = _viewport.get_texture().get_image()
	_expect(result.get_size() == VIEWPORT_SIZE, "Depth proof must render 1920x1080 directly")
	return result

func _opaque_occluders() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for unit: Dictionary in _board.call("_visible_units"):
		result.append({"key": str(unit.get("key", "actor")), "texture": _board.call("_texture_for_unit", unit), "rect": _board.call("_unit_draw_rect", unit)})
	var state: Dictionary = _board.get("combat_state") as Dictionary
	for trap: Dictionary in state.get("traps", []):
		if not _board.call("_board_tile_is_visible_to_player", trap.get("pos")):
			continue
		result.append({"key": "trap", "texture": _board.call("_trap_idle_texture", trap), "rect": _board.call("_trap_visual_draw_rect", trap)})
	for loot: Dictionary in state.get("loot", []):
		if not _board.call("_board_tile_is_visible_to_player", loot.get("pos")):
			continue
		var loot_texture: Texture2D = _board.call("_loot_texture", loot) as Texture2D
		result.append({"key": "loot", "texture": loot_texture, "rect": _board.call("_loot_rect_for_tile", loot.get("pos"), loot_texture, loot)})
	var textures: Dictionary = _board.get("_prop_textures") as Dictionary
	var texture: Texture2D = textures.get("pillar") as Texture2D
	for tile: Vector2i in [Vector2i(3, 3), Vector2i(5, 5)]:
		var rect: Rect2 = _board.call("_prop_draw_rect", texture, _board.call("_prop_rect_for_tile", tile)) as Rect2
		var tint: Color = _board.call("_foreground_blocker_tint", "pillar", tile, rect, _board.get("_foreground_obstruction_entries_cache"))
		if tint.a > 0.999:
			result.append({"key": "pillar_%s" % tile, "texture": texture, "rect": rect})
	return result

func _opaque_neighborhood(image: Image, point: Vector2i) -> bool:
	if point.x < 2 or point.y < 2 or point.x >= image.get_width() - 2 or point.y >= image.get_height() - 2:
		return false
	for dy: int in range(-2, 3):
		for dx: int in range(-2, 3):
			if image.get_pixel(point.x + dx, point.y + dy).a < 0.999:
				return false
	return true

func _difference(a: Color, b: Color) -> float:
	return maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))

func _fixture() -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or y == 0 or x == 8 or y == 8 or Vector2i(x, y) in [Vector2i(3, 3), Vector2i(5, 5)] else "stone")
		grid.append(row)
	return {
		"room_coord": Vector2i(3, 2), "room_element": "none", "grid": grid, "moss": {},
		"player": {"pos": Vector2i(2, 5), "hp": 24, "max_hp": 24},
		"enemies": [{"id": 1, "type": "warden", "pos": Vector2i(4, 4), "hp": 18, "max_hp": 18}, {"id": 2, "type": "acolyte", "pos": Vector2i(6, 4), "hp": 12, "max_hp": 12}],
		"illusions": [], "npcs": [], "traps": [{"id": "depth_trap", "element": "fire", "pos": Vector2i(5, 3), "damage": 3, "armed": true}], "terrain": [], "loot": [{"id": "depth_embers", "kind": "dropped_embers", "amount": 17, "pos": Vector2i(6, 6)}], "umbra": {"stage": "clear"}
	}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
