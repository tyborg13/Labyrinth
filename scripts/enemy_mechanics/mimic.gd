extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Snapshots = preload("res://scripts/enemy_mechanics/tether.gd")
const APPROACH_RANGE: int = 2
const HISTORY_KEY: String = "last_hero_attack_card"
const SPECIAL_RANGE: int = 4
const DIRECT_TYPES: Array = ["melee", "ranged", "aoe"]
const SHAPE_FIELDS: Array = ["range", "pattern", "rotate", "aim", "include_self", "pattern_line"]

static func handles(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "mirror_last_attack"

static func handles_intent(intent: Dictionary) -> bool:
	return str(intent.get("id", "")) == "mirror"

static func base_card(card_id: String) -> Dictionary:
	var card: Dictionary = Data.card_def(card_id)
	return Data.card_def(str(card.get("base_card_id", card_id)))

static func record(engine: RefCounted, before: Dictionary, after: Dictionary, action: Dictionary) -> void:
	var id: String = str(action.get("_card_id", ""))
	if id.is_empty() or bool(action.get("_illusion_echo", false)): return
	var losses: Array[Dictionary] = engine._enemy_target_losses(before, after)
	losses.append_array(engine._terrain_target_losses(before, after))
	for loss: Dictionary in engine._actor_target_losses(before, after):
		if str(loss.get("kind", "")) == "illusion": losses.append(loss)
	if losses.is_empty(): return
	# Actual damage decides whether this was an attack card, including cards
	# with indirect geometry such as a force-only collision (base damage zero).
	after[HISTORY_KEY] = str(Data.card_def(id).get("base_card_id", id))

static func copy_attack(card: Dictionary) -> Dictionary:
	if card.is_empty(): return {}
	var native: Dictionary = {}
	for action: Dictionary in card.get("actions", []):
		if int(action.get("damage", 0)) > 0 and str(action.get("type", "")) != "next_attack":
			native = action
			break # Director feedback 1: only the first damaging action is copied.
	var direct: bool = str(native.get("type", "")) in DIRECT_TYPES and int(native.get("chain", 0)) <= 0 and str(native.get("target", "")) not in ["self", "player"] and str(native.get("aim", "")) != "self"
	var result: Dictionary = {"type": native["type"] if direct else "ranged", "damage": int(native.get("damage", 0)), "element": native.get("element", card.get("element", "none"))}
	result["_copied_icon"] = Icons.action_icon_key(native) if not native.is_empty() else Icons.action_icon_key(result)
	if direct:
		for field: String in SHAPE_FIELDS:
			if native.has(field): result[field] = native[field].duplicate(true) if native[field] is Array else native[field]
	else:
		# Special targeting keeps the card's base damage/name/element, with the
		# director's Shade Bolt geometry rather than Shade Bolt's fixed damage.
		result["range"] = SPECIAL_RANGE
	return result

static func fallback() -> Dictionary:
	for intent: Dictionary in Data.enemy_def("hollow_mimic")["intents"]:
		if str(intent["id"]) == "shade_bolt": return intent.duplicate(true)
	return {}

static func prepare(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if not handles_intent(intent): return intent
	var card: Dictionary = base_card(str(state.get(HISTORY_KEY, ""))) if state.has(HISTORY_KEY) else {}
	var attack: Dictionary = copy_attack(card)
	if attack.is_empty(): return fallback()
	var result: Dictionary = intent.duplicate(true)
	result["name"] = "Mirror: %s" % str(card["name"])
	result["mirror_card_name"] = card["name"]
	result["mirror_card_id"] = str(state[HISTORY_KEY])
	result["actions"] = [{"type": "mirror_last_attack", "copy": attack}]
	var index: int = engine._enemy_index_for_id(state, int(enemy["id"]))
	if index >= 0 and not bool(plan(engine, state, index, result, false, false).get("copy_reachable", false)):
		result["name"] = "Shade Bolt"
		result["time"] = fallback()["time"]
	return result

static func tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, attack: Dictionary) -> Array[Vector2i]:
	var hero: Vector2i = state["player"]["pos"]
	if str(attack["type"]) == "aoe":
		var aimed: Dictionary = attack.duplicate(true)
		if str(attack.get("aim", "")) == "facing" or int(attack.get("range", 0)) == 0:
			aimed["orientation"] = engine._cardinal_direction(hero - Vector2i(enemy["pos"]))
		var center: Vector2i = enemy["pos"] if int(attack.get("range", 0)) == 0 else hero
		if str(attack.get("aim", "")) == "facing": center = Vector2i(enemy["pos"]) + engine._cardinal_direction(hero - Vector2i(enemy["pos"]))
		if int(attack.get("range", 0)) > 0 and not engine._enemy_action_reaches_tile(state, enemy, aimed, hero): return engine._vector2i_values([])
		return engine._enemy_aoe_tiles_for_target(state, enemy, aimed, center, true)
	if engine._enemy_action_reaches_tile(state, enemy, attack, hero): return engine._vector2i_values([hero])
	return engine._vector2i_values([])

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, movement_disabled: bool, attack_disabled: bool) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var attack: Dictionary = (intent["actions"][0] as Dictionary).get("copy", {})
	if attack.is_empty(): attack = fallback()["actions"][0].duplicate(true)
	var path: Array[Vector2i] = engine._vector2i_values([enemy["pos"]])
	var hit_tiles: Array[Vector2i] = tiles(engine, state, enemy, attack)
	var reachable: bool = hit_tiles.has(state["player"]["pos"])
	if not reachable and not movement_disabled:
		var best_distance: int = 2147483647
		var approach_distance: int = engine._enemy_distance_to_tile(enemy, state["player"]["pos"])
		var approach: Array[Vector2i] = path.duplicate()
		for record: Dictionary in engine._enemy_actual_path_records(state, enemy, APPROACH_RANGE):
			var candidate: Dictionary = enemy.duplicate(true)
			candidate["pos"] = record["tile"]
			var distance: int = engine._enemy_distance_to_tile(candidate, state["player"]["pos"])
			if distance < approach_distance:
				approach_distance = distance
				approach = engine._vector2i_values(record["path"])
			var candidate_tiles: Array[Vector2i] = tiles(engine, state, candidate, attack)
			if candidate_tiles.has(state["player"]["pos"]) and int(record["steps"]) < best_distance:
				best_distance = int(record["steps"])
				path = engine._vector2i_values(record["path"])
				hit_tiles = candidate_tiles
				reachable = true
		if not reachable: path = approach
	if not reachable:
		attack = fallback()["actions"][0].duplicate(true)
		var fallback_enemy: Dictionary = enemy.duplicate(true)
		fallback_enemy["pos"] = path.back()
		hit_tiles = tiles(engine, state, fallback_enemy, attack)
	if attack_disabled: hit_tiles.clear()
	return {"enemy_index": index, "enemy_key": engine._enemy_key(enemy), "path": path, "route": path, "destination": path.back(), "movement_action_index": 0,
		"attack_action_index": 0, "attack_action": attack, "target_key": "player", "target_tile": state["player"]["pos"], "projected_attack_target": state["player"]["pos"],
		"projected_attack": hit_tiles, "copy_reachable": reachable, "attack_available": hit_tiles.has(state["player"]["pos"]), "movement_disabled": movement_disabled, "attack_disabled": attack_disabled}

static func resolve(engine: RefCounted, state: Dictionary, index: int, _action: Dictionary, context: Dictionary, bleed_steps: Array[Dictionary]) -> Dictionary:
	var current: Dictionary = plan(engine, state, index, state["enemies"][index]["intent"], bool(context.get("movement_disabled", false)), bool(context.get("attack_disabled", false)))
	if current["path"].size() > 1:
		state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "move_toward"}, bleed_steps)
		if engine._enemy_cannot_continue_after_bleed(state, index): return state
		state = engine._move_enemy_along_planned_path(state, index, engine._vector2i_values(current["path"]), context, APPROACH_RANGE)
		context["move_state"] = state.duplicate(true)
	if bool(current["attack_disabled"]) or engine._enemy_cannot_continue_after_bleed(state, index): return state
	state = engine._trigger_enemy_bleed_for_resolved_action(state, index, {"type": "ranged"}, bleed_steps)
	if engine._enemy_cannot_continue_after_bleed(state, index): return state
	var attack: Dictionary = current["attack_action"]
	var hit_tiles: Array[Vector2i] = tiles(engine, state, state["enemies"][index], attack)
	context["resolved_tiles"] = hit_tiles
	context["copy_attack"] = attack
	# Damage and geometry only: never invoke surface, keyword, force, or terrain riders.
	var hero_before: Dictionary = state["player"].duplicate(true)
	for target: Dictionary in engine._actor_targets_in_tiles(state, hit_tiles):
		state = engine._damage_actor_target(state, target, int(attack["damage"]), false, attack)
	if hit_tiles.has(hero_before["pos"]):
		state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(state["enemies"][index]["id"]), maxi(0, int(hero_before["hp"]) - int(state["player"]["hp"])), maxi(0, int(hero_before["block"]) - int(state["player"]["block"])))
		state = preload("res://scripts/retaliate_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), attack, hero_before["pos"])
	return state

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, _action: Dictionary, context: Dictionary) -> Dictionary:
	var attack: Dictionary = context.get("copy_attack", plan(engine, before, index, before["enemies"][index]["intent"], false, false)["attack_action"])
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	var step: Dictionary = {"kind": attack["type"], "action_type": attack["type"], "en06_mirror": true, "actor_key": engine._enemy_key(before["enemies"][index]),
		"actor_name": Data.enemy_def("hollow_mimic")["name"], "from": after["enemies"][index]["pos"], "to": before["player"]["pos"], "center": before["player"]["pos"], "range": int(attack.get("range", 0)),
		"tiles": context.get("resolved_tiles", []), "element": attack.get("element", "none"), "target_losses": losses, "amount": int(attack.get("damage", 0)), "en06_after": Snapshots.snapshot(after)}
	if context.has("move_state"):
		step["move_step"] = engine._enemy_action_step_base(before, context["move_state"], index, {"type": "move_toward"}, context)
		step["move_after"] = Snapshots.snapshot(context["move_state"])
	return step

# Shared tactical scoring does not know compound copied attacks. Keep the
# director's weights, remove impossible attacks, and use the combat RNG only.
static func choose(engine: RefCounted, state: Dictionary, index: int, intents: Array, rng: RandomNumberGenerator) -> Dictionary:
	var options: Array[Dictionary]
	var total: int = 0
	for intent: Dictionary in intents:
		var candidate: Dictionary = prepare(engine, state, state["enemies"][index], intent)
		var current: Dictionary = engine.enemy_intent_plan(state, index, candidate)
		if str(candidate.get("id", "")) != "recede" and not bool(current.get("attack_available", false)): continue
		var weight: int = int(intent.get("weight", 0))
		if weight <= 0: continue
		total += weight
		options.append({"intent": candidate, "weight": weight})
	if options.is_empty():
		for intent: Dictionary in intents:
			if str(intent.get("id", "")) == "recede": return intent.duplicate(true)
		return fallback()
	var roll: int = rng.randi_range(1, total)
	for option: Dictionary in options:
		roll -= int(option["weight"])
		if roll <= 0: return option["intent"]
	return options.back()["intent"]
