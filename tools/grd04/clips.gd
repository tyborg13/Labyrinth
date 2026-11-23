extends SceneTree
## Record one occupied stone gallery board per MovieWriter invocation.

const Board = preload("res://scripts/combat_board_view.gd")
const Fixture = preload("res://tools/grd01/fixtures.gd")
const GroundLayer = preload("res://scripts/board_pixel_surface_layer.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const FPS: int = 30
const CLIP_SECONDS: int = 4
const FRAMES: int = FPS * CLIP_SECONDS
const SETTLE_FRAMES: int = 4
const STONE: String = "stone"
const KINDS: PackedStringArray = ["fire", "electrified", "ice", "rubble", "stormcoal"]
const SPEEDS: PackedFloat32Array = [1.0, 0.5]
const MOVIE_CLOCK_EPSILON: float = 0.00001
const ELECTRIFIED_GAP := Rect2i(6, 3, 1, 3)
const ELECTRIFIED_ELBOW := Vector2i(7, 5)
const ELECTRIFIED_SIDE := Rect2i(7, 3, 1, 3)
const ELECTRIFIED_PAIR_COUNT: int = 15

var _view: SubViewport
var _check_only: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_check_only = "--check-fixtures" in args
	assert(GroundLayer.enabled() and Cel.mode == "all", "Use pixel ground and the cel look")
	assert(_check_only or DisplayServer.get_name() != "headless", "Use the native visual probe runner")
	_view = Fixture.make_view(Fixture.SIZE, Fixture.SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	if _check_only:
		for kind: String in KINDS:
			for speed: float in SPEEDS:
				await _record(kind, speed)
		print("GRD-05 CLIP FIXTURES: PASS (10 occupied stone boards, 120 ticks each at 30 fps, full and half speed; 15 Electrified pairs and one empty tile column)")
	else:
		assert(args.size() in [5, 6] and KINDS.has(args[0]) and SPEEDS.has(args[1].to_float()))
		assert(not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == FPS,
			"MovieWriter must capture at 30 fps")
		_show_capture()
		var frame_output: String = args[5] if args.size() == 6 else ""
		var receipt: Dictionary = await _record(args[0], args[1].to_float(), frame_output)
		var output: String = args[2]
		var proof: String = output.path_join("proof.png")
		var image: Image = _view.get_texture().get_image()
		assert(image != null and image.get_size() == Fixture.SIZE)
		assert(image.save_png(proof) == OK)
		var file := FileAccess.open(output.path_join("capture.json"), FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(receipt, "\t"))
		file.close()
		print(proof)
		print("GRD-05 MOVIEWRITER: PASS (%s, %s×, %d consecutive frames at %d fps)" % [args[0], args[1], FRAMES, FPS])
		Clock.release_shutdown_callables()
	quit()

func _show_capture() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Fixture.SIZE
	root.content_scale_size = Fixture.SIZE
	root.content_scale_factor = 1.0
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	var composite := Sprite2D.new()
	composite.centered = false
	composite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	composite.texture = _view.get_texture()
	root.add_child(composite)

func _record(kind: String, speed: float, frame_output: String = "") -> Dictionary:
	Engine.time_scale = 1.0
	var sample: Dictionary = Fixture.patch_case(STONE, kind, true)
	if kind == "electrified":
		Fixture.place_rect(sample["state"], ELECTRIFIED_SIDE, kind)
		Fixture.Ground.place(sample["state"], ELECTRIFIED_ELBOW + Vector2i.RIGHT, kind)
	var shown: Dictionary = sample["shown"]
	shown.erase("ambient_time_seconds")
	var board := Board.new()
	board.size = Vector2(Fixture.SIZE)
	_view.add_child(board)
	Fixture.submit(board, sample["state"], shown)
	var layer: GroundLayer = board.get_node("PixelGround")
	var electrified_pairs: int = _verify_board(board, layer, kind)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	# Settle both takes at the same speed so they start from the same phase.
	Engine.time_scale = speed
	var first_elapsed: float
	var first_frame: int
	var first_usec: int
	for index: int in FRAMES:
		if _check_only:
			await process_frame
		else:
			await RenderingServer.frame_post_draw
		var frame: int = Engine.get_process_frames() if _check_only else Engine.get_frames_drawn()
		if index == 0:
			first_frame = frame
			first_elapsed = layer._elapsed
			first_usec = Clock.ticks_usec()
		assert(frame == first_frame + index, "Capture frames must be consecutive")
		if not frame_output.is_empty():
			var image: Image = _view.get_texture().get_image()
			assert(image != null and image.get_size() == Fixture.SIZE)
			assert(image.save_png(frame_output.path_join("frame-%03d.png" % index)) == OK)
		if not _check_only and index < FRAMES - 1:
			await process_frame
	var elapsed: float = speed * (FRAMES - 1) / FPS
	var field_elapsed: float = layer._elapsed - first_elapsed
	if kind != "rubble":
		# Godot's fixed render rate still synchronises process delta with
		# physics. The field may differ from the movie clock by one tick.
		var process_tolerance: float = speed / Engine.physics_ticks_per_second
		assert(absf(field_elapsed - elapsed) <= process_tolerance,
			"%s at %.1f× advanced %.6f game seconds, expected %.6f" % [kind, speed, field_elapsed, elapsed])
	if not _check_only:
		assert(absf(float(Clock.ticks_usec() - first_usec) / 1000000.0 - elapsed) < MOVIE_CLOCK_EPSILON)
	board.queue_free()
	return {"kind": kind, "speed": speed, "fps": FPS, "frames": FRAMES, "seconds": CLIP_SECONDS,
		"first_draw_frame": first_frame, "last_draw_frame": first_frame + FRAMES - 1,
		"field_seconds_between_draws": field_elapsed,
		"size": [Fixture.SIZE.x, Fixture.SIZE.y], "ui_scale": 1.0, "cel_look": Cel.mode,
		"electrified_pairs": electrified_pairs}

static func _verify_board(board: Board, layer: GroundLayer, kind: String) -> int:
	assert(board.get("_biome_id") == STONE)
	var units: Array = board.call("_visible_units")
	assert(units.size() == 2)
	for unit: Dictionary in units:
		var position: Vector2i = Fixture.HERO_ON_PATCH if unit["role"] == "player" else Fixture.ENEMY_ON_PATCH
		assert(unit["pos"] == position and Fixture.PATCH.has_point(position))
	var id: int = layer.Field.ELEMENT_IDS.get(kind, layer.Field.RUBBLE)
	if kind == "stormcoal":
		id = int(layer.Field.ELEMENT_IDS["fire"]) | layer.Field.STORMCOAL
	var tiles: Array[Vector2i] = Fixture.tiles_in(Fixture.PATCH)
	if kind == "electrified":
		tiles.append_array(Fixture.tiles_in(ELECTRIFIED_SIDE))
		tiles.append(ELECTRIFIED_ELBOW + Vector2i.RIGHT)
		for tile: Vector2i in Fixture.tiles_in(ELECTRIFIED_GAP):
			assert(not layer.field.tiles.has(tile) and not layer.decals.bins.has(tile))
	assert(layer.field.tiles.size() == tiles.size() and layer.grid == 2)
	var tile_to_cell: Transform2D = layer._cell_to_tile.affine_inverse()
	var capture_cells := Rect2(Vector2.ZERO, Vector2(layer.cell_rect.size))
	var pairs: int = 0
	for tile: Vector2i in tiles:
		assert(layer.field.tiles.get(tile, 0) == id)
		assert(capture_cells.has_point(tile_to_cell * Vector2(tile)), "Clip must frame the whole fixture")
		if kind == "electrified":
			for direction: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN]:
				pairs += int(layer.field.tiles.has(tile + direction))
	assert(pairs == (ELECTRIFIED_PAIR_COUNT if kind == "electrified" else 0))
	var counts: Dictionary = {}
	for decal: Dictionary in layer.decals.placements:
		var key: int = decal["kind"]
		counts[key] = int(counts.get(key, 0)) + 1
	if kind == "stormcoal":
		assert(counts.size() == 2 and counts.has(layer.Field.ELEMENT_IDS["fire"]) and counts.has(layer.Field.ELEMENT_IDS["electrified"]))
	else:
		assert(counts.size() == 1 and counts.has(id))
	return pairs
