extends Node
## Reuse each screen's native D-pad route for both kinds of directional holds.
const AxisRepeat = preload("res://scripts/controller_axis_repeat.gd")
const HOST_META: String = "controller_gui_navigation_host"
const CUSTOM_META: String = "controller_custom_analog_navigation"
const CUSTOM_DPAD_META: String = "controller_custom_dpad_navigation"

var _host: Control
var _available: Callable
var _scope: Callable
var _repeat := AxisRepeat.new()
var _dispatching: bool = false
var _device: int = 0
var _dpad_scope: Control
var _dpad_region: Variant

static func install(host: Control, available: Callable = Callable(), scope: Callable = Callable()) -> Node:
	var navigation := new()
	navigation.name = "ControllerGuiNavigation"
	navigation._host = host
	navigation._available = available
	navigation._scope = scope
	host.set_meta(HOST_META, true)
	host.add_child(navigation)
	return navigation

func _ready() -> void:
	_repeat.stepped.connect(_step)
	_host.visibility_changed.connect(_reset_if_hidden)
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	set_process(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_repeat.stop_dpad()

func _reset_if_hidden() -> void:
	if not _host.is_visible_in_tree(): _repeat.reset()

func _on_focus_changed(focused: Control) -> void:
	if _repeat.dpad_active() and (_focus_scope() != _dpad_scope or not is_same(AxisRepeat.focus_region(focused, _dpad_scope), _dpad_region)):
		_repeat.stop_dpad()

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
	if _dispatching: return
	if not _owns_focus(): return
	if event is InputEventJoypadButton:
		if event.pressed and AxisRepeat.dpad_side(event.button_index) >= 0 and not event.has_meta(AxisRepeat.SYNTHETIC_PRESS):
			_dpad_scope = _focus_scope()
			_dpad_region = AxisRepeat.focus_region(get_viewport().gui_get_focus_owner(), _dpad_scope)
		_repeat.observe_dpad(event, get_viewport(), _can_step_dpad)
		set_process(_repeat.active())
		return
	if not event is InputEventJoypadMotion or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]: return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	_device = event.device
	var action: StringName = &"ui_right" if event.axis == JOY_AXIS_LEFT_X else &"ui_down"
	_repeat.sample(event.axis, event.axis_value, InputMap.action_get_deadzone(action))
	set_process(_repeat.active())
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _owns_focus():
		_repeat.reset()
		set_process(false)
		return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null or bool(router.call("using_controller")):
		_repeat.advance(delta)
	else:
		_repeat.stop_dpad()
	set_process(_repeat.active())

func _focus_scope() -> Control:
	return _scope.call() if _scope.is_valid() else _host

func _can_step_dpad(button: int) -> bool:
	if not _owns_focus() or _focus_scope() != _dpad_scope: return false
	var focused: Control = get_viewport().gui_get_focus_owner()
	if _dpad_region == null or not is_same(AxisRepeat.focus_region(focused, _dpad_scope), _dpad_region): return false
	var ancestor: Node = focused
	while ancestor != _dpad_scope:
		if ancestor.has_meta(CUSTOM_DPAD_META): return false
		ancestor = ancestor.get_parent()
	if focused is HSlider:
		if button == JOY_BUTTON_DPAD_LEFT: return not is_equal_approx(focused.value, focused.min_value)
		if button == JOY_BUTTON_DPAD_RIGHT: return not is_equal_approx(focused.value, focused.max_value)
	# A search field owns fresh directional actions, including leaving the field.
	if focused is LineEdit or focused is TextEdit: return false
	return AxisRepeat.can_focus_step(focused, button, _dpad_scope)

func _step(axis: int, direction: int) -> void:
	if not _owns_focus(): return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused is HSlider and axis == JOY_AXIS_LEFT_X:
		focused.value += direction * focused.step
		return
	var button: int = (JOY_BUTTON_DPAD_RIGHT if direction > 0 else JOY_BUTTON_DPAD_LEFT) if axis == JOY_AXIS_LEFT_X else (JOY_BUTTON_DPAD_DOWN if direction > 0 else JOY_BUTTON_DPAD_UP)
	_dispatching = true
	AxisRepeat.push_direction(get_viewport(), button, _device)
	_dispatching = false
