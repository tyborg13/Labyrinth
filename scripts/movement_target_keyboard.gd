extends RefCounted

# Keyboard movement targeting shares the existing board cursor and target-click
# resolver. Screen directions and the initial destination match the controller.
static func handle(host: Control, event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventAction) or not event.is_pressed() or event.is_echo():
		return false
	var index: int = host.get("_pending_action_index")
	var actions: Array = host.get("_pending_actions")
	if int(host.get("_selected_card_index")) < 0 or index < 0 or index >= actions.size() or bool(host.get("_animation_lock")) or bool(host.call("_controller_modal_visible")):
		return false
	if str((actions[index] as Dictionary).get("type", "")) not in ["move", "blink"]:
		return false
	var direction: Vector2 = _direction(event)
	if direction == Vector2.ZERO and not event.is_action_pressed("ui_accept"):
		return false
	var targets: Array = host.get("_pending_target_tiles")
	if targets.is_empty(): return false
	if not targets.has(host.get("_controller_board_tile")):
		host.call("_controller_enter_board", true)
	host.set("_controller_region", "board")
	if direction != Vector2.ZERO:
		host.call("_controller_move_board", direction)
	else:
		var tile: Vector2i = host.get("_controller_board_tile")
		if targets.has(tile): await host.call("_on_board_tile_clicked", tile)
	return true

static func _direction(event: InputEvent) -> Vector2:
	if event.is_action_pressed("ui_left"): return Vector2.LEFT
	if event.is_action_pressed("ui_right"): return Vector2.RIGHT
	if event.is_action_pressed("ui_up"): return Vector2.UP
	if event.is_action_pressed("ui_down"): return Vector2.DOWN
	return Vector2.ZERO
