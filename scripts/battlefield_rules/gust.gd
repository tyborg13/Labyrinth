extends RefCounted
## No ground fuel: Gust moves units directly; fresh hazards retain ordinary contact effects.
const TODO_DESIGN_GUST_ENTRY_DIRECTION: String = "TODO_DESIGN_gust_entry_direction"

# Gust primitives and legacy presentation contract. See spec/peer_benchmark/element_rules/design.md.
const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Maneuvers = preload("res://scripts/maneuver_rules.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")

const Paths = preload("res://scripts/path_utils.gd")

static func direction(engine: RefCounted, state: Dictionary, enemy: Dictionary, scan: int = 3) -> Vector2i:
	var hero: Vector2i = state["player"]["pos"]
	var toward: Vector2i = engine._cardinal_direction(Vector2i(enemy["pos"]) - hero)
	if toward == Vector2i.ZERO: toward = engine.CARDINAL_DIRECTIONS[0]
	var closest: int = scan + 1
	var choices: Array[Vector2i]
	for axis: Vector2i in engine.CARDINAL_DIRECTIONS:
		for distance: int in range(1, scan + 1):
			var tile: Vector2i = hero + axis * distance
			if not hazard(engine, state, tile): continue
			if distance < closest:
				closest = distance
				choices.clear()
			if distance == closest: choices.append(axis)
			break
	if choices.is_empty() or choices.has(toward): return toward
	# Prefer the tied direction most toward the Herald even when the primary
	# cardinal axis itself is not tied. Exact angular ties keep cardinal order.
	var delta: Vector2i = Vector2i(enemy["pos"]) - hero
	var best: Vector2i = choices[0]
	for choice: Vector2i in choices:
		if choice.x * delta.x + choice.y * delta.y > best.x * delta.x + best.y * delta.y: best = choice
	return best

static func hazard(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return not Paths.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(state, tile) >= 0 or engine._enemy_index_at_tile(state, tile) >= 0 or engine._occupied_illusion_tiles(state).has(tile) or Surfaces.element_at(state, tile) == "fire" or engine._trap_index_at_tile(state, tile) >= 0

# Store the announcement in the selected action so saves, the chip, the real
# mover and every forecast share one cardinal direction. Legacy saves acquire
# the additive field once at the owned load boundary.
static func commit(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var has_call: bool = false
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) == "call_wind": has_call = true; break
	if not has_call: return intent
	var result: Dictionary = intent.duplicate(true)
	for action: Dictionary in result.get("actions", []):
		if str(action.get("type", "")) == "call_wind":
			action["_wind_direction"] = direction(engine, state, enemy, int(action.get("hazard_scan", 3)))
	return result

static func lock_legacy_intents(engine: RefCounted, state: Dictionary) -> void:
	# The load boundary owns this state. Older saves have no stored announcement;
	# choose it once from their resumed board, then preserve it like a new intent.
	for enemy: Dictionary in state.get("enemies", []):
		for action: Dictionary in enemy.get("intent", {}).get("actions", []):
			if str(action.get("type", "")) == "call_wind" and not action.has("_wind_direction"):
				action["_wind_direction"] = direction(engine, state, enemy, int(action.get("hazard_scan", 3)))

static func announced_direction(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Vector2i:
	# get() evaluates its default eagerly: do not rerun the hazard scan on hits.
	if action.has("_wind_direction"): return action["_wind_direction"]
	return direction(engine, state, enemy, int(action.get("hazard_scan", 3)))

static func active(engine: RefCounted, state: Dictionary) -> Dictionary:
	var value: Dictionary = state.get("wind", {})
	if room_sourced(state, value): return value
	if int(value.get("rounds_left", 0)) <= 0: return {}
	var source: Dictionary = engine._surface_actor(state, "enemy", int(value.get("source_id", -1)))
	if int(source.get("hp", 0)) <= 0: return {}
	var instance: Dictionary = state.get("battlefield_rule", {})
	if str(instance.get("rule", "")) == "gust" and instance.get("source", {}) == {"kind": "enemy", "id": int(value["source_id"])}:
		return projected_value_for(engine, state, instance)
	return value

static func persistent(engine: RefCounted, state: Dictionary, value: Dictionary) -> bool:
	if room_sourced(state, value): return true
	var instance: Dictionary = state.get("battlefield_rule", {})
	if str(instance.get("rule", "")) == "gust" and int(instance.get("source", {}).get("id", -2)) == int(value.get("source_id", -1)):
		return not instance.has("beats_remaining")
	return preload("res://scripts/warband_combat_rules.gd").order(state, engine._surface_actor(state, "enemy", int(value.get("source_id", -1))), "stormcaller_wind")

static func room_sourced(state: Dictionary, value: Dictionary) -> bool:
	return bool(value.get("battlefield_room", false)) or (str(value.get("room_source", "")) == "umbral_snare" and str(state.get("objective", {}).get("special_type", "")) == "umbral_snare")

static func clear_dead_source(engine: RefCounted, state: Dictionary) -> void:
	if state.has("wind") and active(engine, state).is_empty(): state.erase("wind")

static func anchored(state: Dictionary, kind: String, unit: Dictionary, source_id: int = -1) -> bool:
	if bool(unit.get("anchored", false)): return true
	if kind == "player": return Maneuvers.player_anchored(state)
	if kind != "enemy": return false
	return bool(Data.enemy_def(str(unit.get("type", ""))).get("anchored", false))

static func force_anchored(engine: RefCounted, state: Dictionary, kind: String, id: int) -> bool:
	var unit: Dictionary = engine._force_unit(state, kind, id)
	if bool(unit.get("anchored", false)): return true
	if kind == "player": return Maneuvers.player_anchored(state)
	if kind != "enemy": return false
	# Only the Anchored status holds a unit; there is no wielder immunity.
	return bool(Data.enemy_def(str(unit.get("type", ""))).get("anchored", false))

static func actors(state: Dictionary, axis: Vector2i, source_id: int = -1) -> Array[Dictionary]:
	if source_id < 0: source_id = int(state.get("wind", {}).get("source_id", -1))
	var result: Array[Dictionary]
	if int(state.get("player", {}).get("hp", 0)) > 0 and not anchored(state, "player", state["player"], source_id): result.append({"kind": "player", "id": -1, "unit": state["player"]})
	for kind: String in ["enemy", "illusion"]:
		for unit: Dictionary in state.get("enemies" if kind == "enemy" else "illusions", []):
			# Primitive: ordinary Push targetability leaves buried bodies in place.
			if not Burrow.targetable(unit, {"type": "push"}): continue
			if int(unit.get("hp", 0)) > 0 and not anchored(state, kind, unit, source_id): result.append({"kind": kind, "id": int(unit["id"]), "unit": unit})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_pos: Vector2i = a["unit"]["pos"]
		var b_pos: Vector2i = b["unit"]["pos"]
		var a_distance: int = a_pos.x * axis.x + a_pos.y * axis.y
		var b_distance: int = b_pos.x * axis.x + b_pos.y * axis.y
		if a_distance != b_distance: return a_distance > b_distance
		return engine_key(a) < engine_key(b))
	return result

static func engine_key(actor: Dictionary) -> String:
	return "%s_%08d" % [str(actor["kind"]), int(actor["id"])]

static func push_all(engine: RefCounted, state: Dictionary, value: Dictionary) -> Dictionary:
	var axis: Vector2i = value["direction"]
	var room_wind: bool = room_sourced(state, value)
	var context_before: Dictionary = state.get("damage_context", {}).duplicate(true)
	state["damage_context"] = {"actor_kind": "room" if room_wind else "enemy", "actor_id": int(value["source_id"]), "source_kind": "wind", "player_card": false}
	for actor: Dictionary in actors(state, axis, int(value["source_id"])):
		if active(engine, state).is_empty(): break
		state = engine._force_move_actor(state, str(actor["kind"]), int(actor["id"]), axis, int(value.get("push", 1)), {}, true)
	if room_wind: state["damage_context"] = context_before
	return state

static func preview(engine: RefCounted, state: Dictionary, value: Dictionary) -> Dictionary:
	var trial: Dictionary = state.duplicate(true)
	trial["wind"] = value.duplicate(true)
	var before: Dictionary = trial.duplicate(true)
	trial = push_all(engine, trial, value)
	var paths: Array
	var markers: Array
	for actor: Dictionary in actors(before, value["direction"], int(value["source_id"])):
		var start: Vector2i = actor["unit"]["pos"]
		var finish: Vector2i = engine._surface_actor(trial, str(actor["kind"]), int(actor["id"])).get("pos", start)
		if start != finish: paths.append(engine._vector2i_values([start, finish]))
	for event: Dictionary in engine._surface_events_since(before, trial):
		if str(event.get("kind", "")) == "force_collision": markers.append(event.duplicate(true))
	return {"state": trial, "displacement_paths": paths, "collision_markers": markers}

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) != "call_wind": continue
		var enemy: Dictionary = state["enemies"][index]
		var value: Dictionary = {"direction": announced_direction(engine, state, enemy, action), "rounds_left": int(action.get("rounds", 2)), "source_id": int(enemy["id"]), "push": int(action.get("push", 1))}
		var forecast: Dictionary = preview(engine, state, value) if not disabled else {}
		var affected: Array[Vector2i]
		for actor: Dictionary in actors(state, value["direction"], int(value["source_id"])):
			if not disabled: affected.append(actor["unit"]["pos"])
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not disabled, "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": state["player"]["pos"], "target_key": "player", "wind": value, "wind_preview": forecast}
	return {}

static func projected_player_force(engine: RefCounted, state: Dictionary, enemy_id: int, action: Dictionary) -> Dictionary:
	var index: int = engine._enemy_index_for_id(state, enemy_id)
	if index < 0: return {}
	var intent: Dictionary = {"actions": [action]}
	var forecast: Dictionary = plan(engine, state, index, intent, false).get("wind_preview", {})
	if forecast.is_empty(): return {}
	var from: Vector2i = state["player"]["pos"]
	var to: Vector2i = forecast["state"]["player"]["pos"]
	var collision: Dictionary = {}
	for marker: Dictionary in forecast["collision_markers"]:
		if str(marker.get("actor_key", "")) == "player": collision = marker
	if from == to and collision.is_empty(): return {}
	return {"path": engine._vector2i_values([from, to]) if from != to else engine._vector2i_values([from]), "destination": to, "collision": collision}

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	if index < 0 and room_sourced(before, before.get("wind", {})):
		return {"kind": "push", "en02_mechanic": "wind_push", "action_type": "wind_push", "actor_key": "room", "actor_name": "Headwind", "element": "air",
			"action_direction": before["wind"]["direction"], "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after),
			"terrain_losses": engine._terrain_target_losses(before, after), "from": before.get("snare_entry", before.get("entry", before["player"]["pos"])), "to": before["player"]["pos"], "en02_state_after": after.duplicate(true)}
	var enemy: Dictionary = before["enemies"][index]
	var direction_state: Dictionary = before if str(action["type"]) == "wind_push" else after
	var axis: Vector2i = direction_state.get("wind", {}).get("direction", Vector2i.ZERO)
	var affected: Array[Vector2i]
	for actor: Dictionary in actors(before, axis, int(enemy["id"])): affected.append(actor["unit"]["pos"])
	return {"kind": "push", "en02_mechanic": str(action["type"]), "action_type": str(action["type"]), "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "enemy_type": enemy["type"], "element": "air", "intent_id": enemy.get("intent", {}).get("id", ""), "action_direction": axis, "tiles": affected, "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "terrain_losses": engine._terrain_target_losses(before, after), "from": enemy["pos"], "to": before["player"]["pos"], "en02_state_after": after.duplicate(true)}

static func choose_intent(engine: RefCounted, state: Dictionary, index: int, intents: Array, rng: RandomNumberGenerator) -> Dictionary:
	var choices: Array[Dictionary]
	var total: int = 0
	for intent: Dictionary in intents:
		var possible: bool = true
		for action: Dictionary in intent.get("actions", []):
			if str(action.get("type", "")) == "ranged" and not bool(engine.enemy_intent_plan(state, index, intent).get("attack_available", false)): possible = false
		if not possible: continue
		choices.append(intent)
		total += int(intent.get("weight", 0))
	if total <= 0: return {}
	var roll: int = rng.randi_range(1, total)
	for intent: Dictionary in choices:
		roll -= int(intent.get("weight", 0))
		if roll <= 0: return intent.duplicate(true)
	return {}

# All enemy-directed modes hold a saved announcement through the next beat.
const DIRECTION_MODES: Array = ["aimed", "toward_entry", "fixed", "toward_source", "turn_clockwise"]
const FIXED_DIRECTIONS: Dictionary = {"up": Vector2i.UP, "right": Vector2i.RIGHT, "down": Vector2i.DOWN, "left": Vector2i.LEFT}

static func entry_direction(state: Dictionary) -> Vector2i:
	var entry: Vector2i = state.get("snare_entry", state.get("entry", Vector2i(-1, -1)))
	if entry.x == 1: return Vector2i.LEFT
	if entry.x == state["grid"][0].size() - 2: return Vector2i.RIGHT
	if entry.y == 1: return Vector2i.UP
	if entry.y == state["grid"].size() - 2: return Vector2i.DOWN
	return Vector2i.ZERO

static func dial_error(state: Dictionary, instance: Dictionary) -> String:
	var dials: Dictionary = instance.get("dials", {})
	var mode: String = str(dials.get("direction", ""))
	if int(dials.get("tiles", 0)) <= 0: return "Gust requires positive tiles"
	if mode == "aimed":
		return "Gust requires its locked announcement" if not FIXED_DIRECTIONS.values().has(instance.get("locked_direction", Vector2i.ZERO)) else ""
	if mode == "toward_entry": return TODO_DESIGN_GUST_ENTRY_DIRECTION if entry_direction(state) == Vector2i.ZERO else ""
	if mode in ["toward_source", "turn_clockwise"]:
		return "Gust direction requires an enemy source" if str(instance["source"]["kind"]) != "enemy" else ""
	if mode.begins_with("fixed:") and FIXED_DIRECTIONS.has(mode.trim_prefix("fixed:")): return ""
	return "Gust direction is not implemented: " + mode

static func prepare(engine: RefCounted, state: Dictionary, instance: Dictionary) -> void:
	var mode: String = str(instance["dials"]["direction"])
	if mode not in ["toward_source", "turn_clockwise"] or instance.has("locked_direction"): return
	var source: Dictionary = engine._surface_actor(state, "enemy", int(instance["source"]["id"]))
	var delta: Vector2i = Vector2i(state["player"]["pos"]) - Vector2i(source["pos"])
	# The same dominant-cardinal tie rule as Wildfire, mirrored for the pull.
	instance["locked_direction"] = engine._cardinal_direction(-delta if mode == "toward_source" else delta)

static func after_beat(instance: Dictionary) -> void:
	match str(instance["dials"]["direction"]):
		"toward_source": instance.erase("locked_direction")
		"turn_clockwise":
			var axis: Vector2i = instance["locked_direction"]
			instance["locked_direction"] = Vector2i(-axis.y, axis.x)

static func value_for(state: Dictionary, instance: Dictionary) -> Dictionary:
	var dials: Dictionary = instance["dials"]
	var mode: String = str(dials["direction"])
	var axis: Vector2i = instance.get("locked_direction", Vector2i.ZERO)
	if mode == "toward_entry": axis = entry_direction(state)
	elif mode.begins_with("fixed:"): axis = FIXED_DIRECTIONS[mode.trim_prefix("fixed:")]
	var value: Dictionary = {"direction": axis, "source_id": int(instance["source"].get("id", -1)), "push": int(dials["tiles"]), "rounds_left": int(instance.get("beats_remaining", 2))}
	if str(instance["source"]["kind"]) == "room": value.merge({"room_source": "umbral_snare", "battlefield_room": true})
	return value

# The held lock describes the last installed wind. A pending source Call replaces
# it before the next beat, so projections read its saved announcement instead.
# Resolution still installs that Call normally; neither query mutates the save.
static func projected_value_for(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var value: Dictionary = value_for(state, instance)
	if str(instance["dials"]["direction"]) != "aimed" or str(instance["source"]["kind"]) != "enemy": return value
	var index: int = engine._enemy_index_for_id(state, int(instance["source"]["id"]))
	if index < 0: return value
	var intent: Dictionary = state["enemies"][index].get("intent", {})
	for action: Dictionary in intent.get("actions", []):
		if str(action.get("type", "")) != "call_wind" or not action.has("_wind_direction"): continue
		# A skipped Call cannot relock the beat: share the activation-start gates.
		var availability: Dictionary = engine.EnemyActivationRules.forecast(engine, state, index)
		if bool(availability["available"]) and str(availability["intent"]) == str(intent.get("id", "")): value["direction"] = action["_wind_direction"]
		break
	return value

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var value: Dictionary = value_for(state, instance)
	state["wind"] = value
	# Primitive: Wind.push_all (unchanged farthest-first Push/Collision mover).
	return push_all(engine, state, value)

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
