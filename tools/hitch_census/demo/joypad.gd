extends RefCounted
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const DEVICE_ID: int = 0
const BUTTON_HOLD_S: float = 0.08
const SETTLE_S: float = 0.15
const STICK_MAGNITUDE: float = 0.65
const STICK_PULSE_S: float = 0.08
var session
var armed_accept: Dictionary
var counts: Dictionary = {"joypad_button": 0, "joypad_motion": 0, "pointer": 0, "keyboard": 0, "other_gameplay_state_injections": 0}
func _init(s) -> void: session = s
func focus_receipt() -> Dictionary:
	var focused: Control = session.root.gui_get_focus_owner()
	var scene: Node = session.current_scene
	return {"gui": focused.get_instance_id() if focused != null else 0, "candidate": str(scene.get("_controller_focus_candidate").get("key", "")) if scene != null and scene.get("_run_state") != null else "", "hand": scene.get("_controller_hand_index") if scene != null and scene.get("_run_state") != null else -1}
func arm_accept() -> void:
	armed_accept = {"state": Gate.witness(session.current_scene), "focus": focus_receipt()}
func send(event: InputEvent) -> void:
	assert(event is InputEventJoypadButton or event is InputEventJoypadMotion)
	event.set_meta(&"ux09_scripted_joypad", true)
	session.log_event("input", {"event": event.as_text(), "type": event.get_class(), "pressed": event.pressed if event is InputEventJoypadButton else false, "button": event.button_index if event is InputEventJoypadButton else -1, "axis": event.axis if event is InputEventJoypadMotion else -1, "axis_value": event.axis_value if event is InputEventJoypadMotion else 0.0, "device": event.device, "witness": Gate.witness(session.current_scene)})
	Input.parse_input_event(event)
func button(index: int) -> bool:
	var scene: Node = session.current_scene
	var intended: Dictionary = armed_accept.duplicate() if index == JOY_BUTTON_A else {}
	if index == JOY_BUTTON_A: armed_accept.clear()
	var expected: Dictionary = intended.get("state", Gate.witness(scene))
	var expected_focus: Control = session.root.gui_get_focus_owner()
	var expected_candidate: String = str(scene.get("_controller_focus_candidate").get("key", "")) if scene.get("_run_state") != null else ""
	await session.hold(SETTLE_S)
	if not is_instance_valid(scene) or scene != session.current_scene or expected != Gate.witness(scene) or not Gate.ready(scene):
		session.log_event("stale_input_cancelled", {"button": index})
		return false
	if index == JOY_BUTTON_A:
		if not intended.is_empty() and intended["focus"] != focus_receipt():
			session.log_event("stale_focus_cancelled", {"button": index, "armed": intended["focus"], "actual": focus_receipt()})
			return false
		var candidate: String = str(scene.get("_controller_focus_candidate").get("key", "")) if scene.get("_run_state") != null else ""
		if expected_focus != session.root.gui_get_focus_owner() or candidate != expected_candidate:
			session.log_event("stale_focus_cancelled", {"button": index})
			return false
	var event := InputEventJoypadButton.new()
	event.device = DEVICE_ID
	event.button_index = index
	event.pressed = true
	counts["joypad_button"] += 1
	send(event)
	await session.hold(BUTTON_HOLD_S)
	var released := event.duplicate() as InputEventJoypadButton
	released.pressed = false
	counts["joypad_button"] += 1
	send(released)
	await session.hold(SETTLE_S)
	return true
func motion(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = DEVICE_ID
	event.axis = axis
	event.axis_value = value
	counts["joypad_motion"] += 1
	send(event)
func pulse(direction: Vector2, seconds: float = STICK_PULSE_S) -> void:
	if not Gate.ready(session.current_scene): return
	motion(JOY_AXIS_LEFT_X, direction.x * STICK_MAGNITUDE)
	motion(JOY_AXIS_LEFT_Y, direction.y * STICK_MAGNITUDE)
	await session.hold(seconds)
	motion(JOY_AXIS_LEFT_X, 0.0)
	motion(JOY_AXIS_LEFT_Y, 0.0)
	await session.hold(SETTLE_S)
