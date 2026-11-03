extends RefCounted

# Seed-only coefficients, private to one foreground canvas. Retain no geometry,
# texture selection, alpha or clock samples. Moving to another room drops the
# previous room's entries; the bound is that room's pillars × sides × motes.
const HASH_COUNT: int = 48
var _room_coord: Variant = null
var _templates: Dictionary = {}

func resolve(room_coord: Vector2i, seed: int, build: Callable) -> RefCounted:
	if _room_coord != room_coord:
		_room_coord = room_coord
		_templates.clear()
	if not _templates.has(seed): _templates[seed] = build.call(seed)
	return _templates[seed]
