extends SceneTree

## Stills and movie-mode sweep of a real, certified combat inspection save.
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-09/feedback2/stills"
const FPS: int = 30
const CLIP_FRAMES: int = 120
const STILL_SETTLE_FRAMES: int = 6
var check_only: bool = false
var clip: bool = false
var output_dir: String = OUTPUT
var manifest: String = Fixture.MANIFEST
var failures: Array[String]
var samples: Array[Dictionary]
var scene: Node
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	clip = args.has("--clip")
	if args.has("--output-dir"): output_dir = args[args.find("--output-dir") + 1]
	if args.has("--fixture-manifest"): manifest = args[args.find("--fixture-manifest") + 1]
	if DisplayServer.get_name() == "headless": process_frame.connect(_headless_boundary)
	call_deferred("_run")

func _run() -> void:
	if not check_only and DisplayServer.get_name() == "headless":
		push_error("Native capture belongs to the design owner")
		quit(1)
		return
	if clip and not check_only and (Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS):
		push_error("Clip requires --write-movie and --fixed-fps 30; wall-clock PNG sampling is forbidden")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(output_dir)
	Fixture.install_save(manifest)
	canvas = Fixture.make_canvas(self)
	scene = Fixture.resume(self, canvas)
	await _settle(Fixture.SETUP_FRAMES)
	_check(str(scene.get("_run_state").get("mode", "")) == "combat" and not bool(scene.get("_dialogue_active")), "Production resume is real combat without dialogue")
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "Actual UI scale is 100%")
	_check(str((scene.get("_combat_state") as Dictionary).get("room_name", "")) != "Live Move Attack Shortcut Test", "Generated room title retained")
	await scene.call("_on_card_pressed", 0)
	await _settle(STILL_SETTLE_FRAMES)
	_check_composition()
	if clip:
		await _movie_sweep()
	else:
		await _still("01_dull_bolt_foe_behind_crate", Fixture.FOE, "attack")
		await _still("02_empty_behind_tall_unit", Fixture.EMPTY_BEHIND, "invalid")
		await _still("03_unit_feet", Fixture.TALL, "attack")
		await scene.call("_on_cancel_requested")
		scene.call("_begin_player_movement_selection")
		await _settle(STILL_SETTLE_FRAMES)
		var moves: Array = scene.get("_player_movement_target_tiles")
		_check(not moves.is_empty(), "Real hero has movement destinations")
		if not moves.is_empty(): await _still("04_valid_move", moves[0], "move")
		await _still("05_invalid_tile", Fixture.FOE, "invalid")
		await scene.call("_on_cancel_requested")
		await scene.call("_on_card_pressed", 0)
		var router: Node = root.get_node("InputRouter")
		router.call("set_forced_state_for_test", "controller", "steam_deck")
		scene.set("_controller_region", "board")
		scene.call("_controller_set_board_tile", Fixture.FOE)
		await _still("06_controller_foe", Fixture.FOE, "attack", false)
		router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var file := FileAccess.open(output_dir.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"source": manifest, "real_game": true, "movie": not Engine.get_write_movie_path().is_empty(), "movie_path": Engine.get_write_movie_path(), "fps": FPS, "size": [1920, 1080], "samples": samples, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("PTF09 REAL CAPTURE: %s (%d states, 1920x1080, 100%% UI)" % ["PASS" if failures.is_empty() else "FAIL", samples.size()])
	if not check_only and not clip: print(output_dir)
	quit(0 if failures.is_empty() else 1)

func _movie_sweep() -> void:
	var board: Control = scene.get("board_view")
	var previous_usec: int = -1
	for frame: int in range(CLIP_FRAMES):
		var phase: float = float(frame) / float(CLIP_FRAMES - 1) * float(Fixture.SWEEP.size() - 1)
		var index: int = mini(int(phase), Fixture.SWEEP.size() - 2)
		var from: Vector2 = board.call("world_position_for_tile", Fixture.SWEEP[index])
		var to: Vector2 = board.call("world_position_for_tile", Fixture.SWEEP[index + 1])
		Fixture.pointer(self, board, from.lerp(to, phase - float(index)))
		if check_only: await process_frame
		else: await RenderingServer.frame_post_draw
		var now: int = Clock.ticks_usec()
		if not check_only and previous_usec >= 0: _check(absi(now - previous_usec - 33333) <= 1, "Movie clock advances exactly 1/30 second per frame")
		previous_usec = now
		_record("sweep_%03d" % frame)
		if not check_only and frame < CLIP_FRAMES - 1: await process_frame
	print("PTF09 MOVIE CONTRACT: 120 consecutive frames / 30 fps = 4 seconds; 6 sweep tiles")

func _still(label: String, tile: Vector2i, tone: String, pointer: bool = true) -> void:
	var board: Control = scene.get("board_view")
	if pointer: Fixture.pointer(self, board, board.call("world_position_for_tile", tile))
	await _settle(STILL_SETTLE_FRAMES)
	var border: Node2D = board.get("_targeted_tile_highlight")
	_check(border != null and border.visible and border.tile == tile and border.tone == tone, label + ": correct floor tile and tone")
	if pointer: _check(board.call("_tile_at_point", board.get("_last_pointer_position")) == tile, label + ": production GUI input owns the floor pick")
	_record(label)
	if not check_only:
		await RenderingServer.frame_post_draw
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == Fixture.SIZE and picture.save_png(output_dir.path_join(label + ".png")) == OK, label + ": actual 1920x1080 PNG")

func _record(label: String) -> void:
	var board: Control = scene.get("board_view")
	var border: Node2D = board.get("_targeted_tile_highlight")
	_check(Fixture.slot(board), label + ": floor painter slot")
	_check(border != null and border.visible and border.tile == scene.get("_hovered_board_tile"), label + ": highlighted tile equals commit tile")
	samples.append({"name":label, "hover":str(scene.get("_hovered_board_tile")), "clock_usec":Clock.ticks_usec(), "draw_frame":Engine.get_frames_drawn(), "process_frame":Engine.get_process_frames(), "pulse_alpha":border.self_modulate.a if border != null else 0.0})

func _check_composition() -> void:
	var board: Control = scene.get("board_view")
	var crate_texture: Texture2D = (board.get("_terrain_textures") as Dictionary).get("wooden_crate")
	_check(crate_texture != null, "Existing wooden-crate asset loaded")
	if crate_texture != null:
		var crate_rect: Rect2 = board.call("_terrain_rect_for_tile", Fixture.CRATE, crate_texture, "wooden_crate")
		var diamond: PackedVector2Array = board.call("_tile_polygon", Fixture.FOE)
		var covered: int = 0
		for i: int in range(4):
			if crate_rect.has_point(diamond[i] - Vector2(0.0, preload("res://scripts/targeted_tile_highlight.gd").RAISE * float(board.get("_navigation_zoom")))): covered += 1
		_check(covered > 0 and covered < 4, "Crate covers part of the lifted foe diamond, with the remainder on visible floor")
	var tall_found: bool = false
	for unit: Dictionary in board.call("_visible_units"):
		if str(unit.get("type", "")) != "warden": continue
		tall_found = true
		var body: Rect2 = board.call("_unit_draw_rect", unit)
		_check(body.has_point(board.call("world_position_for_tile", Fixture.EMPTY_BEHIND)), "Tall unit overlaps the empty tile behind it")
	_check(tall_found, "Tall production unit is present")

func _settle(frames: int) -> void:
	for frame: int in range(frames): await process_frame

func _headless_boundary() -> void:
	# Logic-only tests need a boundary for production coroutines. Native/movie
	# capture never emits renderer signals manually.
	RenderingServer.frame_post_draw.emit()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
