extends RefCounted

## Ambient sprites always submit the same two triangles for each ordered quad.
## Retain topology by the exact submitted count; positions, UVs and colours are
## still rebuilt every draw. Callers only read the published packed arrays;
## growing the private template never resizes a previously published prefix.
const CACHE_CAPACITY: int = 128
var _complete := PackedInt32Array()
var _counts: Dictionary = {}
var _order: Array[int]

func for_sprites(count: int) -> PackedInt32Array:
	if _counts.has(count): return _counts[count]
	var first_sprite: int = _complete.size() / 6
	_complete.resize(maxi(_complete.size(), count * 6))
	for sprite: int in range(first_sprite, count):
		var vertex: int = sprite * 4
		var index: int = sprite * 6
		_complete[index] = vertex
		_complete[index + 1] = vertex + 1
		_complete[index + 2] = vertex + 2
		_complete[index + 3] = vertex
		_complete[index + 4] = vertex + 2
		_complete[index + 5] = vertex + 3
	var indices: PackedInt32Array = _complete.slice(0, count * 6)
	if _order.size() >= CACHE_CAPACITY: _counts.erase(_order.pop_front())
	_order.append(count)
	_counts[count] = indices
	return indices
