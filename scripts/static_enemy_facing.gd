extends RefCounted

## Directional stills use the cutout policy and the displayed movement sample.
## Resolved combat state, action timing, logical rects and saves are untouched.
const Facing = preload("res://scripts/enemy_cutout_facing.gd")
const Data = preload("res://scripts/game_data.gd")
var _mirrored_textures: Dictionary = {}

static func handles(type: String) -> bool:
	if type in ["hoarfrost_seer", "arc_thrall"]: return false
	if type == "gust_shrike" and preload("res://scripts/gust_shrike_cutout/renderer.gd").available(): return false
	return not str(Data.enemy_def(type).get("art_rear_path", "")).is_empty()

static func presentation_for(board: Control, state: Dictionary, source: Dictionary, previous: Dictionary) -> Dictionary:
	var facings: Dictionary = {}
	var old: Dictionary = previous.get("static_enemy_facings", {})
	var actors: Array[Dictionary]
	actors.assign(state.get("enemies", []))
	actors.append_array(source.get("death_animation_units", []))
	var player: Vector2i = (state.get("player", {}) as Dictionary).get("pos", Vector2i.ZERO)
	var positions: Dictionary = source.get("unit_world_positions", {})
	var draw_tiles: Dictionary = source.get("unit_draw_tiles", {})
	var previous_positions: Dictionary = previous.get("unit_world_positions", {})
	var effect: Dictionary = source.get("effect", {})
	for unit: Dictionary in actors:
		var type: String = str(unit.get("type", ""))
		if not handles(type): continue
		var key: String = "enemy_%d" % int(unit.get("id", -1))
		var tile: Vector2i = unit.get("pos", Vector2i.ZERO)
		var footprint: Vector2i = board._resolved_unit_footprint(unit)
		var direction: Dictionary = Facing.direction_for_delta(player * 2 - (tile * 2 + footprint - Vector2i.ONE))
		if bool(unit.get("death_animation", false)) or int(unit.get("hp", 0)) <= 0:
			direction = old.get(key, direction)
		elif positions.has(key):
			# World samples retain the current segment direction even after the
			# nearest draw tile has changed. Invert the board's 2:1 projection.
			var start: Vector2 = previous_positions.get(key, board.world_position_for_unit_origin(unit, tile))
			var delta: Vector2 = (positions[key] as Vector2) - start
			if not delta.is_zero_approx():
				var projected := Vector2(delta.x / board._tile_width() + delta.y / board._tile_height(),
					-delta.x / board._tile_width() + delta.y / board._tile_height())
				direction = direction_for_projected_delta(projected)
			else:
				var target: Vector2i = draw_tiles.get(key, tile)
				direction = Facing.direction_for_delta(target - tile) if target != tile else old.get(key, direction)
		elif str(effect.get("actor_key", "")) == key and effect.has("from") and effect.has("to"):
			var delta: Vector2i = (effect["to"] as Vector2i) - (effect["from"] as Vector2i)
			if delta != Vector2i.ZERO: direction = Facing.direction_for_delta(delta)
		elif positions.has("player") or (source.get("unit_draw_tiles", {}) as Dictionary).has("player"):
			# A pending hero destination must not turn observers early.
			direction = old.get(key, direction)
		facings[key] = direction
	var result: Dictionary = source.duplicate(false)
	result["static_enemy_facings"] = facings
	return result

static func direction_for_projected_delta(delta: Vector2) -> Dictionary:
	if absf(delta.x) >= absf(delta.y) and not is_zero_approx(delta.x):
		return Facing.direction_for_delta(Vector2i(1 if delta.x > 0 else -1, 0))
	return Facing.direction_for_delta(Vector2i(0, 1 if delta.y >= 0 else -1))

func texture_for(board: Control, unit: Dictionary, front: Texture2D, rear: Texture2D) -> Texture2D:
	var key: String = "enemy_%d" % int(unit.get("id", -1))
	var direction: Dictionary = (board.presentation.get("static_enemy_facings", {}) as Dictionary).get(key, {})
	var texture: Texture2D = rear if str(direction.get("facing", "front")) == "rear" and rear != null else front
	if texture == null or not bool(direction.get("mirrored", false)): return texture
	var id: int = texture.get_instance_id()
	if not _mirrored_textures.has(id):
		var image: Image = texture.get_image().duplicate() as Image
		image.flip_x()
		var mirrored: ImageTexture = ImageTexture.create_from_image(image)
		mirrored.set_meta("asset_source_path", str(texture.get_meta("asset_source_path", texture.resource_path)) + "|mirrored")
		_mirrored_textures[id] = mirrored
	var mirrored: Texture2D = _mirrored_textures[id]
	var cache: Dictionary = board.get("_unit_shadow_polygon_cache")
	if not cache.has(mirrored.get_instance_id()):
		board._install_unit_shadow_precomputed_data(texture)
		cache[mirrored.get_instance_id()] = mirror_shadow_data(board._unit_shadow_data_for_texture(texture), texture.get_width())
	return mirrored

static func mirror_shadow_data(source: Dictionary, canvas_width: float) -> Dictionary:
	var result: Dictionary = source.duplicate(true)
	var polygons: Array[PackedVector2Array]
	var triangles: Array[PackedInt32Array]
	for polygon: PackedVector2Array in source.get("polygons", []):
		var flipped := PackedVector2Array()
		for point: Vector2 in polygon: flipped.append(Vector2(-point.x, point.y))
		polygons.append(flipped)
	for indices: PackedInt32Array in source.get("triangulations", []):
		var flipped: PackedInt32Array = indices.duplicate()
		for index: int in range(0, flipped.size(), 3):
			var temp: int = flipped[index]
			flipped[index] = flipped[index + 1]
			flipped[index + 1] = temp
		triangles.append(flipped)
	var bounds: Rect2 = source.get("bounds", Rect2())
	result["bounds"] = Rect2(Vector2(canvas_width - bounds.end.x, bounds.position.y), bounds.size)
	result["polygons"] = polygons
	result["triangulations"] = triangles
	return result
