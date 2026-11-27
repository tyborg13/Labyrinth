extends SceneTree
## Stage fel-01 saves, then observe the production board under tile-centre hover.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Census = preload("res://tools/fel06/board_census.gd")
const Evidence = preload("res://tools/fel06/hover_evidence.gd")
const RUN_SCENE = "res://scenes/run_scene.tscn"
const FIXTURES = "res://tools/fel01/fixtures"
const FIXTURE_COUNT := 12
const ENTRY_FRAMES := 90
const ENTRY_SECONDS := 2.0
const SETTLE_SECONDS := 0.35
const NO_POINTER := Vector2(-16, -16)
const WINDOW_GUTTER := 24.0
const REST_SEARCH_DIVISIONS := 12

var _viewport: SubViewport
var _window_frame: TextureRect
var _dry: bool
var _destination: String
var _inside: bool


func _initialize() -> void:
	Runtime.apply_from_environment()
	_dry = OS.get_environment("FEL06_DRY_RUN") == "1"
	_destination = OS.get_environment("FEL06_CAPTURE_DIR")
	if _dry:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")


func _run() -> void:
	if _dry != (DisplayServer.get_name() == "headless"):
		_fail("use native.sh, or native.sh --dry-run for headless")
		return
	if _destination.is_empty() or not DirAccess.dir_exists_absolute(_destination):
		_fail("use native.sh to allocate a capture directory")
		return
	var ids: PackedStringArray = DirAccess.get_directories_at(FIXTURES)
	ids.sort()
	if ids.size() != FIXTURE_COUNT:
		_fail("expected %d fixtures, found %d" % [FIXTURE_COUNT, ids.size()])
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel06_capture_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated capture settings")
		return
	var fixtures: Array[Dictionary]
	var count: int = 0
	for id: String in ids:
		var fixture: Dictionary = await _fixture(id)
		if fixture.is_empty(): return
		count += (fixture["samples"] as Array).size()
		fixtures.append(fixture)
	var path: String = _destination.path_join("observations.json")
	var dump := FileAccess.open(path, FileAccess.WRITE)
	if dump == null or not dump.store_string(JSON.stringify({"mode": "headless" if _dry else "native", "fixtures": fixtures}, "\t") + "\n"):
		_fail("cannot write " + path)
		return
	dump.close()
	print("FEL06 %s PASS fixtures=%d samples=%d" % ["DRY RUN" if _dry else "NATIVE", fixtures.size(), count])
	print(path)
	quit()


func _fixture(id: String) -> Dictionary:
	var source: String = FIXTURES.path_join(id)
	var working: String = ProjectSettings.globalize_path("user://fel06_work").path_join(id)
	if not Checkpoint.stage(source, working): return _fail(id + " staging")
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_inside = false
	if not _dry: _show_native_preview()
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = _instantiate_run_scene()
	_viewport.add_child(scene)
	await _point(NO_POINTER)
	await _settle()
	if not _dry:
		# Same wait as fel-01 for the room entrance and cold shader compiles.
		for frame: int in range(ENTRY_FRAMES): await process_frame
		await create_timer(ENTRY_SECONDS).timeout
	if not scene.call("has_installed_run"): return _fail(id + " Continue did not install a run")
	var differences: Dictionary = Checkpoint.compare(scene, source)
	if not differences.is_empty():
		print(JSON.stringify(differences))
		return _fail(id + " Continue changed the saved witness")
	var board: Control = scene.get("board_view")
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_running():
		await process_frame
		centering = scene.get("_board_centering_tween")
	var picks: Array[Dictionary] = Census.pick(scene, board, _viewport.get_visible_rect())
	var samples: Array[Dictionary]
	for pick: Dictionary in picks:
		var label: String = "%s %s %s" % [id, pick["category"], pick["tile"]]
		print("FEL06 PICK " + label + " " + JSON.stringify(_contents_for_log(pick)))
		var sample: Dictionary = await _hover(scene, board, id, pick)
		if sample.is_empty(): return {}
		samples.append(sample)
	_viewport.queue_free()
	if is_instance_valid(_window_frame): _window_frame.queue_free()
	await process_frame
	print("FEL06 RESUME PASS %s samples=%d" % [id, samples.size()])
	return {"id": id, "samples": samples}


func _instantiate_run_scene() -> Node:
	var packed: PackedScene = load(RUN_SCENE)
	return packed.instantiate()


func _hover(scene: Node, board: Control, id: String, pick: Dictionary) -> Dictionary:
	if not _at_rest(scene) and not await _reset_hover(scene, board):
		return _fail(id + " pointer reset did not restore combat rest")
	await _settle()
	var rest: Dictionary = Evidence.read(scene, board, _viewport)
	var tile: Vector2i = pick["tile"]
	var target: Vector2 = Census.center(board, tile)
	await _point(target)
	await _settle(true)
	if not _dry: await RenderingServer.frame_post_draw
	var hovered: Vector2i = scene.get("_hovered_board_tile")
	var hovered_control: Control = _viewport.gui_get_hovered_control()
	if hovered != tile or not _viewport.get_mouse_position().is_equal_approx(target):
		return _fail("%s wanted %s, hover resolved %s over %s at %s" % [
			id, tile, hovered, hovered_control, _viewport.get_mouse_position()])
	if scene.get("_selected_card_index") != -1 or scene.get("_animation_lock") or scene.get("_player_movement_selected"):
		return _fail(id + " hover changed the input or combat phase")
	var reveal: Node = board.get("_occlusion_reveal")
	for fade: Dictionary in (reveal.get("targets") as Dictionary).values():
		if bool(fade["on"]) and not is_equal_approx(float(fade["progress"]), 1.0):
			return _fail("%s %s occluder fade did not settle" % [id, tile])
	var hover: Dictionary = Evidence.read(scene, board, _viewport, tile)
	if not Checkpoint.compare(scene, FIXTURES.path_join(id)).is_empty():
		return _fail(id + " hover changed the saved combat witness")
	var frame: String = ""
	if not _dry:
		frame = "%s-%s-hover.png" % [id, pick["category"]]
		var path: String = _destination.path_join(frame)
		var image: Image = _viewport.get_texture().get_image()
		if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE or image.save_png(path) != OK:
			return _fail("cannot save 1920x1080 frame " + path)
		print(path)
	return {"contents": pick, "rest": rest, "hover": hover, "frame": frame,
		"hovered_control": str(hovered_control.get_path()) if hovered_control != null else ""}


func _reset_hover(scene: Node, board: Control) -> bool:
	# A stage mouse exit retires the reveal but can leave passive board hover.
	# Move over the board's own empty canvas to deliver an invalid floor tile.
	var bounds: Rect2 = _viewport.get_visible_rect()
	var rect: Rect2 = (board.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, board.size)).intersection(bounds)
	for y: int in range(1, REST_SEARCH_DIVISIONS):
		for x: int in range(1, REST_SEARCH_DIVISIONS):
			var point: Vector2 = rect.position + rect.size * Vector2(x, y) / float(REST_SEARCH_DIVISIONS)
			if (board.call("tile_at_global_position", point) as Vector2i).x >= 0: continue
			await _point(point)
			if _at_rest(scene) and _viewport.gui_get_hovered_control() == board:
				await _point(NO_POINTER)
				return true
	return false


func _at_rest(scene: Node) -> bool:
	return not scene.get("_animation_lock") and scene.get("_selected_card_index") == -1 and (scene.get("_hovered_board_tile") as Vector2i).x < 0


func _show_native_preview() -> void:
	# Show the capture viewport in a preview window.
	# The window fit never changes the 1920x1080 game viewport or UI scale.
	_window_frame = TextureRect.new()
	_window_frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_window_frame.texture = _viewport.get_texture()
	_window_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var room: Vector2 = root.get_visible_rect().size
	var dimensions := Vector2(Checkpoint.VIEWPORT_SIZE)
	var fit: float = minf((room.x - 2.0 * WINDOW_GUTTER) / dimensions.x, (room.y - 2.0 * WINDOW_GUTTER) / dimensions.y)
	_window_frame.size = dimensions * fit
	_window_frame.position = (room - _window_frame.size) * 0.5
	root.add_child(_window_frame)


func _point(position: Vector2) -> void:
	var entered: bool = position != NO_POINTER
	if entered != _inside:
		_inside = entered
		if _inside: _viewport.notify_mouse_entered()
		else: _viewport.notify_mouse_exited()
	# Exercise normal GUI motion and embedded popups inside the capture viewport.
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - _viewport.get_mouse_position()
	_viewport.push_input(event, true)
	await process_frame


func _settle(tooltip: bool = false) -> void:
	var delay: float = SETTLE_SECONDS
	if tooltip:
		delay = maxf(delay, float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec", 0.5)))
	await create_timer(delay).timeout
	await process_frame
	await process_frame


func _contents_for_log(pick: Dictionary) -> Dictionary:
	var summary: Dictionary = pick.duplicate()
	for key: String in ["units", "objects", "surfaces", "marks"]:
		var entries: Array[Dictionary]
		for entry: Dictionary in pick[key]:
			var short: Dictionary = entry.duplicate()
			short.erase("raw")
			entries.append(short)
		summary[key] = entries
	return summary


func _fail(message: String) -> Dictionary:
	printerr("FEL06 FAIL " + message)
	quit(1)
	return {}
