extends RefCounted
## Event delivery through the real viewport, including controller ownership.
const STICK_MAGNITUDE: float = 0.75
const CARD_X := [0.15, 0.25, 0.45, 0.70, 0.9]
const CARD_Y := [0.16, 0.32, 0.48, 0.66]
var viewport: Viewport
var scene: Node
var pointer := Vector2.ZERO

func _init(root: Viewport, host: Node) -> void:
	viewport = root
	scene = host

func button(index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = index
		event.pressed = pressed
		viewport.push_input(event, true)

func stick(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_X
	event.axis_value = value
	viewport.push_input(event, true)

func details() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_I
		event.pressed = pressed
		viewport.push_input(event, true)

func focus_card(index: int) -> void:
	var hand: Array = scene._combat_state.get("deck", {}).get("hand", [])
	if scene._controller_region != "hand":
		button(JOY_BUTTON_RIGHT_SHOULDER)
		if scene._controller_region != "hand": button(JOY_BUTTON_X)
	for attempt: int in range(hand.size() + 1):
		if scene._controller_region == "hand" and scene._controller_hand_index == index: return
		button(JOY_BUTTON_RIGHT_SHOULDER)

func card_click(index: int) -> void:
	var point: Vector2 = _exposed_card(index)
	if point.is_finite(): click(point)

func card_hover(index: int) -> void:
	var point: Vector2 = _exposed_card(index)
	if point.is_finite(): motion(point)

func _exposed_card(index: int) -> Vector2:
	var widget: Control = scene._hand_card_control(index)
	if widget == null: return Vector2.INF
	for y: float in CARD_Y:
		for x: float in CARD_X:
			var point: Vector2 = _point(widget, Vector2(x, y))
			if viewport.get_visible_rect().has_point(point) and scene.hand_box.card_index_at_point(point) == index:
				return point
	return Vector2.INF

func tile_motion(tile: Vector2i) -> void:
	motion(_tile_point(tile))

func tile_click(tile: Vector2i) -> void:
	click(_tile_point(tile))

func pass_hover() -> void:
	var chip: Control = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	if chip != null: motion(_point(chip, Vector2(0.5, 0.5)))

func pass_click() -> void:
	var chip: Control = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	if chip != null: click(_point(chip, Vector2(0.5, 0.5)))

func empty_tile() -> Vector2i:
	var board: Control = scene.board_view
	var hero: Vector2i = scene._combat_state["player"]["pos"]
	for tile: Vector2i in board._rendered_tiles_in_draw_order():
		if tile == hero or tile == scene._hovered_board_tile: continue
		if not scene._state_has_visible_enemy_at_tile(scene._combat_state, tile) and viewport.get_visible_rect().has_point(_tile_point(tile)):
			return tile
	return hero

func target(rng: RandomNumberGenerator) -> Vector2i:
	var tiles: Array = scene._pending_target_tiles.filter(func(tile: Vector2i) -> bool:
		return tile != scene._hovered_board_tile and viewport.get_visible_rect().has_point(_tile_point(tile)))
	return empty_tile() if tiles.is_empty() else tiles[rng.randi_range(0, tiles.size() - 1)]

func motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - pointer
	pointer = point
	viewport.push_input(event, true)

func click(point: Vector2) -> void:
	motion(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		viewport.push_input(event, true)

func _point(control: Control, relative: Vector2) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * relative)

func _tile_point(tile: Vector2i) -> Vector2:
	var board: Control = scene.board_view
	return board.get_global_transform_with_canvas() * board._tile_center(tile)
