extends SceneTree
## Production Continue boot for the headless witness, captures, and playable saves.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const SIZE := Vector2i(1920, 1080)
const SETTLE_SECONDS := 0.35
const INPUT_TIMEOUT_MSEC := 25000
const BOARD_LAYOUT_TIMEOUT_MSEC := 5000
const MIN_TILE_WIDTH := 40.0
const STABLE_LAYOUT_FRAMES := 10
const NO_POINTER := Vector2(-1, -1)

var viewport: Viewport
var scene: Node
var board: Control
var dry: bool
var tool_dir: String
var fixture_root: String
var run_path: String

func _initialize() -> void:
	Runtime.apply_from_environment()
	dry = DisplayServer.get_name() == "headless"
	if dry: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	tool_dir = OS.get_environment("FEL13_TOOL_DIR")
	if tool_dir.is_empty(): tool_dir = ProjectSettings.globalize_path("res://tools/fel13")
	fixture_root = tool_dir.path_join("fixtures")
	var mode: String = OS.get_environment("FEL13_MODE")
	# Still and timing probes use their own 1920×1080 SubViewport, as in
	# fel-01. Only the native movie records the root window.
	if mode == "motion" and not dry:
		root.content_scale_size = SIZE
		OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	Settings.set_storage_path("user://fel13-settings.json")
	var options: Dictionary = Settings.default_settings()
	options["ui_scale"] = 1.0
	if mode == "play": options["display_mode"] = Settings.DISPLAY_WINDOWED
	if not Settings.save_settings(options):
		fail("could not create isolated settings")
		return
	if OS.get_environment("FEL13_SHADER_DEBUG") == "grid":
		await load(tool_dir.path_join("native_grid.gd")).new().run(self)
		return
	match mode:
		"finish":
			await load(tool_dir.path_join("finish.gd")).new().run(self)
		"focused":
			await load(tool_dir.path_join("focused.gd")).new().run(self)
		"stage":
			await load(tool_dir.path_join("stage.gd")).new().run(self)
		"play", "check":
			await play(mode)
		_:
			var driver: Variant = load(tool_dir.path_join("witness.gd")).new()
			await driver.run(self, mode)

func fixtures() -> PackedStringArray:
	var result: PackedStringArray = DirAccess.get_directories_at(fixture_root)
	result.sort()
	return result

func open_fixture(id: String, interactive: bool = false) -> bool:
	var source: String = fixture_root.path_join(id)
	if not FileAccess.file_exists(source.path_join("run.save")): return fixture_failure(id + " missing save")
	var working: String = ProjectSettings.globalize_path("user://fel13").path_join(id)
	if DirAccess.make_dir_recursive_absolute(working) != OK: return fixture_failure(id + " could not create working profile")
	for file: String in ["run.save", "progression.json"]:
		if DirAccess.copy_absolute(source.path_join(file), working.path_join(file)) != OK:
			return fixture_failure(id + " could not stage " + source.path_join(file))
	run_path = working.path_join("run.save")
	Store.set_run_storage_path(run_path)
	Store.set_storage_path(working.path_join("progression.json"))
	viewport = root
	if not interactive:
		var view := SubViewport.new()
		view.size = SIZE
		view.msaa_2d = Viewport.MSAA_4X
		view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		view.gui_embed_subwindows = true
		root.add_child(view)
		view.notify_mouse_entered()
		viewport = view
	# Let the native window and offscreen target submit their initial layout
	# before Continue installs the HUD. No root-window resize for offscreen runs.
	if not dry: await RenderingServer.frame_post_draw
	root.set_meta("labyrinth_resume_saved_run", true)
	scene = RunScene.instantiate()
	viewport.add_child(scene)
	if interactive: current_scene = scene
	if not interactive: await point(NO_POINTER)
	var deadline: int = Time.get_ticks_msec() + INPUT_TIMEOUT_MSEC
	while not at_first_input():
		if Time.get_ticks_msec() > deadline:
			await close_fixture()
			return fixture_failure(id + " did not reach combat input")
		await process_frame
	board = scene.get("board_view")
	if not await require_board_layout(id):
		await close_fixture()
		return false
	return true

func require_board_layout(id: String) -> bool:
	var deadline: int = Time.get_ticks_msec() + BOARD_LAYOUT_TIMEOUT_MSEC
	var width: float = board._tile_width()
	var previous: float = -1.0
	var stable: int = 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		width = board._tile_width()
		# Continue installs input before the deferred hand fit publishes the
		# encounter HUD budget. Only sample geometry after that work settles.
		var ready: bool = scene.call("initial_presentation_is_ready")
		var centering: Tween = scene.get("_board_centering_tween")
		if ready and width >= MIN_TILE_WIDTH and (centering == null or not centering.is_running()):
			stable = stable + 1 if is_equal_approx(width, previous) else 1
		else:
			stable = 0
		previous = width
		if stable == STABLE_LAYOUT_FRAMES and Time.get_ticks_msec() <= deadline:
			print("FEL13 LAYOUT ", id, " tile_width=", width, " board=", board.size, " stable_frames=", stable)
			return true
	return fixture_failure("%s board not laid out tile_width=%s" % [id, str(width)])

func at_first_input() -> bool:
	if not scene.call("has_installed_run") or bool(scene.get("_animation_lock")): return false
	var state: Dictionary = scene.get("_combat_state")
	return not state.is_empty() and scene.get("_combat_engine").is_player_turn(state)

func close_fixture() -> void:
	Store.flush_pending_run_saves()
	(viewport if viewport != root else scene).queue_free()
	await process_frame
	scene = null
	board = null
	viewport = null

func point(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - viewport.get_mouse_position()
	viewport.push_input(event, true)
	await process_frame

func tile_point(tile: Vector2i) -> Vector2:
	return board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)

func settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame

func play(mode: String) -> void:
	var ids: PackedStringArray = fixtures()
	var requested: String = OS.get_environment("FEL13_FIXTURE")
	if not requested.is_empty(): ids = PackedStringArray([requested])
	if mode == "play" and (dry or ids.size() != 1):
		fail("play requires one fixture and a windowed launcher")
		return
	if mode == "play": root.mode = Window.MODE_WINDOWED
	var failed: int = 0
	for id: String in ids:
		if not await open_fixture(id, mode == "play"):
			failed += 1
			continue
		print("FEL13 FIRST INPUT ", id)
		if mode == "play": return
		await close_fixture()
	if failed == 0:
		print("FEL13 CONTINUE PASS fixtures=", ids.size())
	else:
		print("FEL13 CONTINUE FAIL fixtures=%d failures=%d" % [ids.size(), failed])
	quit(0 if failed == 0 else 1)

func fixture_failure(message: String) -> bool:
	printerr("FEL13 FAIL ", message)
	return false

func fail(message: String) -> bool:
	quit(1)
	return fixture_failure(message)
