extends RefCounted

const Glossary = preload("res://scripts/glossary.gd")

# Director contract: spec/enemies/hoarfrost_seer.md. State is plain Variant data.
const Paths = preload("res://scripts/path_utils.gd")

const Surfaces = preload("res://scripts/board_surface_rules.gd")

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["icefall_mark", "icefall_land"]

static func attackable(terrain: Dictionary) -> bool:
	return str(terrain.get("kind", "")) != "ice_pillar"

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if str(action.get("type", "")) == "icefall_land":
		return engine._vector2i_values(enemy.get("icefall_tiles", []))
	var result: Array[Vector2i]
	var hero: Vector2i = state["player"]["pos"]
	var delta: Vector2i = hero - Vector2i(enemy["pos"])
	if Paths.manhattan(hero, enemy["pos"]) > int(action.get("range", 5)):
		return result
	# Diagonal directions use the row, including shallow diagonals.
	var axis: Vector2i = Vector2i(0, 1) if delta.y == 0 else Vector2i(1, 0)
	for tile: Vector2i in [hero - axis, hero, hero + axis]:
		if Paths.is_passable(state["grid"], tile) and engine._terrain_index_at_tile(state, tile) < 0:
			result.append(tile)
	return result

static func available(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if handles(action) and tiles(engine, state, enemy, action).is_empty():
			return false
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	for action: Dictionary in intent.get("actions", []):
		if not handles(action): continue
		var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
		if disabled: affected.clear()
		return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": engine._vector2i_values([enemy["pos"]]), "route": engine._vector2i_values([enemy["pos"]]), "destination": enemy["pos"], "projected_attack": affected, "attack_available": not affected.is_empty(), "attack_action": action, "attack_action_index": 0, "movement_action_index": -1, "target_tile": state["player"]["pos"], "target_key": "player"}
	return {}

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var affected: Array[Vector2i] = tiles(engine, state, enemy, action)
	if str(action["type"]) == "icefall_mark":
		enemy["icefall_tiles"] = affected
		return state
	enemy["icefall_serial"] = int(enemy.get("icefall_serial", 0)) + 1
	# One hit per actor, even if a large footprint covers several marks.
	var actors: Array[Dictionary]
	actors.append({"kind": "player", "id": -1, "unit": state["player"]})
	for unit: Dictionary in state.get("enemies", []):
		actors.append({"kind": "enemy", "id": int(unit["id"]), "unit": unit})
	for unit: Dictionary in state.get("illusions", []):
		actors.append({"kind": "illusion", "id": int(unit["id"]), "unit": unit})
	for actor: Dictionary in actors:
		var hit: bool = false
		for tile: Vector2i in Surfaces.footprint_tiles(actor["unit"]):
			if affected.has(tile): hit = true
		if not hit or int(actor["unit"].get("hp", 0)) <= 0: continue
		if str(actor["kind"]) == "enemy":
			state = engine._damage_enemy(state, engine._enemy_index_for_id(state, int(actor["id"])), int(action.get("damage", 5)), true, false, false)
		else:
			state = engine._surface_damage_actor(state, str(actor["kind"]), int(actor["id"]), int(action.get("damage", 5)), true)
		state = engine._surface_freeze_actor(state, str(actor["kind"]), int(actor["id"]), action)
	for tile: Vector2i in affected:
		if occupied(engine, state, tile) or not Paths.is_passable(state["grid"], tile) or engine._terrain_index_at_tile(state, tile) >= 0: continue
		var terrain: Array = state.get("terrain", [])
		terrain.append({"id": "ice_pillar_%d_%d_%d_%d" % [int(enemy["id"]), int(enemy["icefall_serial"]), tile.x, tile.y], "kind": "ice_pillar", "pos": tile, "rounds_left": int(action.get("terrain_rounds", 3)), "shatter_damage": int(action.get("pillar_shatter_damage", 2)), "blocks_sight": true})
		state["terrain"] = terrain
	state["enemies"][index].erase("icefall_tiles")
	return state

static func occupied(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	if int(state["player"].get("hp", 0)) > 0 and state["player"]["pos"] == tile: return true
	return engine._enemy_index_at_tile(state, tile) >= 0 or engine._occupied_illusion_tiles(state).has(tile)

static func end_turn(state: Dictionary, steps: Array[Dictionary] = []) -> void:
	var expired: bool = false
	var entries: Array = state.get("terrain", [])
	for index: int in range(entries.size() - 1, -1, -1):
		var terrain: Dictionary = entries[index]
		if str(terrain.get("kind", "")) != "ice_pillar": continue
		terrain["rounds_left"] = maxi(0, int(terrain.get("rounds_left", 0)) - 1)
		if int(terrain["rounds_left"]) == 0:
			entries.remove_at(index)
			expired = true
	# Apply removal before the following actor is animated: its path and sight
	# were resolved with this terrain already gone. No new expiry animation.
	if expired: steps.append({"kind": "status", "en02_mechanic": "icefall_expiry", "en02_state_after": state.duplicate(true)})

static func collision(engine: RefCounted, state: Dictionary, kind: String, id: int, contact: Dictionary, direction: Vector2i, lost: int, pushing: bool = true) -> bool:
	for blocker: Dictionary in contact.get("blockers", []):
		if str(blocker.get("terrain_kind", "")) != "ice_pillar": continue
		var index: int = engine._terrain_index_at_tile(state, blocker["tile"])
		if index < 0: continue
		var damage: int = int(state["terrain"][index].get("shatter_damage", 2))
		engine._force_collision_damage(state, kind, id, damage)
		state["terrain"].remove_at(index)
		Surfaces.record_event(state, {"kind": "force_collision", "actor_kind": kind, "id": id, "actor_key": engine._surface_actor_key(kind, id), "tile": contact["blocked_tile"] - direction, "blocked_tile": contact["blocked_tile"], "direction": direction, "force": "push" if pushing else "pull", "damage": damage, "target_damage": damage, "blocker_damage": 0, "total_damage": damage, "blocker_kind": "terrain", "terrain_kind": "ice_pillar", "lost_tiles": lost, "tooltip_override": Glossary.name_for("ice_pillar") + "\n" + Glossary.definition("ice_pillar"), "source": state.get("damage_context", {}).duplicate(true)})
		return true
	return false

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	return {"kind": "aoe" if str(action["type"]) == "icefall_land" else "surface", "en02_mechanic": str(action["type"]), "action_type": str(action["type"]), "actor_key": engine._enemy_key(enemy), "actor_name": engine._enemy_display_name(enemy), "enemy_type": enemy["type"], "element": "ice", "from": enemy["pos"], "to": before["player"]["pos"], "tiles": tiles(engine, before, enemy, action), "damage": int(action.get("damage", 0)), "intent_id": enemy.get("intent", {}).get("id", ""), "target_losses": engine._actor_target_losses(before, after), "enemy_losses": engine._enemy_target_losses(before, after), "terrain_losses": engine._terrain_target_losses(before, after), "en02_state_after": after.duplicate(true)}
