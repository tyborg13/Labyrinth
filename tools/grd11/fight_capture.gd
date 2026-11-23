extends SceneTree
## 1920x1080 readback of normal combat and two committed Move actions.

const Fixture = preload("res://tools/grd11/fight_fixture.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Cel = preload("res://scripts/cel_look.gd")
const Gallery = preload("res://tools/grd01/fixtures.gd")
const SIZE := Vector2i(1920, 1080)
const FPS: int = 24
const FIGHT_FRAMES: int = 4 * FPS
const WALK_FRAMES: int = 3 * FPS
const STILLS: PackedInt32Array = [12, 36, 60]
const STORM_FRAME: int = 2 * FPS
const ENTER_FIRE_FRAME: int = 12
const LEAVE_FIRE_FRAME: int = 42
const SETTLE_FRAMES: int = 12
const FRAME_USEC: int = 1000000 / FPS

var _view: SubViewport
var _dry: bool
var _output: String
var _count: int
var _walking_frames: int

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_dry = args.has("--dry-run")
	assert(_dry == (DisplayServer.get_name() == "headless"))
	assert(Cel.mode == "all" and not Cel._files.is_empty(), "Prepare the existing cel variants and set LABYRINTH_CEL_LOOK=all")
	assert(_dry or not Engine.get_write_movie_path().is_empty(), "Run with the fixed 24 fps movie clock")
	for arg: String in args:
		if arg != "--dry-run":
			_output = arg
	assert(_output.is_absolute_path() and not FileAccess.file_exists(_output.path_join("fight-proof.json")))
	assert(DirAccess.make_dir_recursive_absolute(_output) == OK)
	Store.set_storage_path("user://grd11_progression.json")
	Store.set_run_storage_path("user://grd11_run.save")
	Settings.set_storage_path("user://grd11_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	assert(Settings.save_settings(settings))
	root.content_scale_factor = 1.0
	_view = Gallery.make_view(SIZE, SIZE, Viewport.MSAA_4X)
	root.add_child(_view)
	if not _dry:
		var preview := Sprite2D.new()
		preview.centered = false
		preview.texture = _view.get_texture()
		root.add_child(preview)
	for dir: String in ["fight", "stills", "walk"]:
		assert(DirAccess.make_dir_recursive_absolute(_output.path_join(dir)) == OK)
	await _fight("pixel")
	await _fight("off")
	await _walk()
	assert(_count == FIGHT_FRAMES + STILLS.size() * 2 + WALK_FRAMES)
	var file := FileAccess.open(_output.path_join("fight-proof.json"), FileAccess.WRITE)
	assert(file != null)
	file.store_string(JSON.stringify({
		"dry_run": _dry, "images_written": 0 if _dry else _count, "viewport": [SIZE.x, SIZE.y],
		"ui_scale": 1.0, "cel_look": Cel.mode, "fps": FPS, "fight_frames": FIGHT_FRAMES,
		"walk_frames": WALK_FRAMES, "walk_presentation_frames": _walking_frames,
		"still_frames": Array(STILLS), "stormcoal_rule_first_frame": STORM_FRAME,
	}, "\t") + "\n")
	file.close()
	print(_output)
	print("GRD-11 FIGHT %s: PASS (96 fight frames, 6 matched stills, 72 movement frames, %d live walk poses%s)" %
		["DRY RUN" if _dry else "NATIVE", _walking_frames, ", pixels skipped" if _dry else ""])
	quit()

func _fight(mode: String) -> void:
	var scene: Control = await _open(mode, false)
	var board: Control = scene.get("board_view")
	_check_fight(board, false, mode)
	for frame: int in FIGHT_FRAMES:
		if frame == STORM_FRAME:
			Fixture.enable_stormcoal(scene)
			_check_fight(board, true, mode)
		_set_ground_time(board, frame)
		var still: String = "%s-%04d.png" % [mode, frame] if STILLS.has(frame) else ""
		await _sample("fight/%04d.png" % frame if mode == "pixel" else "", "stills/" + still if not still.is_empty() else "")
	scene.free()
	await process_frame

func _walk() -> void:
	var scene: Control = await _open("pixel", true)
	var board: Control = scene.get("board_view")
	var pixel: Node = board.get_node("PixelGround")
	var front: Node = pixel.sheet.stamps[Vector3i(Fixture.WALK_FIRE.x, Fixture.WALK_FIRE.y, 1)]
	var low: Vector2i = front.rows_at(pixel.sheet.tick)
	var full_seen: bool = false
	var previous_foot := Vector2(INF, INF)
	for frame: int in WALK_FRAMES:
		var started: int = Time.get_ticks_usec()
		_set_ground_time(board, frame)
		if frame == ENTER_FIRE_FRAME:
			assert(Fixture.player_tile(scene) == Fixture.WALK_START)
			_move(scene, Fixture.WALK_FIRE)
		elif frame == LEAVE_FIRE_FRAME:
			assert(Fixture.player_tile(scene) == Fixture.WALK_FIRE)
			_move(scene, Fixture.WALK_END)
		var shown: Dictionary = board.get("presentation")
		var feet: Dictionary = shown.get("unit_footprint_world_positions", {})
		if feet.has("player") and feet["player"] != previous_foot:
			_walking_frames += 1
			previous_foot = feet["player"]
		full_seen = full_seen or front.rows_at(pixel.sheet.tick) != low
		if _dry:
			# CombatPacing uses live time when the dummy renderer cannot run
			# MovieWriter. Let one movement sample elapse before the next frame.
			OS.delay_usec(maxi(0, FRAME_USEC - (Time.get_ticks_usec() - started)))
		await _sample("walk/%04d.png" % frame)
	assert(Fixture.player_tile(scene) == Fixture.WALK_END and _walking_frames >= 4)
	assert(full_seen and front.rows_at(pixel.sheet.tick) == low and not pixel.depth.occupied_tiles.has(Fixture.WALK_FIRE))
	scene.free()
	await process_frame

func _open(mode: String, walk: bool) -> Control:
	OS.set_environment("LABYRINTH_GROUND_FX", mode)
	var scene: Control = Fixture.Run.instantiate()
	_view.add_child(scene)
	await process_frame
	Fixture.configure(scene, walk)
	for frame: int in SETTLE_FRAMES:
		await process_frame
	assert(_view.size == SIZE and scene.get_viewport_rect().size == Vector2(SIZE))
	assert(preload("res://scripts/ui_typography.gd").ui_scale(scene) == 1.0)
	assert(scene.get("_movement_meter").is_visible_in_tree(), "Combat movement HUD is visible")
	assert(scene.get("_combat_objective_hud").is_visible_in_tree(), "Combat objective HUD is visible")
	assert(scene.get("hand_box").is_visible_in_tree(), "Combat hand is visible")
	var board: Control = scene.get("board_view")
	assert(board.get_node("HudRenderLayer").is_visible_in_tree() and not board.get("_hud_health_rects_cache").is_empty())
	assert(bool(board.get("_pixel_ground_enabled")) == (mode == "pixel"))
	return scene

func _move(scene: Control, to: Vector2i) -> void:
	scene.call("_on_board_tile_clicked", Fixture.player_tile(scene))
	assert(scene.get("_player_movement_selected") and scene.get("_player_movement_target_tiles").has(to))
	await scene.call("_on_board_tile_clicked", to)

func _check_fight(board: Control, storm: bool, mode: String) -> void:
	var state: Dictionary = board.get("combat_state")
	assert(not state.is_empty() and state["player"]["pos"] == Fixture.HERO)
	var by_tile: Dictionary = {}
	for enemy: Dictionary in state["enemies"]:
		by_tile[enemy["pos"]] = enemy["type"]
	assert(by_tile == {Fixture.CRAWLER: "crawler", Fixture.HARRIER: "harrier", Fixture.CRAGHIDE: "craghide"})
	for tile: Vector2i in [Fixture.HERO, Fixture.CRAWLER, Fixture.CRAGHIDE]:
		assert(Fixture.Ground.has_surface(state, tile, "fire") and Fixture.Ground.is_conductive(state, tile) == storm)
	assert(Fixture.Ground.has_surface(state, Fixture.HARRIER, "electrified"))
	_check_region(state, Fixture.FIRE_REGION, "fire")
	_check_region(state, Fixture.ELECTRIC_REGION, "electrified")
	_check_region(state, Fixture.STORM_REGION, "fire")
	_check_region(state, Fixture.ICE_REGION, "ice")
	_check_region(state, Fixture.RUBBLE_REGION, "rubble")
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(SIZE))
	var to_view: Transform2D = board.get_global_transform_with_canvas()
	for tile: Vector2i in Fixture.Ground.tiles(state):
		var center: Vector2 = board.call("world_position_for_tile", tile)
		assert(viewport_rect.has_point(to_view * center), "Surface tile %s must be in the capture" % tile)
	for unit: Dictionary in board.call("_visible_units"):
		var center: Vector2 = board.call("_unit_center", unit)
		assert(viewport_rect.has_point(to_view * center), "Actor %s must be in the capture" % unit["key"])
	if mode == "pixel":
		var pixel: Node = board.get_node("PixelGround")
		assert(pixel.sheet.stamps.size() == 2 * 12)
		assert(pixel.depth.occupied_tiles.size() == 4)
		assert(pixel._material.get_shader_parameter("electric_pulse") == Vector2(1.2, 0.15))
		var center: Vector2 = board.call("world_position_for_tile", Fixture.CRAGHIDE)
		var front: Node2D = pixel.sheet.stamps[Vector3i(Fixture.CRAGHIDE.x, Fixture.CRAGHIDE.y, 1)]
		assert(front.position.is_equal_approx(center))
		assert((pixel.field.tiles[Fixture.CRAGHIDE] & pixel.Field.STORMCOAL != 0) == storm)

func _check_region(state: Dictionary, area: Rect2i, kind: String) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			assert(Fixture.Ground.has_surface(state, Vector2i(x, y), kind))

func _set_ground_time(board: Control, frame: int) -> void:
	var ground: Node = board.get_node_or_null("PixelGround")
	if ground != null:
		ground.set_process(false)
		ground.set_motion_time(float(frame) / FPS)

func _sample(path: String, still: String = "") -> void:
	if not _dry and (not path.is_empty() or not still.is_empty()):
		await RenderingServer.frame_post_draw
		var image: Image = _view.get_texture().get_image()
		assert(image.get_size() == SIZE)
		if not path.is_empty():
			assert(image.save_png(_output.path_join(path)) == OK)
		if not still.is_empty():
			assert(image.save_png(_output.path_join(still)) == OK)
	_count += int(not path.is_empty()) + int(not still.is_empty())
	await process_frame
