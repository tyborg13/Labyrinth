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
	if effect(effects, "alternating_element_card_bonus").is_empty() and effect(effects, "matching_equipment_card_bonus").is_empty() and effect(effects, "combat_element_knots").is_empty():
		return card
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
	var prevent_block: bool = not effect(effects, "prevent_card_block").is_empty()
	if prevent_block: block = 0
	var actions: Array = result.get("actions", []) as Array
	_modify_card_actions(actions, damage, block, tied.size() if not knot_effect.is_empty() else 0, knot_effect)
	if block > 0 and not actions.any(func(a: Dictionary) -> bool: return str(a.get("type", "")) == "block"):
		actions.append({"type": "block", "amount": block})
	if not prevent_block and not knot_effect.is_empty() and tied.size() >= int(knot_effect.get("block_threshold", 5)):
		actions.append({"type": "block", "amount": int(knot_effect.get("block", 3)), "_knot_reward": true})
	result["actions"] = actions
	return result

static func _modify_card_actions(actions: Array, damage: int, block: int, count: int, knot_effect: Dictionary) -> void:
	for action: Dictionary in actions:
		if action.has("damage"): action["damage"] = int(action["damage"]) + damage
		if str(action.get("type", "")) == "block": action["amount"] = int(action.get("amount", 0)) + block
		if str(action.get("type", "")) in Tempo.ATTACK_ACTION_TYPES and not Tempo.is_forced_movement_only(action):
			if count >= int(knot_effect.get("pierce_threshold", 3)): action["pierce"] = true
			if count >= int(knot_effect.get("chain_threshold", 4)): action["chain"] = maxi(int(knot_effect.get("chain", 1)), int(action.get("chain", 0)))
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
		if tied.size() >= int(knot_effect.get("pierce_threshold", 3)): action["pierce"] = true
		if tied.size() >= int(knot_effect.get("chain_threshold", 4)): action["chain"] = maxi(int(knot_effect.get("chain", 1)), int(action.get("chain", 0)))
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

# Unclouded Sun relays: the source tile of each of your active Lights.
static func light_relays(state: Dictionary) -> Dictionary:
	var relays: Dictionary = {}
	for source: Dictionary in (state.get("umbra", {}) as Dictionary).get("light_sources", []):
		if str(source.get("owner", "")) == "player" and int(source.get("remaining_activations", -1)) != 0:
			relays[source.get("pos", Vector2i(-999, -999))] = true
	return relays

# One Move step between two relays that are not neighbours: an Unclouded Sun
# link. It costs one step and is presented as a blink from relay to relay.
static func is_light_link(state: Dictionary, from: Vector2i, to: Vector2i) -> bool:
	if Paths.manhattan(from, to) <= 1:
		return false
	var relays: Dictionary = light_relays(state)
	return relays.has(from) and relays.has(to)

static func refund_available(state: Dictionary, effects: Array) -> int:
	var entry: Dictionary = effect(effects, "light_move_refund")
	return maxi(0, int(entry.get("max", 2)) - int((state.get("turn_flags", {}) as Dictionary).get(REFUNDS, 0))) if not entry.is_empty() else 0

static func claim_refund(state: Dictionary, tile: Vector2i, effects: Array, step_cost: int) -> int:
	if step_cost <= 0 or refund_available(state, effects) <= 0 or not hero_light(state, tile): return 0
	var flags: Dictionary = state.get("turn_flags", {}) as Dictionary
	flags[REFUNDS] = int(flags.get(REFUNDS, 0)) + 1
	state["turn_flags"] = flags
	return 1

static func move_rules(effects: Array) -> bool:
	return not effect(effects, "light_move_refund").is_empty() or not effect(effects, "move_through_enemies_stagger").is_empty() or not effect(effects, "light_move_links").is_empty()

# Cost-ordered search. A state is (tile, refunds used, direction only for
# straight Move / Winter's Spur). Pareto labels retain safer or loot-bearing
# alternatives within the budget, as the ordinary navigation prefers those.
# Each label stores only its predecessor; materialize winning paths at the end.
static func navigation(engine: RefCounted, state: Dictionary, unit: Dictionary, budget: int, occupied: Dictionary, minimum: bool, hazard: Callable, pickup: Callable, stop: Callable, effects: Array) -> Dictionary:
	var vault: bool = not effect(effects, "move_through_enemies_stagger").is_empty()
	var enemy_tiles: Dictionary = engine._occupied_visible_enemy_tiles(state) if vault else {}
	var endpoints: Dictionary = state.get("_movement_allowed_endpoints", {}) as Dictionary
	var linked: bool = not effect(effects, "light_move_links").is_empty()
	var straight: bool = bool(state.get("_straight_move", false))
	var stride: bool = engine.GuardianRelicRules.amount(state, "ice_stride") > 0
	var skating: bool = engine.ManeuverRules.player_skating(state)
	var directional: bool = straight or (stride and not skating)
	# A Glassway trade enters only its landing tile, so in the trade search only
	# an Illusion endpoint can earn a Light refund.
	var trade_search: bool = bool(state.get("_movement_trade_search", false))
	var max_refunds: int = refund_available(state, effects)
	var passable: Array[Vector2i] = engine._all_passable_tiles(state)
	var indices: Dictionary = {}
	var lights: Dictionary = {}
	var relays: Dictionary = light_relays(state) if linked else {}
	var relay_tiles: Array[Vector2i]
	var harms: Dictionary = {}
	var loot_scores: Dictionary = {}
	for tile: Vector2i in passable:
		indices[tile] = indices.size()
		if hero_light(state, tile) and (not trade_search or endpoints.has(tile)):
			lights[tile] = true
		if relays.has(tile):
			relay_tiles.append(tile)
		harms[tile] = int(hazard.call(tile))
		loot_scores[tile] = int(pickup.call(tile))
	# Build every geometric neighbour list once. Light jumps are explicit edges
	# between relays (Light sources), and cardinal neighbours retain their
	# normal Rubble/Skate cost.
	var neighbours: Dictionary = {}
	var step_costs: Dictionary = {}
	for tile: Vector2i in passable:
		var adjacent: Array[Vector2i]
		var costs: Dictionary = {}
		for direction: Vector2i in Paths.DIRS_4:
			var to: Vector2i = tile + direction
			if not indices.has(to) or (occupied.has(to) and not enemy_tiles.has(to) and not endpoints.has(to)): continue
			adjacent.append(to)
			costs[to] = 0 if skating and Surface.has_surface(state, to, "ice") else Surface.movement_step_cost(state, unit, tile, to)
		if linked and not straight and relays.has(tile):
			for to: Vector2i in relay_tiles:
				if Paths.manhattan(tile, to) <= 1 or (occupied.has(to) and not enemy_tiles.has(to) and not endpoints.has(to)): continue
				adjacent.append(to)
				costs[to] = 1
		neighbours[tile] = adjacent
		step_costs[tile] = costs
	var start: Vector2i = unit["pos"]
	var records: Array[Dictionary]
	records.append({"tile": start, "cost": 0, "harm": 0, "pickup": 0, "refunds": 0, "direction": Vector2i.ZERO, "parent": -1, "active": true})
	var frontier: Array[int]
	frontier.append(0)
	var initial_labels: Array[int]
	initial_labels.append(0)
	var best: Dictionary = {_navigation_key(int(indices[start]), 0, Vector2i.ZERO, max_refunds, directional): initial_labels}
	var winners: Dictionary = {start: 0}
	while not frontier.is_empty():
		var current_id: int = _heap_pop(frontier, records)
		var current: Dictionary = records[current_id]
		if not bool(current["active"]): continue
		var from: Vector2i = current["tile"]
		if endpoints.has(from) and current_id != 0: continue
		for tile: Vector2i in neighbours[from]:
			var direction: Vector2i = tile - from
			if straight and current_id != 0 and direction != current["direction"]: continue
			var entry: int = int(step_costs[from][tile])
			if stride and not skating and current["direction"] == direction and Surface.has_surface(state, from, "ice") and Surface.has_surface(state, tile, "ice"):
				entry = maxi(0, entry - 1)
			if current_id == 0 and minimum and budget > 0: entry = mini(entry, budget)
			var refunds: int = int(current["refunds"])
			if entry > 0 and refunds < max_refunds and lights.has(tile):
				entry -= 1
				refunds += 1
			var spent: int = int(current["cost"]) + entry
			if spent > budget: continue
			var harm: int = int(current["harm"]) + int(harms[tile])
			var loot: int = int(current["pickup"]) + int(loot_scores[tile])
			# Only a cardinal incoming direction can affect the next Ice step.
			var next_direction: Vector2i = direction if directional and Paths.manhattan(from, tile) == 1 else Vector2i.ZERO
			var key: int = _navigation_key(int(indices[tile]), refunds, next_direction, max_refunds, directional)
			var labels: Array = best.get(key, [])
			var dominated: bool = false
			for prior_id: int in labels:
				var prior: Dictionary = records[prior_id]
				if int(prior["cost"]) <= spent and int(prior["harm"]) <= harm and int(prior["pickup"]) >= loot:
					dominated = true
					break
			if dominated or _predecessor_contains(records, current_id, tile): continue
			var kept: Array[int]
			for prior_id: int in labels:
				var prior: Dictionary = records[prior_id]
				if spent <= int(prior["cost"]) and harm <= int(prior["harm"]) and loot >= int(prior["pickup"]):
					prior["active"] = false
				else: kept.append(prior_id)
			var id: int = records.size()
			records.append({"tile": tile, "cost": spent, "harm": harm, "pickup": loot, "refunds": refunds, "direction": next_direction, "parent": current_id, "active": true})
			kept.append(id)
			best[key] = kept
			if not occupied.has(tile) or endpoints.has(tile):
				var prior: Dictionary = records[int(winners[tile])] if winners.has(tile) else {}
				var preferred: bool = prior.is_empty()
				if not preferred:
					preferred = harm < int(prior["harm"]) or (harm == int(prior["harm"]) and loot > int(prior["pickup"]))
					preferred = preferred or (harm == int(prior["harm"]) and loot == int(prior["pickup"]) and spent < int(prior["cost"]))
				if preferred:
					winners[tile] = id
					if stop.is_valid() and bool(stop.call(tile)): return _navigation_result(records, winners)
			_heap_push(frontier, records, id)
	return _navigation_result(records, winners)

static func _navigation_key(tile_index: int, refunds: int, direction: Vector2i, max_refunds: int, directional: bool) -> int:
	var key: int = tile_index * (max_refunds + 1) + refunds
	return key * 5 + Paths.DIRS_4.find(direction) + 1 if directional else key

static func _predecessor_contains(records: Array[Dictionary], id: int, tile: Vector2i) -> bool:
	while id >= 0:
		if records[id]["tile"] == tile: return true
		id = int(records[id]["parent"])
	return false

static func _navigation_result(records: Array[Dictionary], winners: Dictionary) -> Dictionary:
	var paths: Dictionary = {}
	var costs: Dictionary = {}
	var hazards: Dictionary = {}
	for tile: Vector2i in winners:
		var id: int = int(winners[tile])
		costs[tile] = int(records[id]["cost"])
		hazards[tile] = int(records[id]["harm"])
		var path: Array[Vector2i]
		while id >= 0:
			path.append(records[id]["tile"])
			id = int(records[id]["parent"])
		path.reverse()
		paths[tile] = path
	return {"paths": paths, "costs": costs, "hazards": hazards}

static func _heap_before(records: Array[Dictionary], a: int, b: int) -> bool:
	var left: Dictionary = records[a]
	var right: Dictionary = records[b]
	if left["cost"] != right["cost"]: return int(left["cost"]) < int(right["cost"])
	return a < b # Stable discovery order resolves otherwise identical paths.

static func _heap_push(heap: Array[int], records: Array[Dictionary], id: int) -> void:
	heap.append(id)
	var child: int = heap.size() - 1
	while child > 0:
		var parent: int = (child - 1) / 2
		if not _heap_before(records, heap[child], heap[parent]): break
		var swap: int = heap[parent]
		heap[parent] = heap[child]
		heap[child] = swap
		child = parent

static func _heap_pop(heap: Array[int], records: Array[Dictionary]) -> int:
	var result: int = heap[0]
	var tail: int = heap.pop_back()
	if heap.is_empty(): return result
	heap[0] = tail
	var parent: int = 0
	while parent * 2 + 1 < heap.size():
		var child: int = parent * 2 + 1
		if child + 1 < heap.size() and _heap_before(records, heap[child + 1], heap[child]): child += 1
		if not _heap_before(records, heap[child], heap[parent]): break
		var swap: int = heap[parent]
		heap[parent] = heap[child]
		heap[child] = swap
		parent = child
	return result
