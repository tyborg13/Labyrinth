extends "res://tests/pre_battle_fixture.gd"

const BookData = preload("res://scripts/grimoire_library.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CREATURES: String = "creatures"
const LAYOUT_FRAMES: int = 8
const WHEEL_LIMIT: int = 180
const MIN_DRAG_STEPS: int = 8
const DRAG_STEP_PAGE_FRACTION: float = 0.5
const SELECTION_IDLE_SECONDS: float = 0.35
const SELECTION_INDEX: int = 1
const PROOF_TOP_OFFSET: int = 24

var _scene: Node
var _book: Control
var _scroll: ScrollContainer
var _list: VBoxContainer
var _bar: VScrollBar
var _trace: bool
var _diagnose_cache: bool
var _range_changes: int
var _capture_count: int
var _trials: int

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_diagnose_cache = "--diagnose-cache" in args
	_setup()
	var settings: Dictionary = Settings.default_settings()
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	_scene = await _instance(_run_with_available_combat(RunEngine.new()))
	var ids: Array[String]
	for entry: Dictionary in BookData.entries():
		ids.append(str(entry["id"]))
	_scene._run_state[BookData.UNLOCKED_KEY] = ids
	_book = _scene._grimoire_scrim
	_scroll = _book._grimoire_entry_scroll
	_list = _book._grimoire_section_list
	_bar = _scroll.get_v_scroll_bar()
	_scroll.pre_sort_children.connect(_trace_state.bind("scroll pre-sort"))
	_scroll.sort_children.connect(_trace_state.bind("scroll post-sort"))
	_scroll.minimum_size_changed.connect(_trace_state.bind("scroll minimum_size_changed"))
	_list.minimum_size_changed.connect(_trace_state.bind("list minimum_size_changed"))
	_bar.changed.connect(_on_range_changed)
	_bar.visibility_changed.connect(_on_range_changed)
	_bar.value_changed.connect(func(_value: float) -> void: _trace_state("bar value_changed"))
	_viewport.gui_embed_subwindows = true
	var capture_output: String = OS.get_environment("GFIX51_CAPTURE_OUTPUT")
	await _exercise(CREATURES, "", capture_output)
	if capture_output.is_empty() and not _diagnose_cache and "--creatures-only" not in args:
		for section: Dictionary in BookData.sections():
			var section_id: String = str(section["id"])
			if section_id == CREATURES: continue
			await _open_list(section_id, "")
			var groups: Array[String]
			for button: Button in _book._grimoire_nav_buttons:
				if button.get_meta("grimoire_nav_kind") == "group":
					groups.append(str(button.get_meta("grimoire_nav_id")))
			if groups.is_empty():
				if _overflows(): await _exercise(section_id)
			else:
				for group: String in groups:
					await _open_list(section_id, group)
					if _overflows(): await _exercise(section_id, group)
	_book.close()
	_viewport.queue_free()
	await process_frame
	if not _diagnose_cache:
		print("GFIX51 SCROLL: %s (%d input trials, %d capture states)" %
			["FAIL" if _failed else "PASS", _trials, _capture_count])
	quit(int(_failed))

func _exercise(section: String, group: String = "", capture_output: String = "") -> void:
	var modes: Array[String] = ["wheel", "drag", "keyboard", "controller"]
	if not capture_output.is_empty(): modes.resize(2)
	for mode: String in modes:
		await _open_list(section, group)
		if not _overflows():
			_fail(section + " must overflow")
			return
		var entries: Array[Button]
		for button: Button in _book._grimoire_nav_buttons:
			if button.get_meta("grimoire_nav_kind") == "entry": entries.append(button)
		if entries.size() <= SELECTION_INDEX:
			_fail(section + " must have a second page")
			return
		var selected: Button = entries[SELECTION_INDEX]
		var selected_id: String = str(selected.get_meta("grimoire_nav_id"))
		var last_id: String = str(entries.back().get_meta("grimoire_nav_id"))
		var last_title: String = BookData.entry_def(last_id)["title"]
		var trial: String = "%s %s" % [section if group.is_empty() else group, mode]
		# Put the selected page near the top at a nonzero offset. This also
		# keeps the press from using follow_focus to reveal a clipped button.
		_scroll.scroll_vertical = int(selected.get_parent().position.y) - PROOF_TOP_OFFSET
		await _layout_frames()
		var before: float = _bar.value
		_expect(before > 0 and _visible(selected), trial + " has a visible page at a nonzero scroll position")
		_range_changes = 0
		_trace = section == CREATURES and mode == "wheel"
		_report(trial + " before selection")
		await _click(selected)
		await create_timer(SELECTION_IDLE_SECONDS).timeout
		_report(trial + " after selection")
		_expect(_book._grimoire_selected_entry == selected_id, trial + " opens " + selected_id)
		_expect(_bar.value == before and _range_changes == 0, trial + " preserves offset and scrollbar range during selection")
		_expect(_viewport.gui_get_focus_owner() == _button("entry", selected_id), trial + " preserves focus on the opened page")
		if _diagnose_cache:
			_diagnose_scroll_sort()
			return
		var last: Button = _button("entry", last_id)
		var drag_revealed_last: bool = false
		match mode:
			"wheel": await _wheel(last)
			"drag": drag_revealed_last = await _drag(trial, last)
			"keyboard", "controller": await _walk_focus(last, mode == "controller")
		_trace = false
		_report(trial + " after input")
		var reached: bool = _bar.visible and _visible(last)
		if mode == "drag":
			reached = _bar.visible and drag_revealed_last and is_equal_approx(_bar.value, _bar.max_value - _bar.page) \
				and _visible(_book._grimoire_nav_buttons.back())
		if mode in ["keyboard", "controller"]: reached = reached and _viewport.gui_get_focus_owner() == last
		print("GFIX51 %s reached %s (%s)=%s" % [trial, last_title, last_id, reached])
		_expect(reached, trial + " reaches " + last_id)
		_trials += 1
		if reached and not capture_output.is_empty(): await _save_capture(capture_output, mode, last)

func _open_list(section: String, group: String) -> void:
	if _book.visible: _book.close()
	_scene._open_grimoire_overlay()
	await _layout_frames()
	# Switch away before reopening a section from the previous trial.
	if _book._grimoire_selected_section == section:
		await _reveal_and_click(_button("section", "basics" if section != "basics" else CREATURES))
	await _reveal_and_click(_button("section", section))
	if not group.is_empty() and group != "%s:%s" % [section, _book._grimoire_selected_group]:
		await _reveal_and_click(_button("group", group))

func _reveal_and_click(button: Button) -> void:
	_scroll.ensure_control_visible(button)
	await _layout_frames()
	await _click(button)
	await _layout_frames()

func _button(kind: String, id: String) -> Button:
	for button: Button in _book._grimoire_nav_buttons:
		if button.get_meta("grimoire_nav_kind") == kind and button.get_meta("grimoire_nav_id") == id:
			return button
	return null

func _layout_frames() -> void:
	for _frame: int in LAYOUT_FRAMES: await process_frame

func _overflows() -> bool:
	return _list.get_combined_minimum_size().y > _scroll.size.y

func _visible(control: Control) -> bool:
	return control != null and _scroll.get_global_rect().encloses(control.get_global_rect())

func _wheel(last: Button) -> void:
	var point: Vector2 = _scroll.get_global_rect().get_center()
	await _pointer(point)
	for index: int in WHEEL_LIMIT:
		_mouse_button(point, MOUSE_BUTTON_WHEEL_DOWN, true)
		_mouse_button(point, MOUSE_BUTTON_WHEEL_DOWN, false)
		if index == 0: _trace_state("first wheel dispatched")
		await process_frame
		if index == 0:
			_trace_state("first wheel settled")
			_trace = false
		if not _bar.visible or _visible(last): break

func _drag(trial: String, last: Button) -> bool:
	if not _bar.visible: return false
	var rect: Rect2 = _bar.get_global_rect()
	var thumb := Vector2(rect.get_center().x, rect.position.y + rect.size.y * (_bar.value + _bar.page * 0.5) / _bar.max_value)
	await _pointer(thumb)
	_expect(_viewport.gui_get_hovered_control() == _bar, trial + " targets the visible scrollbar")
	var before: float = _bar.value
	_mouse_button(thumb, MOUSE_BUTTON_LEFT, true)
	await process_frame
	_expect(_bar.value == before, trial + " thumb press does not page the scrollbar")
	var finish := Vector2(thumb.x, rect.end.y - 1.0)
	var previous: Vector2 = thumb
	var steps: int = maxi(MIN_DRAG_STEPS, ceili((_bar.max_value - _bar.page) / (_bar.page * DRAG_STEP_PAGE_FRACTION)))
	var revealed_last: bool = _visible(last)
	for step: int in range(1, steps + 1):
		var point: Vector2 = thumb.lerp(finish, float(step) / steps)
		var motion := InputEventMouseMotion.new()
		motion.position = point
		motion.global_position = point
		motion.relative = point - previous
		motion.button_mask = MOUSE_BUTTON_MASK_LEFT
		_viewport.push_input(motion, true)
		previous = point
		await process_frame
		revealed_last = revealed_last or _visible(last)
	_mouse_button(finish, MOUSE_BUTTON_LEFT, false)
	await _layout_frames()
	return revealed_last or _visible(last)

func _mouse_button(point: Vector2, index: MouseButton, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = index
	event.pressed = pressed
	event.factor = 1.0
	_viewport.push_input(event, true)

func _walk_focus(last: Button, controller: bool) -> void:
	for _step: int in _book._grimoire_nav_buttons.size():
		if _viewport.gui_get_focus_owner() == last: break
		if controller:
			await _joy(JOY_BUTTON_DPAD_DOWN)
		else:
			await _key(KEY_DOWN)

func _on_range_changed() -> void:
	_range_changes += 1
	_trace_state("bar range/visibility changed")

func _trace_state(phase: String) -> void:
	if _trace:
		print("GFIX51 TRACE %s: rows=%d max=%d page=%d value=%d visible=%s" %
			[phase, _list.get_child_count(), _bar.max_value, _bar.page, _bar.value, _bar.visible])

func _report(phase: String) -> void:
	print("GFIX51 %s: viewport=%d content=%d minimum=%d max=%d page=%d value=%d bar=%s" %
		[phase, _scroll.size.y, _list.size.y, _list.get_combined_minimum_size().y,
		_bar.max_value, _bar.page, _bar.value, _bar.visible])

func _diagnose_scroll_sort() -> void:
	# This isolated diagnostic runs outside the wheel, drag and focus trials.
	# Both native sorts run immediately, before deferred minimum-size updates.
	_scroll.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_report("direct SORT_CHILDREN without input")
	_scroll.get_minimum_size()
	_scroll.notification(Container.NOTIFICATION_SORT_CHILDREN)
	_report("direct SORT_CHILDREN after minimum-size query")
	_trace = false

func _save_capture(output: String, mode: String, last: Button) -> void:
	_expect(is_equal_approx(Typography.ui_scale(_book), 1.0), "Capture uses 100% UI scale")
	_expect(_visible(last), "The whole last creature row is inside the capture's list viewport")
	print("GFIX51 CAPTURE %s: list=%s last=%s scrollbar=%s" %
		[mode, _scroll.get_global_rect(), last.get_global_rect(), _bar.get_global_rect()])
	var path: String = output.path_join("%s_end_1920x1080.png" % mode)
	if DisplayServer.get_name() == "headless":
		print("WOULD CAPTURE " + path)
	else:
		await _capture(path)
		if FileAccess.file_exists(path): print(path)
	_capture_count += 1
