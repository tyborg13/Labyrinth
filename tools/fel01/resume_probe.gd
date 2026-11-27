extends SceneTree
## Resume through the normal RunScene boot branch and optionally capture its input states.

const Runtime = preload("res://scripts/parallel_runtime.gd")
const Checkpoint = preload("res://tools/fel01/checkpoint.gd")
const Settings = preload("res://scripts/settings_store.gd")
const RUN_SCENE = "res://scenes/run_scene.tscn"
const SETTLE_SECONDS := 0.35
const NO_POINTER := Vector2(-1, -1)
const PHASES := ["rest", "hover", "targeting"]
const FULL_FIXTURE_COUNT := 12
const PROVISIONAL_FIXTURE_COUNT := 3

var _viewport: SubViewport
var _dry: bool
var _witness_only: bool
var _destination: String


func _initialize() -> void:
	Runtime.apply_from_environment()
	_dry = OS.get_environment("FEL01_DRY_RUN") == "1"
	_witness_only = _dry and OS.get_environment("FEL01_WITNESS_ONLY") == "1"
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")


func _run() -> void:
	if _dry != (DisplayServer.get_name() == "headless"):
		_fail("use a headless runner for dry-run or a native renderer for PNG capture")
		return
	var single: String = OS.get_environment("FEL01_FIXTURE")
	var fixtures: Array[String]
	if not single.is_empty() and _dry: fixtures.append(single)
	else:
		var root_path: String = OS.get_environment("FEL01_FIXTURES")
		for key: String in DirAccess.get_directories_at(root_path):
			fixtures.append(root_path.path_join(key))
		fixtures.sort()
		var expected: int = PROVISIONAL_FIXTURE_COUNT if OS.get_environment("FEL01_SAMPLES") == "1" else FULL_FIXTURE_COUNT
		if fixtures.size() != expected:
			_fail("expected %d fixtures in %s" % [expected, root_path])
			return
	_destination = OS.get_environment("FEL01_CAPTURE_DIR")
	if not _dry and (_destination.is_empty() or DirAccess.make_dir_recursive_absolute(_destination) != OK):
		_fail("cannot create fresh capture directory")
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.set_storage_path("user://fel01_capture_settings.json")
	if not Settings.save_settings(settings):
		_fail("cannot save isolated capture settings")
		return
	for source: String in fixtures:
		if not await _fixture(source):
			quit(1)
			return
	var proof: String = "CAPTURE"
	if _dry: proof = "WITNESS" if _witness_only else "DRY RUN"
	print("FEL01 %s PASS states=%d" % [proof, fixtures.size()])
	quit()


func _fixture(source: String) -> bool:
	var id: String = source.get_file()
	var working: String = ProjectSettings.globalize_path("user://fel01_work").path_join(id)
	if not Checkpoint.stage(source, working): return _fail("cannot stage " + source)
	var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("score.json")))
	_viewport = SubViewport.new()
	_viewport.size = Checkpoint.VIEWPORT_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()
	root.set_meta("labyrinth_resume_saved_run", true)
	var packed: PackedScene = load(RUN_SCENE)
	var scene: Node = packed.instantiate()
	_viewport.add_child(scene)
	await _point(NO_POINTER)
	await _settle()
	if not _dry:
		# Native: let the room entrance and first shader compiles finish (atk07 capture pattern).
		for frame: int in range(90): await process_frame
		await create_timer(2.0).timeout
	if not scene.call("has_installed_run"): return _fail(id + " production Continue did not install a run")
	var differences: Dictionary = Checkpoint.compare(scene, source)
	if not differences.is_empty():
		print("FEL01 RESUME DIFFERENCES ", JSON.stringify(differences))
		return _fail(id + " production Continue changed " + ", ".join(differences.keys()))
	print("FEL01 RESUME PASS %s boundary units positions surfaces intents hand" % id)
	if not _witness_only:
		if not row is Dictionary or (row.get("focus", {}) as Dictionary).is_empty():
			return _fail(id + " has no scored covered tile")
		var point: Array = row["focus"]["tile"]
		if not await _capture_phases(scene, id, Vector2i(int(point[0]), int(point[1]))): return false
	_viewport.queue_free()
	await process_frame
	return true


func _capture_phases(scene: Node, id: String, tile: Vector2i) -> bool:
	var board: Control = scene.get("board_view")
	var reveal: Node = board.get("_occlusion_reveal")
	var centering: Tween = scene.get("_board_centering_tween")
	while centering != null and centering.is_running():
		await process_frame
		centering = scene.get("_board_centering_tween")
	if (scene.get("_animation_lock") or scene.get("_selected_card_index") != -1
		or (scene.get("_hovered_board_tile") as Vector2i).x >= 0 or reveal.focus_tile.x >= 0):
		return _fail(id + " resume is not at rest")
	var images: Array[Image]
	if not await _record_image(images, id, "rest"): return false
	await _point(_tile_center(board, tile))
	await _settle()
	if scene.get("_hovered_board_tile") != tile or not _fade_is_settled(reveal, tile):
		return _fail("%s hover at %s did not reveal its occluders (hover %s, focus %s, targets %s, point %s, hovered control %s, last board pointer %s, dialogue %s, guide %s, scene point tile %s)" %
			[id, tile, scene.get("_hovered_board_tile"), reveal.focus_tile, str(reveal.targets),
				_tile_center(board, tile), _viewport.gui_get_hovered_control(), board.get("_last_pointer_position"),
				scene.get("_dialogue_active"), scene.get("_guided_tutorial_phase_id"),
				board.call("tile_at_global_position", _tile_center(board, tile))])
	if not await _record_image(images, id, "hover"): return false
	var index: int = Checkpoint.first_targeted_card(scene)
	if index < 0: return _fail(id + " has no playable targeted card")
	await scene.call("_on_card_pressed", index)
	await _point(_tile_center(board, tile))
	await _settle()
	if (
		scene.get("_selected_card_index") != index or not scene.call("_targeted_card_aiming_active")
		or scene.get("_hovered_board_tile") != tile
	):
		return _fail("%s card %d did not target over %s (hover %s)" %
			[id, index, tile, scene.get("_hovered_board_tile")])
	if not await _record_image(images, id, "targeting"): return false
	var combat: Dictionary = scene.get("_combat_state")
	var legal: bool = (scene.get("_pending_target_tiles") as Array).has(tile)
	print("FEL01 PHASES PASS %s rest hover=%s fade=%d card=%s hover_is_legal_target=%s" %
		[id, tile, reveal.targets.size(), combat["deck"]["hand"][index], legal])
	return _dry or _make_contact_sheet(images, id)


func _tile_center(board: Control, tile: Vector2i) -> Vector2:
	return board.get_global_transform_with_canvas() * (board.call("_tile_center", tile) as Vector2)


func _fade_is_settled(reveal: Node, tile: Vector2i) -> bool:
	if reveal.focus_tile != tile or reveal.targets.is_empty(): return false
	for entry: Dictionary in reveal.targets.values():
		if not entry["on"] or not is_equal_approx(entry["progress"], 1.0): return false
	return true


func _point(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = position - _viewport.get_mouse_position()
	_viewport.push_input(event, true)
	await process_frame


func _settle() -> void:
	await create_timer(SETTLE_SECONDS).timeout
	await process_frame
	await process_frame


func _record_image(images: Array[Image], id: String, phase: String) -> bool:
	if _dry: return true
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.get_size() != Checkpoint.VIEWPORT_SIZE:
		return _fail(id + " " + phase + " image size differs from 1920x1080")
	image.convert(Image.FORMAT_RGBA8)
	images.append(image)
	return _write_image(image, "%s-%s.png" % [id, phase])


func _make_contact_sheet(images: Array[Image], id: String) -> bool:
	var size: Vector2i = Checkpoint.VIEWPORT_SIZE
	var sheet: Image = Image.create_empty(size.x * PHASES.size(), size.y, false, Image.FORMAT_RGBA8)
	for index: int in range(PHASES.size()):
		sheet.blit_rect(images[index], Rect2i(Vector2i.ZERO, size), Vector2i(index * size.x, 0))
	return _write_image(sheet, "%s-contact.png" % id)


func _write_image(image: Image, name: String) -> bool:
	var path: String = _destination.path_join(name)
	if image.save_png(path) != OK: return _fail("cannot write " + path)
	print(path)
	return true


func _fail(message: String) -> bool:
	printerr("FEL01 RESUME/CAPTURE FAIL " + message)
	quit(1)
	return false
