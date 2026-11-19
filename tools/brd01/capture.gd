extends SceneTree

const Fixture = preload("res://tools/brd01/fixture.gd")
const OUTPUT_DIR: String = "user://brd01"
const UI_SCALE: float = 1.0
const HAND_SIZE: int = 5
const READY_FRAME_LIMIT: int = 40
const FPS: int = 30
const CLIP_SECONDS: int = 3
const TOGGLE_FRAMES: int = 15
const CLIP_FRAMES: int = FPS * CLIP_SECONDS

var _scene: Control
var _board: Control
var _canvas: SubViewport
var _hero_tile: Vector2i
var _unselected: Dictionary
var _output_dir: String
var _check_only: bool
var _failures: Array[String]
var _samples: Array[Dictionary]

func _initialize() -> void:
	Fixture.Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var clip: bool = args.has("--clip")
	_check_only = args.has("--check-only")
	_require(_check_only or DisplayServer.get_name() != "headless", "Capture requires a windowed renderer")
	var run: Dictionary = Fixture.encounter("combat")
	_require(run.get("mode") == "combat", "Generated normal combat")
	if not _failures.is_empty():
		_finish()
		return
	_output_dir = ProjectSettings.globalize_path(OUTPUT_DIR)
	var output_arg: int = args.find("--output-dir")
	if output_arg >= 0:
		_output_dir = ProjectSettings.globalize_path(args[output_arg + 1])
	if not _check_only:
		var frame_dir: String = _output_dir.path_join("frames") if clip else _output_dir
		_require(DirAccess.make_dir_recursive_absolute(frame_dir) == OK, "Capture output directory")
	if clip: Engine.max_fps = FPS

	# Render a native-size target even on a monitor that cannot show a full
	# 1920×1080 window. The host window is only a preview of that target.
	_canvas = SubViewport.new()
	_canvas.size = Fixture.DESKTOP
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_canvas)
	var preview := TextureRect.new()
	preview.texture = _canvas.get_texture()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	root.add_child(preview)
	preview.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	root.get_node("InputRouter").call("set_forced_state_for_test", "controller", Fixture.Router.FAMILY_XBOX)
	_scene = Fixture.mount(self, _canvas, run, UI_SCALE)
	if _scene == null:
		_require(false, "Combat save loaded")
		_finish()
		return
	var combat: Dictionary = _scene.get("_combat_state")
	_board = _scene.get("board_view")
	_hero_tile = combat["player"]["pos"]
	Fixture.set_hand(_scene, combat, Fixture.CARDS["attack"], HAND_SIZE)
	for frame: int in range(READY_FRAME_LIMIT):
		if Fixture.ready_for_input(_scene): break
		await process_frame
	var tween: Tween = _scene.get("_board_centering_tween")
	if tween != null and tween.is_running(): await tween.finished
	await Fixture.settle(self)
	_require(Fixture.ready_for_input(_scene), "Room entry and HUD budget settled")
	_require(_canvas.size == Fixture.DESKTOP and _canvas.get_visible_rect().size == Vector2(Fixture.DESKTOP)
		and is_equal_approx(root.content_scale_factor, UI_SCALE), "1920×1080 output at 100% UI scale")
	_unselected = Fixture.coordinates(_board, _hero_tile)
	if clip:
		await _clip()
	else:
		await _capture("unselected.png", false)
		await _set_selected(true)
		await Fixture.settle(self)
		await _capture("selected.png", true)
	if not _check_only:
		var report := FileAccess.open(_output_dir.path_join("transforms.json"), FileAccess.WRITE)
		_require(report != null, "Transform report can be written")
		if report != null: report.store_string(JSON.stringify(_samples, "\t", true, true))
		print(_output_dir)
	_finish()

func _clip() -> void:
	var selected: bool = false
	for frame: int in range(CLIP_FRAMES):
		if frame > 0 and frame % TOGGLE_FRAMES == 0:
			selected = not selected
			await _set_selected(selected)
		await _capture("frames/board_%03d.png" % frame, selected)

func _set_selected(selected: bool) -> void:
	if selected:
		_scene.call("_controller_clear_focus_candidate")
		_scene.set("_controller_region", "hand")
		_scene.call("_controller_set_hand_focused", true)
		_scene.set("_controller_hand_index", 0)
		await Fixture.controller_button(_scene, JOY_BUTTON_A)
	else:
		await Fixture.controller_button(_scene, JOY_BUTTON_B)

func _capture(filename: String, selected: bool) -> void:
	if _check_only:
		await process_frame
	else:
		await RenderingServer.frame_post_draw
	var targeting: bool = _scene.call("_board_targeting_active")
	var transform: Dictionary = Fixture.coordinates(_board, _hero_tile)
	var index: int = _scene.get("_selected_card_index")
	var actions: Array = _scene.get("_pending_actions")
	var expected_card: bool = index == 0 and not actions.is_empty() and actions[0].get("_card_id") == Fixture.CARDS["attack"]
	_require(targeting == selected and (expected_card if selected else index < 0), filename + " has the requested card state")
	_require(transform == _unselected, filename + " keeps the exact unselected projection")
	_samples.append({"file": filename, "selected": selected, "transform": transform})
	if not _check_only:
		var image: Image = _canvas.get_texture().get_image()
		_require(image.get_size() == Fixture.DESKTOP and image.save_png(_output_dir.path_join(filename)) == OK, filename + " saved")

func _require(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _finish() -> void:
	for failure: String in _failures: print("BRD01 CAPTURE ERROR ", failure)
	print("BRD01 CAPTURE RESULT: %s (%d frames, %d failures%s)" % [
		"PASS" if _failures.is_empty() else "FAIL", _samples.size(), _failures.size(),
		", headless setup only" if _check_only else "",
	])
	quit(0 if _failures.is_empty() else 1)
