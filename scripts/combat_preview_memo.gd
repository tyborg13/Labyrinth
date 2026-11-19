extends RefCounted

# Exact, owned, bounded memoization for pure preview queries. Hashes only index
# candidates: collisions and in-place input changes still require full equality.
const CAPACITY: int = 128
var _entries: Dictionary = {}
var _order: Array[int]
var _last_inputs: Array = []
var _latest_entry: Dictionary = {}
var _signature_serial: int = 0

# Tokens are exact and local to this memo. Retain the complete owned inputs;
# neither hashes nor caller container identities establish a revision. A token
# is never reused, even after eviction, so downstream entries cannot go stale.
func exact_signature(inputs: Array) -> int:
	return int(resolve(inputs, _next_signature, null, false, true)[0])

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
func resolve(inputs: Array, compute: Callable, index: Variant = null, copy_result: bool = true, check_latest: bool = false, profile: RefCounted = null) -> Variant:
	# Probe the last resolved entry, including hits in older FIFO buckets. Other
	# callers go directly to their index without paying for another validation.
	if profile != null: profile.begin("memo_equality")
	if check_latest:
		var newest: Dictionary = _latest_entry
		if not newest.is_empty() and newest["inputs"] == inputs:
			_last_inputs = newest["inputs"]
			if profile != null: profile.end()
			return _copy_result(newest["result"], copy_result, profile)
	if profile != null:
		profile.end()
		profile.begin("hashing")
	var key: int = hash(inputs if index == null else index)
	if profile != null:
		profile.end()
		profile.begin("memo_equality")
	var entry: Dictionary = _entries.get(key, {})
	if not entry.is_empty() and entry["inputs"] == inputs:
		_latest_entry = entry
		_last_inputs = entry["inputs"]
		if profile != null: profile.end()
		return _copy_result(entry["result"], copy_result, profile)
	if profile != null: profile.end()
	var result: Variant = compute.call()
	if not _entries.has(key):
		if _order.size() >= CAPACITY: _entries.erase(_order.pop_front())
		_order.append(key)
	if profile != null: profile.begin("copies")
	_latest_entry = {"inputs": _owned_inputs(inputs), "result": result.duplicate(true)}
	if profile != null: profile.end()
	_entries[key] = _latest_entry
	return result

func _copy_result(result: Variant, copy_result: bool, profile: RefCounted) -> Variant:
	if not copy_result: return result
	if profile != null: profile.begin("copies")
	var owned: Variant = result.duplicate(true)
	if profile != null: profile.end()
	return owned

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
			# A rest preview often passes the committed state in both slots.
			# Share the already-owned snapshot of an identical container.
			var snapshot: Variant = null
			for previous: int in range(index):
				if is_same(value, inputs[previous]):
					snapshot = owned[previous]
					break
			owned.append(snapshot if snapshot != null else value.duplicate(true))
		else:
			owned.append(value)
	_last_inputs = owned
	return owned
