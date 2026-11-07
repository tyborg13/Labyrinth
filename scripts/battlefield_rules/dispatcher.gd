extends RefCounted
## One data-driven rule per fight. All caller-owned snapshots remain immutable.
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Wildfire = preload("res://scripts/battlefield_rules/wildfire.gd")
const Frostbite = preload("res://scripts/battlefield_rules/frostbite.gd")
const LightningStorm = preload("res://scripts/battlefield_rules/lightning_storm.gd")
const Upheaval = preload("res://scripts/battlefield_rules/upheaval.gd")
const Shadowstep = preload("res://scripts/battlefield_rules/shadowstep.gd")
const Outcomes = preload("res://scripts/battlefield_rules/outcomes.gd")
const HalfHealth = preload("res://scripts/battlefield_rules/half_health.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const RESOLVERS: Dictionary = {"gust": Gust, "wildfire": Wildfire, "frostbite": Frostbite, "lightning_storm": LightningStorm, "upheaval": Upheaval, "shadowstep": Shadowstep}
const ANCHORS: Array = ["after_source_turn", "after_player_turn", "on_intent"]
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty(): _data = JSON.parse_string(FileAccess.get_file_as_string("res://data/battlefield_rules.json"))
	return _data

static func instance_for(id: String, source_id: int = -1) -> Dictionary:
	var instance: Dictionary = data()["instances"].get(id, {}).duplicate(true)
	if str(instance.get("source", {}).get("kind", "")) == "enemy": instance["source"]["id"] = source_id
	return instance

static func active(state: Dictionary) -> Dictionary:
	var instance: Dictionary = state.get("battlefield_rule", {})
	if instance.is_empty() or int(instance.get("beats_remaining", 1)) <= 0: return {}
	if str(instance.get("source", {}).get("kind", "")) == "room": return instance
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("id", -2)) == int(instance.get("source", {}).get("id", -1)) and int(enemy.get("hp", 0)) > 0: return instance
	return {}

static func clear_dead_source(state: Dictionary) -> void:
	if not state.get("battlefield_rule", {}).is_empty() and active(state).is_empty():
		if str(state["battlefield_rule"].get("rule", "")) == "gust": state.erase("wind")
		state["battlefield_rule"] = {}

static func error_for(state: Dictionary, instance: Dictionary) -> String:
	var problem: String = _instance_error(state, instance)
	if not problem.is_empty(): return problem
	if not instance.has("at_half_health"): return ""
	var change: Dictionary = instance["at_half_health"]
	if str(instance["source"]["kind"]) != "enemy": return "at_half_health requires an enemy source"
	if str(change.get("sentence", "")).is_empty(): return "at_half_health requires its panel sentence"
	var switched: Dictionary = instance.duplicate(true)
	HalfHealth.replace_values(switched, change)
	return _instance_error(state, switched)

static func _instance_error(state: Dictionary, instance: Dictionary) -> String:
	var rule: String = str(instance.get("rule", ""))
	if not RESOLVERS.has(rule): return "Unknown battlefield rule: " + rule
	var source: Dictionary = instance.get("source", {})
	if str(source.get("kind", "")) not in ["enemy", "room"]: return "Battlefield rule requires an enemy or room source"
	var cadence: Dictionary = instance.get("cadence", {})
	var anchor: String = str(cadence.get("anchor", ""))
	if not ANCHORS.has(anchor): return "Unknown battlefield cadence: " + anchor
	if anchor != "after_player_turn" and str(source["kind"]) != "enemy": return "This cadence requires an enemy source"
	if anchor == "on_intent":
		if str(cadence.get("intent", "")).is_empty(): return "on_intent requires an intent ID"
	elif int(cadence.get("every", 0)) <= 0: return "Battlefield cadence requires positive every"
	return RESOLVERS[rule].dial_error(state, instance)

static func install(engine: RefCounted, state: Dictionary, authored: Dictionary) -> void:
	var instance: Dictionary = authored.duplicate(true)
	var prior: Dictionary = state.get("battlefield_rule", {})
	if prior.get("source", {}) == instance.get("source", {}) and prior.get("rule", "") == instance.get("rule", "") and bool(prior.get("half_health_switched", false)):
		instance["half_health_switched"] = true
		if instance.has("at_half_health"): HalfHealth.replace_values(instance, instance["at_half_health"])
	instance["beats_fired"] = int(instance.get("beats_fired", 0))
	instance["counter"] = int(instance.get("counter", 0))
	var problem: String = error_for(state, instance)
	if not problem.is_empty():
		push_error(problem)
		return
	state["battlefield_rule"] = instance
	prepare(engine, state)

static func prepare(engine: RefCounted, state: Dictionary) -> void:
	clear_dead_source(state)
	var instance: Dictionary = active(state)
	if instance.is_empty() or not error_for(state, instance).is_empty(): return
	instance["beats_fired"] = int(instance.get("beats_fired", 0))
	instance["counter"] = int(instance.get("counter", 0))
	match str(instance["rule"]):
		"gust":
			Gust.prepare(engine, state, instance)
			state["wind"] = Gust.value_for(state, instance)
		"wildfire": Wildfire.prepare(engine, state, instance)
		"upheaval": Upheaval.prepare(engine, state, instance)

static func install_call(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> void:
	var enemy: Dictionary = state["enemies"][index]
	var held: bool = preload("res://scripts/warband_combat_rules.gd").order(state, enemy, "stormcaller_wind")
	var instance: Dictionary = instance_for("stormcaller" if held else "gale_herald", int(enemy["id"]))
	instance["dials"]["tiles"] = int(action.get("push", 1))
	instance["locked_direction"] = Gust.announced_direction(engine, state, enemy, action)
	if not held: instance["beats_remaining"] = int(action.get("rounds", 2))
	var prior: Dictionary = active(state)
	if str(prior.get("rule", "")) == "gust" and prior.get("source", {}) == instance["source"]: instance["beats_fired"] = int(prior.get("beats_fired", 0))
	install(engine, state, instance)

# Only legacy primitive callers adopt a wind dictionary. A legacy save without
# battlefield_rule remains none at load; a new Call installs its proper instance.
static func adopt_wind(engine: RefCounted, state: Dictionary) -> void:
	if not state.get("battlefield_rule", {}).is_empty(): return
	var value: Dictionary = Gust.active(engine, state)
	if value.is_empty() or Gust.room_sourced(state, value): return
	var instance: Dictionary = instance_for("stormcaller" if Gust.persistent(engine, state, value) else "gale_herald", int(value["source_id"]))
	instance["dials"]["tiles"] = int(value.get("push", 1))
	instance["locked_direction"] = value["direction"]
	if not Gust.persistent(engine, state, value): instance["beats_remaining"] = int(value["rounds_left"])
	install(engine, state, instance)

static func dispatch(engine: RefCounted, state: Dictionary, anchor: String, actor_id: int = -1, intent_id: String = "", steps: Array[Dictionary] = TypedArrays.dictionaries([]), player_turn: int = -1, accepted: Callable = Callable()) -> Dictionary:
	clear_dead_source(state)
	if engine.combat_outcome(state) != "": return state
	var instance: Dictionary = active(state)
	if instance.is_empty(): return state
	var cadence: Dictionary = instance["cadence"]
	if str(cadence["anchor"]) != anchor: return state
	if anchor == "after_player_turn":
		if player_turn < 0: player_turn = int(state.get("turn", 1))
		if int(instance.get("last_player_turn", -1)) == player_turn: return state
		instance["last_player_turn"] = player_turn
	if anchor != "after_player_turn" and int(instance["source"].get("id", -2)) != actor_id: return state
	if anchor == "on_intent":
		if str(cadence["intent"]) != intent_id: return state
	else:
		instance["counter"] = int(instance.get("counter", 0)) + 1
		if int(instance["counter"]) < int(cadence["every"]): return state
		instance["counter"] = 0
	return fire(engine, state, steps, accepted)

static func after_player_turn(engine: RefCounted, state: Dictionary, player_turn: int = -1, accepted: Callable = Callable()) -> Dictionary:
	var steps: Array[Dictionary]
	return dispatch(engine, state, "after_player_turn", -1, "", steps, player_turn, accepted)

static func fire(engine: RefCounted, state: Dictionary, steps: Array[Dictionary] = TypedArrays.dictionaries([]), accepted: Callable = Callable()) -> Dictionary:
	if engine.combat_outcome(state) != "": return state
	prepare(engine, state)
	var instance: Dictionary = active(state)
	if instance.is_empty(): return state
	var problem: String = error_for(state, instance)
	if not problem.is_empty():
		push_error(problem)
		return state
	var before: Dictionary = state.duplicate(true)
	var context: Dictionary = state.get("damage_context", {}).duplicate(true)
	var source: Dictionary = instance["source"]
	state["damage_context"] = {"actor_kind": source["kind"], "actor_id": int(source.get("id", -1)), "source_kind": "battlefield_rule", "rule": instance["rule"], "player_card": false}
	state = RESOLVERS[instance["rule"]].resolve_beat(engine, state, instance)
	if not state.get("battlefield_rule", {}).is_empty(): instance = state["battlefield_rule"]
	instance["beats_fired"] = int(instance.get("beats_fired", 0)) + 1
	var projection: Dictionary = Outcomes.project(engine, before, state, false)
	if str(source["kind"]) == "room": instance["last_beat_tiles"] = projection["tiles"].duplicate(true)
	var event: Dictionary = Outcomes.analytics(engine, before, state, projection)
	var actor: Dictionary = engine._surface_actor(before, "enemy", int(source.get("id", -1)))
	event.merge({"kind": "battlefield_rule_fired", "rule": instance["rule"], "source_kind": source["kind"], "source_type": str(actor.get("type", "")), "beat_index": instance["beats_fired"]})
	# Keep existing combat/save snapshots unchanged. The JSONL adapter supplies
	# false when absent; only a fired latch needs additional durable metadata.
	if bool(instance.get("half_health_switched", false)): event["half_health_switched"] = true
	Surfaces.record_event(state, event)
	if str(instance["rule"]) == "gust":
		var index: int = engine._enemy_index_for_id(before, int(source.get("id", -1)))
		var step: Dictionary = Gust.animation_step(engine, before, state, index, {"type": "wind_push"})
		step["en02_state_before"] = before
		steps.append(step)
	if instance.has("beats_remaining"): instance["beats_remaining"] = int(instance["beats_remaining"]) - 1
	state["damage_context"] = context
	# An early cadence still counts as a beat, but must retain the visible
	# warning until a player activation has begun. Consumed marks are replanned.
	if str(instance["rule"]) != "upheaval" or Surfaces.BeatFuel.eligible(state, instance.get("marks_source", {})):
		instance.erase("marks")
		instance.erase("marks_source")
	if str(instance["rule"]) == "wildfire": instance.erase("locked_direction")
	if str(instance["rule"]) == "gust": Gust.after_beat(instance)
	clear_dead_source(state)
	prepare(engine, state)
	if accepted.is_valid(): accepted.call(state)
	return state

static func complete_source_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary], actor_id: int, intent_id: String = "", accepted: Callable = Callable()) -> Dictionary:
	# A skipped activation counts for cadence, but never resolves its intent.
	if not intent_id.is_empty(): state = dispatch(engine, state, "on_intent", actor_id, intent_id, steps, -1, accepted)
	state = dispatch(engine, state, "after_source_turn", actor_id, "", steps, -1, accepted)
	return state

static var _forecast_memo := preload("res://scripts/combat_preview_memo.gd").new()
static var _catalog_memo := preload("res://scripts/combat_preview_memo.gd").new()

static func forecast_inputs(engine: RefCounted, state: Dictionary) -> Array:
	# With no living rule source, prepare() cannot produce a beat. Both terminal
	# and nonterminal boards return the same empty projection, independent of
	# catalogs/history/actor positions. Keep injected implementations isolated.
	var implementation: Script = engine.get_script()
	if implementation != null and implementation.resource_path in ["res://scripts/combat_engine.gd", "res://scripts/hero_facing_combat.gd"] and active(state).is_empty():
		return ["inactive"]
	# The resolver can read every catalog via deaths, traps, statuses, relics and
	# vision. Intern their complete owned values once, independently of the board.
	# The exact signature still validates in-place edits on every query; forecast
	# misses no longer hash, compare and snapshot all catalogs a second time.
	var data_source: GDScript = preload("res://scripts/game_data.gd")
	var specials: GDScript = preload("res://scripts/special_encounter_library.gd")
	if specials._data.is_empty(): specials.catalog()
	var catalogs: Array = [data_source.enemies(), data_source.cards(), data_source.relics(), data_source.equipment(), data_source.upgrades(), data_source.omens(), data_source.progression_levels(), preload("res://scripts/skill_tree_library.gd").definitions(), specials._data, preload("res://scripts/depth_rules.gd").data()]
	# Ordinary preview consumers own separate CombatEngine instances, but their
	# forecasts read the same board/catalogs. Instance-local query caches are not
	# rules inputs. Share only the production implementation; injected engines
	# retain their instance identity because their own fields may affect results.
	var script: Script = engine.get_script()
	# Keep the implementation's identity without retaining its script through
	# this static memo (CombatEngine itself preloads this dispatcher).
	var engine_key: int = script.get_instance_id() if script != null and script.resource_path == "res://scripts/combat_engine.gd" else engine.get_instance_id()
	return [engine_key, state, _catalog_memo.exact_signature(catalogs)]

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return _forecast_memo.resolve_repeated(forecast_inputs(engine, state), func() -> Dictionary: return _compute_forecast(engine, state))

static func _compute_forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	# Rebuild derived relic effects on a miss, including raw catalog invalidation.
	engine._relic_effect_cache_valid = false
	if engine.combat_outcome(state) != "": return {"moves": [], "tiles": {"catch": [], "freeze": [], "strike": [], "rise": []}, "hits": [], "collision_markers": []}
	var trial: Dictionary = state.duplicate(true)
	prepare(engine, trial)
	var instance: Dictionary = active(trial)
	if instance.is_empty(): return {"moves": [], "tiles": {"catch": [], "freeze": [], "strike": [], "rise": []}, "hits": [], "collision_markers": []}
	var problem: String = error_for(trial, instance)
	if not problem.is_empty(): return {"error": problem}
	if str(instance["rule"]) == "gust":
		# Project the source's pending relock on this private resolver snapshot.
		instance["locked_direction"] = Gust.projected_value_for(engine, trial, instance)["direction"]
	# Keep the announcement even if a future resolver changes derived state.
	var announcement: Dictionary = {}
	if instance.has("locked_direction"): announcement["direction"] = instance["locked_direction"]
	var before: Dictionary = trial.duplicate(true)
	trial["damage_context"] = {"actor_kind": instance["source"]["kind"], "actor_id": int(instance["source"].get("id", -1)), "source_kind": "battlefield_rule", "rule": instance["rule"], "player_card": false}
	trial = RESOLVERS[instance["rule"]].resolve_beat(engine, trial, instance)
	var result: Dictionary = Outcomes.project(engine, before, trial)
	result.merge(announcement)
	return result

static func _definition(rule: String) -> Dictionary:
	for definition: Dictionary in data()["rules"]:
		if definition["id"] == rule: return definition
	return {}

static func panel(state: Dictionary) -> Dictionary:
	var instance: Dictionary = active(state)
	if instance.is_empty(): return {}
	for definition: Dictionary in data()["rules"]:
		if definition["id"] == instance["rule"]:
			return {"rule": instance["rule"], "name": definition["name"], "icon": definition["icon"], "sentence": instance.get("sentence", "")}
	return {}

static func project_turn_order(engine: RefCounted, state: Dictionary, turns: Array[Dictionary], limit: int) -> Array[Dictionary]:
	var instance: Dictionary = active(state)
	if instance.is_empty(): return turns
	var result: Array[Dictionary]
	var count: int = int(instance.get("counter", 0))
	var remaining: int = int(instance.get("beats_remaining", 2147483647))
	var cadence: Dictionary = instance["cadence"]
	var anchor: String = str(cadence["anchor"])
	for turn: Dictionary in turns:
		if result.size() >= limit: break
		result.append(turn)
		var source_turn: bool = str(turn.get("kind", "")) == "enemy" and int(turn.get("enemy_id", -2)) == int(instance["source"].get("id", -1))
		var matches_anchor: bool = str(turn.get("kind", "")) == "player" if anchor == "after_player_turn" else source_turn
		if not matches_anchor or remaining <= 0: continue
		if anchor == "on_intent":
			# Only the announced activation is knowable, not its unselected future.
			if bool(turn.get("projected", false)): continue
			var index: int = engine._enemy_index_for_id(state, int(instance["source"]["id"]))
			if index < 0: continue
			var availability: Dictionary = engine.EnemyActivationRules.forecast(engine, state, index)
			if not bool(availability["available"]) or str(availability["intent"]) != str(cadence["intent"]): continue
		else:
			count += 1
			if count < int(cadence["every"]): continue
			count = 0
		if result.size() < limit:
			# The beat fires right after its anchor turn, at the same clock. The rail
			# keys, times and labels it like an actor row (el-04 beat token).
			var at: int = int(turn.get("time", state.get("initiative_clock", 0)))
			var definition: Dictionary = _definition(str(instance["rule"]))
			result.append({"kind": "beat", "rule": instance["rule"], "at": at, "time": at, "seq": int(turn.get("seq", 0)),
				"actor_key": "beat_%s_%s_%d_%d" % [instance["rule"], str(turn.get("actor_key", turn.get("kind", ""))), at, int(turn.get("seq", 0))], "name": str(definition.get("name", "")),
				"icon": str(definition.get("icon", "")), "sentence": str(instance.get("sentence", "")), "team": "enemy", "projected": true,
				"eta": int(turn.get("eta", 0))})
		remaining -= 1
	return result
