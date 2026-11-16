extends "res://tests/pre_battle_fixture.gd"

# Task-local proof, not a permanent regression suite. Native runs capture the
# actual Window, Settings UI scaling and real Scavenger confirmation/commit.
const Fixture = preload("res://tests/suites/magic_deck_suite.gd")
const Presentation = preload("res://tests/suites/magic_purge_presentation.gd")
const STEP_SECONDS: float = 1.0 / 60.0
const RECT_TOLERANCE_PX: float = 0.5
const PROOF_SCROLL: int = 296
const TAIL_FRAMES: int = 32
var _output: String = "/private/tmp/purge-04-proof"
var _baseline: bool = false
var _native_capture: bool
var _requested_size: Vector2i
var _rows: Array[Dictionary]
var _strip_frames: Dictionary

func _initialize() -> void:
	_setup()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="): _output = argument.trim_prefix("--output=")
		if argument == "--baseline": _baseline = true
	_native_capture = DisplayServer.get_name().to_lower() != "headless"
	if _native_capture: Engine.max_fps = roundi(1.0 / STEP_SECONDS)
	var resolution := Vector2i(1920, 1080)
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--deck": resolution = Vector2i(1280, 800)
	_requested_size = resolution
	root.mode = Window.MODE_WINDOWED
	root.size = resolution
	DirAccess.make_dir_recursive_absolute(_output)
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	ProgressionStore.save_data(profile)
	for ui_scale: float in [1.0, float(Settings.SUPPORTED_UI_SCALES.back())]:
		for reduced: bool in [false, true]:
			await _purge_case(resolution, ui_scale, reduced)
	var report := FileAccess.open(_output.path_join("rects.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"native": _native_capture, "baseline": _baseline, "measurements": _rows}, "\t"))
	print("PURGE-04 PROOF: %s output=%s native=%s" % ["FAIL" if _failed else "PASS", _output, _native_capture])
	print(_output)
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _purge_case(resolution: Vector2i, ui_scale: float, reduced: bool) -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	var engine := RunEngine.new()
	var state: Dictionary = Fixture.shop_fixture(engine)
	state["attuned_magic_cards"] = Presentation.unique_cards(Presentation.OVERFLOW_IDENTITIES)
	state = engine.repair_loaded_run_state(state)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	if _native_capture:
		root.add_child(instance)
	else:
		_viewport.size = resolution
		_viewport.size_2d_override = Vector2i(Vector2(resolution) / ui_scale)
		_viewport.size_2d_override_stretch = true
		_viewport.add_child(instance)
	await _settle()
	# Run-scene startup applies display settings, including its default window
	# dimensions. Restore the requested native size after that startup hook.
	if _native_capture:
		root.size = resolution
		Settings.apply_settings(settings, root, false)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	instance.set("_animation_lock", false)
	instance.call("_open_magic_purge", "scavenger")
	await _settle()
	var modal: Control = instance.get("_magic_purge_overlay")
	var scroll: ScrollContainer = modal.find_child("MagicPurgeScroll", true, false)
	scroll.scroll_vertical = PROOF_SCROLL
	await _settle()
	_expect(scroll.scroll_vertical > 0, "Proof uses a scrolled purge list")
	modal.call("select_card", str(state["attuned_magic_cards"][0]))
	await _settle()
	var slot: Control = modal.find_child("MagicPurgeConfirmCardSlot", true, false)
	var expected: Rect2 = _screen_rect(slot)
	var case_name: String = "ui%d_%s" % [roundi(ui_scale * 100), "reduced" if reduced else "burn"]
	var folder: String = _output.path_join(case_name)
	DirAccess.make_dir_recursive_absolute(folder)
	_strip_frames.clear()
	await _frame(folder, 0)
	_record(case_name, 0, expected, expected)
	var before_tweens: Array[Tween] = get_processed_tweens()
	var confirm: Button = modal.find_child("ConfirmMagicPurge", true, false)
	confirm.pressed.emit()
	var burn: Control = modal.find_child("CardProxy", true, false)
	_expect(burn != null, "Real confirm creates PurgeBurn")
	if burn == null: return
	if _baseline:
		# Exact reconstruction of the pre-fix inherited transform. No shader,
		# layout, clock or gameplay state is replaced for the before strip.
		burn.top_level = false
		burn.position = Vector2.ZERO
	var clocks: Array[Tween]
	for tween: Tween in get_processed_tweens():
		if not before_tweens.has(tween):
			tween.pause()
			clocks.append(tween)
	_expect(not clocks.is_empty(), "Proof steps the real confirmation tween")
	var duration: float = 0.25 if reduced else 0.70
	var frame_count: int = ceili(duration / STEP_SECONDS)
	for frame: int in range(1, frame_count + TAIL_FRAMES + 1):
		# Draw the first burn frame at t=0, then every actual tween step. Stepping
		# avoids readback stalls skipping the first ten native render frames.
		if is_instance_valid(burn) and frame <= frame_count:
			var paint: Control = burn.get("_paint")
			var actual: Rect2 = paint.get_viewport().get_final_transform() * paint.get_global_transform_with_canvas() * slot.get_global_rect()
			_record(case_name, frame, expected, actual)
		await _frame(folder, frame)
		if frame == 3 and is_instance_valid(modal):
			confirm.pressed.emit()
			modal.call("cancel")
		for tween: Tween in clocks:
			if tween.is_valid(): tween.custom_step(STEP_SECONDS)
	var after: Dictionary = instance.get("_run_state")
	_expect(int(after.get("magic_purges_this_run", 0)) == int(state.get("magic_purges_this_run", 0)) + 1, "Repeated input commits exactly once")
	_expect(engine.held_embers(after) == engine.held_embers(state) - 50, "Exactly one price is charged")
	_expect(not is_instance_valid(instance.get("_magic_purge_overlay")), "Real continuation closes the purge")
	if _native_capture: _contact_sheet(folder, resolution)
	instance.queue_free()
	for _frame_index: int in range(Presentation.TEARDOWN_FRAMES): await process_frame

func _screen_rect(control: Control) -> Rect2:
	return control.get_viewport().get_final_transform() * control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)

func _record(case_name: String, frame: int, expected: Rect2, actual: Rect2) -> void:
	var delta: Vector2 = actual.position - expected.position
	var size_delta: Vector2 = actual.size - expected.size
	var error: float = maxf(maxf(absf(delta.x), absf(delta.y)), maxf(absf(size_delta.x), absf(size_delta.y)))
	_rows.append({"case": case_name, "frame": frame, "expected": _rect_values(expected), "actual": _rect_values(actual), "max_error_px": error})
	if frame <= 10: print("PURGE-04 RECT %s frame=%d expected=%s actual=%s error=%.4fpx" % [case_name, frame, expected, actual, error])
	if not _baseline: _expect(error <= RECT_TOLERANCE_PX, "Burn card stays within 0.5px: " + case_name)

func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _frame(folder: String, frame: int) -> void:
	if _native_capture:
		await RenderingServer.frame_post_draw
		var image: Image = root.get_texture().get_image()
		_expect(image != null and image.get_size() == _requested_size, "Native frame matches requested Window size")
		if image != null:
			_expect(image.save_png(folder.path_join("frame_%03d.png" % frame)) == OK, "Frame saves")
			if frame in [0, 1, 3, 6, 12]: _strip_frames[frame] = image
			_strip_frames[-1] = image
	await process_frame

func _contact_sheet(folder: String, resolution: Vector2i) -> void:
	# Native, unscaled tiles: confirmation, burn 1/3/6/12, final.
	var indices: Array[int] = [0, 1, 3, 6, 12, -1]
	var sheet := Image.create(resolution.x * 3, resolution.y * 2, false, Image.FORMAT_RGB8)
	for index: int in range(indices.size()):
		sheet.blit_rect(_strip_frames[indices[index]], Rect2i(Vector2i.ZERO, resolution), Vector2i(index % 3, index / 3) * resolution)
	_expect(sheet.save_png(folder.path_join("contact_sheet.png")) == OK, "Native contact sheet saves")
