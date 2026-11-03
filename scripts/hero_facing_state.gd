extends RefCounted

## Additive presentation state. No combat costs, clocks, RNG or events live here.
const KEY: String = "hero_facing"
const FRONT: Dictionary = {"facing": "front", "mirrored": false}
const Path = preload("res://scripts/path_utils.gd")
const SNAPSHOT_FIELDS: Array = ["trace_state_after", "reaction_after", "en04_state_after", "en02_state_after", "en03_after", "en05_after", "en06_after", "state_after"]

static func valid(value: Variant) -> bool:
	return value is Dictionary and value.get("facing", "") in ["front", "rear"] and value.get("mirrored") is bool

static func direction(delta: Vector2i, current: Dictionary) -> Dictionary:
	if delta == Vector2i.ZERO: return current.duplicate()
	var x: Dictionary = {"facing": "front" if delta.x > 0 else "rear", "mirrored": true}
	var y: Dictionary = {"facing": "front" if delta.y > 0 else "rear", "mirrored": false}
	if absi(delta.x) == absi(delta.y):
		if current == x or current == y: return current.duplicate()
		# Director decision: prefer the unmirrored candidate of the tied pair.
		return y
	return x if absi(delta.x) > absi(delta.y) else y

static func initial(state: Dictionary) -> Dictionary:
	var origin: Vector2i = state.get("player", {}).get("pos", Vector2i.ZERO)
	var nearest: Dictionary = {}
	var nearest_distance: int = 9223372036854775807
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		# Combat entry uses tile-grid movement steps, then the lower enemy id.
		var distance: int = Path.manhattan(origin, enemy.get("pos", origin))
		if distance < nearest_distance or (distance == nearest_distance and int(enemy.get("id", -1)) < int(nearest.get("id", 9223372036854775807))):
			nearest = enemy
			nearest_distance = distance
	return FRONT.duplicate() if nearest.is_empty() else direction(nearest["pos"] - origin, FRONT)

static func ensure(state: Dictionary) -> Dictionary:
	if not valid(state.get(KEY)): state[KEY] = initial(state)
	return state[KEY]

static func action_delta(engine: RefCounted, before: Dictionary, action: Dictionary, target: Vector2i) -> Vector2i:
	if action.has("_illusion_id") or bool(action.get("_illusion_echo", false)): return Vector2i.ZERO
	if str(action.get("target", "")) == "previous_target": target = engine._previous_target_tile(before, action)
	elif not engine.player_action_needs_target(action): return Vector2i.ZERO
	if target.x < 0 or bool(preload("res://scripts/card_stay_rules.gd").is_stay(before, action, target)): return Vector2i.ZERO
	return target - (before.get("player", {}).get("pos", target) as Vector2i)

static func player_action(engine: RefCounted, before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i) -> void:
	var current: Dictionary = ensure(before.duplicate(false))
	var delta: Vector2i = action_delta(engine, before, action, target)
	if str(action.get("type", "")) == "move" and not action.has("_illusion_id"):
		# Use the actual endpoint: Bleed, hidden occupancy and exchanges can stop
		# a requested route before its target. The final walked step owns facing.
		var origin: Vector2i = before.get("player", {}).get("pos", Vector2i.ZERO)
		var endpoint: Vector2i = after.get("player", {}).get("pos", origin)
		delta = Vector2i.ZERO
		if endpoint != origin:
			var path: Array = engine.path_for_player_action(before, action, target)
			for index: int in range(1, path.size()):
				current = direction(path[index] - path[index - 1], current)
				if path[index] == endpoint: break
	after[KEY] = direction(delta, current)

static func source_delta(_state: Dictionary, step: Dictionary) -> Vector2i:
	# An enemy-owned battlefield beat, collision or status tick is still not
	# an attack. Only direct attack presentation steps may turn the protagonist.
	if str(step.get("kind", "")) not in ["melee", "ranged", "aoe", "projectile", "lightning_strikes", "erupt"] or step.has("battlefield_rule") or str(step.get("source_kind", "")) == "battlefield_rule": return Vector2i.ZERO
	var source: String = str(step.get("source_actor_key", step.get("actor_key", "")))
	if not source.begins_with("enemy_"): return Vector2i.ZERO
	# Missing provenance also fails closed: aggregate HP/defense losses and
	# impact keys can belong entirely to a trap or a secondary reaction.
	var delta: Vector2i = Vector2i.ZERO
	for hit: Dictionary in step.get("direct_player_hits", []):
		if hit.get("target_key", "") == "player" and hit.get("source_actor_key", "") == source and int(hit.get("damage", 0)) > 0:
			delta = (hit["source_tile"] as Vector2i) - (hit["target_tile"] as Vector2i)
	return delta

static func enemy_result(before: Dictionary, result: Dictionary) -> void:
	var state: Dictionary = before.duplicate(true)
	var current: Dictionary = ensure(state)
	var pending_commit: Dictionary = {}
	for step: Dictionary in result.get("steps", []):
		if str(step.get("kind", "")) == "commit":
			if not pending_commit.is_empty(): pending_commit[KEY] = current.duplicate()
			pending_commit = step.get("state", {})
			continue
		current = direction(source_delta(state, step), current)
		# Track source movement and hero displacement without turning on either.
		if str(step.get("kind", "")) == "move":
			for enemy: Dictionary in state.get("enemies", []):
				if "enemy_%d" % int(enemy.get("id", -1)) == str(step.get("actor_key", "")): enemy["pos"] = step.get("to", enemy["pos"])
		if step.has("player_to"): state["player"]["pos"] = step["player_to"]
		for field: String in SNAPSHOT_FIELDS:
			if step.has(field):
				state = step[field].duplicate(true)
				step[field][KEY] = current.duplicate()
	if not pending_commit.is_empty(): pending_commit[KEY] = current.duplicate()
	result["state"][KEY] = current.duplicate()
	if not result.get("player_turn_before_state", {}).is_empty(): result["player_turn_before_state"][KEY] = current.duplicate()
