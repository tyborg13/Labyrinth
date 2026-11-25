extends "res://tests/pre_battle_fixture.gd"

# ett-01: rest the pointer on event choices (icon and plain text spots) past
# the tooltip delay and dump the real tooltip popup Godot creates.
const Suite = preload("res://tests/suites/event_view_suite.gd")
const EVENTS: Array[String] = ["bloodletters_basin", "whispering_well", "lost_cartographer", "moth_library", "hanged_knight"]

func _initialize() -> void:
	_setup()
	_viewport.gui_embed_subwindows = true
	call_deferred("_run")

func _dump(node: Node, depth: int) -> void:
	var line: String = "%s%s(%s)" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is Control: line += " size=%s vis=%s mod=%s" % [(node as Control).size, (node as Control).visible, (node as Control).modulate]
	if node is Window: line += " win_size=%s vis=%s variation=%s" % [(node as Window).size, (node as Window).visible, node.get("theme_type_variation")]
	if node is Label: line += " text=%s" % JSON.stringify((node as Label).text)
	if node is RichTextLabel: line += " text=%s content_h=%s" % [JSON.stringify((node as RichTextLabel).get_parsed_text().left(60)), (node as RichTextLabel).get_content_height()]
	print("ETT01 POPUP " + line)
	for child: Node in node.get_children(true): _dump(child, depth + 1)

func _collect(node: Node, found: Array[Window]) -> void:
	for child: Node in node.get_children(true):
		if child is Window and (child as Window).visible: found.append(child)
		_collect(child, found)

func _popups() -> Array[Window]:
	var found: Array[Window]
	_collect(_viewport, found)
	return found

func _rest(point: Vector2) -> void:
	_viewport.notification(Node.NOTIFICATION_VP_MOUSE_ENTER)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = Vector2(1, 0)
	_viewport.push_input(motion, true)
	await create_timer(1.2).timeout
	await process_frame

func _run() -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	scene.call("_close_dialogue")
	for id: String in EVENTS:
		scene.call("_load_run_state", Suite.fixture(id, true))
		await _settle()
		var view: Control = scene.get("_event_view")
		view.finish_animation_for_test()
		await process_frame
		for button: Button in view.choices:
			var rect: Rect2 = button.get_global_rect()
			var icon_point := Vector2(-1, -1)
			var plain_point: Vector2 = rect.position + Vector2(rect.size.x * 0.85, rect.size.y * 0.5)
			var x: float = rect.position.x + 2
			while x < rect.end.x and icon_point.x < 0:
				var y: float = rect.position.y + 2
				while y < rect.end.y:
					if not button.get_tooltip(button.get_global_transform().affine_inverse() * Vector2(x, y)).is_empty():
						icon_point = Vector2(x, y)
						break
					y += 6
				x += 6
			for spot: Array in [["plain", plain_point], ["icon", icon_point]]:
				if (spot[1] as Vector2).x < 0: continue
				await _rest(Vector2(8, 8))
				await _rest(spot[1])
				var popups: Array[Window] = _popups()
				print("ETT01 REST %s choice=%s spot=%s at=%s tooltip=%s popups=%d" % [id, button.choice_id, spot[0], spot[1], JSON.stringify(button.get_tooltip(button.get_global_transform().affine_inverse() * (spot[1] as Vector2)).left(40)), popups.size()])
				for popup: Window in popups: _dump(popup, 1)
	scene.queue_free()
	_viewport.queue_free()
	await process_frame
	quit(0)
