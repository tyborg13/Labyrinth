extends "res://tests/perf/profiled_run_scene.gd"
## Probe-only inclusive intervals. The unchanged production methods do the work.

func _on_card_hover_started(index: int, pointer_hover: bool = true) -> void:
	var started: int = Time.get_ticks_usec()
	super._on_card_hover_started(index, pointer_hover)
	FrameTrace.record("hand_enter_total", started, Time.get_ticks_usec(), -30)

func _on_card_hover_ended(index: int) -> void:
	var started: int = Time.get_ticks_usec()
	super._on_card_hover_ended(index)
	FrameTrace.record("hand_leave_total", started, Time.get_ticks_usec(), -30)

func _set_hand_emphasized_index(index: int, animated: bool = true) -> void:
	var started: int = Time.get_ticks_usec()
	super._set_hand_emphasized_index(index, animated)
	FrameTrace.record("hand_emphasis_total", started, Time.get_ticks_usec(), -10)

func _show_card_focus_tooltips(index: int) -> void:
	var started: int = Time.get_ticks_usec()
	super._show_card_focus_tooltips(index)
	FrameTrace.record("card_glossary_construct_and_layout", started, Time.get_ticks_usec(), 25)

func _refresh_turn_order_bar(accepted_display_state: Dictionary = {}) -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_turn_order_bar(accepted_display_state)
	FrameTrace.record("turn_order_total", started, Time.get_ticks_usec(), -10)

func _refresh_turn_order_landing_strip() -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_turn_order_landing_strip()
	FrameTrace.record("turn_order_strip_construct_and_layout", started, Time.get_ticks_usec(), 25)

func _refresh_contextual_combat_tutorial() -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_contextual_combat_tutorial()
	FrameTrace.record("tutorial", started, Time.get_ticks_usec(), 25)

func _refresh_board_hover_presentation() -> void:
	var started: int = Time.get_ticks_usec()
	super._refresh_board_hover_presentation()
	FrameTrace.record("deferred_hover_total", started, Time.get_ticks_usec(), -30)

func _enemy_intent_preview_state(display_state: Dictionary) -> Dictionary:
	var started: int = Time.get_ticks_usec()
	var result: Dictionary = super._enemy_intent_preview_state(display_state)
	FrameTrace.record("enemy_intent_preview", started, Time.get_ticks_usec(), 25)
	return result

func _on_board_tile_hovered(tile: Vector2i) -> void:
	var started: int = Time.get_ticks_usec()
	super._on_board_tile_hovered(tile)
	FrameTrace.record("target_input", started, Time.get_ticks_usec(), 25)
