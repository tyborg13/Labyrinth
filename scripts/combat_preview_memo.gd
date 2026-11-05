extends RefCounted

# Exact, owned, bounded memoization for pure preview queries. Hashes only index
# candidates: collisions and in-place input changes still require full equality.
const CAPACITY: int = 128
var _entries: Dictionary = {}
var _order: Array[int]
var _last_inputs: Array = []
var _signature_serial: int = 0

# Tokens are exact and local to this memo. Retain the complete owned inputs;
# neither hashes nor caller container identities establish a revision. A token
# is never reused, even after eviction, so downstream entries cannot go stale.
func exact_signature(inputs: Array) -> int:
	return int(resolve_repeated(inputs, _next_signature)[0])

func _next_signature() -> Array:
	_signature_serial += 1
	return [_signature_serial]

# Use this entry point only for expensive full-input queries that commonly repeat.
func resolve_repeated(inputs: Array, compute: Callable) -> Variant:
	return resolve(inputs, compute, null, true, true)

# An optional cheap index may omit dependencies, but never replaces the complete
# owned equality check below. In-place edits and index/hash collisions still miss.
# Only consumers that copy before publishing may opt out of the result copy;
# they must never mutate the borrowed entry. Default callers retain private data.
func resolve(inputs: Array, compute: Callable, index: Variant = null, copy_result: bool = true, check_latest: bool = false) -> Variant:
	# Only repeated full-input queries probe the newest live FIFO bucket. Other
	# callers go directly to their index without paying for another validation.
	if check_latest and not _order.is_empty():
		var newest: Dictionary = _entries.get(_order.back(), {})
		if not newest.is_empty() and newest["inputs"] == inputs:
			_last_inputs = newest["inputs"]
			return newest["result"].duplicate(true) if copy_result else newest["result"]
	var key: int = hash(inputs if index == null else index)
	var entry: Dictionary = _entries.get(key, {})
	if not entry.is_empty() and entry["inputs"] == inputs:
		_last_inputs = entry["inputs"]
		return entry["result"].duplicate(true) if copy_result else entry["result"]
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
