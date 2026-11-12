extends SceneTree

## A movie records only setup plus the 90-frame sweep, never the test matrix.
const Fixture = preload("res://tools/rd04/real_fixture.gd")
const Cases = preload("res://tools/rd04/proof_case.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const FRAMES: int = 90
const FPS: int = 30
const SETUP_FRAMES: int = 8
var output_dir: String = "/private/tmp/labyrinth_codex/rd-04/feedback2/clip"
var manifest: String = Fixture.CASE_ROOT + "/overlap.json"
var check_only: bool = false
var samples: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args := OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	if args.has("--output-dir"): output_dir = args[args.find("--output-dir") + 1]
	if args.has("--fixture-manifest"): manifest = args[args.find("--fixture-manifest") + 1]
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if not check_only and (DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty()):
		push_error("Native MovieWriter capture belongs to the design owner")
		quit(1)
		return
	Fixture.install_save(manifest)
	var canvas := Fixture.make_canvas(self)
	var scene := Fixture.resume(self, canvas)
	for frame in range(SETUP_FRAMES): await process_frame
	var board: Control = scene.get("board_view")
	var found: Dictionary = Cases.find(board)
	var origin: Vector2i = found.get("enemy", {}).get("pos", Vector2i(-1, -1))
	var overlap: Vector2i = found["overlap"]
	var empty: Vector2i = found["empty"]
	if origin.x < 0 or overlap.x < 0 or empty.x < 0:
		push_error("Certified ordinary fight lacks a visible enemy, overlapping tile or clear floor")
		quit(1)
		return
	print("RD04 MOVIE READY: setup_frames=", SETUP_FRAMES, " sweep_frames=", FRAMES)
	for frame in range(FRAMES):
		var phase: float = float(frame) / float(FRAMES - 1) * 2.0
		var from: Vector2i = origin if phase < 1.0 else overlap
		var to: Vector2i = overlap if phase < 1.0 else empty
		var t: float = fmod(phase, 1.0) if frame < FRAMES - 1 else 1.0
		Fixture.pointer(self, board, board.call("world_position_for_tile", from).lerp(board.call("world_position_for_tile", to), t))
		if check_only: await process_frame
		else: await RenderingServer.frame_post_draw
		samples.append({"draw_frame": Engine.get_frames_drawn(), "process_frame": Engine.get_process_frames(), "clock_usec": Clock.ticks_usec()})
		if (frame + 1) % FPS == 0: print("RD04 MOVIE FRAME ", frame + 1, "/", FRAMES)
		if not check_only and frame < FRAMES - 1: await process_frame
	DirAccess.make_dir_recursive_absolute(output_dir)
	var file := FileAccess.open(output_dir.path_join("proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"failures": [], "movie_samples": samples, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "check_only": check_only, "setup_frames": SETUP_FRAMES, "source": manifest}, "\t"))
	print("RD04 MOVIE %s: PASS (90 sweep frames; 8 setup frames; no interaction-matrix waits)" % ("CHECK-ONLY" if check_only else "CAPTURE"))
	quit()
