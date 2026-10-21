extends RefCounted

# Exact, owned, bounded memoization for pure preview queries. Hashes only index
# candidates: collisions and in-place input changes still require full equality.
const CAPACITY: int = 128
var _entries: Dictionary = {}
var _order: Array[int]

func resolve(inputs: Array, compute: Callable) -> Variant:
	var key: int = hash(inputs)
	var entry: Dictionary = _entries.get(key, {})
	if not entry.is_empty() and entry["inputs"] == inputs: return entry["result"].duplicate(true)
	var result: Variant = compute.call()
	if not _entries.has(key):
		if _order.size() >= CAPACITY: _entries.erase(_order.pop_front())
		_order.append(key)
	_entries[key] = {"inputs": inputs.duplicate(true), "result": result.duplicate(true)}
	return result
