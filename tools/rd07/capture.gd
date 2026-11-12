extends "res://tools/rd07/board_ui_proof.gd"

const CAPTURE_ROOT: String = "/private/tmp/labyrinth_codex/rd-07"
const FPS: int = 30
const CLIP_FRAMES: int = 90
const ENTER_FRAME: int = 15
const LEAVE_FRAME: int = 60
const POINTER_TRAVEL_FRAMES: int = 6
const TOOLTIP_WAIT_SECONDS: float = 0.8
var check_only: bool = false
var movie: bool = false
var dragon: bool = false
var samples: Array[Dictionary]
var capture_dir: String
var target: Dictionary

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	movie = args.has("--clip")
	dragon = args.has("--zekarion")
	_check(check_only or DisplayServer.get_name() != "headless", "Native capture belongs to design owner")
	if not failures.is_empty(): _finish(); return
	if dragon: preload("res://tools/rd07/fixture.gd").install_dragon(DRAGON)
	else: Fixture.install_save(COMBAT)
	canvas = Fixture.make_canvas(self)
	canvas.gui_embed_subwindows = true
	scene = Fixture.resume(self, canvas)
	await _settle(SETTLE_FRAMES)
	board = scene.get("board_view")
	_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
	if not dragon:
		var composition: Dictionary = preload("res://tools/rd07/fixture.gd").open_composition(board)
		_check(bool(composition.hero_clear) and int(composition.clear_foes) >= 2 and int(composition.foes) in [4, 5], "Capture fixture has clear hero and two clear foes")
	target = _foe()
	if dragon:
		for unit: Dictionary in board.call("_visible_units"):
			if str(unit.get("type")) == "zekarion": target = unit
	capture_dir = CAPTURE_ROOT.path_join("clip" if movie else "zekarion" if dragon else "stills")
	DirAccess.make_dir_recursive_absolute(capture_dir)
	if movie:
		_check(check_only or (not Engine.get_write_movie_path().is_empty() and preload("res://scripts/presentation_clock.gd")._read_movie_fps() == FPS), "Native MovieWriter at 30 fps")
		await _movie()
	elif dragon:
		_clear_context()
		await _still("10_zekarion_rest")
		await _pointer(board.call("world_position_for_tile", target.pos))
		await _still("11_zekarion_hover")
	else:
		_clear_context()
		_setting(Settings.BOARD_HEALTH_ALWAYS)
		await _still("01_rest_always")
		_setting(Settings.BOARD_HEALTH_CONTEXTUAL)
		await _still("02_rest_on_hover_and_aim")
		await _pointer(board.call("world_position_for_tile", target.pos))
		await _still("03_enemy_hover")
		var prop: Dictionary = board.combat_state.terrain[0]
		await _pointer(board.call("world_position_for_tile", prop.pos))
		await _still("04_crate_hover")
		await _pointer(board.call("world_position_for_tile", target.pos))
		_check(board.plate_visibility.opacity(board.plate_visibility.terrain_key(prop)) == 0.0, "Adjacent enemy hover leaves crate bar hidden")
		await _still("05_enemy_beside_crate")
		_clear_context()
		var state: Dictionary = scene.get("_combat_state").duplicate(true)
		state.player.block = HERO_BLOCK
		state.enemies[0].bleed = ENEMY_BLEED
		state.enemies[0].expose = ENEMY_EXPOSE
		scene.set("_combat_state", state)
		scene.call("_refresh_stage_view")
		await _settle(SETTLE_FRAMES)
		_clear_context()
		await _still("06_hero_block_rest")
		await _pointer(board.call("world_position_for_tile", state.player.pos))
		await _still("07_hero_block_hover")
		var hero: Dictionary = board.call("_units_by_key", board.call("_visible_units")).player
		var layout: Dictionary = board.get("_status_plate_layout").resolve(board, hero, board.call("_unit_health_bar_rect", hero, board.call("_unit_center", hero)))
		await _pointer((layout.defenses[0].rect as Rect2).get_center())
		await create_timer(TOOLTIP_WAIT_SECONDS).timeout
		_check(not str(board.call("_get_tooltip", (layout.defenses[0].rect as Rect2).get_center())).is_empty(), "Status tooltip available at fixed icon")
		await _still("08_status_tooltip")
		_clear_context()
		await scene.call("_on_card_pressed", 0)
		await _pointer(board.call("world_position_for_tile", target.pos))
		await _still("09_ranged_aim")
		await scene.call("_on_cancel_requested")
		_clear_context()
		scene.call("_on_enemy_intent_toggle_toggled", true)
		await _still("09_details")
	var file := FileAccess.open(capture_dir.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"movie": movie, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "samples": samples, "failures": failures, "size": [1920, 1080], "ui_scale": 1.0}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD07 CAPTURE SETUP: %s (%d samples%s)" % ["PASS" if failures.is_empty() else "FAIL", samples.size(), ", headless; no images" if check_only else ", native 1920x1080; 100% UI"])
	print(capture_dir)
	if is_instance_valid(scene): scene.queue_free()
	quit(0 if failures.is_empty() else 1)

func _pointer(point: Vector2) -> void:
	Fixture.pointer(self, board, point)
	await _settle(SETTLE_FRAMES)
	board.plate_visibility.advance(FADE_SETTLE)

func _still(label: String) -> void:
	board.plate_visibility.advance(SETTLED_SECONDS)
	await _settle(SETTLE_FRAMES)
	_check(is_equal_approx(Typography.ui_scale(scene), 1.0), "100% UI scale")
	if not check_only:
		await RenderingServer.frame_post_draw
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == Fixture.SIZE and picture.save_png(capture_dir.path_join(label + ".png")) == OK, "1920x1080 native still: " + label)
	samples.append({"name": label + ".png", "setting": Settings._applied_board_health_bars, "intent": _badge(str(target.key)), "plate_opacity": board.plate_visibility.opacity(str(target.key))})

func _movie() -> void:
	_clear_context()
	var destination: Vector2 = board.call("world_position_for_tile", target.pos)
	var origin: Vector2 = destination + Vector2(float(board.call("_tile_width")) * 2.0, 0.0)
	var last_clock: int = -1
	for frame: int in range(CLIP_FRAMES):
		var ratio: float = clampf(float(frame - ENTER_FRAME) / POINTER_TRAVEL_FRAMES, 0.0, 1.0)
		if frame >= LEAVE_FRAME: ratio = 1.0 - clampf(float(frame - LEAVE_FRAME) / POINTER_TRAVEL_FRAMES, 0.0, 1.0)
		Fixture.pointer(self, board, origin.lerp(destination, ratio))
		await process_frame
		if not check_only: await RenderingServer.frame_post_draw
		var now: int = preload("res://scripts/presentation_clock.gd").ticks_usec()
		if not check_only and last_clock >= 0: _check(absi(now - last_clock - 33333) <= 1, "Consecutive 30 fps native frame")
		last_clock = now
		samples.append({"frame": frame, "draw_frame": Engine.get_frames_drawn(), "clock_usec": now, "intent": _badge(str(target.key)), "pointer": str(origin.lerp(destination, ratio))})
	_check(bool(samples[CLIP_FRAMES / 2].intent.unfurled), "Movie enters inspected marker")
	_check(not bool(samples.back().intent.unfurled), "Movie leaves inspected marker")
	if not check_only: canvas.get_texture().get_image().save_png(capture_dir.path_join("last_frame.png"))
