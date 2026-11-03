extends "res://scripts/combat_engine.gd"
## Offline-only card definitions and branch-local counters. Authored definitions,
## gameplay analytics and saves are untouched. Speculative branches carry their own counters;
## only the final committed state's counters are returned to the measurement CLI.
const METRICS: String = "_measurement_metrics"
const SHOCK_SOURCE: String = "_measurement_skybolt_shock"
var added_card: String = ""
var override_card_id: String = ""
var field_overrides: Dictionary = {}
var final_metrics: Dictionary = {}
var skybolt_primary_target: Vector2i = Vector2i(-1, -1)
var skybolt_cast_origin: Vector2i = Vector2i(-1, -1)

func primary_only_shock() -> bool:
	return added_card == "skybolt" and (field_overrides.get("action_fields", {}) as Dictionary).get("shock_all_hits", true) == false

func variant_card_id() -> String:
	return added_card if override_card_id.is_empty() else override_card_id

func source_card_id(card_id: String) -> String:
	return added_card if card_id == variant_card_id() else card_id

static func empty_metrics() -> Dictionary:
	return {"casts": {}, "skybolt_hits": 0, "skybolt_kills": 0, "skybolt_cancelled_attacks": 0, "skybolt_hits_beyond_5": 0, "skybolt_hits_without_los": 0, "skybolt_casts_beyond_5": 0, "skybolt_casts_without_los": 0}

func card_def(card_id: String, state: Dictionary = {}) -> Dictionary:
	if card_id != variant_card_id() or field_overrides.is_empty():
		return super.card_def(card_id, state)
	# Resolve the overridden authored definition through the complete production
	# pipeline, including fixed-point keywords, progression and Tempo pricing.
	# This offline resolver is synchronous: restore the shared entry before any
	# caller can observe it, rather than overwriting the resolved discounts.
	var definitions: Dictionary = GameData.cards()
	var original: Dictionary = definitions[card_id]
	definitions[card_id] = with_fields(GameData._raw_card_def(card_id), field_overrides)
	var card: Dictionary = super.card_def(card_id, state)
	definitions[card_id] = original
	return card

func prepare_player_card(state: Dictionary, hand_index: int, play_mode: String = "play") -> Dictionary:
	var prepared: Dictionary = super.prepare_player_card(state, hand_index, play_mode)
	var hand: Array = state.get("deck", {}).get("hand", [])
	if hand_index >= 0 and hand_index < hand.size() and str(hand[hand_index]) == variant_card_id() and not field_overrides.is_empty():
		# Production's raw-catalog fast path cannot see keywords added in memory.
		# Stamp their start state using the same production keyword resolver.
		CardKeywordRules.stamp_card_start(prepared, str(hand[hand_index]), card_def(str(hand[hand_index]), prepared), play_mode == "empower")
	return prepared

static func with_fields(definition: Dictionary, overrides: Dictionary) -> Dictionary:
	var card: Dictionary = definition.duplicate(true)
	overrides = overrides.duplicate(true)
	for field: String in overrides:
		if field == "action_fields":
			for action: Dictionary in card["actions"]:
				for key: String in overrides[field]:
					if overrides[field][key] == null: action.erase(key)
					else: action[key] = overrides[field][key]
		elif overrides[field] == null: card.erase(field)
		else: card[field] = overrides[field]
	return card

func metrics(state: Dictionary) -> Dictionary:
	if not state.has(METRICS): state[METRICS] = empty_metrics()
	return state[METRICS]

func combat_outcome(state: Dictionary) -> String:
	# Policy.run_room's last outcome query is on its final committed state.
	final_metrics = state.get(METRICS, empty_metrics())
	return super.combat_outcome(state)

func finish_player_card(state: Dictionary, hand_index: int, plays_spent: int = 1, play_context: Dictionary = {}) -> Dictionary:
	var card_id: String = source_card_id(str(state["deck"]["hand"][hand_index]))
	var after: Dictionary = super.finish_player_card(state, hand_index, plays_spent, play_context)
	var counts: Dictionary = metrics(after)["casts"]
	counts[card_id] = int(counts.get(card_id, 0)) + 1
	return after

func apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var previous_target: Vector2i = skybolt_primary_target
	var previous_origin: Vector2i = skybolt_cast_origin
	if source_card_id(str(action.get("_card_id", ""))) == "skybolt":
		skybolt_primary_target = target_tile
		skybolt_cast_origin = action.get("_origin_tile", state["player"]["pos"])
	var after: Dictionary = super.apply_player_action(state, action, target_tile)
	skybolt_primary_target = previous_target
	skybolt_cast_origin = previous_origin
	if source_card_id(str(action.get("_card_id", ""))) == "skybolt":
		var counts: Dictionary = metrics(after)
		counts["skybolt_kills"] += maxi(0, int(after["run_stats"].get("enemies_killed", 0)) - int(state["run_stats"].get("enemies_killed", 0)))
		if int(counts["skybolt_hits_beyond_5"]) > int(state.get(METRICS, {}).get("skybolt_hits_beyond_5", 0)): counts["skybolt_casts_beyond_5"] += 1
		if int(counts["skybolt_hits_without_los"]) > int(state.get(METRICS, {}).get("skybolt_hits_without_los", 0)): counts["skybolt_casts_without_los"] += 1
	return after

func _apply_action_keywords_to_enemy(state: Dictionary, enemy_index: int, action: Dictionary, source_pos: Vector2i, trigger_player_relics: bool = true) -> Dictionary:
	var enemy: Dictionary = state["enemies"][enemy_index]
	var old_shock: int = int(enemy.get("shock", 0))
	if source_card_id(str(action.get("_card_id", ""))) == "skybolt":
		# Called once for each actual enemy hit, including lethal and blocked hits.
		var counts: Dictionary = metrics(state)
		counts["skybolt_hits"] += 1
		var nearest: int = 1000000
		var has_los: bool = false
		for tile: Vector2i in _enemy_footprint_tiles(enemy):
			# source_pos is the force/conduction-hop origin, not the caster.
			nearest = mini(nearest, PathUtils.manhattan(skybolt_cast_origin, tile))
			has_los = has_los or combat_line_of_sight(state, skybolt_cast_origin, tile)
		if nearest > 5: counts["skybolt_hits_beyond_5"] += 1
		if not has_los: counts["skybolt_hits_without_los"] += 1
	var keywords: Dictionary = action
	# The brief explicitly requires primary-only Shock. Production currently
	# propagates printed shock:1 even with shock_all_hits:false. Adapt only this
	# offline override; keep the native hit plan, damage, costs and every other
	# keyword. A ground/conductor aim has no primary enemy to receive Shock.
	if str(action.get("_card_id", "")) == variant_card_id() and primary_only_shock() and not _enemy_footprint_tiles(enemy).has(skybolt_primary_target):
		keywords = action.duplicate(true)
		keywords["shock"] = 0
	var after: Dictionary = super._apply_action_keywords_to_enemy(state, enemy_index, keywords, source_pos, trigger_player_relics)
	var updated: Dictionary = after["enemies"][enemy_index]
	if int(updated.get("shock", 0)) > old_shock:
		updated[SHOCK_SOURCE] = source_card_id(str(action.get("_card_id", ""))) == "skybolt"
	return after

func _resolve_enemy_start_of_turn(state: Dictionary, enemy_index: int) -> Dictionary:
	var source: bool = bool(state["enemies"][enemy_index].get(SHOCK_SOURCE, false))
	var result: Dictionary = super._resolve_enemy_start_of_turn(state, enemy_index)
	var after: Dictionary = result["state"]
	var enemy: Dictionary = after["enemies"][enemy_index]
	if source and bool(result["shocked"]):
		if not bool(result["skip_all"]) and combat_outcome(after).is_empty():
			var observation: Dictionary = after.duplicate(true)
			var intent: Dictionary = WarbandRules.current_intent(observation, enemy, _surface_pay_enemy_fuel(observation, enemy, enemy.get("intent", {})))
			for action: Dictionary in intent.get("actions", []):
				# Count damaging intent actions actually suppressed by Shock, not
				# counterfactual hits or damage. Special resolvers retain their rules.
				if int(action.get("damage", 0)) > 0 and not _enemy_action_is_movement(action):
					metrics(after)["skybolt_cancelled_attacks"] += 1
		enemy[SHOCK_SOURCE] = false
	return result
