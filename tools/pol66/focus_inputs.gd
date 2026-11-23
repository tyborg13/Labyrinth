extends RefCounted

const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")

const D_PAD_STEPS: int = 20
const D_PAD := {
	"left": JOY_BUTTON_DPAD_LEFT,
	"right": JOY_BUTTON_DPAD_RIGHT,
	"down": JOY_BUTTON_DPAD_DOWN,
	"up": JOY_BUTTON_DPAD_UP,
}

var _expect: Callable

func _init(expect: Callable) -> void:
	_expect = expect

func check(tree: SkillTreeView, size_label: String) -> void:
	var viewport: Viewport = tree.get_viewport()
	var point: Vector2 = _node_midpoint(tree.node_for_skill("living_shadow"))
	tree.focus_skill("quick_wits")
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	viewport.push_input(motion, true)
	_expect.call(viewport.gui_get_hovered_control() == tree.node_for_skill("living_shadow"), "Pointer reaches Living Shadow")
	# Hover alone never changes the selected skill (the Learn target stays put).
	_expect.call(tree.focused_skill_id() == "quick_wits", "Hover keeps the selected skill")
	_check_focus_style(tree, "quick_wits", "hover")

	# Keep the pointer over Living Shadow to exercise click without another hover.
	tree.focus_skill("quick_wits")
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = point
		click.global_position = point
		click.pressed = pressed
		viewport.push_input(click, true)
	_check_focus_style(tree, "living_shadow", "click")

	tree.focus_skill("quick_wits")
	tree.grab_tree_focus()
	var left_neighbor: String = tree.navigation_neighbor("quick_wits", "left")
	var key := InputEventKey.new()
	key.keycode = KEY_LEFT
	key.pressed = true
	viewport.push_input(key, true)
	_check_focus_style(tree, left_neighbor, "keyboard")
	key.pressed = false
	viewport.push_input(key, true)

	tree.focus_skill("quick_wits")
	tree.grab_tree_focus()
	await tree.get_tree().process_frame
	var visited: Array[String]
	visited.append(tree.focused_skill_id())
	var path: Array[String]
	_expect.call(_find_d_pad_path(tree, visited, path), "The authored tree offers a 20-move path across distinct nodes")
	var before: int = tree.link_geometry_rebuild_count()
	var max_input_usec: int = 0
	var max_frame_usec: int = 0
	for direction: String in path:
		var expected: String = tree.navigation_neighbor(tree.focused_skill_id(), direction)
		var button := InputEventJoypadButton.new()
		button.button_index = D_PAD[direction]
		button.pressed = true
		var started_usec: int = Time.get_ticks_usec()
		viewport.push_input(button, true)
		max_input_usec = maxi(max_input_usec, Time.get_ticks_usec() - started_usec)
		_check_focus_style(tree, expected, "D-pad %s" % direction)
		button.pressed = false
		viewport.push_input(button, true)
		await tree.get_tree().process_frame
		max_frame_usec = maxi(max_frame_usec, Time.get_ticks_usec() - started_usec)
	var after: int = tree.link_geometry_rebuild_count()
	_expect.call(before == after, "D-pad focus moves add zero link geometry rebuilds")
	print("POL66 D-PAD %s: %d moves, %d distinct nodes, _rebuild_link_geometry %d -> %d, max synchronous input %d us, max input to next headless frame %d us" % [
		size_label, path.size(), visited.size(), before, after, max_input_usec, max_frame_usec,
	])

func _check_focus_style(tree: SkillTreeView, skill_id: String, input: String) -> void:
	_expect.call(not skill_id.is_empty() and tree.focused_skill_id() == skill_id, "%s selects %s synchronously" % [input, skill_id])
	var rails := tree.get("_link_layer") as SkillTreeView.SkillLinkLayer
	var arrows := tree.get("_link_overlay_layer") as SkillTreeView.SkillLinkOverlayLayer
	var direct_count: int = 0
	for link: Dictionary in rails.links:
		var direct: bool = skill_id in [link["from_id"], link["to_id"]]
		if direct:
			direct_count += 1
		_expect.call((link["color"] == UiPalette.EMBER) == direct, "%s: %s updates to the expected focus colour on input" % [input, link["sort_key"]])
	_expect.call(direct_count > 0 and rails.links == arrows.links, "%s updates both link layers on input" % input)

func _node_midpoint(control: Control) -> Vector2:
	return control.get_global_transform_with_canvas() * (control.size * 0.5)

func _find_d_pad_path(tree: SkillTreeView, visited: Array[String], path: Array[String]) -> bool:
	if path.size() == D_PAD_STEPS:
		return true
	for direction: String in D_PAD:
		var next: String = tree.navigation_neighbor(visited[-1], direction)
		if next.is_empty() or visited.has(next):
			continue
		visited.append(next)
		path.append(direction)
		if _find_d_pad_path(tree, visited, path):
			return true
		path.pop_back()
		visited.pop_back()
	return false
