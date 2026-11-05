extends Node
## Reuse each screen's native D-pad route, with deterministic analog repeats.
const AxisRepeat = preload("res://scripts/controller_axis_repeat.gd")
const HOST_META: String = "controller_gui_navigation_host"
const CUSTOM_META: String = "controller_custom_analog_navigation"

var _host: Control
var _available: Callable
var _repeat := AxisRepeat.new()
var _dispatching: bool = false
var _device: int = 0

static func install(host: Control, available: Callable = Callable()) -> Node:
	var navigation := new()
	navigation.name = "ControllerGuiNavigation"
	navigation._host = host
	navigation._available = available
	host.set_meta(HOST_META, true)
	host.add_child(navigation)
	return navigation

func _ready() -> void:
	_repeat.stepped.connect(_step)
	set_process(false)

func _owns_focus() -> bool:
	if not _host.is_visible_in_tree() or (_available.is_valid() and not bool(_available.call())):
		return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is OptionButton and focused.get_popup().visible: return false
	var ancestor: Node = focused
	while ancestor != null:
		if ancestor.has_meta(CUSTOM_META): return false
		if ancestor.has_meta(HOST_META): return ancestor == _host
		ancestor = ancestor.get_parent()
	return false

func _input(event: InputEvent) -> void:
	if _dispatching or not event is InputEventJoypadMotion or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		return
	if not _owns_focus(): return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	_device = event.device
	var action: StringName = &"ui_right" if event.axis == JOY_AXIS_LEFT_X else &"ui_down"
	_repeat.sample(event.axis, event.axis_value, InputMap.action_get_deadzone(action))
	set_process(not _repeat._axes.is_empty())
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _owns_focus():
		_repeat.reset()
		set_process(false)
		return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null or bool(router.call("using_controller")):
		_repeat.advance(delta)

func _step(axis: int, direction: int) -> void:
	if not _owns_focus(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is HSlider and axis == JOY_AXIS_LEFT_X:
		focused.value += direction * focused.step
		return
	var event := InputEventJoypadButton.new()
	event.device = _device
	event.button_index = (JOY_BUTTON_DPAD_RIGHT if direction > 0 else JOY_BUTTON_DPAD_LEFT) if axis == JOY_AXIS_LEFT_X else (JOY_BUTTON_DPAD_DOWN if direction > 0 else JOY_BUTTON_DPAD_UP)
	event.pressed = true
	_dispatching = true
	get_viewport().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	get_viewport().push_input(event, true)
	_dispatching = false
