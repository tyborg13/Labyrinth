extends RefCounted

const CaptureViewport = preload("res://tests/helpers/ui03_capture_viewport.gd")
const IDLE_POINTER := Vector2(1500, 650)

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 60308
const SETTLE_SECONDS: float = 0.25
const TOOLTIP_TIMEOUT_SECONDS: float = 3.0
const TOOLTIP_HOLD_SECONDS: float = 0.4
const OFFERED_TEXT: String = "Empower: +2 Time · Stagger +4\nClick the seal or press E"
const CHARGED_TEXT: String = "Empower: +2 Time · Stagger +4\nCharged. Click to cancel."

static func run_live(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var original_size: Vector2i = tree.root.size
	var original_embed: bool = tree.root.gui_embed_subwindows
	tree.root.size = VIEWPORT_SIZE
	tree.root.gui_embed_subwindows = true
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_empower_time"], FIXTURE_SEED)
	var router: Node = tree.root.get_node("InputRouter")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	var card: Control = scene.call("_hand_card_control", 0)
	await move_pointer(tree, tree.root, card.get_global_transform_with_canvas() * (card.size * 0.5))
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	expect.call(stack.is_visible_in_tree() and stack.get_child_count() > 0, "Routed card-body hover displays its keyword stack before visiting the seal")
	var seal: Button = card.get_node("EmpowerSeal") as Button
	var point: Vector2 = seal.get_global_transform_with_canvas() * (seal.size * 0.5)
	await move_pointer(tree, tree.root, point)
	expect.call(seal.is_hovered() and tree.root.gui_get_hovered_control() == seal, "Routed root pointer motion really hovers the Empower seal")
	expect.call(seal.tooltip_text == OFFERED_TEXT, "The offered seal supplies both exact tooltip lines")
	var offered: Window = await wait_for_tooltip(tree, tree.root, seal.tooltip_text)
	print("EMPOWER TOOLTIP ROOT offered: hovered=%s popup=%s" % [seal.is_hovered(), offered != null])
	expect.call(offered != null, "Hovering the unlit seal on the real RunScene root displays its real tooltip")
	expect.call(only_seal_tooltip(tree.root, stack), "The offered seal tooltip is the only visible tooltip")
	# Reposition before the press, just as an actual pointer click does.
	await move_pointer(tree, tree.root, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = tree.root.get_mouse_position()
		click.global_position = click.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		Input.parse_input_event(click)
		await tree.process_frame
	await tree.create_timer(SETTLE_SECONDS).timeout
	await move_pointer(tree, tree.root, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	expect.call(bool(scene.call("_hand_card_empowered", 0)) and seal.tooltip_text == CHARGED_TEXT, "The seal click supplies the exact charged tooltip lines")
	var charged: Window = await wait_for_tooltip(tree, tree.root, seal.tooltip_text)
	print("EMPOWER TOOLTIP ROOT charged: hovered=%s popup=%s" % [seal.is_hovered(), charged != null])
	expect.call(charged != null, "Hovering the charged seal on the real RunScene root displays its updated real tooltip")
	var exclusive: bool = await _hold_only_seal_tooltip(tree, tree.root, stack)
	expect.call(exclusive, "Charging and holding the routed pointer on the seal never reopens the keyword stack; exactly the seal tooltip is visible")
	await move_pointer(tree, tree.root, card.get_global_transform_with_canvas() * (card.size * 0.5))
	var stack_text: String = "\n".join(rendered_lines(stack))
	var active_stack: bool = stack.is_visible_in_tree() and stack_text.contains("EMPOWER · ACTIVE")
	var modified_stack: bool = stack_text.contains("Modified by:") and stack_text.contains("Empower")
	expect.call(active_stack and modified_stack, "Routed motion back onto the charged card body restores EMPOWER · ACTIVE and the modified entries")
	expect.call(_visible_tooltip_count(tree.root) == 0, "The seal popup closes when the routed pointer returns to the card body")
	print("EMPOWER TOOLTIP EXCLUSIVITY charged=%s body_active=%s body_modified=%s" % [exclusive, active_stack, modified_stack])
	await move_pointer(tree, tree.root, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	expect.call(not stack.is_visible_in_tree(), "Returning to the charged seal hides the keyword stack again")
	router.call("set_forced_state_for_test", "controller", "xbox")
	scene.call("_controller_set_hand_index", 0)
	await tree.create_timer(SETTLE_SECONDS).timeout
	expect.call(stack.is_visible_in_tree() and rendered_lines(stack).has("EMPOWER · ACTIVE"), "Controller hand focus still shows the active keyword stack after inspecting the seal")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	await move_pointer(tree, tree.root, IDLE_POINTER)
	scene.queue_free()
	await tree.process_frame
	await _isolated_capture(tree, expect, fixtures)
	tree.root.size = original_size
	tree.root.gui_embed_subwindows = original_embed

static func _hold_only_seal_tooltip(tree: SceneTree, scope: Node, stack: Control) -> bool:
	var exclusive: bool = true
	var deadline: int = Time.get_ticks_msec() + int(TOOLTIP_HOLD_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		exclusive = only_seal_tooltip(scope, stack) and exclusive
		await tree.process_frame
	return exclusive

static func only_seal_tooltip(scope: Node, stack: Control) -> bool:
	return not stack.is_visible_in_tree() and _visible_tooltip_count(scope) == 1

static func _visible_tooltip_count(scope: Node) -> int:
	var count: int = 1 if scope is Window and (scope as Window).visible and str(scope.get("theme_type_variation")) == "TooltipPanel" else 0
	for child: Node in scope.get_children(true):
		count += _visible_tooltip_count(child)
	return count

static func move_pointer(tree: SceneTree, viewport: Viewport, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	if viewport == tree.root: Input.parse_input_event(motion)
	else: viewport.push_input(motion, true)
	await tree.create_timer(SETTLE_SECONDS).timeout

static func wait_for_tooltip(tree: SceneTree, scope: Node, expected: String) -> Window:
	var deadline: int = Time.get_ticks_msec() + int(TOOLTIP_TIMEOUT_SECONDS * 1000.0)
	while Time.get_ticks_msec() < deadline:
		var popup: Window = visible_tooltip(scope, expected)
		if popup != null: return popup
		await tree.process_frame
	return null

static func visible_tooltip(scope: Node, expected: String) -> Window:
	if scope is Window and (scope as Window).visible and str(scope.get("theme_type_variation")) == "TooltipPanel":
		var lines: PackedStringArray = rendered_lines(scope)
		var expected_lines: PackedStringArray = expected.split("\n")
		# UiTooltipPanel's established title typography uses capitals; body copy
		# keeps its authored case. Verify the actual native popup's label content.
		if lines.has(expected_lines[0].to_upper()) and lines.has(expected_lines[1]):
			return scope as Window
	for child: Node in scope.get_children(true):
		var popup: Window = visible_tooltip(child, expected)
		if popup != null: return popup
	return null

static func rendered_lines(scope: Node) -> PackedStringArray:
	var lines := PackedStringArray()
	if scope is Label: lines.append((scope as Label).text)
	if scope is RichTextLabel: lines.append((scope as RichTextLabel).get_parsed_text())
	for child: Node in scope.get_children(true): lines.append_array(rendered_lines(child))
	return lines


static func _isolated_capture(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var capture = CaptureViewport.new()
	tree.root.add_child(capture)
	capture.setup(tree.root)
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_filler", "kwtest_empower_time"], FIXTURE_SEED)
	scene.reparent(capture.viewport)
	scene.call("_refresh_ui")
	var card: Control = scene.call("_hand_card_control", 1)
	await _capture_motion(tree, capture, card.get_global_transform_with_canvas() * (card.size * 0.5))
	var seal: Button = card.get_node("EmpowerSeal") as Button
	await _capture_motion(tree, capture, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	var offered: Window = await wait_for_tooltip(tree, capture.viewport, OFFERED_TEXT)
	var offered_visible: bool = offered != null
	expect.call(offered_visible, "The isolated SubViewport displays the same real offered tooltip")
	expect.call(capture.display is TextureRect and capture.display.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The full-window capture display has no input forwarding")
	var cursor: Node = tree.root.get_node("CursorFeedback")
	var glyph: Control = cursor.call("glyph_for_test") as Control
	var recorded_position: Vector2 = glyph.position
	var recorded_hover: Control = capture.viewport.gui_get_hovered_control()
	# Simulate desktop-only mouse input on the root after the synthetic hover.
	var desktop := InputEventMouseMotion.new()
	var other_card: Control = scene.call("_hand_card_control", 0)
	desktop.position = other_card.get_global_transform_with_canvas() * (other_card.size * 0.5)
	desktop.global_position = desktop.position
	tree.root.push_input(desktop, true)
	await tree.create_timer(SETTLE_SECONDS).timeout
	expect.call(capture.viewport.gui_get_hovered_control() == recorded_hover and recorded_hover == seal and glyph.position.is_equal_approx(recorded_position), "Desktop mouse motion cannot change the captured hover or drawn cursor")
	await _capture_motion(tree, capture, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	for pressed: bool in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = capture.viewport.get_mouse_position()
		click.global_position = click.position
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		capture.route(click)
		await tree.process_frame
	await tree.create_timer(SETTLE_SECONDS).timeout
	await _capture_motion(tree, capture, seal.get_global_transform_with_canvas() * (seal.size * 0.5))
	var charged: Window = await wait_for_tooltip(tree, capture.viewport, CHARGED_TEXT)
	expect.call(charged != null and bool(scene.call("_hand_card_empowered", 1)), "The isolated seal click displays the real charged tooltip")
	if charged != null:
		expect.call(charged.is_embedded() and capture.viewport.get_embedded_subwindows().has(charged), "The real tooltip is embedded in the recorded SubViewport texture")
	print("EMPOWER TOOLTIP ISOLATED offered=%s charged=%s desktop_input_isolated=%s" % [offered_visible, charged != null, glyph.position.is_equal_approx(capture.viewport.get_mouse_position() - CursorFeedbackController.CustomCursorGlyphScript.HOTSPOT)])
	await _capture_motion(tree, capture, IDLE_POINTER)
	capture.close()
	capture.queue_free()
	await tree.process_frame

static func _capture_motion(tree: SceneTree, capture: Node, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	capture.route(motion)
	await tree.create_timer(SETTLE_SECONDS).timeout
