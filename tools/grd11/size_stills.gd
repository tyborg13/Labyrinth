extends SceneTree
## Real combat stills at the requested physical tile widths.

const Fixture = preload("res://tools/grd11/fight_fixture.gd")
const Gallery = preload("res://tools/grd01/fixtures.gd")
const Proof = preload("res://tools/grd11/size_proof.gd")
const Sheet = preload("res://scripts/board_ground_fx_sheet.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const SETTLE_FRAMES: int = 12
const SAMPLE_SECONDS: float = 0.5
const COLOR_TEST_SIZE := Vector2i(512, 256)
const COLOR_TEST_CENTER := Vector2(256.3, 155.7)
const COLOR_TEST_ROW_PAIR := Vector2i(1, 8)

var _dry: bool
var _output: String
var _view: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dry = args.has("--dry-run")
	assert(_dry == (DisplayServer.get_name() == "headless"))
	assert(Cel.mode == "all" and not Cel._files.is_empty())
	var size: Vector2i = Proof.DECK_SIZE if args.has("--deck") else Gallery.SIZE
	var targets: PackedInt32Array = PackedInt32Array([Proof.DECK_WIDTH]) if args.has("--deck") else Proof.TARGET_WIDTHS
	for arg: String in args:
		if not arg.begins_with("--"):
			_output = arg
	assert(_output.is_absolute_path() and not FileAccess.file_exists(_output.path_join("stills.json")))
	assert(DirAccess.make_dir_recursive_absolute(_output) == OK)
	OS.set_environment("LABYRINTH_GROUND_FX", "pixel")
	Store.set_storage_path("user://grd11_stills_progression.json")
	Store.set_run_storage_path("user://grd11_stills_run.save")
	Settings.set_storage_path("user://grd11_stills_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	assert(Settings.save_settings(settings))
	_view = Gallery.make_view(size, Proof.logical_size(size), Viewport.MSAA_4X)
	root.add_child(_view)
	if not _dry:
		var preview := Sprite2D.new()
		preview.centered = false
		preview.texture = _view.get_texture()
		root.add_child(preview)
	var samples: Array[Dictionary]
	for target: int in targets:
		samples.append(await _capture_room(target))
	if not _dry:
		await _check_palette_pixels()
	var manifest := FileAccess.open(_output.path_join("stills.json"), FileAccess.WRITE)
	assert(manifest != null)
	manifest.store_string(JSON.stringify({"size": [size.x, size.y], "dry_run": _dry, "samples": samples}, "\t") + "\n")
	manifest.close()
	print(_output)
	print("GRD-11 SIZE STILLS %s: PASS (%dx%d, %d rooms, %d stills planned)" %
		["DRY RUN" if _dry else "NATIVE", size.x, size.y, targets.size(), targets.size() * 2])
	quit()

func _capture_room(target: int) -> Dictionary:
	var scene: Control = Fixture.Run.instantiate()
	_view.add_child(scene)
	await process_frame
	Fixture.configure(scene, false)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	var board: Control = scene.get("board_view")
	board.call("reset_navigation")
	Proof.fit(board, target)
	var ground: Node = board.get_node("PixelGround")
	assert(scene.get("_movement_meter").is_visible_in_tree() and scene.get("hand_box").is_visible_in_tree())
	assert(preload("res://scripts/ui_typography.gd").ui_scale(scene) == 1.0)
	var state: Dictionary = board.get("combat_state")
	assert(Fixture.Ground.has_surface(state, Fixture.HERO, "fire") and Fixture.Ground.has_surface(state, Fixture.HARRIER, "electrified"))
	assert(Fixture.Ground.has_surface(state, Fixture.FIRE_REGION.position, "fire"))
	assert(not ground.depth.occupied_tiles.has(Fixture.FIRE_REGION.position))
	assert(ground.depth.occupied_tiles.has(Fixture.HERO) and ground.depth.occupied_tiles.has(Fixture.HARRIER))
	await _save(ground, "%03d-fire-electrified.png" % target)
	Fixture.enable_stormcoal(scene)
	Proof.fit(board, target)
	assert(Fixture.Ground.is_conductive(board.combat_state, Fixture.CRAGHIDE))
	_check_onscreen(board, [Fixture.HERO, Fixture.HARRIER, Fixture.CRAGHIDE, Fixture.FIRE_REGION.position])
	await _save(ground, "%03d-stormcoal.png" % target)
	var tile_px: float = Proof.physical_tile_width(board)
	var tile_cells: float = Sheet._data["sizes"][ground.sheet.sheet_index]["tile_cells"][0]
	var ratio: float = tile_cells * ground.sheet.cell_px / tile_px
	assert(ratio >= Proof.MIN_RATIO and ratio <= Proof.MAX_RATIO)
	var record: Dictionary = {"tile_px": tile_px, "cell_px": ground.sheet.cell_px,
		"sheet": Sheet._data["sizes"][ground.sheet.sheet_index]["atlas"], "ratio": ratio}
	scene.queue_free()
	for frame: int in 2:
		await process_frame
	return record

func _check_onscreen(board: Control, tiles: Array) -> void:
	var stretch: Transform2D = _view.get_stretch_transform()
	var canvas: Transform2D = stretch * board.get_global_transform_with_canvas()
	var frame := Rect2(Vector2.ZERO, Vector2(_view.size))
	for tile: Vector2i in tiles:
		var center: Vector2 = board.call("world_position_for_tile", tile)
		assert(frame.has_point(canvas * center), "A proof tile is outside the viewport: " + str(tile))

func _save(ground: Node, filename: String) -> void:
	ground.set_process(false)
	ground.set_motion_time(SAMPLE_SECONDS)
	if _dry:
		await process_frame
	else:
		await RenderingServer.frame_post_draw
		var image: Image = _view.get_texture().get_image()
		assert(image.get_size() == _view.size)
		assert(image.save_png(_output.path_join(filename)) == OK)

func _check_palette_pixels() -> void:
	var view: SubViewport = Gallery.make_view(COLOR_TEST_SIZE, COLOR_TEST_SIZE, Viewport.MSAA_DISABLED)
	view.transparent_bg = true
	root.add_child(view)
	var sheet := Sheet.new()
	sheet.setup()
	sheet.set_time(0.0, false)
	var stamp := Sheet.Stamp.new()
	stamp.material = sheet.ink
	view.add_child(stamp)
	stamp.present(COLOR_TEST_CENTER, COLOR_TEST_ROW_PAIR, 0, 0, 1, 0)
	var checked: int = 0
	for width: int in Proof.TARGET_WIDTHS:
		sheet.sync_size(width, Vector2.ONE, Gallery.SIZE.y)
		stamp.set_cull_bounds(sheet._cull_bounds)
		await RenderingServer.frame_post_draw
		var image: Image = view.get_texture().get_image()
		var atlas: Image = Sheet._textures[sheet.sheet_index].get_image()
		var rect: Rect2 = sheet.framebuffer_rect(COLOR_TEST_CENTER)
		var pixels: PackedByteArray = atlas.get_data()
		var frame := Vector2i(sheet.bounds.size)
		for y: int in frame.y:
			for x: int in frame.x:
				var index: int = pixels[(COLOR_TEST_ROW_PAIR.y * frame.y + y) * atlas.get_width() + x]
				if index == 0:
					index = pixels[(COLOR_TEST_ROW_PAIR.x * frame.y + y) * atlas.get_width() + x]
				var sample := Vector2i(rect.position) + Vector2i(x, y) * sheet.cell_px
				for dy: int in sheet.cell_px:
					for dx: int in sheet.cell_px:
						var color: Color = image.get_pixelv(sample + Vector2i(dx, dy))
						var exact: bool = color.a == 0.0 if index == 0 else color.to_rgba32() == Sheet._palette[index].to_rgba32()
						assert(exact, "Indexed shader RGBA and pixel size")
						checked += 1
	view.free()
	print("GRD-11 SHADER RGBA: PASS (%d framebuffer pixels)" % checked)
