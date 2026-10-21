extends RefCounted
const Rooms = preload("res://scripts/room_generator.gd")
const RoomRules = preload("res://scripts/warband_room_rules.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const Identity = preload("res://scripts/enemy_identity.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/warband_inspection.gd")
const MATRIX_SEEDS: int = 200
const TEST_PLAYER_HP: int = 100
const LEGACY_GOLDEN_SEEDS: int = 64
const FALLBACK_PROOF_SEED: int = 123456
const OPENING_DAMAGE_THRESHOLD: int = 6

class FallbackGenerator extends "res://scripts/room_generator.gd":
	var template_attempts: int = 0
	func _apply_template(grid: Array, _rng: RandomNumberGenerator) -> void:
		template_attempts += 1
		for y: int in range(1, 8):
			for x: int in range(1, 8): grid[y][x] = "pillar"

class NarrowFallbackGenerator extends FallbackGenerator:
	func _base_grid(_rng: RandomNumberGenerator) -> Array:
		var grid: Array = []
		for y: int in range(9):
			var row: Array = []
			for x: int in range(9): row.append("wall")
			grid.append(row)
		for y: int in range(1, 8): grid[y][4] = "stone"
		for x: int in range(4, 8): grid[7][x] = "stone"
		for y: int in range(5, 7): grid[y][7] = "stone"
		return grid
	func _apply_template(_grid: Array, _rng: RandomNumberGenerator) -> void:
		template_attempts += 1

static func run(expect: Callable, measure_opening_damage: bool = false) -> Dictionary:
	var report: Dictionary = _matrix(expect, measure_opening_damage)
	_golden(expect)
	_command(expect)
	_command_composite_movement(expect)
	_keep_distance(expect)
	_break(expect)
	_titles(expect)
	_save_load(expect)
	_native_fixture_semantics(expect)
	_fixture_case_typing(expect)
	return report

static func _matrix(expect: Callable, measure_opening_damage: bool) -> Dictionary:
	var generator := Rooms.new()
	var combat := Combat.new()
	var player_snapshot: Dictionary = {}
	if measure_opening_damage:
		var engine := Run.new()
		player_snapshot = engine._player_snapshot(engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()))
		player_snapshot["hp"] = TEST_PLAYER_HP
		player_snapshot["max_hp"] = TEST_PLAYER_HP
	var report: Dictionary = {"threshold_hp": OPENING_DAMAGE_THRESHOLD, "method": "headless console incoming preview: finish_player_activation then advance_to_next_player_turn_with_steps, HP before next-turn setup", "player": "fresh-run default loadout, 100 HP to avoid lethal truncation, no cards or movement", "seeds_per_cohort": MATRIX_SEEDS, "cohorts": [], "rooms": [], "over_threshold": 0}
	var count: int = 0
	for biome: String in Library.definition("warband")["variants"]:
		var variant: Dictionary = Library.definition("warband")["variants"][biome]
		for tier: int in [1, 2, 3]:
			var over_threshold: int = 0
			var max_hp_loss: int = 0
			for seed: int in range(MATRIX_SEEDS):
				var room: Dictionary = Fixture.room_spec(biome, tier)
				var layout: Dictionary = generator.generate_room(seed, room, Paths.DIRS_4[seed % 4])
				var enemies: Array = layout["enemies"]
				var captain: Dictionary = enemies[0]
				var entry: Vector2i = layout["player_start"]
				var grid: Array = layout["grid"]
				var context: String = "%s tier %d seed %d" % [biome, tier, seed]
				expect.call(enemies.size() == tier + 3 and captain["type"] == variant["captain"] and bool(captain.get("is_leader", false)), "Authored roster/captain: " + context)
				for index: int in range(1, enemies.size()): expect.call(enemies[index]["type"] == variant["escort"][index - 1], "Ordered tier escort: " + context)
				var distance: int = Paths.manhattan(entry, captain["pos"])
				expect.call(distance >= 5 and distance <= 7, "Captain range 5–7: " + context)
				var nearest: int = distance
				var occupied: Dictionary = {entry: true}
				for index: int in range(enemies.size()):
					var tile: Vector2i = enemies[index]["pos"]
					expect.call(not occupied.has(tile) and Paths.is_passable(grid, tile) and not Paths.find_path(grid, entry, tile).is_empty(), "Distinct reachable spawn: " + context)
					occupied[tile] = true
					nearest = mini(nearest, Paths.manhattan(entry, tile))
					expect.call(Paths.manhattan(entry, tile) > Rooms.ENEMY_SPAWN_SAFE_RADIUS, "Every spawn outside ordinary entry halo: " + context)
					if index > 0: expect.call(Paths.manhattan(entry, tile) >= 3, "Every escort at least 3 from entry: " + context)
				expect.call(nearest < distance, "Captain never closest: " + context)
				var screen: Vector2i = enemies[2]["pos"]
				expect.call(Paths.manhattan(entry, screen) + Paths.manhattan(screen, captain["pos"]) == distance, "Screen on Manhattan shortest path: " + context)
				expect.call(captain["max_hp"] == ceili(generator._scaled_enemy_max_hp(str(captain["type"]), tier) * 1.25) and captain["stoneskin"] == tier + 1, "Warband HP/Stoneskin: " + context)
				expect.call(not captain.has("scale") and Identity.display_name(captain) == variant["title"], "Captain density/title: " + context)
				_spread_rules(expect, layout, context)
				if biome == "lightning":
					var unused_rng := RandomNumberGenerator.new()
					var deepest: Array[Vector2i] = RoomRules.positions(grid, entry, enemies.size(), Rooms.ENEMY_SPAWN_SAFE_RADIUS, unused_rng, true, true)
					expect.call(not deepest.is_empty() and Paths.manhattan(deepest[0], entry) == distance, "Dynamo uses farthest complete legal formation: " + context)
				if measure_opening_damage:
					var hp_loss: int = opening_hp_loss(combat, combat.create_combat(seed, layout, player_snapshot))
					if hp_loss > OPENING_DAMAGE_THRESHOLD: over_threshold += 1
					max_hp_loss = maxi(max_hp_loss, hp_loss)
					(report["rooms"] as Array).append({"biome": biome, "tier": tier, "seed": seed, "entry_direction": seed % 4, "hp_loss": hp_loss})
				count += 1
			if measure_opening_damage:
				(report["cohorts"] as Array).append({"biome": biome, "tier": tier, "rooms": MATRIX_SEEDS, "over_threshold": over_threshold, "percent": 100.0 * over_threshold / MATRIX_SEEDS, "max_hp_loss": max_hp_loss})
				report["over_threshold"] += over_threshold
				print("Warband opening damage >6 HP: %s tier %d: %d/%d (%.2f%%), max %d HP" % [biome, tier, over_threshold, MATRIX_SEEDS, 100.0 * over_threshold / MATRIX_SEEDS, max_hp_loss])
	print("Warband placement matrix: %d rooms (6 variants × 3 tiers × 200 seeds), 4 entry directions" % count)
	var sample: Dictionary = generator.generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("air", 2), Vector2i.UP)
	var rng := RandomNumberGenerator.new()
	var first: Array[Vector2i] = RoomRules.positions(sample["grid"], sample["player_start"], 5, Rooms.ENEMY_SPAWN_SAFE_RADIUS, rng, false, true)
	rng.seed = FALLBACK_PROOF_SEED
	expect.call(first == RoomRules.positions(sample["grid"], sample["player_start"], 5, Rooms.ENEMY_SPAWN_SAFE_RADIUS, rng, false, true), "Deterministic legal fallback is seed-independent")
	var blocked := FallbackGenerator.new()
	var fallback: Dictionary = blocked.generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("lightning", 3), Vector2i.UP)
	expect.call(blocked.template_attempts <= RoomRules.MAX_PLACEMENT_ATTEMPTS + 1 and RoomRules.validate(fallback, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Exhausted seeded retries produce a deterministic legal fallback room")
	var narrow := NarrowFallbackGenerator.new()
	var relaxed: Dictionary = narrow.generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("lightning", 3), Vector2i.UP)
	expect.call(narrow.template_attempts == RoomRules.MAX_PLACEMENT_ATTEMPTS + 1 and not relaxed.has("warband_escort_radius_relaxed") and RoomRules.validate(relaxed, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Narrow fallback preserves every spread constraint after seeded retries")
	expect.call(relaxed["grid"][6][3] == "stone", "Impossible narrow formation clears interior blockers instead of relaxing spread")
	var repeat: Dictionary = NarrowFallbackGenerator.new().generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("lightning", 3), Vector2i.UP)
	expect.call(relaxed == repeat, "Strict fallback remains deterministic")
	# Revalidate the entry halo even if it becomes larger than the authored
	# three-tile minimum; fallback must never trade it for roster capacity.
	var wider_halo: int = 3
	var halo_positions: Array[Vector2i] = RoomRules.fallback_positions(sample["grid"], sample["player_start"], 5, wider_halo, false)
	expect.call(halo_positions.size() == 5 and halo_positions.all(func(tile: Vector2i) -> bool: return Paths.manhattan(tile, sample["player_start"]) > wider_halo), "Fallback preserves the supplied ordinary entry halo")
	if measure_opening_damage:
		report["total_rooms"] = count
		report["percent"] = 100.0 * int(report["over_threshold"]) / count
		print("Warband opening damage >6 HP: TOTAL %d/%d (%.2f%%)" % [report["over_threshold"], count, report["percent"]])
	_placement_regressions(expect)
	_screen_geometry_regression(expect)
	return report

static func _spread_rules(expect: Callable, layout: Dictionary, context: String) -> void:
	var enemies: Array = layout["enemies"]
	var captain: Vector2i = enemies[0]["pos"]
	var entry: Vector2i = layout["player_start"]
	var guard: Vector2i = enemies[1]["pos"]
	var screen: Vector2i = enemies[2]["pos"]
	expect.call(Paths.manhattan(guard, captain) <= 2, "Guard within Command: " + context)
	expect.call(Paths.manhattan(screen, captain) in [2, 3], "Screen 2–3 from captain: " + context)
	var grid: Array = layout["grid"]
	expect.call(Paths.find_path(grid, entry, screen).size() + Paths.find_path(grid, screen, captain).size() == Paths.find_path(grid, entry, captain).size() + 1, "Screen on walkable shortest route: " + context)
	var blocked: Dictionary = {captain: true, guard: true}
	for index: int in range(1, enemies.size()):
		var tile: Vector2i = enemies[index]["pos"]
		for previous: int in range(1, index): expect.call(Paths.manhattan(tile, enemies[previous]["pos"]) >= 2, "No adjacent followers: " + context)
		if index >= 3:
			var distance: int = Paths.manhattan(tile, entry)
			expect.call(distance >= 3 and distance <= 5, "Skirmisher entry distance: " + context)
			var line: Vector2i = captain - entry
			var offset: Vector2i = tile - entry
			var cross: int = line.x * offset.y - line.y * offset.x
			expect.call(cross < 0 if (index - 3) % 2 == 0 else cross > 0, "Alternating left/right skirmishers: " + context)
			for previous: int in range(index): expect.call(Paths.manhattan(tile, enemies[previous]["pos"]) >= 3, "Skirmisher gap from every prior unit: " + context)
		if index >= 2:
			blocked[tile] = true
			for axis: Vector2i in Paths.DIRS_4: blocked[tile + axis] = true
	var targets: Array[Vector2i]
	for tile: Vector2i in Paths.reachable_tiles(grid, entry, grid.size() * grid.size(), blocked):
		if Paths.manhattan(tile, captain) <= 2: targets.append(tile)
	expect.call(not targets.is_empty(), "Independent way-through flood fill: " + context)
	expect.call(RoomRules.validate(layout, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Complete spread validator: " + context)

static func _screen_geometry_regression(expect: Callable) -> void:
	var generated: Dictionary = Rooms.new().generate_room(54, Fixture.room_spec("air", 2), Vector2i.DOWN)
	_spread_rules(expect, generated, "seed 54 DOWN")
	var invalid: Dictionary = generated.duplicate(true)
	invalid["enemies"][2]["pos"] = invalid["enemies"][1]["pos"]
	expect.call(not RoomRules.validate(invalid, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Validator rejects overlapping guard/screen")
	invalid = generated.duplicate(true)
	invalid["enemies"][3]["pos"] = invalid["player_start"]
	expect.call(not RoomRules.validate(invalid, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Validator rejects skirmisher in entry halo")
	invalid = generated.duplicate(true)
	var first: Vector2i = invalid["enemies"][3]["pos"]
	invalid["enemies"][3]["pos"] = invalid["enemies"][4]["pos"]
	invalid["enemies"][4]["pos"] = first
	expect.call(not RoomRules.validate(invalid, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Validator rejects reversed skirmisher sides")
	print("Warband spread geometry: guard, screen, alternating skirmishers, gaps and way-through checked")

static func _fixture_case_typing(expect: Callable) -> void:
	var source: String = FileAccess.get_file_as_string("res://tools/warband_inspection.gd")
	var bare_literal := RegEx.new()
	bare_literal.compile("(?:const|var)\\s+CASES\\s*:\\s*Array\\[String\\]\\s*=\\s*\\[")
	expect.call(bare_literal.search(source) == null, "Fixture CASES cannot assign a bare literal to Array[String] on Windows")
	expect.call(Fixture.CASES.is_typed() and Fixture.CASES.get_typed_builtin() == TYPE_STRING, "Fixture CASES has runtime string typing")
	for value: String in ["encounter", "pre_battle", "keep_distance", "break"]:
		expect.call(Fixture.validate({"warband_case": value}).is_empty(), "Typed fixture cases preserve " + value)

static func opening_hp_loss(engine: RefCounted, state: Dictionary) -> int:
	# Exactly the existing headless console's incoming preview, including
	# Command, initiative timing and repeated activations. No damage estimator.
	var phase: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(state))
	var before_setup: Dictionary = phase.get("player_turn_before_state", {})
	var after_enemy: Dictionary = before_setup if not before_setup.is_empty() else phase["state"]
	return maxi(0, int(state["player"]["hp"]) - int(after_enemy["player"]["hp"]))

static func _placement_regressions(expect: Callable) -> void:
	var run_engine := Run.new()
	var combat := Combat.new()
	for sample: Dictionary in [{"biome": "air", "tier": 2, "seed": 83}, {"biome": "fire", "tier": 1, "seed": 7}]:
		var run: Dictionary = Fixture.build(run_engine, combat, run_engine.create_new_run(sample["seed"], Store.default_data()), {"warband_biome": sample["biome"], "warband_tier": sample["tier"]})
		var layout: Dictionary = run["current_room_layout"]
		expect.call(RoomRules.validate(layout, Rooms.ENEMY_SPAWN_SAFE_RADIUS), "Console placement regression: " + str(sample))
		for index: int in range(1, layout["enemies"].size()):
			expect.call(Paths.manhattan(layout["enemies"][index]["pos"], layout["player_start"]) >= 3, "Console escorts never start within 2 tiles: " + str(sample))
		print("Warband console regression: %s tier %d seed %d: pass preview %d HP" % [sample["biome"], sample["tier"], sample["seed"], opening_hp_loss(combat, run["combat_state"])])

static func _golden(expect: Callable) -> void:
	var golden: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/spx03_legacy_golden.json"))
	var generator := Rooms.new()
	for revision: int in [3, 4, 5]:
		for seed: int in range(1, LEGACY_GOLDEN_SEEDS + 1):
			var room: Dictionary = {"type": "combat", "coord": Vector2i(seed % 7, seed % 11), "depth": 1 + seed % 3, "element": "air", "section_index": 0, "section_map_layout_revision": revision, "encounter_biome": "air", "connections": [{"door_dir": Vector2i.UP, "coord": Vector2i(0, -1), "kind": "outward"}]}
			var layout: Dictionary = generator.generate_room(seed, room, Vector2i.UP)
			expect.call(var_to_bytes(layout).hex_encode().sha256_text() == golden[str(revision)][seed - 1], "Pre-change full layout golden revision %d seed %d" % [revision, seed])
			room["section_map_layout_revision"] = 6
			expect.call(Objectives._type_for_room(seed, room) == Objectives.KILL_ALL, "Revision 6 standard always Defeat All")
	for type: String in ["boss", "guardian"]:
		var objective: Dictionary = Objectives.build_for_room(1, {"type": type, "depth": 3, "section_map_layout_revision": 6}, Vector2i.UP)
		expect.call(objective["type"] == Objectives.KILL_LEADER and objective["leader_health_multiplier"] == 1.0 and objective["leader_stoneskin"] == 0, "Authored bosses/guardians keep their objective and stats")
	print("Warband legacy golden seeds: 192 full layouts (revisions 3–5)")

static func battle(biome: String = "air", tier: int = 2) -> Dictionary:
	var run := Run.new()
	return Fixture.build(run, Combat.new(), run.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": biome, "warband_tier": tier})["combat_state"]

static func arena() -> Dictionary:
	var state: Dictionary = battle()
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["illusions"] = []
	state.erase("umbra")
	state["enemies"].resize(3)
	state["enemies"][0]["pos"] = Vector2i(4, 2)
	state["enemies"][1]["pos"] = Vector2i(4, 3)
	state["enemies"][2]["pos"] = Vector2i(1, 1)
	state["player"]["pos"] = Vector2i(4, 4)
	state["player"]["hp"] = TEST_PLAYER_HP
	state["player"]["max_hp"] = TEST_PLAYER_HP
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	return state

static func _command(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = arena()
	var follower: Dictionary = state["enemies"][1]
	var attack: Dictionary = {"type": "melee", "damage": 3}
	follower["intent"] = {"id": "command_test", "name": "Command test", "time": 4, "actions": [attack]}
	var shown: Dictionary = Rules.intent(state, follower, follower["intent"])
	expect.call(shown["actions"][0]["damage"] == 4 and Rules.intent(state, follower, shown) == shown, "Command shown +1 and idempotent")
	var plan: Dictionary = engine.enemy_intent_plan(state, 1)
	expect.call(plan["attack_action"]["damage"] == 4, "Command +1 in planned preview")
	expect.call(engine.enemy_threat_tiles(state, 1)["projected_attack_action"]["damage"] == 4, "Command +1 in threat previews")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 1)
	expect.call(result["state"]["player"]["hp"] == TEST_PLAYER_HP - 4, "Command +1 resolved damage")
	for type: String in ["melee", "ranged", "aoe", "push", "pull"]:
		var action: Dictionary = {"type": type, "damage": 3, "range": 5, "radius": 1}
		var resolved: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 1, action)
		expect.call(resolved["player"]["hp"] == TEST_PLAYER_HP - 4, "Command on damaging " + type)
	follower["pos"] = Vector2i(1, 4)
	expect.call(Rules.intent(state, follower, shown)["actions"][0]["damage"] == 3, "Leaving Command immediately removes bonus")
	follower["pos"] = Vector2i(4, 3)
	state["enemies"][0]["hp"] = 0
	expect.call(Rules.command_bonus(state, follower) == 0, "Dead captain grants no Command")
	expect.call(Rules.action(state, follower, {"type": "push", "damage": 0})["damage"] == 0, "Command never creates a damaging action")
	print("Warband Command: intents, previews, movement boundary and resolved damaging actions checked")

static func _keep_distance(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = arena()
	var path: Array[Vector2i] = Rules.retreat_path(engine, state, state["enemies"][0])
	expect.call(path.size() == 2 and path.back() == Vector2i(4, 1), "Captain steps farthest while keeping screen between")
	state["enemies"][0]["intent"] = {"id": "hold", "name": "Hold", "time": 4, "actions": [{"type": "ranged", "damage": 3, "range": 6}]}
	var plan: Dictionary = engine.enemy_intent_plan(state, 0)
	expect.call(plan["path"][0] == Vector2i(4, 2) and plan["path"][1] == Vector2i(4, 1), "Keep-distance included in preview path")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state, 0)
	expect.call(result["state"]["enemies"][0]["pos"] == Vector2i(4, 1), "Keep-distance step resolves before ordinary action")
	expect.call(result["state"]["player"]["hp"] == TEST_PLAYER_HP - 3, "Normal intent retargets from retreat tile")
	var batch: Dictionary = state.duplicate(true)
	for index: int in range(1, (batch["enemies"] as Array).size()): batch["enemies"][index]["hp"] = 0
	expect.call(engine.resolve_enemy_phase_with_steps(batch)["state"]["enemies"][0]["pos"] == Vector2i(4, 1), "Legacy batch API uses the same keep-distance activation")
	var bleeding: Dictionary = state.duplicate(true)
	bleeding["enemies"][0]["bleed"] = 2
	bleeding["enemies"][0]["stoneskin"] = 0
	bleeding["enemies"][0]["intent"]["actions"] = []
	var bleeding_result: Dictionary = engine.resolve_enemy_turn_with_steps(bleeding, 0)
	expect.call(int(bleeding_result["state"]["enemies"][0]["hp"]) == int(bleeding["enemies"][0]["hp"]) - 2 and (bleeding_result["steps"] as Array).any(func(step: Dictionary) -> bool: return step.get("label", "") == "Bleed"), "The keep-distance movement pays and presents ordinary action Bleed")
	state["grid"][1][4] = "pillar"
	path = Rules.retreat_path(engine, state, state["enemies"][0])
	expect.call(path.size() == 2 and Paths.manhattan(path.back(), state["player"]["pos"]) == 3, "Blocked screen route falls back to farthest legal tile")
	state["enemies"][0]["immobilize"] = true
	result = engine.resolve_enemy_turn_with_steps(state, 0)
	expect.call(result["state"]["enemies"][0]["pos"] == state["enemies"][0]["pos"], "Immobilized captain preserves movement status")
	state = battle("lightning", 3)
	Fixture.stage_keep_distance(state)
	expect.call(Rules.retreat_path(engine, state, state["enemies"][0]).is_empty(), "Dynamo skips keep-distance")
	print("Warband keep-distance: screened, blocked, immobilized and immobile cases checked")

static func _break(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = _break_fixture()
	var follower_kill: Dictionary = engine._damage_enemy(state.duplicate(true), 1, TEST_PLAYER_HP, false, true)
	expect.call(follower_kill["room_embers"] == state["room_embers"], "Individually killed follower drops no Embers")
	var hp_before: int = state["player"]["hp"]
	var after: Dictionary = engine._damage_enemy(state, 0, TEST_PLAYER_HP, false, true)
	expect.call(engine.combat_outcome(after) == "victory", "Captain death wins Warband")
	var fled: int = 0
	for enemy: Dictionary in after["enemies"]:
		expect.call(int(enemy["hp"]) == 0, "All followers removed at break")
		if bool(enemy.get("warband_fled", false)):
			fled += 1
			var path: Array = enemy["warband_flee_path"]
			expect.call(path.size() <= 3 and path[0] == enemy["pos"], "Flee at most two tiles")
			for index: int in range(1, path.size()): expect.call(Paths.manhattan(path[index - 1], path[index]) == 1, "Flee route is contiguous")
			if int(enemy["id"]) == 2:
				expect.call(path.size() == 3 and mini(mini(path.back().x - 1, 7 - path.back().x), mini(path.back().y - 1, 7 - path.back().y)) > 0, "Central follower stops after two tiles before reaching the edge and dissolves")
	expect.call(fled == 5 and after["player"]["hp"] == hp_before, "Ember Ticks flee without bursting")
	expect.call((after.get("death_burst_events", []) as Array).is_empty(), "No Tick death-burst event")
	expect.call((after.get("death_rewards", []) as Array).size() <= 1, "No per-follower break reward")
	var line: String = after["objective"]["break_line"]
	expect.call((after["log"] as Array).count(line) == 1, "Break line occurs once")
	Rules.break_followers(engine, after, 1)
	expect.call((after["log"] as Array).count(line) == 1, "Break is idempotent")
	var batch: Dictionary = _break_fixture()
	batch["_surface_damage_batch"] = true
	for index: int in range(1, (batch["enemies"] as Array).size()):
		if str(batch["enemies"][index]["type"]) in ["ember_tick", "cinder_ooze"]:
			batch = engine._damage_enemy(batch, index, TEST_PLAYER_HP, false, true)
	batch = engine._damage_enemy(batch, 0, TEST_PLAYER_HP, false, true)
	batch["_surface_damage_batch"] = false
	batch = engine._flush_surface_deaths(batch)
	expect.call((batch["enemies"] as Array).size() == 6 and (batch["enemies"] as Array).all(func(enemy: Dictionary) -> bool: return int(enemy["hp"]) == 0), "A simultaneous captain/Ooze kill cannot spawn surviving Droplets")
	expect.call((batch.get("death_burst_events", []) as Array).is_empty() and int(batch["player"]["hp"]) == TEST_PLAYER_HP, "Queued adjacent Tick deaths do not burst after simultaneous captain kill")
	print("Warband break: followers, Tick suppression, no follower Embers and one announcement checked (including batched captain/Tick/Ooze deaths)")

static func _break_fixture() -> Dictionary:
	var state: Dictionary = battle("fire", 3)
	for y: int in range(1, 8):
		for x: int in range(1, 8): state["grid"][y][x] = "stone"
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state.erase("umbra")
	state["player"]["pos"] = Vector2i(4, 5)
	state["player"]["hp"] = TEST_PLAYER_HP
	state["player"]["max_hp"] = TEST_PLAYER_HP
	state["player"]["block"] = 0
	state["player"]["stoneskin"] = 0
	state["enemies"][0]["stoneskin"] = 0
	var positions: Array[Vector2i]
	positions.assign([Vector2i(1, 1), Vector2i(4, 4), Vector2i(7, 3), Vector2i(5, 5), Vector2i(1, 7), Vector2i(7, 7)])
	for index: int in range(positions.size()): state["enemies"][index]["pos"] = positions[index]
	return state

static func _titles(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in Library.definition("warband")["variants"]:
		var state: Dictionary = battle(biome)
		state.erase("umbra")
		var captain: Dictionary = state["enemies"][0]
		var title: String = Library.definition("warband")["variants"][biome]["title"]
		var initial_objective: Dictionary = Objectives.build_for_room(Fixture.FIXTURE_SEED, Fixture.room_spec(biome, 2), Vector2i.UP)
		expect.call(initial_objective["name"] == "Defeat " + Identity.running_name(title) and initial_objective["description"] == Objectives.description_for_objective(initial_objective), "Objective builder owns correct title/tooltip before generation: " + biome)
		expect.call(engine._enemy_display_name(captain) == title, "Instance display title: " + biome)
		expect.call(engine._enemy_actor_entry(state, captain, 0, 0)["name"] == title, "Initiative title: " + biome)
		expect.call(engine.current_turn_order(state, 20).any(func(actor: Dictionary) -> bool: return actor.get("name", "") == title), "Projected turn order title: " + biome)
		expect.call(engine._enemy_intent_step_for_player(state, captain, captain["intent"])["actor_name"] == title, "Action caption title: " + biome)
		expect.call(engine._umbra_marked_enemy_status_step(state, state, {"kind": "status_damage", "actor_key": "enemy_1", "actor_name": "Definition name"}, 1)["actor_name"] == title, "Passive Retaliate/illusion status caption title: " + biome)
		expect.call(Objectives.title_for_objective(state["objective"]) == "Defeat " + Identity.running_name(title), "Objective lowercase the: " + biome)
		expect.call(Objectives.description_for_objective(state["objective"]) == "Kill the captain and the rest flee. Followers within 2 tiles of it deal +1 damage.\nOrder: " + Library.definition("warband")["variants"][biome]["order"]["text"], "Exact Warband tooltip")
		var follower: Dictionary = state["enemies"][1]
		expect.call(Identity.display_name(follower) == Data.enemy_def(str(follower["type"]))["name"], "Other enemies retain definition names")
	print("Warband titles: all six instance, caption, objective and initiative paths checked")

static func _save_load(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var run: Dictionary = Fixture.build(engine, combat, engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": "fire", "warband_tier": 3})
	run["combat_state"] = combat.resolve_enemy_turn_with_steps(run["combat_state"], 1)["state"]
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://spx03-mid-warband.save")
	expect.call(Store.save_run_state(run), "Mid-Warband save writes")
	var loaded: Dictionary = Store.load_saved_run()
	expect.call(loaded["combat_state"] == run["combat_state"], "Mid-Warband save/load exact combat state")
	expect.call(combat.resolve_enemy_turn_with_steps(loaded["combat_state"], 0) == combat.resolve_enemy_turn_with_steps(run["combat_state"], 0), "Mid-Warband resume deterministic")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	print("Warband save/load: exact mid-combat state and deterministic next turn checked")


static func _command_composite_movement(expect: Callable) -> void:
	var engine := Combat.new()
	# Each authored composite crosses the aura boundary inside one action.
	# Compare against the exact same geometry without Command, then assert the
	# independent final-position range and the resolved preview damage.
	for mechanic: String in ["tether_beam", "dive_line", "erupt", "ambush"]:
		for enters: bool in [false, true]:
			var state: Dictionary = arena()
			var enemy: Dictionary = state["enemies"][1]
			var action: Dictionary = {}
			if mechanic == "tether_beam":
				enemy["type"] = "arc_thrall"
				enemy["pos"] = Vector2i(2, 2)
				state["enemies"][2]["pos"] = Vector2i(6, 4)
				state["enemies"][2]["type"] = "arc_thrall"
				state["enemies"][0]["pos"] = Vector2i(2, 6) if enters else Vector2i(2, 1)
				action = {"type": mechanic, "damage": 3, "align_move": 3, "max_length": 6}
				enemy["intent"] = {"actions": [action], "tether_plan": {"partner_id": 3, "path": [Vector2i(2, 2), Vector2i(2, 3), Vector2i(2, 4)]}}
			elif mechanic == "dive_line":
				enemy["type"] = "gust_shrike"
				enemy["pos"] = Vector2i(4, 1)
				state["player"]["pos"] = Vector2i(4, 5)
				state["enemies"][0]["pos"] = Vector2i(2, 4) if enters else Vector2i(2, 1)
				action = {"type": mechanic, "damage": 3, "max_length": 5}
				enemy["intent"] = {"actions": [action]}
			elif mechanic == "erupt":
				enemy["type"] = "burrow_grub"
				enemy["pos"] = Vector2i(2, 2)
				enemy["burrowed"] = true
				enemy["erupt_tile"] = Vector2i(4, 4)
				state["enemies"][0]["pos"] = Vector2i(5, 4) if enters else Vector2i(2, 1)
				action = {"type": mechanic, "damage": 6, "surface": "rubble"}
				enemy["intent"] = {"actions": [action]}
			else:
				enemy["type"] = "veilbound_acolyte"
				enemy["pos"] = Vector2i(2, 2)
				enemy["veiled"] = true
				state["enemies"][0]["pos"] = Vector2i(5, 3) if enters else Vector2i(2, 1)
				action = {"type": "melee", "damage": 3, "ends_veil": true}
				enemy["intent"] = {"actions": [action]}
			var baseline: Dictionary = state.duplicate(true)
			baseline["objective"].erase("special_type")
			baseline = engine._resolve_enemy_action(baseline, 1, action)
			var result: Dictionary = engine._resolve_enemy_action(state.duplicate(true), 1, action)
			var expected: int = 1 if enters else 0
			var damage: int = TEST_PLAYER_HP - int(result["player"]["hp"])
			var base_damage: int = TEST_PLAYER_HP - int(baseline["player"]["hp"])
			expect.call(base_damage > 0, "Composite fixture actually hits: " + mechanic)
			expect.call(damage == base_damage + expected, "Composite Command at hit position (%s enters=%s): %d vs %d" % [mechanic, enters, damage, base_damage + expected])
			var plan: Dictionary = engine.enemy_intent_plan(state, 1)
			expect.call(int(plan.get("attack_action", {}).get("damage", plan.get("projected_attack_action", {}).get("damage", 0))) == int(action["damage"]) + expected, "Composite preview shows resolved Command: " + mechanic)
	print("Warband composite Command: Tether, Dive, Erupt and Ambush enter/leave aura checked")

static func _native_fixture_semantics(expect: Callable) -> void:
	for biome: String in Library.definition("warband")["variants"]:
		for tier: int in [1, 2, 3]:
			var engine := Run.new()
			var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": biome, "warband_tier": tier})
			var room: Dictionary = engine.room_metadata(run, run["current_room"])
			expect.call(room["type"] == "special" and room["special_variant"] == biome and posmod(int(room["depth"]) - 1, 4) + 1 == tier, "Fixture preserves real map topology and requested biome/tier")
	for biome: String in ["air", "lightning"]:
		var tier: int = 2 if biome == "air" else 3
		var state: Dictionary = battle(biome, tier)
		expect.call(state["enemies"].any(func(enemy: Dictionary) -> bool: return (Rules.intent(state, enemy, enemy.get("intent", {})).get("actions", []) as Array).any(func(action: Dictionary) -> bool: return int(action.get("_warband_command_bonus", 0)) > 0)), "Native opening fixture has Command followers: " + biome)
		expect.call(Fixture.stage_keep_distance(state), "Native keep-distance fixture has a legal trigger tile: " + biome)
		var path: Array[Vector2i] = Rules.retreat_path(Combat.new(), state, state["enemies"][0])
		expect.call(path.is_empty() if biome == "lightning" else path.size() == 2, "Native fixture resolves step or immobile skip: " + biome)
	print("Warband native fixture contracts: Stormcaller tier 2 and Dynamo tier 3 checked headless")
