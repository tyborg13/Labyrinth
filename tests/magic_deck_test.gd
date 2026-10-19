extends SceneTree

const Suite = preload("res://tests/suites/magic_deck_suite.gd")
const TEST_RUN_SAVE_PATH: String = "user://magic_deck_migration_roundtrip.save"
var _failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Suite.run(_expect)
	preload("res://tests/suites/magic_purge_presentation.gd").halo_checks(_expect)
	var profile = preload("res://scripts/progression_store.gd")
	profile.set_run_storage_path(TEST_RUN_SAVE_PATH)
	var engine = preload("res://scripts/run_engine.gd").new()
	var legacy: Dictionary = engine.create_new_run(Suite.TEST_SEED, profile.default_data())
	legacy.erase(engine.MAGIC_DECK_SAVE_VERSION_KEY)
	legacy["magic_inventory"] = ["spark_dart", "spark_dart", "frostbolt"]
	_expect(profile.save_run_state(legacy), "Legacy reserve save writes")
	var migrated: Dictionary = engine.repair_loaded_run_state(profile.load_saved_run())
	_expect(migrated["attuned_magic_cards"].size() == 9 and migrated["magic_inventory"].is_empty(), "Real saved reserve cards migrate into deck")
	_expect(profile.save_run_state(migrated), "Migrated save writes its version")
	var reloaded: Dictionary = engine.repair_loaded_run_state(profile.load_saved_run())
	_expect(reloaded["attuned_magic_cards"] == migrated["attuned_magic_cards"] and reloaded[engine.MAGIC_DECK_SAVE_VERSION_KEY] == 1, "Disk save/reload migration is idempotent")
	# Compile the real scene and new modal without opening a window.
	_expect(load("res://scenes/run_scene.tscn") != null, "Run scene compiles")
	_expect(load("res://scripts/magic_purge_overlay.gd") != null, "Purge overlay compiles")
	var purge = preload("res://scripts/magic_purge_overlay.gd")
	_expect(purge.dialog_size_for(4) == Vector2(896, 458), "Four identities fit a centred single-row dialog with the 72px header and 24px badge padding")
	_expect(purge.dialog_size_for(11) == Vector2(1532, 754), "Eleven identities use the director's exact 1532x754 dialog")
	_expect(purge.dialog_size_for(14) == purge.dialog_size_for(20), "Overflow scrolls within the same two-row dialog")
	_expect(purge.dialog_size_for(1).x == 760, "Small decks retain the 760px minimum width")
	print("MAGIC DECK TEST: %s" % ("PASS" if _failures == 0 else "FAIL"))
	print("TEST RESULT: %s" % ("PASS" if _failures == 0 else "FAIL"))
	quit(0 if _failures == 0 else 1)

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures += 1
	push_error(message)
