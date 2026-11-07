extends RefCounted

## This memo only formats the existing mesh/geometry key. Keep that historical
## format (including its rounding) so cache hits and submitted meshes are exact.
## Input equality uses the unrounded size; clearing a mesh cache needs no key
## invalidation because no geometry or resources are retained here.
const CACHE_CAPACITY: int = 128
var _textures: Dictionary = {}

func resolve(texture: Texture2D, size: Vector2, unit_type: String, art_enabled: bool) -> String:
	var id: int = texture.get_instance_id()
	var previous: Array = _textures.get(id, [])
	if not previous.is_empty() and previous[0] == size and previous[1] == unit_type and previous[2] == art_enabled:
		return previous[3]
	var key: String = "%d|%.3f,%.3f|%s|%s" % [id, size.x, size.y, unit_type, art_enabled]
	if _textures.size() >= CACHE_CAPACITY: _textures.clear()
	_textures[id] = [size, unit_type, art_enabled, key]
	return key
