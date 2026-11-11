extends "res://tests/helpers/counted_program.gd"

# This fixture was saved on the unmodified ptf-02 base, before the second
# Hearth. Loading uses the production migration and resume path, never initialize.
const EngineScript = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const FIXTURE: String = "res://tools/ptf02/prechange_run.save"
const FIXTURE_SEED: int = 83
const TEST_SAVE: String = "user://ptf02_saved_map.save"

func _initialize() -> void:
	var engine := EngineScript.new()
	if OS.get_cmdline_user_args().has("--record-prechange"):
		var old: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data())
		for node: Dictionary in old["rooms"].values():
			assert(not (str(node["type"]) == "campfire" and int(node["depth"]) % 4 == 2), "Record only before changing the generator")
		Store.set_run_storage_path(FIXTURE)
		_expect(Store.save_run_state(old), "Pre-change run saved using production serialization")
		_finish("PTF02 PRECHANGE FIXTURE")
		return
	check_saved_map(Callable(self, "_expect"))
	_finish("PTF02 SAVED MAP RESULT")

static func check_saved_map(expect: Callable) -> void:
	var engine := EngineScript.new()
	var previous_save_path: String = Store._run_storage_path
	var file := FileAccess.open(FIXTURE, FileAccess.READ)
	var original: Dictionary = file.get_var(false)
	file.close()
	expect.call(int(original["section_map_layout_revision"]) == 7, "Fixture uses the live pre-change revision")
	Store.set_run_storage_path(TEST_SAVE)
	expect.call(Store.save_run_state(original), "Old run can be written to isolated storage")
	var loaded: Dictionary = Store.load_saved_run()
	expect.call(not loaded.is_empty(), "Production save loader resumes the pre-change run")
	var resumed: Dictionary = engine.repair_loaded_run_state(loaded)
	expect.call(resumed["rooms"] == original["rooms"], "Resume preserves every stored room, connection, type and discovery")
	expect.call(resumed["map_sections"] == original["map_sections"], "Resume preserves all stored section metadata")
	expect.call(Store.save_run_state(resumed), "Resumed run saves again")
	var roundtrip: Dictionary = Store.load_saved_run()
	expect.call(roundtrip["rooms"] == original["rooms"] and roundtrip["map_sections"] == original["map_sections"], "Save/resume round trip never upgrades the old map")
	Store.set_run_storage_path(previous_save_path)
