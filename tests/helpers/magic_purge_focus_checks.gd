extends RefCounted

const Fixture = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const TEST_IDENTITY_COUNTS: Array = [15, 20]
const TEST_COLUMNS: int = 7
const TEST_ROW_PITCH: int = 296
const TEST_VISIBLE_ROWS: int = 2
const TEST_PAN_DELTA := Vector2(0, 0.25)

static func run(fixture: SceneTree, instance: Node, engine: RunEngine, report: Callable) -> void:
	for count: int in TEST_IDENTITY_COUNTS:
		var failures: Array[String]
		var expect: Callable = func(ok: bool, message: String) -> void:
			report.call(ok, "%d identities: %s" % [count, message])
			if not ok: failures.append(message)
		var state: Dictionary = Fixture.shop_fixture(engine)
		var cards: Array = Presentation.unique_cards(count)
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
		expect.call(grid.get_child_count() == count, "Interleaved input fixture represents every identity")
		for route: String in ["wheel", "trackpad", "scrollbar"]:
			for direction: int in [1, -1]:
				for controller: bool in [false, true]:
					# Evict either edge of the disappearing row. Activation follows
					# immediately through real viewport input, then returns via Back.
					var disappearing_row: int = 0 if direction > 0 else 2
					var last_index: int = mini((disappearing_row + 1) * TEST_COLUMNS, count) - 1
					for start_index: int in [disappearing_row * TEST_COLUMNS, last_index]:
						(grid.get_child(start_index) as Control).grab_focus()
						_manual_scroll(scroll, route, direction)
						var expected: int = TEST_COLUMNS if direction > 0 else 0
						assert_focus(scroll, grid, expected, expect)
						await _activate_and_back(fixture, instance, modal, grid.get_child(expected), controller, expect)
					# A focused card in the overlapping row stays exactly where it
					# was; scrolling with focus on X must not steal toolbar focus.
					scroll.scroll_vertical = 0 if direction > 0 else TEST_ROW_PITCH
					(grid.get_child(TEST_COLUMNS + 1) as Control).grab_focus()
					_manual_scroll(scroll, route, direction)
					assert_focus(scroll, grid, TEST_COLUMNS + 1, expect)
					await _activate_and_back(fixture, instance, modal, grid.get_child(TEST_COLUMNS + 1), controller, expect)
				var close: Control = modal.find_child("CancelMagicPurgeList", true, false)
				close.grab_focus()
				scroll.scroll_vertical = 0 if direction > 0 else TEST_ROW_PITCH
				_manual_scroll(scroll, route, direction)
				expect.call(close.has_focus(), route + " preserves focus outside the card grid")
		await _navigation_routes(fixture, instance, modal, scroll, grid, expect)
		# Stale/released activation signals cannot select hidden cards either.
		(grid.get_child(0) as Control).grab_focus()
		scroll.scroll_vertical = TEST_ROW_PITCH
		(grid.get_child(0) as Button).pressed.emit()
		expect.call(str(modal.get("pending_card_id")).is_empty(), "An off-page card cannot activate through a stale pressed signal")
		print("PURGE INTERLEAVED FOCUS CHECKS (%d identities): %s" % [count, "PASS" if failures.is_empty() else "FAIL"])
		instance.call("_close_magic_purge")
		await fixture.call("_settle")

static func assert_focus(scroll: ScrollContainer, grid: Control, expected_index: int, expect: Callable) -> void:
	var focused: Control = scroll.get_viewport().gui_get_focus_owner()
	expect.call(focused == grid.get_child(expected_index), "Page change preserves visible focus or moves it to the first card of the visible top row")
	if focused == null or focused.get_parent() != grid:
		expect.call(false, "Scrolled card focus stays inside the grid")
		return
	var first_row: int = scroll.scroll_vertical / TEST_ROW_PITCH
	var row: int = focused.get_index() / TEST_COLUMNS
	expect.call(row >= first_row and row < first_row + TEST_VISIBLE_ROWS, "Focused card is on a visible row before activation")

static func _manual_scroll(scroll: ScrollContainer, route: String, direction: int) -> void:
	var viewport: Viewport = scroll.get_viewport()
	if route == "wheel":
		var wheel := InputEventMouseButton.new()
		wheel.position = scroll.get_global_rect().get_center()
		wheel.global_position = wheel.position
		wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN if direction > 0 else MOUSE_BUTTON_WHEEL_UP
		wheel.pressed = true
		viewport.push_input(wheel, true)
	elif route == "trackpad":
		var pan := InputEventPanGesture.new()
		pan.position = scroll.get_global_rect().get_center()
		pan.delta = TEST_PAN_DELTA * direction
		viewport.push_input(pan, true)
	else:
		scroll.get_v_scroll_bar().value += direction * TEST_ROW_PITCH
	# No settle/frame between the manual page change and activation is needed:
	# focus reconciliation is synchronous with the native scrollbar write.

static func _activate_and_back(fixture: SceneTree, instance: Node, modal: Control, expected: Control, controller: bool, expect: Callable) -> void:
	var before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	if controller: await fixture.call("_joy", JOY_BUTTON_A)
	else: await fixture.call("_key", KEY_ENTER)
	expect.call(str(modal.get("pending_card_id")) == str(expected.get("card_id")), "Enter/A selects exactly the visible focused identity after scrolling")
	var scroll := modal.find_child("MagicPurgeScroll", true, false) as ScrollContainer
	# ScrollContainer applies child positions on the next frame. Activation
	# above was immediate; now independently check the resulting real bounds.
	expect.call(scroll.get_global_rect().encloses(expected.get_global_rect()), "Activated card's full bounds are inside the settled viewport")
	expect.call(instance.get("_run_state") == before, "Scroll and selection preserve deck, wallet and purge counters")
	if controller: await fixture.call("_joy", JOY_BUTTON_B)
	else: await fixture.call("_key", KEY_ESCAPE)
	expect.call(str(modal.get("pending_card_id")).is_empty() and expected.has_focus(), "Back restores the same visible card's focus")

static func _navigation_routes(fixture: SceneTree, instance: Node, modal: Control, scroll: ScrollContainer, grid: Control, expect: Callable) -> void:
	var last_column: int = (grid.get_child_count() - 1) % TEST_COLUMNS
	for controller: bool in [false, true]:
		(grid.get_child(last_column) as Control).grab_focus()
		for _step: int in range(2):
			if controller: await fixture.call("_joy", JOY_BUTTON_DPAD_DOWN)
			else: await fixture.call("_key", KEY_DOWN)
		assert_focus(scroll, grid, grid.get_child_count() - 1, expect)
		expect.call(scroll.scroll_vertical == TEST_ROW_PITCH, "Keyboard/controller navigation reveals the intended final-row card")
		await _activate_and_back(fixture, instance, modal, grid.get_child(grid.get_child_count() - 1), controller, expect)
		_manual_scroll(scroll, "trackpad" if controller else "wheel", -1)
		assert_focus(scroll, grid, 0, expect)
		if controller: await fixture.call("_joy", JOY_BUTTON_DPAD_RIGHT)
		else: await fixture.call("_key", KEY_RIGHT)
		assert_focus(scroll, grid, 1, expect)
		await _activate_and_back(fixture, instance, modal, grid.get_child(1), controller, expect)
		(grid.get_child(grid.get_child_count() - 1) as Control).grab_focus()
		for _step: int in range(2):
			if controller: await fixture.call("_joy", JOY_BUTTON_DPAD_UP)
			else: await fixture.call("_key", KEY_UP)
		assert_focus(scroll, grid, last_column, expect)

