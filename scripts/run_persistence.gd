extends Node

const ProgressionStore = preload("res://scripts/progression_store.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const OpeningBoonRules = preload("res://scripts/opening_boon_rules.gd")
const SectionMapGraph = preload("res://scripts/section_map_graph.gd")
const AFTER_DRAW_RESOLUTION_META: String = "persistence_rules_after_draw"
var _host: WeakRef
var _observed_analytics_failure: int = 0
static var _resolution_frame: int = -1
static var _write_frame: int = -1

static func mark_resolution_frame() -> void:
	_resolution_frame = Engine.get_process_frames()

static func expect_resolution_after_draw(scene: Node) -> void:
	# Post-draw continuations run after ordinary idle callbacks. Reserve their
	# frame before yielding so an earlier deferred drain cannot steal its budget.
	scene.set_meta(AFTER_DRAW_RESOLUTION_META, true)

static func resume_resolution_after_draw(scene: Node) -> void:
	scene.remove_meta(AFTER_DRAW_RESOLUTION_META)
	mark_resolution_frame()

static func attach(scene: Node) -> void:
	var lifecycle := new()
	lifecycle.name = "RunPersistence"
	lifecycle._host = weakref(scene)
	lifecycle.process_mode = Node.PROCESS_MODE_ALWAYS
	lifecycle.process_priority = 10000
	lifecycle._observed_analytics_failure = AnalyticsStore.write_failure_generation()
	scene.add_child(lifecycle)
	scene._analytics_store.deferred_writes = true

func _process(_delta: float) -> void:
	# Drain after process/timer callbacks have marked any combat work this frame.
	_drain_idle.call_deferred()

func _drain_idle() -> void:
	var scene: Node = _host.get_ref()
	if _observed_analytics_failure != AnalyticsStore.write_failure_generation():
		_observed_analytics_failure = AnalyticsStore.write_failure_generation()
		_invalidate_replay_cursors(scene)
	if not is_instance_valid(scene) or _write_frame == Engine.get_process_frames(): return
	var idle: bool = _resolution_frame != Engine.get_process_frames() and not scene.has_meta(AFTER_DRAW_RESOLUTION_META)
	var saves: RefCounted = ProgressionStore._run_writer
	var events: RefCounted = AnalyticsStore._writer
	# One automatic disk operation per frame. Oldest first; the age cap takes
	# precedence over combat exclusion, including a reserved post-draw frame.
	var saves_ready: bool = saves.busy() and (idle or saves.oldest_wait_usec() >= saves.MAX_DELAY_USEC)
	var events_ready: bool = events.busy() and (idle or events.oldest_wait_usec() >= events.MAX_DELAY_USEC)
	if not saves_ready and not events_ready: return
	var write_checkpoint: bool = saves_ready and (not events_ready or saves.service_wait_usec() >= events.service_wait_usec())
	var writer: RefCounted = saves if write_checkpoint else events
	var started: int = Time.get_ticks_usec()
	if write_checkpoint: ProgressionStore.poll_pending_run_saves(idle)
	else: AnalyticsStore.poll_pending_events(idle)
	if writer.last_write_started_usec >= started:
		_write_frame = Engine.get_process_frames()
	_record_write_interval(scene, "deferred_checkpoint_write" if write_checkpoint else "deferred_analytics_batch", started, writer)
	# When both queues are past the cap, serving only one would push the other a
	# frame beyond it; the cap outranks the one-write-per-frame budget.
	var other: RefCounted = events if write_checkpoint else saves
	if other.busy() and other.oldest_wait_usec() >= other.MAX_DELAY_USEC:
		var other_started: int = Time.get_ticks_usec()
		if write_checkpoint: AnalyticsStore.poll_pending_events(idle)
		else: ProgressionStore.poll_pending_run_saves(idle)
		_record_write_interval(scene, "deferred_analytics_batch" if write_checkpoint else "deferred_checkpoint_write", other_started, other)

static func _record_write_interval(scene: Node, phase: String, started: int, writer: RefCounted) -> void:
	if writer.last_write_started_usec < started: return
	if is_instance_valid(scene) and scene.has_method("_record_external_runtime_performance_interval"):
		scene._record_external_runtime_performance_interval(phase, writer.last_write_started_usec, writer.last_write_started_usec + writer.last_write_usec)

func _exit_tree() -> void:
	flush(_host.get_ref())

static func flush(scene: Node = null) -> bool:
	# Return the I/O result; transition policy stays with the original callers.
	# 69444f134 proceeded on Quit/Continue, but guarded replacement saves.
	var saved: bool = ProgressionStore.flush_pending_run_saves()
	var appended: bool = AnalyticsStore.flush_pending_events(true)
	if not appended: _invalidate_replay_cursors(scene)
	if is_instance_valid(scene) and scene.has_meta("perf03_analytics_replay_needed"):
		scene.remove_meta("perf03_analytics_replay_needed")
		scene._analytics_flush_surface_events(scene._combat_state, scene._run_state)
		scene._analytics_flush_map_events(scene._run_state)
		appended = AnalyticsStore.flush_pending_events(true)
		if not appended: _invalidate_replay_cursors(scene)
	return saved and appended

static func _invalidate_replay_cursors(scene: Node) -> void:
	if not is_instance_valid(scene): return
	scene._surface_analytics_revisions.clear()
	scene._map_analytics_revision = 0
	scene.set_meta("perf03_analytics_replay_needed", true)

static func persist(scene: Node, run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:
	return _persist_snapshot(scene, run_state, hold_for_animation, boundary, false)

static func persist_owned(scene: Node, owned_state: Dictionary, boundary: String) -> Dictionary:
	# Transfer only a fresh _committed_run_state() result. The caller must never
	# mutate or reuse it. Public/held snapshot callers retain defensive copying;
	# combat queues take ownership after the last mutation (play-time sampling).
	return _persist_snapshot(scene, owned_state, false, boundary, true)

static func _queue_owned_snapshot(state: Dictionary, failure_boundary: String) -> bool:
	# Identical request, path capture, callback and supersession policy to
	# ProgressionStore.queue_run_state. Only this detached snapshot's ownership
	# differs. After submission, opening/surface/map analytics only read it;
	# only the recursively read-only map journal may be shared with a live or
	# held snapshot. All mutable fields belong exclusively to this request.
	var request: Dictionary = {"state": state, "failure_boundary": failure_boundary, "reported": false}
	ProgressionStore._run_writer.submit(ProgressionStore._save_queued_run_state_at.bind(ProgressionStore._run_storage_path, request), true)
	return true

static func _persist_snapshot(scene: Node, run_state: Dictionary, hold_for_animation: bool, boundary: String, owns_snapshot: bool) -> Dictionary:
	mark_resolution_frame()
	var performance_total_started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
	var state: Dictionary = run_state if owns_snapshot else SectionMapGraph.checkpoint_copy(run_state)
	var performance_phase_started: int = scene._record_runtime_performance_phase("combat_checkpoint_persist_input_duplicate", performance_total_started)
	if state.is_empty() or bool(state.get("debug_boss_run", false)):
		return {"state": state, "saved": false}
	if scene._save_in_progress:
		return {"state": state, "saved": false}
	scene._run_play_clock.sample_scene_play_time(scene, state)
	scene._save_in_progress = true
	var mode: String = str(state.get("mode", ""))
	var resume_run_skill_request: bool = mode not in ["combat", "victory", "defeat"] and scene._run_skill_analytics_queue.busy() and not scene._run_skill_analytics_flushing
	if mode != "combat" and not scene._skill_analytics_flushing:
		scene._cancel_deferred_skill_analytics(true)
	var saved: bool = false
	var profile_saved: bool = true
	var run_before_profile: bool = boundary in ["heirloom_left", "heirloom_confirmed"]
	if mode in ["victory", "defeat"]:
		flush(scene)
		var terminal_resume_state: Dictionary = state.duplicate(true)
		state = scene._finalize_terminal_committed_state(state)
		if run_before_profile:
			if not terminal_resume_state.has("heirloom_terminal_wallet"):
				scene._progression["progression_revision"] = int(scene._progression.get("progression_revision", 0)) + 1
				state["progression"] = scene._progression.duplicate(true)
			# Boon choices commit to the run first. A failed run write must not
			# change the profile; a deferred profile write is recoverable from it.
			saved = ProgressionStore.save_run_state(state)
		else:
			saved = ProgressionStore.save_data(scene._progression)
			if saved and (OpeningBoonRules.heirloom_prompt_pending(state) or state.has(OpeningBoonRules.EVENTS_KEY)):
				saved = ProgressionStore.save_run_state(state)
			elif saved:
				ProgressionStore.clear_saved_run()
			else:
				ProgressionStore.save_run_state(terminal_resume_state)
		if run_before_profile and saved: profile_saved = ProgressionStore.save_data(scene._progression)
	else:
		var durable_boundary: bool = boundary == "explicit_save" or boundary.ends_with("_outbox") or boundary.ends_with("_ack") or boundary.ends_with("_cursor")
		var failure_boundary: String = "" if durable_boundary else (boundary if not boundary.is_empty() else "unspecified")
		if mode == "combat":
			# Public/held callers still receive independently mutable run fields;
			# the queued request shares only the guarded journal prefix.
			saved = _queue_owned_snapshot(state if owns_snapshot else SectionMapGraph.checkpoint_copy(state), failure_boundary)
		else:
			saved = ProgressionStore.save_run_state(state)
		# Durable outbox/cursor protocols must observe the actual result, never
		# queue acceptance. These explicit barriers remain synchronous.
		if mode == "combat" and durable_boundary:
			saved = ProgressionStore.flush_pending_run_saves() and saved
	performance_phase_started = scene._record_runtime_performance_phase("combat_checkpoint_persist_storage", performance_phase_started)
	if hold_for_animation:
		scene._committed_run_state_override = SectionMapGraph.checkpoint_copy(state)
	scene._record_runtime_performance_phase("combat_checkpoint_persist_hold_duplicate", performance_phase_started)
	scene._save_in_progress = false
	if not saved:
		push_error("Failed to persist committed run boundary: %s" % (boundary if not boundary.is_empty() else "unspecified"))
	scene._record_runtime_performance_phase("combat_checkpoint_persist_total", performance_total_started)
	if saved:
		var opening_events_saved: bool = scene._opening_boon_flow.flush_events(scene, state)
		if mode in ["victory", "defeat"] and not OpeningBoonRules.heirloom_prompt_pending(state) and opening_events_saved and profile_saved:
			ProgressionStore.clear_saved_run()
		scene._analytics_flush_surface_events(state.get("combat_state", {}) as Dictionary, state)
		scene._analytics_flush_map_events(state)
		# A reveal/action may save after its final HUD refresh. Keep that same-run
		# request alive so unlocking without another refresh still drains it.
		if resume_run_skill_request: scene._request_run_skill_event_analytics()
	return {"state": state, "saved": saved}

