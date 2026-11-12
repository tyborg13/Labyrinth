extends RefCounted

# Seed coefficients and exact prepared rosters, private to one foreground canvas.
# Retain no alpha or clock samples. Moving to another room drops the
# previous room's entries; the bound is that room's pillars × sides × motes.
const HASH_COUNT: int = 48
var _room_coord: Variant = null
var _templates: Dictionary = {}

func resolve(room_coord: Vector2i, seed: int, build: Callable) -> RefCounted:
	if _room_coord != room_coord:
		_room_coord = room_coord
		_templates.clear()
		_sides.clear()
	if not _templates.has(seed): _templates[seed] = build.call(seed)
	return _templates[seed]

# One prepared roster per tile/side in the current room. Exact value snapshots
# include texture identities/sizes and fitted width; no clock or pose is cached.
class PreparedMote:
	extends RefCounted
	var particle: RefCounted
	var seed: int
	var width: float
	var draw_size: Vector2
	var texture: Texture2D
	var soft_texture: Texture2D
	var glow_texture: Texture2D

var _sides: Dictionary = {}

func for_side(room_coord: Vector2i, tile: Vector2i, side: String, tile_width: float, materials: Array, count: int, seed_for: Callable, build: Callable, min_width: float, max_width: float, columns: int) -> Array[PreparedMote]:
	# resolve() owns the room bound for both seed coefficients and these rosters.
	if _room_coord != room_coord:
		_room_coord = room_coord
		_templates.clear()
		_sides.clear()
	var key: String = "%d,%d/%s" % [tile.x, tile.y, side]
	var inputs: Array = [tile_width, materials, count, min_width, max_width, columns, seed_for, build]
	var entry: Dictionary = _sides.get(key, {})
	if entry.is_empty() or entry["inputs"] != inputs:
		var motes: Array[PreparedMote]
		for index: int in range(count):
			var mote := PreparedMote.new()
			mote.seed = seed_for.call(tile, side, index)
			mote.particle = resolve(room_coord, mote.seed, build)
			var hashes: PackedFloat64Array = mote.particle.hashes
			mote.width = tile_width * lerpf(min_width, max_width, hashes[37])
			var variant: int = posmod(index + int(hashes[39] * float(columns)), columns)
			var material: Array = materials[variant]
			mote.texture = material[0]
			mote.soft_texture = material[1]
			mote.glow_texture = material[2]
			if mote.texture == null:
				mote.texture = mote.soft_texture
			mote.draw_size = Vector2(mote.width, mote.width)
			var texture_size: Vector2 = material[3]
			if texture_size.x > 0.0:
				mote.draw_size.y = mote.width * texture_size.y / texture_size.x
			motes.append(mote)
		entry = {"inputs": inputs.duplicate(true), "motes": motes}
		_sides[key] = entry
	return entry["motes"]

# Shared fire paint uses these seed-only factors for ambient particles and
# foreground embers. Keep each original floating-point operation in order.
static func fire_samples(hashes: PackedFloat64Array) -> PackedFloat64Array:
	return PackedFloat64Array([
		lerpf(7.0, 10.5, hashes[14]), hashes[15] * TAU,
		lerpf(1.6, 2.8, hashes[16]), hashes[17] * TAU,
		lerpf(2.2, 3.8, hashes[18]), hashes[19] * TAU,
		hashes[20] * TAU, hashes[21] * TAU, hashes[22] * TAU,
	])
