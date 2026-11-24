extends RefCounted

const LAYOUT_FRAMES: int = 8
const WHEEL_LIMIT: int = 180
const DRAG_STEPS: int = 8
const INPUT_IDLE_SECONDS: float = 0.35

static func measure(tree: SceneTree, viewport: SubViewport, book: Control, ids: Array, click: Callable) -> void:
	var scroll: ScrollContainer = book._grimoire_entry_scroll
	var section: Button = button(book, "section", "creatures")
	scroll.ensure_control_visible(section)
	await settle(tree)
	await click.call(section)
	await settle(tree)
	var page: Button = button(book, "entry", ids[1])
	scroll.ensure_control_visible(page)
	await settle(tree)
	_report("section opened", book)
	await click.call(page)
	await tree.create_timer(INPUT_IDLE_SECONDS).timeout
	_report("page opened", book)
	var last: Button = button(book, "entry", ids.back())
	var list_point: Vector2 = scroll.get_global_rect().get_center()
	await _drag(tree, viewport, scroll)
	_report("after scrollbar drag", book)
	print("TXT38 SCROLL scrollbar reached %s=%s" % [ids.back(), _visible(scroll, last)])
	if _visible(scroll, last):
		await click.call(last)
		print("TXT38 SCROLL scrollbar opened last=%s" % (book._grimoire_selected_entry == ids.back()))
		await settle(tree)
	# Recalculate the range before preparing the independent wheel trial.
	# The new page click again goes through the production rebuild.
	scroll.queue_sort()
	await settle(tree)
	page = button(book, "entry", ids.front())
	scroll.ensure_control_visible(page)
	await settle(tree)
	await click.call(page)
	await tree.create_timer(INPUT_IDLE_SECONDS).timeout
	_report("page reopened", book)
	last = button(book, "entry", ids.back())
	await _wheel(tree, viewport, scroll, list_point, last)
	_report("after wheel", book)
	print("TXT38 SCROLL wheel reached %s=%s" % [ids.back(), _visible(scroll, last)])
	if _visible(scroll, last):
		await click.call(last)
		print("TXT38 SCROLL wheel opened last=%s" % (book._grimoire_selected_entry == ids.back()))
	else:
		# Confirm that the collapsed range disagrees with the laid-out child.
		scroll.queue_sort()
		await settle(tree)
		_report("after diagnostic sort", book)
		await _drag(tree, viewport, scroll)
		print("TXT38 SCROLL diagnostic drag reached %s=%s" % [ids.back(), _visible(scroll, last)])

static func _wheel(tree: SceneTree, viewport: SubViewport, scroll: ScrollContainer, point: Vector2, last: Button) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	_move_pointer(viewport, point)
	await tree.process_frame
	for event_index: int in WHEEL_LIMIT:
		_mouse_button(viewport, point, MOUSE_BUTTON_WHEEL_DOWN, true)
		_mouse_button(viewport, point, MOUSE_BUTTON_WHEEL_DOWN, false)
		await tree.process_frame
		if event_index == 0:
			print("TXT38 SCROLL first wheel event: max=%d, page=%d, value=%d" % [bar.max_value, bar.page, bar.value])
		if not bar.is_visible_in_tree() or _visible(scroll, last): break

static func _drag(tree: SceneTree, viewport: SubViewport, scroll: ScrollContainer) -> void:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var rect: Rect2 = bar.get_global_rect()
	if not bar.is_visible_in_tree() or not rect.has_area(): return
	var thumb := Vector2(rect.get_center().x, rect.position.y + rect.size.y * (bar.value + bar.page * 0.5) / bar.max_value)
	_move_pointer(viewport, thumb)
	await tree.process_frame
	print("TXT38 SCROLL drag starts on scrollbar=%s at %s" % [viewport.gui_get_hovered_control() == bar, thumb])
	_mouse_button(viewport, thumb, MOUSE_BUTTON_LEFT, true)
	await tree.process_frame
	print("TXT38 SCROLL after thumb press: max=%d, page=%d, value=%d" % [bar.max_value, bar.page, bar.value])
	var finish := Vector2(thumb.x, rect.end.y - 1.0)
	var previous: Vector2 = thumb
	for index: int in range(1, DRAG_STEPS + 1):
		var point: Vector2 = thumb.lerp(finish, float(index) / DRAG_STEPS)
		_move_pointer(viewport, point, point - previous, MOUSE_BUTTON_MASK_LEFT)
		previous = point
		await tree.process_frame
	_mouse_button(viewport, finish, MOUSE_BUTTON_LEFT, false)
	await settle(tree)

static func button(book: Control, kind: String, id: String) -> Button:
	for item: Button in book._grimoire_nav_buttons:
		if item.get_meta("grimoire_nav_kind", "") == kind and item.get_meta("grimoire_nav_id", "") == id:
			return item
	return null

static func settle(tree: SceneTree) -> void:
	for _frame: int in LAYOUT_FRAMES:
		await tree.process_frame

static func _visible(scroll: ScrollContainer, item: Button) -> bool:
	return item != null and scroll.get_global_rect().has_point(item.get_global_rect().get_center())

static func _report(phase: String, book: Control) -> void:
	var scroll: ScrollContainer = book._grimoire_entry_scroll
	var list: Control = book._grimoire_section_list
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	print("TXT38 SCROLL %s: viewport=%d, content=%d, minimum=%d, max=%d, page=%d, scroll=%d, visible bar=%s, entry=%s" %
		[phase, scroll.size.y, list.size.y, list.get_combined_minimum_size().y, bar.max_value, bar.page, bar.value,
		bar.is_visible_in_tree(), book._grimoire_selected_entry])

static func _move_pointer(viewport: SubViewport, point: Vector2, relative: Vector2 = Vector2.ZERO, mask: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = relative
	motion.button_mask = mask
	viewport.push_input(motion, true)

static func _mouse_button(viewport: SubViewport, point: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = pressed
	event.factor = 1.0
	viewport.push_input(event, true)
