extends RefCounted

const TypedArrays = preload("res://scripts/typed_arrays.gd")
const Glossary = preload("res://scripts/glossary.gd")

const Data = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const IllusionRules = preload("res://scripts/illusion_card_rules.gd")
const Snapshots = preload("res://scripts/enemy_mechanics/actor_snapshot.gd")
static var TOOLTIP: String = Glossary.name_for("reflect") + "\n" + Glossary.definition("reflect")

const BOUNCE_EVENT: String = "reflect_bounced"
const DEFENSE_FIELDS: PackedStringArray = ["hp", "block", "stoneskin"]
const RESOLVED_DAMAGE: String = "_reflect_resolved_damage"
const EXEMPT_HIT: String = "_reflect_exempt_hit"

# The rule text is the whole rule: an attack whose attacker stands on a tile not
# adjacent to a living Reflect unit bounces. Area, Chain, conducted and
# Push/Pull attacks count. Each unit bounces at most once per attack.
# Status and movement without damage, battlefield-wide hits and Burst effects land.
static func reflects(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i, index: int) -> bool:
	if int(action.get("damage", 0)) <= 0 or str(action.get("type", "")) not in ["melee", "ranged", "aoe", "push", "pull"]: return false
	if bool(action.get(EXEMPT_HIT, false)) or bool(action.get("status_only", false)) or bool(action.get("_battlefield_all_units", false)): return false
	if index < 0 or index >= state.get("enemies", []).size(): return false
	var enemy: Dictionary = state["enemies"][index]
	if not bool(Data.enemies().get(str(enemy.get("type", "")), {}).get("reflect_ranged", false)): return false
	return int(enemy.get("hp", 0)) > 0 and engine._enemy_distance_to_tile(enemy, origin) > 1

# The same rule for a planned attack hit (the planner's actor record).
static func reflects_hit(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i, hit: Dictionary) -> bool:
	return str(hit.get("kind", "")) == "enemy" and reflects(engine, state, action, hit.get("attack_origin", origin), engine._enemy_index_for_id(state, int(hit.get("id", -1))))

static func hit_ids(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i, hits: Array) -> Dictionary:
	var ids: Dictionary = {}
	for hit: Dictionary in hits:
		if reflects_hit(engine, state, action, origin, hit): ids[int(hit["id"])] = true
	return ids

# Called after target-dependent damage modifiers, before Block and hit
# riders. Returning damage is a fresh normal hit against the attacker's defense.
# The bounce is recorded so previews and analytics see every one, whatever
# attack path or follow-up produced it.
static func bounce(engine: RefCounted, state: Dictionary, index: int, damage: int, kind: String, id: int, action: Dictionary = {}, trace: Dictionary = {}) -> Dictionary:
	var mirror: Dictionary = state["enemies"][index]
	var previous: Dictionary = state.get("damage_context", {}).duplicate(true)
	var source: Dictionary = {"actor_kind": "enemy", "actor_id": mirror["id"], "source_kind": "direct_attack", "player_card": false}
	state["damage_context"] = source
	var attacker_before: Dictionary = {}
	var attacker_unit: Dictionary = engine._surface_actor(state, kind, id)
	for field: String in DEFENSE_FIELDS: attacker_before[field] = int(attacker_unit.get(field, 0))
	var return_hit: Dictionary = {"type": str(action.get("type", "")), "damage": damage, RESOLVED_DAMAGE: true}
	var player_health_loss: int = 0
	var defiance_before: int = int(state.get("defiance_remaining", 0))
	var struck: Dictionary = {}
	if kind == "enemy":
		var attacker: int = engine._enemy_index_for_id(state, id)
		if attacker >= 0: state = engine._damage_enemy(state, attacker, damage, true, false, false)
	elif kind == "player":
		var damage_received: int = int(state.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0))
		state = engine._damage_actor_target(state, {"kind": "player", "id": -1}, damage, false, return_hit)
		# Run stats record the hit before Defiance or a prevent-lethal relic restores Health.
		player_health_loss = int(state.get("run_stats", {}).get(engine.RUN_STAT_DAMAGE_RECEIVED, 0)) - damage_received
		state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(mirror["id"]), player_health_loss, maxi(0, int(attacker_before["block"]) - int(state["player"].get("block", 0))))
	elif kind == "illusion":
		var target: Dictionary = {"kind": kind, "id": id}
		IllusionRules.note_enemy_hit(engine, state, struck, target, return_hit)
		state = engine._damage_actor_target(state, target, damage, false, return_hit)
	var attacker_after: Dictionary = engine._surface_actor(state, kind, id)
	var event: Dictionary = {"kind": BOUNCE_EVENT, "enemy_id": int(mirror["id"]), "attacker_kind": kind, "attacker_id": id, "damage": damage, "source": source.duplicate(true)}
	for field: String in DEFENSE_FIELDS:
		event[field + "_loss"] = maxi(0, int(attacker_before[field]) - int(attacker_after.get(field, attacker_before[field])))
	if kind == "player":
		event["net_hp_loss"] = event["hp_loss"]
		event["hp_loss"] = player_health_loss
		event["lethal"] = int(attacker_before["hp"]) > 0 and int(attacker_after.get("hp", 0)) <= 0
		var defiance_spent: int = defiance_before - int(state.get("defiance_remaining", 0))
		if defiance_spent > 0: event["defiance_spent"] = defiance_spent
	Surface.record_event(state, event)
	if not struck.is_empty(): state = IllusionRules.after_enemy_hit(engine, state, int(mirror["id"]), struck, trace)
	state["damage_context"] = previous
	return state

static func bounces_between(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var sequence: int = int(before.get("surface_event_sequence", 0))
	for event_var: Variant in after.get("surface_events", []):
		if typeof(event_var) == TYPE_DICTIONARY and int((event_var as Dictionary).get("sequence", 0)) > sequence and str((event_var as Dictionary).get("kind", "")) == BOUNCE_EVENT:
			result.append(event_var as Dictionary)
	return result

static func guard_target(engine: RefCounted, state: Dictionary, source: int, action: Dictionary) -> int:
	var best: int = -1
	for index: int in range(state["enemies"].size()):
		var candidate: Dictionary = state["enemies"][index]
		if index == source or int(candidate.get("hp", 0)) <= 0: continue
		if engine._enemy_distance_between(state["enemies"][source], candidate) > int(action.get("range", 1)): continue
		if best < 0 or int(candidate.get("block", 0)) < int(state["enemies"][best].get("block", 0)) or (int(candidate.get("block", 0)) == int(state["enemies"][best].get("block", 0)) and int(candidate["id"]) < int(state["enemies"][best]["id"])): best = index
	return source if best < 0 and bool(action.get("self_if_none", false)) else best

static func refraction(enemy: Dictionary, action: Dictionary) -> bool:
	return str(enemy.get("type", "")) == "glacial_mirror" and str(action.get("type", "")) == "aoe" and int(action.get("pattern_line", 0)) > 0

static func line(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Array[Vector2i]:
	var enemy: Dictionary = state["enemies"][index]
	var direction: Vector2i = engine._cardinal_direction(state["player"]["pos"] - enemy["pos"])
	var result: Array[Vector2i]
	for distance: int in range(1, int(action.get("pattern_line", 4)) + 1):
		var tile: Vector2i = enemy["pos"] + direction * distance
		if not Paths.is_passable(state.get("grid", []), tile): break
		result.append(tile)
	return result

static func available(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if refraction(state["enemies"][index], action): return line(engine, state, index, action).has(state["player"]["pos"])
	return true

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, attack_disabled: bool) -> Dictionary:
	var actions: Array = intent.get("actions", [])
	if actions.is_empty() or not refraction(state["enemies"][index], actions[0]): return {}
	var start: Vector2i = state["enemies"][index]["pos"]
	var tiles: Array[Vector2i] = TypedArrays.vector2i(engine._vector2i_values([]) if attack_disabled else line(engine, state, index, actions[0]))
	return {"path": engine._vector2i_values([start]), "destination": start, "attack_action_index": 0, "movement_action_index": -1, "attack_action": actions[0], "projected_attack": tiles, "projected_attack_target": tiles.back() if not tiles.is_empty() else engine.INVALID_TILE, "attack_available": not tiles.is_empty(), "target_key": "player", "target_tile": state["player"]["pos"]}

# Intent hover reads the same return events as the committed line. Only visible
# Mirrors can contribute a number to the intent panel.
static func forecast_return_damage(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, tiles: Array[Vector2i]) -> int:
	var visible_mirrors: Dictionary = {}
	var origin: Vector2i = state["enemies"][index]["pos"]
	for target_index: int in engine._enemy_indices_in_tiles(state, tiles):
		var unit: Dictionary = state["enemies"][target_index]
		if reflects(engine, state, action, origin, target_index) and engine.is_enemy_visible_to_player(state, unit):
			visible_mirrors[int(unit["id"])] = true
	if visible_mirrors.is_empty(): return 0
	var after: Dictionary = engine._resolve_enemy_action(state.duplicate(true), index, action)
	var damage: int = 0
	for event: Dictionary in bounces_between(state, after):
		if visible_mirrors.has(int(event["enemy_id"])):
			damage += int(event["damage"])
	return damage

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, context: Dictionary = {}) -> Dictionary:
	context["refraction_started"] = false
	context["refraction_started"] = true
	var tiles: Array[Vector2i] = line(engine, state, index, action)
	# Preserve all-actor friendly-fire/death accounting.
	return damage_line(engine, state, index, action, tiles)

static func step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary, context: Dictionary = {}) -> Dictionary:
	var losses: Array[Dictionary] = engine._actor_target_losses(before, after)
	losses.append_array(engine._enemy_target_losses(before, after))
	var tiles: Array[Vector2i] = line(engine, before, index, action)
	return {"kind": "aoe", "action_type": "refraction", "cancelled": not bool(context.get("refraction_started", true)), "element": "ice", "actor_key": engine._enemy_key(before["enemies"][index]), "from": before["enemies"][index]["pos"], "to": tiles.back() if not tiles.is_empty() else engine.INVALID_TILE, "tiles": tiles, "target_losses": losses, "impact_actor_keys": engine._target_loss_keys(losses), "en05_after": Snapshots.snapshot(after), "label": "Refraction"}

# All units on the authored line share the existing friendly-fire rules.
static func damage_line(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, tiles: Array[Vector2i]) -> Dictionary:
	var origin: Vector2i = state["enemies"][index]["pos"]
	var caster_id: int = int(state["enemies"][index]["id"])
	state["damage_context"] = {"actor_kind": "enemy", "actor_id": caster_id, "source_kind": "direct_attack", "player_card": false}
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hero_before: Dictionary = state["player"].duplicate(true)
	var struck_player: bool = false
	var struck_illusions: Dictionary = {}
	for actor: Dictionary in engine._surface_actor_records(state):
		if not engine._surface_unit_intersects(actor["unit"], tiles): continue
		var hit_action: Dictionary = action
		var bonus: Dictionary = action.get("surface_bonus", {}) as Dictionary
		if not bonus.is_empty() and engine._surface_condition_met(state, bonus, actor["unit"]["pos"], actor["unit"]):
			hit_action = action.duplicate()
			for field: String in engine.SURFACE_BONUS_FIELDS:
				if bonus.has(field): hit_action[field] = int(hit_action.get(field, 0)) + int(bonus[field])
		if str(actor["kind"]) == "enemy":
			var target_index: int = engine._enemy_index_for_id(state, int(actor["id"]))
			if reflects(engine, state, hit_action, origin, target_index):
				var damage: int = engine._damage_for_enemy_target(state, hit_action, target_index, false)
				state = bounce(engine, state, target_index, damage, "enemy", caster_id, hit_action)
				state = engine._apply_action_keywords_to_enemy(state, index, hit_action, actor["unit"]["pos"], false)
				engine._apply_stagger_to_enemy(state, caster_id, int(hit_action.get("stagger", 0)))
				continue
			state = engine._damage_enemy_hit(state, target_index, int(hit_action["damage"]), engine._action_pierces_defense(hit_action), false)
			state = engine._apply_action_keywords_to_enemy(state, target_index, hit_action, origin, false)
			engine._apply_stagger_to_enemy(state, int(actor["id"]), int(hit_action.get("stagger", 0)))
		else:
			if str(actor["kind"]) == "player": struck_player = true
			elif str(actor["kind"]) == "illusion": preload("res://scripts/illusion_card_rules.gd").note_enemy_hit(engine, state, struck_illusions, actor, hit_action)
			state = engine._damage_actor_target(state, actor, int(hit_action["damage"]), engine._action_pierces_defense(hit_action), hit_action)
			state = engine._apply_action_keywords_to_target(state, actor, hit_action, origin)
	if struck_player:
		state = preload("res://scripts/common_relic_rules.gd").blocked_attack(engine, state, int(state["enemies"][index]["id"]), maxi(0, int(hero_before["hp"]) - int(state["player"]["hp"])), maxi(0, int(hero_before["block"]) - int(state["player"]["block"])))
		var hit_action: Dictionary = action.duplicate(true)
		hit_action["_origin_tile"] = origin
		state = preload("res://scripts/retaliate_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), hit_action, hero_before["pos"])
	if not struck_illusions.is_empty(): state = preload("res://scripts/illusion_card_rules.gd").after_enemy_hit(engine, state, int(state["enemies"][index]["id"]), struck_illusions)
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch: state = engine._flush_surface_deaths(state)
	return state
