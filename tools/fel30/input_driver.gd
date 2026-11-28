extends RefCounted
## Resolve hunt offers to player input. The only write path is Viewport.push_input.

var viewport: Viewport
var pointer := Vector2.ZERO


func _init(target: Viewport) -> void:
	viewport = target


func control(target: Control) -> Dictionary:
	if not available(target): return {}
	var rect: Rect2 = target.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, target.size)
	rect = rect.intersection(viewport.get_visible_rect())
	if not rect.has_area(): return {}
	var input: Dictionary = point(rect.get_center(), str(target.name))
	input["node"] = str(target.name)
	if target.has_meta("choice_id"): input["choice"] = str(target.get_meta("choice_id"))
	if target is Button and not target.text.is_empty(): input["text"] = target.text
	return input


func available(target: Variant) -> bool:
	return (is_instance_valid(target) and target is Control and target.is_visible_in_tree()
		and (not target is BaseButton or not target.disabled))


func point(at: Vector2, label: String = "") -> Dictionary:
	return {"type": "click", "point": [at.x, at.y], "label": label}


func key(code: int) -> Dictionary:
	return {"type": "key", "code": code, "label": OS.get_keycode_string(code)}


func motion(at: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = at
	event.global_position = at
	event.relative = at - pointer
	pointer = at
	viewport.push_input(event, true)


func prepare(input: Dictionary) -> void:
	if input["type"] == "click": motion(Vector2(input["point"][0], input["point"][1]))


func send(input: Dictionary) -> void:
	if input["type"] == "key":
		for pressed: bool in [true, false]:
			var event := InputEventKey.new()
			event.keycode = int(input["code"]) as Key
			event.pressed = pressed
			viewport.push_input(event, true)
	else:
		for pressed: bool in [true, false]:
			var event := InputEventMouseButton.new()
			event.button_index = MOUSE_BUTTON_LEFT
			event.position = pointer
			event.global_position = pointer
			event.pressed = pressed
			viewport.push_input(event, true)


func tile_point(scene: Node, tile: Vector2i) -> Vector2:
	var board: Control = scene.board_view
	return board.get_global_transform_with_canvas() * board.world_position_for_tile(tile)


func hunt_input(scene: Node, offer: Dictionary) -> Dictionary:
	if offer.has("control"): return control(offer["control"])
	var args: Array = offer.get("args", [])
	match offer["kind"]:
		"dialogue": return key(KEY_ENTER)
		"card": return key(KEY_1 + int(args[0]))
		"pass": return key(KEY_P)
		"cancel_card": return key(KEY_ESCAPE)
		"confirm_card": return board_tile(scene, scene._preview_combat_state["player"]["pos"], "confirm on hero")
		"begin_combat": return control(named(scene, "PreBattleStartButton"))
		"map_room": return map_room(scene, args[0])
	if offer.has("tile"): return board_tile(scene, scene._combat_state["player"]["pos"], "select movement")
	if offer.get("method") == "_on_board_tile_clicked":
		return board_tile(scene, args[0], "tile %s" % str(args[0]))
	return {}


func board_tile(scene: Node, tile: Vector2i, label: String) -> Dictionary:
	var input: Dictionary = point(tile_point(scene, tile), label)
	input["tile"] = [tile.x, tile.y]
	return input


func map_room(scene: Node, tile: Vector2i) -> Dictionary:
	if not scene._large_map_scrim.visible: return {}
	var map: Control = scene._large_map_view
	var destinations: Array[Vector2i] = [tile]
	var rects: Dictionary = map.selectable_room_global_rects(destinations)
	if not rects.has(tile): return {}
	var rect: Rect2 = rects[tile]
	var input: Dictionary = point(map.get_canvas_transform() * rect.get_center(), "map %s" % str(tile))
	input["room"] = [tile.x, tile.y]
	return input


func resolve(scene: Node, input: Dictionary) -> Dictionary:
	if input.has("tile"): return board_tile(scene, Vector2i(int(input["tile"][0]), int(input["tile"][1])), input["label"])
	if input.has("room"): return map_room(scene, Vector2i(int(input["room"][0]), int(input["room"][1])))
	if input.has("choice"):
		for panel: Control in scene.find_children("*", "PanelContainer", true, false):
			if (panel.get_meta("choice_id", "") == input["choice"] and available(panel)
					and panel.get_meta("choice_enabled", false) and panel.get_meta("choice_revealed", false)):
				return control(panel)
		return {}
	var name: String = input.get("node", "")
	if not name.is_empty() and not name.begins_with("@"):
		var matches: Array[Control]
		for node: Control in scene.find_children(name, "Control", true, false):
			if available(node): matches.append(node)
		if matches.size() == 1: return control(matches[0])
	var label: String = input.get("text", "")
	if not label.is_empty():
		var matches: Array[Control]
		for button: Button in scene.find_children("*", "Button", true, false):
			if available(button) and button.text == label: matches.append(button)
		if matches.size() == 1: return control(matches[0])
	return input



func named(host: Node, pattern: String) -> Control:
	if not is_instance_valid(host): return null
	for node: Node in host.find_children(pattern, "Control", true, false):
		if available(node): return node as Control
	return null
