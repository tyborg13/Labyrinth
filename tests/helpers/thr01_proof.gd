extends RefCounted
const Fixture = preload("res://tests/helpers/thr01_fixture.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Warband = preload("res://tools/warband_inspection.gd")
const Snare = preload("res://tools/snare_inspection.gd")
const SEED: int = 83
const TIER: int = 2
const CASES: PackedStringArray = ["dynamo", "thrall", "snare"]

static func build(kind: String) -> Dictionary:
	assert(kind in CASES)
	var engine := Run.new()
	var combat := Combat.new()
	var run: Dictionary = engine.create_new_run(SEED, Store.default_data())
	if kind == "dynamo":
		run = Warband.build(engine, combat, run, {"warband_biome": "lightning", "warband_tier": TIER, "warband_case": "encounter"})
	elif kind == "snare":
		run = Snare.build(engine, combat, run, {"snare_biome": "lightning", "snare_tier": TIER, "snare_case": "pressure_turn3"})
	else:
		run["mode"] = "combat"
		run["current_room"] = Vector2i(1, 0)
		run["combat_state"] = Fixture.bolt()
		run["current_room_layout"] = {"name": "thr-01 ordinary Thrall proof", "coord": run["current_room"], "type": "combat", "depth": 1, "element": "lightning", "grid": run["combat_state"]["grid"], "player_start": Fixture.HERO, "enemies": run["combat_state"]["enemies"], "terrain": [], "traps": [], "loot": []}
	var state: Dictionary = run["combat_state"]
	for enemy: Dictionary in state["enemies"]:
		if enemy["type"] != "arc_thrall" or int(enemy["hp"]) <= 0: continue
		enemy["intent"] = combat._scale_enemy_intent(combat.GameData.enemy_def("arc_thrall")["intents"][0], int(state["room_depth"]), state, enemy)
		# Keep the fixture clock bound to the held intent's authored Time.
		var cost: int = combat._enemy_intent_time_cost(enemy["intent"])
		for slot: Dictionary in state.get("turn_queue", []):
			if int(slot.get("enemy_id", -1)) != int(enemy["id"]): continue
			slot["time"] = int(slot["time"]) + cost - int(slot.get("intent_time_cost", cost))
			slot["intent_time_cost"] = cost
	state["turn_queue"] = combat._sorted_turn_queue(state["turn_queue"])

	return run

static func cast_index(state: Dictionary) -> int:
	var engine := Combat.new()
	for index: int in range(state["enemies"].size()):
		var enemy: Dictionary = state["enemies"][index]
		if enemy["type"] == "arc_thrall" and int(enemy["hp"]) > 0 and not engine.enemy_intent_plan(state, index).get("projected_attack", []).is_empty(): return index
	return -1
