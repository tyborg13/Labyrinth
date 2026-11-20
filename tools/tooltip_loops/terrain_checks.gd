extends RefCounted
## Authoring proof from production retained draw commands, not state presence alone.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Margin = preload("res://tools/tooltip_loops/sprite_margin.gd")
const Board = preload("res://tools/tooltip_loops/record_board.gd")
const LOOP_SIZE := Vector2(282, 168)
const NATIVE_PIXEL_TOLERANCE: float = 2.0 / 255.0 # Debug readback comparison only.
var failures: Array[String]
var minimum_margins: Dictionary = {}
var rise_samples: Array[float]
var final_terrain: Array[Dictionary]
var final_surfaces: Array[Dictionary]
var changes: Array[Dictionary]
var final_rock_pixels_above_floor: int = 0
var native_pixels_above_floor: int = -1
var airborne_above_rock_seen: bool = false
var observed_surfaces: Dictionary = {}

static func _surface_visible(board: Control, tile: Vector2i, kind: String) -> bool:
	var layer: Control = board._scene_render_layers_by_tile.get(tile)
	var canvases: Array[Control]
	if is_instance_valid(layer): _canvases(layer, canvases)
	var field: String = {"rubble": "_surface_rubble_layer", "ice": "_surface_ice_layer", "fire": "_surface_fire_layer", "electrified": "_surface_electric_layer"}[kind]
	for canvas: Control in canvases:
		var surface_layer: Node2D = canvas.get(field)
		if is_instance_valid(surface_layer) and surface_layer.is_visible_in_tree(): return true
	return false

static func _canvases(node: Node, result: Array[Control]) -> void:
	if node is Control and node.get_script() == preload("res://tools/tooltip_loops/record_board.gd"): result.append(node)
	for child: Node in node.get_children(): _canvases(child, result)

static func _terrain_rows(board: Control, tile: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var layer: Control = board._scene_render_layers_by_tile.get(tile)
	if not is_instance_valid(layer): return result
	var canvases: Array[Control]
	_canvases(layer, canvases)
	for canvas: Control in canvases:
		if not canvas.is_visible_in_tree(): continue
		var cache: RefCounted = canvas.get("_prop_command_cache")
		for slot: String in cache.get("_slots"):
			if not slot.begins_with("terrain:"): continue
			var entry: Dictionary = cache.get("_slots")[slot]
			result.append({"slot": slot, "inputs": entry["inputs"], "commands": entry["commands"], "canvas": canvas})
	return result

static func polygons(row: Dictionary) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]
	var offset := Vector2.ZERO
	var canvas: Control = row["canvas"]
	var transform: Transform2D = canvas.get_global_transform_with_canvas()
	for command: Array in row["commands"]:
		var points := PackedVector2Array()
		match str(command[0]):
			"transform": offset = command[1]
			"polygon":
				var colors: PackedColorArray = command[2]
				if colors.is_empty() or colors[0].a <= 0.0: continue
				points = command[1].duplicate()
			"texture", "region":
				var rect: Rect2 = command[2]
				points = PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		for i: int in range(points.size()): points[i] = transform * (points[i] + offset)
		if not points.is_empty(): result.append(points)
	return result

static func bounds(paint: Array[PackedVector2Array]) -> Rect2:
	var result := Rect2()
	var first: bool = true
	for polygon: PackedVector2Array in paint:
		for point: Vector2 in polygon:
			if first: result = Rect2(point, Vector2.ZERO); first = false
			else: result = result.expand(point)
	return result

static func floor_top(board: Control, tile: Vector2i) -> float:
	var result: float = INF
	for point: Vector2 in board._tile_polygon(tile): result = minf(result, (board.get_global_transform_with_canvas() * point).y)
	return result

static func pixels_above(paint: Array[PackedVector2Array], top: float, crop: Rect2i) -> Dictionary:
	var pixels: Dictionary = {}
	var scale: Vector2 = LOOP_SIZE / Vector2(crop.size)
	var cutoff: float = (top - crop.position.y) * scale.y
	for polygon: PackedVector2Array in paint:
		var local := PackedVector2Array()
		for point: Vector2 in polygon: local.append((point - Vector2(crop.position)) * scale)
		var rect: Rect2 = bounds(_one_polygon(local))
		for y: int in range(maxi(0, floori(rect.position.y)), mini(ceili(cutoff), ceili(rect.end.y))):
			for x: int in range(maxi(0, floori(rect.position.x)), mini(int(LOOP_SIZE.x), ceili(rect.end.x))):
				if y + 0.5 < cutoff and Geometry2D.is_point_in_polygon(Vector2(x + 0.5, y + 0.5), local): pixels[Vector2i(x, y)] = true
	return pixels

static func _one_polygon(polygon: PackedVector2Array) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array]
	result.append(polygon)
	return result

func observe(board: Control, crop: Rect2i) -> void:
	for tile: Vector2i in Surfaces.tiles(board.combat_state):
		for kind: String in ["rubble", "ice", "fire", "electrified"]:
			if Surfaces.has_surface(board.combat_state, tile, kind) and _surface_visible(board, tile, kind): observed_surfaces["%s:%s" % [tile, kind]] = true
	for terrain: Dictionary in board.combat_state.get("terrain", []):
		if not Surfaces.terrain_is_live(terrain): continue
		for row: Dictionary in _terrain_rows(board, terrain["pos"]):
			var rect: Rect2 = bounds(polygons(row))
			if not rect.has_area(): continue
			var margin: float = Margin.margin(rect, crop)
			var key: String = str(terrain.get("id", terrain["pos"]))
			minimum_margins[key] = minf(float(minimum_margins.get(key, INF)), margin)
			if margin < Margin.REQUIRED_PIXELS and not failures.has("Terrain lacks 4 px frame margin: " + key): failures.append("Terrain lacks 4 px frame margin: " + key)
			if terrain.get("kind") == "crag_outcrop":
				var rise: float = float(row["inputs"][3])
				if not rise_samples.has(rise): rise_samples.append(rise)
				if rise > 0.0 and rise < 1.0:
					if board.first_visible_frame < 0: board.first_visible_frame = board.capture_frame
					board.last_visible_frame = maxi(board.last_visible_frame, board.capture_frame)
				if board.presentation.get("unit_throw_ground_positions", {}).has("enemy_1"):
					var manager: Node = board.get("_occlusion_silhouettes")
					if is_instance_valid(manager):
						var body: Control = manager.get("team").bodies.get("enemy_1")
						if is_instance_valid(body) and body.z_index > row["canvas"].z_index: airborne_above_rock_seen = true

func finish(board: Control, fixture: Dictionary, result: Dictionary, crop: Rect2i) -> void:
	var states: Array[Dictionary]
	states.append(fixture["state"])
	for beat: Dictionary in result["beats"]:
		states.append(beat["after"])
		for field: String in ["terrain", "surfaces", "grid"]:
			if beat["before"].get(field) != beat["after"].get(field): changes.append({"field": field, "before": var_to_str(beat["before"].get(field)), "after": var_to_str(beat["after"].get(field))})
	var engine := Combat.new()
	for state: Dictionary in states:
		var visible: Dictionary = engine.umbra_visible_tile_lookup(state)
		for tile: Vector2i in Surfaces.tiles(state):
			if not visible.has(tile): continue
			for kind: String in ["rubble", "ice", "fire", "electrified"]:
				if Surfaces.has_surface(state, tile, kind) and not observed_surfaces.has("%s:%s" % [tile, kind]):
					var error: String = "Surface must draw during its recorded lifetime: %s %s" % [kind, tile]
					if not failures.has(error): failures.append(error)
	for terrain: Dictionary in result["final"].get("terrain", []):
		if not Surfaces.terrain_is_live(terrain): continue
		var tile: Vector2i = terrain["pos"]
		var rows: Array[Dictionary] = _terrain_rows(board, tile)
		if rows.is_empty(): failures.append("Final terrain has no production draw commands: " + str(tile))
		var count: int = 0
		for row: Dictionary in rows:
			count += row["commands"].size()
			if terrain.get("kind") == "crag_outcrop": final_rock_pixels_above_floor += pixels_above(polygons(row), floor_top(board, tile), crop).size()
		final_terrain.append({"tile": var_to_str(tile), "kind": terrain.get("kind"), "commands": count})
	for key: String in result["final"].get("surfaces", {}):
		var tile: Vector2i = Surfaces.tile_from_key(key)
		var expected_visible: bool = engine.is_tile_visible_to_player(result["final"], tile)
		for kind: String in ["rubble", "ice", "fire", "electrified"]:
			if not Surfaces.has_surface(result["final"], tile, kind): continue
			var drawn: bool = _surface_visible(board, tile, kind)
			final_surfaces.append({"tile": var_to_str(tile), "kind": kind, "production_layer_visible": drawn})
			if expected_visible and not drawn: failures.append("Final surface lacks its visible production layer: %s %s" % [kind, tile])
			if not expected_visible and drawn: failures.append("A dark tile reveals its final surface: %s %s" % [kind, tile])
	if fixture["id"] == "worldspine_pulse" and not _rise_complete():
		failures.append("Worldspine Outcrops must animate their rise and finish fully raised")
	if fixture["id"] == "rule_upheaval":
		var found: bool = (board.combat_state.get("terrain", []) as Array).any(func(t: Dictionary) -> bool: return t.get("pos") == fixture["state"]["enemies"][0]["pos"] and t.get("kind") == "crag_outcrop" and Surfaces.terrain_is_live(t))
		if not found: failures.append("Final recording board must retain the Outcrop on the marked tile")
		if final_rock_pixels_above_floor <= 0: failures.append("Final Outcrop must submit non-floor rock pixels above its tile")
		if not _rise_complete(): failures.append("Production Outcrop must animate its rise and finish fully raised")
		if not airborne_above_rock_seen: failures.append("Production throw body must draw above the rock while airborne")

func _rise_complete() -> bool:
	return rise_samples.has(1.0) and rise_samples.any(func(rise: float) -> bool: return rise > 0.0 and rise < 1.0)

func report() -> Dictionary:
	return {"changes": changes, "final_terrain": final_terrain, "final_surfaces": final_surfaces, "observed_surfaces": observed_surfaces.keys(), "minimum_margins_px": minimum_margins, "rise_samples": rise_samples, "airborne_above_rock_seen": airborne_above_rock_seen, "final_rock_pixels_above_floor": final_rock_pixels_above_floor, "native_pixels_above_floor": native_pixels_above_floor, "failures": failures}

func native_final(scene: Node, viewport: SubViewport, picture: Image, crop: Rect2i, tile: Vector2i, output: String) -> void:
	# Outside the raw action window: compare its settled final frame against
	# the identical board with only this rock removed. Restore the real state.
	var board: Control = scene.get("board_view")
	var paint: Array[PackedVector2Array]
	for row: Dictionary in _terrain_rows(board, tile): paint.append_array(polygons(row))
	var top: float = floor_top(board, tile)
	var region: Rect2i = Rect2i(bounds(paint)).intersection(Rect2i(Vector2i.ZERO, viewport.size))
	var transform: Transform2D = board.get_global_transform_with_canvas()
	Board.proof_hidden_terrain_tile = tile
	board._queue_scene_render_layer_for_tile(tile)
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
	var control: Image = viewport.get_texture().get_image()
	native_pixels_above_floor = 0
	if board.get_global_transform_with_canvas() != transform: failures.append("Rock pixel comparison must preserve the production board transform")
	if control == null or picture == null or control.get_size() != picture.get_size():
		failures.append("Rock final-frame pixel proof needs matching native images")
	else:
		for y: int in range(region.position.y, mini(region.end.y, floori(top))):
			for x: int in range(region.position.x, region.end.x):
				var point := Vector2(x + 0.5, y + 0.5)
				if not paint.any(func(polygon: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(point, polygon)): continue
				var a: Color = picture.get_pixel(x, y)
				var b: Color = control.get_pixel(x, y)
				if maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b))) > NATIVE_PIXEL_TOLERANCE: native_pixels_above_floor += 1
		var path: String = output.path_join("rule_upheaval_without_rock_1920x1080.png")
		control.save_png(path)
		print(path)
	if native_pixels_above_floor <= 0: failures.append("Native final frame must contain non-floor rock pixels above the marked tile")
	Board.proof_hidden_terrain_tile = Vector2i(-1, -1)
	board._queue_scene_render_layer_for_tile(tile)
	await scene.get_tree().process_frame
	await RenderingServer.frame_post_draw
