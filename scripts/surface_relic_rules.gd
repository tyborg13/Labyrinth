extends RefCounted
class_name SurfaceRelicRules

const GameData = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const INVALID: Vector2i = Vector2i(-999999, -999999)
const CROSS: Array = [Vector2i.ZERO, Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

# These are techniques on the existing paid action, not extra actions. Keeping
# their choices on the action lets the ordinary preview execute the same rules.
static func configure(state: Dictionary) -> void:
	var overrides: Dictionary = state.get("surface_rule_overrides", {}) as Dictionary
	overrides["conductive_fire"] = has_effect(state, "conductive_fire")
	state["surface_rule_overrides"] = overrides

static func effects(state: Dictionary) -> Array[Dictionary]:
	return GameData.relic_effects_for_ids(state.get("relics", []) as Array)

static func effect(state: Dictionary, effect_type: String) -> Dictionary:
	for entry: Dictionary in effects(state):
		if str(entry.get("type", "")) == effect_type:
			return entry
	return {}

static func has_effect(state: Dictionary, effect_type: String) -> bool:
	return not effect(state, effect_type).is_empty()

static func mode_enabled(action: Dictionary, mode: String) -> bool:
	return (action.get("_surface_relic_modes", []) as Array).has(mode) or str(action.get("_surface_relic_mode", "")) == mode

static func _with_mode(action: Dictionary, mode: String, label: String) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	var modes: Array = (result.get("_surface_relic_modes", []) as Array).duplicate()
	var old_mode: String = str(result.get("_surface_relic_mode", ""))
	if not old_mode.is_empty() and not modes.has(old_mode):
		modes.append(old_mode)
	result.erase("_surface_relic_mode")
	if modes.has(mode):
		modes.erase(mode)
	else:
		modes.append(mode)
	result["_surface_relic_modes"] = modes
	result["_surface_relic_label"] = label
	return result

static func action_variants(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var ordinary: Dictionary = action.duplicate(true)
	for key: String in ["_surface_relic_modes", "_surface_relic_mode", "_origin_tile", "_ice_spill_direction"]:
		ordinary.erase(key)
	ordinary["_surface_relic_label"] = "Normal"
	result.append(ordinary)
	var action_type: String = str(action.get("type", ""))
	if action_type in ["push", "pull"]:
		if has_effect(state, "transport_surface"):
			result.append(_with_mode(action, "transport", "Carry elemental ground"))
		if has_effect(state, "rubble_redirect"):
			result.append(_with_mode(action, "redirect", "Spend Rubble · redirect"))
	if action_type == "melee" and int(action.get("chain", 0)) <= 0 and has_effect(state, "stoneskin_melee_cross"):
		var price: int = int(effect(state, "stoneskin_melee_cross").get("cost", 4))
		if int((state.get("player", {}) as Dictionary).get("stoneskin", 0)) >= price:
			result.append(_with_mode(action, "cross", "Spend %d Stoneskin · cross" % price))
	if action_type == "detonate" and has_effect(state, "rubble_detonate"):
		result.append(_with_mode(action, "crush", "Crush Rubble"))
	if int(action.get("chain", 0)) > 0 and has_effect(state, "chain_swap_endpoints"):
		result.append(_with_mode(action, "swap", "Exchange Chain endpoints"))
	if action_type in ["melee", "ranged"] and has_effect(state, "rubble_attack_origin") and Surface.unit_on(state, state.get("player", {}) as Dictionary, "rubble"):
		result.append(_with_mode(action, "remote", "Strike through Worldroot"))
	if action_type in ["melee", "ranged", "aoe"] and _element(action) == "ice" and has_effect(state, "freeze_relocate_ice"):
		for index: int in range(PathUtils.DIRS_4.size()):
			var spill: Dictionary = action.duplicate(true)
			spill["_ice_spill_direction"] = PathUtils.DIRS_4[index]
			spill["_surface_relic_label"] = "Spill Ice · %s" % ["north", "east", "south", "west"][index]
			result.append(spill)
	return result

static func resolve_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var result: Dictionary = action.duplicate(true)
	if mode_enabled(result, "cross") and str(result.get("type", "")) == "melee":
		var price: int = int(effect(state, "stoneskin_melee_cross").get("cost", 4))
		if not has_effect(state, "stoneskin_melee_cross") or int((state.get("player", {}) as Dictionary).get("stoneskin", 0)) < price or int(result.get("chain", 0)) > 0:
			result["_surface_relic_invalid"] = true
		else:
			result["_native_action_type"] = "melee"
			result["type"] = "aoe"
			result["pattern"] = [[0, 0], [0, -1], [1, 0], [0, 1], [-1, 0]]
			result["rotate"] = false
	if mode_enabled(result, "redirect"):
		result["_allow_sideways_force"] = has_effect(state, "rubble_redirect")
	if mode_enabled(result, "crush"):
		result["_detonate_surface"] = "rubble"
	if mode_enabled(result, "remote") and not result.has("_origin_tile"):
		result["_surface_relic_needs_origin"] = true
	return result

static func origin_tiles(state: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if not has_effect(state, "rubble_attack_origin"):
		return result
	var start: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	if not Surface.has_rubble(state, start):
		return result
	var queue: Array[Vector2i]
	queue.append(start)
	var seen: Dictionary = {start: true}
	var cursor: int = 0
	while cursor < queue.size():
		var tile: Vector2i = queue[cursor]
		cursor += 1
		if tile != start:
			result.append(tile)
		for direction: Vector2i in PathUtils.DIRS_4:
			var adjacent: Vector2i = tile + direction
			if not seen.has(adjacent) and Surface.can_place(state, adjacent) and Surface.has_rubble(state, adjacent):
				seen[adjacent] = true
				queue.append(adjacent)
	return result

static func can_prepare(state: Dictionary, action: Dictionary, target: Vector2i) -> bool:
	if bool(action.get("_surface_relic_invalid", false)):
		return false
	var type: String = str(action.get("_native_action_type", action.get("type", "")))
	var mode_effects: Dictionary = {"transport": "transport_surface", "redirect": "rubble_redirect", "cross": "stoneskin_melee_cross", "crush": "rubble_detonate", "remote": "rubble_attack_origin", "swap": "chain_swap_endpoints"}
	for mode: String in mode_effects:
		if mode_enabled(action, mode) and not has_effect(state, str(mode_effects[mode])):
			return false
	if (mode_enabled(action, "transport") or mode_enabled(action, "redirect")) and type not in ["push", "pull"]:
		return false
	if mode_enabled(action, "cross") and (type != "melee" or int(action.get("chain", 0)) > 0 or int((state.get("player", {}) as Dictionary).get("stoneskin", 0)) < int(effect(state, "stoneskin_melee_cross").get("cost", 4))):
		return false
	if mode_enabled(action, "crush") and type != "detonate":
		return false
	if mode_enabled(action, "swap") and int(action.get("chain", 0)) <= 0:
		return false
	if action.has("_ice_spill_direction") and (not has_effect(state, "freeze_relocate_ice") or _element(action) != "ice"):
		return false
	if mode_enabled(action, "remote"):
		if type not in ["melee", "ranged"] or mode_enabled(action, "cross") or not origin_tiles(state).has(action.get("_origin_tile", INVALID)):
			return false
	if mode_enabled(action, "redirect"):
		var unit: Dictionary = enemy_at(state, target)
		if unit.is_empty() or not Surface.unit_on(state, unit, "rubble"):
			return false
	return true

static func before_action(_engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	configure(state)
	var context: Dictionary = {"target": target, "surface_sequence": int(state.get("surface_event_sequence", 0))}
	var unit: Dictionary = enemy_at(state, target)
	if not unit.is_empty():
		context["target_id"] = int(unit.get("id", -1))
		context["target_origin"] = unit.get("pos", INVALID)
		var ground: Dictionary = {}
		for tile: Vector2i in Surface.footprint_tiles(unit):
			var element: String = Surface.element_at(state, tile)
			if not element.is_empty():
				ground[Surface.tile_key(tile)] = {"elemental": element, "source": Surface.surface_at(state, tile).get("elemental_source", {})}
		context["transport_ground"] = ground
	if mode_enabled(action, "cross"):
		var player: Dictionary = state.get("player", {}) as Dictionary
		player["stoneskin"] = maxi(0, int(player.get("stoneskin", 0)) - int(effect(state, "stoneskin_melee_cross").get("cost", 4)))
		state["player"] = player
	if mode_enabled(action, "redirect"):
		for tile: Vector2i in Surface.footprint_tiles(unit):
			Surface.remove(state, tile, "rubble", "relic_redirect")
	if mode_enabled(action, "remote"):
		Surface.remove(state, action.get("_origin_tile", INVALID), "rubble", "relic_attack_origin")
	state["_surface_relic_context"] = context
	return state

static func apply_events(engine: RefCounted, before_state: Dictionary, after_state: Dictionary, action: Dictionary, target: Vector2i = INVALID, trace: Dictionary = {}) -> Dictionary:
	var state: Dictionary = after_state
	configure(state)
	var context: Dictionary = state.get("_surface_relic_context", {}) as Dictionary
	if target == INVALID:
		target = context.get("target", INVALID)
	var events: Array[Dictionary] = events_since(state, int(before_state.get("surface_event_sequence", 0)))
	if mode_enabled(action, "transport") and has_effect(state, "transport_surface"):
		_transport(state, context)
	if mode_enabled(action, "cross") and has_effect(state, "stoneskin_melee_cross"):
		for delta: Vector2i in CROSS:
			Surface.place(state, target + delta, "rubble", _source("stoneskin_melee_cross"))
	if mode_enabled(action, "crush") and has_effect(state, "rubble_detonate"):
		for event: Dictionary in events:
			if str(event.get("kind", "")) == "surface_removed" and str(event.get("surface", "")) == "rubble" and str(event.get("reason", "")).contains("detonate"):
				Surface.place(state, event.get("tile", INVALID), "fire", _source("rubble_detonate"))
	_frozen_transitions(before_state, state, action, events)
	if mode_enabled(action, "swap") and has_effect(state, "chain_swap_endpoints"):
		state = _exchange_endpoints(engine, state, trace)
	state = _event_rewards(engine, before_state, state, action, target, events, trace)
	state.erase("_surface_relic_context")
	return state

static func _transport(state: Dictionary, context: Dictionary) -> void:
	var unit: Dictionary = enemy_by_id(state, int(context.get("target_id", -1)))
	if unit.is_empty() or int(unit.get("hp", 0)) <= 0:
		return
	var from: Vector2i = context.get("target_origin", INVALID)
	var offset: Vector2i = (unit.get("pos", from) as Vector2i) - from
	if offset == Vector2i.ZERO:
		return
	var replaced_ground: Dictionary = {}
	for event: Dictionary in events_since(state, int(context.get("surface_sequence", 0))):
		if str(event.get("surface", "")) != "rubble" and str(event.get("kind", "")) in ["surface_removed", "surface_replaced"]:
			replaced_ground[event.get("tile", INVALID)] = true
	var moved: Array[Dictionary]
	for key: String in (context.get("transport_ground", {}) as Dictionary):
		var tile: Vector2i = Surface.tile_from_key(key)
		var old: Dictionary = (context.get("transport_ground", {}) as Dictionary)[key] as Dictionary
		# Identical source metadata does not make consumed-and-recreated ground
		# the original surface that survived this displacement.
		if replaced_ground.has(tile):
			continue
		if Surface.element_at(state, tile) != str(old.get("elemental", "")):
			continue
		if Surface.surface_at(state, tile).get("elemental_source", {}) != old.get("source", {}):
			continue
		if not Surface.can_place(state, tile + offset):
			continue
		moved.append({"from": tile, "to": tile + offset, "surface": old.get("elemental", "")})
	# Remove all origins first: overlapping large footprints must not erase a
	# surface that was already moved by an earlier iteration.
	for entry: Dictionary in moved:
		Surface.remove(state, entry["from"], "elemental", "relic_transport")
	for entry: Dictionary in moved:
		Surface.place(state, entry["to"], str(entry["surface"]), _source("transport_surface"))

static func _frozen_transitions(before: Dictionary, state: Dictionary, action: Dictionary, events: Array[Dictionary]) -> void:
	var direct_deaths: Dictionary = {}
	var freezes: Dictionary = {}
	for event: Dictionary in events:
		if str(event.get("kind", "")) == "actor_death" and str(event.get("source_kind", "")) in ["direct_attack", "detonate"] and bool(event.get("player_card", false)):
			direct_deaths[int(event.get("id", -1))] = event
		elif str(event.get("kind", "")) == "status_applied" and str(event.get("status", "")) == "freeze" and str(event.get("actor_kind", "")) == "enemy":
			freezes[int(event.get("id", -1))] = event
	for old: Dictionary in before.get("enemies", []):
		if int(old.get("hp", 0)) <= 0:
			continue
		var current: Dictionary = enemy_by_id(state, int(old.get("id", -1)))
		if current.is_empty():
			continue
		var id: int = int(old.get("id", -1))
		var death: Dictionary = direct_deaths.get(id, {}) as Dictionary
		var at_death: Dictionary = death.get("unit", {}) as Dictionary
		if int(at_death.get("freeze", 0)) > 0 and has_effect(state, "frozen_kill_rubble"):
			var formation: Dictionary = {}
			for tile: Vector2i in Surface.footprint_tiles(at_death):
				for direction: Vector2i in CROSS:
					formation[tile + direction] = true
			for tile: Vector2i in formation:
				Surface.place(state, tile, "rubble", _source("frozen_kill_rubble"))
		if freezes.has(id) and has_effect(state, "freeze_relocate_ice") and action.has("_ice_spill_direction"):
			var direction: Vector2i = action.get("_ice_spill_direction", Vector2i.ZERO)
			if not PathUtils.DIRS_4.has(direction) or not Surface.unit_on(before, old, "ice"):
				continue
			var footprint: Array[Vector2i] = Surface.footprint_tiles(current)
			for tile: Vector2i in footprint:
				var destination: Vector2i = tile + direction
				if not footprint.has(destination) and Surface.can_place(state, destination):
					Surface.place(state, destination, "ice", _source("freeze_relocate_ice"))
					break

static func _exchange_endpoints(engine: RefCounted, state: Dictionary, trace: Dictionary) -> Dictionary:
	var route: Array = trace.get("chain_hits", trace.get("hits", [])) as Array
	var ids: Array[int]
	for hit: Dictionary in route:
		var enemy_id: int = int(hit.get("enemy_id", -1))
		if enemy_id >= 0 and not ids.has(enemy_id) and not bool(hit.get("conduction", false)):
			ids.append(enemy_id)
	if ids.size() < 2:
		return state
	var first: Dictionary = enemy_by_id(state, ids.front())
	var last: Dictionary = enemy_by_id(state, ids.back())
	if first.is_empty() or last.is_empty() or int(first.get("hp", 0)) <= 0 or int(last.get("hp", 0)) <= 0:
		return state
	for actor: Dictionary in [first, last]:
		if bool(actor.get("forced_movement_immune", false)) or (actor.get("status_immunities", []) as Array).has("displacement"):
			return state
	var first_pos: Vector2i = first.get("pos", INVALID)
	var last_pos: Vector2i = last.get("pos", INVALID)
	var exclusions: Array[int]
	exclusions.append(ids.front())
	exclusions.append(ids.back())
	var a_tiles: Array[Vector2i] = Surface.footprint_tiles(first, last_pos)
	var b_tiles: Array[Vector2i] = Surface.footprint_tiles(last, first_pos)
	for tile: Vector2i in a_tiles:
		if b_tiles.has(tile) or not _landing_open(state, tile, exclusions):
			return state
	for tile: Vector2i in b_tiles:
		if not _landing_open(state, tile, exclusions):
			return state
	first["pos"] = last_pos
	last["pos"] = first_pos
	Surface.record_event(state, {"kind": "relic_exchange", "first_id": ids.front(), "last_id": ids.back(), "from": first_pos, "to": last_pos})
	if engine.has_method("surface_actor_arrival"):
		state = engine.call("surface_actor_arrival", state, "enemy", ids.front(), first_pos) as Dictionary
		state = engine.call("surface_actor_arrival", state, "enemy", ids.back(), last_pos) as Dictionary
	return state

static func _landing_open(state: Dictionary, tile: Vector2i, excluded_ids: Array[int]) -> bool:
	if not Surface.can_place(state, tile) or (state.get("player", {}) as Dictionary).get("pos", INVALID) == tile:
		return false
	for actor: Dictionary in state.get("enemies", []):
		if int(actor.get("hp", 0)) > 0 and not excluded_ids.has(int(actor.get("id", -1))) and Surface.footprint_tiles(actor).has(tile):
			return false
	for actor: Dictionary in state.get("illusions", []):
		if int(actor.get("hp", 0)) > 0 and Surface.footprint_tiles(actor).has(tile):
			return false
	return true

static func events_since(state: Dictionary, sequence: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for event: Dictionary in state.get("surface_events", []):
		if int(event.get("sequence", 0)) > sequence:
			result.append(event)
	return result

static func _event_rewards(engine: RefCounted, before: Dictionary, state: Dictionary, action: Dictionary, target: Vector2i, events: Array[Dictionary], trace: Dictionary) -> Dictionary:
	if not engine.has_method("apply_surface_reward"):
		return state
	for entry: Dictionary in effects(state):
		var type: String = str(entry.get("type", ""))
		if not str(entry.get("requires_element", "")).is_empty() and _element(action) != str(entry.get("requires_element", "")):
			continue
		var matched: bool = false
		var position: Vector2i = target
		match type:
			"chain_hit_count_reward":
				if int(action.get("chain", 0)) <= 0:
					continue
				var native_targets: Dictionary = {}
				for hit: Dictionary in trace.get("chain_hits", trace.get("hits", [])):
					if not bool(hit.get("conduction", false)) and str(hit.get("kind", "")) != "conduction" and int(hit.get("enemy_id", -1)) >= 0:
						native_targets[int(hit["enemy_id"])] = true
				matched = native_targets.size() >= int(entry.get("threshold", 3))
			"resolved_action_surface":
				if str(action.get("type", "")) in ["move", "blink"]:
					var start: Vector2i = (before.get("player", {}) as Dictionary).get("pos", INVALID)
					var end: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
					if start != end and _claim(state, entry):
						position = start if str(entry.get("position_mode", "origin")) == "origin" else end
						Surface.place(state, position, str(entry.get("surface", "electrified")), _source(type))
						state = _rewards(engine, state, entry, position)
				continue
			"surface_creation_reward":
				for event: Dictionary in events:
					var source: Dictionary = event.get("source", {}) as Dictionary
					if str(source.get("kind", "")) in ["relic", "skill", "enemy"] or str(source.get("actor_kind", "")) != "player" or not bool(source.get("player_card", false)) or source.has("skill_id"):
						continue
					if str(event.get("kind", "")) in ["surface_created", "surface_replaced"] and str(event.get("surface", "")) == str(entry.get("surface", "fire")):
						matched = true
						if position == INVALID:
							position = event.get("tile", INVALID)
			"surface_consumption_reward", "layered_surface_consumption_reward":
				var consumed: Dictionary = {}
				for event: Dictionary in events:
					if str(event.get("kind", "")) != "surface_removed" or str(event.get("reason", "")) not in ["chain", "conduction", "detonate", "freeze"]:
						continue
					var tile: Vector2i = event.get("tile", INVALID)
					if type == "layered_surface_consumption_reward":
						if str(event.get("surface", "")) != "rubble" and bool(event.get("rubble_underlay", false)):
							consumed[tile] = true
					elif str(event.get("reason", "")) in ["chain", "conduction"] and Surface.is_conductive(before, tile):
						consumed[tile] = true
				matched = consumed.size() >= int(entry.get("min_consumed", entry.get("threshold", 2 if type == "surface_consumption_reward" else 1)))
				if type == "layered_surface_consumption_reward" and not consumed.is_empty():
					var sorted: Array[Vector2i]
					for tile: Vector2i in consumed:
						sorted.append(tile)
					sorted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y if a.y != b.y else a.x < b.x)
					position = sorted.front()
			"board_surface_types_reward":
				var kinds: Dictionary = {}
				for tile: Vector2i in Surface.tiles(state):
					if engine.has_method("is_tile_visible_to_player") and not bool(engine.call("is_tile_visible_to_player", state, tile)):
						continue
					var elemental: String = Surface.element_at(state, tile)
					if not elemental.is_empty():
						kinds[elemental] = true
					if Surface.has_rubble(state, tile):
						kinds["rubble"] = true
				matched = kinds.size() >= int(entry.get("required_types", entry.get("threshold", 3)))
		if matched and _claim(state, entry):
			state = _rewards(engine, state, entry, position)
	return state

static func _rewards(engine: RefCounted, state: Dictionary, entry: Dictionary, position: Vector2i) -> Dictionary:
	for raw: Dictionary in entry.get("rewards", []):
		var reward: Dictionary = raw.duplicate(true)
		reward["pos"] = position
		state = engine.call("apply_surface_reward", state, reward, {"source": "relic", "relic_id": entry.get("relic_id", ""), "pos": position}) as Dictionary
	return state

static func _claim(state: Dictionary, entry: Dictionary) -> bool:
	var scope: String = str(entry.get("once", "turn"))
	var flags: Dictionary = state.get("surface_relic_flags", {}) as Dictionary
	var key: String = "%s:%s" % [str(entry.get("relic_id", "")), str(entry.get("type", ""))]
	var stamp: int = int(state.get("turn", 0)) if scope == "turn" else -1
	if flags.has(key) and int(flags[key]) == stamp:
		return false
	flags[key] = stamp
	state["surface_relic_flags"] = flags
	return true

static func _source(type: String) -> Dictionary:
	return {"kind": "relic", "effect": type, "actor_kind": "player"}

static func _element(action: Dictionary) -> String:
	return str(action.get("element", action.get("_card_element", "")))

static func _is_direct_attack(action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["melee", "ranged", "aoe", "push", "pull", "detonate"] and not bool(action.get("_secondary_relic", false))

static func enemy_at(state: Dictionary, tile: Vector2i) -> Dictionary:
	for unit: Dictionary in state.get("enemies", []):
		if int(unit.get("hp", 0)) > 0 and Surface.footprint_tiles(unit).has(tile):
			return unit
	return {}

static func enemy_by_id(state: Dictionary, id: int) -> Dictionary:
	for unit: Dictionary in state.get("enemies", []):
		if int(unit.get("id", -1)) == id:
			return unit
	return {}
