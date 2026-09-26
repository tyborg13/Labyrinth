extends SceneTree

# Run with a real renderer: this verifies the production frame_post_draw queue.
# A bounded timeout also fails cleanly if invoked with the dummy renderer.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const STORAGE_ROOT: String = "user://deferred_skill_analytics_test"

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
			"frame": Engine.get_process_frames(), "saved": bool(result.get("saved", false)),
			"run_id": str((state.get("analytics", {}) as Dictionary).get("run_id", "")),
			"hp": int(((state.get("combat_state", {}) as Dictionary).get("player", {}) as Dictionary).get("hp", -1)),
		})
		return result
	func _reconcile_progression_analytics_outbox() -> bool:
		var result: bool
		if fail_append_once:
			fail_append_once = false
			if append_prefix_before_failure:
				prefix_append_succeeded = _analytics_store.write_events(ProgressionStore.progression_analytics_outbox(_progression))
			result = false
		else:
			result = super._reconcile_progression_analytics_outbox()
		calls.append({"kind": "append", "frame": Engine.get_process_frames(), "saved": result})
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
	root.size = Vector2i(640, 360)
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	create_timer(15.0).timeout.connect(_timed_out)
	call_deferred("_run")

func _run() -> void:
	_pulse = RenderPulse.new()
	_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_pulse)
	_set_namespace("boot")
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	instance.set_script(TestHost)
	_host = instance as TestHost
	root.add_child(_host)
	# Required inherited @onready paths resolve in the authored scene, while the
	# host override skips all RunScene boot, save/load, UI and process behavior.
	await _frames(1)
	await _test_ordered_stages()
	await _test_locked_warmup()
	await _test_action_pause_and_restart()
	await _test_action_after_acknowledgment()
	await _test_explicit_save_held_state()
	await _test_scope_and_namespace()
	await _test_initial_save_failure()
	await _test_append_failure_and_replay()
	await _test_terminal_failure_preserves_fallback("victory", 47)
	await _test_terminal_failure_preserves_fallback("defeat", 31)
	_host.call("_cancel_deferred_skill_analytics")
	_host.queue_free()
	await process_frame
	_finish()

func _test_ordered_stages() -> void:
	_configure("ordered")
	var profile_hash: String = FileAccess.get_sha256(ProgressionStore._storage_path)
	_host.call("_request_skill_event_analytics")
	_expect(_host.calls.is_empty(), "request performs no synchronous persistence stage")
	_expect(not ProgressionStore.has_saved_run(), "request does not create a run save")
	_expect(AnalyticsStore.load_all_events().is_empty(), "request does not append analytics")
	_expect(FileAccess.get_sha256(ProgressionStore._storage_path) == profile_hash, "request leaves the profile file unchanged")
	await _frames(1)
	_expect(_boundaries() == _strings(["combat_skill_event_outbox"]), "first frame saves only the staged outbox")
	_expect(_disk_outbox_count() == 1 and _disk_staged_revision() == 1, "first save contains matching outbox and staged cursor")
	_expect(_event_count() == 0, "JSONL append waits for its own frame")
	await _frames(1)
	_expect(_host.calls.size() == 2 and str(_host.calls[1]["kind"]) == "append", "second frame performs append/profile acknowledgment")
	_expect(_event_count() == 1, "second stage appends the trigger exactly once")
	_expect(_pending_count(_host.get("_progression") as Dictionary) == 0, "second stage acknowledges active progression")
	_expect(_pending_count((_host.get("_run_state") as Dictionary).get("progression", {}) as Dictionary) == 0, "second stage synchronizes the run outbox in the same slice")
	_expect(_pending_count(ProgressionStore.load_data()) == 0 and _disk_outbox_count() == 1, "profile acknowledgment precedes final run acknowledgment")
	await _frames(1)
	_expect(_boundaries() == _strings(["combat_skill_event_outbox", "combat_skill_event_ack"]), "third frame saves the run acknowledgment")
	_expect(_disk_outbox_count() == 0 and not _busy(), "successful ordered protocol drains completely")
	_expect(_host.calls.size() == 3 and int(_host.calls[0]["frame"]) < int(_host.calls[1]["frame"]) and int(_host.calls[1]["frame"]) < int(_host.calls[2]["frame"]), "all three stages use distinct rendered frames")
	_record_case("ordered")

func _test_action_pause_and_restart() -> void:
	_configure("action_pause")
	_host.call("_request_skill_event_analytics")
	await _frames(1)
	var future: Dictionary = _future_state(3, true)
	_host.set("_animation_lock", true)
	_host.set("_committed_run_state_override", future.duplicate(true))
	await _frames(2)
	_expect(_host.calls.size() == 1 and _event_count() == 0, "new action and held snapshot pause acknowledgment")
	_host.set("_run_state", future.duplicate(true))
	_host.set("_combat_state", (future.get("combat_state", {}) as Dictionary).duplicate(true))
	_host.set("_progression", (future.get("progression", {}) as Dictionary).duplicate(true))
	_host.set("_committed_run_state_override", {})
	_host.set("_animation_lock", false)
	await _frames(3)
	_expect(_boundaries() == _strings(["combat_skill_event_outbox", "combat_skill_event_outbox", "combat_skill_event_ack"]), "unlock restarts from a coherent outbox checkpoint")
	_expect(_disk_hp() == 3 and _disk_staged_revision() == 2, "restarted stages persist the newest gameplay state and trigger revision")
	_expect(_event_count() == 2 and _disk_outbox_count() == 0, "both pending revisions append once and acknowledge")
	_expect(int(_host.calls[1].get("hp", -1)) == 3 and int(_host.calls[-1].get("hp", -1)) == 3, "restart and final save never adopt the old HP snapshot")
	_record_case("action_pause")

func _test_locked_warmup() -> void:
	_configure("locked_warmup")
	_host.set("_animation_lock", true)
	_host.call("_reconcile_skill_event_analytics_across_frames")
	_expect(_host.calls.is_empty(), "locked warmup also waits before its first I/O")
	await _frames(4)
	_expect(not _busy() and _event_count() == 1 and _disk_outbox_count() == 0, "authorized player-turn warmup drains while input remains locked")
	_expect(bool(_host.get("_animation_lock")) and str(_host.get("_skill_analytics_locked_scope")).is_empty(), "warmup releases only its queue readiness exception")
	_expect(_host.calls.size() == 3 and int(_host.calls[0]["frame"]) < int(_host.calls[1]["frame"]) and int(_host.calls[1]["frame"]) < int(_host.calls[2]["frame"]), "locked warmup retains three distinct frame stages")
	_record_case("locked_warmup")

func _test_action_after_acknowledgment() -> void:
	_configure("after_ack")
	_host.call("_request_skill_event_analytics")
	await _frames(2)
	var future: Dictionary = _future_state(4, true)
	_expect(_pending_count(future.get("progression", {}) as Dictionary) == 0, "an action started after profile acknowledgment inherits no acknowledged outbox")
	_host.set("_animation_lock", true)
	_host.set("_committed_run_state_override", future.duplicate(true))
	await _frames(2)
	_expect(_host.calls.size() == 2 and _disk_hp() == 9, "new held action pauses the older final disk acknowledgment")
	_host.set("_run_state", future.duplicate(true))
	_host.set("_combat_state", (future.get("combat_state", {}) as Dictionary).duplicate(true))
	_host.set("_progression", (future.get("progression", {}) as Dictionary).duplicate(true))
	_host.set("_committed_run_state_override", {})
	_host.set("_animation_lock", false)
	_host.call("_request_skill_event_analytics")
	await _frames(3)
	_expect(_event_count() == 2 and _disk_outbox_count() == 0 and _disk_hp() == 4, "new action restarts against current state without resurrecting or duplicating the acknowledged trigger")
	_expect(int(_host.calls[-1].get("hp", -1)) == 4, "late acknowledgment saves current HP")
	_record_case("after_ack")

func _test_explicit_save_held_state() -> void:
	_configure("explicit_save")
	_host.call("_request_skill_event_analytics")
	await _frames(1)
	var future: Dictionary = _future_state(2, false)
	_host.set("_animation_lock", true)
	_host.set("_committed_run_state_override", future.duplicate(true))
	_host.call("_save_run_progress")
	var call_count: int = _host.calls.size()
	var saved_hash: String = FileAccess.get_sha256(ProgressionStore._run_storage_path)
	_expect(_disk_hp() == 2, "explicit save uses the held future HP rather than displayed HP")
	_expect(not _busy() and _event_count() == 1, "explicit save synchronously drains analytics and cancels its sleeper")
	_expect(str(_host.calls[-1].get("boundary", "")) == "explicit_save", "explicit checkpoint is the final synchronous save")
	await _frames(4)
	_expect(_host.calls.size() == call_count and FileAccess.get_sha256(ProgressionStore._run_storage_path) == saved_hash, "sleeping callbacks cannot overwrite an explicit checkpoint")
	_expect(_disk_hp() == 2, "newest committed gameplay remains saved after canceled callbacks wake")
	_record_case("explicit_save")

func _test_scope_and_namespace() -> void:
	_configure("old_scope")
	_host.call("_request_skill_event_analytics")
	await _frames(1)
	var old_path: String = ProgressionStore._run_storage_path
	var old_hash: String = FileAccess.get_sha256(old_path)
	# Change both state identity and paths without canceling the existing sleeper.
	# Readiness/scope checks must stop it from operating in the new namespace.
	_configure("new_scope", false)
	await _frames(2)
	_expect(_host.calls.is_empty() and not ProgressionStore.has_saved_run(), "old scope cannot write after run and namespace replacement")
	_expect(AnalyticsStore.load_all_events().is_empty(), "old scope cannot append into the replacement namespace")
	_host.call("_request_skill_event_analytics")
	await _frames(3)
	_expect(_event_count() == 1 and _disk_outbox_count() == 0, "explicit new-scope request completes its own protocol")
	_expect(str((ProgressionStore.load_saved_run().get("analytics", {}) as Dictionary).get("run_id", "")) == "deferred_new_scope", "replacement namespace contains only the new run")
	_expect(FileAccess.get_sha256(old_path) == old_hash, "new job does not alter the old namespace")
	_host.call("_request_skill_event_analytics")
	_host.call("_cancel_deferred_skill_analytics")
	var call_count: int = _host.calls.size()
	await _frames(2)
	_expect(_host.calls.size() == call_count and not _busy(), "explicit cancellation makes the sleeping job inert")
	_record_case("scope")

func _test_initial_save_failure() -> void:
	_configure("save_failure")
	_host.fail_save_boundary = "combat_skill_event_outbox"
	_host.call("_request_skill_event_analytics")
	await _frames(4)
	_expect(_host.calls.size() == 1 and not _busy(), "failed outbox save stops without automatic retries")
	_expect(not bool(_host.calls[0]["saved"]) and not ProgressionStore.has_saved_run(), "failed save is never reported as durable")
	_expect(_event_count() == 0 and _pending_count(_host.get("_progression") as Dictionary) == 1, "failed first save retains the trigger without appending")
	_host.call("_request_skill_event_analytics")
	await _frames(3)
	_expect(_event_count() == 1 and _disk_outbox_count() == 0, "later request retries the failed save and appends once")
	_record_case("save_failure")

func _test_append_failure_and_replay() -> void:
	_configure("append_failure")
	_host.fail_append_once = true
	_host.append_prefix_before_failure = true
	_host.call("_request_skill_event_analytics")
	await _frames(5)
	_expect(_host.prefix_append_succeeded, "failure fixture actually reaches JSONL before reporting failure")
	_expect(_host.calls.size() == 2 and not _busy(), "reported append failure stops without an acknowledgment save or automatic retry")
	_expect(_disk_outbox_count() == 1 and _pending_count(_host.get("_progression") as Dictionary) == 1, "reported append failure retains replayable disk and memory outboxes")
	_expect(_event_count() == 1, "partially completed append leaves exactly one real row")
	_host.call("_request_skill_event_analytics")
	await _frames(3)
	_expect(_event_count() == 1 and _disk_outbox_count() == 0, "later retry deduplicates the written prefix and durably acknowledges")
	_record_case("append_failure")

func _test_terminal_failure_preserves_fallback(mode: String, held: int) -> void:
	_configure("terminal_" + mode)
	_host.call("_request_skill_event_analytics")
	await _frames(1)
	var live_run: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	var live_combat: Dictionary = (_host.get("_combat_state") as Dictionary).duplicate(true)
	_expect(_pending_count(live_run.get("progression", {}) as Dictionary) == 1, mode + ": terminal fixture has a pending combat trigger")
	var terminal_run: Dictionary = live_run.duplicate(true)
	var terminal_combat: Dictionary = live_combat.duplicate(true)
	if mode == "victory":
		terminal_run["debug_boss_run"] = true
		var enemies: Array = (terminal_combat.get("enemies", []) as Array).duplicate(true)
		for index: int in range(enemies.size()):
			var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
			enemy["hp"] = 0
			enemies[index] = enemy
		terminal_combat["enemies"] = enemies
	else:
		var player: Dictionary = (terminal_combat.get("player", {}) as Dictionary).duplicate(true)
		player["hp"] = 0
		terminal_combat["player"] = player
	var engine := RunEngine.new()
	terminal_run = engine.finish_combat(terminal_run, terminal_combat)
	terminal_run["debug_boss_run"] = false
	terminal_run["held_embers"] = held
	terminal_run["unbanked_embers"] = held
	_expect(str(terminal_run.get("mode", "")) == mode, mode + ": fixture reaches the actual terminal mode")
	var writable_profile: String = ProgressionStore._storage_path
	# A real file as the parent component guarantees this profile path is invalid.
	ProgressionStore.set_storage_path(writable_profile.path_join("blocked.json"))
	_host.set("_victory_carry_processed", false)
	_host.set("_defeat_loss_processed", false)
	var failed: Dictionary = _host.call("_persist_run_state_snapshot", terminal_run, true, "terminal_" + mode + "_forced_failure") as Dictionary
	var fallback: Dictionary = ProgressionStore.load_saved_run()
	var fallback_hash: String = FileAccess.get_sha256(ProgressionStore._run_storage_path)
	_expect(not bool(failed.get("saved", true)) and fallback == terminal_run, mode + ": failed profile save persists the original terminal fallback")
	_expect(engine.held_embers(_host.call("_committed_run_state") as Dictionary) == 0 and engine.held_embers(fallback) == held, mode + ": finalized held state differs from the recoverable fallback")
	_host.set("_run_state", live_run)
	_host.set("_combat_state", live_combat)
	_host.set("_animation_lock", true)
	_host.call("_save_run_progress")
	var call_count: int = _host.calls.size()
	_expect(not _busy() and ProgressionStore.load_saved_run() == terminal_run, mode + ": Save & Quit preserves the unprocessed fallback despite the pending outbox")
	await _frames(3)
	_expect(_host.calls.size() == call_count and FileAccess.get_sha256(ProgressionStore._run_storage_path) == fallback_hash, mode + ": canceled analytics cannot later overwrite the fallback")
	_expect(_event_count() == 0 and _disk_outbox_count() == 1, mode + ": failed terminal checkpoint keeps the trigger replayable")
	ProgressionStore.set_storage_path(writable_profile)
	_host.call("_save_run_progress")
	var recovered: Dictionary = ProgressionStore.load_data()
	_expect(not ProgressionStore.has_saved_run(), mode + ": recovered profile checkpoint clears the fallback")
	if mode == "victory":
		_expect(int(recovered.get("embers", -1)) == held, "victory recovery banks the original held amount exactly once")
	else:
		_expect(int(ProgressionStore.recovery_marker(recovered).get("amount", -1)) == held, "defeat recovery preserves the original lost amount")
	_expect(_pending_count(recovered) == 1, mode + ": successful terminal checkpoint retains pending analytics in the durable profile")
	_record_case("terminal_" + mode)

func _configure(label: String, cancel_previous: bool = true) -> void:
	if cancel_previous:
		_host.call("_cancel_deferred_skill_analytics")
	_set_namespace(label)
	var progression: Dictionary = ProgressionStore.default_data()
	_expect(ProgressionStore.save_data(progression), label + ": fixture profile saves")
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_debug_boss_run(progression)
	state["debug_boss_run"] = false
	state["analytics"] = {"run_id": "deferred_" + label, "combat_counter": 1}
	var combat: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	combat["analytics"] = {"combat_id": "deferred_" + label + "_c001", "combat_skill_event_revision_staged": 0, "combat_defiance_event_revision_staged": 0}
	combat["skill_event_revision"] = 1
	combat["defiance_event_revision"] = 0
	combat["skill_events"] = [{"revision": 1, "skill_id": "afterimage", "turn": int(combat.get("turn", 1)), "message": "Afterimage leaves an illusion behind."}]
	var player: Dictionary = (combat.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 9
	combat["player"] = player
	state = engine.set_combat_state(state, combat)
	_host.set("_progression", progression)
	_host.set("_run_state", state)
	_host.set("_combat_state", combat)
	_host.set("_committed_run_state_override", {})
	_host.set("_animation_lock", false)
	_host.set("_save_in_progress", false)
	_host.set("_analytics_store", AnalyticsStore.new())
	_host.calls.clear()
	_host.fail_save_boundary = ""
	_host.fail_append_once = false
	_host.append_prefix_before_failure = false
	_host.prefix_append_succeeded = false

func _set_namespace(label: String) -> void:
	var prefix: String = STORAGE_ROOT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(prefix))
	ProgressionStore.set_storage_path(prefix.path_join("profile.json"))
	ProgressionStore.set_run_storage_path(prefix.path_join("run.save"))
	ProgressionStore.clear_saved_run()
	AnalyticsStore.set_storage_dir(prefix.path_join("analytics"))
	AnalyticsStore.clear_storage()

func _future_state(hp: int, add_trigger: bool) -> Dictionary:
	var state: Dictionary = (_host.get("_run_state") as Dictionary).duplicate(true)
	var combat: Dictionary = (state.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = hp
	combat["player"] = player
	if add_trigger:
		var events: Array = (combat.get("skill_events", []) as Array).duplicate(true)
		events.append({"revision": 2, "skill_id": "afterimage", "turn": int(combat.get("turn", 1)), "message": "A second coherent action triggers Afterimage."})
		combat["skill_events"] = events
		combat["skill_event_revision"] = 2
	var engine := RunEngine.new()
	return engine.set_combat_state(state, combat)

func _pending_count(progression: Dictionary) -> int:
	return ProgressionStore.progression_analytics_outbox(progression).size()

func _disk_outbox_count() -> int:
	return _pending_count(ProgressionStore.load_saved_run().get("progression", {}) as Dictionary)

func _disk_hp() -> int:
	return int(((ProgressionStore.load_saved_run().get("combat_state", {}) as Dictionary).get("player", {}) as Dictionary).get("hp", -1))

func _disk_staged_revision() -> int:
	return int(((ProgressionStore.load_saved_run().get("combat_state", {}) as Dictionary).get("analytics", {}) as Dictionary).get("combat_skill_event_revision_staged", -1))

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
	return bool(_host.get("_skill_analytics_queue").busy())

func _frames(count: int) -> void:
	for index: int in range(count):
		_pulse.pulse()
		await RenderingServer.frame_post_draw
		await process_frame

func _record_case(label: String) -> void:
	_results.append({"case": label, "calls": _host.calls.duplicate(true)})

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
	print("DEFERRED SKILL ANALYTICS RESULT: " + JSON.stringify({"checks": _checks, "errors": _errors, "cases": _results}))
	print("TEST RESULT: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)
