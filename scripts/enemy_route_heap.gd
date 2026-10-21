extends RefCounted

# Stable minimum queue for the existing enemy route comparator. Equal records
# retain insertion order, exactly like the former linear minimum scan. Neither
# records nor their priority fields are modified by this container.
var _entries: Array[Dictionary]
var _precedes: Callable
var _next_sequence: int = 0

func _init(precedes: Callable) -> void:
	_precedes = precedes

func is_empty() -> bool:
	return _entries.is_empty()

func push(record: Dictionary) -> void:
	var entry: Dictionary = {"record": record, "sequence": _next_sequence}
	_next_sequence += 1
	_entries.append(entry)
	var index: int = _entries.size() - 1
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _entry_precedes(entry, _entries[parent]): break
		_entries[index] = _entries[parent]
		index = parent
	_entries[index] = entry

func pop() -> Dictionary:
	var first: Dictionary = _entries[0]
	var last: Dictionary = _entries.pop_back()
	if not _entries.is_empty():
		var index: int = 0
		while index * 2 + 1 < _entries.size():
			var child: int = index * 2 + 1
			if child + 1 < _entries.size() and _entry_precedes(_entries[child + 1], _entries[child]): child += 1
			if not _entry_precedes(_entries[child], last): break
			_entries[index] = _entries[child]
			index = child
		_entries[index] = last
	return first["record"]

func _entry_precedes(a: Dictionary, b: Dictionary) -> bool:
	if _precedes.call(a["record"], b["record"]): return true
	if _precedes.call(b["record"], a["record"]): return false
	return int(a["sequence"]) < int(b["sequence"])
