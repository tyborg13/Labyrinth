extends RefCounted

## Godot can emit GUI enter/exit before RunScene receives the mouse event.
## Resolve once its viewport-local endpoint is known, including when that early
## enter was rejected. Never recover it from the host cursor or GUI hover cache.
static func observe(scene: Node, event: InputEvent) -> void:
	if not event is InputEventMouse:
		return
	scene._hand_pointer_position = event.position
	scene._hand_pointer_position_valid = true
	var cursor: Node = scene.get_node_or_null("/root/CursorFeedback")
	if cursor != null:
		cursor.observe_pointer_event(event)
	if (
		scene._controller_is_active()
		or scene._hand_pointer_resolve_queued
		or not scene._hand_pointer_hover_allowed()
		or scene._controller_modal_visible()
	):
		return
	var index: int = scene._hand_index_under_pointer()
	if index == scene._hovered_card_index:
		return
	if index >= 0:
		scene._on_card_hover_started(index)
	else:
		scene._on_card_hover_ended(scene._hovered_card_index)
