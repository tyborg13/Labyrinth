extends "res://scripts/run_scene.gd"

# Causal lane only: detailed snapshots deliberately never run in clean timing.
var _completion_trace_active: bool = false
var _completion_trace: Array[Dictionary]
var _completion_trace_stack: Array[String]
func start_completion_trace() -> void:
	_completion_trace.clear()
	_completion_trace_stack.clear()
	_completion_trace_active = true
func finish_completion_trace() -> Array:
	_completion_trace_active = false
	return _completion_trace.duplicate(true)
func _trace_completion(event: String, subject: Control = null) -> void:
	if not _completion_trace_active: return
	var point: Vector2 = get_viewport().get_mouse_position()
	var routed: Control = get_viewport().gui_get_hovered_control()
	var cards: Array[Dictionary]
	for index: int in range(hand_box.get_child_count()):
		var widget: Control = _hand_card_control(index)
		var slot: Control = hand_box.get_child(index)
		if widget == null: continue
		var local: Vector2 = widget.get_global_transform_with_canvas().affine_inverse() * point
		cards.append({"slot_id": slot.get_instance_id(), "id": widget.get_instance_id(), "index": index, "card": widget.card_id, "slot_position": [slot.position.x, slot.position.y], "slot_scale": [slot.scale.x, slot.scale.y], "slot_rotation": slot.rotation, "widget_size": [widget.size.x,widget.size.y], "contains": Rect2(Vector2.ZERO, widget.size).has_point(local), "visible": widget.is_visible_in_tree(), "filter": widget.mouse_filter, "local_hover": widget.get("_local_hovered")})
	_completion_trace.append({"event": event, "usec": Time.get_ticks_usec(), "frame": Engine.get_process_frames(), "stack": _completion_trace_stack.duplicate(), "hover": _hovered_card_index, "emphasis": hand_box.emphasized_index(), "strength": hand_box.emphasis_strength(), "pointer": [point.x,point.y], "route": routed.get_instance_id() if routed != null else 0, "subject": subject.get_instance_id() if subject != null else 0, "cards": cards})
func _trace_enter(label: String, subject: Control = null) -> void:
	_trace_completion(label + ".enter", subject)
	if _completion_trace_active: _completion_trace_stack.append(label)
func _trace_exit(label: String, subject: Control = null) -> void:
	if _completion_trace_active: _completion_trace_stack.pop_back()
	_trace_completion(label + ".exit", subject)

func _refresh_hand_panel() -> void:
	_trace_enter("hand")
	super._refresh_hand_panel()
	_trace_exit("hand")

func _refresh_stage_view() -> void:
	_trace_enter("stage")
	super._refresh_stage_view()
	_trace_exit("stage")

func _refresh_turn_order_bar() -> void:
	_trace_enter("turnbar")
	super._refresh_turn_order_bar()
	_trace_exit("turnbar")

func _refresh_contextual_combat_tutorial() -> void:
	_trace_enter("tutorial")
	super._refresh_contextual_combat_tutorial()
	_trace_exit("tutorial")

func _sync_board_view_rect() -> void:
	_trace_enter("board_rect")
	super._sync_board_view_rect()
	_trace_exit("board_rect")

func _configure_scaled_card_slot_geometry(slot: Control, card_size: Vector2, retain_hand_transform: bool = false) -> void:
	_trace_enter("geometry", slot)
	super._configure_scaled_card_slot_geometry(slot, card_size, retain_hand_transform)
	_trace_exit("geometry", slot)

func _on_hand_card_widget_hover_started(widget: CardWidget) -> void:
	_trace_enter("hover_start", widget)
	super._on_hand_card_widget_hover_started(widget)
	_trace_exit("hover_start", widget)

func _on_hand_card_widget_hover_ended(widget: CardWidget) -> void:
	_trace_enter("hover_end", widget)
	super._on_hand_card_widget_hover_ended(widget)
	_trace_exit("hover_end", widget)

func _set_hand_emphasized_index(index: int, animated: bool = true) -> void:
	_trace_enter("emphasis")
	super._set_hand_emphasized_index(index, animated)
	_trace_exit("emphasis")

func _fit_current_hand_layout_to_visible_width(expected_revision: int, retry_count: int = 0) -> void:
	_trace_completion("fit.wait_start:%d" % expected_revision)
	await super._fit_current_hand_layout_to_visible_width(expected_revision, retry_count)
	_trace_completion("fit.wait_end:%d" % expected_revision)

func _prepare_skill_analytics_outbox() -> bool:
	_trace_enter("analytics_outbox")
	var result: bool = super._prepare_skill_analytics_outbox()
	_trace_exit("analytics_outbox")
	return result

func _append_and_acknowledge_skill_analytics() -> bool:
	_trace_enter("analytics_append_ack")
	var result: bool = super._append_and_acknowledge_skill_analytics()
	_trace_exit("analytics_append_ack")
	return result

func _persist_skill_analytics_acknowledgment() -> bool:
	_trace_enter("analytics_run_ack")
	var result: bool = super._persist_skill_analytics_acknowledgment()
	_trace_exit("analytics_run_ack")
	return result
