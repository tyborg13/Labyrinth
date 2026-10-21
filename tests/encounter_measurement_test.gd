extends SceneTree
const Sweep = preload("res://tools/encounter_sweep.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const Game = preload("res://scripts/game_data.gd")
var failures: int = 0
var checks: int = 0

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/encounter_measurement_golden.json"))
	check(Sweep.golden() == expected, "pre-change golden maps, rooms, combat transitions and save roundtrips match")
	print("ENCOUNTER GOLDEN: %s (3 seeds; maps, rooms, combat, saves)" % ["PASS" if failures == 0 else "FAIL"])
	var seen: Dictionary = {}
	var objectives: Dictionary = {}
	for seed_value: int in [1, 2]:
		var state: Dictionary = Sweep.map_for_seed(seed_value)
		var original: Dictionary = state.duplicate(true)
		for sample: Dictionary in Sweep.samples(state):
			var room: Dictionary = Sweep.layout(sample, state)
			var row: Dictionary = Sweep.composition(sample, room)
			var key: String = "%s/%s" % [sample["tier"], sample["biome"]]
			seen[key] = int(seen.get(key, 0)) + 1
			objectives[row["objective"]] = true
			check(row["unit_count"] == room["enemies"].size() and row["unit_count"] > 0, "sweep counts real generated enemies")
			var roles: int = 0
			var base_hp: int = 0
			var spawn_hp: int = 0
			for count: int in row["roles"].values(): roles += count
			for enemy: Dictionary in room["enemies"]:
				base_hp += int(Game.enemy_def(enemy["type"])["max_hp"])
				spawn_hp += int(enemy["max_hp"])
			check(roles == row["unit_count"] and row["base_hp"] == base_hp and row["spawn_hp"] == spawn_hp, "role and health totals match definitions and spawns")
			if row["objective"] == "kill_leader": check(not str(row["leader_type"]).is_empty() and row["leader_distance"] >= 0 and row["leader_closest"] != null, "leader dimensions populated")
			if row["objective"] == "reach_exit": check(row["exit_path_length"] >= 0 and row["exit_free_turns"] == ceili(float(row["exit_path_length"]) / 2.0), "exit minimum uses real path and two free tiles")
		check(state == original, "sampling and layout generation do not mutate the input map")
	check(seen.size() == 18 and seen.values().min() == 2 and seen.values().max() == 2, "small sweep covers two seeds per tier and all six biomes")
	check(objectives.size() == 3, "small sweep includes every current objective")
	print("ENCOUNTER SMALL SWEEP: %s (36 rooms)" % ["PASS" if failures == 0 else "FAIL"])
	var scorer := Bot.Policy.new()
	var damage_before: Dictionary = {"enemies": [{"id": 1, "hp": 8}], "objective": {"type": "kill_all"}, "run_stats": {"damage_dealt": 0, "enemies_killed": 0}}
	var damage_after: Dictionary = {"enemies": [{"id": 1, "hp": 0}], "objective": {"type": "kill_all"}, "run_stats": {"damage_dealt": 8, "enemies_killed": 1}}
	check(scorer.gain(damage_before, damage_after) == 13.0, "policy scores actual HP removed plus five per kill")
	damage_before["objective"] = {"type": "kill_leader", "leader_id": 1}
	damage_after["enemies"][0]["hp"] = 3
	damage_after["run_stats"] = {"damage_dealt": 5, "enemies_killed": 0}
	check(scorer.gain(damage_before, damage_after) == 10.0, "leader HP removed also counts as objective progress")
	damage_before["enemies"].append({"id": 2, "hp": 7})
	damage_after["enemies"] = [{"id": 1, "hp": 0}, {"id": 2, "hp": 0, "objective_cleared": true}]
	damage_after["run_stats"] = {"damage_dealt": 8, "enemies_killed": 1}
	check(scorer.gain(damage_before, damage_after) == 21.0, "leader follower culls do not count as damage or kills")
	check(scorer.kill_count(damage_after) == 1, "reported kills use actual engine deaths, excluding follower culls")
	var presets: Dictionary = Bot.deck_presets()
	check(presets["1"] == Game.starting_deck(), "tier one is new-run starting deck")
	check(presets["2"] == presets["1"] + presets["common_rewards"] and presets["3"] == presets["2"] + presets["rare_rewards"], "tier deck additions are cumulative")
	for id: String in presets["common_rewards"]: check(Game.card_def(id)["rarity"] == "common", "common reward comes from actual game data")
	for id: String in presets["rare_rewards"]: check(Game.card_def(id)["rarity"] == "rare", "rare reward comes from actual game data")
	check(presets["common_rewards"].size() == 3 and presets["rare_rewards"].size() == 2 and Bot.deck_presets() == presets, "fixed-seed rewards are deterministic")
	var state: Dictionary = Sweep.map_for_seed(1)
	var selected: Dictionary = {}
	for sample: Dictionary in Sweep.samples(state):
		var room: Dictionary = Sweep.layout(sample, state)
		if not selected.has(room["objective"]["type"]): selected[room["objective"]["type"]] = room
	for objective: String in selected:
		var room: Dictionary = selected[objective]
		var before: Dictionary = room.duplicate(true)
		var first: Dictionary = Bot.Policy.new().run_room(1, room, presets["2"])
		var second: Dictionary = Bot.Policy.new().run_room(1, room, presets["2"])
		check(first == second, "same seed/deck/policy replays exactly: " + objective)
		check(room == before, "bot does not mutate generator output: " + objective)
		check(first["turns"] >= 1 and first["turns"] <= Bot.MAX_TURNS and first["hp_lost"] >= 0, "bounded and valid measurement: " + objective)
		check((first["first_enemy_death_turn"] == null) == (first["kills"] == 0), "first death agrees with kills: " + objective)
	print("ENCOUNTER BOT DETERMINISM: %s (3 objectives, repeated seeded rooms)" % ["PASS" if failures == 0 else "FAIL"])
	print("ENCOUNTER MEASUREMENT: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
