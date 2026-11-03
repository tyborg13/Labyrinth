extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Game = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const TEST_SEED: int = 41027
const TEST_HERO_HP: int = 30
const TEST_GRID_SIZE: int = 9
const TEST_ENEMY_START := Vector2i(2, 4)
const TEST_HERO_START := Vector2i(6, 4)
const TEST_FADE_HERO := Vector2i(4, 4)
const TEST_RANGED_HERO := Vector2i(7, 4)
const TEST_ILLUSION_HP: int = 10
const TEST_RANGED_RANGE: int = 6
const TEST_SAVED_SHOCK: int = 1
const TEST_ANALYTICS_DAMAGE: int = 17

static func enemy(type: String, id: int, pos: Vector2i, intent_id: String) -> Dictionary:
	var definition: Dictionary = Game.enemy_def(type)
	var intent: Dictionary = {}
	for candidate: Dictionary in definition["intents"]:
		if candidate["id"] == intent_id: intent = candidate.duplicate(true)
	return {"id": id, "type": type, "pos": pos, "hp": definition["max_hp"], "max_hp": definition["max_hp"], "intent": intent}

static func state(type: String, intent: String) -> Dictionary:
	var grid: Array
	for y: int in range(TEST_GRID_SIZE):
		var row: Array[String]
		for x: int in range(TEST_GRID_SIZE): row.append("wall" if x in [0, TEST_GRID_SIZE - 1] or y in [0, TEST_GRID_SIZE - 1] else "stone")
		grid.append(row)
	var unit: Dictionary = enemy(type, 1, TEST_ENEMY_START, intent)
	var layout: Dictionary = {"grid": grid, "name": "sta-01 proof", "coord": Vector2i(1, 0), "type": "combat", "depth": 1, "umbra_stage": "clear", "element": "none", "player_start": TEST_HERO_START, "enemies": [unit], "terrain": [], "traps": [], "loot": []}
	var engine := Combat.new()
	var result: Dictionary = engine.create_combat(TEST_SEED, layout, {"hp": TEST_HERO_HP, "max_hp": TEST_HERO_HP, "deck_cards": ["quick_stab", "pale_spark"], "hand_size": 2, "relics": []})
	result["enemies"][0]["intent"] = engine._surface_prepare_enemy_intent(result, result["enemies"][0], unit["intent"])
	return result

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var before: Dictionary = state("gloam_stalker", "fade")
	before["player"]["pos"] = TEST_FADE_HERO
	var faded: Dictionary = engine._resolve_enemy_intent(before, 0, before["enemies"][0]["intent"])
	var fade_tokens: Array = preload("res://scripts/action_icon_library.gd").tokens_for_action(before["enemies"][0]["intent"]["actions"][0])
	expect.call(fade_tokens[0]["tooltip"] == "Fade: Blinks behind you. Next turn it Ambushes.", "Fade tooltip is the approved exact copy")
	expect.call(not faded["enemies"][0].has("veiled"), "Fade never installs Veiled")
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	engine._assign_enemy_intent(faded, 0, rng)
	expect.call(faded["enemies"][0]["intent"]["id"] == "ambush", "Fade forces the advertised Ambush")
	faded["player"]["pos"] = TEST_RANGED_HERO
	var target: Vector2i = faded["enemies"][0]["pos"]
	expect.call(engine.PathUtils.manhattan(faded["player"]["pos"], target) > 1, "Wind-up targeting fixture is non-adjacent")
	var shot: Dictionary = {"type": "ranged", "range": TEST_RANGED_RANGE, "damage": 11}
	expect.call(engine.valid_targets_for_player_action(faded, shot).has(target), "Wind-up Stalker is targetable at range")
	var killed: Dictionary = engine.apply_player_action(faded, shot, target)
	expect.call(killed["enemies"][0]["hp"] == 0, "Ranged card can kill the wind-up Stalker")
	test_dive(expect, engine)
	_test_force_forecast(expect, engine)
	var live: Dictionary = state("gust_shrike", "dive")
	live["enemies"][0]["intent"]["live_body"] = true
	expect.call(not engine.enemy_intent_plan(live, 0).is_empty(), "Shared live-body shape replans without recursive commitment")
	_test_saves(expect, engine)
	_test_save_scope(expect)

static func _test_force_forecast(expect: Callable, engine: RefCounted) -> void:
	for restriction: String in ["blocked", "rooted", "interrupted", "reachable"]:
		var before: Dictionary = state("gust_shrike", "dive")
		match restriction:
			"blocked": before["grid"][TEST_ENEMY_START.y][TEST_ENEMY_START.x + 1] = "wall"
			"rooted": before["enemies"][0]["immobilize"] = true
			"interrupted": before["enemies"][0]["shock"] = TEST_SAVED_SHOCK
		var threat: Dictionary = engine.enemy_threat_tiles(before, 0)
		var force: Dictionary = engine.projected_player_force(before, 1, threat)
		var reached: bool = restriction == "reachable"
		expect.call((threat["projected_attack"] as Array).has(TEST_HERO_START) == reached, "Dive projected hit respects " + restriction)
		expect.call(force.is_empty() != reached, "Force forecast requires a hero hit: " + restriction)
		var after: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0, false, false)["state"]
		expect.call((after["player"]["pos"] != TEST_HERO_START) == reached, "Resolved displacement agrees with " + restriction + " forecast")
		expect.call((int(after["player"]["hp"]) < TEST_HERO_HP) == reached, "Resolved hit agrees with " + restriction + " forecast")

static func test_dive(expect: Callable, engine: RefCounted) -> void:
	var before: Dictionary = state("gust_shrike", "dive")
	var intent: Dictionary = before["enemies"][0]["intent"]
	var authored: Dictionary = Game.enemy_def("gust_shrike")["intents"][0]["actions"][1]
	expect.call(str(authored["type"]) == "aoe" and int(authored["damage"]) == 4 and str(authored["committed_shape"]) == "swept_path" and int(authored["push"]) == 1 and str(authored["element"]) == "air", "Dive uses the approved shared action values")
	expect.call(int(intent["time"]) == 5 and intent["actions"][0]["type"] == "move_toward" and int(intent["actions"][0]["range"]) == 4, "Dive keeps Time and uses shared Move 4")
	var plan: Dictionary = engine.enemy_intent_plan(before, 0)
	var path: Array = plan["path"]
	expect.call(path.size() > 2, "Dive fixture has an actual movement path")
	# An adjacent body beside an intermediate anchor is in the shared swept
	# shape but outside the final landing ring. This detects endpoint-only hits.
	var middle: Vector2i = path[1]
	var witness: Vector2i = middle + Vector2i.UP
	before["illusions"] = [{"id": 2, "pos": witness, "hp": TEST_ILLUSION_HP, "max_hp": TEST_ILLUSION_HP, "block": 0}]
	plan = engine.enemy_intent_plan(before, 0)
	expect.call(plan["projected_attack"].has(witness), "Dive preview includes units along its swept path")
	var hp: int = before["illusions"][0]["hp"]
	var after: Dictionary = engine._resolve_enemy_intent(before, 0, intent)
	expect.call(after["illusions"][0]["hp"] <= hp - 4, "Dive hits units along its path")
	expect.call(after["player"]["hp"] <= TEST_HERO_HP - 4, "Dive applies shared air area damage to hero")
	expect.call(after["enemies"][0]["pos"] == plan["destination"], "Dive shared forecast and landing agree")
	var effect: Dictionary = {"kind": "aoe", "committed_shape": "swept_path", "element": "air"}
	expect.call(preload("res://scripts/gust_shrike_cutout/action.gd").action_for_effect(effect, before["enemies"][0]) == "dive", "Shared swept attack plays the existing Dive clip")

static func _round_trip(value: Dictionary) -> Dictionary:
	return _round_trip_run({"mode": "combat", "combat_state": value}).get("combat_state", {})

static func _round_trip_run(value: Dictionary) -> Dictionary:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://sta01_legacy.save")
	Store.save_run_state(value)
	var loaded: Dictionary = Store.load_saved_run()
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	return loaded

static func _test_save_scope(expect: Callable) -> void:
	var fight: Dictionary = state("gust_shrike", "dive")
	var legacy: Dictionary = {"veiled": true, "ends_veil": true, "actions": [{"type": "dive_line", "damage": TEST_ANALYTICS_DAMAGE}]}
	fight["enemies"][0]["veiled"] = true
	fight["enemies"][0]["intent"] = {"id": "dive", "actions": [{"type": "dive_line", "max_length": 4, "damage": 4, "side_push": 1}]}
	fight["analytics"] = legacy.duplicate(true)
	fight["history"] = [legacy.duplicate(true)]
	var saved: Dictionary = {"mode": "combat", "combat_state": fight, "analytics": legacy.duplicate(true), "history": [legacy.duplicate(true)], "pending_combat_checkpoints": [{"state": fight.duplicate(true), "analytics": legacy.duplicate(true)}]}
	var loaded: Dictionary = _round_trip_run(saved)
	expect.call(loaded["analytics"] == saved["analytics"] and loaded["history"] == saved["history"], "Save migration preserves unrelated analytics and history payloads")
	for converted: Dictionary in [loaded["combat_state"], loaded["pending_combat_checkpoints"][0]["state"]]:
		expect.call(not converted["enemies"][0].has("veiled") and converted["enemies"][0]["intent"]["actions"].size() == 2, "Live fight and continuation snapshot convert retired mechanics")
		expect.call(converted["analytics"] == legacy and converted["history"] == [legacy], "Combat snapshot migration preserves embedded analytics and history")
	expect.call(loaded["pending_combat_checkpoints"][0]["analytics"] == legacy, "Continuation metadata is outside combat migration scope")

static func _test_saves(expect: Callable, engine: RefCounted) -> void:
	var stalker: Dictionary = state("gloam_stalker", "ambush")
	stalker["enemies"][0]["veiled"] = true
	stalker["enemies"][0]["intent"]["actions"][0].erase("ambush")
	stalker["enemies"][0]["intent"]["actions"][0]["ends_veil"] = true
	var loaded: Dictionary = _round_trip(stalker)
	expect.call(not loaded.is_empty() and not loaded["enemies"][0].has("veiled") and loaded["enemies"][0]["intent"]["actions"][0].get("ambush", false), "Old saved Veiled Stalker converts on load")
	expect.call(not engine.enemy_intent_plan(loaded, 0).is_empty(), "Converted Stalker plans without errors")
	var shrike: Dictionary = state("gust_shrike", "dive")
	shrike["enemies"][0]["intent"] = {"id": "dive", "name": "Dive", "time": 5, "actions": [{"type": "dive_line", "max_length": 4, "damage": 4, "side_push": 1, "element": "air", "shock": TEST_SAVED_SHOCK, "scale_damage": false}]}
	loaded = _round_trip(shrike)
	var intent: Dictionary = loaded["enemies"][0]["intent"]
	expect.call(intent["time"] == 5 and intent["actions"].size() == 2 and intent["actions"][1].get("committed_shape") == "swept_path", "Old saved held Dive converts on load")
	var after: Dictionary = engine._resolve_enemy_intent(loaded, 0, intent)
	expect.call(after["player"]["hp"] < TEST_HERO_HP, "Converted held Dive resolves through shared pieces")
	expect.call(int(after["player"]["shock"]) == TEST_SAVED_SHOCK and not bool(intent["actions"][1]["scale_damage"]), "Converted Dive retains saved ordinary riders and scaling metadata")
