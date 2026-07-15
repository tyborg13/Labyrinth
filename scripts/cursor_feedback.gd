extends CanvasLayer
class_name CursorFeedbackController

const CustomCursorGlyphScript = preload("res://scripts/custom_cursor_glyph.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const CONTEXT_META: String = "cursor_feedback_context"
const DRAG_SOURCE_META: String = "cursor_feedback_drag_source"
const CONTEXT_PROVIDER_META: String = "cursor_feedback_context_provider"
const CONTEXT_AT_METHOD: String = "cursor_feedback_context_at"
const DRAG_THRESHOLD: float = 7.0
const AUDIO_MIX_RATE: int = 44100
const VALID_CLICK_SECONDS: float = 0.082
const INVALID_CLICK_SECONDS: float = 0.105
const VALID_CLICK_VOLUME_DB: float = -7.0
const INVALID_CLICK_VOLUME_DB: float = -10.0
const SCENE_TRANSITION_LEAD_SECONDS: float = 0.11
const SCENE_TRANSITION_MINIMUM_SECONDS: float = 0.44

var _glyph: CustomCursorGlyph
var _audio_players: Array[AudioStreamPlayer] = []
var _audio_cursor: int = 0
var _valid_click_stream: AudioStreamWAV
var _invalid_click_stream: AudioStreamWAV
var _left_pressed: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _press_actionable: bool = false
var _press_drag_source: bool = false
var _drag_started: bool = false
var _drag_sound_pending: bool = false
var _manual_loading_depth: int = 0
var _loading_until_msec: int = 0
var _transition_generation: int = 0
var _last_feedback_kind: String = ""
var _feedback_counts: Dictionary = {"valid": 0, "invalid": 0}

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	_glyph = CustomCursorGlyphScript.new()
	_glyph.name = "ForgedCursorGlyph"
	add_child(_glyph)
	_create_audio_players()
	_valid_click_stream = build_click_stream(true)
	_invalid_click_stream = build_click_stream(false)
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	show_loading_for(0.34)
	set_process(true)

func _exit_tree() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _process(_delta: float) -> void:
	# Controls are free to request any native shape; the OS cursor remains hidden
	# and those semantic requests are translated into the forged cursor below.
	if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	if _glyph == null:
		return
	var viewport: Viewport = get_viewport()
	var pointer_position: Vector2 = viewport.get_mouse_position()
	_glyph.position = pointer_position - CustomCursorGlyph.HOTSPOT
	var window: Window = get_window()
	var pointer_inside: bool = viewport.get_visible_rect().grow(2.0).has_point(pointer_position)
	_glyph.visible = pointer_inside and (window == null or window.has_focus())
	_glyph.set_cursor_state(_resolved_cursor_state(viewport.gui_get_hovered_control(), pointer_position))

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton and not event is InputEventMouseMotion:
		return
	if event is InputEventMouseMotion:
		_update_drag_from_motion(event as InputEventMouseMotion)
		return
	var mouse_event := event as InputEventMouseButton
	if mouse_event.button_index != MOUSE_BUTTON_LEFT:
		return
	if mouse_event.pressed:
		_begin_pointer_press(mouse_event.position)
	else:
		_end_pointer_press()

func begin_loading() -> void:
	_manual_loading_depth += 1

func end_loading() -> void:
	_manual_loading_depth = maxi(0, _manual_loading_depth - 1)

func show_loading_for(seconds: float) -> void:
	var deadline: int = Time.get_ticks_msec() + int(round(maxf(0.0, seconds) * 1000.0))
	_loading_until_msec = maxi(_loading_until_msec, deadline)

func is_loading() -> bool:
	return _manual_loading_depth > 0 or Time.get_ticks_msec() < _loading_until_msec

func change_scene_to_file(path: String) -> void:
	_transition_generation += 1
	var generation: int = _transition_generation
	show_loading_for(SCENE_TRANSITION_MINIMUM_SECONDS)
	await get_tree().create_timer(SCENE_TRANSITION_LEAD_SECONDS, true, false, true).timeout
	if generation != _transition_generation or not is_inside_tree():
		return
	var result: Error = get_tree().change_scene_to_file(path)
	if result != OK:
		_loading_until_msec = 0
		push_error("CursorFeedback could not change scene to %s (error %d)" % [path, result])
		return
	await get_tree().process_frame
	if generation == _transition_generation and is_inside_tree():
		show_loading_for(0.18)

func last_feedback_kind() -> String:
	return _last_feedback_kind

func feedback_counts() -> Dictionary:
	return _feedback_counts.duplicate(true)

func glyph_for_test() -> CustomCursorGlyph:
	return _glyph

func _resolved_cursor_state(hovered: Control, pointer_position: Variant = null) -> String:
	if is_loading():
		return CustomCursorGlyph.STATE_LOADING
	if _left_pressed:
		if _press_drag_source and _drag_started:
			return CustomCursorGlyph.STATE_DRAGGING
		return CustomCursorGlyph.STATE_PRESSED_VALID if _press_actionable or _press_drag_source else CustomCursorGlyph.STATE_PRESSED_INVALID
	return state_for_context(context_for_control(hovered, pointer_position), false, false)

func _begin_pointer_press(position: Vector2) -> void:
	if _left_pressed or is_loading():
		return
	var context: Dictionary = context_for_control(get_viewport().gui_get_hovered_control(), position)
	_begin_pointer_press_with_context(position, context)

func _begin_pointer_press_with_context(position: Vector2, context: Dictionary) -> void:
	if _left_pressed or is_loading():
		return
	_left_pressed = true
	_press_position = position
	_press_actionable = bool(context.get("actionable", false))
	_press_drag_source = bool(context.get("drag_source", false))
	_drag_started = false
	_drag_sound_pending = _press_drag_source and not _press_actionable
	if _press_actionable:
		_play_click_feedback(true)
	elif not _drag_sound_pending:
		_play_click_feedback(false)

func _update_drag_from_motion(event: InputEventMouseMotion) -> void:
	if not _left_pressed or not _press_drag_source or _drag_started:
		return
	if event.position.distance_to(_press_position) < DRAG_THRESHOLD:
		return
	_drag_started = true
	if _drag_sound_pending:
		_drag_sound_pending = false
		_play_click_feedback(true)

func _end_pointer_press() -> void:
	if not _left_pressed:
		return
	if _drag_sound_pending:
		_play_click_feedback(false)
	_left_pressed = false
	_press_actionable = false
	_press_drag_source = false
	_drag_started = false
	_drag_sound_pending = false

func _play_click_feedback(valid: bool) -> void:
	var kind: String = "valid" if valid else "invalid"
	_last_feedback_kind = kind
	_feedback_counts[kind] = int(_feedback_counts.get(kind, 0)) + 1
	if _audio_players.is_empty():
		return
	var player: AudioStreamPlayer = _audio_players[_audio_cursor % _audio_players.size()]
	_audio_cursor += 1
	player.stop()
	player.stream = _valid_click_stream if valid else _invalid_click_stream
	player.volume_db = VALID_CLICK_VOLUME_DB if valid else INVALID_CLICK_VOLUME_DB
	player.play()

func _create_audio_players() -> void:
	for index: int in range(3):
		var player := AudioStreamPlayer.new()
		player.name = "CursorClickPlayer%d" % (index + 1)
		player.bus = SettingsStore.SFX_BUS
		add_child(player)
		_audio_players.append(player)

static func context_for_control(hovered: Control, pointer_position: Variant = null) -> Dictionary:
	var context: Dictionary = _empty_context()
	if hovered == null:
		return context
	var current: Control = hovered
	while current != null:
		var explicit_context: String = _context_provider_value(current, pointer_position)
		if explicit_context.is_empty():
			explicit_context = str(current.get_meta(CONTEXT_META, ""))
		if not explicit_context.is_empty():
			return _context_from_semantic(explicit_context, current.mouse_default_cursor_shape, bool(current.get_meta(DRAG_SOURCE_META, false)))

		if current is BaseButton:
			var button := current as BaseButton
			return _context_from_semantic("invalid" if button.disabled else "action", current.mouse_default_cursor_shape)
		if current is LineEdit or current is TextEdit:
			return _context_from_semantic("action", Control.CURSOR_IBEAM)
		if current is Range:
			return _context_from_semantic("action_drag", current.mouse_default_cursor_shape)
		if bool(current.get_meta(DRAG_SOURCE_META, false)):
			return _context_from_semantic("drag", current.mouse_default_cursor_shape)

		var shape: int = current.mouse_default_cursor_shape
		if shape != Control.CURSOR_ARROW:
			return _context_from_shape(shape)
		var parent_control: Control = current.get_parent() as Control
		current = parent_control
	return context

static func _empty_context() -> Dictionary:
	return {
		"actionable": false,
		"drag_source": false,
		"invalid": false,
		"loading": false,
		"shape": Control.CURSOR_ARROW
	}

static func _context_provider_value(control: Control, pointer_position: Variant) -> String:
	var has_method_provider: bool = control.has_method(CONTEXT_AT_METHOD)
	var has_meta_provider: bool = control.has_meta(CONTEXT_PROVIDER_META)
	if not has_method_provider and not has_meta_provider:
		return ""
	var local_position: Vector2 = Vector2.ZERO
	if pointer_position is Vector2:
		local_position = control.get_global_transform_with_canvas().affine_inverse() * (pointer_position as Vector2)
	elif control.is_inside_tree():
		local_position = control.get_local_mouse_position()
	if has_method_provider:
		return str(control.call(CONTEXT_AT_METHOD, local_position))
	var provider_var: Variant = control.get_meta(CONTEXT_PROVIDER_META)
	if provider_var is Callable:
		var provider: Callable = provider_var
		if provider.is_valid():
			return str(provider.call(local_position))
	return ""

static func _context_from_semantic(semantic: String, shape: int = Control.CURSOR_ARROW, force_drag: bool = false) -> Dictionary:
	var context: Dictionary = _empty_context()
	context["shape"] = shape
	match semantic:
		"action":
			context["actionable"] = true
		"drag":
			context["drag_source"] = true
		"action_drag":
			context["actionable"] = true
			context["drag_source"] = true
		"invalid":
			context["invalid"] = true
		"loading":
			context["loading"] = true
		"inert", "help":
			pass
	if force_drag and not bool(context.get("invalid", false)):
		context["drag_source"] = true
	return context

static func _context_from_shape(shape: int) -> Dictionary:
	match shape:
		Control.CURSOR_POINTING_HAND:
			return _context_from_semantic("action", shape)
		Control.CURSOR_HELP:
			# Help means that hover information exists; it does not promise that a
			# click performs an action.
			return _context_from_semantic("help", shape)
		Control.CURSOR_DRAG, Control.CURSOR_CAN_DROP:
			return _context_from_semantic("drag", shape)
		Control.CURSOR_MOVE, Control.CURSOR_HSIZE, Control.CURSOR_VSIZE, Control.CURSOR_BDIAGSIZE, Control.CURSOR_FDIAGSIZE:
			return _context_from_semantic("drag", shape)
		Control.CURSOR_FORBIDDEN:
			return _context_from_semantic("invalid", shape)
	return _empty_context()

static func state_for_context(context: Dictionary, pressed: bool, dragged: bool) -> String:
	if bool(context.get("loading", false)):
		return CustomCursorGlyph.STATE_LOADING
	if pressed:
		if dragged and bool(context.get("drag_source", false)):
			return CustomCursorGlyph.STATE_DRAGGING
		return CustomCursorGlyph.STATE_PRESSED_VALID if bool(context.get("actionable", false)) or bool(context.get("drag_source", false)) else CustomCursorGlyph.STATE_PRESSED_INVALID
	if bool(context.get("invalid", false)):
		return CustomCursorGlyph.STATE_INVALID
	if bool(context.get("drag_source", false)):
		return CustomCursorGlyph.STATE_DRAG_READY
	if bool(context.get("actionable", false)):
		return CustomCursorGlyph.STATE_ACTION
	return CustomCursorGlyph.STATE_IDLE

static func click_feedback_contract() -> Dictionary:
	return {
		"mix_rate": AUDIO_MIX_RATE,
		"valid_seconds": VALID_CLICK_SECONDS,
		"invalid_seconds": INVALID_CLICK_SECONDS,
		"valid_volume_db": VALID_CLICK_VOLUME_DB,
		"invalid_volume_db": INVALID_CLICK_VOLUME_DB,
		"valid_character": "bright forged-metal double tick",
		"invalid_character": "damped ash-and-wood knock",
		"bus": SettingsStore.SFX_BUS
	}

static func build_click_stream(valid: bool) -> AudioStreamWAV:
	var seconds: float = VALID_CLICK_SECONDS if valid else INVALID_CLICK_SECONDS
	var frame_count: int = int(ceil(seconds * float(AUDIO_MIX_RATE)))
	var bytes := PackedByteArray()
	bytes.resize(frame_count * 4)
	var noise_state: int = 739391
	for frame: int in range(frame_count):
		var time: float = float(frame) / float(AUDIO_MIX_RATE)
		noise_state = posmod(noise_state * 48271, 2147483647)
		var noise: float = float(noise_state) / 1073741823.5 - 1.0
		var left: float
		var right: float
		if valid:
			var first_envelope: float = exp(-time * 46.0)
			var first_tone: float = sin(TAU * 1180.0 * time) * 0.34 + sin(TAU * 1760.0 * time + 0.28) * 0.20
			var body: float = sin(TAU * 390.0 * time) * exp(-time * 31.0) * 0.22
			var second_time: float = maxf(0.0, time - 0.021)
			var second_gate: float = 1.0 if time >= 0.021 else 0.0
			var second: float = sin(TAU * 1450.0 * second_time) * exp(-second_time * 62.0) * 0.19 * second_gate
			var sample: float = (first_tone * first_envelope + body + second + noise * exp(-time * 78.0) * 0.055) * 0.82
			left = sample
			right = sample * 0.94 + sin(TAU * 1240.0 * time + 0.14) * first_envelope * 0.035
		else:
			var thump_envelope: float = exp(-time * 27.0)
			var thump: float = sin(TAU * (168.0 - time * 260.0) * time) * 0.43
			var knock: float = sin(TAU * 286.0 * time + 0.36) * exp(-time * 39.0) * 0.16
			var grit: float = noise * exp(-time * 58.0) * 0.085
			var sample: float = (thump * thump_envelope + knock + grit) * 0.70
			left = sample
			right = sample * 0.91
		bytes.encode_s16(frame * 4, int(round(clampf(left, -0.98, 0.98) * 32767.0)))
		bytes.encode_s16(frame * 4 + 2, int(round(clampf(right, -0.98, 0.98) * 32767.0)))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AUDIO_MIX_RATE
	stream.stereo = true
	stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	stream.data = bytes
	return stream
