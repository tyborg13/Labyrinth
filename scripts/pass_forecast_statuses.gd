extends RefCounted
## Receipts on the existing forecast copy, never live/save state. Observe action
## boundaries before turn-start consumption so Shock/Freeze do not disappear.
const Keywords = preload("res://scripts/card_keyword_rules.gd")
const KEY: String = "_pass_forecast_status_receipt"
const FIELDS: Array = ["shock", "freeze", "immobilize", "chilled", "expose", "petrify", "stagger"]

static func mark(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for field: String in FIELDS: result[field] = int(state.get("player", {}).get(field, 0))
	result["stagger"] = Keywords.player_stagger_delay(state)
	return result

# Announced riders keep their authored conditions. The forecast supplies the
# allowance left when that enemy first acts, after earlier hits and room beats.
static func note_enemy_stagger(cursor: Dictionary, enemy: Dictionary, before: Dictionary) -> void:
	if not bool(cursor.get("losses_only", false)) or bool(cursor.get("rng_unknown", false)): return
	var id: int = int(enemy["id"])
	if int(cursor.get("enemy_activations", {}).get(id, 0)) != 1: return
	var applied: int = Keywords.player_stagger_delay(before)
	if applied <= 0: return
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if int(action.get("stagger", 0)) <= 0 and int(action.get("surface_bonus", {}).get("stagger", 0)) <= 0:
			continue
		var limits: Dictionary = cursor.get_or_add("enemy_stagger_limits", {})
		limits["enemy_%d" % id] = Keywords.stagger_delay("", Keywords.STAGGER_TURN_CAP, applied)
		return

static func limit_stagger_rows(rows: Array, allowance: int) -> void:
	for row: Array in rows:
		for index: int in range(row.size()):
			var token: Dictionary = row[index]
			if str(token.get("icon", "")) != "stagger": continue
			var amount: int = int(token.get("value", 0))
			var shown: int = mini(amount, allowance)
			allowance -= shown
			if shown == amount: continue
			var updated: Dictionary = token.duplicate()
			updated["value"] = shown
			updated["tooltip_amount"] = shown
			row[index] = updated

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
