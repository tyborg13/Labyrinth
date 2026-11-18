extends "res://tools/inspection_fixture.gd"
## Debug-only arrangements, certified by the unchanged fixture/store contract.
const Omens = preload("res://scripts/omen_rules.gd")
const Battlefield = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Difficulty = preload("res://scripts/difficulty_tier_rules.gd")
const FIXTURE_SIZE: int = 9
const FIXTURE_HERO := Vector2i(3, 3)
const FIXTURE_CENTER := Vector2i(4, 3)
const CHAIN_TARGET := Vector2i(5, 3)
const FIRST_SPLIT_TILE := Vector2i(4, 2)
const FIXTURE_HERO_HP: int = 100
const FIXTURE_LETHAL_HP: int = 1
const FIXTURE_PASS_TIME: int = 20
const ROSTER_SEARCH_LIMIT: int = 128

class RosterWitness extends "res://scripts/room_generator.gd":
	var raw_layout: Dictionary = {}
	func _finalize_difficulty(layout: Dictionary) -> void:
		raw_layout = layout.duplicate(true)
		super._finalize_difficulty(layout)

func _build_progression() -> Dictionary:
	return preload("res://scripts/contextual_combat_tutorial.gd").dismiss_tutorial(super._build_progression())

func _build_combat_run(progression: Dictionary) -> Dictionary:
	var run: Dictionary = super._build_combat_run(progression)
	var case_name: String = str(_options["summary"])
	if case_name == "hunted_cap":
		return _roster_run(run)
	if case_name not in ["storm_trap", "storm_chain_spawn"]:
		_fail("Unknown qa-91 fixture: " + case_name)
		return run
	var chain_spawn: bool = case_name == "storm_chain_spawn"
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	var grid: Array = []
	for y: int in range(FIXTURE_SIZE):
		var row: Array = []
		for x: int in range(FIXTURE_SIZE):
			row.append("wall" if x in [0, FIXTURE_SIZE - 1] or y in [0, FIXTURE_SIZE - 1] else "stone")
		grid.append(row)
	layout.merge({"grid": grid, "player_start": FIXTURE_HERO, "terrain": [], "loot": [], "traps": [],
		"objective": {"type": CombatObjectiveRules.KILL_ALL, "initial_enemy_count": 1},
		"enemies": [_enemy(1, "cinder_ooze" if chain_spawn else "crawler", FIXTURE_CENTER)]}, true)
	layout["traps"] = [RoomGenerator.new()._trap_for_tile(FIXTURE_CENTER, "fire", 1)]
	if chain_spawn:
		layout["enemies"].append(_enemy(2, "crawler", CHAIN_TARGET))
		layout["objective"]["initial_enemy_count"] = 2
		for tile: Vector2i in [FIRST_SPLIT_TILE, CHAIN_TARGET]:
			layout["traps"].append(RoomGenerator.new()._trap_for_tile(tile, "earth", 1))
	var snapshot: Dictionary = _run_engine._player_snapshot(run)
	snapshot.merge({"hp": FIXTURE_HERO_HP, "max_hp": FIXTURE_HERO_HP, "deck_cards": ["pale_spark"], "hand_size": 1}, true)
	var state: Dictionary = _combat_engine.create_combat(int(run["seed"]), layout, snapshot)
	state["deck"]["hand"] = ["pale_spark"]
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["umbra"]["radius"] = FIXTURE_SIZE * 2
	BoardSurfaceRules.place(state, FIXTURE_CENTER, "electrified")
	state["turn"] = int(state.get("turn", 1)) + 1
	state["player_turn_time_spent"] = FIXTURE_PASS_TIME
	Battlefield.install(_combat_engine, state, {"rule": "lightning_storm", "source": {"kind": "room"},
		"cadence": {"anchor": "after_player_turn", "every": 1}, "dials": {"damage": FIXTURE_LETHAL_HP, "chain": 1 if chain_spawn else 0},
		"sentence": "QA fixture."})
	run.merge({"current_room_layout": layout, "combat_state": state, "player_hp": FIXTURE_HERO_HP, "player_max_hp": FIXTURE_HERO_HP}, true)
	return run

func _enemy(id: int, type: String, tile: Vector2i) -> Dictionary:
	return {"id": id, "type": type, "pos": tile, "hp": FIXTURE_LETHAL_HP, "max_hp": FIXTURE_LETHAL_HP, "block": 0}

func _roster_run(run: Dictionary) -> Dictionary:
	var generator := RosterWitness.new()
	var room: Dictionary = {"coord": run["current_room"], "depth": 11, "type": "combat", "element": "lightning",
		"section_map_layout_revision": 6, "section_index": 2, "encounter_biome": "shadow", "fight_number": 7,
		"connections": [{"coord": Vector2i(0, 0), "door_dir": Vector2i.LEFT}]}
	var layout: Dictionary = {}
	var selected_seed: int = int(run["seed"])
	for offset: int in range(ROSTER_SEARCH_LIMIT):
		selected_seed = int(run["seed"]) + offset
		layout = generator.generate_room(selected_seed, room, Vector2i.RIGHT)
		var raw_count: int = Difficulty.starter_count(generator.raw_layout)
		if raw_count == Difficulty.MAX_STARTERS: break
		layout = {}
	if layout.is_empty():
		_fail("No natural roster found for hunted_cap")
		return run
	var raw: Dictionary = generator.raw_layout.duplicate(true)
	var base_layout: Dictionary = layout.duplicate(true)
	run = Omens.add(run, "hunted")
	room["omen_extra_enemies"] = Omens.amount(run, "extra_enemies")
	layout = generator.generate_room(selected_seed, room, Vector2i.RIGHT)
	var state: Dictionary = _combat_engine.create_combat(selected_seed, layout, _run_engine._player_snapshot(run))
	run.merge({"current_room_layout": layout, "combat_state": state}, true)
	var room_key: String = "%d,%d" % [run["current_room"].x, run["current_room"].y]
	if run["rooms"].has(room_key): run["rooms"][room_key].merge(room, true)
	run["qa89_roster_witness"] = {"seed": selected_seed, "room": room, "raw": raw, "baseline": base_layout}
	return run
