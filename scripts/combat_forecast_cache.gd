extends RefCounted

# One complete input snapshot survives selection-key changes. No field subset
# or hash can omit a status, RNG, history, or Umbra information dependency.
# Own both values: the live state and the per-selection summary may be mutated.
var _state: Dictionary = {}
var _summary: Dictionary = {}
var _ready: bool = false

func remember(state: Dictionary, result: Dictionary) -> void:
	_state = state.duplicate(true)
	_summary = result.duplicate(true)
	_ready = true

func matches(state: Dictionary) -> bool:
	return _ready and _state == state

func summary() -> Dictionary:
	return _summary.duplicate(true)

func clear() -> void:
	_state = {}
	_summary = {}
	_ready = false
