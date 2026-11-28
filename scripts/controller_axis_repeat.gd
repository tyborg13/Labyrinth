extends RefCounted
## Digital and analog holds share the same game-time cadence.
signal stepped(axis: int, direction: int)

const RELEASE_THRESHOLD: float = 0.30
const INITIAL_DELAY_SECONDS: float = 0.40
const REPEAT_INTERVAL_SECONDS: float = 0.12
const TIME_EPSILON_SECONDS: float = 0.000001
const SYNTHETIC_PRESS: StringName = &"controller_synthetic_direction"
const DPAD_REPEAT: StringName = &"controller_dpad_repeat"
const REGION_META: StringName = &"controller_repeat_region"
const ORDER_META: StringName = &"controller_repeat_order"

var _axes: Dictionary = {}
var _suppressed_axes: Dictionary = {}
var _dpad_button: int = -1
var _dpad_device: int
var _dpad_elapsed: float
var _dpad_next: float
var _dpad_viewport: WeakRef
var _dpad_can_step: Callable

func sample(axis: int, value: float, enter_threshold: float) -> void:
	if absf(value) < RELEASE_THRESHOLD:
		_axes.erase(axis)
		_suppressed_axes.erase(axis)
	elif not _axes.has(axis) and absf(value) >= enter_threshold:
		if _suppressed_axes.has(axis): return
		stop_dpad()
		var direction: int = int(signf(value))
		_axes[axis] = {"direction": direction, "elapsed": 0.0, "next": INITIAL_DELAY_SECONDS}
		stepped.emit(axis, direction)

func advance(delta: float) -> void:
	if _dpad_button >= 0:
		_advance_dpad(delta)
		return
	for axis: int in _axes.keys():
		if not _axes.has(axis): continue
		var held: Dictionary = _axes[axis]
		held["elapsed"] += delta
		while float(held["elapsed"]) + TIME_EPSILON_SECONDS >= float(held["next"]):
			held["next"] += REPEAT_INTERVAL_SECONDS
			stepped.emit(axis, int(held["direction"]))
			if not _axes.has(axis): break

func reset() -> void:
	_axes.clear()
	_suppressed_axes.clear()
	stop_dpad()

func active() -> bool:
	return dpad_active() or not _axes.is_empty()

func dpad_active() -> bool:
	return _dpad_button >= 0

func stop_dpad() -> void:
	_dpad_button = -1
	_dpad_viewport = null
	_dpad_can_step = Callable()

func observe_dpad(event: InputEvent, viewport: Viewport, can_step: Callable, fresh_step_allowed: bool = true) -> void:
	if not event is InputEventJoypadButton or event.has_meta(SYNTHETIC_PRESS): return
	var button: int = event.button_index
	if not event.pressed:
		if button == _dpad_button and event.device == _dpad_device: stop_dpad()
		return
	stop_dpad()
	if dpad_side(button) < 0: return
	for axis: int in _axes:
		_suppressed_axes[axis] = true
	_axes.clear()
	if not fresh_step_allowed or not bool(can_step.call(button)): return
	_dpad_button = button
	_dpad_device = event.device
	_dpad_elapsed = 0.0
	_dpad_next = INITIAL_DELAY_SECONDS
	_dpad_viewport = weakref(viewport)
	_dpad_can_step = can_step

func _advance_dpad(delta: float) -> void:
	_dpad_elapsed += delta
	while _dpad_button >= 0 and _dpad_elapsed + TIME_EPSILON_SECONDS >= _dpad_next:
		var viewport: Viewport = _dpad_viewport.get_ref()
		if viewport == null or not _dpad_can_step.is_valid() or not bool(_dpad_can_step.call(_dpad_button)):
			stop_dpad()
			return
		_dpad_next += REPEAT_INTERVAL_SECONDS
		push_direction(viewport, _dpad_button, _dpad_device, true)

static func push_direction(viewport: Viewport, button: int, device: int, repeating_dpad: bool = false) -> void:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = button as JoyButton
	event.pressed = true
	event.set_meta(SYNTHETIC_PRESS, true)
	if repeating_dpad: event.set_meta(DPAD_REPEAT, true)
	viewport.push_input(event, true)
	if not repeating_dpad:
		event = event.duplicate()
		event.pressed = false
		viewport.push_input(event, true)

static func dpad_side(button: int) -> int:
	match button:
		JOY_BUTTON_DPAD_LEFT: return SIDE_LEFT
		JOY_BUTTON_DPAD_UP: return SIDE_TOP
		JOY_BUTTON_DPAD_RIGHT: return SIDE_RIGHT
		JOY_BUTTON_DPAD_DOWN: return SIDE_BOTTOM
	return -1

static func dpad_direction(button: int) -> Vector2:
	match dpad_side(button):
		SIDE_LEFT: return Vector2.LEFT
		SIDE_TOP: return Vector2.UP
		SIDE_RIGHT: return Vector2.RIGHT
		SIDE_BOTTOM: return Vector2.DOWN
	return Vector2.ZERO

static func focus_region(control: Control, scope: Control) -> Variant:
	if control == null or scope == null: return null
	if control != scope and not scope.is_ancestor_of(control): return null
	var node: Node = control
	while node != scope:
		if node.has_meta(REGION_META):
			var region: Variant = node.get_meta(REGION_META)
			return node if region is bool else region
		node = node.get_parent()
	return scope

static func mark_region(controls: Array, region: StringName, ordered_axis: int = -1) -> void:
	for index: int in range(controls.size()):
		var control: Control = controls[index]
		if control == null: continue
		control.set_meta(REGION_META, region)
		if ordered_axis >= 0: control.set_meta(ORDER_META, Vector2i(ordered_axis, index))

static func can_focus_step(control: Control, button: int, scope: Control) -> bool:
	var side: int = dpad_side(button)
	if control == null or side < 0: return false
	var target: Control = control.find_valid_focus_neighbor(side as Side)
	var region: Variant = focus_region(control, scope)
	if target == null or target == control or region == null or not is_same(focus_region(target, scope), region): return false
	var direction: Vector2 = dpad_direction(button)
	var axis: int = Vector2.AXIS_X if direction.x != 0.0 else Vector2.AXIS_Y
	var source_order: Vector2i = control.get_meta(ORDER_META, Vector2i(-1, -1))
	var target_order: Vector2i = target.get_meta(ORDER_META, Vector2i(-1, -1))
	if source_order.x == axis and target_order.x == axis:
		return float(target_order.y - source_order.y) * direction[axis] > 0.0
	# An explicit neighbor can wrap in the direction opposite to the input.
	var offset: Vector2 = target.get_global_rect().get_center() - control.get_global_rect().get_center()
	return offset.dot(direction) > 0.0
