extends Node

const ProgressionStore = preload("res://scripts/progression_store.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const OpeningBoonRules = preload("res://scripts/opening_boon_rules.gd")
const Writer = preload("res://scripts/ordered_background_writer.gd")
const Checkpoint = preload("res://scripts/run_checkpoint.gd")
const SectionMapGraph = preload("res://scripts/section_map_graph.gd")
const Score = preload("res://scripts/run_score_rules.gd")
const AFTER_DRAW_RESOLUTION_META: String = "persistence_rules_after_draw"
const DEPARTURE_META := &"persistence_departure"
const PENDING_ABANDON_RECEIPT := "pending_abandon_analytics"
var _host: WeakRef
var _observed_analytics_failure: int = 0
static var _resolution_frame: int = -1
static var _write_frame: int = -1
static var _application_drained: bool = false

static func has_checkpoint(state: Dictionary) -> bool:
	return Checkpoint.has_checkpoint(state)

static func reward_checkpoint_key(state: Dictionary) -> String:
	var room: Variant = state.get("current_room")
	match state.get("mode"):
		"reward":
			var reward: Dictionary = state.get("pending_reward", {})
			if reward.get("kind") == "dragon":
				var milestone: String = str(reward.get("milestone_id", ""))
				return "" if milestone.is_empty() else "%s|%s|dragon|%s" % [Score.identity(state), room, milestone]
			var board: Dictionary = reward.get("board_state", {})
			if not board.is_empty():
				return "%s|%s|combat|%s" % [Score.identity(state), room, board.get("analytics", {}).get("combat_id", "")]
		"treasure":
			var trophy: Dictionary = state.get("guardian_reward", {})
			if not trophy.is_empty() and not bool(trophy.get("claimed", false)) and state.get("pending_relics", []).has(trophy.get("relic_id")):
				return "%s|%s|guardian|%s|%s" % [Score.identity(state), room, trophy.get("guardian_id", ""), trophy["relic_id"]]
	return ""

static func load_resumable_checkpoint(recover_terminal_profile: bool = false) -> Dictionary:
	return ProgressionStore.read_resumable_checkpoint(recover_terminal_profile).get("state", {})

static func replay_run_closing_receipts(profile: Dictionary, checkpoint: Dictionary, hidden_wins: Array = []) -> void:
	var embedded: Dictionary = checkpoint.get("progression", {}) if checkpoint.get("progression") is Dictionary else {}
	var outbox_key: String = ProgressionStore.PROGRESSION_ANALYTICS_OUTBOX_KEY
	var pending: Variant = embedded.get(outbox_key)
	if hidden_wins.is_empty() and profile.get(outbox_key, []).is_empty() and (not pending is Array or pending.is_empty()): return
	var carried := profile if hidden_wins.is_empty() else ProgressionStore.merge_progression_analytics_outbox(profile, {outbox_key: hidden_wins})
	var outbox: Array[Dictionary] = ProgressionStore.progression_analytics_outbox(
		ProgressionStore.merge_progression_analytics_outbox(carried, embedded)
	)
	outbox = ProgressionStore.deliverable_progression_receipts(outbox, profile)
	for receipt: Dictionary in outbox:
		if receipt["event_type"] in ["combat_ended", "reward_offered", "run_ended"]:
			# Title boot can deliver immediately. RunScene owns profile
			# acknowledgment and can safely retry an already appended batch.
			# A receipt still waiting for that acknowledgment is usually already
			# in the newest log: check the tail before a full deduplicating load.
			if AnalyticsStore.has_durable_rows(outbox.map(func(entry: Dictionary) -> String: return entry["idempotency_key"])): return
			AnalyticsStore.new().write_events_durable(outbox)
			return

static func validated_resume_summary(state: Dictionary) -> Dictionary:
	return Checkpoint.validated_resume_summary(state)

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
	if not is_instance_valid(scene) or scene.has_meta(DEPARTURE_META): return
	var saves: RefCounted = ProgressionStore._run_writer
	var events: RefCounted = AnalyticsStore._writer
	saves.collect()
	AnalyticsStore.collect_completed_events()
	if _observed_analytics_failure != AnalyticsStore.write_failure_generation():
		_observed_analytics_failure = AnalyticsStore.write_failure_generation()
		_invalidate_replay_cursors(scene)
	if _write_frame == Engine.get_process_frames(): return
	var idle: bool = _resolution_frame != Engine.get_process_frames() and not scene.has_meta(AFTER_DRAW_RESOLUTION_META)
	# Preserve the original dispatch order and per-frame cadence. The disk
	# service runs both stores' accepted transactions in that same order.
	var saves_ready: bool = saves.can_dispatch() and (idle or saves.oldest_wait_usec() >= saves.MAX_DELAY_USEC)
	var events_ready: bool = events.can_dispatch() and (idle or events.oldest_wait_usec() >= events.MAX_DELAY_USEC)
	if saves_ready or events_ready:
		var write_checkpoint: bool = saves_ready and (not events_ready or saves.service_wait_usec() >= events.service_wait_usec())
		_dispatch(scene, idle, write_checkpoint)
		var other: RefCounted = events if write_checkpoint else saves
		if other.can_dispatch() and other.oldest_wait_usec() >= other.MAX_DELAY_USEC:
			_dispatch(scene, idle, not write_checkpoint)
	_record_samples(scene)

static func _dispatch(scene: Node, idle: bool, checkpoint: bool) -> void:
	var writer: RefCounted = ProgressionStore._run_writer if checkpoint else AnalyticsStore._writer
	var started: int = Time.get_ticks_usec()
	if checkpoint: ProgressionStore.poll_pending_run_saves(idle)
	else: AnalyticsStore.poll_pending_events(idle)
	if writer.last_write_started_usec < started: return
	_write_frame = Engine.get_process_frames()
	if scene.has_method("_record_external_runtime_performance_interval"):
		var phase: String = "deferred_checkpoint_write" if checkpoint else "deferred_analytics_batch"
		scene._record_external_runtime_performance_interval(phase, writer.last_write_started_usec,
			writer.last_write_started_usec + writer.last_write_usec)

static func _record_samples(scene: Node) -> void:
	var enabled: bool = is_instance_valid(scene) and scene.has_method("_record_persistence_performance_sample") and scene._runtime_performance_instrumentation_enabled
	for checkpoint: bool in [true, false]:
		var writer: RefCounted = ProgressionStore._run_writer if checkpoint else AnalyticsStore._writer
		var samples: Array[Dictionary] = writer.take_samples()
		writer.track_performance = enabled
		if not enabled: continue
		var prefix: String = "checkpoint_write_" if checkpoint else "analytics_write_"
		var deferred_phase: String = "deferred_checkpoint_write" if checkpoint else "deferred_analytics_batch"
		for sample: Dictionary in samples:
			if sample.has("worker_usec"):
				scene._record_persistence_performance_sample(prefix + "worker", int(sample["worker_usec"]))
			elif sample.has("barrier_wait_usec"):
				scene._record_persistence_performance_sample(prefix + "barrier_wait", int(sample["barrier_wait_usec"]))
			else:
				scene._record_persistence_performance_sample(prefix + "serialize", int(sample["serialize_usec"]))
				if not bool(sample["barrier"]):
					scene._record_persistence_performance_sample(deferred_phase, int(sample["elapsed_usec"]))

func _exit_tree() -> void:
	var scene: Node = _host.get_ref()
	if not _application_drained and (not is_instance_valid(scene) or not scene.has_meta(DEPARTURE_META)):
		flush(scene)

static func set_application_drained() -> void:
	# The application's final save barrier has returned and no retries remain.
	# Record failures before the Steam autoload submits its clean-quit batch.
	ProgressionStore._run_writer.report_abandoned_requests()
	ProgressionStore.SaveFailures.append_pending_events()
	_application_drained = true

static func application_drained() -> bool:
	return _application_drained

static func _flush_events_in_tree(tree: SceneTree, all_directories: bool = false) -> bool:
	var writers: Array[RefCounted]
	writers.append(AnalyticsStore._writer)
	if all_directories:
		for writer: RefCounted in AnalyticsStore._writers_by_directory.values():
			if not writers.has(writer): writers.append(writer)
	var succeeded := true
	for writer: RefCounted in writers:
		if not await writer.flush_in_tree(tree): succeeded = false
		writer.take_failure()
	if not succeeded:
		AnalyticsStore._write_failure_generation += 1
		AnalyticsStore._storage_generation += 1
		push_error("Failed to flush queued analytics events.")
	return succeeded

static func flush_in_tree(tree: SceneTree, scene: Node = null) -> bool:
	var saved: bool = await ProgressionStore.flush_pending_run_saves_in_tree(tree)
	var appended := await _flush_scene_events_in_tree(tree, scene)
	return saved and appended

static func _flush_scene_events_in_tree(tree: SceneTree, scene: Node) -> bool:
	var appended: bool = await _flush_events_in_tree(tree, true)
	if not appended: _invalidate_replay_cursors(scene)
	if is_instance_valid(scene) and scene.has_meta("perf03_analytics_replay_needed"):
		scene.remove_meta("perf03_analytics_replay_needed")
		scene._analytics_flush_surface_events(scene._combat_state, scene._run_state)
		scene._analytics_flush_map_events(scene._run_state)
		appended = await _flush_events_in_tree(tree, true)
		if not appended: _invalidate_replay_cursors(scene)
	_record_samples(scene)
	return appended

static func _append_receipts_in_tree(tree: SceneTree, analytics: RefCounted, events: Array) -> bool:
	if events.is_empty(): return true
	analytics.hold_ordered_receipts(events)
	var order: RefCounted = analytics._receipt_order()
	for event: Dictionary in events:
		var receipt: Dictionary = order.find_key(str(event["idempotency_key"]))
		if not receipt.is_empty(): receipt["ready"] = true
	while order.busy():
		var batch: Dictionary = order.next_batch()
		if batch.is_empty(): break
		var count: int = batch["records"].size()
		if not bool(batch["submitted"]):
			if not analytics._append_records_at(str(batch["path"]), batch["records"]): return false
			order.mark_submitted(count)
		if not await _flush_events_in_tree(tree): return false
		order.acknowledge(count)
	for event: Dictionary in events:
		if not analytics.has_idempotency_key(str(event["idempotency_key"])): return false
	return true

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
	_record_samples(scene)
	return saved and appended

static func _invalidate_replay_cursors(scene: Node) -> void:
	if not is_instance_valid(scene): return
	scene._surface_analytics_revisions.clear()
	scene._map_analytics_revision = 0
	scene.set_meta("perf03_analytics_replay_needed", true)

static func save_for_departure(scene: Node) -> bool:
	var tree := scene.get_tree()
	scene.set_meta(DEPARTURE_META, true)
	scene._cancel_deferred_skill_analytics(true)
	if scene._event_view != null: scene._event_view.finish_result_beats()
	var state: Dictionary = {}
	var held: bool = not scene._committed_run_state_override.is_empty()
	if not scene._initial_loading_cancelled and scene.has_installed_run() and not scene._campfire_embrace_committed and not scene._is_debug_boss_run():
		# Freeze the same committed boundary before allowing any animation or
		# renderer continuation to run during the disk wait.
		if not held and str(scene._run_state.get("mode", "")) not in ["victory", "defeat"]:
			scene._stage_skill_analytics_outbox()
		state = scene._committed_run_state()
		scene._run_play_clock.sample_scene_play_time(scene, state)
	while scene._save_in_progress: await tree.process_frame
	var pending_saved := await ProgressionStore.flush_pending_run_saves_in_tree(tree)
	await _flush_scene_events_in_tree(tree, scene)
	if not has_checkpoint(state): return pending_saved
	var mode: String = str(state.get("mode", ""))
	var saved: bool
	if mode in ["victory", "defeat"]:
		saved = await _save_terminal_for_departure(tree, scene, state, held)
	else:
		saved = await _save_active_for_departure(tree, scene, state)
	await flush_in_tree(tree, scene)
	return saved

static func _save_terminal_for_departure(tree: SceneTree, scene: Node, state: Dictionary, held: bool) -> bool:
	var disk := await ProgressionStore.load_data_in_tree(tree)
	state = terminal_state_for_departure(state, disk)
	var pending: bool = OpeningBoonRules.heirloom_prompt_pending(state)
	if prompt_needs_checkpoint(state) and not await _write_departing_checkpoint(tree, scene, state): return false
	var events := _opening_receipts(scene, state)
	var append_failed := false
	if not pending or held:
		append_failed = not await _append_receipts_in_tree(tree, scene._analytics_store, events)
	var settlement: Dictionary = prepare_terminal_departure(scene, state, disk)
	var terminal: Dictionary = settlement["state"]
	var retained: Dictionary = ProgressionStore.merge_progression_analytics_outbox(terminal["progression"], disk)
	ProgressionStore.merge_run_completion_ids(retained, disk)
	ProgressionStore.merge_run_completion_ids(retained, state.get("progression", {}))
	if append_failed:
		for event: Dictionary in events:
			retained = ProgressionStore.queue_progression_analytics_event(retained,
				event["event_type"], event["idempotency_key"], event["context"], event["payload"])
	if not await ProgressionStore.save_data_in_tree(tree, retained):
		push_error("Failed to persist terminal progression; the resumable fallback remains intact.")
		return false
	terminal["progression"] = retained
	scene._apply_terminal_settlement(settlement)
	if not await _write_departing_checkpoint(tree, scene, terminal): return false
	if pending: await _append_receipts_in_tree(tree, scene._analytics_store, events)
	scene._analytics_flush_surface_events(terminal.get("combat_state", {}), terminal)
	scene._analytics_flush_map_events(terminal)
	if not pending: return await ProgressionStore.clear_saved_run_in_tree(tree)
	return true

static func active_departure_profile(active: Dictionary, disk: Dictionary, embedded: Dictionary) -> Dictionary:
	var source: Dictionary = active if int(active.get("progression_revision", 0)) >= int(disk.get("progression_revision", 0)) else disk
	var profile := ProgressionStore.merge_progression_analytics_outbox(source, disk)
	ProgressionStore.merge_run_completion_ids(profile, active)
	ProgressionStore.merge_depth_progress(profile, disk)
	ProgressionStore.merge_depth_progress(profile, embedded)
	# The checkpoint owns this run's held wallet. A profile may have a
	# different, already settled bank after a cloud conflict.
	profile["embers"] = int(disk.get("embers", 0))
	return profile

static func _save_active_for_departure(tree: SceneTree, scene: Node, state: Dictionary) -> bool:
	var disk := await ProgressionStore.load_data_in_tree(tree)
	if ProgressionStore.has_completed_run(disk, state) or preserves_heirloom_fallback(state): return true
	var embedded: Dictionary = state.get("progression", {})
	var profile := active_departure_profile(scene._progression, disk, embedded)
	ProgressionStore.merge_run_completion_ids(profile, disk)
	ProgressionStore.merge_run_completion_ids(profile, embedded)
	if state.has("progression"):
		ProgressionStore.merge_run_completion_ids(embedded, profile)
	var profile_saved := await ProgressionStore.save_data_in_tree(tree, profile)
	if not await _write_departing_checkpoint(tree, scene, state): return false
	var outbox := ProgressionStore.deliverable_progression_receipts(
		ProgressionStore.progression_analytics_outbox(embedded), profile if profile_saved else disk
	)
	# Title or Continue replays the win receipts from this frozen checkpoint.
	# Departure can still deliver unrelated receipts through its existing path.
	outbox = outbox.filter(func(receipt: Dictionary) -> bool: return not ProgressionStore.is_combat_win_receipt(receipt))
	var run_skill_events: Array = scene._run_skill_receipts(state, state.get("combat_state", {}))
	var cursor_updated := false
	if not outbox.is_empty() and await _append_receipts_in_tree(tree, scene._analytics_store, outbox):
		var keys: Array[String]
		for event: Dictionary in outbox: keys.append(event["idempotency_key"])
		var acknowledged := ProgressionStore.acknowledge_progression_analytics_events(profile, keys)
		if profile_saved:
			profile_saved = await ProgressionStore.save_data_in_tree(tree, acknowledged)
			if profile_saved:
				state["progression"] = ProgressionStore.acknowledge_progression_analytics_events(embedded, keys)
				cursor_updated = true
	if not run_skill_events.is_empty() and await _append_receipts_in_tree(tree, scene._analytics_store, run_skill_events):
		var logged: int = 0
		for event: Dictionary in run_skill_events:
			logged = maxi(logged, int(event["payload"]["trigger_revision"]))
		state["analytics"]["run_skill_event_revision_logged"] = logged
		cursor_updated = true
	var checkpoint_saved := true
	if cursor_updated: checkpoint_saved = await _write_departing_checkpoint(tree, scene, state)
	await _append_receipts_in_tree(tree, scene._analytics_store, _opening_receipts(scene, state))
	scene._analytics_flush_surface_events(state.get("combat_state", {}), state)
	scene._analytics_flush_map_events(state)
	return profile_saved and checkpoint_saved

static func _opening_receipts(scene: Node, state: Dictionary) -> Array[Dictionary]:
	var events: Array[Dictionary]
	var context: Dictionary = scene._analytics_context_from_states(state)
	var source: Array = state.get(OpeningBoonRules.EVENTS_KEY, [])
	for index: int in source.size():
		var event: Dictionary = source[index]
		events.append({"event_type": event["type"], "idempotency_key": OpeningBoonRules.event_key(context, index, event),
			"context": context, "payload": event["payload"]})
	return events

static func _write_departing_checkpoint(tree: SceneTree, scene: Node, state: Dictionary) -> bool:
	_queue_checkpoint(scene, state, "explicit_save")
	return await ProgressionStore.flush_pending_run_saves_in_tree(tree)

static func save_loaded_checkpoint(scene: Node, state: Dictionary) -> bool:
	_queue_checkpoint(scene, state, "", true)
	return ProgressionStore.flush_pending_run_saves()

static func _queue_checkpoint(scene: Node, state: Dictionary, failure_boundary: String = "", show_victory_failure: bool = false) -> void:
	var key := reward_checkpoint_key(state)
	var settled: Callable
	if not key.is_empty():
		# Do not pin a receipt. The writer calls this observer again if an
		# ordinary background retry makes a previously failed checkpoint durable.
		settled = _report_reward_checkpoint.bind(weakref(scene), key, show_victory_failure)
	ProgressionStore.queue_owned_run_state(state.duplicate(true), failure_boundary, null, settled)

static func _report_reward_checkpoint(saved: bool, host: WeakRef, key: String, show_victory_failure: bool) -> void:
	var scene: Node = host.get_ref()
	if is_instance_valid(scene): scene._record_reward_checkpoint(key, saved, show_victory_failure)

static func prompt_needs_checkpoint(state: Dictionary) -> bool:
	if not OpeningBoonRules.heirloom_prompt_pending(state): return false
	var id := ProgressionStore.completion_run_id(state)
	if id.is_empty(): return false
	# Publish the unanswered prompt before settling its wallet. The fallback
	# retains the original amount so it can also recover a failed profile write.
	var saved := ProgressionStore.load_saved_run()
	return ProgressionStore.completion_run_id(saved) != id or saved.get("mode") != state.get("mode") or not OpeningBoonRules.heirloom_prompt_pending(saved)

static func terminal_state_for_departure(state: Dictionary, profile: Dictionary) -> Dictionary:
	if not state.has(OpeningBoonRules.HEIRLOOM_END_KEY): return state
	var id := ProgressionStore.completion_run_id(state)
	if id.is_empty(): return state
	var saved := ProgressionStore.load_saved_run()
	if ProgressionStore.completion_run_id(saved) == id and ProgressionStore.terminal_profile_write_pending(saved, profile):
		return saved
	return state

static func prepare_terminal_departure(scene: Node, state: Dictionary, profile: Dictionary) -> Dictionary:
	if ProgressionStore.terminal_profile_write_pending(state, profile):
		return scene._prepare_terminal_settlement(state, true, state["progression"])
	return scene._prepare_terminal_settlement(state)

static func stage_unsettled_abandon(scene: Node, receipt: Dictionary) -> void:
	# An active checkpoint may hold an attempt, but only a settled profile
	# may expose it to the deliverable progression outbox.
	var fallback: Dictionary = scene._committed_run_state()
	fallback[PENDING_ABANDON_RECEIPT] = AnalyticsStore._sanitize_variant(receipt)
	if not ProgressionStore.save_run_state(fallback):
		push_error("Failed to save the unsettled Abandon attempt.")

static func preserves_heirloom_fallback(state: Dictionary) -> bool:
	if state.get("mode") != "reward": return false
	var id := ProgressionStore.completion_run_id(state)
	if id.is_empty(): return false
	# A failed profile write can leave the reward scene active after its
	# unanswered terminal prompt already committed to the checkpoint.
	var saved := ProgressionStore.load_saved_run()
	return ProgressionStore.completion_run_id(saved) == id and (
		OpeningBoonRules.heirloom_prompt_pending(saved)
		or ProgressionStore.terminal_profile_write_pending(saved, ProgressionStore.load_data())
	)

static func persist(scene: Node, run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:
	return _persist_snapshot(scene, run_state, hold_for_animation, boundary, false)

static func persist_owned(scene: Node, owned_state: Dictionary, boundary: String, receipt: Writer.Receipt = null) -> Dictionary:
	# Transfer only a fresh _committed_run_state() result. The caller must never
	# mutate or reuse it. Public/held snapshot callers retain defensive copying;
	# combat queues take ownership after the last mutation (play-time sampling).
	return _persist_snapshot(scene, owned_state, false, boundary, true, receipt)

static func _persist_snapshot(scene: Node, run_state: Dictionary, hold_for_animation: bool, boundary: String, owns_snapshot: bool,
		receipt: Writer.Receipt = null) -> Dictionary:
	var prepared := _begin_snapshot(scene, run_state, owns_snapshot)
	var state: Dictionary = prepared["state"]
	if not prepared["ready"]: return {"state": state, "saved": false}
	var mode: String = str(state.get("mode", ""))
	var saved: bool = false
	var profile_saved: bool = true
	var terminal_profile_committed := false
	var run_before_profile: bool = boundary in ["heirloom_left", "heirloom_confirmed"]
	if mode in ["victory", "defeat"]:
		flush(scene)
		if not run_before_profile and prompt_needs_checkpoint(state) and not ProgressionStore.save_run_state(state):
			scene._save_in_progress = false
			push_error("Failed to persist the terminal heirloom checkpoint.")
			return {"state": state, "saved": false}
		var terminal_resume_state: Dictionary = state.duplicate(true)
		var settlement: Dictionary = scene._prepare_terminal_settlement(state, run_before_profile)
		state = settlement["state"]
		var candidate: Dictionary = state["progression"]
		if run_before_profile:
			if not terminal_resume_state.has("heirloom_terminal_wallet"):
				candidate["progression_revision"] = int(candidate.get("progression_revision", 0)) + 1
			# Boon choices commit to the run first. A failed run write must not
			# change the profile; a deferred profile write is recoverable from it.
			saved = ProgressionStore.save_run_state(state)
			if saved:
				profile_saved = ProgressionStore.save_data(candidate)
				if profile_saved: scene._apply_terminal_settlement(settlement)
				else: push_error("Failed to persist the heirloom profile; the saved choice remains recoverable.")
			if not saved or not profile_saved: state = terminal_resume_state
		else:
			saved = ProgressionStore.save_data(candidate)
			terminal_profile_committed = saved
			if saved:
				scene._apply_terminal_settlement(settlement)
				# Publish the terminal record before cleanup. An interrupted or
				# blocked clear must leave the terminal state authoritative.
				saved = ProgressionStore.save_run_state(state)
			else:
				ProgressionStore.save_run_state(terminal_resume_state)
				state = terminal_resume_state
	else:
		var durable_boundary: bool = boundary == "explicit_save" or boundary.ends_with("_outbox") or boundary.ends_with("_ack") or boundary.ends_with("_cursor")
		var failure_boundary: String = "" if durable_boundary else (boundary if not boundary.is_empty() else "unspecified")
		if mode == "combat":
			var settled: Callable
			if receipt != null:
				settled = _finish_combat_receipt.bind(weakref(scene), state, boundary)
			# Public/held callers still receive independently mutable run fields;
			# the queued request shares only the guarded journal prefix.
			saved = ProgressionStore.queue_owned_run_state(state if owns_snapshot else SectionMapGraph.checkpoint_copy(state), failure_boundary, receipt, settled)
		else:
			_queue_checkpoint(scene, state, "", hold_for_animation or boundary == "reward_intro_complete")
			saved = ProgressionStore.flush_pending_run_saves()
		# Explicit callers need the result now. Deferred combat reconciliation
		# instead waits on its pinned receipt before the dependent append.
		if mode == "combat" and durable_boundary and receipt == null:
			saved = ProgressionStore.flush_pending_run_saves() and saved
	var phase: int = scene._record_runtime_performance_phase("combat_checkpoint_persist_storage", prepared["phase"])
	_finish_snapshot(scene, state, boundary, hold_for_animation, saved, profile_saved, receipt,
		prepared["resume_run_skill_request"], phase, prepared["started"])
	return {"state": state, "saved": saved, "terminal_profile_committed": terminal_profile_committed}

static func persist_reward_in_tree(scene: Node, run_state: Dictionary, boundary: String, hold_for_animation: bool = false) -> Dictionary:
	var prepared := _begin_snapshot(scene, run_state, false)
	var state: Dictionary = prepared["state"]
	if not prepared["ready"]: return {"state": state, "saved": false}
	# Publish the held checkpoint at its existing commit point after VICTORY.
	# Departure can snapshot it while the live reward waits for durability.
	if hold_for_animation:
		scene._committed_run_state_override = SectionMapGraph.checkpoint_copy(state)
		scene._track_reward_checkpoint(state)
	_queue_checkpoint(scene, state, "", hold_for_animation or boundary == "reward_intro_complete")
	scene._record_runtime_performance_phase("reward_checkpoint_submit", prepared["phase"])
	var saved := await ProgressionStore.flush_pending_run_saves_in_tree(scene.get_tree())
	var phase: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
	_finish_snapshot(scene, state, boundary, false, saved, true, null, prepared["resume_run_skill_request"], phase)
	return {"state": state, "saved": saved}

static func _begin_snapshot(scene: Node, run_state: Dictionary, owns_snapshot: bool) -> Dictionary:
	mark_resolution_frame()
	var performance_total_started: int = Time.get_ticks_usec() if scene._runtime_performance_instrumentation_enabled else 0
	var state: Dictionary = run_state if owns_snapshot else SectionMapGraph.checkpoint_copy(run_state)
	var performance_phase_started: int = scene._record_runtime_performance_phase("combat_checkpoint_persist_input_duplicate", performance_total_started)
	if not has_checkpoint(state) or bool(state.get("debug_boss_run", false)):
		return {"state": state, "started": performance_total_started, "ready": false}
	if scene._save_in_progress:
		return {"state": state, "started": performance_total_started, "ready": false}
	scene._run_play_clock.sample_scene_play_time(scene, state)
	scene._save_in_progress = true
	var mode: String = str(state.get("mode", ""))
	var resume_run_skill_request: bool = mode not in ["combat", "victory", "defeat"] and scene._run_skill_analytics_queue.busy() and not scene._run_skill_analytics_flushing
	if mode != "combat" and not scene._skill_analytics_flushing:
		scene._cancel_deferred_skill_analytics(true)
	return {"state": state, "started": performance_total_started, "phase": performance_phase_started,
		"ready": true, "resume_run_skill_request": resume_run_skill_request}

static func _finish_snapshot(scene: Node, state: Dictionary, boundary: String, hold_for_animation: bool,
		saved: bool, profile_saved: bool, receipt: Writer.Receipt, resume_run_skill_request: bool, phase: int,
		total_started: int = 0) -> void:
	if hold_for_animation:
		scene._committed_run_state_override = SectionMapGraph.checkpoint_copy(state)
	scene._record_runtime_performance_phase("combat_checkpoint_persist_hold_duplicate", phase)
	scene._save_in_progress = false
	if not saved:
		push_error("Failed to persist committed run boundary: %s" % (boundary if not boundary.is_empty() else "unspecified"))
	if total_started > 0: scene._record_runtime_performance_phase("combat_checkpoint_persist_total", total_started)
	if saved and receipt == null:
		_after_saved_snapshot(scene, state, str(state.get("mode", "")), profile_saved)
		# A reveal/action may save after its final HUD refresh. Keep that same-run
		# request alive so unlocking without another refresh still drains it.
		if resume_run_skill_request: scene._request_run_skill_event_analytics()

static func _finish_combat_receipt(saved: bool, host: WeakRef, state: Dictionary, boundary: String) -> void:
	if not saved:
		push_error("Failed to persist committed run boundary: %s" % boundary)
		return
	var scene: Node = host.get_ref()
	if is_instance_valid(scene) and not scene.has_meta(DEPARTURE_META): _after_saved_snapshot(scene, state, "combat", true)

static func _after_saved_snapshot(scene: Node, state: Dictionary, mode: String, profile_saved: bool) -> void:
	var opening_events_saved: bool = scene._opening_boon_flow.flush_events(scene, state)
	if mode in ["victory", "defeat"] and not OpeningBoonRules.heirloom_prompt_pending(state) and opening_events_saved and profile_saved:
		ProgressionStore.clear_saved_run()
	scene._analytics_flush_surface_events(state.get("combat_state", {}) as Dictionary, state)
	scene._analytics_flush_map_events(state)

