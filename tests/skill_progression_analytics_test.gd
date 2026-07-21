extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")

const STORAGE_DIR: String = "user://skill_progression_analytics_test"

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	AnalyticsStore.clear_storage()

	var store: AnalyticsStore = AnalyticsStore.new()
	var context: Dictionary = {
		"run_id": "skill_analytics_run",
		"combat_id": "skill_analytics_combat",
		"turn": 3,
		"progression_level": 4,
		"progression_skills": ["quick_wits", "measured_breath", "borrowed_time"],
		"moltshards": 2,
	}
	_expect(store.write_event("progression_level_up", context, {
		"level_before": 3,
		"level_after": 4,
		"skill_id": "borrowed_time",
		"skill_ids": context.get("progression_skills", []),
		"cost": 540,
		"held_embers_after": 20,
		"room": Vector2i(2, 3),
	}), "Level-up analytics should write successfully")
	_expect(store.write_event("progression_respec", context, {
		"skill_ids_before": ["quick_wits", "measured_breath", "borrowed_time"],
		"skill_ids_after": ["quick_wits", "ghost_stride", "afterimage"],
		"moltshards_before": 2,
		"moltshards_after": 1,
		"room": Vector2i(2, 3),
	}), "Respec analytics should write successfully")
	_expect(store.write_event("progression_moltshard_gained", context, {
		"amount": 1,
		"source": "first_boss_victory",
		"moltshards_before": 1,
		"moltshards_after": 2,
	}), "Moltshard analytics should write successfully")
	_expect(store.write_event("skill_triggered", context, {
		"skill_id": "borrowed_time",
		"activation": "automatic",
		"trigger_revision": 7,
		"trigger_scope": "combat",
		"turn": 3,
		"message": "The banked play costs no Time.",
	}), "Skill-trigger analytics should write successfully")

	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	_expect(events.size() == 4, "The focused analytics fixture should reload all four progression events")
	for event: Dictionary in events:
		_expect(event.get("progression_skills", []) == context.get("progression_skills", []), "Every event should retain the learned skill ids in top-level context")
		_expect(int(event.get("moltshards", -1)) == 2, "Every event should retain the Moltshard count in top-level context")
		_expect(event.get("progression_stats", null) == {}, "The retired stat context should remain as an empty compatibility field")

	var level_event: Dictionary = _event_by_type(events, "progression_level_up")
	var level_payload: Dictionary = level_event.get("payload", {}) as Dictionary
	_expect(str(level_payload.get("skill_id", "")) == "borrowed_time", "Level-up payloads should identify the one learned skill")
	_expect((level_payload.get("skill_ids", []) as Array).size() == 3, "Level-up payloads should include the complete learned set")
	var room: Dictionary = level_payload.get("room", {}) as Dictionary
	_expect(int(room.get("x", -1)) == 2 and int(room.get("y", -1)) == 3, "Analytics should sanitize the level-up room coordinate")

	var respec_payload: Dictionary = (_event_by_type(events, "progression_respec").get("payload", {}) as Dictionary)
	_expect(int(respec_payload.get("moltshards_before", -1)) == 2 and int(respec_payload.get("moltshards_after", -1)) == 1, "Respec payloads should expose the exact resource spend")

	var gained_payload: Dictionary = (_event_by_type(events, "progression_moltshard_gained").get("payload", {}) as Dictionary)
	_expect(str(gained_payload.get("source", "")) == "first_boss_victory" and int(gained_payload.get("amount", 0)) == 1, "Currency-gain payloads should retain their idempotent award source")

	var trigger_payload: Dictionary = (_event_by_type(events, "skill_triggered").get("payload", {}) as Dictionary)
	_expect(str(trigger_payload.get("skill_id", "")) == "borrowed_time", "Skill-trigger payloads should identify the activated skill")
	_expect(str(trigger_payload.get("activation", "")) == "automatic", "Skill-trigger payloads should distinguish automatic and manual activation")
	_expect(str(trigger_payload.get("trigger_scope", "")) == "combat", "Skill-trigger payloads should identify their combat or run event stream")
	_expect(int(trigger_payload.get("trigger_revision", 0)) == 7 and int(trigger_payload.get("turn", 0)) == 3, "Skill-trigger payloads should retain their de-duplication revision and turn")
	_expect(not str(trigger_payload.get("message", "")).is_empty(), "Skill-trigger payloads should retain player-readable feedback")

	AnalyticsStore.clear_storage()
	if _failures.is_empty():
		print("TEST RESULT: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _event_by_type(events: Array[Dictionary], event_type: String) -> Dictionary:
	for event: Dictionary in events:
		if str(event.get("event_type", "")) == event_type:
			return event
	return {}

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
