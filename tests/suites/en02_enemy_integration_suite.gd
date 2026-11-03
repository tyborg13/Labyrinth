extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Context = preload("res://scripts/cutout_context.gd")
const Strikes = preload("res://scripts/enemy_strike_points.gd")
const PROJECTILE_HERO := Vector2i(6, 3)
const STATIONARY_FOE := Vector2i(7, 3)
const ROSTER := ["burrow_grub", "ember_tick", "hoarfrost_seer", "gale_herald", "arc_thrall", "gloam_stalker"]
const FIXTURE_PARTNER_ID: int = 3

static func run(engine: RefCounted, fixture: Callable, intent: Callable, enemy: Callable, expect: Callable) -> void:
	for type: String in ROSTER:
		var registered: bool = Context.STATIC_ENEMY_TYPES.has(type)
		if type in ["hoarfrost_seer", "arc_thrall", "burrow_grub", "ember_tick"]:
			registered = Context.FAMILY_KEYS.get(type) == type + "_motion" and not Context.STATIC_ENEMY_TYPES.has(type)
		elif type in ["gale_herald", "gloam_stalker"]:
			# rr-32/rr-33 promoted both to humanoid v2 cutouts: their own motion family, never static.
			registered = Context.family_key(type) == type + "_motion" and not Context.STATIC_ENEMY_TYPES.has(type)
		expect.call(Data.enemy_def(type).has("intents") and registered and Scene.TURN_ORDER_PORTRAITS.has(type) and Strikes.REGISTRY.has(type), "%s retains enemy, presentation, strike and portrait registrations" % type)
	var state: Dictionary = fixture.call(engine, "gale_herald")
	state["enemies"].append(enemy.call(2, Vector2i(6, 5), 12, "burrow_grub"))
	state["enemies"][1].merge({"burrowed": true, "erupt_tile": Vector2i(5, 5), "intent": intent.call("burrow_grub", "erupt")}, true)
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	var actors: Array[Dictionary] = Wind.actors(state, Vector2i(1, 0))
	expect.call(actors.size() == 1 and actors[0]["kind"] == "player", "Burrowed bodies are omitted from wind's affected actors")
	expect.call(not Wind.hazard(engine, state, Vector2i(6, 5)), "Burrowed bodies retain en-01's empty floor occupancy")
	var forecast: Dictionary = Wind.preview(engine, state, state["wind"])
	var steps: Array[Dictionary]
	state = Wind.end_turn(engine, state, steps)
	expect.call(state["enemies"][1]["pos"] == Vector2i(6, 5) and bool(state["enemies"][1]["burrowed"]), "Wind leaves the buried Grub and its held Erupt in place")
	expect.call(state["player"]["pos"] == Vector2i(6, 5) and forecast["state"]["player"] == state["player"], "Wind can cross a buried body and its preview matches resolution")
	var rng := RandomNumberGenerator.new()
	rng.seed = 20261012
	engine._assign_enemy_intent(state, 1, rng)
	expect.call(state["enemies"][1]["intent"]["id"] == "erupt", "Merged next_intent retains forced Erupt after wind")

	state = fixture.call(engine, "gale_herald")
	state["enemies"].append(enemy.call(2, Vector2i(3, 5), 12, "burrow_grub"))
	state["player"]["pos"] = Vector2i(6, 6)
	state["terrain"] = [{"id": "erupt_blocker", "kind": "crag_outcrop", "hp": 3, "max_hp": 3, "pos": Vector2i(5, 5), "rounds_left": 3, "blocks_sight": true}]
	state["enemies"][1].merge({"burrowed": true, "erupt_tile": Vector2i(5, 5), "intent": intent.call("burrow_grub", "erupt")}, true)
	var landing: Vector2i = Burrow.landing_tile(engine, state, state["enemies"][1])
	state = engine._resolve_enemy_action(state, 1, intent.call("burrow_grub", "erupt")["actions"][0])
	expect.call(landing != Vector2i(5, 5) and state["enemies"][1]["pos"] == landing and engine._terrain_index_at_tile(state, Vector2i(5, 5)) >= 0, "Outcrop redirects Erupt to its existing free landing fallback")
	expect.call(Surfaces.has_rubble(state, landing), "Redirected Erupt leaves Rubble on its actual landing tile")
	state = fixture.call(engine, "gale_herald")
	Surfaces.place(state, Vector2i(6, 5), "rubble")
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	forecast = Wind.preview(engine, state, state["wind"])
	steps.clear()
	state = Wind.end_turn(engine, state, steps)
	expect.call(state["player"]["pos"] == Vector2i(6, 5) and int(state["player"]["hp"]) == 50 and Surfaces.has_rubble(state, Vector2i(6, 5)), "Wind uses normal forced movement into Rubble without spending voluntary Move")
	expect.call(state["player"] == forecast["state"]["player"], "Rubble wind preview equals resolution")

	state = fixture.call(engine, "gale_herald")
	state["enemies"].append(enemy.call(2, Vector2i(4, 3), 10, "harrier"))
	state["enemies"].append(enemy.call(FIXTURE_PARTNER_ID, STATIONARY_FOE, 10, "harrier"))
	state["player"]["pos"] = PROJECTILE_HERO
	state["enemies"][1]["intent"] = intent.call("harrier", "pelt")
	state["terrain"] = [{"id": "projectile_blocker", "kind": "crag_outcrop", "hp": 3, "max_hp": 3, "pos": Vector2i(5, 3), "rounds_left": 1, "blocks_sight": true}]
	var plan: Dictionary = engine.enemy_intent_plan(state, 1)
	expect.call(not bool(plan["attack_available"]) and (plan["projected_attack"] as Array).is_empty(), "Outcrop blocks the ordinary ranged shot")
	state["terrain"].clear()
	state["enemies"][2]["anchored"] = true
	state["wind"] = {"direction": Vector2i(0, 1), "rounds_left": 2, "source_id": 1}
	forecast = Wind.preview(engine, state, state["wind"])
	steps.clear()
	state = Wind.end_turn(engine, state, steps)
	plan = engine.enemy_intent_plan(state, 1)
	expect.call(state["enemies"][1]["pos"] == Vector2i(4, 4) and state["enemies"][2]["pos"] == STATIONARY_FOE and bool(plan["attack_available"]), "Wind moves the ranged caster while preserving the anchored actor")
	expect.call(plan["projected_attack"] == engine.enemy_intent_plan(forecast["state"], 1)["projected_attack"], "ranged threat after forecasted wind matches resolution")

	state = fixture.call(engine, "gale_herald")
	state["enemies"].append(enemy.call(2, Vector2i(6, 3), 11, "gloam_stalker"))
	state["hero_last_move"] = {"turn": int(state["turn"]), "direction": Vector2i(0, 1)}
	state["wind"] = {"direction": Vector2i(1, 0), "rounds_left": 2, "source_id": 1}
	forecast = Wind.preview(engine, state, state["wind"])
	steps.clear()
	state = Wind.end_turn(engine, state, steps)
	expect.call(state["enemies"][1]["pos"] == Vector2i(7, 3), "Wind pushes a Stalker through the real mover")
	expect.call(state["hero_last_move"]["direction"] == Vector2i(0, 1), "Wind preserves the hero's last voluntary movement direction")
	expect.call(state["enemies"] == forecast["state"]["enemies"], "Wind forecast equals resolution")
	var board: Control = Board.new()
	var badges: Array[Dictionary] = board._unit_status_badges(state["enemies"][0])
	expect.call(not badges.is_empty(), "Merged status row retains the Herald's Anchored badge")
	board.free()
