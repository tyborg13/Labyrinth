extends Node

signal modality_changed(modality: String)
signal controller_family_changed(family: String)

const MODALITY_POINTER: String = "pointer"
const MODALITY_CONTROLLER: String = "controller"

const FAMILY_XBOX: String = "xbox"
const FAMILY_STEAM_DECK: String = "steam_deck"

const ACTION_ACCEPT: StringName = &"controller_accept"
const ACTION_CANCEL: StringName = &"controller_cancel"
const ACTION_HAND_TOGGLE: StringName = &"controller_hand_toggle"
const ACTION_PASS: StringName = &"controller_pass"
const ACTION_HAND_PREVIOUS: StringName = &"controller_hand_previous"
const ACTION_HAND_NEXT: StringName = &"controller_hand_next"
const ACTION_HAND_BUMPERS: StringName = &"controller_hand_bumpers"
const ACTION_MENU: StringName = &"controller_menu"
const ACTION_MAP: StringName = &"controller_map"
const ACTION_MAP_ZOOM: StringName = &"controller_map_zoom"

const JOYSTICK_ACTIVITY_THRESHOLD: float = 0.42
const POINTER_ACTIVITY_THRESHOLD: float = 2.0
const POINTER_HANDOFF_GRACE_MSEC: int = 500

const STEAM_INPUT_TYPE_XBOX360_CONTROLLER: int = 2
const STEAM_INPUT_TYPE_XBOXONE_CONTROLLER: int = 3
const STEAM_INPUT_TYPE_GENERIC_XINPUT: int = 4
const STEAM_INPUT_TYPE_STEAM_DECK_CONTROLLER: int = 14

var _modality: String = MODALITY_POINTER
var _controller_family: String = FAMILY_XBOX
var _active_device_id: int = -1
var _forced_family_for_test: String = ""
var _forced_modality_for_test: String = ""
var _last_controller_activity_msec: int = -10000
var _steam_input_initialized: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	ensure_input_map()
	Input.joy_connection_changed.connect(_on_joy_connection_changed)
	_refresh_connected_family()

func _input(event: InputEvent) -> void:
	# GUI probes share the host's real input stream. A forced test state must stay
	# deterministic until the probe explicitly authors its next modality.
	if not _forced_modality_for_test.is_empty():
		return
	if event is InputEventJoypadButton:
		var button_event := event as InputEventJoypadButton
		if button_event.pressed:
			mark_controller_device(button_event.device)
		return
	if event is InputEventJoypadMotion:
		var motion_event := event as InputEventJoypadMotion
		if absf(motion_event.axis_value) >= JOYSTICK_ACTIVITY_THRESHOLD:
			mark_controller_device(motion_event.device)
		return
	if event is InputEventMouseButton:
		if (event as InputEventMouseButton).pressed:
			set_modality(MODALITY_POINTER)
		return
	if event is InputEventMouseMotion:
		if (
			(event as InputEventMouseMotion).relative.length() >= POINTER_ACTIVITY_THRESHOLD
			and Time.get_ticks_msec() - _last_controller_activity_msec >= POINTER_HANDOFF_GRACE_MSEC
		):
			set_modality(MODALITY_POINTER)
		return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		set_modality(MODALITY_POINTER)

func modality() -> String:
	return _modality

func using_controller() -> bool:
	return _modality == MODALITY_CONTROLLER

func controller_family() -> String:
	return _forced_family_for_test if not _forced_family_for_test.is_empty() else _controller_family

func active_device_id() -> int:
	return _active_device_id

func set_modality(next_modality: String) -> void:
	var normalized: String = MODALITY_CONTROLLER if next_modality == MODALITY_CONTROLLER else MODALITY_POINTER
	if _modality == normalized:
		return
	_modality = normalized
	modality_changed.emit(_modality)

func mark_controller_device(device_id: int) -> void:
	_last_controller_activity_msec = Time.get_ticks_msec()
	_active_device_id = device_id
	var next_family: String = family_for_device(device_id)
	if _controller_family != next_family:
		_controller_family = next_family
		controller_family_changed.emit(controller_family())
	set_modality(MODALITY_CONTROLLER)

func family_for_device(device_id: int) -> String:
	var steam_input_family: String = _family_from_steam_input(device_id)
	if not steam_input_family.is_empty():
		return steam_input_family
	var joy_name: String = Input.get_joy_name(device_id)
	var info: Dictionary = Input.get_joy_info(device_id)
	var raw_name: String = str(info.get("raw_name", ""))
	return family_for_device_name("%s %s" % [joy_name, raw_name], platform_is_steam_deck())

func _family_from_steam_input(device_id: int) -> String:
	if device_id < 0 or not Engine.has_singleton("Steam"):
		return ""
	var steam_service: Node = get_node_or_null("/root/SteamService")
	if (
		steam_service == null
		or not steam_service.has_method("is_steam_active")
		or not bool(steam_service.call("is_steam_active"))
	):
		return ""
	var steam: Object = Engine.get_singleton("Steam")
	if steam == null or not steam.has_method("getControllerForGamepadIndex") or not steam.has_method("getInputTypeForHandle"):
		return ""
	if not _steam_input_initialized:
		if not steam.has_method("inputInit"):
			return ""
		_steam_input_initialized = bool(steam.call("inputInit", false))
	if not _steam_input_initialized:
		return ""
	var handle: int = int(steam.call("getControllerForGamepadIndex", device_id))
	if handle <= 0:
		return ""
	return family_for_steam_input_type(int(steam.call("getInputTypeForHandle", handle)))

func force_family_for_test(family: String) -> void:
	var normalized: String = family if family in [FAMILY_XBOX, FAMILY_STEAM_DECK] else ""
	if _forced_family_for_test == normalized:
		return
	_forced_family_for_test = normalized
	controller_family_changed.emit(controller_family())

func clear_forced_family_for_test() -> void:
	force_family_for_test("")

func glyph_label(action_name: StringName, family_override: String = "") -> String:
	var family: String = family_override if family_override in [FAMILY_XBOX, FAMILY_STEAM_DECK] else controller_family()
	return glyph_label_for_family(action_name, family)

static func glyph_label_for_family(action_name: StringName, family: String) -> String:
	match action_name:
		ACTION_ACCEPT:
			return "A"
		ACTION_CANCEL:
			return "B"
		ACTION_HAND_TOGGLE:
			return "X"
		ACTION_PASS:
			return "Y"
		ACTION_HAND_PREVIOUS:
			return "L1" if family == FAMILY_STEAM_DECK else "LB"
		ACTION_HAND_NEXT:
			return "R1" if family == FAMILY_STEAM_DECK else "RB"
		ACTION_HAND_BUMPERS:
			return "L1·R1" if family == FAMILY_STEAM_DECK else "LB·RB"
		ACTION_MENU:
			return "≡"
		ACTION_MAP:
			return "▣"
		ACTION_MAP_ZOOM:
			return "L2·R2" if family == FAMILY_STEAM_DECK else "LT·RT"
		&"controller_move":
			return "LS"
		&"controller_dpad":
			return "+"
	return "?"

func set_forced_state_for_test(next_modality: String, family: String) -> void:
	_forced_modality_for_test = MODALITY_CONTROLLER if next_modality == MODALITY_CONTROLLER else MODALITY_POINTER
	force_family_for_test(family)
	set_modality(_forced_modality_for_test)

func clear_forced_state_for_test() -> void:
	_forced_modality_for_test = ""
	clear_forced_family_for_test()

func _refresh_connected_family() -> void:
	var devices: Array[int] = Input.get_connected_joypads()
	if devices.is_empty():
		return
	_active_device_id = devices[0]
	var next_family: String = family_for_device(_active_device_id)
	if _controller_family == next_family:
		return
	_controller_family = next_family
	controller_family_changed.emit(controller_family())

func _on_joy_connection_changed(device_id: int, connected: bool) -> void:
	if connected:
		_active_device_id = device_id
		var next_family: String = family_for_device(device_id)
		if _controller_family != next_family:
			_controller_family = next_family
			controller_family_changed.emit(controller_family())
		return
	if device_id == _active_device_id:
		_active_device_id = -1
		_refresh_connected_family()

static func platform_is_steam_deck() -> bool:
	if OS.get_environment("SteamDeck") == "1":
		return true
	var steam_disabled: bool = OS.get_environment("LABYRINTH_DISABLE_STEAM").strip_edges().to_lower() in ["1", "true", "yes"]
	if not steam_disabled and Engine.has_singleton("Steam"):
		var steam: Object = Engine.get_singleton("Steam")
		if steam != null and steam.has_method("isSteamRunningOnSteamDeck") and bool(steam.call("isSteamRunningOnSteamDeck")):
			return true
	var model: String = OS.get_model_name().to_lower()
	return "steam deck" in model or "jupiter" in model

static func is_controller_event(event: InputEvent) -> bool:
	return event is InputEventJoypadButton or event is InputEventJoypadMotion

static func family_for_device_name(device_name: String, deck_platform: bool = false) -> String:
	var normalized: String = device_name.strip_edges().to_lower()
	if "xbox" in normalized or "xinput" in normalized or "microsoft" in normalized:
		return FAMILY_XBOX
	if "steam deck" in normalized or "steam virtual" in normalized or "steam controller" in normalized:
		return FAMILY_STEAM_DECK
	if deck_platform and (normalized.is_empty() or "gamepad" in normalized or "controller" in normalized):
		return FAMILY_STEAM_DECK
	return FAMILY_XBOX

static func family_for_steam_input_type(input_type: int) -> String:
	if input_type == STEAM_INPUT_TYPE_STEAM_DECK_CONTROLLER:
		return FAMILY_STEAM_DECK
	if input_type in [STEAM_INPUT_TYPE_XBOX360_CONTROLLER, STEAM_INPUT_TYPE_XBOXONE_CONTROLLER, STEAM_INPUT_TYPE_GENERIC_XINPUT]:
		return FAMILY_XBOX
	return ""

static func ensure_input_map() -> void:
	_ensure_button_action(ACTION_ACCEPT, JOY_BUTTON_A)
	_ensure_button_action(ACTION_CANCEL, JOY_BUTTON_B)
	_ensure_button_action(ACTION_HAND_TOGGLE, JOY_BUTTON_X)
	_ensure_button_action(ACTION_PASS, JOY_BUTTON_Y)
	_ensure_button_action(ACTION_HAND_PREVIOUS, JOY_BUTTON_LEFT_SHOULDER)
	_ensure_button_action(ACTION_HAND_NEXT, JOY_BUTTON_RIGHT_SHOULDER)
	_ensure_button_action(ACTION_MENU, JOY_BUTTON_START)
	_ensure_button_action(ACTION_MAP, JOY_BUTTON_BACK)
	_ensure_button_action(&"ui_accept", JOY_BUTTON_A)
	_ensure_button_action(&"ui_cancel", JOY_BUTTON_B)
	_ensure_button_action(&"ui_left", JOY_BUTTON_DPAD_LEFT)
	_ensure_button_action(&"ui_right", JOY_BUTTON_DPAD_RIGHT)
	_ensure_button_action(&"ui_up", JOY_BUTTON_DPAD_UP)
	_ensure_button_action(&"ui_down", JOY_BUTTON_DPAD_DOWN)
	_ensure_axis_action(&"ui_left", JOY_AXIS_LEFT_X, -1.0)
	_ensure_axis_action(&"ui_right", JOY_AXIS_LEFT_X, 1.0)
	_ensure_axis_action(&"ui_up", JOY_AXIS_LEFT_Y, -1.0)
	_ensure_axis_action(&"ui_down", JOY_AXIS_LEFT_Y, 1.0)

static func _ensure_button_action(action_name: StringName, button_index: int) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button_index:
			return
	var joy_event := InputEventJoypadButton.new()
	joy_event.button_index = button_index
	InputMap.action_add_event(action_name, joy_event)

static func _ensure_axis_action(action_name: StringName, axis: int, axis_value: float) -> void:
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
	for event: InputEvent in InputMap.action_get_events(action_name):
		if event is InputEventJoypadMotion:
			var motion_event := event as InputEventJoypadMotion
			if motion_event.axis == axis and is_equal_approx(motion_event.axis_value, axis_value):
				return
	var joy_event := InputEventJoypadMotion.new()
	joy_event.axis = axis
	joy_event.axis_value = axis_value
	InputMap.action_add_event(action_name, joy_event)
