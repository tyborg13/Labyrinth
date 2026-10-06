extends SceneTree

# Run with a real renderer: this verifies the production frame_post_draw queue.
# A bounded timeout also fails cleanly if invoked with the dummy renderer.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const STORAGE_ROOT: String = "user://deferred_run_skill_analytics_test"

class TestHost:
	extends "res://scripts/run_scene.gd"
	var calls: Array[Dictionary]
	var fail_save_boundary: String = ""
	var fail_append_once: bool = false
	var append_prefix_before_failure: bool = false
	var prefix_append_succeeded: bool = false
	func _ready() -> void:
		set_process(false)
		set_process_input(false)
		set_process_unhandled_input(false)
	func _notification(_what: int) -> void:
		pass
	func _exit_tree() -> void:
		_cancel_deferred_skill_analytics()
	func _persist_run_state_snapshot(state: Dictionary, hold: bool, boundary: String) -> Dictionary:
		var result: Dictionary
		if not fail_save_boundary.is_empty() and boundary == fail_save_boundary:
			fail_save_boundary = ""
			result = {"state": state.duplicate(true), "saved": false}
		else:
			result = super._persist_run_state_snapshot(state, hold, boundary)
		calls.append({
			"kind": "save", "boundary": boundary,
			"frame": Engine.get_process_frames(), "drawn": int(get_meta("draw_count", 0)), "saved": bool(result.get("saved", false)),
			"run_id": str((state.get("analytics", {}) as Dictionary).get("run_id", "")),
			"hp": int(state.get("player_hp", -1)),
		})
		return result
	func _reconcile_run_skill_event_analytics() -> bool:
		var result: bool
		if fail_append_once:
			fail_append_once = false
			if append_prefix_before_failure:
				var event: Dictionary = _run_engine.run_skill_events(_run_state)[0]
				var skill_id: String = str(event.get("skill_id", ""))
				prefix_append_succeeded = _analytics_store.write_event("skill_triggered", _analytics_context_from_states(_run_state, _combat_state), {"skill_id": skill_id, "trigger_scope": "run"}, _run_skill_event_idempotency_key(_run_state, int(event.get("revision", 0)), skill_id))
			result = false
		else:
			result = super._reconcile_run_skill_event_analytics()
		calls.append({"kind": "append", "frame": Engine.get_process_frames(), "saved": result,
			"disk_revision": int((ProgressionStore.load_saved_run().get("skill_state", {}) as Dictionary).get("event_revision", 0)),
			"disk_cursor": int((ProgressionStore.load_saved_run().get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", 0))})
		return result

class RenderPulse:
	extends Control
	var tick: bool = false
	func pulse() -> void:
		tick = not tick
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, Vector2.ONE), Color.WHITE if tick else Color.BLACK)

var _host: TestHost
var _pulse: RenderPulse
var _checks: int = 0
var _errors: Array[String]
var _results: Array[Dictionary]
var _finished: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)
	OS.low_processor_usage_mode = false
	create_timer(20.0).timeout.connect(_timed_out)
	call_deferred("_run")

func _run() -> void:
	_pulse = RenderPulse.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pulse)
	_set_namespace("boot")
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	instance.set_script(TestHost)
	_host = instance as TestHost
	root.add_child(_host)
	RenderingServer.frame_post_draw.connect(func() -> void:
		if is_instance_valid(_host): _host.set_meta("draw_count", int(_host.get_meta("draw_count", 0)) + 1)
	)
	await _frames(1)
	await _test_order_and_coalescing()
	await _test_latest_authoritative_state()
	await _test_owned_event_context()
	await _test_bounded_context_history()
	await _test_save_failure()
	await _test_append_failure(false)
	await _test_append_failure(true)
	await _test_cursor_failure_and_replay()
	await _test_explicit_save()
	await _test_held_newer_event()
	await _test_namespace()
	await _test_invalidation()
	await _test_checkpoint_after_last_refresh()
	await _test_terminal()
	_configure("freed_owner")
	_host.call("_request_run_skill_event_analytics")
	_host.queue_free()
	await _frames(3)
	_expect(not ProgressionStore.has_saved_run() and _event_count() == 0, "scene exit cancels the sleeping callback")
	_record_case("freed_owner")
	_finish()

func _test_order_and_coalescing() -> void:
	_configure("ordered")
	var frame: int = int(_host.get_meta("draw_count", 0))
	for index: int in range(5): _host.call("_request_run_skill_event_analytics")
	_expect(_host.calls.is_empty() and not ProgressionStore.has_saved_run() and _event_count() == 0, "request has no synchronous save or append")
	await _frames(2)
	_expect(_host.calls.size() == 3 and _boundaries() == _strings(["hud_run_skill_outbox", "hud_run_skill_cursor"]), "coalesced HUD requests run the original ordered protocol once")
	_expect(str(_host.calls[1]["kind"]) == "append" and int(_host.calls[1]["disk_revision"]) == 1 and int(_host.calls[1]["disk_cursor"]) == 0, "the complete outbox is durable before append, and the cursor waits")
	_expect(int(_host.calls[0]["drawn"]) > frame and int(_host.calls[2]["drawn"]) > frame, "analytics work crosses a real rendered frame")
	_expect(_event_count() == 1 and _disk_cursor() == 1 and not _busy(), "successful drain appends once and persists the cursor")
	_record_case("ordered")

func _test_latest_authoritative_state() -> void:
	_configure("latest")
	_host.call("_request_run_skill_event_analytics")
	_host.set("_animation_lock", true)
	await _frames(2)
	_expect(_host.calls.is_empty(), "presentation lock pauses all analytics I/O")
	var latest: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	latest["player_hp"] = 3
	var skills: Dictionary = (latest.get("skill_state", {}) as Dictionary).duplicate(true)
	(skills["events"] as Array).append({"revision": 2, "skill_id": "deferred_choice", "message": "Another action."})
	skills["event_revision"] = 2
	latest["skill_state"] = skills
	_host.set("_run_state", latest)
	_host.call("_request_run_skill_event_analytics")
	_host.set("_animation_lock", false)
	_host.set("_committed_run_state_override", latest.duplicate(true))
	await _frames(2)
	_expect(_host.calls.is_empty(), "held authoritative snapshot pauses the queue")
	_host.set("_committed_run_state_override", {})
	await _frames(2)
	_expect(_event_count() == 2 and _disk_cursor() == 2 and int(ProgressionStore.load_saved_run().get("player_hp", 0)) == 3, "resume uses newest HP and both revisions without a kept stale snapshot")
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) != "skill_triggered": continue
		var expected_hp: int = 9 if str((event.get("payload", {}) as Dictionary).get("skill_id", "")) == "discerning_eye" else 3
		_expect(int(event.get("player_hp", -1)) == expected_hp, "a following action preserves each trigger's request-time HP attribution")
	_record_case("latest")

func _test_owned_event_context() -> void:
	_configure("owned_context")
	var engine := RunEngine.new()
	var combat: Dictionary = (engine.create_debug_boss_run(_host.get("_progression") as Dictionary).get("combat_state", {}) as Dictionary).duplicate(true)
	combat["turn"] = 4
	(combat["player"] as Dictionary)["hp"] = 9
	combat["balance_transition"] = {"values": [1]}
	_host.set("_combat_state", combat)
	_host.call("_request_run_skill_event_analytics")
	combat["turn"] = 5
	(combat["player"] as Dictionary)["hp"] = 3
	((combat["balance_transition"] as Dictionary)["values"] as Array).append(2)
	await _frames(2)
	var event: Dictionary = {}
	for record: Dictionary in AnalyticsStore.load_all_events():
		if str(record.get("event_type", "")) == "skill_triggered": event = record
	_expect(int(event.get("player_hp", -1)) == 9 and int(event.get("turn", -1)) == 4 and int((event.get("payload", {}) as Dictionary).get("turn", -1)) == 4, "context and payload retain the original HP and turn despite mutable following presentation")
	_expect(((event.get("balance_transition", {}) as Dictionary).get("values", []) as Array).size() == 1, "nested cached attribution owns its data")
	_record_case("owned_context")

func _test_bounded_context_history() -> void:
	_configure("bounded_history")
	_host.set("_animation_lock", true)
	var state: Dictionary = _host.get("_run_state") as Dictionary
	var skills: Dictionary = {"event_revision": 0, "events": []}
	state["skill_state"] = skills
	for index: int in range(60):
		(skills["events"] as Array).append({"revision": index + 1, "skill_id": "true_bearing", "message": "Entry %d" % index})
		skills["event_revision"] = index + 1
		state["player_hp"] = index + 1
		_host.call("_request_run_skill_event_analytics")
	var engine := RunEngine.new()
	var actual_pending: Array[Dictionary] = engine.run_skill_events(state)
	_expect(actual_pending.size() == 48 and (_host.get("_run_skill_event_contexts") as Dictionary).size() == actual_pending.size(), "failed/paused writes keep attribution bounded to the engine's actual pending history")
	_host.set("_animation_lock", false)
	await _frames(2)
	_expect(_event_count() == actual_pending.size() and _disk_cursor() == 60, "drain enumerates only surviving authoritative events")
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) != "skill_triggered": continue
		var revision: int = int((event.get("payload", {}) as Dictionary).get("trigger_revision", 0))
		_expect(int(event.get("player_hp", -1)) == revision, "surviving contexts retain their first capture through history pruning")
	_record_case("bounded_history")

func _test_save_failure() -> void:
	_configure("failed_outbox")
	_host.fail_save_boundary = "hud_run_skill_outbox"
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 0 and not ProgressionStore.has_saved_run() and not _busy(), "failed outbox save stops without append or acknowledgment")
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 1 and _disk_cursor() == 1, "a later HUD request retries successfully")
	_record_case("failed_outbox")

func _test_append_failure(partial: bool) -> void:
	var label: String = "partial_append" if partial else "failed_append"
	_configure(label)
	_host.fail_append_once = true
	_host.append_prefix_before_failure = partial
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_disk_cursor() == 0 and int((ProgressionStore.load_saved_run().get("skill_state", {}) as Dictionary).get("event_revision", 0)) == 1, label + ": failure leaves a replayable durable outbox")
	_expect(_event_count() == (1 if partial else 0), label + ": only successful appends exist")
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 1 and _disk_cursor() == 1 and not _busy(), label + ": retry deduplicates stable trigger keys and acknowledges")
	_record_case(label)

func _test_cursor_failure_and_replay() -> void:
	_configure("failed_cursor")
	_host.fail_save_boundary = "hud_run_skill_cursor"
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 1 and _disk_cursor() == 0, "failed cursor save preserves append-before-ack replay state")
	_host.set("_run_state", ProgressionStore.load_saved_run())
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 1 and _disk_cursor() == 1, "crash replay after a failed cursor write cannot duplicate JSONL")
	_record_case("failed_cursor")

func _test_explicit_save() -> void:
	_configure("explicit_save")
	_host.call("_request_run_skill_event_analytics")
	_host.set("_animation_lock", true)
	var state: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	state["player_hp"] = 4
	_host.set("_run_state", state)
	_host.set("_committed_run_state_override", state.duplicate(true))
	_host.call("_save_run_progress")
	_expect(_event_count() == 1 and _disk_cursor() == 1 and int(ProgressionStore.load_saved_run().get("player_hp", 0)) == 4, "explicit Save & Quit flushes the trigger and saves the held newest HP")
	var call_count: int = _host.calls.size()
	await _frames(3)
	_expect(not _busy() and _host.calls.size() == call_count, "explicit save cancels the old sleeping request")
	_record_case("explicit_save")

func _test_namespace() -> void:
	for kind: String in ["run", "profile", "analytics", "run_identity"]:
		_configure("namespace_" + kind)
		_host.call("_request_run_skill_event_analytics")
		var path: String = STORAGE_ROOT.path_join("replacement_" + kind)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path))
		match kind:
			"run": ProgressionStore.set_run_storage_path(path.path_join("run.save"))
			"profile": ProgressionStore.set_storage_path(path.path_join("profile.json"))
			"analytics": AnalyticsStore.set_storage_dir(path.path_join("analytics"))
			"run_identity":
				var state: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
				state["analytics"] = {"run_id": "different_run"}
				_host.set("_run_state", state)
		await _frames(2)
		_expect(_host.calls.is_empty() and _event_count() == 0 and not _busy(), kind + ": changed scope cancels the old request without writing")
		_record_case("namespace_" + kind)

func _test_held_newer_event() -> void:
	_configure("held_newer")
	_host.call("_request_run_skill_event_analytics")
	var latest: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	latest["player_hp"] = 4
	var skills: Dictionary = (latest.get("skill_state", {}) as Dictionary).duplicate(true)
	(skills["events"] as Array).append({"revision": 2, "skill_id": "deferred_choice", "message": "Held action."})
	skills["event_revision"] = 2
	latest["skill_state"] = skills
	_host.set("_committed_run_state_override", latest)
	_host.set("_animation_lock", true)
	_host.call("_save_run_progress")
	_expect(_event_count() == 1 and _disk_cursor() == 1 and int((ProgressionStore.load_saved_run().get("skill_state", {}) as Dictionary).get("event_revision", 0)) == 2, "explicit save keeps a newer held trigger replayable without adopting its gameplay into the live display")
	_expect(int(ProgressionStore.load_saved_run().get("player_hp", 0)) == 4, "the held checkpoint remains authoritative for explicit persistence")
	await _frames(2)
	_expect(_event_count() == 1 and not _busy(), "the canceled queue does not later append against the old live display")
	_host.set("_run_state", ProgressionStore.load_saved_run())
	_host.set("_committed_run_state_override", {})
	_host.set("_animation_lock", false)
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_event_count() == 2 and _disk_cursor() == 2, "the held trigger replays once after the authoritative checkpoint becomes live")
	_record_case("held_newer")

func _test_invalidation() -> void:
	_configure("invalidated")
	_host.call("_request_run_skill_event_analytics")
	_host.call("_cancel_deferred_skill_analytics")
	await _frames(2)
	_expect(_host.calls.is_empty() and _event_count() == 0 and not _busy(), "load/new-run/abandon cancellation invalidates pending work")
	_record_case("invalidated")

func _test_checkpoint_after_last_refresh() -> void:
	_configure("last_refresh_before_checkpoint")
	_host.set("_animation_lock", true)
	_host.call("_request_run_skill_event_analytics")
	await _frames(2)
	_expect(_host.calls.is_empty(), "reveal-style presentation waits for unlock")
	_host.set("_animation_lock", false)
	_host.call("_persist_committed_boundary", "reward_intro_complete")
	var count_before: int = _host.calls.size()
	await _frames(2)
	_expect(_event_count() == 1 and _disk_cursor() == 1 and _host.calls.size() == count_before + 3 and not _busy(), "a final checkpoint after the last HUD refresh still drains while the player idles")
	_record_case("last_refresh_before_checkpoint")

func _test_terminal() -> void:
	_configure("terminal")
	var state: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	state["mode"] = "victory"
	_host.set("_run_state", state)
	_host.call("_request_run_skill_event_analytics")
	_expect(_event_count() == 1 and not _busy(), "terminal HUD keeps the original synchronous analytics protocol")
	_record_case("terminal")

func _configure(label: String) -> void:
	_host.call("_cancel_deferred_skill_analytics")
	_set_namespace(label)
	var profile: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(profile), label + ": fixture profile saves")
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_debug_boss_run(profile)
	state["debug_boss_run"] = false
	state["mode"] = "reward"
	state["combat_state"] = {}
	state["player_hp"] = 9
	state["analytics"] = {"run_id": "deferred_run_" + label, "run_skill_event_revision_logged": 0}
	state["skill_state"] = {"event_revision": 1, "events": [{"revision": 1, "skill_id": "discerning_eye", "message": "Replace the choices."}]}
	_host.set("_progression", profile)
	_host.set("_run_state", state)
	_host.set("_combat_state", {})
	_host.set("_committed_run_state_override", {})
	_host.set("_animation_lock", false)
	_host.set("_save_in_progress", false)
	_host.set("_analytics_store", AnalyticsStore.new())
	_host.calls.clear()
	_host.fail_save_boundary = ""
	_host.fail_append_once = false
	_host.append_prefix_before_failure = false
	_host.prefix_append_succeeded = false

func _disk_cursor() -> int:
	return int((ProgressionStore.load_saved_run().get("analytics", {}) as Dictionary).get("run_skill_event_revision_logged", -1))
func _set_namespace(label: String) -> void:
	var prefix: String = STORAGE_ROOT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(prefix))
	ProgressionStore.set_storage_path(prefix.path_join("profile.json"))
	ProgressionStore.set_run_storage_path(prefix.path_join("run.save"))
	ProgressionStore.clear_saved_run()
	AnalyticsStore.set_storage_dir(prefix.path_join("analytics"))
	AnalyticsStore.clear_storage()

func _event_count() -> int:
	var count: int = 0
	for event: Dictionary in AnalyticsStore.load_all_events():
		if str(event.get("event_type", "")) == "skill_triggered":
			count += 1
	return count

func _boundaries() -> Array[String]:
	var result: Array[String]
	for entry: Dictionary in _host.calls:
		if str(entry.get("kind", "")) == "save":
			result.append(str(entry.get("boundary", "")))
	return result

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	result.assign(values)
	return result

func _busy() -> bool:
	return bool(_host.get("_run_skill_analytics_queue").busy())

func _frames(count: int) -> void:
	for index: int in range(count):
		_pulse.pulse()
		await RenderingServer.frame_post_draw
		await process_frame

func _record_case(label: String) -> void:
	_results.append({"case": label, "calls": _host.calls.duplicate(true) if is_instance_valid(_host) else []})

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
		push_error(message)

func _timed_out() -> void:
	if _finished:
		return
	_errors.append("Timed out waiting for native rendered frames; use a real renderer, not --headless.")
	if is_instance_valid(_host):
		_host.call("_cancel_deferred_skill_analytics")
	_finish()

func _finish() -> void:
	if _finished:
		return
	_finished = true
	print("DEFERRED RUN SKILL ANALYTICS RESULT: " + JSON.stringify({"checks": _checks, "errors": _errors, "cases": _results}))
	print("TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)
