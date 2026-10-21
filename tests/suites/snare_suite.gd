extends RefCounted
const Rules = preload("res://scripts/snare_room_rules.gd")
const Rooms = preload("res://scripts/room_generator.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Library = preload("res://scripts/special_encounter_library.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Data = preload("res://scripts/game_data.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const MATRIX_SEEDS: int = 200
const TEST_HP: int = 100
const FIRST_TURN_CARD_FIXTURE: Dictionary = {"hand": ["shadow_step", "shadow_step"]}

class BlockedGenerator extends "res://scripts/room_generator.gd":
	var template_attempts: int = 0
	func _apply_template(grid: Array, _rng: RandomNumberGenerator) -> void:
		template_attempts += 1
		for y: int in range(1, grid.size() - 1):
			for x: int in range(1, grid[y].size() - 1): grid[y][x] = "pillar"

static func run(expect: Callable) -> void:
	_matrix(expect)
	_fallback(expect)
	_boundaries(expect)
	_first_turn_card_scope(expect)
	_hunters(expect)
	_rewards_and_save(expect)
	preload("res://tests/suites/warband_suite.gd")._golden(expect)
	print("Snare revision-5 Reach Exit: existing full-layout goldens checked")

static func _matrix(expect: Callable) -> void:
	var generator := Rooms.new()
	var count: int = 0
	for biome: String in Library.definition("umbral_snare")["variants"]:
		for tier: int in [1, 2, 3]:
			for seed: int in range(MATRIX_SEEDS):
				var travel: Vector2i = Paths.DIRS_4[seed % 4]
				var room: Dictionary = Fixture.room_spec(biome, tier)
				room["connections"] = []
				for direction: Vector2i in Paths.DIRS_4:
					if direction == -travel: continue
					room["connections"].append({"door_dir": direction, "coord": Vector2i(1, room["connections"].size()), "kind": "outward"})
				if seed % 2 == 0: room["connections"].pop_back()
				var layout: Dictionary = generator.generate_room(seed, room, travel)
				var exits: Array = layout["objective"]["exits"]
				var context: String = "%s/%d/%d" % [biome, tier, seed]
				var occupied: Dictionary = {layout["player_start"]: true}
				for index: int in range(exits.size()):
					var exit: Dictionary = exits[index]
					var length: int = Paths.find_path(layout["grid"], layout["player_start"], exit["target_tile"]).size() - 1
					expect.call(length >= 5 and length == int(exit["path_tiles"]), "Five-tile path: " + context)
					if index == 0:
						expect.call(exit["role"] == "jailer" and not exit.has("seal_after_player_turns"), "Permanent jailer door: " + context)
					else:
						var previous: Dictionary = exits[index - 1]
						expect.call(length > int(previous["path_tiles"]) or (length == int(previous["path_tiles"]) and int(exit["map_lane"]) > int(previous["map_lane"])), "Shortest path / lower lane ordering: " + context)
						expect.call(int(exit["seal_after_player_turns"]) == (3 if exits.size() == 2 else [2, 4][index - 1]), "Authored seal time: " + context)
						var binder: Dictionary = layout["enemies"][index]
						expect.call(binder["type"] == "veilbound_acolyte" and binder["hp"] == 4 and binder["display_name"] == "Sealbinder" and int(binder["id"]) == int(exit["sealbinder_id"]), "Sealbinder identity: " + context)
						expect.call(Paths.manhattan(binder["pos"], exit["target_tile"]) == 1 and binder["pos"] != exit["door_tile"], "Sealbinder inside beside threshold: " + context)
				var jailer: Dictionary = layout["enemies"][0]
				var path: Array[Vector2i] = Paths.find_path(layout["grid"], layout["player_start"], exits[0]["target_tile"])
				expect.call(jailer["type"] == "chainbound_gaoler" and jailer["display_name"] == "The Umbral Gaoler" and jailer["pos"] == path[path.size() - 2], "Gaoler path placement: " + context)
				expect.call(jailer["hp"] == ceili(generator._scaled_enemy_max_hp("chainbound_gaoler", tier) * 2.0) and jailer["stoneskin"] == tier + 1, "Gaoler authored scaling: " + context)
				for enemy: Dictionary in layout["enemies"]:
					expect.call(not occupied.has(enemy["pos"]) and Paths.is_passable(layout["grid"], enemy["pos"]) and not Paths.find_path(layout["grid"], layout["player_start"], enemy["pos"]).is_empty(), "Free reachable spawn: " + context)
					occupied[enemy["pos"]] = true
					if bool(enemy.get("snare_hunter", false)): expect.call(Paths.manhattan(enemy["pos"], layout["player_start"]) >= 2, "Ice hunter distance: " + context)
				var expected_roster_embers: int = int(Data.enemy_def("chainbound_gaoler")["reward_embers"]) + (exits.size() - 1) * int(Data.enemy_def("veilbound_acolyte")["reward_embers"])
				expect.call(layout["special_starting_reward_embers"] == expected_roster_embers and Library.starting_embers(layout) == expected_roster_embers, "Reward roster excludes starting hunters: " + context)
				var start_count: int = 3 if biome == "ice" else 0
				expect.call(layout["enemies"].size() == exits.size() + start_count and layout["objective"]["hunters_spawned"] == start_count, "Complete roster: " + context)
				count += 1
	print("Snare placement matrix: %d rooms (6 variants × 3 tiers × 200 seeds), 2/3 exits, 4 entries" % count)

static func _fallback(expect: Callable) -> void:
	var generator := BlockedGenerator.new()
	var layout: Dictionary = generator.generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec("ice", 2), Vector2i.RIGHT)
	expect.call(generator.template_attempts == Rules.MAX_PLACEMENT_ATTEMPTS + 1, "Snare exhausts seeded rerolls before deterministic blocker clearing")
	expect.call(layout["enemies"].size() == 6, "Fallback preserves entire ice roster")
	for exit: Dictionary in layout["objective"]["exits"]:
		expect.call(Paths.find_path(layout["grid"], layout["player_start"], exit["target_tile"]).size() - 1 >= 5, "Fallback never relaxes five-tile exit rule")
	print("Snare fallback: seeded retries and complete deterministic formation checked")

static func battle(biome: String = "fire") -> Dictionary:
	return Combat.new().create_combat(Fixture.FIXTURE_SEED, Rooms.new().generate_room(Fixture.FIXTURE_SEED, Fixture.room_spec(biome, 2), Vector2i.RIGHT), {"hp": TEST_HP, "max_hp": TEST_HP, "deck_cards": []})

static func _boundaries(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle()
	var original: Dictionary = state.duplicate(true)
	expect.call(not engine.player_movement_targets(state).any(func(tile: Vector2i) -> bool: return Objectives.exit_target_tiles(state["objective"]).has(tile)), "No exit within first-turn base movement")
	var binder: Dictionary = state["enemies"][1]
	var bonus: int = int(Library.definition("umbral_snare")["bonus"]["amount"])
	expect.call(Rules.seal_intent(state["objective"], binder)["description"] == "Seals its door in 2 turns. Kill it to keep the door open. When you escape, each open door pays %d Embers." % bonus, "Seal tooltip uses plural turns and director bonus data")
	var one_turn: Dictionary = state["objective"].duplicate(true)
	one_turn["player_turns_completed"] = 1
	expect.call(Rules.seal_intent(one_turn, binder)["description"] == "Seals its door in 1 turn. Kill it to keep the door open. When you escape, each open door pays %d Embers." % bonus, "Seal tooltip uses singular turn")
	var binder_pos: Vector2i = state["enemies"][1]["pos"]
	var binder_turn: Dictionary = engine.resolve_enemy_turn_with_steps(state, 1)["state"]
	expect.call(binder_turn["enemies"][1]["pos"] == binder_pos and binder_turn["player"]["hp"] == state["player"]["hp"] and binder_turn["enemies"][1]["intent"]["name"] == "Seal · 2", "Only Seal, no movement or damage")
	var pushed: Dictionary = engine._force_move_enemy_from(state.duplicate(true), 1, {"push": 2}, binder_pos + Vector2i.UP, true, 2)
	expect.call(pushed["enemies"][1]["pos"] == binder_pos, "Sealbinder cannot be displaced")
	for turn: int in range(1, 5):
		state = engine.finish_player_activation(state)
		expect.call(not bool(state["objective"]["exits"][1]["sealed"]) if turn <= 2 else bool(state["objective"]["exits"][1]["sealed"]), "Sealing waits until round end %d" % turn)
		var before_end: Dictionary = state.duplicate(true)
		var result: Dictionary = engine.advance_to_next_player_turn_with_steps(state)
		state = result["state"]
		expect.call(bool(state["objective"]["exits"][1]["sealed"]) == (turn >= 2) and bool(state["objective"]["exits"][2]["sealed"]) == (turn >= 4), "Exact end boundary %d" % turn)
		expect.call(before_end["objective"]["enemy_round_pending"] and not state["objective"]["enemy_round_pending"], "Pending round consumed once")
		expect.call(not bool(state["objective"]["exits"][0]["sealed"]), "Jailer never seals")
	var sealed: Vector2i = state["objective"]["exits"][1]["target_tile"]
	expect.call(not Objectives.exit_target_tiles(state["objective"]).has(sealed) and engine._player_blocking_tiles(state).has(sealed) and engine._enemy_blocking_tiles(state).has(sealed) and engine._force_blocker_at(state, sealed, "player", -1)["kind"] == "wall", "Sealed threshold is blocked for all actors and no longer an exit")
	expect.call(state["enemies"][1]["hp"] == 0 and bool(state["enemies"][1]["snare_dissolved"]) and state["objective"]["sealbinders_killed"] == 0 and (state["death_rewards"] as Array).is_empty(), "Dissolve has no kill or rewards")
	var killed: Dictionary = engine._damage_enemy(original.duplicate(true), 1, 4, true, true, false, false)
	for turn: int in range(4): killed = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(killed))["state"]
	expect.call(not killed["objective"]["exits"][1]["sealed"] and killed["objective"]["exits"][1]["kept_open"] and killed["objective"]["sealbinders_killed"] == 1, "Killed Sealbinder keeps door open through deadline")
	var legacy: Dictionary = engine.resolve_enemy_phase(original)
	legacy = engine.resolve_enemy_phase(legacy)
	expect.call(legacy["objective"]["exits"][1]["sealed"], "Legacy batch API seals at same round boundary")
	var silent: Dictionary = Rules.sound_snapshot(state, {"death_animation_units": [state["enemies"][1]]})
	expect.call(not silent["state"]["enemies"].any(func(enemy: Dictionary) -> bool: return bool(enemy.get("snare_dissolved", false))) and silent["shown"]["death_animation_units"].is_empty(), "Sealing audio snapshot is silent")
	print("Snare seals: exact boundary, permanent kill, immobility, blocked exits, silent dissolve and batch API checked")

# The director allows earned first-turn escape through existing card movement.
static func _first_turn_card_scope(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = battle()
	state["deck"]["hand"] = FIRST_TURN_CARD_FIXTURE["hand"].duplicate()
	var target: Vector2i = Objectives.exit_target_tile_for_direction(Vector2i.RIGHT)
	var midpoint: Vector2i = state["player"]["pos"] + Vector2i.RIGHT * int(Data.card_def("shadow_step")["actions"][0]["range"])
	for tile: Vector2i in [midpoint, target]:
		expect.call(engine.hand_card_has_play_budget(state, 0), "Two existing Shadow Step plays fit the first-turn budget")
		state = engine.prepare_player_card(state, 0)
		for action: Dictionary in engine.card_play_actions("shadow_step", state):
			var needs_target: bool = engine.player_action_needs_target(action)
			if needs_target: expect.call(engine.valid_targets_for_player_action(state, action).has(tile), "First-turn card escape uses legal real-card targets")
			state = engine.apply_player_action(state, action, tile if needs_target else Vector2i(-1, -1))
		state = engine.finish_player_card(state, 0)
	expect.call(state["turn"] == 1 and engine.combat_outcome(state) == "victory", "Existing card movement can earn a first-turn escape")
	print("Snare first turn: free movement cannot escape; two legal Shadow Steps can")

static func _hunters(expect: Callable) -> void:
	var engine := Combat.new()
	for biome: String in Library.definition("umbral_snare")["variants"]:
		var state: Dictionary = battle(biome)
		var types: Array = []
		for turn: int in range(5):
			state = engine.finish_player_activation(state)
			var count: int = 0
			for enemy: Dictionary in state["enemies"]:
				if bool(enemy.get("snare_hunter", false)): count += 1
			expect.call(count == (3 if biome == "ice" else mini(turn + 1, 3)), "Hunter total cap / ice start: %s %d" % [biome, turn])
			if turn == 0 and biome != "ice":
				var hunter: Dictionary = state["enemies"].back()
				expect.call(Paths.manhattan(hunter["pos"], state["snare_entry"]) == 1, "Occupied entry uses nearest free threshold neighbour")
			state = engine.advance_to_next_player_turn_with_steps(state)["state"]
		for enemy: Dictionary in state["enemies"]:
			if bool(enemy.get("snare_hunter", false)): types.append(enemy["type"])
		if biome == "shadow": expect.call(types == ["gloam_stalker", "wick_shade", "gloam_stalker"], "Shadow hunters alternate")
	var killed_hunters: Dictionary = battle()
	killed_hunters["player"]["pos"] += Vector2i.UP * 2
	killed_hunters = engine.finish_player_activation(killed_hunters)
	expect.call(killed_hunters["enemies"].back()["pos"] == killed_hunters["snare_entry"], "Free entry threshold is preferred")
	var hunter_index: int = killed_hunters["enemies"].size() - 1
	killed_hunters = engine._damage_enemy(killed_hunters, hunter_index, TEST_HP, true, true, false, false)
	for turn: int in range(4):
		killed_hunters = engine.advance_to_next_player_turn_with_steps(killed_hunters)["state"]
		killed_hunters = engine.finish_player_activation(killed_hunters)
	expect.call(killed_hunters["objective"]["hunters_spawned"] == 3 and killed_hunters["enemies"].size() == 6, "Killing a hunter never replenishes the total arrival cap")
	print("Snare hunters: all six variants, total cap, alternating list and ice start checked")

static func _rewards_and_save(expect: Callable) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var source: Dictionary = engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data())
	for biome: String in Library.definition("umbral_snare")["variants"]:
		for tier: int in [1, 2, 3]:
			var fixture: Dictionary = Fixture.build(engine, combat, source, {"snare_biome": biome, "snare_tier": tier})
			expect.call(fixture["combat_state"]["objective"]["exits"].size() >= 2, "Natural fixture retains branching route")
	var run: Dictionary = Fixture.build(engine, combat, source, {})
	expect.call(run["combat_state"]["objective"]["exits"].size() == 3, "Fire tier 2 proof has both chips")
	run["combat_state"] = combat.finish_player_activation(run["combat_state"])
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path("user://spx05-mid-snare.save")
	expect.call(Store.save_run_state(run), "Mid-Snare save writes")
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	expect.call(loaded["combat_state"] == run["combat_state"], "Mid-Snare timers / hunters roundtrip exactly")
	expect.call(combat.advance_to_next_player_turn_with_steps(loaded["combat_state"]) == combat.advance_to_next_player_turn_with_steps(run["combat_state"]), "Pending enemy round resumes deterministically")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)
	for open_count: int in [1, 2, 3]:
		var state: Dictionary = Fixture.build(engine, combat, source, {})
		var battle_value: Dictionary = state["combat_state"]
		for index: int in range(open_count, 3): battle_value["objective"]["exits"][index]["sealed"] = true
		Fixture.stage(combat, state, "escape")
		battle_value = state["combat_state"]
		var context: Dictionary = combat.snare_escape_context(battle_value)
		expect.call(combat.combat_outcome(battle_value) == "victory" and context["doors_open_at_escape"] == open_count, "Escape counts used door and all other open doors")
		var defeated: Dictionary = battle_value.duplicate(true)
		defeated["player"]["hp"] = 0
		expect.call(combat.snare_escape_context(defeated)["doors_open_at_escape"] == 0, "Defeat on a threshold is not an escape")
		var result: Dictionary = engine.finish_combat(state, battle_value)
		var room: Dictionary = engine.room_metadata(state, state["current_room"])
		var base: int = Library.reward_embers(room, battle_value)
		expect.call(result["pending_reward"]["ember_amount"] == base + 6 * open_count and result["pending_reward"]["cards"].size() == 4, "Special reward plus per-open-door bonus")
		expect.call((result["pending_reward"]["cards"] as Array).any(func(id: String) -> bool: return Data.card_rarity(id) in ["rare", "epic", "legendary"]), "Snare retains Rare reward floor")
		_analytics(expect, state, battle_value, result, open_count)
		expect.call(result["pending_escape"]["destination"] == battle_value["objective"]["exits"][0]["coord"], "Escape commits used branch")
		expect.call(engine.finish_combat(result, battle_value) == result, "Escape bonus cannot pay twice")
	var kept_run: Dictionary = Fixture.build(engine, combat, source, {})
	kept_run["combat_state"] = combat._damage_enemy(kept_run["combat_state"], 1, 4, true, true, false, false)
	Fixture.stage(combat, kept_run, "escape")
	var kept_result: Dictionary = engine.finish_combat(kept_run, kept_run["combat_state"])
	_analytics(expect, kept_run, kept_run["combat_state"], kept_result, 3, 1)
	_natural_entry(expect, engine, combat, source)
	print("Snare escape/reward/save: all 18 biome/tier fixtures, 1/2/3 open doors and pending-round resume checked")

static func _natural_entry(expect: Callable, engine: RefCounted, combat: RefCounted, source: Dictionary) -> void:
	var run: Dictionary = source.duplicate(true)
	var selected: Dictionary = {}
	for room: Dictionary in run["rooms"].values():
		if room.get("special_type", "") != "umbral_snare": continue
		for parent: Dictionary in run["rooms"].values():
			for link: Dictionary in parent["connections"]:
				if link["coord"] == room["coord"]:
					selected = room
					run["current_room"] = parent["coord"]
					parent["cleared"] = true
					break
		if not selected.is_empty(): break
	expect.call(not selected.is_empty(), "Enabled Snare appears on production map")
	if selected.is_empty(): return
	run["mode"] = "room"
	run = engine.move_to_pre_battle(run, selected["coord"])
	expect.call(run["mode"] == "pre_battle", "Natural Snare uses normal pre-battle entry")
	var prepared: Dictionary = engine.prepare_pre_battle_combat(run)
	expect.call(engine.prepared_pre_battle_matches_input(prepared, run), "Natural Snare prepared layout matches input")
	run = engine.begin_pre_battle_combat(run, prepared)
	expect.call(Rules.active(run["combat_state"]) and run["combat_state"]["objective"]["exits"].size() == selected["connections"].size(), "Natural Snare preserves every outgoing branch")
	Fixture.stage(combat, run, "escape")
	var result: Dictionary = engine.finish_combat(run, run["combat_state"])
	expect.call(result["pending_reward"]["cards"].size() == 4, "Natural Snare escape meets its special goal")

static func _analytics(expect: Callable, run: Dictionary, battle_value: Dictionary, result: Dictionary, open_count: int, expected_kills: int = 0) -> void:
	var previous_dir: String = Analytics.storage_dir()
	Analytics.set_storage_dir("user://spx05-analytics")
	for caller: String in ["UI", "console"]:
		Analytics.clear_storage()
		var store := Analytics.new()
		var host = preload("res://scripts/run_scene.gd").new() if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
		host.set("_analytics_store", store)
		host.set("_progression", run["progression"].duplicate(true))
		host.set("_run_state", result.duplicate(true))
		host.set("_combat_state", {})
		if caller == "UI": host._analytics_log_combat_transition(run, "snare_test", battle_value)
		else: host._log_combat_transition(run, "snare_test", battle_value)
		var records: Array[Dictionary] = Analytics.load_all_events()
		var count: int = 0
		for event: Dictionary in records:
			if event["event_type"] != "combat_ended": continue
			count += 1
			expect.call(int(event["payload"]["doors_open_at_escape"]) == open_count and int(event["payload"]["sealbinders_killed"]) == expected_kills, "Additive Snare analytics fields: " + caller)
		expect.call(count == 1, "Snare emits one existing combat_ended event: " + caller)
		host.free()
	Analytics.clear_storage()
	Analytics.set_storage_dir(previous_dir)
