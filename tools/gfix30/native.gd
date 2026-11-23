extends SceneTree

const Fixture = preload("res://tools/gfix30/fixture.gd")
const RunFixture = preload("res://tools/gfix30/run_fixture.gd")
const RouteInput = preload("res://tools/smoke_recording/route_input.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Cel = preload("res://scripts/cel_look.gd")
const CHOICES: Array = ["some", "all"]
const HOLD_SECONDS: float = 1.0
const OUTPUT_ARG: String = "--out="

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var check_fixture: bool = args.has("--check-fixture")
	if check_fixture != (DisplayServer.get_name() == "headless"):
		_fail("Use --check-fixture for headless validation or a native renderer for captures")
		return
	if Cel.mode != "all" or Cel._files.is_empty():
		_fail("The installed cel look must be enabled")
		return
	var output: String = ""
	for arg: String in args:
		if arg.begins_with(OUTPUT_ARG): output = arg.trim_prefix(OUTPUT_ARG)
	if not check_fixture and (not output.is_absolute_path() or DirAccess.make_dir_recursive_absolute(output) != OK):
		_fail("Use an absolute writable --out directory")
		return
	if check_fixture: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	var view: Control = await RunFixture.install(self)
	if view == null:
		_fail("RunScene did not load")
		return
	var hover: Control = view.hover_preview
	for frame: int in range(Fixture.FRAME_LIMIT):
		if _ready_to_hover(view): break
		await process_frame
	var hud: Control = current_scene.find_child("RoomTitle", true, false) as Control
	if not _ready_to_hover(view) or hud == null or not hud.is_visible_in_tree():
		_fail("Expected the live, unlocked Ash Confessional and RunScene HUD: %s" % hover.preparation_snapshot())
		return
	var driver := RouteInput.new(self, false)
	for index: int in range(CHOICES.size()):
		var choice: Button = view.choices[index]
		if not choice.available or choice.choice_id != CHOICES[index]:
			_fail("Expected an available %s choice" % CHOICES[index])
			return
		driver.motion(Fixture.choice_point(choice))
		await create_timer(HOLD_SECONDS).timeout
		var expected: Dictionary = Preview.hover_line(view.cached_preview_lines(choice.choice_id))
		if not _visible_preview(view, index, expected):
			_fail("Missing hovered transform for %s: %s" % [choice.choice_id, hover.preparation_snapshot()])
			return
		if not check_fixture:
			await RenderingServer.frame_post_draw
			var path: String = output.path_join("ash_confessional_%02d_%s.png" % [index + 1, choice.choice_id])
			var still: Image = root.get_texture().get_image()
			if still == null or still.get_size() != Fixture.RESOLUTION or still.save_png(path) != OK:
				_fail("Could not save a 1920x1080 image at %s" % path)
				return
			print(path)
	print("GFIX30 %s: PASS (two hovered transforms; cel look and HUD on)" % ("native fixture" if check_fixture else "native stills"))
	unload_current_scene()
	await process_frame
	quit()

func _ready_to_hover(view: Control) -> bool:
	return not view.get("_busy") and not current_scene.get("_animation_lock") and view.hover_preview.preparation_snapshot().phase == "ready"

func _visible_preview(view: Control, index: int, expected: Dictionary) -> bool:
	var hover: Control = view.hover_preview
	return expected.get("kind") == "transform" and view.get("_pointer_choice") == index and hover.current_line == expected and is_instance_valid(hover.current) and hover.current.is_visible_in_tree() and is_equal_approx(hover.current.modulate.a, 1.0)

func _fail(message: String) -> void:
	push_error("GFIX30 native: " + message)
	quit(1)
