extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Snare = preload("res://scripts/snare_room_rules.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Base = preload("res://tests/suites/snare_suite.gd")
const Wind = preload("res://scripts/enemy_mechanics/wind.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const TEST_GRID_SIZE: int = 9
const TEST_HP: int = 1000
const TEST_POSITIONS: Dictionary = {"entry": Vector2i(1, 4), "hero": Vector2i(4, 4),
	"exits": [Vector2i(7, 4), Vector2i(4, 1), Vector2i(4, 7)], "thralls": [Vector2i(2, 3), Vector2i(6, 3)]}

static func run(expect: Callable) -> void:
	preload("res://tests/suites/element_retrofit_suite.gd").run_pressures(expect)
	_catalog_and_scope(expect)
	_air(expect)
	_ice(expect)
	_shadow(expect)
	_seeded_preview_and_escape(expect)
	_save_and_analytics(expect)
	_analytics_callers(expect)
	_pressure_fixtures(expect)
	print("Snare pressures: six rules, live previews, escapes, persistence and additive analytics checked")

static func battle(biome: String) -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(biome)
	var grid: Array
	for y: int in range(TEST_GRID_SIZE):
		var row: Array
		for x: int in range(TEST_GRID_SIZE): row.append("wall" if x == 0 or y == 0 or x == TEST_GRID_SIZE - 1 or y == TEST_GRID_SIZE - 1 else "floor")
		grid.append(row)
	state["grid"] = grid
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["surface_events"] = []
	state["snare_entry"] = TEST_POSITIONS["entry"]
	state["player"]["pos"] = TEST_POSITIONS["hero"]
	state["player"]["hp"] = TEST_HP
	state["player"]["max_hp"] = TEST_HP
	for index: int in range(3):
		var exit: Dictionary = state["objective"]["exits"][index]
		exit["target_tile"] = TEST_POSITIONS["exits"][index]
		exit["door_tile"] = exit["target_tile"] + [Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN][index]
		exit["map_lane"] = index
		exit["path_tiles"] = combat_path_length(state["snare_entry"], exit["target_tile"])
		state["enemies"][index]["pos"] = Vector2i(index + 2, 6)
	state.erase("snare_pressure")
	Pressure.initialize(engine, state)
	return state

static func combat_path_length(start: Vector2i, finish: Vector2i) -> int:
	return absi(start.x - finish.x) + absi(start.y - finish.y)

static func _catalog_and_scope(expect: Callable) -> void:
	var protected: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/spx-06/pressures.json"))["pressures"]
	for biome: String in protected:
		var state: Dictionary = battle(biome)
		var expected: Dictionary = protected[biome].duplicate(true)
		expected["battlefield_instance"] = "snare_" + biome
		expected["text"] = preload("res://scripts/battlefield_rules/dispatcher.gd").instance_for("snare_" + biome)["sentence"]
		expect.call(Pressure.definition(state) == expected, "Pressure retains non-rule dials: " + biome)
		expect.call(preload("res://scripts/combat_objective_rules.gd").description_for_objective(state["objective"]).ends_with(expected["text"]), "Exact pressure is objective tooltip's last line: " + biome)
		state["objective"].erase("special_type")
		expect.call(Pressure.id(state).is_empty(), "Pressure inactive outside Snare: " + biome)


static func _air(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("air")
	var original: Dictionary = state.duplicate(true)
	var forecast: Dictionary = Pressure.preview(engine, state)["wind_preview"]
	Pressure.resolve(engine, state, 1)
	expect.call(state["player"]["pos"] == Vector2i(3, 4) and state["player"] == forecast["state"]["player"], "Headwind uses real mover preview, toward entry")
	for index: int in [1, 2]: expect.call(state["enemies"][index]["pos"] == original["enemies"][index]["pos"] + Vector2i.LEFT, "Headwind moves unanchored Sealbinders")
	var blocked: Dictionary = original.duplicate(true)
	blocked["enemies"][1]["pos"] = Vector2i(3, 4)
	blocked["enemies"][1]["anchored"] = true
	var blocked_preview: Dictionary = Pressure.preview(engine, blocked)["wind_preview"]
	Pressure.resolve(engine, blocked, 1)
	expect.call(blocked["player"]["pos"] == TEST_POSITIONS["hero"] and int(blocked["player"]["hp"]) == TEST_HP - 2 and blocked["enemies"][1]["pos"] == Vector2i(3, 4), "Headwind collides with an anchored Sealbinder rather than displacing it")
	expect.call(blocked["player"] == blocked_preview["state"]["player"] and blocked["enemies"] == blocked_preview["state"]["enemies"], "Headwind unit-collision preview equals every affected actor outcome")
	state["player"]["pos"] = TEST_POSITIONS["entry"]
	forecast = Pressure.preview(engine, state)["wind_preview"]
	Pressure.resolve(engine, state, 2)
	expect.call(state["player"] == forecast["state"]["player"] and int(state["player"]["hp"]) == TEST_HP - 2 and not forecast["collision_markers"].is_empty(), "Headwind wall collision matches shown damage")
	var steps: Array[Dictionary]
	Wind.complete_turn(engine, state, steps)
	expect.call(state["player"] == forecast["state"]["player"] and steps.is_empty() and Wind.persistent(engine, state, state["wind"]), "Headwind persists and never runs on enemy completions")
	for entry: Vector2i in [Vector2i(7, 4), Vector2i(4, 1), Vector2i(4, 7)]:
		state.erase("snare_pressure")
		state["snare_entry"] = entry
		Pressure.initialize(engine, state)
		expect.call(state["wind"]["direction"] == Vector2i(signi(entry.x - 4), signi(entry.y - 4)), "Room wind points at each physical entry wall")
	print("Snare Headwind: slides, wall collisions, four entry walls, anchored Sealbinders and persistence checked")

static func _ice(expect: Callable) -> void:
	var state: Dictionary = battle("ice")
	expect.call(Pressure.approach_tiles(state) == _tiles([Vector2i(3, 1), Vector2i(3, 7)]), "Ice approach shortest paths break ties by x then y")
	for tile: Vector2i in Pressure.approach_tiles(state): expect.call(Surfaces.element_at(state, tile) == "ice", "Ice placed before first player turn")
	state["objective"]["enemy_round_pending"] = true
	state["objective"]["player_turns_completed"] = 4
	Snare.end_round(state)
	expect.call(Surfaces.element_at(state, Vector2i(3, 1)) == "ice" and Surfaces.element_at(state, Vector2i(3, 7)) == "ice", "Ice remains after sealing")
	state = battle("ice")
	state.erase("snare_pressure")
	state["player"]["pos"] = Vector2i(3, 1)
	Pressure.initialize(Combat.new(), state)
	expect.call(bool(state["player"].get("chilled", false)), "An alternate opening start on threshold Ice receives normal start Chill")
	print("Snare Ice: exact approach tiles, shortest path/x/y ties and post-seal persistence checked")

static func thrall_battle() -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = battle("lightning")
	state["player"]["pos"] = Vector2i(4, 4)
	for tile: Vector2i in TEST_POSITIONS["thralls"]:
		state["enemies"].append(engine._spawned_enemy_entry(state, "arc_thrall", engine._next_enemy_id(state), tile, false))
	var rng := RandomNumberGenerator.new()
	rng.seed = Fixture.FIXTURE_SEED
	for index: int in range(3, state["enemies"].size()): engine._assign_enemy_intent(state, index, rng)
	return state


static func _shadow(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle("shadow")
	state["umbra"]["stage"] = Combat.UMBRA_STAGE_FRINGE
	var initial: int = engine.effective_umbra_radius(state)
	for turn: int in range(1, initial * 2 + 3):
		var expected: int = maxi(1, initial - turn / 2)
		var forecast: Dictionary = Pressure.preview(engine, state, turn)
		var visible_before: Array[Vector2i] = engine.umbra_visible_tiles(state)
		expect.call(forecast["radius"] == expected, "Umbra previews the next radius step")
		Pressure.resolve(engine, state, turn)
		expect.call(engine.effective_umbra_radius(state) == expected, "Umbra shrinks every two turns to radius one")
		var lost: Array[Vector2i]
		for tile: Vector2i in visible_before:
			if not engine.is_tile_visible_to_player(state, tile): lost.append(tile)
		expect.call(forecast["tiles"] == lost, "Umbra marks exactly the sight tiles that will be lost")
	for exit: Dictionary in state["objective"]["exits"]:
		for tile: Vector2i in [exit["target_tile"], exit["door_tile"]]: expect.call(engine.is_tile_visible_to_player(state, tile) and engine.umbra_visible_tiles(state).has(tile), "Doors and thresholds stay visible outside radius")
	for enemy: Dictionary in state["enemies"]:
		if bool(enemy.get("snare_sealbinder", false)): expect.call(engine.is_enemy_visible_to_player(state, enemy), "Sealbinders stay visible outside radius")
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, {"umbra_stage": "fringe", "umbra_visible_tiles": engine.umbra_visible_tiles(state), "visible_enemy_ids": engine.visible_enemy_ids(state)})
	expect.call(board._board_tile_is_visible_to_player(state["objective"]["exits"][0]["door_tile"]), "Renderer exempts exit art from fog")
	board.free()
	state["enemies"][1]["hp"] = 0
	expect.call(not engine.is_tile_visible_to_player(state, state["enemies"][1]["pos"]), "A removed Sealbinder does not permanently reveal its former floor tile")
	state["umbra"]["stage"] = Combat.UMBRA_STAGE_CLEAR
	var clear: Dictionary = Pressure.preview(engine, state, 2)
	Pressure.resolve(engine, state, 2)
	expect.call(clear["radius"] == engine.effective_umbra_radius(state) and clear["tiles"].is_empty(), "Temporary Clear vision retains preview/outcome equality")
	print("Snare Umbra: exact two-turn steps, minimum one, doors/thresholds/Sealbinders and renderer exemptions checked")

static func _seeded_preview_and_escape(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in ["earth", "fire", "air", "ice", "lightning", "shadow"]:
		for seed: int in [0, 83, 199]:
			var state: Dictionary = engine.create_combat(seed, preload("res://scripts/room_generator.gd").new().generate_room(seed, Fixture.room_spec(biome, 2), Vector2i.RIGHT), {"hp": TEST_HP, "max_hp": TEST_HP, "deck_cards": []})
			var before: Dictionary = state.duplicate(true)
			var forecast: Dictionary = Pressure.preview(engine, state)
			var board := preload("res://scripts/combat_board_view.gd").new()
			board.set_combat_state(state)
			expect.call(board.presentation["snare_pressure_preview"] == Pressure.presentation_projection(forecast), "Renderer consumes the exact pressure selector")
			var marked: Array = board.presentation["threats_at_rest"]["threats"].filter(func(threat: Dictionary) -> bool: return str(threat.get("key", "")) == "snare_pressure")
			expect.call(marked.size() == 1 and marked[0]["area"] and marked[0]["tiles"] == forecast["tiles"], "Pressure marks reuse the marked-intent area renderer")
			board.free()
			var ended: Dictionary = engine.finish_player_activation(state)
			expect.call(state == before, "Pressure preview and completion preserve the source state")
			for tile: Vector2i in forecast["tiles"]:
				if biome == "earth": expect.call(engine._terrain_index_at_tile(ended, tile) >= 0, "Seeded Upheaval preview matches player completion")
				elif biome == "fire": expect.call(Surfaces.element_at(ended, tile) == "fire", "Seeded Wildfire preview matches player completion")
			if biome == "air": expect.call(ended["player"] == forecast["wind_preview"]["state"]["player"], "Seeded headwind preview equals player completion")
			var twice: Dictionary = engine.finish_player_activation(ended)
			expect.call(twice == ended, "Pressure never resolves twice at the same boundary")
			state["player"]["pos"] = state["objective"]["exits"][0]["target_tile"]
			expect.call(engine.combat_outcome(state) == "victory" and engine.finish_player_activation(state) == state, "Nothing resolves after escape: " + biome)
			expect.call(Snare.resolve_phase(engine, state)["state"] == state, "Batch Snare API also resolves nothing after escape: " + biome)
	print("Snare pressure preview/outcome/escape: all six variants at seeds 0, 83, 199")

static func _save_and_analytics(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	var previous_storage: String = Store._run_storage_path
	for biome: String in ["earth", "fire", "air", "ice", "lightning", "shadow"]:
		var run: Dictionary = Fixture.build(engine, combat, source, {"snare_biome": biome, "snare_tier": 2})
		run["combat_state"] = combat.advance_to_next_player_turn_with_steps(combat.finish_player_activation(run["combat_state"]))["state"]
		var path: String = "user://spx06-" + biome + ".json"
		Store.set_run_storage_path(path)
		expect.call(Store.save_run_state(run), "Mid-Snare save writes: " + biome)
		var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
		expect.call(loaded["combat_state"]["snare_pressure"] == run["combat_state"]["snare_pressure"] and loaded["combat_state"].get("wind", {}) == run["combat_state"].get("wind", {}), "Pressure state resumes through production repair: " + biome)
		expect.call(Pressure.preview(combat, loaded["combat_state"]) == Pressure.preview(combat, run["combat_state"]), "Resumed pressure preview equals uninterrupted preview: " + biome)
		var scheduled: Dictionary = combat.finish_player_activation(run["combat_state"])
		loaded["combat_state"] = combat.finish_player_activation(loaded["combat_state"])
		expect.call(loaded["combat_state"] == scheduled, "Resumed next pressure outcome equals uninterrupted completion: " + biome)
		run["combat_state"] = scheduled
		expect.call(Store.save_run_state(run), "Pending-pressure enemy round save writes: " + biome)
		loaded = engine.repair_loaded_run_state(Store.load_saved_run())
		expect.call(combat.advance_to_next_player_turn_with_steps(loaded["combat_state"]) == combat.advance_to_next_player_turn_with_steps(scheduled), "Pending pressure resumes once before the enemy round: " + biome)
		scheduled["analytics"] = {"combat_id": "spx06-" + biome}
		var events: Array[Dictionary] = preload("res://scripts/snare_pressure_analytics.gd").records(scheduled, {})
		if biome != "lightning": expect.call(not events.is_empty(), "Pressure changes produce analytics: " + biome)
		for event: Dictionary in events:
			expect.call(event["event_type"] == "snare_pressure" and event["payload"]["id"] == Pressure.id(scheduled) and event["payload"].keys().size() == 3, "Additive exact pressure JSONL payload")
		Store.clear_saved_run()
	Store.set_run_storage_path(previous_storage)
	print("Snare pressure save/load: six mid-Snare states, previews and next outcomes through production repair")

static func _analytics_callers(expect: Callable) -> void:
	var analytics = preload("res://scripts/analytics_store.gd")
	var previous: String = analytics.storage_dir()
	analytics.set_storage_dir("user://spx06-pressure-analytics")
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for biome: String in ["earth", "fire", "air", "ice", "lightning", "shadow"]:
		var run: Dictionary = Fixture.build(engine, combat, source, {"snare_biome": biome})
		var state: Dictionary = thrall_battle() if biome == "lightning" else run["combat_state"]
		if biome == "lightning": Pressure.resolve(combat, state, 1)
		else:
			Pressure.resolve(combat, state, 1)
			Pressure.resolve(combat, state, 2)
		state["analytics"] = {"combat_id": "spx06-analytics-" + biome}
		var expected: int = preload("res://scripts/snare_pressure_analytics.gd").records(state, {}).size()
		expect.call(expected > 0, "Each pressure has a recorded change: " + biome)
		for caller: String in ["UI", "console"]:
			analytics.clear_storage()
			var store = analytics.new()
			var host = preload("res://scripts/run_scene.gd").new() if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
			host.set("_analytics_store", store)
			host.set("_progression", run["progression"].duplicate(true))
			var result: Dictionary = run.duplicate(true)
			result["mode"] = "reward"
			host.set("_run_state", result)
			if caller == "UI":
				host._analytics_flush_surface_events(state)
				host._analytics_flush_surface_events(state)
				host._analytics_log_combat_ended(state, "pressure_test")
			else:
				host._log_combat_transition(run, "pressure_test", state)
				host._log_combat_transition(run, "pressure_test", state)
			var count: int = 0
			var ended: bool = false
			for event: Dictionary in analytics.load_all_events():
				if event["event_type"] == "combat_ended": ended = event["payload"]["snare_pressure"] == Pressure.id(state)
				if event["event_type"] != "snare_pressure": continue
				count += 1
				expect.call(event["payload"]["id"] == Pressure.id(state), "Pressure event carries exact id: " + caller)
				if biome in ["air", "shadow"]: expect.call(event["payload"]["tiles"].is_empty(), "Wind and Umbra analytics tiles are empty")
			expect.call(count == expected and ended, "Both analytics callers emit exactly one event per change and combat_ended id: " + biome + "/" + caller)
			host.free()
	analytics.clear_storage()
	analytics.set_storage_dir(previous)
	print("Snare pressure analytics: six ids, exact payloads, empty wind/Umbra tiles, retry deduplication on UI and console")

static func _pressure_fixtures(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for biome: String in ["earth", "fire", "air", "ice", "lightning", "shadow"]:
		var state: Dictionary = Fixture.build(engine, combat, source, {"snare_biome": biome, "snare_tier": 2, "snare_case": "pressure_turn3"})
		var battle_value: Dictionary = state["combat_state"]
		expect.call(combat.is_player_turn(battle_value) and int(battle_value["objective"]["player_turns_completed"]) == 2, "Fixture reaches real player turn three: " + biome)
		if biome == "shadow":
			var initial: Dictionary = battle_value.duplicate(true)
			initial["snare_pressure"]["radius_loss"] = 0
			expect.call(int(battle_value["snare_pressure"]["radius_loss"]) == 1 and combat.effective_umbra_radius(battle_value) == maxi(1, combat.effective_umbra_radius(initial) - 1), "Fixture shrinks normal Shadow sight before capture")
	print("Snare pressure fixtures: six tier-two seed-83 turn-three states; aligned Thralls and shrunk Shadow sight")

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(values)
	return result
