extends "res://scripts/ui_socket.gd"

const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")

var _state_owner: BaseButton

func follow_button_states(button: BaseButton) -> void:
	_state_owner = button
	for event: Signal in [button.mouse_entered, button.mouse_exited, button.focus_entered, button.focus_exited]:
		event.connect(queue_redraw)

func _socket_active() -> bool:
	if _state_owner != null:
		return not _state_owner.disabled and (_state_owner.is_hovered() or _state_owner.has_focus())
	return super._socket_active()

func _socket_dimmed() -> bool:
	return super._socket_dimmed() or (_state_owner != null and _state_owner.disabled)

func _make_custom_tooltip(for_text: String) -> Object:
	return null if for_text.strip_edges().is_empty() else Tooltip.make_text(for_text)
