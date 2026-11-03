extends RefCounted

# Exact, owned, bounded memoization for pure preview queries. Hashes only index
# candidates: collisions and in-place input changes still require full equality.
const CAPACITY: int = 128
var _entries: Dictionary = {}
var _order: Array[int]
var _last_inputs: Array = []

func resolve(inputs: Array, compute: Callable) -> Variant:
	var key: int = hash(inputs)
	var entry: Dictionary = _entries.get(key, {})
	if not entry.is_empty() and entry["inputs"] == inputs:
		_last_inputs = entry["inputs"]
		return entry["result"].duplicate(true)
	var result: Variant = compute.call()
	if not _entries.has(key):
		if _order.size() >= CAPACITY: _entries.erase(_order.pop_front())
		_order.append(key)
	_entries[key] = {"inputs": _owned_inputs(inputs), "result": result.duplicate(true)}
	return result

func _owned_inputs(inputs: Array) -> Array:
	# Battlefield forecasts include every raw catalog beside the changing board.
	# Deep-copying those same catalogs into all 128 entries in several memos
	# retained hundreds of MB. Share only our own equal snapshots; never borrow
	# caller containers, key only by identity, or weaken collision validation.
	var owned: Array = []
	for index: int in range(inputs.size()):
		var value: Variant = inputs[index]
		if index < _last_inputs.size() and typeof(value) == typeof(_last_inputs[index]) and value == _last_inputs[index]:
			owned.append(_last_inputs[index])
		elif value is Dictionary or value is Array:
			owned.append(value.duplicate(true))
		else:
			owned.append(value)
	_last_inputs = owned
	return owned
