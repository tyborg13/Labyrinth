extends SceneTree

## Ten consecutive GUI-pointer frames. Tile selectors/draw plan must be stable;
## authored pulse phase is deliberately separate from tile-presentation identity.
const Fixture = preload("res://tools/ptf09/real_fixture.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const OUTPUT: String = "/private/tmp/labyrinth_codex/ptf-09/feedback2"
const FRAMES: int = 10
const FPS: int = 30
const SWEEP_FROM := Vector2i(4, 4)
const SWEEP_TO := Vector2i(5, 4)
var failures: Array[String]
var samples: Array[Dictionary]
var legacy_sampling: bool = false
var release_scripts: bool = false
var movie_clock: GDScript

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	legacy_sampling = OS.get_cmdline_user_args().has("--legacy-sampling")
	release_scripts = OS.get_cmdline_user_args().has("--release")
	if release_scripts: _use_release_scripts()
	if DisplayServer.get_name() == "headless": process_frame.connect(_headless_boundary)
	call_deferred("_run")

func _use_release_scripts() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var bundle: Dictionary = packed._bundled.duplicate(true)
	var variants: Array = bundle["variants"]
	for i: int in range(variants.size()):
		if variants[i] is Script and variants[i].resource_path == "res://scripts/run_scene.gd": variants[i] = load(OUTPUT.path_join("release_run_scene.gd"))
		if variants[i] is Script and variants[i].resource_path == "res://scripts/combat_board_view.gd": variants[i] = load(OUTPUT.path_join("release_combat_board_view.gd"))
	bundle["variants"] = variants
	packed._bundled = bundle

func _run() -> void:
	Fixture.install_save()
	var canvas: SubViewport = Fixture.make_canvas(self)
	var scene: Node = Fixture.resume(self, canvas)
	for frame: int in range(Fixture.SETUP_FRAMES): await process_frame
	await scene.call("_on_card_pressed", 0)
	for frame: int in range(6): await process_frame
	var board: Control = scene.get("board_view")
	var origin: Vector2 = board.call("world_position_for_tile", SWEEP_FROM)
	var destination: Vector2 = board.call("world_position_for_tile", SWEEP_TO)
	Fixture.pointer(self, board, origin)
	for frame: int in range(3): await process_frame
	movie_clock = GDScript.new()
	# Same production movie clock, with engine startup arguments injected only
	# because this logic-only test is forbidden from recording dummy pixels.
	var original_clock: Script = Clock
	movie_clock.source_code = original_clock.source_code.replace('Engine.get_write_movie_path()', '"movie.png"').replace('OS.get_cmdline_args()', 'PackedStringArray(["--write-movie", "movie.png", "--fixed-fps", "30"])')
	_check(movie_clock.reload() == OK, "Production movie-clock test injection compiles")
	var old: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(OUTPUT.path_join("legacy_sampling.json")))
	var first: Dictionary = {}
	var previous: int = -1
	for frame: int in range(FRAMES):
		Fixture.pointer(self, board, origin.lerp(destination, float(frame) / float(FRAMES - 1)))
		await process_frame
		var tile: Vector2i = scene.get("_hovered_board_tile")
		_check(tile != Fixture.CRATE and board.get("_hover_tile") == tile, "Single production GUI path never visits crate")
		var state: Dictionary = tile_presentation(board, Fixture.CRATE)
		if frame == 0: first = state.duplicate(true)
		_check(state == first, "Crate presentation identical in consecutive sweep frame " + str(frame))
		var ticks: int = int(old["saved_wall_usec"][frame]) if legacy_sampling else movie_clock.ticks_usec()
		if previous >= 0: _check(absi(ticks - previous - 33333) <= 1, "Sampling advances 1/30 second: frame " + str(frame) + " step=" + str(ticks - previous))
		previous = ticks
		samples.append({"frame": frame, "hover": str(tile), "crate": state, "sample_usec": ticks})
	movie_clock.release_shutdown_callables()
	var label: String = ("release" if release_scripts else "candidate") + ("_before" if legacy_sampling else "_after")
	var file := FileAccess.open(OUTPUT.path_join("flicker_" + label + ".json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"side":label,"frames":samples,"logical_crate_stable":samples.all(func(row:Dictionary)->bool:return row["crate"]==first),"headless_movie_clock_injected":true,"failures":failures},"\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print("PTF09 FLICKER %s: %s (10 identical crate presentations; %d timing/input failures)" % [label, "PASS" if failures.is_empty() else "FAIL", failures.size()])
	quit(0 if failures.is_empty() else 1)

static func tile_presentation(board: Control, tile: Vector2i) -> Dictionary:
	var shown: Dictionary = board.get("presentation")
	var layer: Control = board.get("_overlay_render_layer")
	var ops: Array = []
	var canvases: Array = [layer]
	canvases.append_array(layer.get("_layer_slices").canvases)
	var polygon: PackedVector2Array = board.call("_tile_polygon", tile)
	for canvas: Node in canvases:
		for op: Array in canvas.get("_render_slice_ops"):
			var args: Array = op[1]
			if not args.is_empty() and ((typeof(args[0])==TYPE_VECTOR2I and args[0]==tile) or (typeof(args[0])==TYPE_PACKED_VECTOR2_ARRAY and args[0]==polygon)): ops.append(op.duplicate(true))
	return {"move":(board.get("move_tiles") as Array).has(tile),"attack":(board.get("attack_tiles") as Array).has(tile),"focus":(shown.get("focus_tiles",[]) as Array).has(tile),"selected":board.get("selected_tile")==tile,"hover":board.get("_hover_tile")==tile,"controller":board.get("_controller_focus_tile")==tile,"pulse_enabled":shown.get("pulse_attack_tiles",false),"operations":ops}

func _headless_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _check(condition: bool, message: String) -> void:
	if not condition: failures.append(message)
