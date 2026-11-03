extends "res://scripts/combat_board_view.gd"

const FrameTrace = preload("res://tests/perf/combat_frame_trace.gd")

func _draw() -> void:
	var started: int = Time.get_ticks_usec()
	super._draw()
	FrameTrace.record("draw:" + (_render_layer_kind if _is_dynamic_render_layer else "static"), started, Time.get_ticks_usec(), -10)
	FrameTrace.event("draw")

func _process(delta: float) -> void:
	var started: int = Time.get_ticks_usec()
	super._process(delta)
	FrameTrace.record("board_process", started, Time.get_ticks_usec())

func _record_render_section_time(section: String, started_usec: int) -> void:
	FrameTrace.record("draw_section:" + section, started_usec, Time.get_ticks_usec())
	super._record_render_section_time(section, started_usec)

func _record_submission_performance_phase(phase: String, started_usec: int) -> int:
	if _submission_performance_instrumentation_enabled:
		FrameTrace.record("submission:" + phase, started_usec, Time.get_ticks_usec(), 20)
	return super._record_submission_performance_phase(phase, started_usec)

func _queue_hover_redraws() -> void:
	var started: int = Time.get_ticks_usec()
	super._queue_hover_redraws()
	FrameTrace.record("hover_hud_rebuild", started, Time.get_ticks_usec(), 20)

func _get_tooltip(at_position: Vector2) -> String:
	var started: int = Time.get_ticks_usec()
	var result: String = super._get_tooltip(at_position)
	FrameTrace.record("tooltip_lookup", started, Time.get_ticks_usec(), 20)
	return result

func _make_custom_tooltip(for_text: String) -> Object:
	var started: int = Time.get_ticks_usec()
	var result: Object = super._make_custom_tooltip(for_text)
	FrameTrace.record("tooltip_construct", started, Time.get_ticks_usec(), 20)
	return result

func _gui_input(event: InputEvent) -> void:
	var started: int = Time.get_ticks_usec()
	super._gui_input(event)
	FrameTrace.record("board_gui_dispatch", started, Time.get_ticks_usec(), -15)

func _tile_at_point(point: Vector2) -> Vector2i:
	var started: int = Time.get_ticks_usec()
	var result: Vector2i = super._tile_at_point(point)
	FrameTrace.record("input_tile_pick", started, Time.get_ticks_usec(), 20)
	return result
