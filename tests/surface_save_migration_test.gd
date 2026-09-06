extends SceneTree

const Migration = preload("res://scripts/surface_save_migration.gd")
const Store = preload("res://scripts/progression_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board: Dictionary = {
		"grid": [[1, 1, 1], [1, 1, 1], [1, 1, 1]],
		"player": {"pos": Vector2i(1, 1), "hp": 9, "max_hp": 24, "block": 3, "burn": 2, "poison": {"damage": 4}, "chilled": 1},
		"enemies": [], "illusions": [], "terrain": [], "traps": [],
		"deck": {"hand": ["bone_dart", "spark"], "draw": ["bone_dart"], "burned": ["cinderfall"]},
		"elemental_intensity": {"fire": 5}, "turn": 3, "initiative_clock": 42,
		"rng_state": 8192, "player_movement_remaining": 1, "current_actor": {"kind": "player"},
		"pending_card_payment": {"card": {"burn": true}, "health_paid": 2},
		"surfaces": {"1,1": {"elemental": "ice", "rubble": true}},
	}
	var old: Dictionary = {"combat_state": board, "surface_rules_version": 0, "seed": 44, "held_embers": 109, "magic_inventory": ["bone_dart", "spark"], "progression": {"embers": 91, "skill_ids": ["prismatic_instinct"]}, "pending_combat_checkpoints": [{"state": board.duplicate(true)}], "log": [{"poison": 3, "card_id": "bone_dart"}]}
	var pristine: Dictionary = old.duplicate(true)
	var migrated: Dictionary = Migration.migrate_run(old, Combat.new())
	var combat: Dictionary = migrated["combat_state"] as Dictionary
	check(old == pristine, "Migration must not mutate its caller's save")
	check(migrated.get("surface_rules_version") == 4 and combat.get("rules_version") == 4, "Both run and combat are versioned")
	check(int(migrated.get("held_embers")) == 109 and int((migrated.get("progression") as Dictionary).get("embers")) == 91, "Run and account resources survive")
	check(int((combat["player"] as Dictionary).get("hp")) == 9 and int((combat["player"] as Dictionary).get("block")) == 3, "Action-boundary health and defense survive")
	check(int(combat.get("initiative_clock")) == 42 and int(combat.get("rng_state")) == 8192 and int(combat.get("player_movement_remaining")) == 1, "Clocks, RNG and partially spent allowance survive")
	check(not combat.has("elemental_intensity") and not (combat["player"] as Dictionary).has("burn") and not (combat["player"] as Dictionary).has("poison"), "Retired combat state is removed")
	check(not (combat["player"] as Dictionary).has("chilled"), "Opening old save never activates contact Chill")
	check(bool(((combat["pending_card_payment"] as Dictionary)["card"] as Dictionary).get("burn")), "Top-level Exhaust flag survives")
	check(((combat["deck"] as Dictionary)["hand"] as Array)[0] == "pale_spark" and (migrated["magic_inventory"] as Array)[0] == "pale_spark", "Retired Bone Dart maps in ownership and piles")
	check((migrated["log"] as Array) == (old["log"] as Array), "Historical evidence remains unchanged")
	check(int((((migrated["pending_combat_checkpoints"] as Array)[0] as Dictionary)["state"] as Dictionary).get("rules_version")) == 4, "Animation continuation boundaries migrate too")
	check(Migration.migrate_run(migrated, Combat.new()) == migrated, "Migration is idempotent")
	var refunds: Dictionary = Store.normalized_data({"embers": 10, "level": 1, "progression_schema": 7, "purchased_upgrades": ["bone_dart_barbed"], "card_upgrades": {"bone_dart": "bone_dart_barbed"}, "card_mods": {"venom_claw": [{"cost_paid": 17}]}})
	check(int(refunds.get("embers")) == 52, "Retired fixed upgrades refund once plus actual paid modifier cost")
	check(Store.normalized_data(refunds) == refunds, "Permanent growth refunds are idempotent")
	_test_archives(old, migrated)
	for failure: String in failures:
		push_error(failure)
	print("Surface migration checks: %s" % ("PASS" if failures.is_empty() else "%d failures" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _test_archives(old: Dictionary, migrated: Dictionary) -> void:
	var root: String = "user://surface_migration_proof"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))
	var run_path: String = root.path_join("legacy_run.save")
	var profile_path: String = root.path_join("legacy_profile.json")
	Store.set_run_storage_path(run_path)
	Store.set_storage_path(profile_path)
	var file: FileAccess = FileAccess.open(run_path, FileAccess.WRITE)
	file.store_var(old, false)
	file.close()
	var run_hash: String = FileAccess.get_sha256(run_path)
	file = FileAccess.open(profile_path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"progression_schema": 7, "level": 1, "embers": 31, "moltshards": 3}))
	file.close()
	var profile_hash: String = FileAccess.get_sha256(profile_path)
	check(Store.save_run_state(migrated), "Migrated run saves successfully")
	check(Store.load_saved_run() == migrated, "Migrated run round trips exact Variant state")
	check(Store.save_data(Store.load_data()), "Profile normalizes and saves")
	var run_archive: String = "%s.pre-surfaces-v4.%s" % [run_path, run_hash.substr(0, 16)]
	var profile_archive: String = "%s.pre-surfaces-v4.%s" % [profile_path, profile_hash.substr(0, 16)]
	check(FileAccess.file_exists(run_archive) and FileAccess.get_sha256(run_archive) == run_hash, "Legacy run archive is byte-exact")
	check(FileAccess.file_exists(profile_archive) and FileAccess.get_sha256(profile_archive) == profile_hash, "Legacy profile archive is byte-exact")
	check(Store.save_run_state(migrated) and Store.save_data(Store.load_data()), "Repeated saves remain valid")
	Store.clear_saved_run()
	check(FileAccess.file_exists(run_archive) and FileAccess.file_exists(profile_archive), "Archives survive subsequent saves and clearing a finished run")
	# An archive failure must prevent overwriting the only old copy.
	file = FileAccess.open(run_path, FileAccess.WRITE)
	file.store_var(old, false)
	file.close()
	file = FileAccess.open(run_archive, FileAccess.WRITE)
	file.store_string("corrupt archive fixture")
	file.close()
	check(not Store.save_run_state(migrated) and FileAccess.get_sha256(run_path) == run_hash, "A conflicting archive prevents legacy save replacement")
	Store.clear_saved_run()
	check(FileAccess.file_exists(run_path), "Archive failure prevents terminal legacy run deletion too")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(run_archive))
	Store.clear_saved_run()
	check(not FileAccess.file_exists(run_path) and FileAccess.get_sha256(run_archive) == run_hash, "Clearing a legacy run directly creates its byte-exact durable archive")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
