extends RefCounted

const History = preload("res://scripts/recent_event_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Events = preload("res://scripts/event_rules.gd")
const Fixture = preload("res://tests/suites/event_view_suite.gd")
const HISTORY_PATH: String = "user://evt01_feedback_history.json"
const PROFILE_PATH: String = "user://evt01_feedback_award_profile.json"
const RUN_PATH: String = "user://evt01_feedback_award_run.save"
const BLOCKED_PARENT_PATH: String = "user://evt01_feedback_history_parent_file"
const BANKED_EMBERS: int = 17
const NEXT_RUN_SEED: int = 123
const AWARD_ID: String = "evt01:first_boss_moltshard"

static func run(engine: RefCounted, expect: Callable) -> void:
	var history_path: String = History._storage_path
	var profile_path: String = Store._storage_path
	var run_path: String = Store._run_storage_path
	History.set_storage_path(HISTORY_PATH)
	_files(engine, expect)
	_failed_award(engine, expect)
	History.set_storage_path(history_path)
	Store.set_storage_path(profile_path)
	Store.set_run_storage_path(run_path)

static func _ids(values: Array) -> Array[String]:
	var ids: Array[String]
	ids.assign(values)
	return ids

static func _write(path: String, text: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert(file != null, "History test fixture opens: " + path)
	file.store_string(text)
	file.close()

static func _files(engine: RefCounted, expect: Callable) -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(HISTORY_PATH))
	expect.call(History.load_recent_events().is_empty(), "Missing history reads as empty")
	for source: String in ["invalid json", "[]", "null", '{"recent_events":42}', '{"recent_events":["valid",42]}']:
		_write(HISTORY_PATH, source)
		expect.call(History.load_recent_events().is_empty(), "Corrupt history reads as empty: " + source)
	expect.call(History.save_recent_events(_ids(["bloodletters_basin"])), "History atomically replaces a corrupt file")
	_write(HISTORY_PATH + ".tmp", "interrupted temporary write")
	expect.call(History.load_recent_events() == ["bloodletters_basin"], "An interrupted temp file never replaces the live history")
	expect.call(History.save_recent_events(_ids(["hanged_knight"])) and History.load_recent_events() == ["hanged_knight"], "Atomic rename replaces existing live history")
	expect.call(not FileAccess.file_exists(HISTORY_PATH + ".tmp"), "Successful rename leaves no temp file")
	var many: Array[String]
	for index: int in range(20): many.append("event_%d" % index)
	expect.call(History.save_recent_events(many), "Long history writes")
	var capped: Array[String] = History.load_recent_events()
	expect.call(capped.size() == 16 and capped[0] == "event_4" and capped.back() == "event_19", "Independent history retains the most recent sixteen in order")
	var state: Dictionary = Fixture.fixture("bloodletters_basin", true)
	var result: Dictionary = engine.resolve_map_event(state, "leave")
	var result_bytes: PackedByteArray = var_to_bytes(result)
	_write(BLOCKED_PARENT_PATH, "parent is a file, so history cannot create its directory")
	History.set_storage_path(BLOCKED_PARENT_PATH + "/recent_events.json")
	expect.call(not History.record_resolution(state, result), "A failed history write reports best-effort failure")
	expect.call(History.load_recent_events().is_empty() and var_to_bytes(result) == result_bytes, "History I/O failure never alters the committed state")
	expect.call(engine.resolve_map_event(result, "continue")["mode"] == "room", "History I/O failure never blocks continuation")
	History.set_storage_path(HISTORY_PATH)
	expect.call(History.save_recent_events(_ids([])), "History fixture resets")
	expect.call(History.record_resolution(state, result) and History.load_recent_events() == ["bloodletters_basin"], "The live-flow boundary records a resolved choice")
	expect.call(History.record_resolution(result, result) and History.record_resolution(state, state) and History.record_resolution(result, engine.resolve_map_event(result, "continue")), "Rejected, repeated and Continue requests are harmless")
	expect.call(History.load_recent_events() == ["bloodletters_basin"], "Only the choices-to-result transition appends history")
	var profile: Dictionary = Store.default_data()
	expect.call(not profile.has("recent_events"), "New profiles have no event history")
	profile["recent_events"] = ["retired_profile_history"]
	expect.call(not Store.normalized_data(profile).has("recent_events"), "Retired profile history is discarded without migration or repair")
	expect.call(engine.create_new_run(NEXT_RUN_SEED, profile)["event_memory"] == ["bloodletters_basin"], "New runs snapshot only the independent history file")
	print("Event history file checks: missing/corrupt/atomic/last-16/failure isolation passed")

static func _failed_award(engine: RefCounted, expect: Callable) -> void:
	Store.set_storage_path(PROFILE_PATH)
	Store.set_run_storage_path(RUN_PATH)
	var banked: Dictionary = Store.default_data()
	banked["embers"] = BANKED_EMBERS
	var awarded: Dictionary = Store.add_moltshard_for_award(banked, AWARD_ID)
	var choices: Dictionary = Fixture.fixture("bloodletters_basin", true)
	choices["progression"] = awarded
	var result: Dictionary = engine.resolve_map_event(choices, "leave")
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set("_run_state", result)
	scene.set("_progression", result["progression"].duplicate(true))
	# The run owns the award while the disk profile still predates it, exactly
	# the recoverable state left by a failed award-profile write in the review.
	expect.call(Store.save_data(banked) and Store.save_run_state(result), "Failed-award fixture saves its run with the older disk profile")
	scene.call("_repair_profile_progression_from_run")
	var control: Dictionary = Store.load_data()
	expect.call(Store.moltshard_count(control) == 1, "Control resume repairs the pending Moltshard")
	expect.call(Store.save_data(banked), "Restore the failed award-profile write")
	var profile_before: String = FileAccess.get_file_as_string(PROFILE_PATH)
	var run_before: PackedByteArray = FileAccess.get_file_as_bytes(RUN_PATH)
	expect.call(History.save_recent_events(_ids([])) and History.record_resolution(choices, result), "A subsequent event writes its independent history")
	expect.call(FileAccess.get_file_as_string(PROFILE_PATH) == profile_before and FileAccess.get_file_as_bytes(RUN_PATH) == run_before, "History writes touch neither profile revisions nor run checkpoint bytes")
	scene.call("_repair_profile_progression_from_run")
	var repaired: Dictionary = Store.load_data()
	var next_run: Dictionary = engine.create_new_run(NEXT_RUN_SEED, repaired)
	expect.call(Store.moltshard_count(repaired) == 1 and Store.has_moltshard_award(repaired, AWARD_ID), "Resume repairs the earned Moltshard after the history write")
	expect.call(Store.moltshard_count(next_run["progression"]) == 1, "The next run retains the repaired Moltshard")
	expect.call(int(repaired["embers"]) == BANKED_EMBERS and next_run["event_memory"] == ["bloodletters_basin"], "Award repair preserves the bank and independent rotation memory")
	print("EVT01 FAILED-AWARD RECOVERY: control_shards=%d after_history_shards=%d next_run_shards=%d bank=%d" % [Store.moltshard_count(control), Store.moltshard_count(repaired), Store.moltshard_count(next_run["progression"]), repaired["embers"]])
	scene.free()
