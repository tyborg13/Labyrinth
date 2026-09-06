extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Migration = preload("res://scripts/surface_save_migration.gd")
const Store = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Scenario = preload("res://scripts/guided_combat_scenario.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_test_legacy_clear_archives()
	_test_legacy_guide_has_no_invisible_gate()
	_test_direct_detonate_shatter_and_passive_exclusion()
	_test_ember_siphon_source_filter()
	_test_tongs_excludes_relic_fire()
	for failure: String in failures:
		push_error(failure)
	print("Surface parent review checks: %s" % ("PASS" if failures.is_empty() else "%d failures" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_legacy_clear_archives() -> void:
	var path: String = "user://surface_review_legacy_clear.save"
	Store.set_run_storage_path(path)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_var({"surface_rules_version": 0, "mode": "victory", "held_embers": 55}, false)
	file.close()
	var digest: String = FileAccess.get_sha256(path)
	Store.clear_saved_run()
	var archive: String = "%s.pre-surfaces-v4.%s" % [path, digest.substr(0, 16)]
	check(FileAccess.file_exists(archive) and FileAccess.get_sha256(archive) == digest, "Clearing an old terminal run before its first migrated save must preserve the exact legacy archive")

func _test_legacy_guide_has_no_invisible_gate() -> void:
	var combat: Combat = Combat.new()
	var board: Dictionary = Base.fixture(combat)
	board["guided_combat_scenario"] = {"version": 1, "player_tile": Vector2i(2, 3), "move_tile": Vector2i(3, 3), "target_tile": Vector2i(4, 3), "preview_card_id": "pale_spark", "kill_card_id": "quick_stab", "refund_card_id": "brace"}
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": 2, "status": "active", "completed_steps": [Tutorial.MILESTONE_MOVE, Tutorial.MILESTONE_INTENT, Tutorial.MILESTONE_PLAYS, Tutorial.MILESTONE_CANCEL, Tutorial.MILESTONE_FIRST_CARD]}
	var migrated: Dictionary = Migration.migrate_run({"mode": "combat", "combat_state": board, "progression": profile}, combat)
	var scene: RunSceneScript = RunSceneScript.new()
	scene.set("_run_state", migrated)
	scene.set("_combat_state", migrated["combat_state"])
	scene.set("_progression", migrated["progression"])
	scene.call("_guided_tutorial_reconcile_phase")
	var phase: String = str(scene.get("_guided_tutorial_phase_id"))
	var restricted: bool = bool(scene.call("_guided_tutorial_action_restricted"))
	var visible: bool = bool(scene.call("_guided_tutorial_phase_displayable", phase))
	check(not restricted or visible, "Resuming a v1 authored fight must not leave an invisible guide restricting abilities, loadout and Grimoire")
	check(int(migrated["combat_state"]["enemies"][0]["hp"]) == int(board["enemies"][0]["hp"]), "Guide compatibility must preserve already-committed enemy HP")
	scene.free()

func _test_direct_detonate_shatter_and_passive_exclusion() -> void:
	var combat: Combat = Combat.new()
	var state: Dictionary = Base.fixture(combat)
	state["relics"] = ["frost_prism"]
	state["enemies"][0]["hp"] = 8
	state["enemies"][0]["freeze"] = 1
	Ground.place(state, Vector2i(4, 3), "fire")
	state = combat.apply_player_action(state, {"type": "detonate", "damage": 4, "range": 5, "element": "fire"}, Vector2i(4, 3))
	check(int(state["enemies"][0]["hp"]) == 0 and Ground.tiles(state, "rubble").size() == 5, "Direct Detonate Frozen kills should retain Shatterglass's direct-attack identity")
	state = Base.fixture(combat)
	state["relics"] = ["frost_prism"]
	state["enemies"][0]["hp"] = 1
	state["enemies"][0]["freeze"] = 1
	Ground.place(state, Vector2i(5, 3), "fire")
	state = combat.apply_player_action(state, {"type": "push", "damage": 0, "amount": 1, "range": 5, "force_direction": Vector2i.RIGHT}, Vector2i(4, 3))
	check(int(state["enemies"][0]["hp"]) == 0 and Ground.tiles(state, "rubble").is_empty(), "An entry Fire kill caused by a push is passive damage and must not activate Shatterglass")

func _test_ember_siphon_source_filter() -> void:
	var combat: Combat = Combat.new()
	var state: Dictionary = Base.fixture(combat)
	state["relics"] = ["ember_siphon"]
	state["player"]["hp"] = 20
	state["player"]["max_hp"] = 24
	state["enemies"][0]["hp"] = 1
	state = combat.apply_player_action(state, {"type": "ranged", "range": 5, "damage": 1, "element": "none"}, Vector2i(4, 3))
	check(int(state["player"]["hp"]) == 20, "Ember Siphon must not reward a neutral direct kill without Fire or Detonate")
	state = Base.fixture(combat)
	state["relics"] = ["ember_siphon"]
	state["player"]["hp"] = 20
	state["player"]["max_hp"] = 24
	state["enemies"][0]["hp"] = 1
	Ground.place(state, Vector2i(4, 3), "fire", {"actor_kind": "player", "card_id": "spark", "player_card": true})
	state = (combat.call("_resolve_enemy_start_of_turn", state, 0) as Dictionary)["state"]
	check(int(state["player"]["hp"]) == 23, "Ember Siphon should heal once when your persistent Fire kills on enemy turn start")
	check(int(state.get("death_bonus_card_plays_this_turn", 0)) == 0, "Causal Fire credit must never turn a passive start death into banked plays")

func _test_tongs_excludes_relic_fire() -> void:
	var combat: Combat = Combat.new()
	var state: Dictionary = Base.fixture(combat)
	state["relics"] = ["cinderbrand_tongs", "phoenix_ember"]
	state["player"]["hp"] = 1
	state["player"]["max_hp"] = 24
	state["defiance_capacity"] = 1
	state["defiance_remaining"] = 1
	Ground.place(state, Vector2i(2, 3), "fire")
	state = combat.apply_player_action(state, {"type": "detonate", "damage": 2, "range": 5, "element": "fire"}, Vector2i(2, 3))
	check(Ground.has_surface(state, Vector2i(4, 3), "fire"), "Tongs source fixture should include Phoenix's actual new Fire during a paid action")
	check(not (state.get("surface_relic_flags", {}) as Dictionary).has("cinderbrand_tongs:surface_creation_reward"), "Relic-created Fire must not spend or recursively trigger Cinderbrand Tongs's player-card creation reward")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
