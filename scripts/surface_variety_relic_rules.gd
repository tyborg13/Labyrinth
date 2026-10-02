extends RefCounted

## U7 rules. GameData calls card modifiers here, so this module must not preload
## GameData or any module that depends on it. State is saved in combat dictionaries.
const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const STORED := "relic_stored_surfaces"
const KNOTS := "relic_element_knots"
const LAST := "variety_last_card_element"
const REFUNDS := "light_move_refunds"
const ELEMENTS: Array = ["fire", "ice", "lightning", "air", "earth"]
const STATUSES: Array = ["bleed", "expose", "shock", "freeze", "chilled", "immobilize", "petrify"]

static func effect(effects: Array, type: String) -> Dictionary:
	for entry: Dictionary in effects:
		if str(entry.get("type", "")) == type: return entry
	return {}

static func stored(state: Dictionary) -> Array:
	return state.get(STORED, []) as Array

static func knots(state: Dictionary) -> Array:
	return state.get(KNOTS, []) as Array

static func modify_card(card: Dictionary, state: Dictionary, effects: Array, equipment: Dictionary, granted_cards: Dictionary) -> Dictionary:
	var result: Dictionary = card.duplicate(true)
	var element: String = str(card.get("element", "none"))
	var damage: int = 0
	var block: int = 0
	var alternating: Dictionary = effect(effects, "alternating_element_card_bonus")
	var previous: String = str((state.get("turn_flags", {}) as Dictionary).get(LAST, "none"))
	if not alternating.is_empty() and ELEMENTS.has(element) and ELEMENTS.has(previous) and element != previous:
		damage += int(alternating.get("damage", 2))
		block += int(alternating.get("block", 2))
	var bonded: Dictionary = effect(effects, "matching_equipment_card_bonus")
	if not bonded.is_empty():
		var equipped: Array = (state.get("equipped_equipment", {}) as Dictionary).values()
		for item_id: Variant in equipped:
			var item: Dictionary = equipment.get(str(item_id), {}) as Dictionary
			var gear_element: String = str(item.get("element", "none"))
			if gear_element in ["", "none"] or not (granted_cards.get(str(item_id), []) as Array).has(str(card.get("id", ""))): continue
			if equipped.any(func(other: Variant) -> bool: return other != item_id and str((equipment.get(str(other), {}) as Dictionary).get("element", "none")) == gear_element):
				damage += int(bonded.get("damage", 1))
				block += int(bonded.get("block", 1))
				break # A card shared by two pieces is still improved only once.
	var tied: Array = knots(state).duplicate()
	if ELEMENTS.has(element) and not tied.has(element): tied.append(element)
	var knot_effect: Dictionary = effect(effects, "combat_element_knots")
	var actions: Array = result.get("actions", []) as Array
	_modify_card_actions(actions, damage, block, tied.size() if not knot_effect.is_empty() else 0, knot_effect)
	if block > 0 and not actions.any(func(a: Dictionary) -> bool: return str(a.get("type", "")) == "block"):
		actions.append({"type": "block", "amount": block})
	if not knot_effect.is_empty() and tied.size() >= 5:
		actions.append({"type": "block", "amount": int(knot_effect.get("block", 3)), "_knot_reward": true})
	result["actions"] = actions
	return result

static func _modify_card_actions(actions: Array, damage: int, block: int, count: int, knot_effect: Dictionary) -> void:
	for action: Dictionary in actions:
		if action.has("damage"): action["damage"] = int(action["damage"]) + damage
		if str(action.get("type", "")) == "block": action["amount"] = int(action.get("amount", 0)) + block
		if str(action.get("type", "")) in Tempo.ATTACK_ACTION_TYPES and not Tempo.is_forced_movement_only(action):
			if count >= 3: action["pierce"] = true
			if count >= 4: action["chain"] = maxi(1, int(action.get("chain", 0)))
		# Conditional rewards belong to the same card, including Block riders.
		if action.has("rewards"): _modify_card_actions(action["rewards"], damage, block, count, knot_effect)
		if action.has("on_result"): _modify_card_actions((action["on_result"] as Dictionary).get("rewards", []), damage, block, count, knot_effect)

static func finish_card(state: Dictionary, element: String, effects: Array) -> void:
	var flags: Dictionary = state.get("turn_flags", {}) as Dictionary
	flags[LAST] = element # A none card breaks Chorus's sequence as well.
	state["turn_flags"] = flags
	if not effect(effects, "combat_element_knots").is_empty() and ELEMENTS.has(element):
		var tied: Array = knots(state).duplicate()
		if not tied.has(element): tied.append(element)
		state[KNOTS] = tied

static func resolve_action(state: Dictionary, action: Dictionary, effects: Array) -> void:
	if bool(action.get("_enemies_only", false)) or str(action.get("type", "")) not in Tempo.ATTACK_ACTION_TYPES or Tempo.is_forced_movement_only(action): return
	var knot_effect: Dictionary = effect(effects, "combat_element_knots")
	var tied: Array = knots(state).duplicate()
	var element: String = str(action.get("_card_element", "none"))
	if ELEMENTS.has(element) and not tied.has(element): tied.append(element)
	if not knot_effect.is_empty():
		if tied.size() >= 3: action["pierce"] = true
		if tied.size() >= 4: action["chain"] = maxi(1, int(action.get("chain", 0)))
	var dial: Dictionary = effect(effects, "store_consumed_surface_release")
	if not dial.is_empty() and not stored(state).is_empty():
		action["_stored_release"] = stored(state).duplicate()
		action["_stored_release_damage"] = stored(state).size() * int(dial.get("damage", 2))
		action["damage"] = int(action.get("damage", 0)) + int(action["_stored_release_damage"])

static func before_action(state: Dictionary, action: Dictionary) -> void:
	if action.has("_stored_release"): state[STORED] = []

static func after_action(engine: RefCounted, before: Dictionary, state: Dictionary, action: Dictionary, target: Vector2i, effects: Array) -> Dictionary:
	var dial: Dictionary = effect(effects, "store_consumed_surface_release")
	if not dial.is_empty():
		var held: Array = stored(state).duplicate()
		for event: Dictionary in state.get("surface_events", []):
			if int(event.get("sequence", 0)) <= int(before.get("surface_event_sequence", 0)): continue
			var source: Dictionary = event.get("source", {}) as Dictionary
			if str(source.get("actor_kind", "")) != "player" or str(source.get("source_kind", "")) == "trap": continue
			if str(event.get("kind", "")) == "surface_removed" and str(event.get("reason", "")) in ["detonate", "chain", "conduction", "freeze", "consume", "attack_consume", "melee_consume", "relic_redirect", "relic_attack_origin", "force_collision", "discharge", "consumed", "clear"]:
				if held.size() < int(dial.get("capacity", 3)): held.append(str(event["surface"]))
		state[STORED] = held
	if action.has("_stored_release"):
		var index: int = engine._enemy_index_for_id(state, int((state.get("last_action_target_actor", {}) as Dictionary).get("enemy_id", -1)))
		if index < 0: index = engine._enemy_index_at_tile(state, target)
		if index >= 0:
			for surface: String in action["_stored_release"]:
				# Keyword application normalizes/replaces the enemy dictionary.
				var enemy: Dictionary = state["enemies"][index]
				match surface:
					"fire":
						for tile: Vector2i in Surface.footprint_tiles(enemy): Surface.place(state, tile, "fire", {"kind": "relic", "actor_kind": "player"})
					"ice":
						if int(enemy.get("hp", 0)) > 0 and int(enemy.get("freeze", 0)) <= 0 and not engine._enemy_is_immune_to_status(enemy, "chilled"):
							enemy["chilled"] = true
							enemy["relic_chilled"] = true # Chill from a rider does not need supporting Ice.
					"electrified": state = engine._apply_action_keywords_to_enemy(state, index, {"shock": 1}, target)
					"rubble": engine._apply_stagger_to_enemy(state, int(enemy["id"]), 2)
	return state

static func blink(state: Dictionary, distance: int, effects: Array) -> void:
	var entry: Dictionary = effect(effects, "blink_distance_next_attack")
	if entry.is_empty() or distance <= 0: return
	# Repeated Blinks replace the pending bonus with this Blink's distance.
	var buffs: Array = Tempo.next_attack_buffs(state)
	for index: int in range(buffs.size() - 1, -1, -1):
		if bool((buffs[index] as Dictionary).get("blink_distance", false)): buffs.remove_at(index)
	Tempo.gain_next_attack(state, {"damage": mini(distance, int(entry.get("max", 4)))}, str(entry.get("source_name", "Gale Tabi")))
	Tempo.next_attack_buffs(state).back()["blink_distance"] = true
	Tempo.next_attack_buffs(state).back()["granted_at"] = -1 # Also usable later in this card.

static func death(engine: RefCounted, state: Dictionary, enemy: Dictionary, effects: Array, on_fire: bool) -> Dictionary:
	var footprint: Array[Vector2i] = Surface.footprint_tiles(enemy)
	var adjacent: Dictionary = {}
	for tile: Vector2i in footprint:
		for direction: Vector2i in Paths.DIRS_4:
			if not footprint.has(tile + direction): adjacent[tile + direction] = true
	if on_fire and not effect(effects, "death_on_surface_spread").is_empty():
		for tile: Vector2i in adjacent:
			if Surface.element_at(state, tile).is_empty(): Surface.place(state, tile, "fire", {"kind": "relic", "actor_kind": "player"})
	var spread: Dictionary = effect(effects, "death_status_spread")
	var statuses: Dictionary = {}
	for status: String in STATUSES:
		if int(enemy.get(status, 0)) > 0: statuses[status] = enemy[status]
	if spread.is_empty() or statuses.size() < int(spread.get("threshold", 2)): return state
	for other: Dictionary in state.get("enemies", []):
		if int(other.get("hp", 0)) <= 0 or not Surface.footprint_tiles(other).any(func(tile: Vector2i) -> bool: return adjacent.has(tile)): continue
		var index: int = engine._enemy_index_for_id(state, int(other["id"]))
		state = engine._apply_action_keywords_to_enemy(state, index, statuses, enemy.get("pos", Vector2i.ZERO))
		other = state["enemies"][index]
		for status: String in ["freeze", "chilled", "immobilize", "petrify"]:
			if not statuses.has(status) or engine._enemy_is_immune_to_status(other, status): continue
			if status == "freeze":
				other["freeze"] = maxi(int(other.get("freeze", 0)), int(statuses[status]))
				other["chilled"] = false
				other.erase("relic_chilled")
			elif status == "chilled" and int(other.get("freeze", 0)) <= 0:
				other["chilled"] = true
				other["relic_chilled"] = true
			elif status == "immobilize": other["immobilize"] = true
			elif status == "petrify" and not engine.DragonBossLibrary.is_dragon_boss_id(str(other.get("type", ""))): other["petrify"] = maxi(int(other.get("petrify", 0)), int(statuses[status]))
	return state

static func hero_light(state: Dictionary, tile: Vector2i) -> bool:
	for source: Dictionary in (state.get("umbra", {}) as Dictionary).get("light_sources", []):
		if str(source.get("owner", "")) == "player" and int(source.get("remaining_activations", -1)) != 0 and Paths.manhattan(source.get("pos", Vector2i(-999, -999)), tile) <= int(source.get("radius", 0)): return true
	return false

static func refund_available(state: Dictionary, effects: Array) -> int:
	var entry: Dictionary = effect(effects, "light_move_refund")
	return maxi(0, int(entry.get("max", 2)) - int((state.get("turn_flags", {}) as Dictionary).get(REFUNDS, 0))) if not entry.is_empty() else 0

static func claim_refund(state: Dictionary, tile: Vector2i, effects: Array) -> int:
	if refund_available(state, effects) <= 0 or not hero_light(state, tile): return 0
	var flags: Dictionary = state.get("turn_flags", {}) as Dictionary
	flags[REFUNDS] = int(flags.get(REFUNDS, 0)) + 1
	state["turn_flags"] = flags
	return 1

static func move_rules(effects: Array) -> bool:
	return not effect(effects, "light_move_refund").is_empty() or not effect(effects, "move_through_enemies_stagger").is_empty() or not effect(effects, "light_move_links").is_empty()

static func navigation(engine: RefCounted, state: Dictionary, unit: Dictionary, budget: int, occupied: Dictionary, minimum: bool, hazard: Callable, pickup: Callable, stop: Callable, effects: Array) -> Dictionary:
	var vault: bool = not effect(effects, "move_through_enemies_stagger").is_empty()
	var enemy_tiles: Dictionary = engine._occupied_visible_enemy_tiles(state) if vault else {}
	var light_tiles: Array[Vector2i]
	if not effect(effects, "light_move_links").is_empty():
		for tile: Vector2i in engine._all_passable_tiles(state):
			if hero_light(state, tile): light_tiles.append(tile)
	var start: Vector2i = unit["pos"]
	var first_path: Array[Vector2i]
	first_path.append(start)
	var paths: Dictionary = {start: first_path}
	var costs: Dictionary = {start: 0}
	var hazards: Dictionary = {start: 0}
	var pickups: Dictionary = {start: 0}
	var queue: Array[Dictionary]
	queue.append({"tile": start, "cost": 0, "harm": 0, "pickup": 0, "refunds": 0, "path": first_path, "direction": Vector2i.ZERO})
	var best: Dictionary = {}
	var cursor: int = 0
	while cursor < queue.size():
		var current: Dictionary = queue[cursor]
		cursor += 1
		var next_tiles: Array[Vector2i]
		for direction: Vector2i in Paths.DIRS_4: next_tiles.append(current["tile"] + direction)
		if not bool(state.get("_straight_move", false)) and light_tiles.has(current["tile"]):
			for tile: Vector2i in light_tiles:
				if not next_tiles.has(tile): next_tiles.append(tile)
		for tile: Vector2i in next_tiles:
			if bool(state.get("_straight_move", false)) and (current["path"] as Array).size() > 1 and tile - (current["tile"] as Vector2i) != current["direction"]: continue
			if not Paths.is_passable(state["grid"], tile) or (occupied.has(tile) and not enemy_tiles.has(tile)) or (current["path"] as Array).has(tile): continue
			var entry: int = engine.hero_move_step_cost(state, unit, current["tile"], tile, current["direction"])
			if (current["path"] as Array).size() == 1 and minimum and budget > 0: entry = mini(entry, budget)
			var refunds: int = int(current["refunds"])
			if refunds < refund_available(state, effects) and hero_light(state, tile):
				entry -= 1
				refunds += 1
			var spent: int = int(current["cost"]) + entry
			if spent > budget: continue
			var harm: int = int(current["harm"]) + int(hazard.call(tile))
			var loot: int = int(current["pickup"]) + int(pickup.call(tile))
			var direction: Vector2i = tile - (current["tile"] as Vector2i)
			var key: String = "%s:%s:%d:%d" % [tile, direction, spent, refunds]
			if best.has(key):
				var prior: Dictionary = best[key]
				if int(prior["harm"]) < harm or (int(prior["harm"]) == harm and int(prior["pickup"]) >= loot): continue
			best[key] = {"harm": harm, "pickup": loot}
			var path: Array[Vector2i]
			path.assign(current["path"])
			path.append(tile)
			if not occupied.has(tile) and (not paths.has(tile) or harm < int(hazards[tile]) or (harm == int(hazards[tile]) and (loot > int(pickups[tile]) or (loot == int(pickups[tile]) and spent < int(costs[tile]))))):
				paths[tile] = path
				costs[tile] = spent
				hazards[tile] = harm
				pickups[tile] = loot
				if stop.is_valid() and bool(stop.call(tile)): return {"paths": paths, "costs": costs, "hazards": hazards}
			queue.append({"tile": tile, "cost": spent, "harm": harm, "pickup": loot, "refunds": refunds, "path": path, "direction": direction})
	return {"paths": paths, "costs": costs, "hazards": hazards}
