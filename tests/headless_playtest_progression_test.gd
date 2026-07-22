extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const HeadlessPlaytest = preload("res://tools/headless_playtest.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

var _failures: Array[String]

func _initialize() -> void:
	ProgressionStore.set_storage_path("user://headless_progression_profile.json")
	ProgressionStore.set_run_storage_path("user://headless_progression_run.save")
	AnalyticsStore.set_storage_dir("user://headless_progression_analytics")
	AnalyticsStore.clear_storage()
	_test_level_then_learn_commands()
	if _failures.is_empty():
		print("HEADLESS PLAYTEST PROGRESSION TEST: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("HEADLESS PLAYTEST PROGRESSION TEST: FAIL (%d failures)" % _failures.size())
	quit(1)

func _test_level_then_learn_commands() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	var cost: int = ProgressionStore.next_level_cost(progression)
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(220726, progression)
	run_state["mode"] = "campfire"
	run_state["held_embers"] = cost
	run_state["unbanked_embers"] = cost
	run_state["progression"] = progression.duplicate(true)

	var harness = HeadlessPlaytest.new()
	harness.set("_analytics_store", AnalyticsStore.new())
	harness.set("_notes_path", "user://headless_progression_notes.md")
	harness.set("_progression", progression)
	harness.set("_run_state", run_state)
	harness.call("_command_level_up", PackedStringArray(["level", "quick_wits"]))
	_expect(int((harness.get("_progression") as Dictionary).get("level", 0)) == 1, "The retired level-plus-skill syntax should not mutate progression")
	_expect(str((harness.get("_run_state") as Dictionary).get("mode", "")) == "campfire", "Rejected combined leveling should leave the campfire choice open")

	harness.call("_command_level_up", PackedStringArray(["level"]))
	var leveled: Dictionary = harness.get("_progression") as Dictionary
	_expect(int(leveled.get("level", 0)) == 2, "The level command should purchase exactly one level")
	_expect(ProgressionStore.selected_skill_ids(leveled).is_empty(), "Leveling should not choose a skill")
	_expect(ProgressionStore.unspent_skill_points(leveled) == 1, "Leveling should bank one unspent skill point")
	_expect(str((harness.get("_run_state") as Dictionary).get("mode", "")) == "room", "Successful leveling should preserve the campfire continue flow")

	harness.call("_command_learn", PackedStringArray(["learn", "quick_wits"]))
	var learned: Dictionary = harness.get("_progression") as Dictionary
	_expect(ProgressionStore.selected_skill_ids(learned) == ["quick_wits"], "The independent learn command should commit one legal skill")
	_expect(ProgressionStore.unspent_skill_points(learned) == 0, "Learning should spend exactly one banked point")
	_expect(ProgressionStore.selected_skill_ids((harness.get("_run_state") as Dictionary).get("progression", {})) == ["quick_wits"], "Learning should update the active run snapshot")
	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	_expect(events.size() == 2, "The harness should record separate level-up and skill-learning events")
	if events.size() == 2:
		_expect(str(events[0].get("event_type", "")) == "progression_level_up", "The harness should log leveling before the later skill choice")
		_expect(str(events[1].get("event_type", "")) == "progression_skill_learned", "The harness should log the independent skill choice")
		var level_payload: Dictionary = events[0].get("payload", {}) as Dictionary
		var learn_payload: Dictionary = events[1].get("payload", {}) as Dictionary
		_expect(not level_payload.has("skill_id") and int(level_payload.get("unspent_skill_points_after", -1)) == 1, "Harness level analytics should expose a banked point without implying a skill")
		_expect(str(learn_payload.get("skill_id", "")) == "quick_wits" and int(learn_payload.get("unspent_skill_points_after", -1)) == 0, "Harness learn analytics should expose the later point spend")
	harness.free()

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
