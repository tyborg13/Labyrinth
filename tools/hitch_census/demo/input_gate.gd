extends Node
# Proof-only sibling placed last, so reverse-depth-first _input sees it first.
const GuiNavigation = preload("res://scripts/controller_gui_navigation.gd")
const OWNED_META: StringName = &"ux09_scripted_joypad"
var session
var accepted: int = 0
var derived_controller_events: int = 0
var suppressed: Dictionary
var _reorder_pending: bool = false
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().node_added.connect(_new_node)
	_new_node(self)
func _new_node(_node: Node) -> void:
	if _reorder_pending: return
	_reorder_pending = true
	_reorder.call_deferred()
func _reorder() -> void:
	_reorder_pending = false
	if is_inside_tree(): get_parent().move_child(self, get_parent().get_child_count() - 1)
func _input(event: InputEvent) -> void:
	if event.has_meta(OWNED_META) and (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		accepted += 1
		return
	# Production analog GUI navigation re-dispatches D-pad events synchronously.
	# Keep that real input path intact; only its active production dispatcher
	# can admit an untagged controller event.
	if event is InputEventJoypadButton:
		for dispatcher: Node in get_tree().root.find_children("ControllerGuiNavigation", "", true, false):
			if dispatcher.get_script() == GuiNavigation and bool(dispatcher.get("_dispatching")):
				derived_controller_events += 1
				session.log_event("production_derived_input", {"type": event.get_class(), "button": event.button_index, "pressed": event.pressed})
				return
	var kind: String = event.get_class()
	suppressed[kind] = int(suppressed.get(kind, 0)) + 1
	session.log_event("external_input_suppressed", {"type": kind})
	get_viewport().set_input_as_handled()
