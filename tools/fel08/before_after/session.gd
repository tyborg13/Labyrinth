extends SceneTree
## The absolute script and fixture paths work against either project's res://.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunScene = preload("res://scenes/run_scene.tscn")
const ObservationScript := "observations.gd"
const FRAME_SIZE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const MIN_TILE_WIDTH := 40.0
const STABLE_LAYOUT_FRAMES := 10
const BOARD_LAYOUT_TIMEOUT_MSEC := 5000
const SETTLE_FRAMES := 2
const NO_POINTER := Vector2(-16, -16)
const WINDOW_GUTTER := 24.0
const FIXTURE_FILES := ["run.save", "progression.json"]

var _dry: bool
var _side: String
var _destination: String
var _observations: GDScript
var _viewport: SubViewport
var _preview: TextureRect
var _inside: bool


func _initialize() -> void:
	Runtime.apply_from_environment()
	_dry = OS.get_environment("FEL08_BA_MODE") == "dry"
	if _dry: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_run.call_deferred()


func _run() -> void:
	var output := OS.get_environment("FEL08_BA_OUTPUT")
	_side = OS.get_environment("FEL08_BA_SIDE")
	_destination = output.path_join(_side)
	if _side not in ["release", "branch"] or _dry != (DisplayServer.get_name() == "headless") or not DirAccess.dir_exists_absolute(_destination):
		printerr("FEL08 BA use run.sh [--dry-run]")
		quit(1)
		return
	_observations = load(OS.get_environment("FEL08_BA_TOOL").path_join(ObservationScript))
	var cases: Variant = JSON.parse_string(FileAccess.get_file_as_string(output.path_join("cases.json")))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	Settings.set_storage_path("user://fel08_ba_settings.json")
	if not cases is Array or cases.is_empty() or _observations == null or not Settings.save_settings(settings):
		printerr("FEL08 BA missing capture configuration or isolated settings")
		quit(1)
		return

	var samples: Array[Dictionary]
	for case: Dictionary in cases:
		var sample: Dictionary = await _capture_case(case)
		if not sample.is_empty(): samples.append(sample)
		await _close_case()
	var file := FileAccess.open(_destination.path_join("observations.json"), FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(samples, "\t") + "\n"):
		printerr("FEL08 BA cannot write observations for ", _side)
		quit(1)
		return
	file.close()
	var passed: bool = samples.size() == cases.size()
	var mode := "DRY" if _dry else "NATIVE"
	if passed:
		print("FEL08 BA %s PASS cases=%d" % [mode, samples.size()])
	else:
		printerr("FEL08 BA %s FAIL %s captured=%d cases=%d" % [mode, _side, samples.size(), cases.size()])
	quit(0 if passed else 1)


func _capture_case(case: Dictionary) -> Dictionary:
	var name: String = case["name"]
	var folder := _stage(case["source"], name)
	if folder.is_empty(): return _fail_case(name, "cannot stage fixture")
	var resume: bool = case["mount"] == "resume"
	var state: Dictionary = {} if resume else Store._load_run_dictionary(folder.path_join("run.save"))
	if not resume and state.is_empty(): return _fail_case(name, "cannot load fixture")
	_viewport = SubViewport.new()
	_viewport.size = FRAME_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	if not _dry: _show_preview()
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	var scene := RunScene.instantiate()
	_viewport.add_child(scene)
	await _point(NO_POINTER)
	if not resume: scene.call("_load_run_state", state)
	if scene.get("_dialogue_active"): scene.call("_close_dialogue")
	var board: Control = scene.get("board_view")
	var target: String = case["target"]
	if board == null or not await _require_board_layout(scene, board, target == "plate"):
		return _fail_case(name, "board not laid out")
	print("FEL08 BA LAYOUT %s %s tile_width=%.2f stable_frames=%d" % [
		name, _side, board._tile_width(), STABLE_LAYOUT_FRAMES])

	var heading: Control
	var anchor: Rect2
	var marks: Array[Array]
	match target:
		"hud":
			var hud: Control = scene.get("_combat_objective_hud")
			if hud == null or not hud.is_visible_in_tree(): return _fail_case(name, "objective panel missing")
			anchor = hud.get_global_rect()
			var inset := hud.get_theme_stylebox("panel").get_margin(SIDE_LEFT) * 0.5
			await _point(Vector2(anchor.position.x + inset, anchor.get_center().y))
		"plate":
			var panel: Control = scene.get("_pre_battle_panel")
			if panel != null: heading = panel.find_child("PreBattleObjectiveTitle", true, false) as Control
			if heading == null or not heading.is_visible_in_tree(): return _fail_case(name, "objective plate missing")
			var plate := panel.find_child("PreBattleObjectiveChip", true, false) as Control
			anchor = plate.get_global_rect() if plate != null else heading.get_global_rect()
			heading.grab_focus()
		"tile", "marks":
			var pick: Array = case["tile"]
			var tile := Vector2i(int(pick[0]), int(pick[1]))
			anchor = _observations.tile_rect(board, tile)
			if target == "tile":
				var center: Vector2 = board.call("_tile_center", tile)
				await _point(board.get_global_transform_with_canvas() * center)
		_:
			return _fail_case(name, "unknown target")
	await _settle(case["settle"])
	if not _dry: await RenderingServer.frame_post_draw

	if target == "marks": marks = _observations.medallions(board)
	var popups: Array[Dictionary] = _observations.popups(_viewport, heading)
	var filename := name + ".png"
	if not _dry:
		var image := _viewport.get_texture().get_image()
		var path := _destination.path_join(filename)
		if image == null or image.get_size() != FRAME_SIZE or image.save_png(path) != OK:
			return _fail_case(name, "cannot write frame")
		print(path)

	var text: Array[Array]
	for popup: Dictionary in popups: text.append(popup["panels"])
	print("FEL08 BA POPUP %s %s %s" % [name, _side, JSON.stringify(text)])
	if target == "marks":
		print("FEL08 BA MARKS %s %s count=%d" % [name, _side, marks.size()])
	return {"case": name, "frame": filename, "anchor": _observations.edges(anchor), "medallions": marks, "popups": popups}


func _stage(source: String, name: String) -> String:
	var folder := ProjectSettings.globalize_path("user://fel08_ba").path_join(name)
	if DirAccess.make_dir_recursive_absolute(folder) != OK: return ""
	for filename: String in FIXTURE_FILES:
		if DirAccess.copy_absolute(source.path_join(filename), folder.path_join(filename)) != OK: return ""
	Store.set_run_storage_path(folder.path_join("run.save"))
	Store.set_storage_path(folder.path_join("progression.json"))
	return folder


func _require_board_layout(scene: Node, board: Control, pre_battle: bool) -> bool:
	var deadline := Time.get_ticks_msec() + BOARD_LAYOUT_TIMEOUT_MSEC
	var previous := -1.0
	var stable := 0
	var remeasured := false
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var width: float = board._tile_width()
		var ready: bool = scene.call("initial_presentation_is_ready")
		if ready and width < MIN_TILE_WIDTH and not remeasured:
			remeasured = _remeasure_board(scene, board, pre_battle)
		var centering: Tween = scene.get("_board_centering_tween")
		if ready and width >= MIN_TILE_WIDTH and (centering == null or not centering.is_running()):
			stable = stable + 1 if is_equal_approx(width, previous) else 1
		else:
			stable = 0
		previous = width
		if stable == STABLE_LAYOUT_FRAMES: return Time.get_ticks_msec() <= deadline
	print("FEL08 BA layout timeout details width=%.2f ready=%s board=%s fit=%s mode=%s" % [
		board._tile_width(), scene.call("initial_presentation_is_ready"), board.size,
		board.presentation.get("board_fit_rect"), scene.get("_run_state").get("mode")])
	return false


func _remeasure_board(scene: Node, board: Control, pre_battle: bool) -> bool:
	if pre_battle:
		# The modal never allocates a combat hand, so the normal HUD fit is one pixel high.
		# Fit the backdrop inside the proof viewport without changing the modal itself.
		var fit: Rect2 = scene.call("_legacy_board_fit_rect")
		var exclusions: Array[Rect2]
		board.set_room_framing(fit, exclusions, fit)
		scene.call_deferred("_sync_board_view_rect")
		return true
	var hand: Control = scene.get("hand_row")
	if not hand.is_visible_in_tree() or hand.get_global_rect().position.y <= 0.0: return false
	# Match the fel-13 Continue witness when the startup fit predates the HUD layout.
	var budget: RefCounted = scene.call("_active_board_hud_budget")
	budget.key.clear()
	scene.call_deferred("_freeze_board_hud_budget")
	return true


func _point(position: Vector2) -> void:
	var entered := position != NO_POINTER
	if entered != _inside:
		_inside = entered
		if _inside: _viewport.notify_mouse_entered()
		else: _viewport.notify_mouse_exited()
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - _viewport.get_mouse_position()
	_viewport.push_input(event, true)
	await process_frame


func _settle(seconds: float) -> void:
	await create_timer(seconds).timeout
	for frame: int in range(SETTLE_FRAMES): await process_frame


func _show_preview() -> void:
	_preview = TextureRect.new()
	_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_preview.texture = _viewport.get_texture()
	_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var available := root.get_visible_rect().size
	var dimensions := Vector2(FRAME_SIZE)
	var fit := minf((available.x - 2.0 * WINDOW_GUTTER) / dimensions.x,
		(available.y - 2.0 * WINDOW_GUTTER) / dimensions.y)
	_preview.size = dimensions * fit
	_preview.position = (available - _preview.size) * 0.5
	root.add_child(_preview)


func _close_case() -> void:
	Store.flush_pending_run_saves()
	if is_instance_valid(_preview): _preview.queue_free()
	if is_instance_valid(_viewport): _viewport.queue_free()
	_inside = false
	await process_frame


func _fail_case(name: String, reason: String) -> Dictionary:
	printerr("FEL08 BA FAIL %s %s %s" % [name, _side, reason])
	return {}
