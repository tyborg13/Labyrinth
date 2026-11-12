extends SceneTree

const Fixture = preload("res://tools/rd04/real_fixture.gd")
const Cases = preload("res://tools/rd04/proof_case.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const ROOT: String = "/private/tmp/labyrinth_codex/rd-08"
const FRAMES: int = 120
const FPS: int = 30
const SETUP_FRAMES: int = 8
const PHASE_FRAMES: int = 30
const TRAVEL_FRAMES: int = 6
var check_only: bool = false
var samples: Array[Dictionary]
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	check_only = OS.get_cmdline_user_args().has("--check-only")
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if not check_only and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty()):
		push_error("Native MovieWriter belongs to design owner"); quit(1); return
	Fixture.install_save(ROOT + "/overlap.json")
	var canvas := Fixture.make_canvas(self)
	var scene := Fixture.resume(self, canvas)
	Settings._applied_board_health_bars = Settings.BOARD_HEALTH_CONTEXTUAL
	for frame in range(SETUP_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var found: Dictionary = Cases.find(board)
	var enemy: Dictionary = found.enemy
	if enemy.is_empty() or found.overlap.x < 0 or found.empty.x < 0:
		push_error("Certified overlap scene must supply all three movie targets"); quit(1); return
	var positions: Array[Vector2]
	positions.append(board.call("world_position_for_tile", found.empty))
	positions.append(board.call("world_position_for_tile", enemy.pos))
	positions.append(board.call("world_position_for_tile", found.overlap))
	positions.append(positions[0])
	var key: String = "enemy_%d" % int(enemy.id)
	print("RD08 MOVIE READY: setup=8, sweep=120, fps=30")
	for frame: int in range(FRAMES):
		var phase: int = mini(frame / PHASE_FRAMES, 3)
		var previous: int = maxi(phase - 1, 0)
		var ratio: float = clampf(float(frame % PHASE_FRAMES) / TRAVEL_FRAMES, 0.0, 1.0)
		var point: Vector2 = positions[previous].lerp(positions[phase], ratio)
		Fixture.pointer(self, board, point)
		if check_only: await process_frame
		else: await RenderingServer.frame_post_draw
		var expanded: bool = board.plate_visibility.unfurled(key)
		var isolated: Array = board.presentation.get("isolated_enemy_actor_keys", [])
		if frame == 2 * PHASE_FRAMES - 1 and (not expanded or isolated != [key]): failures.append("Enemy phase must unfurl and isolate its intent")
		if frame == 3 * PHASE_FRAMES - 1 and isolated.size() != 2: failures.append("Threatened tile phase must reverse lookup both attackers")
		if frame == FRAMES - 1 and not isolated.is_empty(): failures.append("Away phase clears isolation")
		samples.append({"draw_frame": Engine.get_frames_drawn(), "clock_usec": Clock.ticks_usec(), "pointer": str(point), "isolated": isolated.duplicate(), "unfurled": expanded})
		if (frame + 1) % FPS == 0: print("RD08 MOVIE FRAME ", frame + 1, "/", FRAMES)
		if not check_only and frame < FRAMES - 1: await process_frame
	DirAccess.make_dir_recursive_absolute(ROOT + "/clip")
	var file := FileAccess.open(ROOT + "/clip/proof.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": failures, "movie_samples": samples, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "check_only": check_only, "setup_frames": SETUP_FRAMES}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD08 MOVIE %s: %s (120 frames; 30 fps; 4 seconds)" % ["CHECK-ONLY" if check_only else "CAPTURE", "PASS" if failures.is_empty() else "FAIL"])
	quit(0 if failures.is_empty() else 1)
