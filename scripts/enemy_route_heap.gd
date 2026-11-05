extends RefCounted

# Stable minimum queue for the three-way route comparator. Parallel buffers
# retain capacity across searches and avoid one wrapper Dictionary per push.
var _entries: Array[Dictionary]
var _sequences: Array[int]
var _size: int = 0
var _compare: Callable
var _next_sequence: int = 0

func _init(compare: Callable) -> void:
	_compare = compare

func clear() -> void:
	_size = 0
	_next_sequence = 0

func is_empty() -> bool:
	return _size == 0

func push(record: Dictionary) -> void:
	var sequence: int = _next_sequence
	_next_sequence += 1
	var index: int = _size
	_size += 1
	if index == _entries.size():
		_entries.append(record)
		_sequences.append(sequence)
	while index > 0:
		var parent: int = (index - 1) / 2
		if not _entry_precedes(record, sequence, parent): break
		_entries[index] = _entries[parent]
		_sequences[index] = _sequences[parent]
		index = parent
	_entries[index] = record
	_sequences[index] = sequence

func pop() -> Dictionary:
	var first: Dictionary = _entries[0]
	_size -= 1
	var last: Dictionary = _entries[_size]
	var sequence: int = _sequences[_size]
	if _size > 0:
		var index: int = 0
		while index * 2 + 1 < _size:
			var child: int = index * 2 + 1
			if child + 1 < _size and _entry_precedes(_entries[child + 1], _sequences[child + 1], child): child += 1
			var order: int = _compare.call(_entries[child], last)
			if order > 0 or (order == 0 and _sequences[child] >= sequence): break
			_entries[index] = _entries[child]
			_sequences[index] = _sequences[child]
			index = child
		_entries[index] = last
		_sequences[index] = sequence
	return first

func _entry_precedes(record: Dictionary, sequence: int, index: int) -> bool:
	var order: int = _compare.call(record, _entries[index])
	return order < 0 or (order == 0 and sequence < _sequences[index])
