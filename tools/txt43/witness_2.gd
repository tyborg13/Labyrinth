extends "res://tools/txt43/witness.gd"

const FORCE_SOURCE := Vector2i(4, 4)
const FORCE_AIM := Vector2i(4, 1)
const PUSH_ON_AXIS := Vector2i.UP
const PULL_ON_AXIS := Vector2i(0, -3)
const OFF_AXIS := Vector2i(1, -1)
const STORMCOAL_ENTRY := Vector2i(4, 4)
const STORMCOAL_BRIDGE := Vector2i(5, 4)
const STORMCOAL_DESTINATION := Vector2i(6, 4)
const STORMCOAL_STRIP := [STORMCOAL_ENTRY, STORMCOAL_BRIDGE, STORMCOAL_DESTINATION]
const STORMCOAL_HERO_CARD: String = "chain_bolt"
const CHAIN_TEST_REACH: int = 1
const TEST_ILLUSION_HEALTH: int = 20

func _run() -> void:
	_force_motion()
	_relay_rows()
	_stormcoal_relay()
	_stormcoal_components()
	_groundsplit()
	_brace()
	_fade()
	_placement()
	_burrow()
	_gust()
	print("TXT43 ROUND 2 WITNESS: %s" % ("FAIL" if _failed else "PASS"))
	quit(int(_failed))

func _force_motion() -> void:
	for enemy_id: String in FORCE_MOVES:
		if enemy_id == "noctyrax": continue
		for move: String in FORCE_MOVES[enemy_id]:
			var state: Dictionary = Fight.state(enemy_id, move)
			state["enemies"][0]["pos"] = FORCE_SOURCE
			state["player"]["pos"] = FORCE_AIM
			var raw: Dictionary = Fight.enemy(enemy_id, 1, FORCE_SOURCE, move)["intent"]
			var intent: Dictionary = Guardians.commit(_engine, state, 0, raw)
			state["enemies"][0]["intent"] = intent
			var action: Dictionary = intent["actions"][-1]
			var aim: Vector2i = action["declared_direction"]
			var pushing: bool = action.has("push")
			var amount: int = int(action["push"] if pushing else action["pull"])
			var direction_sign: int = 1 if pushing else -1
			# Isolate the declared strike at the center of the arena so the
			# board edge never clips the Push or Pull after the held approach.
			var on_axis: Vector2i = PUSH_ON_AXIS if pushing else PULL_ON_AXIS
			for offset: Vector2i in [on_axis, OFF_AXIS]:
				var trial: Dictionary = state.duplicate(true)
				var victim: Vector2i = FORCE_SOURCE + offset
				trial["player"]["pos"] = victim
				var marked: Array[Vector2i] = Guardians.live_tiles(_engine, trial, trial["enemies"][0], action)
				var health: int = int(trial["player"]["hp"])
				var after: Dictionary = _engine._resolve_enemy_action(trial, 0, action)
				var endpoint: Vector2i = after["player"]["pos"]
				var delta: Vector2i = endpoint - victim
				var hit: bool = marked.has(victim)
				var expected_hit: bool = move != "mourning_hook" or offset == on_axis
				var expected_distance: int = mini(amount, OFF_AXIS.x) if not pushing and offset == OFF_AXIS else amount
				var victim_axis: Vector2i = Vector2i.UP if offset == on_axis else Vector2i.RIGHT
				var expected_delta: Vector2i = victim_axis * direction_sign * expected_distance if expected_hit else Vector2i.ZERO
				var lost: int = health - int(after["player"]["hp"])
				_expect(aim == Vector2i.UP and not action.has("force_direction") and hit == expected_hit
					and lost == (int(action["damage"]) if hit else 0) and delta == expected_delta,
					"FORCE MOTION " + move, {"source": FORCE_SOURCE, "aim": aim, "victim": victim,
						"hit": hit, "end": endpoint, "delta": delta, "hp_lost": lost, "footprint": marked})

func _stormcoal_state() -> Dictionary:
	var state: Dictionary = Fight.state("arc_thrall", "arc_bolt")
	state["relics"] = [STORMCOAL]
	SurfaceRelics.configure(state)
	var enemy: Dictionary = state["enemies"][0]
	var shot: Dictionary = enemy["intent"]["actions"][-1]
	# Isolate the authored delivery so approach movement cannot put the target
	# into direct Range during the test.
	enemy["intent"]["actions"] = [shot]
	state["player"]["pos"] = STORMCOAL_DESTINATION
	for tile: Vector2i in STORMCOAL_STRIP:
		Surface.place(state, tile, "fire", {})
	return state

func _stormcoal_relay() -> void:
	var state: Dictionary = _stormcoal_state()
	var enemy: Dictionary = state["enemies"][0]
	var shot: Dictionary = enemy["intent"]["actions"][0]
	var plan: Dictionary = _engine.enemy_intent_plan(state, 0)
	var marks: Array = _engine.enemy_threat_tiles(state, 0)["projected_attack"]
	var hit: Dictionary = _engine._enemy_attack_target(state.duplicate(true), 0, shot, "Ranged")
	var hero_loss: int = int(state["player"]["hp"]) - int(hit["player"]["hp"])
	var fire_left: Array = Surface.tiles(hit, "fire")
	_expect(SurfaceRelics.has_effect(state, "conductive_fire") and plan["projected_attack"].is_empty()
		and marks.is_empty() and hero_loss == 0 and Cases.same_tiles(fire_left, STORMCOAL_STRIP),
		"STORMCOAL ENEMY RELAY", {"forecast": plan["projected_attack"], "marks": marks,
			"hero_hp_lost": hero_loss, "fire_left": fire_left})

	# Same Fire and same firing/target tiles, with the units exchanging roles.
	state["player"]["pos"] = ORIGIN
	enemy["pos"] = STORMCOAL_DESTINATION
	var card: Dictionary = _engine.card_play_actions(STORMCOAL_HERO_CARD, state)[0]
	var targets: Array = _engine.valid_targets_for_player_action(state, card)
	var impact: Array[Vector2i] = [STORMCOAL_ENTRY]
	var shot_plan: Dictionary = _engine._board_attack_plan(state, card, impact, "player")
	var hero_hit: Dictionary = _engine.apply_player_action(state, card, STORMCOAL_ENTRY)
	var enemy_loss: int = int(enemy["hp"]) - int(hero_hit["enemies"][0]["hp"])
	var burned: Array = Surface.tiles(hero_hit, "fire")
	_expect(targets.has(STORMCOAL_ENTRY) and Cases.same_tiles(shot_plan["consumed"].keys(), STORMCOAL_STRIP)
		and enemy_loss == int(card["damage"]) and burned.is_empty(), "STORMCOAL HERO RELAY",
		{"card": STORMCOAL_HERO_CARD, "target": STORMCOAL_ENTRY, "forecast_consumes": shot_plan["consumed"].keys(),
			"enemy_hp_lost": enemy_loss, "fire_left": burned})

func _stormcoal_components() -> void:
	var state: Dictionary = _stormcoal_state()
	Surface.place(state, STORMCOAL_ENTRY, "electrified", {})
	Surface.place(state, STORMCOAL_DESTINATION, "electrified", {})
	state = _engine._create_illusion(state, STORMCOAL_ENTRY, TEST_ILLUSION_HEALTH)
	var shot: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	# Exercise the optional Chain route as well as the component route. Arc
	# Bolt in production has no intrinsic Chain reach.
	var chained: Dictionary = shot.duplicate(true)
	chained["chain"] = CHAIN_TEST_REACH
	state["enemies"][0]["intent"]["actions"] = [chained]
	var impact: Array[Vector2i] = [STORMCOAL_ENTRY]
	var forecast: Array = _engine.enemy_intent_plan(state, 0)["projected_attack"]
	var mixed_plan: Dictionary = _engine._board_attack_plan(state, chained, impact, "enemy")
	var mixed_hit: Dictionary = _engine._enemy_attack_target(state.duplicate(true), 0, chained, "Ranged")
	var hero_loss: int = int(state["player"]["hp"]) - int(mixed_hit["player"]["hp"])
	var fire_left: bool = Surface.has_surface(mixed_hit, STORMCOAL_BRIDGE, "fire")
	_expect(Cases.same_tiles(forecast, impact) and mixed_plan["hits"].size() == 1
		and not mixed_plan["used_conductors"].has(STORMCOAL_BRIDGE) and hero_loss == 0 and fire_left,
		"STORMCOAL ENEMY COMPONENT AND CHAIN", {"forecast": forecast,
			"used_conductors": mixed_plan["used_conductors"].keys(), "hero_hp_lost": hero_loss, "bridge_fire": fire_left})
	Surface.place(state, STORMCOAL_BRIDGE, "electrified", {})
	var electric_forecast: Array = _engine.enemy_intent_plan(state, 0)["projected_attack"]
	var electric_hit: Dictionary = _engine._enemy_attack_target(state.duplicate(true), 0, chained, "Ranged")
	var electric_loss: int = int(state["player"]["hp"]) - int(electric_hit["player"]["hp"])
	_expect(Cases.same_tiles(electric_forecast, STORMCOAL_STRIP) and electric_loss > 0,
		"STORMCOAL ENEMY ELECTRIFIED CONTROL", {"forecast": electric_forecast, "hero_hp_lost": electric_loss})
