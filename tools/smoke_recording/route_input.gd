extends RefCounted
## Send viewport-space events through the same GUI and board pickers as a player.

var tree: SceneTree
var position := Vector2.ZERO
var warp_pointer: bool

func _init(scene_tree: SceneTree, native: bool) -> void:
	tree = scene_tree
	warp_pointer = native

func point(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func motion(destination: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = destination
	event.global_position = destination
	event.relative = destination - position
	position = destination
	if warp_pointer: tree.root.warp_mouse(destination)
	tree.root.push_input(event, true)

func click(destination: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	motion(destination)
	await tree.process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = button
		event.pressed = pressed
		event.button_mask = (1 << (button - 1)) if pressed else 0
		event.position = position
		event.global_position = position
		tree.root.push_input(event, true)
		await tree.process_frame

func joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		event.pressure = 1.0 if pressed else 0.0
		tree.root.push_input(event, true)
		await tree.process_frame

func usable(control: Control) -> bool:
	return (
		is_instance_valid(control) and control.is_visible_in_tree()
		and control.size.x > 0.0 and control.size.y > 0.0
		and (not control is BaseButton or not (control as BaseButton).disabled)
	)
