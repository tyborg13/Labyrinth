extends RefCounted
## Receipts on the existing forecast copy, never live/save state. Observe action
## boundaries before turn-start consumption so Shock/Freeze do not disappear.
const KEY: String = "_pass_forecast_status_receipt"
const FIELDS: Array = ["shock", "freeze", "bleed", "immobilize", "chilled", "expose", "petrify", "stagger"]

static func mark(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in FIELDS: result[field] = int(state.get("player", {}).get(field, 0))
	return result

static func begin(state: Dictionary) -> void:
	if not state.has(KEY): state[KEY] = {"last": mark(state), "gains": {}}

static func observe(state: Dictionary) -> void:
	if not state.has(KEY): return
	var receipt: Dictionary = (state[KEY] as Dictionary).duplicate(true)
	var now: Dictionary = mark(state)
	for field: String in FIELDS:
		var gain: int = maxi(0, int(now[field]) - int(receipt["last"].get(field, 0)))
		if gain > 0: receipt["gains"][field] = int(receipt["gains"].get(field, 0)) + gain
	receipt["last"] = now
	state[KEY] = receipt

static func callback(engine: RefCounted, accepted: Callable = Callable()) -> Callable:
	return func(state: Dictionary) -> void:
		observe(state)
		if accepted.is_valid(): accepted.call(state)

static func gains(state: Dictionary) -> Dictionary:
	return (state.get(KEY, {}).get("gains", {}) as Dictionary).duplicate()
