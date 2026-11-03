extends RefCounted
## Test/proof-only fixture choices; no production values are changed.
const Rest = preload("res://tests/suites/threats_at_rest_suite.gd")
const Groups = preload("res://tests/suites/board_hud_group_suite.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const SEED: int = 83
const SIZE := Vector2(1920, 1080)
const OWNER_ENEMY_TILE := Vector2i(4, 3)
const OWNER_HERO_TILE := Vector2i(5, 3)
const OWNER_ENEMY_ID: int = 1
# Interpolated adjacent hero position, lower right in screen space.
const OWNER_HERO_FROM_ENEMY_FEET := Vector2(32, 32)
const OWNER_FREEZE: int = 1
const MIDFIGHT_ADVANCES: int = 1
const STRESS_ROWS: int = 3
const STRESS_COLUMNS: int = 4
const STRESS_ORIGIN := Vector2i(2, 2)
const BIOMES: Array = ["air", "earth", "fire", "ice", "lightning", "shadow"]
const TIERS: Array = [1, 2, 3]

static func owner_state() -> Dictionary:
	var state: Dictionary = Rest.staged_state(Combat.new())
	state["player"]["pos"] = OWNER_HERO_TILE
	var enemy: Dictionary = Rest.foe(OWNER_ENEMY_ID, "crawler", OWNER_ENEMY_TILE - Rest.FIXTURE_HERO, "skitter_strike")
	enemy["freeze"] = OWNER_FREEZE
	state["enemies"] = [enemy]
	return state

static func owner_run() -> Dictionary:
	var run: Dictionary = Run.new().create_new_run(SEED, Store.default_data())
	run.merge({"mode": "combat", "current_room": Vector2i(1, 0), "current_room_layout": Rest.staged_layout(), "combat_state": owner_state()}, true)
	return run

static func owner_presentation(board: Control) -> Dictionary:
	var units: Dictionary = board._units_by_key(board._visible_units())
	return {"unit_world_positions": {"player": board._unit_center(units["enemy_1"]) + OWNER_HERO_FROM_ENEMY_FEET}}

static func warband_run(biome: String, tier: int = 2, midfight: bool = false) -> Dictionary:
	var engine := Run.new()
	var combat := Combat.new()
	var run: Dictionary = Warband.build(engine, combat, engine.create_new_run(SEED, Store.default_data()), {"warband_biome": biome, "warband_tier": tier})
	if midfight:
		var state: Dictionary = run["combat_state"]
		for _advance: int in range(MIDFIGHT_ADVANCES): state = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(state))["state"]
		run["combat_state"] = state
	return run

static func movement_stress() -> Dictionary:
	# Exact roster/positions from board_hud_movement_suite's crowded fixture.
	var state: Dictionary = Rest.staged_state(Combat.new())
	var enemies: Array[Dictionary]
	for y: int in range(STRESS_ROWS):
		for x: int in range(STRESS_COLUMNS):
			var tile: Vector2i = STRESS_ORIGIN + Vector2i(x, y)
			if tile == Rest.FIXTURE_HERO: continue
			var enemy: Dictionary = Groups._foe("crawler", 1 + x + y * STRESS_COLUMNS, tile)
			enemy.merge({"max_hp": 30, "block": 8, "stoneskin": 3, "immobilize": true, "bleed": 3, "expose": 2, "frost_armor": 3}, true)
			enemies.append(enemy)
	state["enemies"] = enemies
	return state

static func cases() -> Array[Dictionary]:
	var combat := Combat.new()
	var result: Array[Dictionary]
	result.append({"name": "owner", "state": owner_state(), "owner": true})
	result.append({"name": "rest_open", "state": Rest.staged_state(combat)})
	result.append({"name": "rest_crowded_props", "state": Rest.crowded_state(combat)})
	result.append({"name": "wave_E2", "state": Rest.wave_e2_state(combat)})
	result.append({"name": "mixed_stress", "state": Groups.mixed_state()})
	result.append({"name": "movement_stress_11", "state": movement_stress()})
	result.append({"name": "boss_crowded", "state": Groups.boss_state(), "boss": true})
	var dragon: Dictionary = Groups.boss_state()
	dragon["enemies"][0] = Groups._foe("vyraketh", 1, Vector2i(2, 2))
	dragon["enemies"][0]["footprint"] = Vector2i(2, 2)
	Groups._decorate(dragon)
	result.append({"name": "dragon_crowded", "state": dragon, "boss": true})
	var engine := Run.new()
	var source: Dictionary = engine.create_new_run(SEED, Store.default_data())
	for biome: String in BIOMES:
		for tier: int in TIERS:
			var run: Dictionary = warband_run(biome, tier)
			result.append({"name": "warband_%s_%d_open" % [biome, tier], "state": run["combat_state"]})
			var decorated: Dictionary = run["combat_state"].duplicate(true)
			Groups._decorate(decorated)
			result.append({"name": "warband_%s_%d_crowd" % [biome, tier], "state": decorated})
		for study: String in ["first_turn", "first_seal", "kept_open", "escape", "pressure_turn3"]:
			var run: Dictionary = Snare.build(engine, combat, source, {"snare_biome": biome, "snare_tier": 2, "snare_case": study})
			result.append({"name": "snare_%s_%s" % [biome, study], "state": run["combat_state"]})
	result.append({"name": "warband_air_2_midfight", "state": warband_run("air", 2, true)["combat_state"]})
	return result
