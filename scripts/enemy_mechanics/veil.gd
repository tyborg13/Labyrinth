extends RefCounted

const Paths = preload("res://scripts/path_utils.gd")
const Tether = preload("res://scripts/enemy_mechanics/tether.gd")
const TARGETING_REASON: String = "Veiled — attack from an adjacent tile."
const BLINK_RANGE: int = 4 # Fade and Ambush share the brief's range.

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "veil_blink" or bool(action.get("ends_veil", false))

static func handles_intent(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if handles(action): return true
	return false

static func record_move(state: Dictionary, from: Vector2i, to: Vector2i) -> void:
	if from == to: return
	state["hero_last_move"] = {"turn": int(state.get("turn", 1)), "direction": direction(from, to)}

static func target_reason(engine: RefCounted, state: Dictionary, action: Dictionary, tile: Vector2i) -> String:
	# Area, surfaces and secondary chain/conduction hits never pass this gate.
	if str(action.get("type", "")) not in ["melee", "ranged", "push", "pull", "swap", "petrify"]: return ""
	var index: int = engine._enemy_index_at_tile(state, tile)
	if index < 0 or not bool(state["enemies"][index].get("veiled", false)): return ""
	var origin: Vector2i = state["player"]["pos"]
	if engine._enemy_distance_to_tile(state["enemies"][index], origin) <= 1: return ""
	return TARGETING_REASON

static func destination(engine: RefCounted, state: Dictionary, enemy: Dictionary, reach: int = BLINK_RANGE) -> Vector2i:
	var hero: Vector2i = state["player"]["pos"]
	var start: Vector2i = enemy["pos"]
	var last: Dictionary = state.get("hero_last_move", {})
	var direction: Vector2i = last.get("direction", Vector2i.ZERO) if int(last.get("turn", -1)) == int(state.get("turn", 1)) else Vector2i.ZERO
	if direction == Vector2i.ZERO: direction = direction(hero, start)
	var preferred: Vector2i = hero - direction
	var chosen: Vector2i = start
	var nearest: int = 2147483647
	var blockers: Dictionary = engine._enemy_path_blockers(state, enemy, true, false)
	for offset: Vector2i in engine.CARDINAL_DIRECTIONS:
		var tile: Vector2i = hero + offset
		if Paths.manhattan(start, tile) > reach or not engine._enemy_can_occupy_anchor(state, enemy, tile, blockers): continue
		var distance: int = Paths.manhattan(tile, preferred)
		if distance < nearest:
			nearest = distance
			chosen = tile
	return chosen

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, movement_disabled: bool = false, attack_disabled: bool = false) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var action: Dictionary = intent["actions"][0]
	var start: Vector2i = enemy["pos"]
	var hero: Vector2i = state["player"]["pos"]
	var ambush: bool = bool(action.get("ends_veil", false))
	var end: Vector2i = start
	if not movement_disabled and (not ambush or Paths.manhattan(start, hero) > 1): end = destination(engine, state, enemy, int(action.get("range", BLINK_RANGE)) if not ambush else BLINK_RANGE)
	var path: Array[Vector2i] = engine._vector2i_values([start] if start == end else [start, end])
	var tiles: Array[Vector2i]
	if ambush and not attack_disabled and Paths.manhattan(end, hero) == 1: tiles.append(hero)
	return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": path, "route": path, "destination": end, "movement_action_index": 0,
		"attack_action_index": 0 if ambush else -1, "attack_action": action, "target": {"key": "player", "kind": "player", "pos": hero}, "target_key": "player", "target_tile": hero,
		"projected_attack_target": hero, "projected_attack": tiles, "attack_available": not tiles.is_empty(), "veil_blink": true, "movement_disabled": movement_disabled, "attack_disabled": attack_disabled}

static func blink(engine: RefCounted, state: Dictionary, index: int, end: Vector2i) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var start: Vector2i = enemy["pos"]
	if end == start: return state
	enemy["pos"] = end
	state["enemies"][index] = enemy
	return engine.surface_actor_arrival(state, "enemy", int(enemy["id"]), start)

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var ambush: bool = bool(action.get("ends_veil", false))
	var start: Vector2i = enemy["pos"]
	var hero: Vector2i = state["player"]["pos"]
	var end: Vector2i = start
	if not bool(context.get("movement_disabled", enemy.get("immobilize", false))) and (not ambush or Paths.manhattan(start, hero) > 1):
		end = destination(engine, state, enemy, BLINK_RANGE if ambush else int(action.get("range", BLINK_RANGE)))
	if not ambush: enemy["veiled"] = true
	state["enemies"][index] = enemy
	state = blink(engine, state, index, end)
	context["blink_state"] = state.duplicate(true)
	context["blink_from"] = start
	context["blink_to"] = end
	if ambush:
		action = preload("res://scripts/warband_combat_rules.gd").action(state, state["enemies"][index], action)
		var strike_context: Dictionary = context.duplicate(true)
		strike_context["target_key"] = "player"
		strike_context["blocking_terrain_index"] = -1
		strike_context["trap_attack_index"] = -1
		if int(state["enemies"][index].get("hp", 0)) > 0 and Paths.manhattan(state["enemies"][index]["pos"], hero) == 1:
			state = engine._enemy_attack_target(state, index, action, "hits", null, bleed_steps, strike_context)
		state["enemies"][index]["veiled"] = false
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary) -> Dictionary:
	var step: Dictionary = {"kind": "move", "action_type": "veil_blink", "en03_veil": true, "actor_key": engine._enemy_key(before["enemies"][index]),
		"actor_name": engine._enemy_display_name(before["enemies"][index]),
		"from": context.get("blink_from", before["enemies"][index]["pos"]), "to": context.get("blink_to", after["enemies"][index]["pos"]),
		"label": "Ambush" if bool(action.get("ends_veil", false)) else "Fade", "en03_after": Tether.snapshot(after), "blink_after": Tether.snapshot(context.get("blink_state", before))}
	if bool(action.get("ends_veil", false)):
		var strike: Dictionary = engine._enemy_action_step_base(context.get("blink_state", before), after, index, action, {"target_key": "player"})
		strike["enemy_after"] = after["enemies"][index].duplicate(true)
		step["strike_step"] = strike
		step["kind"] = "melee"
		step["action_type"] = "melee"
		step["target_losses"] = strike.get("target_losses", [])
		step["amount"] = strike.get("amount", 0)
	return step

static func direction(from: Vector2i, to: Vector2i) -> Vector2i:
	var delta: Vector2i = to - from
	if delta == Vector2i.ZERO: return delta
	return Vector2i(signi(delta.x), 0) if absi(delta.x) >= absi(delta.y) else Vector2i(0, signi(delta.y))
