extends RefCounted

# Keep the rest forecast alongside recent target forecasts as selection keys
# change. Compare full owned inputs, including RNG, history and Umbra data.
const SOURCE_LIMIT: int = 8
var _entries: Array[Dictionary]

func remember(state: Dictionary, result: Dictionary) -> void:
	for index: int in range(_entries.size()):
		if _entries[index]["state"] == state:
			_entries.remove_at(index)
			break
	_entries.push_front({"state": state.duplicate(true), "summary": result.duplicate(true)})
	if _entries.size() > SOURCE_LIMIT: _entries.pop_back()

# Null is the miss sentinel. A computed empty summary is still a hit.
func lookup(state: Dictionary) -> Variant:
	for index: int in range(_entries.size()):
		var entry: Dictionary = _entries[index]
		if entry["state"] == state:
			if index > 0:
				_entries.remove_at(index)
				_entries.push_front(entry)
			return (entry["summary"] as Dictionary).duplicate(true)
	return null

func clear() -> void:
	_entries.clear()
