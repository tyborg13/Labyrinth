extends SceneTree
const Sweep = preload("res://tools/encounter_sweep.gd")
const Bot = preload("res://tools/encounter_bot.gd")
const MeasurementBot = preload("res://tools/encounter_measurement_bot.gd")
const Game = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Persistence = preload("res://scripts/progression_store.gd")
const SAVE_DIRECTORY: String = "user://encounter_measurement_saves"
const SMALL_SWEEP_MAX_SEED: int = 100
const SAVE_TRAVEL_DIRECTION: Vector2i = Vector2i.RIGHT
const REJECTED_PENDING_COUNTERS = [0.5, "0", 0.0, 1, -1, null, false]
var failures: int = 0
var checks: int = 0
var stripped_wind_announcements: int = 0
var stripped_fuel_metadata: int = 0
var skybolt_suite = preload("res://tests/suites/skybolt_measurement_suite.gd").new()
# Debug-only arena; independent of all authored encounters and deck presets.
const POLICY_FIXTURE: Dictionary = {"seed": 4501, "size": 7, "player": Vector2i(2, 3), "enemy": Vector2i(3, 3), "enemy_hp": 30, "damage": 10, "enemy_time": 1, "enemy_id": 1, "low_hp": 5, "lethal_hp": 1, "approach_start": Vector2i(1, 3), "leader_id": 2, "leader_pos": Vector2i(5, 3), "exit_pos": Vector2i(2, 5), "determinism_enemy_hp": 8}

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		print("FAIL: " + message)

func test_run_save_roundtrips() -> void:
	var previous_failures: int = failures
	check(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SAVE_DIRECTORY)) == OK, "isolated run-save directory is available")
	for seed_value: int in Sweep.GOLDEN_SEEDS:
		var path: String = SAVE_DIRECTORY.path_join("seed_%d.save" % seed_value)
		Persistence.set_run_storage_path(path)
		Persistence.clear_saved_run()
		check(not Persistence.has_saved_run(), "run save begins without an old or backup checkpoint: %d" % seed_value)
		var engine := Run.new()
		var run: Dictionary = engine.create_new_run(seed_value, Persistence.default_data())
		var room: Dictionary = {}
		for candidate: Dictionary in run["rooms"].values():
			if candidate["type"] == "combat":
				room = candidate
				break
		check(not room.is_empty(), "real run has a combat room: %d" % seed_value)
		if room.is_empty(): continue
		run["current_room"] = room["coord"]
		var layout: Dictionary = engine._combat_layout_for_room(room, SAVE_TRAVEL_DIRECTION, run)
		engine._record_encounter_pick(run, layout)
		run["current_room_layout"] = layout
		run["mode"] = "combat"
		var combat := Bot.CombatEngine.new()
		var initial: Dictionary = combat.create_combat(seed_value, layout, run)
		run = engine.set_combat_state(run, combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(initial))["state"])
		var expected: Dictionary = run.duplicate(true)
		check(Persistence.save_run_state(run), "ProgressionStore run save succeeds: %d" % seed_value)
		check(Persistence.has_saved_run() and FileAccess.file_exists(path), "run checkpoint persists to isolated storage: %d" % seed_value)
		var loaded: Dictionary = Persistence.load_saved_run()
		check(not loaded.is_empty(), "ProgressionStore loads a nonempty run: %d" % seed_value)
		check(loaded == expected, "ProgressionStore restores complete run state: %d" % seed_value)
		check(run == expected, "saving does not mutate the source run: %d" % seed_value)
		print("ENCOUNTER RUN SAVE PATH: " + ProjectSettings.globalize_path(path))
		Persistence.clear_saved_run()
		check(not Persistence.has_saved_run(), "isolated run checkpoint cleans up: %d" % seed_value)
	Persistence.set_run_storage_path(Persistence.DEFAULT_RUN_STORAGE_PATH)
	print("ENCOUNTER RUN SAVE: %s (3 seeds; ProgressionStore; complete state equality)" % ["PASS" if failures == previous_failures else "FAIL"])

func arena_room(objective: String = "kill_all") -> Dictionary:
	var grid: Array
	for y: int in range(POLICY_FIXTURE["size"]):
		var row: Array[String]
		for x: int in range(POLICY_FIXTURE["size"]):
			row.append("wall" if x == 0 or y == 0 or x == POLICY_FIXTURE["size"] - 1 or y == POLICY_FIXTURE["size"] - 1 else "stone")
		grid.append(row)
	var goal: Dictionary = {"type": objective}
	if objective == "kill_leader": goal["leader_id"] = POLICY_FIXTURE["enemy_id"]
	if objective == "reach_exit": goal["exits"] = [{"target_tile": POLICY_FIXTURE["exit_pos"]}]
	return {"coord": Vector2i.ZERO, "depth": 1, "type": "combat", "grid": grid, "player_start": POLICY_FIXTURE["player"], "objective": goal,
		"enemies": [{"id": POLICY_FIXTURE["enemy_id"], "type": "crawler", "pos": POLICY_FIXTURE["enemy"], "hp": POLICY_FIXTURE["determinism_enemy_hp"], "max_hp": POLICY_FIXTURE["determinism_enemy_hp"]}]}

func policy_fixture(hand: Array) -> Dictionary:
	var policy := Bot.Policy.new()
	var state: Dictionary = policy.engine.create_combat(POLICY_FIXTURE["seed"], arena_room(), {"hp": Bot.MAX_HP, "max_hp": Bot.MAX_HP, "deck_cards": Game.starting_deck(), "relics": []})
	state["objective"] = {"type": "kill_all"}
	state["player"]["pos"] = POLICY_FIXTURE["player"]
	state["terrain"] = []
	state["traps"] = []
	state["loot"] = []
	state["surfaces"] = {}
	state["umbra"]["stage"] = "clear"
	var enemy: Dictionary = policy.engine._spawned_enemy_entry(state, "crawler", POLICY_FIXTURE["enemy_id"], POLICY_FIXTURE["enemy"], false)
	enemy["hp"] = POLICY_FIXTURE["enemy_hp"]
	enemy["max_hp"] = POLICY_FIXTURE["enemy_hp"]
	enemy["intent"] = {"id": "fixture", "time": POLICY_FIXTURE["enemy_time"], "actions": [{"type": "melee", "range": 1, "damage": POLICY_FIXTURE["damage"]}]}
	state["enemies"] = [enemy]
	state["turn_queue"] = [policy.engine._enemy_actor_entry(state, enemy, POLICY_FIXTURE["enemy_time"], 1)]
	state["deck"]["hand"] = hand.duplicate()
	return state

func test_policy() -> void:
	var previous_failures: int = failures
	var policy := Bot.Policy.new()
	var state: Dictionary = policy_fixture([])
	var original: Dictionary = state.duplicate(true)
	var stay: Dictionary = policy.phase_preview(state)
	var dodge: Dictionary = policy.best_dodge(state)
	check(stay["damage"] == POLICY_FIXTURE["damage"] and dodge["damage"] == 0, "end-turn dodge escapes a real revealed melee intent")
	var minimum_distance: int = 1000000
	for tile: Vector2i in policy.engine.player_movement_targets(state):
		var moved: Dictionary = policy.engine.apply_player_movement(state, tile)
		if policy.phase_preview(moved)["damage"] == 0: minimum_distance = mini(minimum_distance, policy.objective_distance(moved))
	check(dodge["distance"] == minimum_distance, "safe dodge ties approach the nearest objective")
	check(state == original, "dodge search leaves the live state unchanged")
	for card: String in ["brace", "stonewall_stance"]:
		state = policy_fixture([card])
		state["player_movement_remaining"] = 0
		var baseline: Dictionary = policy.best_dodge(state)
		var chosen: Dictionary = policy.choose(state)
		check(not chosen.is_empty() and chosen["card"] == card, "zero-damage defense survives shortlist and is played: " + card)
		if chosen.is_empty(): continue
		var defended: Dictionary = policy.best_dodge(chosen["state"])
		var prevented: int = int(baseline["damage"]) - int(defended["damage"])
		var expected: int = int(Game.card_def(card)["actions"][0]["amount"])
		check(prevented == expected and chosen["score"] == Bot.INCOMING_DAMAGE_WEIGHT * prevented, "defense scores actual preview HP prevented: " + card)
	state = policy_fixture(["whirlwind_slash", "brace"])
	state["player"]["hp"] = POLICY_FIXTURE["low_hp"]
	state["player_movement_remaining"] = 0
	var chosen: Dictionary = policy.choose(state)
	check(not chosen.is_empty() and chosen["card"] == "brace" and policy.best_dodge(chosen["state"])["survives"], "surviving defense beats a higher-damage lethal card preview")
	state = policy_fixture(["rooted_stance"])
	state["player"]["hp"] = POLICY_FIXTURE["lethal_hp"]
	check(policy.best_dodge(state)["survives"] and policy.choose(state).is_empty(), "safe pass and dodge beats a lethal no-move card")
	state = policy_fixture(["quick_stab"])
	state["player"]["pos"] = POLICY_FIXTURE["approach_start"]
	chosen = policy.choose(state)
	check(not chosen.is_empty() and chosen["predicted_damage"] == 0 and policy.engine.player_movement_remaining(chosen["state"]) > 0, "approach plus card preserves a safe post-card free step")
	state = policy_fixture([])
	state["objective"] = {"type": "kill_leader", "leader_id": POLICY_FIXTURE["leader_id"]}
	state["enemies"].append(policy.engine._spawned_enemy_entry(state, "crawler", POLICY_FIXTURE["leader_id"], POLICY_FIXTURE["leader_pos"], false))
	check(policy.objective_distance(state) == Sweep.Paths.manhattan(POLICY_FIXTURE["player"], POLICY_FIXTURE["leader_pos"]), "leader dodge proximity ignores closer followers")
	state = policy_fixture([])
	state["objective"] = {"type": "reach_exit", "exits": [{"target_tile": POLICY_FIXTURE["exit_pos"]}]}
	dodge = policy.best_dodge(state)
	check(dodge["state"]["player"]["pos"] == POLICY_FIXTURE["exit_pos"] and policy.engine.combat_outcome(dodge["state"]) == "victory", "end-turn movement reaches the nearest safe exit")
	check(policy.choose(state).is_empty(), "available free escape does not waste a card")
	check(Bot.defaults()["policy_version"] == 2, "policy version is recorded in defaults")
	print("ENCOUNTER BOT DODGE/DEFENSE: %s" % ["PASS" if failures == previous_failures else "FAIL"])

func test_small_sweep(revision: int) -> void:
	var previous_failures: int = failures
	var seen: Dictionary = {}
	var objectives: Dictionary = {}
	var generated: int = 0
	var seed_value: int = Sweep.DEFAULT_FIRST_SEED
	var expected_bins: int = Sweep.bin_keys(revision).size()
	while (seen.size() < expected_bins or seen.values().min() < 2) and seed_value < SMALL_SWEEP_MAX_SEED:
		var state: Dictionary = Sweep.map_for_seed(seed_value, revision)
		var original: Dictionary = state.duplicate(true)
		for sample: Dictionary in Sweep.samples(state):
			var key: String = "%s/%s/%s" % [sample["cohort"], sample["tier"], sample["biome"]]
			if int(seen.get(key, 0)) >= 2: continue
			var room: Dictionary = Sweep.layout(sample, state)
			var row: Dictionary = Sweep.composition(sample, room)
			seen[key] = int(seen.get(key, 0)) + 1
			generated += 1
			objectives[row["objective"]] = true
			check(row["revision"] == revision and row["cohort"] == sample["cohort"], "sample retains revision and cohort")
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
			if revision >= 6:
				if sample["cohort"] == "warband":
					check(sample["room"]["type"] == "special" and row["special_type"] == "warband" and row["special_variant"] == sample["biome"] and row["objective"] == "kill_leader", "Warband uses real special node and biome variant")
					check(Sweep.digest(room) == Sweep.digest(Run.new()._combat_layout_for_room(sample["room"], sample["travel_dir"], state)), "Warband matches spx-03 production path")
				elif sample["cohort"] == "standard":
					check(row["objective"] == "kill_all" and row["special_type"] == "", "revision-6 standard fights are Defeat All")
			if sample["cohort"] in ["guardian", "boss"]:
				var cohort: String = sample["cohort"]
				check(sample["room"]["type"] == cohort and row["room_type"] == cohort, "new cohorts select their actual room type")
				check(room["objective"] == Run.new()._combat_layout_for_room(sample["room"], sample["travel_dir"], state)["objective"], "new cohorts retain the complete production objective")
				check(row["objective"] == "kill_leader" and row["boss_id"] == sample["room"]["boss_id"], "Guardian/dragon identity and leader objective come from their own room")
				check(MeasurementBot.accepts(sample, sample["tier"], cohort), "bot selection accepts the natural cohort and tier")
				check(not MeasurementBot.accepts(sample, sample["tier"], "standard"), "bot selection rejects a different cohort")
				check(MeasurementBot.deck_tier(sample) == (3 if cohort == "boss" else sample["tier"]), "new cohorts use the required deck preset")
				if cohort == "boss":
					check(row["room_tier"] == 4 and sample["tier"] == 3, "dragon keeps band 4 separately from tier-3 measurement deck")
					check(MeasurementBot.accepts(sample, 3, "boss", row["boss_id"]) and not MeasurementBot.accepts(sample, 3, "boss", "different_dragon"), "per-dragon bot selection retains the section's dragon")
				else:
					check(row["room_tier"] == sample["tier"] and row["guardian_id"] == sample["room"]["guardian_id"], "Guardian keeps its own room tier and identity")
		check(state == original, "sampling and layout generation do not mutate the input map")
		seed_value += 1
	check(seen.size() == expected_bins and seen.values().min() == 2 and seen.values().max() == 2, "small sweep covers two distinct seeds per cohort/tier and all six biomes")
	check(objectives.size() == (2 if revision >= 6 else 3), "small sweep includes the revision's supported objectives")
	print("ENCOUNTER SMALL SWEEP: %s (revision %d; %d rooms; seeds 1..%d)" % ["PASS" if failures == previous_failures else "FAIL", revision, generated, seed_value - 1])

func _legacy_wind_metadata(combats: Array) -> Array:
	# spx-07 adds wind announcements; bos-04 adds ground lay provenance.
	# Resolve the complete new rules before excluding that additive metadata. All
	# positions, directions that actually blew, damage, RNG, maps and saves still
	# compare exactly. The focused wind suite checks the new metadata itself.
	var compatible: Array = combats.duplicate(true)
	for state: Dictionary in compatible:
		_strip_fuel_metadata(state, int(state.get("turn", 1)))
		for enemy: Dictionary in state.get("enemies", []):
			for action: Dictionary in enemy.get("intent", {}).get("actions", []):
				if action.has("_wind_direction"):
					stripped_wind_announcements += 1
					action.erase("_wind_direction")
	return compatible

func _strip_fuel_metadata(value: Variant, player_activation: int) -> void:
	# bos-04 adds saved lay provenance, not a change to this revision-5
	# ordinary-fight oracle. Validate only these new fields before removing
	# them; the frozen hashes still compare every other resolved/save field.
	if value is Array:
		for child: Variant in value: _strip_fuel_metadata(child, player_activation)
	elif value is Dictionary:
		if value.has("marks_source"):
			var source: Dictionary = value.get("source", {})
			var marks_source: Dictionary = value["marks_source"]
			var expected: Dictionary = {"actor_kind": source.get("kind", ""), "actor_id": int(source.get("id", -1)), "source_kind": "battlefield_rule", "rule": "upheaval", "laid_player_activation": marks_source.get("laid_player_activation")}
			check(value.get("rule", "")=="upheaval" and marks_source==expected, "Golden excludes only the exact additive Upheaval provenance record")
			_strip_fuel_metadata(marks_source, player_activation)
			value.erase("marks_source")
		if value.has("laid_player_activation"):
			var laid: Variant = value["laid_player_activation"]
			check(typeof(laid)==TYPE_INT and int(laid)>=0 and int(laid)<=player_activation, "Golden ground lay index is an actual begun player activation")
			stripped_fuel_metadata += 1
			value.erase("laid_player_activation")
		for child: Variant in value.values(): _strip_fuel_metadata(child, player_activation)

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var audit: Script = preload("res://tools/enc04_golden_audit.gd")
	check(audit.approved_pending_counter({"pending_summon_card_plays": 0}), "Golden audit permits exactly integer zero")
	check(not audit.approved_pending_counter({}), "Golden audit rejects a missing pending counter")
	for counter: Variant in REJECTED_PENDING_COUNTERS:
		check(not audit.approved_pending_counter({"pending_summon_card_plays": counter}), "Golden audit rejects non-integer-zero counter: " + var_to_str(counter))
	# el-01 re-recorded seeds 1 and 421: the Gust beat now fires after its source's turn
	# (owner-approved element rules). Only their two Gale Herald rooms changed.
	# fix-17 updates only seed 19 combat/save_roundtrip for pt13-01 (68df4200c):
	# combat[13].surface_events[0].source.causal_source_kind = "trap". Removing
	# only that additive field reproduces every previous golden hash exactly.
	# bos-01 updates only seed 421 combat/save_roundtrip: combat[23]'s Briar
	# Weaver Thornwall (enemy id 2) skips (2,5), which disconnects the floor
	# after (1,5) is marked. The generic line_between guard applies to every user,
	# including this ordinary Thornwall and the Thornmother. No other field changes.
	# enc-03 updates exactly 2 fire rooms containing Slag Mortars (seed 1 at
	# (19, -15), seed 421 at (9, -8)): Lob Slag min_range 3 -> 2, weight 3 -> 4.
	# Only those intent fields differ in 3 combat snapshots; their containing
	# combat/save_roundtrip hashes change. Maps, rooms, other units and every
	# other combat field are identical; serialization still roundtrips exactly.
	# int-06 combines seed 421's bos-01/enc-03 changes (1 Thornwall room and
	# 2 Slag rooms across seeds 1/421) and sum-01's pending_summon_card_plays=0
	# in all 54 rooms (108 snapshots). enc04_golden_audit.gd reconstructs every
	# prior hash by removing only that zero field and restoring seed 421's
	# pre-enc-03 Slag data. No maps, layouts or unexplained fields are re-pinned.
	# bos-03 feedback 3 re-audit after the int-06 sync: all hashes match exactly.
	# This oracle samples 54 standard rooms and zero Guardian rooms; bos-03
	# changes none of its hashes and requires no further re-pin.
	# bos-04 validates and removes only lay metadata here. Its independent
	# scheduler/save regressions test the new fields; the oracle stays frozen.
	# int-11: re-pin only the 12 director-reviewed rooms; all three maps and
	# 54 layouts remain exact. Enemy simplifications plus mrk-01's additive
	# Seer/Mortar dials and Rime Spitter's removed non-path _resolved_path
	# explain every changed leaf. The full before/after audit matched the
	# reviewed differences before updating these combat/save hashes.
	# qa-21: qa-18 (67a5e1906, integrated by 797fa596e) replaces saved
	# committed_plan.enemy_index with enemy_id. Seed 1 snapshots 10, 16, 17
	# change index 1 -> id 2 (Rime Spitter) and index 3 -> id 4 (Bell Tender).
	# These six leaves and their six save copies are the complete diff from
	# both 695404aa5 and pre-qa-18 e6b5727ef; only seed 1 combat/save hashes
	# are re-pinned. Maps, rooms and all other fields still compare exactly.
	var expected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/encounter_measurement_golden.json"))
	check(Sweep.golden(_legacy_wind_metadata) == expected, "pre-change golden maps, rooms, combat transitions and save roundtrips match")
	check(stripped_wind_announcements > 0, "Legacy golden exercises the separately tested additive wind-lock metadata")
	check(stripped_fuel_metadata > 0, "Legacy golden exercises the lay provenance independently covered by the fuel scheduler/save regressions")
	test_run_save_roundtrips()
	print("ENCOUNTER GOLDEN: %s (3 seeds; maps, rooms, combat, saves)" % ["PASS" if failures == 0 else "FAIL"])
	test_small_sweep(Sweep.LEGACY_REVISION)
	test_small_sweep(6)
	test_small_sweep(Sweep.LATEST_REVISION)
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
	test_policy()
	skybolt_suite.run(Callable(self, "check"), Callable(self, "policy_fixture"), Callable(self, "arena_room"), POLICY_FIXTURE)
	var previous_failures: int = failures
	for objective: String in ["kill_all", "kill_leader", "reach_exit"]:
		var room: Dictionary = arena_room(objective)
		var before: Dictionary = room.duplicate(true)
		var first: Dictionary = Bot.Policy.new().run_room(POLICY_FIXTURE["seed"], room, presets["2"])
		var second: Dictionary = Bot.Policy.new().run_room(POLICY_FIXTURE["seed"], room, presets["2"])
		check(first == second, "same seed/deck/policy replays exactly: " + objective)
		check(room == before, "bot does not mutate fixture input: " + objective)
		check(first["turns"] >= 1 and first["turns"] <= Bot.MAX_TURNS and first["hp_lost"] >= 0, "bounded and valid measurement: " + objective)
		check((first["first_enemy_death_turn"] == null) == (first["kills"] == 0), "first death agrees with kills: " + objective)
	print("ENCOUNTER BOT DETERMINISM: %s (3 explicit objective fixtures, repeated seeded rooms)" % ["PASS" if failures == previous_failures else "FAIL"])
	print("ENCOUNTER MEASUREMENT: %s (%d checks; %d failures)" % ["PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)
