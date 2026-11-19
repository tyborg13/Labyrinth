extends RefCounted
## Debug encounter snapshots. Use shipped cards, enemies and combat resolution.

const Encounters = preload("res://tools/qa110/encounters.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const AIM_CARD: String = "haft_shove"
const DEATH_HEALTH: int = 1

static var base_runs: Dictionary

static func build(kind: String, route: String) -> Dictionary:
	if not base_runs.has(kind): base_runs[kind] = Encounters.combat(kind)
	var run: Dictionary = base_runs[kind].duplicate(true)
	if run.is_empty() or not run.has("combat_state"): return {}
	var state: Dictionary = run["combat_state"]
	var hand: Array[String]
	hand.assign([AIM_CARD, Encounters.Board.FILLER])
	state["deck"]["hand"] = hand
	var witness: Dictionary = {}
	match route:
		"own_move_death": witness = prepare_death(state)
		"summon_under_hover": witness = prepare_summon(state)
		"cancel_right", "cancel_escape", "cancel_b", "rapid_hover", "focus_loss_drag", "application_pause_drag":
			witness = prepare_aim(state)
	return {"run": run, "witness": witness}

static func prepare_aim(state: Dictionary) -> Dictionary:
	var engine := Combat.new()
	var actions: Array[Dictionary]
	actions.assign(engine.card_play_actions(AIM_CARD, state))
	if actions.is_empty(): return {}
	var origin: Vector2i = state["player"]["pos"]
	var occupied: Dictionary = engine._occupied_actor_tiles(state)
	for unit: Dictionary in state["enemies"]:
		for tile: Vector2i in engine._enemy_footprint_tiles(unit):
			for heading: Vector2i in Paths.DIRS_4:
				var anchor: Vector2i = tile + heading
				if occupied.has(anchor) or not engine._tile_is_passable(state, anchor): continue
				state["player"]["pos"] = anchor
				if engine.is_enemy_visible_to_player(state, unit) and not engine.valid_targets_for_player_action(state, actions[0]).is_empty():
					return {"hero": anchor, "foe": tile, "card": AIM_CARD}
	state["player"]["pos"] = origin
	return {}

static func prepare_summon(state: Dictionary) -> Dictionary:
	var engine := Combat.new()
	for index: int in range(state["enemies"].size()):
		var unit: Dictionary = state["enemies"][index]
		var intent: Dictionary = engine._zekarion_summon_intent()
		var old: Dictionary = unit.get("intent", {})
		unit["intent"] = intent
		var after: Dictionary = engine.resolve_enemy_turn_with_steps(state.duplicate(true), index).get("state", {})
		if after.get("enemies", []).size() > state["enemies"].size():
			return {"actor": unit["id"], "intent": intent["id"]}
		unit["intent"] = old
	return {}

static func prepare_death(state: Dictionary) -> Dictionary:
	var engine := Combat.new()
	var witness: Dictionary = death_from_existing_roster(engine, state)
	if not witness.is_empty(): return witness
	# Rooms with only flying or immobile actors need a grounded test crawler.
	# Use vacant terrain and the same arrival/initiative APIs as a real summon.
	var hero: Vector2i = state["player"]["pos"]
	var occupied: Dictionary = engine._occupied_actor_tiles(state)
	for heading: Vector2i in Paths.DIRS_4:
		var step: Vector2i = hero + heading
		var origin: Vector2i = step + heading
		if occupied.has(step) or occupied.has(origin): continue
		if not engine._tile_is_passable(state, step) or not engine._tile_is_passable(state, origin): continue
		var probe: Dictionary = state.duplicate(true)
		var enemy: Dictionary = engine._spawned_enemy_entry(probe, "crawler", engine._next_enemy_id(probe), origin, false)
		probe["enemies"].append(enemy)
		engine._schedule_enemy_after_spawn(probe, enemy, 0, true)
		witness = try_death(engine, probe, probe["enemies"].size() - 1)
		if witness.is_empty(): continue
		state.merge(probe, true)
		witness["added_fixture_crawler"] = true
		return witness
	return {}

static func death_from_existing_roster(engine: RefCounted, state: Dictionary) -> Dictionary:
	for index: int in range(state["enemies"].size()):
		var probe: Dictionary = state.duplicate(true)
		var witness: Dictionary = try_death(engine, probe, index)
		if not witness.is_empty():
			state.merge(probe, true)
			return witness
	return {}

static func try_death(engine: RefCounted, probe: Dictionary, index: int) -> Dictionary:
	var unit: Dictionary = probe["enemies"][index]
	var origin: Vector2i = unit["pos"]
	var intents: Array = Data.enemy_def("crawler").get("intents", [])
	if Surface.unit_on(probe, unit, "fire"): return {}
	for intent: Dictionary in intents:
		if intent.get("id") == "skitter_strike": unit["intent"] = intent.duplicate(true)
	var plan: Dictionary = engine.enemy_intent_plan(probe, index)
	var path: Array = plan.get("path", [])
	if path.size() < 2 or path[0] != origin: return {}
	var step: Vector2i = path[1]
	Surface.place(probe, step, "fire")
	unit["hp"] = DEATH_HEALTH
	unit["block"] = 0
	unit["stoneskin"] = 0
	var scheduled: Dictionary = Committed.finish_player_activation(engine, probe.duplicate(true))
	var result: Dictionary = Committed.advance_to_player(engine, scheduled)
	var after: Dictionary = result.get("state", {})
	if after.is_empty(): return {}
	var actor: int = unit["id"]
	var alive: bool = (after.get("enemies", []) as Array).any(func(enemy: Dictionary) -> bool:
		return enemy["id"] == actor and enemy["hp"] > 0)
	if alive: return {}
	for event: Dictionary in after.get("surface_events", []):
		if event.get("id") == actor and event.get("kind") == "surface_damage" and event.get("surface") == "fire" and event.get("trigger") == "entry":
			return {"actor": actor, "from": origin, "fire_tile": event.get("tile"), "intent": unit["intent"]["id"]}
	return {}
