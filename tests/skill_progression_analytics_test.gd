extends SceneTree

const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")

const STORAGE_DIR: String = "user://skill_progression_analytics_test"
const BLOCKED_STORAGE_PATH: String = "user://skill_progression_analytics_blocked"
const BLOCKED_PROGRESSION_PATH: String = "user://skill_progression_analytics_profile_blocked"
const PROGRESSION_PATH: String = "user://skill_progression_analytics_profile.json"

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	AnalyticsStore.clear_storage()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	_expect(ProgressionStore.save_data(ProgressionStore.default_data()), "Moltshard outbox fixture should create a clean profile")

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
		"skill_points_refunded": 3,
		"skill_points_reallocated": 3,
		"replacement_flow": "from_scratch",
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
	var trigger_idempotency_key: String = "skill_triggered|combat|skill_analytics_combat|7|borrowed_time"
	var trigger_payload: Dictionary = {
		"skill_id": "borrowed_time",
		"activation": "automatic",
		"trigger_revision": 7,
		"trigger_scope": "combat",
		"turn": 3,
		"message": "The banked play costs no Time.",
	}
	_expect(store.write_event("skill_triggered", context, trigger_payload, trigger_idempotency_key), "Skill-trigger analytics should write successfully")
	var replay_store: AnalyticsStore = AnalyticsStore.new()
	var replay_payload: Dictionary = trigger_payload.duplicate(true)
	replay_payload["message"] = "A crash replay must not replace the original event."
	_expect(replay_store.write_event("skill_triggered", context, replay_payload, trigger_idempotency_key), "Replaying an already-written idempotency key should report success")

	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	_expect(events.size() == 4, "A crash replay should reload only the original four progression events")
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
	_expect(int(respec_payload.get("skill_points_refunded", -1)) == 3 and int(respec_payload.get("skill_points_reallocated", -1)) == 3, "Respec payloads should expose the full refunded and reallocated point totals")
	_expect(str(respec_payload.get("replacement_flow", "")) == "from_scratch", "Respec payloads should identify the reset-and-rebuild flow")

	var gained_payload: Dictionary = (_event_by_type(events, "progression_moltshard_gained").get("payload", {}) as Dictionary)
	_expect(str(gained_payload.get("source", "")) == "first_boss_victory" and int(gained_payload.get("amount", 0)) == 1, "Currency-gain payloads should retain their idempotent award source")

	var trigger_event: Dictionary = _event_by_type(events, "skill_triggered")
	var stored_trigger_payload: Dictionary = trigger_event.get("payload", {}) as Dictionary
	_expect(str(trigger_event.get("idempotency_key", "")) == trigger_idempotency_key, "Idempotent events should retain their stable replay key at top level")
	_expect(str(stored_trigger_payload.get("skill_id", "")) == "borrowed_time", "Skill-trigger payloads should identify the activated skill")
	_expect(str(stored_trigger_payload.get("activation", "")) == "automatic", "Skill-trigger payloads should distinguish automatic and manual activation")
	_expect(str(stored_trigger_payload.get("trigger_scope", "")) == "combat", "Skill-trigger payloads should identify their combat or run event stream")
	_expect(int(stored_trigger_payload.get("trigger_revision", 0)) == 7 and int(stored_trigger_payload.get("turn", 0)) == 3, "Skill-trigger payloads should retain their de-duplication revision and turn")
	_expect(str(stored_trigger_payload.get("message", "")) == "The banked play costs no Time.", "A duplicate idempotency key should preserve the originally appended event")

	_test_moltshard_outbox_crash_windows(context)
	_test_moltshard_checkpoint_retains_failed_outbox()

	AnalyticsStore.clear_storage()
	_remove_profile_fixture()
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

func _test_moltshard_outbox_crash_windows(context: Dictionary) -> void:
	var first_award_id: String = "run:21:seed:73031:first_boss_moltshard"
	var first_key: String = "progression_moltshard_gained|%s" % first_award_id
	var profile: Dictionary = ProgressionStore.add_moltshard_for_award(ProgressionStore.load_data(), first_award_id)
	profile = ProgressionStore.queue_progression_analytics_event(
		profile,
		"progression_moltshard_gained",
		first_key,
		context,
		{
			"amount": 1,
			"source": "first_boss_victory",
			"moltshards_before": 0,
			"moltshards_after": 1,
		}
	)
	_expect(ProgressionStore.save_data(profile), "The award and its analytics outbox entry should persist atomically before append")

	var blocked_absolute_path: String = ProjectSettings.globalize_path(BLOCKED_STORAGE_PATH)
	DirAccess.remove_absolute(blocked_absolute_path)
	var blocker: FileAccess = FileAccess.open(BLOCKED_STORAGE_PATH, FileAccess.WRITE)
	_expect(blocker != null, "Append-failure fixture should create a file where the analytics directory belongs")
	if blocker != null:
		blocker.store_string("blocked")
		blocker.close()
	AnalyticsStore.set_storage_dir(BLOCKED_STORAGE_PATH)
	var failed_reconcile_host: RunScene = RunScene.new()
	failed_reconcile_host.set("_progression", ProgressionStore.load_data())
	_expect(not bool(failed_reconcile_host.call("_reconcile_progression_analytics_outbox")), "An analytics append failure should report an incomplete reconciliation")
	failed_reconcile_host.free()
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).size() == 1, "An append failure must leave the persisted Moltshard event pending")

	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	DirAccess.remove_absolute(blocked_absolute_path)
	var retry_host: RunScene = RunScene.new()
	retry_host.set("_progression", ProgressionStore.load_data())
	_expect(bool(retry_host.call("_reconcile_progression_analytics_outbox")), "A later boot should retry the pending Moltshard event")
	retry_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), first_key) == 1, "Retrying after an append failure should emit the Moltshard event exactly once")
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).is_empty(), "A successful retry should durably acknowledge the pending event")

	var second_award_id: String = "run:22:seed:73032:first_boss_moltshard"
	var second_key: String = "progression_moltshard_gained|%s" % second_award_id
	profile = ProgressionStore.add_moltshard_for_award(ProgressionStore.load_data(), second_award_id)
	var second_context: Dictionary = context.duplicate(true)
	second_context["run_id"] = "skill_analytics_run_22"
	second_context["moltshards"] = 2
	var second_payload: Dictionary = {
		"amount": 1,
		"source": "first_boss_victory",
		"moltshards_before": 1,
		"moltshards_after": 2,
	}
	profile = ProgressionStore.queue_progression_analytics_event(
		profile,
		"progression_moltshard_gained",
		second_key,
		second_context,
		second_payload
	)
	_expect(ProgressionStore.save_data(profile), "The second award should persist with a pending event before append")
	var append_before_ack_store: AnalyticsStore = AnalyticsStore.new()
	_expect(append_before_ack_store.write_event("progression_moltshard_gained", second_context, second_payload, second_key), "The append-before-ack crash fixture should write the event")
	var append_before_ack_host: RunScene = RunScene.new()
	append_before_ack_host.set("_progression", ProgressionStore.load_data())
	_expect(bool(append_before_ack_host.call("_reconcile_progression_analytics_outbox")), "Replaying after append but before acknowledgement should succeed idempotently")
	append_before_ack_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), second_key) == 1, "Append-before-ack replay must not duplicate the Moltshard event")
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).is_empty(), "Append-before-ack replay should finish the durable acknowledgement")

	var third_award_id: String = "run:23:seed:73033:first_boss_moltshard"
	var third_key: String = "progression_moltshard_gained|%s" % third_award_id
	var persisted_profile: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(persisted_profile), "Held-Ember recovery fixture should persist a zero-Ember profile")
	var active_progression: Dictionary = ProgressionStore.default_data()
	active_progression["embers"] = 73
	active_progression = ProgressionStore.add_moltshard_for_award(active_progression, third_award_id)
	var third_context: Dictionary = context.duplicate(true)
	third_context["run_id"] = "skill_analytics_run_23"
	third_context["moltshards"] = 1
	active_progression = ProgressionStore.queue_progression_analytics_event(
		active_progression,
		"progression_moltshard_gained",
		third_key,
		third_context,
		{
			"amount": 1,
			"source": "first_boss_victory",
			"moltshards_before": 0,
			"moltshards_after": 1,
		}
	)
	var held_ember_host: RunScene = RunScene.new()
	held_ember_host.set("_progression", active_progression)
	_expect(bool(held_ember_host.call("_reconcile_progression_analytics_outbox")), "A recovered embedded outbox should reconcile")
	_expect(int((held_ember_host.get("_progression") as Dictionary).get("embers", -1)) == 73, "Acknowledging analytics should not change the active run's held Embers")
	held_ember_host.free()
	_expect(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Acknowledging a recovered event must not bank held Embers into the profile")
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), third_key) == 1, "The held-Ember recovery event should append exactly once")

func _test_moltshard_checkpoint_retains_failed_outbox() -> void:
	var blocked_absolute_path: String = ProjectSettings.globalize_path(BLOCKED_PROGRESSION_PATH)
	DirAccess.remove_absolute(blocked_absolute_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % BLOCKED_PROGRESSION_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.backup" % BLOCKED_PROGRESSION_PATH))
	DirAccess.make_dir_recursive_absolute(blocked_absolute_path)
	ProgressionStore.set_storage_path(BLOCKED_PROGRESSION_PATH)

	var base_progression: Dictionary = ProgressionStore.default_data()
	var engine: RunEngine = RunEngine.new()
	var base_run: Dictionary = engine.create_debug_boss_run(base_progression)
	base_run["debug_boss_run"] = false
	base_run["run_index"] = 24
	base_run["seed"] = 73034
	var completed_combat: Dictionary = (base_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var enemies: Array = (completed_combat.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	completed_combat["enemies"] = enemies

	var checkpoint_host: RunScene = RunScene.new()
	checkpoint_host.set("_progression", base_progression)
	var first_checkpoint: Dictionary = checkpoint_host.call("_run_state_for_combat_checkpoint", base_run, completed_combat) as Dictionary
	var first_pending: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(first_checkpoint.get("progression", {}) as Dictionary)
	_expect(first_pending.size() == 1, "A failed profile save should leave the real boss-award event in the returned checkpoint")
	var expected_key: String = "progression_moltshard_gained|run:24:seed:73034:first_boss_moltshard"
	if not first_pending.is_empty():
		_expect(str(first_pending[0].get("idempotency_key", "")) == expected_key, "The production checkpoint should use the stable run-result award identity")

	var second_checkpoint: Dictionary = checkpoint_host.call("_run_state_for_combat_checkpoint", base_run, completed_combat) as Dictionary
	var second_pending: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(second_checkpoint.get("progression", {}) as Dictionary)
	_expect(second_pending.size() == 1 and str(second_pending[0].get("idempotency_key", "")) == expected_key, "A second stale-base checkpoint must carry forward the failed outbox at the same progression revision")
	checkpoint_host.free()

	DirAccess.remove_absolute(blocked_absolute_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % BLOCKED_PROGRESSION_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.backup" % BLOCKED_PROGRESSION_PATH))
	ProgressionStore.set_storage_path(PROGRESSION_PATH)

	var banked_profile: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(banked_profile), "Successful boss-award fixture should persist a zero-Ember profile")
	var held_progression: Dictionary = ProgressionStore.default_data()
	held_progression["embers"] = 73
	var successful_run: Dictionary = engine.create_debug_boss_run(held_progression)
	successful_run["debug_boss_run"] = false
	successful_run["run_index"] = 25
	successful_run["seed"] = 73035
	var successful_combat: Dictionary = (successful_run.get("combat_state", {}) as Dictionary).duplicate(true)
	var successful_enemies: Array = (successful_combat.get("enemies", []) as Array).duplicate(true)
	for index: int in range(successful_enemies.size()):
		var enemy: Dictionary = (successful_enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		successful_enemies[index] = enemy
	successful_combat["enemies"] = successful_enemies
	var successful_host: RunScene = RunScene.new()
	successful_host.set("_progression", held_progression)
	var successful_checkpoint: Dictionary = successful_host.call("_run_state_for_combat_checkpoint", successful_run, successful_combat) as Dictionary
	successful_host.free()
	var successful_key: String = "progression_moltshard_gained|run:25:seed:73035:first_boss_moltshard"
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), successful_key) == 1, "A successful production checkpoint should append the stable Moltshard event once")
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).is_empty(), "A successful production checkpoint should acknowledge its profile outbox")
	_expect(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Persisting the boss award must not bank the run's held Embers")
	_expect(int(((successful_checkpoint.get("progression", {}) as Dictionary).get("embers", -1))) == 73, "The returned run checkpoint should retain its held Ember balance")

func _event_count_for_key(events: Array[Dictionary], idempotency_key: String) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if str(event.get("idempotency_key", "")) == idempotency_key:
			count += 1
	return count

func _remove_profile_fixture() -> void:
	for path: String in [PROGRESSION_PATH, "%s.tmp" % PROGRESSION_PATH, "%s.backup" % PROGRESSION_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
