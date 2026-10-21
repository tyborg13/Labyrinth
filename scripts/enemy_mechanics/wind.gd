extends RefCounted

# Director contract: spec/enemies/gale_herald.md. Preview uses the real mover.
const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Maneuvers = preload("res://scripts/maneuver_rules.gd")

const Paths = preload("res://scripts/path_utils.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall.gd")

static func complete_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	# A pillar on its last round still blocks this turn's wind (director feedback 1).
	state = end_turn(engine, state, steps)
	Icefall.end_turn(state, steps)
	return state

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

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	state["wind"] = {"direction": direction(engine, state, enemy, int(action.get("hazard_scan", 3))), "rounds_left": int(action.get("rounds", 2)), "source_id": int(enemy["id"]), "push": int(action.get("push", 1))}
	return state

static func active(engine: RefCounted, state: Dictionary) -> Dictionary:
	var value: Dictionary = state.get("wind", {})
	if int(value.get("rounds_left", 0)) <= 0: return {}
	var source: Dictionary = engine._surface_actor(state, "enemy", int(value.get("source_id", -1)))
	return value if int(source.get("hp", 0)) > 0 else {}

static func persistent(engine: RefCounted, state: Dictionary, value: Dictionary) -> bool:
	return preload("res://scripts/warband_combat_rules.gd").order(state, engine._surface_actor(state, "enemy", int(value.get("source_id", -1))), "stormcaller_wind")

static func clear_dead_source(engine: RefCounted, state: Dictionary) -> void:
	if state.has("wind") and active(engine, state).is_empty(): state.erase("wind")

static func anchored(state: Dictionary, kind: String, unit: Dictionary, source_id: int = -1) -> bool:
	if bool(unit.get("anchored", false)): return true
	if kind == "player": return Maneuvers.player_anchored(state)
	if kind != "enemy": return false
	var leader: Dictionary = preload("res://scripts/warband_combat_rules.gd").captain(state)
	if int(leader.get("id", -2)) == source_id and preload("res://scripts/warband_combat_rules.gd").order(state, leader, "stormcaller_wind"): return false
	var definition: Dictionary = Data.enemy_def(str(unit.get("type", "")))
	var objective: Dictionary = state.get("objective", {})
	return str(unit.get("type", "")) == "gale_herald" or bool(unit.get("is_leader", false)) or bool(unit.get("boss", false)) or bool(definition.get("boss_bar", false)) or bool(definition.get("dragon_cycle", false)) or (bool(definition.get("guardian", false)) and not bool(unit.get("guardian_helper", false))) or bool(definition.get("construct", false)) or (int(objective.get("leader_id", -999)) == int(unit.get("id", -1)))

static func force_anchored(engine: RefCounted, state: Dictionary, kind: String, id: int) -> bool:
	var unit: Dictionary = engine._force_unit(state, kind, id)
	if bool(unit.get("anchored", false)): return true
	if kind == "player": return Maneuvers.player_anchored(state)
	if kind != "enemy": return false
	# Wind-only boss/guardian/construct immunity does not change card pushes.
	return str(unit.get("type", "")) == "gale_herald" or bool(Data.enemy_def(str(unit.get("type", ""))).get("anchored", false))

static func actors(state: Dictionary, axis: Vector2i, source_id: int = -1) -> Array[Dictionary]:
	if source_id < 0: source_id = int(state.get("wind", {}).get("source_id", -1))
	var result: Array[Dictionary]
	if int(state.get("player", {}).get("hp", 0)) > 0 and not anchored(state, "player", state["player"], source_id): result.append({"kind": "player", "id": -1, "unit": state["player"]})
	for kind: String in ["enemy", "illusion"]:
		for unit: Dictionary in state.get("enemies" if kind == "enemy" else "illusions", []):
			# en-01's forced mover leaves buried bodies in place; previews agree.
			if bool(unit.get("burrowed", false)): continue
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
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": int(value["source_id"]), "source_kind": "wind", "player_card": false}
	for actor: Dictionary in actors(state, axis, int(value["source_id"])):
		if active(engine, state).is_empty(): break
		state = engine._force_move_actor(state, str(actor["kind"]), int(actor["id"]), axis, int(value.get("push", 1)), {}, true)
	return state

static func end_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	clear_dead_source(engine, state)
	var value: Dictionary = active(engine, state).duplicate(true)
	if value.is_empty(): return state
	var before: Dictionary = state.duplicate(true)
	state = push_all(engine, state, value)
	if not active(engine, state).is_empty():
		if not persistent(engine, state, value): state["wind"]["rounds_left"] = int(value["rounds_left"]) - 1
		clear_dead_source(engine, state)
	var source_index: int = engine._enemy_index_for_id(before, int(value["source_id"]))
	var step: Dictionary = animation_step(engine, before, state, source_index, {"type": "wind_push"})
	step["en02_state_before"] = before
	steps.append(step)
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
		var value: Dictionary = {"direction": direction(engine, state, enemy, int(action.get("hazard_scan", 3))), "rounds_left": int(action.get("rounds", 2)), "source_id": int(enemy["id"]), "push": int(action.get("push", 1))}
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
