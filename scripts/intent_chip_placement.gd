extends RefCounted

## A chip belongs at its owner's feet, even when local HUD is too crowded.
const MAX_SLIDE: float = 24.0
const SIDE_MARGIN: float = 0.15
const HERO_WEIGHT: float = 2.0
const UNIT_WEIGHT: float = 1.0
const PROP_WEIGHT: float = 0.5
const SOLE_BAND_FRACTION: float = 0.06
const SOLE_CLEARANCE: float = 4.0
const REST_CACHE_META: StringName = &"intent_chip_rest_silhouettes"
# Cold-path counters for focused cache proof; no timers or frame sampling.
static var sole_clip_count: int = 0
static var rest_silhouette_build_count: int = 0
const Assets = preload("res://scripts/asset_loader.gd")
const Actor = preload("res://scripts/actor_presentation.gd")
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const StaticFacing = preload("res://scripts/static_enemy_facing.gd")
const SurfaceRules = preload("res://scripts/board_surface_rules.gd")
const HeroRest = preload("res://scripts/intent_chip_hero_rest.gd")

## Exact polygon intersection area, in weighted board pixels. Opaque polygons
## from a texture are disjoint; different things contribute independently.
## Earlier chips are deliberately absent: they are HUD, never coverage.
static func coverage(rect: Rect2, silhouettes: Array, owner_key: String = "") -> float:
	var total: float = 0.0
	var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
	for silhouette: Dictionary in silhouettes:
		if not owner_key.is_empty() and str(silhouette.get("key", "")) == owner_key: continue
		var bounds: Rect2 = silhouette["rect"]
		if not rect.intersects(bounds, false): continue
		var area: float = 0.0
		var polygons: Array = silhouette.get("polygons", [])
		if polygons.is_empty():
			area = rect.intersection(bounds).get_area()
		else:
			for polygon: PackedVector2Array in polygons:
				for intersection: PackedVector2Array in Geometry2D.intersect_polygons(clip, polygon):
					area += _polygon_area(intersection)
			for hole: PackedVector2Array in silhouette.get("holes", []):
				for intersection: PackedVector2Array in Geometry2D.intersect_polygons(clip, hole):
					area -= _polygon_area(intersection)
		total += area * float(silhouette["weight"])
	return total

static func _polygon_area(polygon: PackedVector2Array) -> float:
	var twice: float = 0.0
	# Relative coordinates avoid cancellation at large board positions.
	for index: int in range(1, polygon.size() - 1):
		twice += (polygon[index] - polygon[0]).cross(polygon[index + 1] - polygon[0])
	return absf(twice) * 0.5

## The bottom 6% of the cached rest silhouette marks contact with the floor.
## Its tight clipped bounds plus 4px are a hard obstacle for this owner only;
## coverage and the preferred-side policy continue to ignore the owner.
static func owner_sole_obstacle(silhouettes: Array, owner_key: String) -> Rect2:
	if owner_key.is_empty(): return Rect2()
	for shape: Dictionary in silhouettes:
		if str(shape.get("key", "")) != owner_key: continue
		return shape["sole_obstacle"] if shape.has("sole_obstacle") else _build_sole_obstacle(shape)
	return Rect2()

static func _build_sole_obstacle(shape: Dictionary) -> Rect2:
	var bounds: Rect2 = shape["rect"]
	var band := Rect2(bounds.position.x, bounds.end.y - bounds.size.y * SOLE_BAND_FRACTION, bounds.size.x, bounds.size.y * SOLE_BAND_FRACTION)
	if not band.has_area(): return Rect2()
	var polygons: Array = shape.get("polygons", [])
	if polygons.is_empty(): return band.grow(SOLE_CLEARANCE)
	var clip := PackedVector2Array([band.position, Vector2(band.end.x, band.position.y), band.end, Vector2(band.position.x, band.end.y)])
	var sole := Rect2()
	var has_point: bool = false
	for polygon: PackedVector2Array in polygons:
		var fragments: Array[PackedVector2Array]
		sole_clip_count += 1
		fragments.assign(Geometry2D.intersect_polygons(clip, polygon))
		for hole: PackedVector2Array in shape.get("holes", []):
			var remaining: Array[PackedVector2Array]
			for fragment: PackedVector2Array in fragments:
				sole_clip_count += 1
				remaining.append_array(Geometry2D.clip_polygons(fragment, hole))
			fragments = remaining
		for fragment: PackedVector2Array in fragments:
			for point: Vector2 in fragment:
				if not has_point:
					sole = Rect2(point, Vector2.ZERO)
					has_point = true
				else: sole = sole.expand(point)
	return sole.grow(SOLE_CLEARANCE) if sole.has_area() else Rect2()

static func rest_silhouettes(board: Control, units: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var live_keys: Dictionary = {}
	for unit: Dictionary in units:
		if bool(unit.get("death_animation", false)): continue
		if not (board.call("_umbra_actor_clip_for_unit", unit) as Dictionary).is_empty(): continue
		var shape: Dictionary = unit_rest_silhouette(board, unit)
		if not shape.is_empty():
			result.append(shape)
			live_keys[shape["key"]] = true
	var rest_cache: Dictionary = board.get_meta(REST_CACHE_META, {})
	for key: String in rest_cache.keys():
		if not live_keys.has(key): rest_cache.erase(key)
	# Static board obstruction geometry is already cached per submission. Scene
	# props use their rest texture separately so campfire idle frames never enter.
	var grid: Array = (board.get("combat_state") as Dictionary).get("grid", [])
	for candidate: Dictionary in board.call("_foreground_obstruction_candidates"):
		var kind: String = str(candidate.get("tile_id", ""))
		if kind in ["scene_prop", "terrain"]: continue
		var tile: Vector2i = candidate.get("tile", Vector2i(-1, -1))
		if not board.call("_board_tile_is_visible_to_player", tile): continue
		var rect: Rect2 = candidate["rect"]
		var texture: Texture2D = candidate.get("texture")
		if texture != null:
			rect = board.call("_texture_used_draw_rect", texture, rect)
		elif kind == "wall":
			# Boundary corners draw only half a texture. Tighten in that source
			# region before mapping it to the half-width destination rectangle.
			for segment: Dictionary in board.call("_boundary_prop_segments", kind, grid, tile):
				if segment["draw_rect"] != rect: continue
				texture = segment["texture"]
				var source: Rect2 = segment["source_rect"]
				var used: Rect2 = Rect2(board.call("_texture_used_rect", texture)).intersection(source)
				rect = Rect2(rect.position + (used.position - source.position) * rect.size / source.size, used.size * rect.size / source.size)
				break
		else:
			texture = board.call("_door_texture_for_tile", grid, tile) if kind == "door" else (board.get("_prop_textures") as Dictionary).get(kind)
			if texture != null: rect = board.call("_texture_used_draw_rect", texture, rect)
		if rect.has_area(): result.append({"rect": rect, "weight": PROP_WEIGHT})
	for terrain: Dictionary in (board.get("combat_state") as Dictionary).get("terrain", []):
		var tile: Vector2i = terrain.get("pos", Vector2i(-1, -1))
		if not SurfaceRules.terrain_is_live(terrain) or not board.call("_board_tile_is_visible_to_player", tile): continue
		var kind: String = str(board.call("_terrain_art_kind", str(terrain.get("kind", ""))))
		var texture: Texture2D = (board.get("_terrain_textures") as Dictionary).get(kind)
		if texture == null: continue
		var rect: Rect2 = board.call("_texture_used_draw_rect", texture, board.call("_terrain_rect_for_tile", tile, texture, kind))
		if rect.has_area(): result.append({"rect": rect, "weight": PROP_WEIGHT})
	for prop: Dictionary in (board.get("presentation") as Dictionary).get("scene_props", []):
		if not board.call("_board_tile_is_visible_to_player", prop.get("tile", Vector2i(-1, -1))): continue
		var kind: String = str(prop.get("kind", ""))
		var texture: Texture2D = (board.get("_scene_prop_textures") as Dictionary).get("watch_brazier_dark" if kind == "watch_brazier_lit" else kind)
		if texture == null: continue
		var rect: Rect2 = board.call("_texture_used_draw_rect", texture, board.call("_scene_prop_rect", texture, prop))
		if rect.has_area(): result.append({"rect": rect, "weight": PROP_WEIGHT})
	return result

static func unit_rest_silhouette(board: Control, unit: Dictionary) -> Dictionary:
	var type: String = str(unit.get("type", ""))
	var texture: Texture2D = (board.get("_unit_textures") as Dictionary).get(type)
	if texture == null: return {}
	var direction: Dictionary = {}
	var renderer: Node = board.call("unit_cutout_renderer", unit)
	if is_instance_valid(renderer): direction = {"facing": renderer.get("facing"), "mirrored": renderer.get("mirrored")}
	elif board.call("_unit_uses_cutout", unit): direction = Facing.direction_for_delta(((board.get("combat_state") as Dictionary).get("player", {}) as Dictionary).get("pos", Vector2i.ZERO) - (unit.get("pos", Vector2i.ZERO) as Vector2i))
	var directional_still: bool = StaticFacing.handles(type)
	if directional_still: direction = (board.get("presentation") as Dictionary).get("static_enemy_facings", {}).get(str(unit.get("key", "")), {})
	var rear: bool = str(direction.get("facing", "front")) == "rear"
	var mirrored: bool = bool(direction.get("mirrored", false))
	if directional_still:
		# This selects only cached directional stills, never idle/action frames.
		texture = (board.get("_static_enemy_art") as RefCounted).texture_for(board, unit, texture, (board.get("_unit_rear_textures") as Dictionary).get(type))
		mirrored = false # The still and its shadow polygons are already reflected.
	else:
		var path: String = str(texture.get_meta("asset_source_path", texture.resource_path))
		var rear_path: String = path.replace("/front/", "/rear/").replace("front_", "rear_") if rear and type != "player" else path
		# Hero contours already contain both facings on the same source canvas.
		# Keep the prepared registration texture; a facing turn must not decode
		# another image inside this geometry-only coverage query.
		if is_instance_valid(renderer) and type != "player":
			var rigs: Dictionary = renderer.get("rigs")
			var view: String = "rear" if rear else "front"
			if rigs.has(view):
				var rig: Node = rigs[view]
				var source: String = str((rig.get("layout") as Dictionary).get("rest_source", ""))
				if not source.is_empty(): rear_path = str(rig.call("_resolve", source)) if rig.has_method("_resolve") else source
		if rear_path != path:
			var rear_texture: Texture2D = Assets.load_texture_source_first(rear_path)
			if rear_texture != null: texture = rear_texture
	var center: Vector2 = board.call("_unit_center", unit)
	var draw: Rect2 = board.call("_unit_draw_rect_for_texture", unit, center, texture)
	if Actor.has_profile(type): draw.position = center - Actor.floor_anchor(type, "rear" if rear else "front", mirrored) * draw.size / Actor.SOURCE_SIZE
	var hero: bool = type == "player" and board.call("_unit_uses_cutout", unit)
	var data: Dictionary
	if hero:
		data = HeroRest.data_for("rear" if rear else "front")
	else:
		data = board.call("_unit_shadow_data_for_texture", texture)
	var bounds: Rect2 = data.get("bounds", Rect2())
	if not bounds.has_area(): return {}
	# The board owns these entries, never the shared source resource. Fetch the
	# board's cached alpha data first: a replacement/clear invalidates this
	# projection and its sole together. Facing, registration, position, scale
	# and role are the complete projection inputs; idle phase is absent.
	var key: String = str(unit.get("key", ""))
	var inputs: Array = [texture.get_size(), draw, bounds, mirrored, hero, str(unit.get("role", ""))]
	var rest_cache: Dictionary = board.get_meta(REST_CACHE_META, {})
	var cached: Dictionary = rest_cache.get(key, {})
	if cached.get("inputs", []) == inputs and is_same(cached.get("source"), data): return cached["shape"]
	rest_silhouette_build_count += 1
	var scale: Vector2 = draw.size / texture.get_size()
	var opaque := Rect2(draw.position + bounds.position * scale, bounds.size * scale)
	if mirrored: opaque.position.x = draw.end.x - bounds.end.x * scale.x
	var polygons: Array[PackedVector2Array]
	var holes: Array[PackedVector2Array]
	for source: PackedVector2Array in data.get("polygons", []) + data.get("holes", []):
		var polygon := PackedVector2Array()
		for point: Vector2 in source:
			var pixel: Vector2 = point if hero else bounds.position + Vector2(bounds.size.x * (point.x + 0.5), bounds.size.y * (point.y + 1.0))
			if mirrored: pixel.x = texture.get_width() - pixel.x
			polygon.append(draw.position + pixel * scale)
		if hero and not Geometry2D.is_polygon_clockwise(source): holes.append(polygon)
		else: polygons.append(polygon)
	var shape: Dictionary = {"key": key, "rect": opaque, "polygons": polygons, "holes": holes, "weight": HERO_WEIGHT if str(unit.get("role", "")) == "player" else UNIT_WEIGHT}
	# Only enemies own intent chips; hero/NPC coverage needs no sole clipping.
	if str(unit.get("role", "")) == "enemy": shape["sole_obstacle"] = _build_sole_obstacle(shape)
	rest_cache[key] = {"source": data, "inputs": inputs, "shape": shape}
	board.set_meta(REST_CACHE_META, rest_cache)
	return shape

## Exact nearest clear placement among axis-aligned obstacle/bounds edges.
## A closest clear point is a home projection onto an edge or an intersection
## of edges, so this finite grid includes it without a pixel-step approximation.
## only_preferred limits this same search to the coverage-chosen home.
static func find_clear(right: Rect2, left: Rect2, obstacles: Array, previous: Array, bounds: Rect2, prefer_left: bool = false, only_preferred: bool = false) -> Dictionary:
	var occupied: Array[Rect2]
	occupied.assign(obstacles)
	for chip: Dictionary in previous: occupied.append(chip["rect"])
	var best: Dictionary = {}
	var best_distance: float = INF
	# Equal distances keep the coverage-chosen side. Within each home prefer
	# vertical over horizontal; retain the previous above/below sign ordering.
	var homes: Array[Rect2]
	homes.append(left if prefer_left else right)
	if not only_preferred: homes.append(right if prefer_left else left)
	for home: Rect2 in homes:
		var nearby: Array[Rect2]
		var reach: Rect2 = home.grow(MAX_SLIDE)
		for rect: Rect2 in occupied:
			if reach.intersects(rect, false): nearby.append(rect)
		var x_values: Array[float]
		var y_values: Array[float]
		_add_axis(x_values, home.position.x, home.position.x)
		_add_axis(y_values, home.position.y, home.position.y)
		if bounds.has_area():
			_add_axis(x_values, bounds.position.x, home.position.x)
			_add_axis(x_values, bounds.end.x - home.size.x, home.position.x)
			_add_axis(y_values, bounds.position.y, home.position.y)
			_add_axis(y_values, bounds.end.y - home.size.y, home.position.y)
		for rect: Rect2 in nearby:
			_add_axis(x_values, rect.position.x - home.size.x, home.position.x)
			_add_axis(x_values, rect.end.x, home.position.x)
			_add_axis(y_values, rect.position.y - home.size.y, home.position.y)
			_add_axis(y_values, rect.end.y, home.position.y)
		# Stable signs match the original solver: above before below, right
		# before left. No inputs depend on draw-frame time or sprite motion.
		x_values.sort()
		x_values.reverse()
		y_values.sort()
		var home_best: Dictionary = {}
		var home_distance: float = INF
		var home_horizontal: float = INF
		for x: float in x_values:
			for y: float in y_values:
				var offset := Vector2(x, y) - home.position
				var distance: float = offset.length_squared()
				if distance > MAX_SLIDE * MAX_SLIDE or distance > best_distance or distance > home_distance: continue
				if distance == home_distance and absf(offset.x) >= home_horizontal: continue
				var rect := Rect2(Vector2(x, y), home.size)
				if bounds.has_area() and not bounds.encloses(rect): continue
				if not _clear(rect, nearby): continue
				home_distance = distance
				home_horizontal = absf(offset.x)
				home_best = {"rect": rect, "placement": "above" if y < home.position.y else "below" if y > home.position.y else "lower_right" if home == right else "lower_left"}
		if home_distance < best_distance:
			best_distance = home_distance
			best = home_best
	return best

static func _add_axis(values: Array[float], value: float, origin: float) -> void:
	if absf(value - origin) <= MAX_SLIDE and not values.has(value): values.append(value)

static func _clear(rect: Rect2, occupied: Array[Rect2]) -> bool:
	for obstacle: Rect2 in occupied:
		if rect.intersects(obstacle, false): return false
	return true
