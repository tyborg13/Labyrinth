extends Node
## PopupMenu handles raw axes before Node input. While open, reserve only its
## vertical analog bindings so the shared repeat clock owns those steps.
const AxisRepeat = preload("res://scripts/controller_axis_repeat.gd")
const ACTIONS: Array = [&"ui_up", &"ui_down"]
static var _binding_users: int = 0
static var _reserved_bindings: Dictionary = {}

var _popup: PopupMenu
var _repeat := AxisRepeat.new()
var _claimed: bool = false
var _enter_threshold: float

static func install(option: OptionButton) -> void:
	var navigation := new()
	navigation.name = "ControllerOptionNavigation"
	navigation._popup = option.get_popup()
	navigation._popup.add_child(navigation)

func _ready() -> void:
	_repeat.stepped.connect(_step)
	_popup.about_to_popup.connect(_reserve_bindings)
	_popup.popup_hide.connect(_release_bindings)

func _reserve_bindings() -> void:
	if _claimed: return
	_claimed = true
	_enter_threshold = InputMap.action_get_deadzone(&"ui_down")
	_binding_users += 1
	if _binding_users != 1: return
	for action: StringName in ACTIONS:
		var removed: Array = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
				removed.append(event)
				InputMap.action_erase_event(action, event)
		_reserved_bindings[action] = removed

func _release_bindings() -> void:
	_repeat.reset()
	if not _claimed: return
	_claimed = false
	_binding_users -= 1
	if _binding_users != 0: return
	for action: StringName in _reserved_bindings:
		for event: InputEvent in _reserved_bindings[action]:
			if not InputMap.action_has_event(action, event): InputMap.action_add_event(action, event)
	_reserved_bindings.clear()

func _exit_tree() -> void:
	_release_bindings()

func _input(event: InputEvent) -> void:
	if not _popup.visible or not event is InputEventJoypadMotion or event.axis != JOY_AXIS_LEFT_Y: return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	_repeat.sample(event.axis, event.axis_value, _enter_threshold)
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _popup.visible: return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null or bool(router.call("using_controller")):
		_repeat.advance(delta)

func _step(_axis: int, direction: int) -> void:
	var index: int = _popup.get_focused_item()
	for offset: int in range(_popup.item_count):
		index = posmod(index + direction, _popup.item_count)
		if not _popup.is_item_disabled(index) and not _popup.is_item_separator(index):
			_popup.set_focused_item(index)
			_popup.id_focused.emit(_popup.get_item_id(index))
			return
