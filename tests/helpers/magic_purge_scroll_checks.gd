extends RefCounted

const Fixture = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const BadgeChecks = preload("res://tests/helpers/pile_copy_badge_checks.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const TEST_IDENTITIES: int = 15
const TEST_ROW_PITCH: int = 296
const TEST_LAYOUT_FRAMES: int = 2
const TEST_PAN_DELTA := Vector2(0, 0.25)

static func run(fixture: SceneTree, instance: Node, engine: RunEngine, report: Callable) -> void:
	var failures: Array[String]
	var expect: Callable = func(ok: bool, message: String) -> void:
		report.call(ok, message)
		if not ok: failures.append(message)
	var state: Dictionary = Fixture.shop_fixture(engine)
	var cards: Array = Presentation.unique_cards(TEST_IDENTITIES)
	cards.append_array(cards.duplicate())
	state["attuned_magic_cards"] = cards
	state = engine.repair_loaded_run_state(state)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await fixture.call("_settle")
	instance.set("_animation_lock", false)
	instance.call("_open_magic_purge", "scavenger")
	await fixture.call("_settle")
	var modal: Control = instance.get("_magic_purge_overlay")
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid: Control = modal.find_child("MagicPurgeRows", true, false)
	Presentation.assert_grid(modal, state["attuned_magic_cards"], expect)
	expect.call(grid.get_child_count() == 15 and scroll.size.y == 614 and scroll.get_v_scroll_bar().page == 596, "Viewport fits exactly two complete rows, 24px badge room and the existing 18px crown headroom (size %s, page %s)" % [scroll.size, scroll.get_v_scroll_bar().page])
	expect.call(scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page == 296 and scroll.get_v_scroll_bar().step == 296, "Scroll range and native scrollbar step are exactly one whole row")
	var reached: Dictionary = {}
	# Exhaust every integer offset a caller can request across the full range.
	# Snapping must expose only the two reachable row positions, with no frame
	# containing an intermediate page or a partly visible badge.
	for requested: int in range(TEST_ROW_PITCH + 1):
		scroll.scroll_vertical = requested
		await fixture.process_frame
		reached[scroll.scroll_vertical] = true
		assert_page(modal, expect)
	expect.call(reached.size() == 2 and reached.has(0) and reached.has(296), "All reachable scroll positions are whole rows")
	_parent_bounds_mutation(modal, expect)
	scroll.scroll_vertical = 0
	await _frames(fixture)
	BadgeChecks.assert_viewport_mutations(modal, expect)
	await _pointer_routes(fixture, modal, expect)
	await _focus_routes(fixture, modal, expect)
	for requested: int in [-296, 592]:
		scroll.get_v_scroll_bar().value = requested
		await _frames(fixture)
		expect.call(scroll.scroll_vertical == (0 if requested < 0 else 296), "Scrollbar clamps to whole-row endpoints")
		assert_page(modal, expect)
	print("PURGE WHOLE-ROW SCROLL CHECKS: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	instance.call("_close_magic_purge")
	await fixture.call("_settle")

static func assert_page(modal: Control, expect: Callable) -> void:
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid: Control = modal.find_child("MagicPurgeRows", true, false)
	expect.call(scroll.scroll_vertical % TEST_ROW_PITCH == 0 and scroll.scroll_vertical in [0, 296], "Every displayed scroll position is a clamped whole row")
	var first: int = scroll.scroll_vertical / TEST_ROW_PITCH
	for index: int in range(grid.get_child_count()):
		var cell: Control = grid.get_child(index)
		var on_page: bool = index / 7 >= first and index / 7 < first + 2
		expect.call(cell.get("widget").is_visible_in_tree() == on_page and cell.get_node("PileCopyCount").is_visible_in_tree() == on_page, "Only the two current rows draw cards and badges")
		expect.call(cell.mouse_filter == (Control.MOUSE_FILTER_STOP if on_page else Control.MOUSE_FILTER_IGNORE), "Off-page focus targets cannot take invisible pointer hits")
	for failure: String in BadgeChecks.viewport_failures(modal): expect.call(false, failure)

static func _parent_bounds_mutation(modal: Control, expect: Callable) -> void:
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid: Control = modal.find_child("MagicPurgeRows", true, false)
	var cell: Control = grid.get_child(0)
	var badge: Control = cell.get_node("PileCopyCount")
	expect.call(not cell.get_global_rect().intersects(scroll.get_global_rect()), "Mutation fixture has a fully offscreen parent card")
	badge.show()
	var caught: Array[String] = BadgeChecks.viewport_failures(modal)
	badge.hide()
	var killed: bool = caught.any(func(message: String) -> bool: return message.contains(str(badge.get_path())))
	expect.call(killed, "Badge guard catches a partial badge independently of its offscreen parent")
	print("PURGE BADGE PARENT-BOUNDS MUTATION: %s" % ("KILLED" if killed else "SURVIVED"))

static func _pointer_routes(fixture: SceneTree, modal: Control, expect: Callable) -> void:
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var viewport: SubViewport = fixture.get("_viewport")
	for direction: int in [1, -1]:
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if direction > 0 else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		viewport.push_input(wheel, true)
		await _frames(fixture)
		expect.call(scroll.scroll_vertical == (296 if direction > 0 else 0), "Mouse wheel advances a complete row")
		assert_page(modal, expect)
	for direction: int in [1, -1]:
		var pan := InputEventPanGesture.new()
		pan.position = scroll.get_global_rect().get_center()
		pan.delta = TEST_PAN_DELTA * direction
		viewport.push_input(pan, true)
		await _frames(fixture)
		expect.call(scroll.scroll_vertical == (296 if direction > 0 else 0), "Small trackpad pan advances a complete row")
		assert_page(modal, expect)

static func _focus_routes(fixture: SceneTree, modal: Control, expect: Callable) -> void:
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	var grid: Control = modal.find_child("MagicPurgeRows", true, false)
	(grid.get_child(0) as Control).grab_focus()
	for _step: int in range(2): await fixture.call("_key", KEY_DOWN)
	expect.call((grid.get_child(14) as Control).has_focus() and scroll.scroll_vertical == 296, "Keyboard reveals the final row without partial scrolling")
	assert_page(modal, expect)
	for _step: int in range(2): await fixture.call("_key", KEY_UP)
	expect.call((grid.get_child(0) as Control).has_focus() and scroll.scroll_vertical == 0, "Keyboard returns to the first complete row")
	for _step: int in range(2): await fixture.call("_joy", JOY_BUTTON_DPAD_DOWN)
	expect.call((grid.get_child(14) as Control).has_focus() and scroll.scroll_vertical == 296, "Controller reveals the final row without partial scrolling")
	assert_page(modal, expect)
	for index: int in range(grid.get_child_count()):
		(grid.get_child(index) as Control).grab_focus()
		await _frames(fixture)
		expect.call((grid.get_child(index) as Control).has_focus(), "Every off-page card retains a reachable focus target")
		assert_page(modal, expect)
	(grid.get_child(0) as Control).grab_focus()
	await _frames(fixture)
	expect.call(scroll.scroll_vertical == 0, "Focus-follow returns to a complete first row")

static func _frames(fixture: SceneTree) -> void:
	for _frame: int in range(TEST_LAYOUT_FRAMES): await fixture.process_frame
