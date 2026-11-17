extends "res://scripts/hero_facing_combat.gd"
## Read-only receipts around production resolvers, used ONLY on oracle copies.
const STATUS_FIELDS: Array = ["shock", "freeze", "chilled", "bleed", "expose", "immobilize", "burn", "burning", "poison", "marked"]
var receipts: Array[Dictionary]
var observing: bool = false

static func hero(state: Dictionary) -> Dictionary:
	var result: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	result["received"] = int(state.get("run_stats", {}).get("damage_received", 0))
	return result

static func delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var gains: Dictionary = {}
	for field: String in STATUS_FIELDS:
		if int(after.get(field, 0)) > int(before.get(field, 0)): gains[field] = int(after[field]) - int(before.get(field, 0))
	return {"hp": maxi(maxi(0, int(before.get("hp", 0)) - int(after.get("hp", 0))), int(after.get("received", 0)) - int(before.get("received", 0))),
		"block": maxi(0, int(before.get("block", 0)) - int(after.get("block", 0))), "stoneskin": maxi(0, int(before.get("stoneskin", 0)) - int(after.get("stoneskin", 0))),
		"moved": before.get("pos") != after.get("pos"), "statuses": gains}

func _resolve_enemy_action(state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator = null, followup: Dictionary = {}, bleed: Array[Dictionary] = TypedArrays.dictionaries([]), context: Dictionary = {}) -> Dictionary:
	if not observing: return super._resolve_enemy_action(state, index, action, rng, followup, bleed, context)
	var before: Dictionary = hero(state)
	var enemy: Dictionary = state["enemies"][index]
	var record: Dictionary = {"actor_tile": str(enemy.get("pos")), "clock": state.get("initiative_clock", 0), "source": str(enemy["type"]), "owner": _enemy_key(enemy), "intent": str(enemy.get("intent", {}).get("id", "")), "action": action.duplicate(true)}
	if GuardianCombatRules.handles(action): record["live_tiles"] = GuardianCombatRules.live_tiles(self, state, enemy, action).map(func(tile: Vector2i) -> String: return str(tile))
	var result: Dictionary = super._resolve_enemy_action(state, index, action, rng, followup, bleed, context)
	record.merge(delta(before, hero(result)))
	receipts.append(record)
	return result

func _resolve_board_attack(state: Dictionary, action: Dictionary, target: Vector2i, actor_kind: String = "player", actor_id: int = -1, trace: Dictionary = {}, supplied_impact: Array[Vector2i] = TypedArrays.vector2i([])) -> Dictionary:
	var rule: bool = observing and str(state.get("damage_context", {}).get("source_kind", "")) == "battlefield_rule"
	if not rule: return super._resolve_board_attack(state, action, target, actor_kind, actor_id, trace, supplied_impact)
	var before: Dictionary = hero(state)
	var plan: Dictionary = _board_attack_plan(state, action, supplied_impact, actor_kind)
	var routes: Array[Dictionary]
	for hit: Dictionary in plan.get("hits", []):
		if str(hit.get("key", "")) == "player": routes.append({"kind": hit.get("kind_trace", ""), "from": str(hit.get("from")), "to": str(hit.get("to")), "assisted": hit.get("electrically_assisted", false)})
	var result: Dictionary = super._resolve_board_attack(state, action, target, actor_kind, actor_id, trace, supplied_impact)
	var record: Dictionary = {"source": "peal_direct" if supplied_impact.has(before.get("pos")) else "peal_chain", "owner": "battlefield_rule", "intent": "peal", "action": action.duplicate(true), "tiles": supplied_impact.map(func(tile: Vector2i) -> String: return str(tile)), "hero_routes": routes}
	record.merge(delta(before, hero(result)))
	receipts.append(record)
	return result

# Planning invokes the resolver on private prediction copies. Those are not
# committed hits and must never enter the oracle receipts.
func enemy_intent_plan(state: Dictionary, enemy_index: int, intent: Dictionary = {}, movement_disabled: bool = false, attack_disabled: bool = false, use_memo: bool = true) -> Dictionary:
	var previous: bool = observing
	observing = false
	var result: Dictionary = super.enemy_intent_plan(state, enemy_index, intent, movement_disabled, attack_disabled, use_memo)
	observing = previous
	return result

func _assign_enemy_intent(state: Dictionary, enemy_index: int, rng: RandomNumberGenerator) -> void:
	var previous: bool = observing
	observing = false
	super._assign_enemy_intent(state, enemy_index, rng)
	observing = previous
