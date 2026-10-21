extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/enemy_mechanics/tether.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
static var _memo := preload("res://scripts/combat_preview_memo.gd").new()

# State-derived beam evidence is identical across focus/aim presentations. Keep
# the real resolver, but run it once per exact board/definition snapshot.
static func for_state(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(Data.enemy_def(str(enemy.get("type", ""))))
	return _memo.resolve([state, index, definitions, engine._relic_effects(state), Warband.order_for_objective(state.get("objective", {})), engine.get_script()], func() -> Dictionary: return _build(engine, state, index))

static func _build(engine: RefCounted, state: Dictionary, index: int) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var threat: Dictionary = engine.enemy_threat_tiles(state, index)
	threat["enemy_key"] = engine._enemy_key(enemy)
	var damage: Dictionary = {}
	if int(enemy.get("freeze", 0)) > 0 or int(enemy.get("shock", 0)) > 0: return {"threat": threat, "damage": damage}
	var context: Dictionary = engine.enemy_intent_plan(state, index)
	var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), index, Rules.action_for(enemy["intent"]), null, {}, engine._dictionary_values([]), context)
	var losses: Array[Dictionary] = engine._actor_target_losses(state, after)
	losses.append_array(engine._enemy_target_losses(state, after))
	for loss: Dictionary in losses:
		var key: String = str(loss.get("key", ""))
		if key.is_empty() or damage.has(key): continue
		var unit: Dictionary = after["player"] if key == "player" else engine._surface_actor(after, str(loss["kind"]), int(loss.get("id", -1)))
		damage[key] = {"hp": int(unit.get("hp", 0)), "damage": int(loss.get("hp_loss", 0)), "lethal": int(unit.get("hp", 0)) <= 0}
	return {"threat": threat, "damage": damage}
