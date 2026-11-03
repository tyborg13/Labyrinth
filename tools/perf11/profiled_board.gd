extends "res://tests/perf/profiled_combat_board.gd"

func _flush_hover_hud_redraw() -> void:
	var started: int = Time.get_ticks_usec()
	super._flush_hover_hud_redraw()
	FrameTrace.record("deferred_hud_total", started, Time.get_ticks_usec(), -10)

func set_combat_state(next_state: Dictionary, next_move_tiles: Array = [], next_attack_tiles: Array = [], next_selected_tile: Vector2i = Vector2i(-1, -1), next_status_label: String = "", next_status_detail: String = "", next_exit_tiles: Dictionary = {}, next_exit_icon_ids: Dictionary = {}, next_presentation: Dictionary = {}, trust_same_reference_state: bool = false) -> void:
	var started: int = Time.get_ticks_usec()
	super.set_combat_state(next_state, next_move_tiles, next_attack_tiles, next_selected_tile, next_status_label, next_status_detail, next_exit_tiles, next_exit_icon_ids, next_presentation, trust_same_reference_state)
	FrameTrace.record("board_submission_with_decorators_total", started, Time.get_ticks_usec(), -20)
