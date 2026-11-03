extends "res://scripts/run_scene.gd"

const FrameTrace = preload("res://tests/perf/combat_frame_trace.gd")
var reference_checkpoint_copy: bool = false

func _run_state_for_combat_checkpoint(base_run_state: Dictionary, combat_state: Dictionary) -> Dictionary:
	# Reproduce the removed caller copy for the current-base reference workload.
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._run_state_for_combat_checkpoint(base_run_state.duplicate(true) if reference_checkpoint_copy else base_run_state, combat_state)
	FrameTrace.record("checkpoint_builder_call", started, Time.get_ticks_usec(), -5)
	return result

func _record_runtime_performance_frame_phase(phase: String, started_usec: int, ended_usec: int) -> void:
	if phase in ["deferred_checkpoint_write", "deferred_analytics_batch"]:
		FrameTrace.event(phase)
	if not RUNTIME_PERFORMANCE_DIAGNOSTIC_PHASES.has(phase):
		FrameTrace.record(phase, started_usec, ended_usec, 0 if phase.ends_with("_total") else 10)
	super._record_runtime_performance_frame_phase(phase, started_usec, ended_usec)

func _record_runtime_performance_diagnostic_interval(started_usec: int, ended_usec: int) -> void:
	FrameTrace.record("telemetry_record", started_usec, ended_usec, 100)
	super._record_runtime_performance_diagnostic_interval(started_usec, ended_usec)

func _commit_runtime_performance_frame() -> void:
	var started: int = Time.get_ticks_usec()
	super._commit_runtime_performance_frame()
	FrameTrace.record("telemetry_partition", started, Time.get_ticks_usec())

func _spawn_card_proxy(card_id: String, rect: Rect2) -> Control:
	var started: int = Time.get_ticks_usec()
	var result: Control = super._spawn_card_proxy(card_id, rect)
	FrameTrace.record("card_proxy_construct", started, Time.get_ticks_usec())
	return result

func _contextual_combat_rendered_board_bounds() -> Rect2:
	var started: int = Time.get_ticks_usec()
	var result: Rect2 = super._contextual_combat_rendered_board_bounds()
	FrameTrace.record("layout_board_bounds", started, Time.get_ticks_usec(), 20)
	return result

func _active_card_preview() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._active_card_preview()
	FrameTrace.record("input_active_card_preview", started, Time.get_ticks_usec(), 20)
	return result

func _shortcut_plan_for_tile(preview: Dictionary, target_tile: Vector2i, use_approach: bool = true) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._shortcut_plan_for_tile(preview, target_tile, use_approach)
	FrameTrace.record("input_shortcut_plan_for_tile", started, Time.get_ticks_usec(), 20)
	return result

func _lock_action_step_tracker_position_for_resolution() -> void:
	var started: int = Time.get_ticks_usec()
	super._lock_action_step_tracker_position_for_resolution()
	FrameTrace.record("input_lock_action_step_tracker_position_for_resolution", started, Time.get_ticks_usec(), 20)

func _analytics_snapshot_combat_tracker() -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._analytics_snapshot_combat_tracker()
	FrameTrace.record("input_analytics_snapshot_combat_tracker", started, Time.get_ticks_usec(), 20)
	return result

func _sync_click_targeting_arrow(mouse_position: Vector2 = Vector2(-1.0, -1.0)) -> void:
	var started: int = Time.get_ticks_usec()
	super._sync_click_targeting_arrow(mouse_position)
	FrameTrace.record("input_sync_click_targeting_arrow", started, Time.get_ticks_usec(), 20)

func _begin_card_play_meter_spend_preview(plays_spent: int = 1) -> void:
	var started: int = Time.get_ticks_usec()
	super._begin_card_play_meter_spend_preview(plays_spent)
	FrameTrace.record("input_begin_card_play_meter_spend_preview", started, Time.get_ticks_usec(), 20)

func _card_preview_from_state(card_id: String, combat_state: Dictionary, actions: Array, action_index: int, has_effect: bool = false, use_position_only_move_legality: bool = true, allow_skip_suffix_shortcut: bool = true, playability_only: bool = false, information_override: Variant = null) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._card_preview_from_state(card_id, combat_state, actions, action_index, has_effect, use_position_only_move_legality, allow_skip_suffix_shortcut, playability_only, information_override)
	FrameTrace.record("input_card_preview_continuation", started, Time.get_ticks_usec(), -5)
	return result

func _resolve_reused_target_preview_actions(source_preview: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._resolve_reused_target_preview_actions(source_preview)
	FrameTrace.record("input_resolve_reused_target_preview_actions", started, Time.get_ticks_usec(), -5)
	return result

func _shortcut_action_with_default_force_direction(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._shortcut_action_with_default_force_direction(state, action, target_tile)
	FrameTrace.record("input_shortcut_action_with_default_force_direction", started, Time.get_ticks_usec(), -5)
	return result

func _load_pending_preview_state(preview: Dictionary) -> void:
	var started: int = Time.get_ticks_usec()
	super._load_pending_preview_state(preview)
	FrameTrace.record("input_load_pending_preview_state", started, Time.get_ticks_usec(), -5)

func _mark_preview_selection_changed() -> void:
	var started: int = Time.get_ticks_usec()
	super._mark_preview_selection_changed()
	FrameTrace.record("input_mark_preview_selection_changed", started, Time.get_ticks_usec(), -5)

func _input(event: InputEvent) -> void:
	var started: int = Time.get_ticks_usec()
	await super._input(event)
	FrameTrace.record("scene_input_dispatch", started, Time.get_ticks_usec(), -20)

func _hold_committed_run_state(run_state: Dictionary, boundary: String = "") -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._hold_committed_run_state(run_state, boundary)
	FrameTrace.record("checkpoint_hold_call", started, Time.get_ticks_usec(), -5)
	return result

func _persist_run_state_snapshot(run_state: Dictionary, hold_for_animation: bool, boundary: String) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._persist_run_state_snapshot(run_state, hold_for_animation, boundary)
	FrameTrace.record("checkpoint_persist_call", started, Time.get_ticks_usec(), -5)
	return result

func _play_card_play_sfx() -> void:
	var started: int = Time.get_ticks_usec()
	super._play_card_play_sfx()
	FrameTrace.record("input_card_play_sfx", started, Time.get_ticks_usec(), 20)

func _mount_card_proxy(proxy: Control, parent: Node, rect: Rect2) -> void:
	var started: int = Time.get_ticks_usec()
	super._mount_card_proxy(proxy, parent, rect)
	FrameTrace.record("input_card_proxy_mount", started, Time.get_ticks_usec(), 20)
