extends RefCounted

# Forced-movement relics share the real mover, damage path and surface events.
# Owning contract: spec/forced_movement.md, relic pool overhaul unit U3.
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const INVALID := Vector2i(-1, -1)
const KNOCKED_KEY := "_forced_relic_knocked" # action-local; never saved

static func effect(engine: RefCounted, state: Dictionary, type: String) -> Dictionary:
	for entry: Dictionary in engine._relic_effects(state):
		if str(entry.get("type", "")) == type:
			return entry
	return {}

static func damage_bonus(engine: RefCounted, state: Dictionary, enemy: Dictionary, damage: int) -> int:
	if damage <= 0 or int(enemy.get("hp", 0)) <= 0:
		return 0
	var bonus: int = 0
	for entry: Dictionary in engine._relic_effects(state):
		if str(entry.get("type", "")) == "damage_on_surface" and Surface.unit_on(state, enemy, str(entry.get("surface", "rubble"))):
			bonus += Data.fixed_point_amount(int(entry.get("amount", 0)))
	return bonus

static func outcrop_health_bonus(engine: RefCounted, state: Dictionary, source: Dictionary, fields: Dictionary) -> int:
	var guard: Dictionary = effect(engine, state, "outcrop_collision_guard")
	if str(source.get("actor_kind", "")) != "player" or not (guard.get("terrain_kinds", []) as Array).has(str(fields.get("kind", "crag_outcrop"))):
		return 0
	return Data.fixed_point_amount(int(guard.get("health", 0)))

static func _hero_force(context: Dictionary) -> bool:
	# A trap encountered during a card still has the card's context, but is not
	# the hero's Push/Pull. Retaliate is a hero force without card-play credit.
	return str(context.get("actor_kind", "")) == "player" and str(context.get("source_kind", "")) not in ["trap", "surface_fire"]

static func _protected_outcrop(engine: RefCounted, state: Dictionary, blocker: Dictionary) -> bool:
	if str(blocker.get("kind", "")) != "terrain" or effect(engine, state, "outcrop_collision_guard").is_empty():
		return false
	var index: int = engine._terrain_index_at_tile(state, blocker.get("tile", INVALID))
	if index < 0:
		return false
	var terrain: Dictionary = state["terrain"][index]
	return (effect(engine, state, "outcrop_collision_guard").get("terrain_kinds", []) as Array).has(str(terrain.get("kind", ""))) and str(terrain.get("owner_kind", "")) == "player"

static func _party_damage(engine: RefCounted, state: Dictionary, kind: String, id: int, base: int, lost: int) -> int:
	if kind == "player":
		var defense: Dictionary = effect(engine, state, "collision_player_defense")
		return Data.fixed_point_amount(int(defense["damage_per_tile"])) * lost if not defense.is_empty() else base
	if kind == "enemy":
		var unit: Dictionary = engine._surface_actor(state, kind, id)
		for entry: Dictionary in engine._relic_effects(state):
			if str(entry.get("type", "")) == "collision_status_multiplier" and engine._unit_status_amount(unit, str(entry.get("status", ""))) > 0:
				base *= int(entry.get("multiplier", 1))
	return base

static func _damage_party(engine: RefCounted, state: Dictionary, kind: String, id: int, amount: int) -> Dictionary:
	var full_amount: int = amount
	if kind == "enemy":
		full_amount += damage_bonus(engine, state, engine._surface_actor(state, kind, id), amount)
	state = engine._force_collision_damage(state, kind, id, amount)
	if kind == "enemy" and not effect(engine, state, "collision_stagger").is_empty():
		engine._apply_stagger_to_enemy(state, id, full_amount)
	return {"state": state, "damage": full_amount}

static func resolve_collision(engine: RefCounted, state: Dictionary, kind: String, id: int, contact: Dictionary, direction: Vector2i, lost: int, pushing: bool) -> Dictionary:
	if lost <= 0:
		return state
	var base: int = Data.fixed_point_amount(engine.FORCE_COLLISION_DAMAGE_PER_TILE) * lost
	var unit: Dictionary = engine._force_unit(state, kind, id).duplicate(true)
	var tile: Vector2i = contact.get("blocked_tile", INVALID) - direction
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	var context_before: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = context_before.duplicate(true)
	context["source_kind"] = "force_collision"
	state["damage_context"] = context
	state["_surface_damage_batch"] = true
	var hero_force: bool = kind == "enemy" and _hero_force(context_before)
	var wheel: Dictionary = effect(engine, state, "collision_break_surfaces") if kind == "enemy" else {}
	var ground: Dictionary = Surface.surface_at(state, tile).duplicate(true) if not wheel.is_empty() else {}
	var mover_base: int = base
	if str(ground.get("elemental", "")) == "fire":
		mover_base += Data.fixed_point_amount(int(wheel.get("fire_damage", 3)))
	for blocker: Dictionary in contact.get("blockers", []):
		if kind == "enemy" and _protected_outcrop(engine, state, blocker):
			mover_base += Data.fixed_point_amount(int(effect(engine, state, "outcrop_collision_guard").get("damage", 2)))
			break # One rider per collision, even against two outcrop tiles.
	var result: Dictionary = _damage_party(engine, state, kind, id, _party_damage(engine, state, kind, id, mover_base, lost))
	state = result["state"]
	var damage: int = int(result["damage"])
	var total_damage: int = damage
	var blockers: Array[Dictionary]
	var hero_involved: bool = kind == "player"
	for raw: Dictionary in contact.get("blockers", []):
		var blocker: Dictionary = raw.duplicate(true)
		var dealt: int = 0
		var blocker_kind: String = str(blocker.get("kind", ""))
		match blocker_kind:
			"terrain":
				var index: int = engine._terrain_index_at_tile(state, blocker.get("tile", INVALID))
				if index >= 0 and not (kind == "enemy" and _protected_outcrop(engine, state, blocker)):
					state = engine._damage_terrain(state, index, base)
					dealt = base
			"enemy", "player", "illusion":
				var blocker_id: int = int(blocker.get("id", -1))
				result = _damage_party(engine, state, blocker_kind, blocker_id, _party_damage(engine, state, blocker_kind, blocker_id, base, lost))
				state = result["state"]
				dealt = int(result["damage"])
				hero_involved = hero_involved or blocker_kind == "player"
		blocker["damage"] = dealt
		total_damage += dealt
		blockers.append(blocker)
	var primary: Dictionary = blockers[0] if not blockers.is_empty() else {}
	Surface.record_event(state, {
		"kind": "force_collision", "tile": tile, "anchor": unit.get("pos", INVALID),
		"blocked_tile": contact.get("blocked_tile", INVALID), "direction": direction,
		"force": "push" if pushing else "pull", "actor_kind": kind, "id": id,
		"actor_key": engine._surface_actor_key(kind, id), "lost_tiles": lost,
		"damage": damage, "target_damage": damage, "blocker_kind": str(primary.get("kind", "")),
		"blocker_key": str(primary.get("key", "")), "blocker_damage": int(primary.get("damage", 0)),
		"blockers": blockers, "total_damage": total_damage, "source": context_before
	})
	engine._log(state, "Collision: %d damage." % damage)
	# Riders resolve after the original event's damage. Quarry observes existing
	# Rubble at damage time; Wheel consumes it before Millstone lays new Rubble.
	if not ground.is_empty():
		state = _break_ground(engine, state, id, tile, ground, wheel, blockers)
	if hero_force and not effect(engine, state, "collision_rubble").is_empty():
		var source: Dictionary = context.duplicate(true)
		source["relic_id"] = effect(engine, state, "collision_rubble").get("relic_id", "")
		for occupied: Vector2i in Surface.footprint_tiles(unit):
			Surface.place(state, occupied, "rubble", source)
	if hero_involved:
		var reward: int = Data.fixed_point_amount(int(effect(engine, state, "collision_player_defense").get("block", 0)))
		state["player"]["block"] = int(state["player"].get("block", 0)) + reward
	state["damage_context"] = context_before
	# Re-enter the ordinary mover only after all original collision damage. This
	# bounded action-local set also covers multiple force targets and Chain hops.
	if hero_force:
		state = _knock_blockers(engine, state, blockers, direction)
	state["damage_context"] = context_before
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	return state

static func _break_ground(engine: RefCounted, state: Dictionary, id: int, tile: Vector2i, ground: Dictionary, wheel: Dictionary, blockers: Array[Dictionary]) -> Dictionary:
	var element: String = str(ground.get("elemental", ""))
	if element == "ice":
		var action: Dictionary = {"type": "push", "_card_element": "ice", "_collision_freeze_tile": tile}
		var before: int = int(engine._surface_actor(state, "enemy", id).get("freeze", 0))
		state = engine._surface_freeze_actor(state, "enemy", id, action)
		if before == 0 and int(engine._surface_actor(state, "enemy", id).get("freeze", 0)) > 0:
			state = engine._trigger_status_relics(state, "freeze", action)
			state = engine._surface_status_light(state, "freeze", tile)
	elif element == "electrified":
		var action: Dictionary = {"type": "push", "shock": int(wheel.get("shock", 1))}
		state = engine._apply_action_keywords_to_enemy(state, engine._enemy_index_for_id(state, id), action, tile)
		for blocker: Dictionary in blockers:
			if str(blocker.get("kind", "")) == "enemy":
				state = engine._apply_action_keywords_to_enemy(state, engine._enemy_index_for_id(state, int(blocker.get("id", -1))), action, tile)
	if bool(ground.get("rubble", false)):
		engine._apply_stagger_to_enemy(state, id, int(wheel.get("rubble_stagger", 3)))
	Surface.remove(state, tile, "all", "force_collision")
	return state

static func _knock_blockers(engine: RefCounted, state: Dictionary, blockers: Array[Dictionary], direction: Vector2i) -> Dictionary:
	var knock: Dictionary = effect(engine, state, "collision_knock_chain")
	if knock.is_empty():
		return state
	var owned_set: bool = not state.has(KNOCKED_KEY)
	var knocked: Dictionary = state.get(KNOCKED_KEY, {})
	state[KNOCKED_KEY] = knocked
	for blocker: Dictionary in blockers:
		var id: int = int(blocker.get("id", -1))
		if str(blocker.get("kind", "")) != "enemy" or knocked.has(str(id)) or int(engine._surface_actor(state, "enemy", id).get("hp", 0)) <= 0:
			continue
		knocked[str(id)] = true
		state = engine._force_move_actor(state, "enemy", id, direction, int(knock.get("amount", 1)), {}, true)
	if owned_set:
		state.erase(KNOCKED_KEY)
	return state
