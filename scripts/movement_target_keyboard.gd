extends RefCounted

const FOCUS_META: String = "movement_target_keyboard_focus"

# Keyboard movement targeting shares the existing board cursor and target-click
# resolver. Screen directions and the initial destination match the controller.
static func handle(host: Control, event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return false
	if not _available(host):
		return false
	var direction: Vector2 = _direction(event)
	if direction == Vector2.ZERO and not event.is_action_pressed("ui_accept"):
		return false
	var targets: Array = host.get("_pending_target_tiles")
	if targets.is_empty(): return false
	host.set_meta(FOCUS_META, true)
	if not targets.has(host.get("_controller_board_tile")):
		host.call("_controller_enter_board", true)
	host.set("_controller_region", "board")
	if direction != Vector2.ZERO:
		host.call("_controller_move_board", direction)
	else:
		var tile: Vector2i = host.get("_controller_board_tile")
		if targets.has(tile): await host.call("_on_board_tile_clicked", tile)
	host.call("_sync_click_targeting_arrow")
	return true

static func active(host: Control) -> bool:
	return bool(host.get_meta(FOCUS_META, false)) and _available(host) and str(host.get("_controller_region")) == "board"

static func preserve_focus(host: Control) -> bool:
	if not active(host): return false
	var tile: Vector2i = host.get("_controller_board_tile")
	if tile.x >= 0:
		# Hand/board layout can settle after the key event. Refresh screen geometry
		# without changing the logical target or discovering a different candidate.
		var point: Vector2 = host.call("_controller_board_point", tile)
		var candidate: Dictionary = host.get("_controller_focus_candidate")
		candidate["point"] = point
		host.set("_controller_virtual_board_position", point)
		(host.get("board_view") as Control).call("set_controller_focus_tile", tile)
		if host.get("_hovered_board_tile") != tile: host.call("_on_board_tile_hovered", tile)
	host.call("_sync_click_targeting_arrow")
	return true

static func observe_input(host: Control, event: InputEvent) -> void:
	var controller_activity: bool = (event is InputEventJoypadButton and event.pressed) or (event is InputEventJoypadMotion and absf(event.axis_value) >= preload("res://scripts/input_router.gd").JOYSTICK_ACTIVITY_THRESHOLD)
	if event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag or controller_activity:
		if bool(host.get_meta(FOCUS_META, false)):
			clear(host)
			host.call("_controller_clear_board_focus")

static func clear(host: Control) -> void:
	if host.has_meta(FOCUS_META): host.remove_meta(FOCUS_META)

static func _available(host: Control) -> bool:
	var index: int = host.get("_pending_action_index")
	var actions: Array = host.get("_pending_actions")
	return (
		int(host.get("_selected_card_index")) >= 0 and index >= 0 and index < actions.size()
		and not bool(host.get("_animation_lock")) and not bool(host.call("_controller_modal_visible"))
		and int(host.get("_drag_card_index")) < 0
		and str((actions[index] as Dictionary).get("type", "")) in ["move", "blink"]
	)

static func _direction(event: InputEvent) -> Vector2:
	if event.is_action_pressed("ui_left"): return Vector2.LEFT
	if event.is_action_pressed("ui_right"): return Vector2.RIGHT
	if event.is_action_pressed("ui_up"): return Vector2.UP
	if event.is_action_pressed("ui_down"): return Vector2.DOWN
	return Vector2.ZERO
