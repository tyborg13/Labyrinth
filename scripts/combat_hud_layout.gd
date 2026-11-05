extends RefCounted
## One home per deal (hud-01 / pol-37). Reserve every smaller fan and controller
## focus up front; only a larger draw, a new combat/turn or display change reflows.

const HandFan = preload("res://scripts/hand_fan_container.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

var right_column := preload("res://scripts/combat_hud_right_column.gd").new()

var _turn_key: String = ""
var _dealt_count: int = 0
var _awaiting_deal: bool = false
var _turn_start_active: bool = false
var _held_bounds := Rect2()
var _environment: Array = []
var _placed: bool = false
var _placing: bool = false

func clear() -> void:
	right_column.clear()
	_turn_key = ""
	_dealt_count = 0
	_awaiting_deal = false
	_turn_start_active = false
	_held_bounds = Rect2()
	_environment.clear()
	_placed = false

func hand_bounds(scene: Control) -> Rect2:
	var scroll: Control = scene.get("hand_scroll") as Control
	if scroll == null or scroll.size.x <= 0.0 or scroll.size.y <= 0.0:
		return Rect2()
	if _dealt_count == 0:
		_turn_key = _key_for(scene)
		_dealt_count = maxi(1, _hand_count(scene))
	var environment: Array = _environment_for(scene)
	if _held_bounds.has_area() and environment == _environment:
		return _held_bounds
	var envelope := Vector2.ZERO
	for count: int in range(1, _dealt_count + 1):
		for focused: bool in [false, true]:
			var card_size: Vector2 = scene.call("_hand_card_size", count, false, focused)
			var gap: float = scene.call("_hand_layout_gap", count, card_size)
			var candidate: Vector2 = HandFan.content_size_for_layout(count, card_size, gap, true)
			envelope = envelope.max(candidate)
	_held_bounds = Rect2(scroll.get_global_rect().get_center() - envelope * 0.5, envelope)
	_environment = environment
	return _held_bounds

func begin_handoff(scene: Control) -> void:
	_awaiting_deal = true
	_turn_start_active = true
	# Retain the painted controls, including an exhausted previous turn's counters.
	for field: String in ["_play_meter", "_movement_meter"]:
		var meter: Control = scene.get(field) as Control
		if meter != null: meter.modulate.a = 1.0

func begin_deal(scene: Control, transition: Dictionary = {}, draw_entries: Array = []) -> void:
	var key: String = _key_for(scene)
	var count: int = (transition["target_hand"] as Array).size() if transition.has("target_hand") else _hand_count(scene)
	for entry: Variant in draw_entries:
		if entry is Dictionary: count = maxi(count, int(entry.get("total", count)))
	var new_home: bool = key != _turn_key or count > _dealt_count or not _placed or _awaiting_deal
	if key != _turn_key:
		_dealt_count = 0
	_turn_key = key
	_dealt_count = maxi(1, maxi(_dealt_count, count))
	_awaiting_deal = false
	if new_home:
		_held_bounds = Rect2()
		_relayout(scene)

func viewport_changed(scene: Control) -> void:
	if _in_combat(scene) and (_placed or _awaiting_deal):
		_held_bounds = Rect2()
		_relayout(scene)

func holds_layout(scene: Control) -> bool:
	turn_start_active(scene)
	if _placing or not (_placed or _awaiting_deal):
		return false
	# A resize can propagate through containers over multiple sorts. Each new
	# display/scroll-width geometry gets one complete synchronous placement batch;
	# focus changes intentionally exclude scroll height/vertical position.
	if _environment_for(scene) != _environment:
		_relayout(scene)
	return true

func turn_start_active(scene: Control) -> bool:
	if not _in_combat(scene):
		clear()
	elif not bool(scene.get("_animation_lock")):
		_awaiting_deal = false
		_turn_start_active = false
	return _turn_start_active

func _relayout(scene: Control) -> void:
	if _placing: return
	_placing = true
	hand_bounds(scene)
	scene.call("_layout_combat_action_dock")
	scene.call("_layout_choice_button_overlay")
	_placed = true
	_placing = false
	if not bool(scene.call("_controller_is_active")):
		scene.get_viewport().update_mouse_cursor_state()

func _environment_for(scene: Control) -> Array:
	var scroll: Control = scene.get("hand_scroll") as Control
	return [scene.get_viewport_rect().size, scene.get_window().content_scale_factor,
		scroll.global_position.x if scroll != null else 0.0, scroll.size.x if scroll != null else 0.0]

func _key_for(scene: Control) -> String:
	var state: Dictionary = scene.get("_combat_state") as Dictionary
	return "%s|%s|%s" % [(scene.get("_run_state") as Dictionary).get("seed", 0), state.get("room_coord", Vector2i.ZERO), state.get("turn", 1)]

func _hand_count(scene: Control) -> int:
	return (((scene.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array).size()

func _in_combat(scene: Control) -> bool:
	return str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat"

static func floor_card_count(scene: Control) -> int:
	return maxi(1, int((scene.get("_combat_state") as Dictionary).get("hand_size", RunEngine.BASE_HAND_SIZE)))
