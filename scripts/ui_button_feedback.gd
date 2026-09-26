extends RefCounted
## Shared hover/focus feedback for action buttons, independent of their artwork.

const BOUND_META: String = "ui_button_feedback_bound"
const POINTER_META: String = "ui_button_feedback_pointer"
const FOCUS_META: String = "ui_button_feedback_focus"
const ACTIVE_META: String = "ui_button_feedback_active"

static func bind_button(button: BaseButton) -> void:
	if button == null or button.has_meta(BOUND_META):
		return
	button.set_meta(BOUND_META, true)
	button.mouse_entered.connect(_set_highlight.bind(button, POINTER_META, true))
	button.mouse_exited.connect(_set_highlight.bind(button, POINTER_META, false))
	button.focus_entered.connect(_set_highlight.bind(button, FOCUS_META, true))
	button.focus_exited.connect(_set_highlight.bind(button, FOCUS_META, false))
	button.visibility_changed.connect(_reset_if_hidden.bind(button))
	button.tree_exiting.connect(_reset.bind(button))

static func _set_highlight(button: BaseButton, source: String, active: bool) -> void:
	button.set_meta(source, active)
	var was_active: bool = bool(button.get_meta(ACTIVE_META, false))
	var highlighted: bool = (
		button.is_inside_tree() and button.is_visible_in_tree()
		and not button.disabled and button.can_process()
		and (bool(button.get_meta(POINTER_META, false)) or bool(button.get_meta(FOCUS_META, false)))
	)
	button.set_meta(ACTIVE_META, highlighted)
	# Pointer hover followed by click/native focus is still one highlight.
	if not highlighted or was_active:
		return
	var feedback: Node = button.get_node_or_null("/root/CursorFeedback")
	if feedback != null and feedback.has_method("play_focus_feedback"):
		feedback.call("play_focus_feedback")

static func _reset_if_hidden(button: BaseButton) -> void:
	if not button.is_visible_in_tree():
		_reset(button)

static func _reset(button: BaseButton) -> void:
	button.set_meta(POINTER_META, false)
	button.set_meta(FOCUS_META, false)
	button.set_meta(ACTIVE_META, false)
