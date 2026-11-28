extends RefCounted
## Observe submitted presentation state. Native also pairs each row with the
## actual framebuffer, while headless verifies the structural blend contract.

const MAX_FRAME_MS := 50.0
const MAP_SIZE_TOLERANCE := 1.0
const MAP_ALPHA_EPSILON := 0.001
const QUIT_MID_BLEND_FRAMES := 5

var destination: String
var ready_ms: float = -1.0
var steady_ms: float = -1.0
var _started: int
var _reveal_ms: float = -1.0
var _handoff_ms: float = -1.0
var _reveal_frame: int = -1
var _handoff_frame: int = -1
var _input_ready_frame: int = -1
var _dark_frames: int
var _room_frames: int
var _cover_blend_frames: int
var _fade_count: int
var _saw_destination_fade: bool
var _max_frame_ms: float
var _covered_steady: bool
var _ready_at_reveal: bool
var _frames: Array[Dictionary]


func _init(expected: String, started: int) -> void:
	destination = expected
	_started = started
	# Native media captures this frame immediately before the activating press.
	_frames.append({"ms": 0.0, "phase": "title", "room": false})


func watch(cover: CanvasLayer) -> void:
	cover.phase_changed.connect(_on_phase.bind(cover))


func elapsed_ms() -> float:
	return (Time.get_ticks_usec() - _started) / 1000.0


func _on_phase(phase: StringName, cover: CanvasLayer) -> void:
	if phase == &"revealing":
		_reveal_ms = elapsed_ms()
		_reveal_frame = Engine.get_process_frames()
		_ready_at_reveal = _covered_steady and cover.destination.initial_presentation_is_ready()
	elif phase == &"complete":
		_handoff_ms = elapsed_ms()
		_handoff_frame = Engine.get_process_frames()


func mark_ready() -> void:
	ready_ms = elapsed_ms()
	_input_ready_frame = Engine.get_process_frames()


func _end_is_drawable(scene: Node) -> bool:
	if scene == null or not scene.initial_presentation_is_ready(): return false
	match destination:
		"map":
			var scrim: ColorRect = scene._large_map_scrim
			var viewport_size: Vector2 = scene.get_viewport_rect().size
			return scrim.visible and scrim.modulate.a >= 1.0 - MAP_ALPHA_EPSILON and scrim.color.a == 1.0 \
				and (scrim.size - viewport_size).length() <= MAP_SIZE_TOLERANCE and is_zero_approx(scene.room_title.self_modulate.a)
		"event_choices", "event_result":
			var event: Control = scene._event_view
			return event != null and event.visible and not event._busy and is_equal_approx(event.art.modulate.a, 1.0)
		"combat": return not scene.board_view.combat_state.is_empty() and scene.hand_row.visible
		"dialogue": return scene._dialogue_active and scene._dialogue_overlay.visible
		"section":
			return is_instance_valid(scene._section_transition) and scene._section_transition._surface.visible
		"prebattle": return scene._pre_battle_scrim.visible and is_equal_approx(scene._pre_battle_scrim.modulate.a, 1.0)
		"shop": return scene._scavenger_shop_view != null and scene._scavenger_shop_view.visible
		"treasure": return not scene._treasure_reveal_active and scene._relic_choice_host.visible
		_: return not scene.board_view.combat_state.get("grid", []).is_empty()


func sample(cover: Variant, scene: Node) -> Dictionary:
	var ms: float = elapsed_ms()
	var phase: String = "complete" if not is_instance_valid(cover) else str(cover.phase)
	var target: Node = scene
	var cover_alpha: float = 0.0
	var grouped: bool = false
	if phase != "complete":
		target = cover.destination
		grouped = cover._surface.self_modulate.a < 1.0
		cover_alpha = cover._surface.self_modulate.a if grouped else cover._surface.modulate.a
	var drawable: bool = _end_is_drawable(target) and (
		destination != "section" or phase == "complete" or cover.layer > target._section_transition.layer
	)
	var revealing: bool = _reveal_ms >= 0.0
	var room: bool = revealing and cover_alpha < 1.0 and destination == "map" and not drawable
	if not revealing: _covered_steady = drawable
	elif steady_ms < 0.0:
		_max_frame_ms = maxf(_max_frame_ms, ms - float(_frames.back()["ms"]))
		if phase == "revealing" and cover_alpha > 0.0 and cover_alpha < 1.0:
			if _cover_blend_frames == 0: _fade_count += 1
			_cover_blend_frames += 1
			# This counts unsafe blend samples. Only native measures luminance.
			if not grouped or not drawable: _dark_frames += 1
		if room: _room_frames += 1
		if not drawable and ((destination == "map" and target != null and target._large_map_scrim.visible)
				or (destination == "prebattle" and target != null and target._pre_battle_scrim.visible)
				or (destination.begins_with("event_") and target != null and is_instance_valid(target._event_view))):
			if not _saw_destination_fade: _fade_count += 1
			_saw_destination_fade = true
		if phase == "complete" and drawable: steady_ms = ms
	var frame := {"ms": ms, "phase": phase, "room": room, "alpha": cover_alpha}
	_frames.append(frame)
	return frame


func should_quit(point: String) -> bool:
	return _reveal_ms >= 0.0 and _handoff_ms < 0.0 and (point == "start" or _cover_blend_frames >= QUIT_MID_BLEND_FRAMES)


func record(label: String) -> Dictionary:
	return {"case": label, "frames": _frames, "reveal_ms": _reveal_ms, "ready_ms": ready_ms,
		"steady_ms": steady_ms, "handoff_ms": _handoff_ms, "room_frames": _room_frames,
		"max_frame_ms": _max_frame_ms}


func checks(reduced: bool, duration: float) -> Dictionary:
	var duration_ms: float = _handoff_ms - _reveal_ms
	return {
		"unsafe_blend_frames": [_dark_frames, _dark_frames == 0],
		"room_frames": [_room_frames, _room_frames == 0],
		"fades": [_fade_count, _fade_count == (0 if reduced else 1)],
		"covered_first_screen": [_ready_at_reveal, _ready_at_reveal],
		"ready_ms": [roundi(ready_ms), ready_ms >= 0.0 and _input_ready_frame - _handoff_frame <= 1],
		"reveal_ms": [roundi(duration_ms), _reveal_frame == _handoff_frame if reduced else absf(duration_ms - duration * 1000.0) <= MAX_FRAME_MS],
		"max_frame_ms": [snappedf(_max_frame_ms, 0.1), steady_ms >= 0.0 and _max_frame_ms <= MAX_FRAME_MS],
	}
