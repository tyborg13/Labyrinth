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
const RUN_PATH: String = "user://skill_progression_analytics_run.save"
const BLOCKED_RUN_PATH: String = "user://skill_progression_analytics_run_blocked"

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	AnalyticsStore.clear_storage()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	ProgressionStore.clear_saved_run()
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
		"skill_ids": context.get("progression_skills", []),
		"unspent_skill_points_before": 0,
		"unspent_skill_points_after": 1,
		"cost": 540,
		"held_embers_after": 20,
		"room": Vector2i(2, 3),
	}), "Level-up analytics should write successfully")
	_expect(store.write_event("progression_skill_learned", context, {
		"skill_id": "borrowed_time",
		"skill_ids": context.get("progression_skills", []),
		"unspent_skill_points_before": 1,
		"unspent_skill_points_after": 0,
		"room": Vector2i(2, 3),
	}), "Immediate skill-learning analytics should write successfully")
	_expect(store.write_event("progression_skill_reset", context, {
		"skill_ids_before": ["quick_wits", "measured_breath", "borrowed_time"],
		"skill_ids_after": [],
		"skill_points_refunded": 3,
		"unspent_skill_points_after": 3,
		"moltshards_before": 2,
		"moltshards_after": 1,
		"room": Vector2i(2, 3),
	}), "Skill-reset analytics should write successfully")
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
	# Construct this writer before the first append so the regression proves that
	# a live peer invalidates its cached key index when another store writes.
	var concurrent_replay_store: AnalyticsStore = AnalyticsStore.new()
	_expect(store.write_event("skill_triggered", context, trigger_payload, trigger_idempotency_key), "Skill-trigger analytics should write successfully")
	_expect(concurrent_replay_store.write_event("skill_triggered", context, trigger_payload, trigger_idempotency_key), "A concurrently alive analytics store should observe newly appended idempotency keys")
	var replay_store: AnalyticsStore = AnalyticsStore.new()
	var replay_payload: Dictionary = trigger_payload.duplicate(true)
	replay_payload["message"] = "A crash replay must not replace the original event."
	_expect(replay_store.write_event("skill_triggered", context, replay_payload, trigger_idempotency_key), "Replaying an already-written idempotency key should report success")

	var events: Array[Dictionary] = AnalyticsStore.load_all_events()
	_expect(events.size() == 5, "A crash replay should reload only the original five progression events")
	for event: Dictionary in events:
		_expect(event.get("progression_skills", []) == context.get("progression_skills", []), "Every event should retain the learned skill ids in top-level context")
		_expect(int(event.get("moltshards", -1)) == 2, "Every event should retain the Moltshard count in top-level context")
		_expect(event.get("progression_stats", null) == {}, "The retired stat context should remain as an empty compatibility field")

	var level_event: Dictionary = _event_by_type(events, "progression_level_up")
	var level_payload: Dictionary = level_event.get("payload", {}) as Dictionary
	_expect((level_payload.get("skill_ids", []) as Array).size() == 3, "Level-up payloads should include the complete learned set")
	_expect(int(level_payload.get("unspent_skill_points_after", -1)) == 1, "Level-up payloads should identify the newly banked point")
	var room: Dictionary = level_payload.get("room", {}) as Dictionary
	_expect(int(room.get("x", -1)) == 2 and int(room.get("y", -1)) == 3, "Analytics should sanitize the level-up room coordinate")

	var learned_payload: Dictionary = (_event_by_type(events, "progression_skill_learned").get("payload", {}) as Dictionary)
	_expect(str(learned_payload.get("skill_id", "")) == "borrowed_time" and int(learned_payload.get("unspent_skill_points_after", -1)) == 0, "Learning payloads should identify the skill and point spend")
	var reset_payload: Dictionary = (_event_by_type(events, "progression_skill_reset").get("payload", {}) as Dictionary)
	_expect(int(reset_payload.get("moltshards_before", -1)) == 2 and int(reset_payload.get("moltshards_after", -1)) == 1, "Reset payloads should expose the exact resource spend")
	_expect(int(reset_payload.get("skill_points_refunded", -1)) == 3 and int(reset_payload.get("unspent_skill_points_after", -1)) == 3, "Reset payloads should expose the full refunded point total")

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
	_test_combat_skill_outbox_crash_windows()
	_test_defiance_outbox_stages_once()

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
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).size() == 1, "The production boss checkpoint should persist its outbox before touching JSONL")
	_expect(bool(successful_host.call("_reconcile_progression_analytics_outbox")), "The persisted production boss outbox should flush after its gameplay checkpoint")
	successful_host.free()
	var successful_key: String = "progression_moltshard_gained|run:25:seed:73035:first_boss_moltshard"
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), successful_key) == 1, "A successful production checkpoint should append the stable Moltshard event once")
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).is_empty(), "A successful production checkpoint should acknowledge its profile outbox")
	_expect(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Persisting the boss award must not bank the run's held Embers")
	_expect(int(((successful_checkpoint.get("progression", {}) as Dictionary).get("embers", -1))) == 73, "The returned run checkpoint should retain its held Ember balance")

func _test_combat_skill_outbox_crash_windows() -> void:
	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	ProgressionStore.clear_saved_run()
	var progression: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(progression), "Combat-trigger outbox fixture should start from a clean profile")
	var engine: RunEngine = RunEngine.new()
	var entry_run: Dictionary = engine.create_debug_boss_run(progression)
	entry_run["debug_boss_run"] = false
	var entry_combat: Dictionary = (entry_run.get("combat_state", {}) as Dictionary).duplicate(true)
	entry_combat["skill_event_revision"] = 0
	entry_combat["skill_events"] = []
	entry_run["combat_state"] = entry_combat.duplicate(true)
	var previous_entry_run: Dictionary = entry_run.duplicate(true)
	previous_entry_run["mode"] = "room"
	var entry_host: RunScene = RunScene.new()
	entry_host.set("_progression", progression)
	entry_host.set("_run_state", entry_run)
	entry_host.call("_analytics_log_combat_transition", previous_entry_run, "analytics_test", entry_combat)
	var entered_run: Dictionary = entry_host.get("_run_state") as Dictionary
	var entered_combat: Dictionary = entry_host.get("_combat_state") as Dictionary
	var entered_analytics: Dictionary = entered_combat.get("analytics", {}) as Dictionary
	_expect(not str(entered_analytics.get("combat_id", "")).is_empty(), "Normal combat entry should assign a durable combat id")
	_expect(int(entered_analytics.get("combat_skill_event_revision_staged", -1)) == 0, "Normal combat entry should initialize the staged trigger cursor before any skill can fire")
	entered_combat["skill_event_revision"] = 1
	entered_combat["skill_events"] = [{
		"revision": 1,
		"skill_id": "afterimage",
		"turn": int(entered_combat.get("turn", 1)),
		"message": "Afterimage leaves an illusion behind.",
	}]
	var entry_stage: Dictionary = entry_host.call("_stage_combat_skill_event_analytics_for_state", entered_run, entered_combat) as Dictionary
	var entry_staged_run: Dictionary = entry_stage.get("run_state", {}) as Dictionary
	var entry_staged_combat: Dictionary = entry_stage.get("combat_state", {}) as Dictionary
	entry_staged_run = engine.set_combat_state(entry_staged_run, entry_staged_combat)
	_expect(ProgressionStore.progression_analytics_outbox(entry_staged_run.get("progression", {}) as Dictionary).size() == 1, "The first trigger after normal combat entry must enter the durable outbox")
	var entry_key: String = str(entry_host.call("_combat_skill_event_idempotency_key", entry_staged_run, entry_staged_combat, 1, "afterimage"))
	var blocked_run_absolute: String = ProjectSettings.globalize_path(BLOCKED_RUN_PATH)
	DirAccess.remove_absolute(blocked_run_absolute)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % BLOCKED_RUN_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.backup" % BLOCKED_RUN_PATH))
	DirAccess.make_dir_recursive_absolute(blocked_run_absolute)
	ProgressionStore.set_run_storage_path(BLOCKED_RUN_PATH)
	entry_host.set("_run_state", entry_staged_run)
	entry_host.set("_combat_state", entry_staged_combat)
	entry_host.set("_progression", entry_staged_run.get("progression", {}) as Dictionary)
	entry_host.call("_reconcile_skill_event_analytics")
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), entry_key) == 0, "A failed gameplay checkpoint must prevent its combat trigger from reaching JSONL")
	_expect(ProgressionStore.progression_analytics_outbox(entry_host.get("_progression") as Dictionary).size() == 1, "A failed gameplay checkpoint should keep the combat trigger pending in memory")
	DirAccess.remove_absolute(blocked_run_absolute)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.tmp" % BLOCKED_RUN_PATH))
	DirAccess.remove_absolute(ProjectSettings.globalize_path("%s.backup" % BLOCKED_RUN_PATH))
	ProgressionStore.set_run_storage_path(RUN_PATH)
	entry_host.call("_reconcile_skill_event_analytics")
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), entry_key) == 1, "A later successful gameplay checkpoint should append the pending combat trigger exactly once")
	entry_host.free()
	progression = ProgressionStore.normalized_data(progression)
	var run_state: Dictionary = engine.create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["analytics"] = {"run_id": "combat_outbox_run", "combat_counter": 1}
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat_state["analytics"] = {
		"combat_id": "combat_outbox_run_c001",
		"combat_skill_event_revision_staged": 0,
	}
	combat_state["skill_event_revision"] = 1
	combat_state["skill_events"] = [{
		"revision": 1,
		"skill_id": "afterimage",
		"turn": int(combat_state.get("turn", 1)),
		"message": "Afterimage leaves an illusion behind.",
	}]
	run_state["combat_state"] = combat_state.duplicate(true)

	var staging_host: RunScene = RunScene.new()
	staging_host.set("_progression", progression)
	var staged_result: Dictionary = staging_host.call("_stage_combat_skill_event_analytics_for_state", run_state, combat_state) as Dictionary
	var staged_run: Dictionary = staged_result.get("run_state", {}) as Dictionary
	var staged_combat: Dictionary = staged_result.get("combat_state", {}) as Dictionary
	staged_run = engine.set_combat_state(staged_run, staged_combat)
	var first_key: String = str(staging_host.call("_combat_skill_event_idempotency_key", staged_run, staged_combat, 1, "afterimage"))
	var alternate_key: String = str(staging_host.call("_combat_skill_event_idempotency_key", staged_run, staged_combat, 1, "encore"))
	_expect(first_key == "skill_triggered|combat|combat_outbox_run_c001|1|afterimage", "Production combat-trigger keys should use combat id, revision, and skill id")
	_expect(alternate_key != first_key, "Different skills at the same rolled-back revision must not suppress one another")
	_expect(int((staged_combat.get("analytics", {}) as Dictionary).get("combat_skill_event_revision_staged", 0)) == 1, "Staging should advance the combat cursor in the same snapshot as the outbox")
	_expect(ProgressionStore.progression_analytics_outbox(staged_run.get("progression", {}) as Dictionary).size() == 1, "Staging should copy the combat trigger into the durable progression outbox")
	_expect(ProgressionStore.save_run_state(staged_run), "Crash-before-append fixture should persist gameplay and outbox before JSONL")
	staging_host.free()

	var recovered_run: Dictionary = ProgressionStore.load_saved_run()
	var recovered_host: RunScene = RunScene.new()
	recovered_host.set("_progression", recovered_run.get("progression", {}) as Dictionary)
	_expect(bool(recovered_host.call("_reconcile_progression_analytics_outbox")), "Boot recovery should flush a combat trigger staged before a crash")
	recovered_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), first_key) == 1, "Crash-before-append recovery should emit the combat trigger exactly once")

	var append_before_ack_host: RunScene = RunScene.new()
	append_before_ack_host.set("_progression", recovered_run.get("progression", {}) as Dictionary)
	_expect(bool(append_before_ack_host.call("_reconcile_progression_analytics_outbox")), "Replaying the pre-ack run snapshot should succeed idempotently")
	append_before_ack_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), first_key) == 1, "Append-before-ack replay must not duplicate a combat trigger")

	var second_run: Dictionary = engine.create_debug_boss_run(ProgressionStore.load_data())
	second_run["debug_boss_run"] = false
	second_run["analytics"] = {"run_id": "combat_outbox_run", "combat_counter": 2}
	var second_combat: Dictionary = (second_run.get("combat_state", {}) as Dictionary).duplicate(true)
	second_combat["analytics"] = {
		"combat_id": "combat_outbox_run_c002",
		"combat_skill_event_revision_staged": 0,
	}
	second_combat["skill_event_revision"] = 1
	second_combat["skill_events"] = [{
		"revision": 1,
		"skill_id": "makeshift_tool",
		"turn": int(second_combat.get("turn", 1)),
		"message": "Makeshift Tool preserves the item.",
	}]
	var failure_host: RunScene = RunScene.new()
	failure_host.set("_progression", ProgressionStore.load_data())
	var failed_stage: Dictionary = failure_host.call("_stage_combat_skill_event_analytics_for_state", second_run, second_combat) as Dictionary
	var failed_run: Dictionary = failed_stage.get("run_state", {}) as Dictionary
	var failed_combat: Dictionary = failed_stage.get("combat_state", {}) as Dictionary
	failed_run = engine.set_combat_state(failed_run, failed_combat)
	var failed_key: String = str(failure_host.call("_combat_skill_event_idempotency_key", failed_run, failed_combat, 1, "makeshift_tool"))
	_expect(ProgressionStore.save_run_state(failed_run), "Append-failure fixture should persist its staged combat trigger")
	var blocked_absolute_path: String = ProjectSettings.globalize_path(BLOCKED_STORAGE_PATH)
	DirAccess.remove_absolute(blocked_absolute_path)
	var blocker: FileAccess = FileAccess.open(BLOCKED_STORAGE_PATH, FileAccess.WRITE)
	_expect(blocker != null, "Combat append-failure fixture should block the analytics directory")
	if blocker != null:
		blocker.store_string("blocked")
		blocker.close()
	AnalyticsStore.set_storage_dir(BLOCKED_STORAGE_PATH)
	failure_host.set("_progression", failed_run.get("progression", {}) as Dictionary)
	_expect(not bool(failure_host.call("_reconcile_progression_analytics_outbox")), "A combat-trigger append failure should leave the outbox unacknowledged")
	failure_host.free()
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_saved_run().get("progression", {}) as Dictionary).size() == 1, "The persisted run should retain a combat trigger after append failure")

	AnalyticsStore.set_storage_dir(STORAGE_DIR)
	DirAccess.remove_absolute(blocked_absolute_path)
	var retry_run: Dictionary = ProgressionStore.load_saved_run()
	var retry_host: RunScene = RunScene.new()
	retry_host.set("_progression", retry_run.get("progression", {}) as Dictionary)
	_expect(bool(retry_host.call("_reconcile_progression_analytics_outbox")), "A later boot should retry the failed combat-trigger append")
	retry_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), failed_key) == 1, "Append-failure retry should emit the combat trigger exactly once")

	ProgressionStore.clear_saved_run()
	var terminal_progression: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(terminal_progression), "Terminal combat-trigger fixture should reset the profile")
	var terminal_run: Dictionary = engine.create_debug_boss_run(terminal_progression)
	terminal_run["debug_boss_run"] = false
	terminal_run["run_index"] = 26
	terminal_run["seed"] = 73036
	terminal_run["analytics"] = {"run_id": "combat_outbox_terminal", "combat_counter": 1}
	var terminal_rooms: Dictionary = (terminal_run.get("rooms", {}) as Dictionary).duplicate(true)
	var terminal_coord: Vector2i = terminal_run.get("current_room", Vector2i.ZERO)
	var terminal_room_key: String = "%d,%d" % [terminal_coord.x, terminal_coord.y]
	var terminal_room: Dictionary = (terminal_rooms.get(terminal_room_key, {}) as Dictionary).duplicate(true)
	terminal_room["depth"] = 24
	terminal_rooms[terminal_room_key] = terminal_room
	terminal_run["rooms"] = terminal_rooms
	var terminal_combat: Dictionary = (terminal_run.get("combat_state", {}) as Dictionary).duplicate(true)
	terminal_combat["room_depth"] = 24
	terminal_combat["analytics"] = {
		"combat_id": "combat_outbox_terminal_c001",
		"combat_skill_event_revision_staged": 0,
	}
	terminal_combat["skill_event_revision"] = 1
	terminal_combat["skill_events"] = [{
		"revision": 1,
		"skill_id": "afterimage",
		"turn": int(terminal_combat.get("turn", 1)),
		"message": "Afterimage resolves on the final action.",
	}]
	var terminal_enemies: Array = (terminal_combat.get("enemies", []) as Array).duplicate(true)
	for index: int in range(terminal_enemies.size()):
		var enemy: Dictionary = (terminal_enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		terminal_enemies[index] = enemy
	terminal_combat["enemies"] = terminal_enemies
	var terminal_host: RunScene = RunScene.new()
	terminal_host.set("_progression", terminal_progression)
	var terminal_checkpoint: Dictionary = terminal_host.call("_run_state_for_combat_checkpoint", terminal_run, terminal_combat) as Dictionary
	var terminal_key: String = str(terminal_host.call("_combat_skill_event_idempotency_key", terminal_run, terminal_combat, 1, "afterimage"))
	_expect(str(terminal_checkpoint.get("mode", "")) == "victory", "Terminal outbox fixture should reach the final victory boundary")
	terminal_host.call("_hold_committed_run_state", terminal_checkpoint, "terminal_combat_skill_outbox")
	terminal_host.free()
	_expect(not ProgressionStore.has_saved_run(), "A terminal boundary should clear the resumable run")
	var terminal_profile: Dictionary = ProgressionStore.load_data()
	var terminal_pending_keys: Array[String]
	for entry: Dictionary in ProgressionStore.progression_analytics_outbox(terminal_profile):
		terminal_pending_keys.append(str(entry.get("idempotency_key", "")))
	_expect(terminal_pending_keys.has(terminal_key), "Terminal persistence should move the combat trigger into the profile outbox before clearing the run")
	var terminal_retry_host: RunScene = RunScene.new()
	terminal_retry_host.set("_progression", terminal_profile)
	_expect(bool(terminal_retry_host.call("_reconcile_progression_analytics_outbox")), "The next boot should flush a terminal combat trigger from the profile outbox")
	terminal_retry_host.free()
	_expect(_event_count_for_key(AnalyticsStore.load_all_events(), terminal_key) == 1, "Terminal combat-trigger recovery should emit exactly one row")
	_expect(ProgressionStore.progression_analytics_outbox(ProgressionStore.load_data()).is_empty(), "Terminal combat-trigger recovery should durably acknowledge every queued event")

func _test_defiance_outbox_stages_once() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	var engine: RunEngine = RunEngine.new()
	var run_state: Dictionary = engine.create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["analytics"] = {"run_id": "defiance_outbox_run", "combat_counter": 1}
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat_state[RunEngine.DEFIANCE_CAPACITY_KEY] = 2
	combat_state[RunEngine.DEFIANCE_REMAINING_KEY] = 1
	combat_state["analytics"] = {
		"combat_id": "defiance_outbox_run_c001",
		"combat_skill_event_revision_staged": 0,
		"combat_defiance_event_revision_staged": 0,
	}
	combat_state["defiance_event_revision"] = 1
	combat_state["defiance_events"] = [{
		"revision": 1,
		"turn": 4,
		"cause": "enemy_attack",
		"lethal_hp_loss": 3,
		"restored_hp": 6,
		"charges_before": 2,
		"charges_after": 1,
	}]
	run_state["combat_state"] = combat_state.duplicate(true)

	var host: RunScene = RunScene.new()
	host.set("_progression", progression)
	var first_stage: Dictionary = host.call("_stage_combat_skill_event_analytics_for_state", run_state, combat_state) as Dictionary
	var first_run: Dictionary = first_stage.get("run_state", {}) as Dictionary
	var first_combat: Dictionary = first_stage.get("combat_state", {}) as Dictionary
	first_run = engine.set_combat_state(first_run, first_combat)
	var outbox: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(first_run.get("progression", {}) as Dictionary)
	var expected_key: String = "defiance_triggered|combat|defiance_outbox_run_c001|1"
	_expect(outbox.size() == 1, "A Defiance trigger should enter the durable progression outbox")
	if outbox.size() == 1:
		var entry: Dictionary = outbox[0]
		var payload: Dictionary = entry.get("payload", {}) as Dictionary
		_expect(str(entry.get("event_type", "")) == "defiance_triggered" and str(entry.get("idempotency_key", "")) == expected_key, "Defiance analytics should use the revisioned combat idempotency key")
		_expect(int(payload.get("restored_hp", 0)) == 6 and int(payload.get("capacity", 0)) == 2, "Defiance analytics should retain natural-unit restoration and capacity")
		_expect(int(payload.get("combat_unit_scale", 0)) == 1 and str(payload.get("cause", "")) == "enemy_attack", "Defiance analytics should identify natural units and the lethal cause")
	var first_analytics: Dictionary = first_combat.get("analytics", {}) as Dictionary
	_expect(int(first_analytics.get("combat_defiance_event_revision_staged", 0)) == 1, "Staging Defiance should advance its cursor in the same combat snapshot")

	var replay_stage: Dictionary = host.call("_stage_combat_skill_event_analytics_for_state", first_run, first_combat) as Dictionary
	var replay_run: Dictionary = replay_stage.get("run_state", {}) as Dictionary
	var replay_outbox: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(replay_run.get("progression", {}) as Dictionary)
	_expect(replay_outbox.size() == 1 and str(replay_outbox[0].get("idempotency_key", "")) == expected_key, "Re-staging the same Defiance revision must not duplicate its outbox entry")
	_expect(not bool(replay_stage.get("staged", true)), "A fully staged Defiance cursor should report no new analytics work on replay")
	host.free()

func _event_count_for_key(events: Array[Dictionary], idempotency_key: String) -> int:
	var count: int = 0
	for event: Dictionary in events:
		if str(event.get("idempotency_key", "")) == idempotency_key:
			count += 1
	return count

func _remove_profile_fixture() -> void:
	ProgressionStore.clear_saved_run()
	for path: String in [PROGRESSION_PATH, "%s.tmp" % PROGRESSION_PATH, "%s.backup" % PROGRESSION_PATH, RUN_PATH, "%s.tmp" % RUN_PATH, "%s.backup" % RUN_PATH, BLOCKED_RUN_PATH, "%s.tmp" % BLOCKED_RUN_PATH, "%s.backup" % BLOCKED_RUN_PATH]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
