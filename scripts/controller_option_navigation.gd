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
var _last_focused_item: int = -1
const NATIVE_STEP: StringName = &"controller_option_native_step"

static func install(option: OptionButton) -> void:
	var navigation := new()
	navigation.name = "ControllerOptionNavigation"
	navigation._popup = option.get_popup()
	navigation._popup.add_child(navigation)

func _ready() -> void:
	_repeat.stepped.connect(_step)
	_popup.about_to_popup.connect(_reserve_bindings)
	_popup.popup_hide.connect(_release_bindings)
	_popup.window_input.connect(_observe_native_input)

func _reserve_bindings() -> void:
	if _claimed: return
	_claimed = true
	_last_focused_item = _popup.get_focused_item()
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT: _repeat.stop_dpad()

func _observe_native_input(event: InputEvent) -> void:
	# Embedded and native windows handle their PopupMenu input before Node input.
	var current: int = _popup.get_focused_item()
	if event is InputEventJoypadButton and event.pressed and _vertical_direction(event.button_index) != 0:
		if current != _last_focused_item:
			var direction: int = _vertical_direction(event.button_index)
			_repeat.observe_dpad(event, _popup, _can_step_dpad, (current - _last_focused_item) * direction > 0)
			event.set_meta(NATIVE_STEP, true)
	_last_focused_item = current

func _input(event: InputEvent) -> void:
	if not _popup.visible: return
	var router: Node = get_node_or_null("/root/InputRouter")
	if event is InputEventJoypadButton:
		if event.has_meta(NATIVE_STEP): return
		_repeat.observe_dpad(event, _popup, _can_step_dpad)
		var direction: int = _vertical_direction(event.button_index)
		if direction != 0 and event.pressed:
			if router != null: router.call("record_input_activity", event)
			_step(JOY_AXIS_LEFT_Y, direction)
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventJoypadMotion: return
	if event.axis == JOY_AXIS_LEFT_X and absf(event.axis_value) >= _enter_threshold: _repeat.stop_dpad()
	if event.axis != JOY_AXIS_LEFT_Y: return
	if router != null: router.call("record_input_activity", event)
	_repeat.sample(event.axis, event.axis_value, _enter_threshold)
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not _popup.visible: return
	_last_focused_item = _popup.get_focused_item()
	var router: Node = get_node_or_null("/root/InputRouter")
	if router == null or bool(router.call("using_controller")):
		_repeat.advance(delta)
	else:
		_repeat.stop_dpad()

func _step(_axis: int, direction: int) -> void:
	var index: int = _next_item(direction, true)
	if index < 0: return
	_popup.set_focused_item(index)
	_popup.id_focused.emit(_popup.get_item_id(index))
	_last_focused_item = index

func _can_step_dpad(button: int) -> bool:
	var direction: int = _vertical_direction(button)
	return _popup.visible and direction != 0 and _next_item(direction, false) >= 0

func _vertical_direction(button: int) -> int:
	return int(AxisRepeat.dpad_direction(button).y)

func _next_item(direction: int, wrap: bool) -> int:
	var index: int = _popup.get_focused_item()
	for offset: int in range(_popup.item_count):
		index += direction
		if wrap: index = posmod(index, _popup.item_count)
		elif index < 0 or index >= _popup.item_count: return -1
		if not _popup.is_item_disabled(index) and not _popup.is_item_separator(index):
			return index
	return -1
