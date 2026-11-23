extends SceneTree

const Fixture = preload("res://tools/gfix30/fixture.gd")
const RunFixture = preload("res://tools/gfix30/run_fixture.gd")
const RouteInput = preload("res://tools/smoke_recording/route_input.gd")
const Data = preload("res://scripts/game_data.gd")
const Events = preload("res://scripts/event_rules.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const View = preload("res://scripts/event_view.gd")
const PARTIAL_TRANSFORM_IDS: Array = ["buffet"]

var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	process_frame.connect(_headless_draw_tick)
	await _check_run_scene()
	var viewport := SubViewport.new()
	viewport.size = Fixture.RESOLUTION
	root.add_child(viewport)
	var starter: Dictionary = Fixture.starter()
	var spells: Array = starter["attuned_magic_cards"]
	if spells != Data.starting_magic_cards() or spells[int(starter["starter_buffet_magic_slot"])] != "buffet":
		print("GFIX30 FAIL: fixture does not have the opening Buffet")
		quit(1)
		return
	var ids: Array = [Fixture.ASH]
	if OS.get_cmdline_user_args().has("--sweep"):
		ids = Data.events().keys()
		ids.sort()
	await _check_state(viewport, "starter", starter, ids, Fixture.START_SECTION)
	await _check_unbuildable(viewport, starter)
	if OS.get_cmdline_user_args().has("--sweep"):
		var mid: Dictionary = Fixture.mid_run(starter)
		await _check_state(viewport, "mid-run", mid, ids, Fixture.MID_SECTION)
	print("GFIX30 TOTAL: %d failures" % failures)
	viewport.free()
	quit(0 if failures == 0 else 1)

func _headless_draw_tick() -> void:
	RenderingServer.frame_post_draw.emit()

func _check_run_scene() -> void:
	var started_with: int = failures
	var view: Control = await RunFixture.install(self)
	if view == null:
		_fail("RunScene", Fixture.ASH, "fixture", "installation failed")
		return
	var hover: Control = view.hover_preview
	var driver := RouteInput.new(self, false)
	for frame: int in range(Fixture.FRAME_LIMIT):
		if not view.get("_busy") and not current_scene.get("_animation_lock"): break
		await process_frame
	for index: int in range(view.choices.size()):
		var choice: Button = view.choices[index]
		if not choice.available: continue
		var line: Dictionary = Preview.hover_line(view.cached_preview_lines(choice.choice_id))
		if choice.choice_id == "some":
			var ids: Array = line.get("ids", [])
			print("GFIX30 RunScene transform: %s" % str(ids))
			if ids != ["buffet", "hoarfrost_ward"]:
				_fail("RunScene", Fixture.ASH, choice.choice_id, "fixture differs from the reported opening Buffet transform")
		driver.motion(Fixture.choice_point(choice))
		var ready: bool = false
		for frame: int in range(Fixture.FRAME_LIMIT):
			ready = hover.preparation_snapshot().phase == "ready"
			if ready and int(view.get("_pointer_choice")) == index and _preview_matches(hover, line): break
			await process_frame
		if not ready: _fail("RunScene", Fixture.ASH, choice.choice_id, "preparation did not reach ready: %s" % hover.preparation_snapshot())
		if int(view.get("_pointer_choice")) != index:
			_fail("RunScene", Fixture.ASH, choice.choice_id, "viewport motion selected %d" % int(view.get("_pointer_choice")))
		_check_preview(hover, line, "RunScene", Fixture.ASH, choice.choice_id, "pointer")
		view.move_focus(index - view.focused_choice_index())
		_check_preview(hover, line, "RunScene", Fixture.ASH, choice.choice_id, "focus")
	print("GFIX30 RunScene: %d failures; preparation=%s" % [failures - started_with, hover.preparation_snapshot().phase])
	unload_current_scene()
	await process_frame

func _check_state(viewport: SubViewport, label: String, base: Dictionary, ids: Array, section: int) -> void:
	var started_with: int = failures
	var counts: Dictionary = {"available": 0, "preview": 0, "no_preview": 0, "blocked": 0}
	for id: String in ids:
		var state: Dictionary = Fixture.event(base, id, section)
		if state.is_empty():
			_fail(label, id, "fixture", "no event room in section %d" % section)
			continue
		var view := View.new()
		viewport.add_child(view)
		view.present(state)
		var hover: Control = view.hover_preview
		for frame: int in range(Fixture.FRAME_LIMIT):
			if not hover.preparation_snapshot().active and not view.get("_busy"): break
			await process_frame
		for choice: Button in view.choices:
			var choice_id: String = choice.choice_id
			if not Events.choice_available(state, id, choice_id):
				counts.blocked += 1
				continue
			counts.available += 1
			var expected: Dictionary = Preview.hover_line(Events.preview_lines(state, id, choice_id))
			if id == Fixture.ASH and choice_id in ["some", "all"] and expected.get("kind") != "transform":
				_fail(label, id, choice_id, "missing transform line")
			counts.no_preview += int(expected.is_empty())
			counts.preview += int(not expected.is_empty())
			if not expected.is_empty() and hover.preparation_snapshot().phase != "ready":
				_fail(label, id, choice_id, "preparation did not reach ready: %s" % hover.preparation_snapshot())
			_check_inputs(view, choice, expected, label, id)
		view.queue_free()
		await process_frame
	print("GFIX30 %s: %d events; %d available; %d previews; %d no preview line; %d blocked; %d failures" % [label, ids.size(), counts.available, counts.preview, counts.no_preview, counts.blocked, failures - started_with])

func _check_unbuildable(viewport: SubViewport, starter: Dictionary) -> void:
	var started_with: int = failures
	var view := View.new()
	viewport.add_child(view)
	view.present(Fixture.event(starter, Fixture.ASH), true)
	var hover: Control = view.hover_preview
	hover.clear()
	# A failed transform can supply its source with no destination. Keep the
	# valid sibling preview in the real queue alongside this fault injection.
	var lines: Dictionary = view.get("_preview_cache")
	lines["some"][0]["ids"] = PARTIAL_TRANSFORM_IDS
	view.finish_animation_for_test()
	var incomplete: Dictionary = Preview.hover_line(view.cached_preview_lines("some"))
	if hover.cache.has(hash(incomplete)):
		_fail("isolation", Fixture.ASH, "some", "cached an incomplete transform")
	for choice: Button in view.choices:
		var expected: Dictionary = {} if choice.choice_id == "some" else Preview.hover_line(view.cached_preview_lines(choice.choice_id))
		_check_inputs(view, choice, expected, "isolation", Fixture.ASH)
	print("GFIX30 isolation: %d failures" % (failures - started_with))
	view.queue_free()
	await process_frame

func _check_inputs(view: Control, choice: Button, line: Dictionary, label: String, event_id: String) -> void:
	var index: int = view.choices.find(choice)
	var motion := InputEventMouseMotion.new()
	view.hover_preview.conceal(true)
	# RunScene routes motion to the view before GUI picking. A second motion
	# must identify its target even if GUI picking has yet to send mouse_entered.
	view.handle_input(motion)
	motion.position = Fixture.choice_point(choice)
	view.handle_input(motion)
	_check_preview(view.hover_preview, line, label, event_id, choice.choice_id, "motion before GUI enter")
	choice.mouse_entered.emit()
	if view.get("_pointer_choice") != index:
		_fail(label, event_id, choice.choice_id, "pointer did not select choice")
	_check_preview(view.hover_preview, line, label, event_id, choice.choice_id, "pointer")
	choice.mouse_exited.emit()
	view.hover_preview.conceal(true)
	view.move_focus(index - view.focused_choice_index())
	if not choice.has_focus(): _fail(label, event_id, choice.choice_id, "choice did not receive focus")
	_check_preview(view.hover_preview, line, label, event_id, choice.choice_id, "focus")

func _check_preview(hover: Control, line: Dictionary, label: String, event_id: String, choice_id: String, input: String) -> void:
	if not _preview_matches(hover, line):
		_fail(label, event_id, choice_id, "%s expected %s, got %s, visible=%s, cache_has_line=%s" % [input, line, hover.current_line, _preview_visible(hover), hover.cache.has(hash(line))])

func _preview_visible(hover: Control) -> bool:
	return is_instance_valid(hover.current) and hover.current.is_visible_in_tree()

func _preview_matches(hover: Control, line: Dictionary) -> bool:
	return hover.current_line == line and _preview_visible(hover) == (not line.is_empty())

func _fail(label: String, event_id: String, choice_id: String, message: String) -> void:
	failures += 1
	print("GFIX30 FAIL %s %s/%s: %s" % [label, event_id, choice_id, message])
