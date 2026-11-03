extends "res://scripts/combat_engine.gd"

const FrameTrace = preload("res://tests/perf/combat_frame_trace.gd")

func finish_player_card(state: Dictionary, hand_index: int, plays_spent: int = 1, play_context: Dictionary = {}) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super.finish_player_card(state, hand_index, plays_spent, play_context)
	FrameTrace.record("engine_finish_player_card", started, Time.get_ticks_usec(), 5)
	return result

func apply_planned_player_move(state: Dictionary, action: Dictionary, target_tile: Vector2i, movement_plan: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super.apply_planned_player_move(state, action, target_tile, movement_plan)
	FrameTrace.record("engine_apply_planned_player_move", started, Time.get_ticks_usec(), -5)
	return result

func apply_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i = Vector2i(-1, -1)) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super.apply_player_action(state, action, target_tile)
	FrameTrace.record("engine_apply_player_action", started, Time.get_ticks_usec(), -5)
	return result

func apply_prevalidated_player_move(state: Dictionary, action: Dictionary, target_tile: Vector2i, planned_path: Array) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super.apply_prevalidated_player_move(state, action, target_tile, planned_path)
	FrameTrace.record("engine_apply_prevalidated_player_move", started, Time.get_ticks_usec(), -5)
	return result

func apply_prevalidated_player_action(state: Dictionary, action: Dictionary, target_tile: Vector2i) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super.apply_prevalidated_player_action(state, action, target_tile)
	FrameTrace.record("engine_apply_prevalidated_player_action", started, Time.get_ticks_usec(), -5)
	return result
