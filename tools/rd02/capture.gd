extends SceneTree

const Fixture = preload("res://tools/rd02/fixture.gd")
const Real = preload("res://tools/ptf09/real_fixture.gd")
const Outline = preload("res://scripts/board_occlusion_silhouettes.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const FRAMES: int = 90
const FPS: int = 30
const COMPACT_SIZE := Vector2i(1280, 800) # Proof-only compact viewport.
const SIZE := Vector2i(1920, 1080)
var failures: Array[String]
var samples: Array[Dictionary]
var check_only: bool = false
var clip: bool = false
var case_name: String = "standard"
var capture_size: Vector2i = SIZE
var output: String
var scene: Node
var board: Control
var overlay: Node2D
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	check_only = args.has("--check-only")
	clip = args.has("--clip")
	if args.has("--compact"): capture_size = COMPACT_SIZE
	if args.has("--case"): case_name = args[args.find("--case") + 1]
	output = Fixture.OUTPUT.path_join("clip" if clip else "stills").path_join(case_name)
	if args.has("--output-dir"): output = args[args.find("--output-dir") + 1]
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not check_only:
		push_error("Native visual proof belongs to the design owner")
		quit(1)
		return
	Fixture.install(case_name)
	canvas = Real.make_canvas(self)
	root.size = capture_size
	root.content_scale_size = capture_size
	scene = Real.resume(self, canvas)
	for frame: int in range(Fixture.SETTLE_FRAMES): await process_frame
	board = scene.get("board_view")
	overlay = board.get("_occlusion_silhouettes")
	DirAccess.make_dir_recursive_absolute(output)
	_check_composition()
	if clip:
		if check_only: Engine.max_fps = FPS
		_check(check_only or (not Engine.get_write_movie_path().is_empty() and Clock._read_movie_fps() == FPS), "MovieWriter fixed 30 fps required")
		var path: Array[Vector2i]
		path.assign(Fixture.WALK)
		_walk(path)
		var previous: int = -1
		for frame: int in range(FRAMES):
			if check_only: await process_frame
			else: await RenderingServer.frame_post_draw
			var now: int = Clock.ticks_usec()
			if not check_only and previous >= 0: _check(absi(now - previous - 33333) <= 1, "One movie frame per 1/30 game second")
			previous = now
			samples.append({"frame": frame, "draw_frame": Engine.get_frames_drawn(), "clock_usec": now, "active": _active(), "team": _team_state(), "hero_pose": board.call("protagonist_animation_snapshot")})
			if not check_only and frame < FRAMES - 1: await process_frame
		_check_movie_states()
	else:
		# Disable all simulation/animation processing after settling. The second
		# render only removes the tool overlay; every source texture/pose is held.
		overlay.sync_coverage()
		overlay._process(0.15)
		scene.process_mode = Node.PROCESS_MODE_DISABLED
		var before: Array = Fixture.signature(board) if not check_only else []
		_check(not overlay.get("team").get("entries").is_empty(), "Requested fight has normal team outlines")
		_check(case_name in ["standard", "hero"] or not _active().is_empty(), "Requested occlusion fight has covered targets")
		await _still("on")
		overlay.set_tool_enabled(false)
		await _still("off")
		_check(check_only or before == Fixture.signature(board), "On/off captures have identical source pixels and placement")
		# Director accepted the existing ptf09 floor-border ordering.
	var file := FileAccess.open(output.path_join("semantics.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"real_game": true, "case": case_name, "size": [capture_size.x,capture_size.y], "ui_scale": 1.0,
		"movie": clip, "movie_path": Engine.get_write_movie_path(), "fps": FPS, "samples": samples, "failures": failures}, "\t"))
	file.close()
	for failure: String in failures: push_error(failure)
	print(output)
	if clip: print(Engine.get_write_movie_path().get_base_dir())
	print("RD02 REAL CAPTURE: %s (%s, %d samples)" % ["PASS" if failures.is_empty() else "FAIL", case_name, samples.size()])
	quit(0 if failures.is_empty() else 1)

func _walk(path: Array[Vector2i]) -> void:
	await scene.call("_animate_actor_along_path", scene.get("_combat_state"), "player", path, board.get("presentation"))

func _active() -> Array:
	var result: Array = []
	for key: String in overlay.get("entries"):
		var entry: Dictionary = overlay.get("entries")[key]
		if bool(entry["on"]): result.append({"key": key, "coverage": entry["coverage"], "alpha": entry["alpha"]})
	return result

func _still(label: String) -> void:
	if check_only: await process_frame
	else:
		await RenderingServer.frame_post_draw
		var image: Image = canvas.get_texture().get_image()
		_check(image.get_size() == capture_size and image.save_png(output.path_join(label + ".png")) == OK, "1920x1080 capture " + label)
	samples.append({"name": label, "active": _active(), "overlay_visible": overlay.visible, "team": _team_state()})

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)


func _check_composition() -> void:
	var sources: Array[Dictionary] = Sources.collect(board)
	var alpha := Alpha.new()
	alpha.prepare(sources)
	var matches: Dictionary = {}
	for index: int in range(sources.size()):
		var source: Dictionary = sources[index]
		if not bool(source["eligible"]): continue
		var kind: String = source["kind"]
		var data: Dictionary = source.get("data", {})
		var covered: float = alpha.coverage_for(sources, index)
		if str(source.get("key", "")) == ("enemy_1" if case_name == "warband" else "player"):
			print("RD02 ALPHA COVERAGE %s %s: %.6f (%s)" % [case_name, source["key"], covered, "on" if Outline.switched_on(covered, false, kind == "unit") else "off"])
			if case_name == "hero": _check(not Outline.switched_on(covered, false, true), "Visible hero has no x-ray")
			if case_name in ["zekarion_arena", "vyraketh_arena"]: _check(Outline.switched_on(covered, false, true), "Hero behind real arena dragon gets x-ray")
			if case_name == "walk": _check(covered < Outline.UNIT_OFF, "Movie begins with an uncovered normal rim")
		var owner_coverage: float = covered
		if case_name in ["zekarion", "vyraketh"]: owner_coverage = alpha.coverage_for(sources, index, "", case_name)
		elif case_name == "warband": owner_coverage = alpha.coverage_for(sources, index, "pillar")
		if not Outline.switched_on(owner_coverage, false, kind == "unit"): continue
		if kind == "unit": matches[str(data.get("type", ""))] = true
		elif kind == "terrain": matches[str(data.get("kind", ""))] = true
		else: matches[kind] = true
	if case_name == "standard":
		_check(board.get("combat_state")["enemies"].size() in [4, 5] and overlay.get("team").get("entries").size() >= 5, "Section I fight has four to five ordinary foes plus hero rims")
	if case_name in ["zekarion_arena", "vyraketh_arena", "walk"]:
		var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Fixture.OUTPUT.path_join(case_name + ".json")))
		_check(manifest.get("scenario") == "dragon", "Certified production dragon arena")
	match case_name:
		"zekarion": _check(matches.has("player"), "Hero covered by Zekarion")
		"vyraketh": _check(matches.has("player") and matches.has("trap"), "Hero and trap covered by Vyraketh")
		"warband": _check(not matches.is_empty(), "Warband foe covered by pillar")
	print("RD02 COMPOSITION ", case_name, ": ", JSON.stringify(matches))

func _team_state() -> Dictionary:
	var result: Dictionary = {}
	for key: String in overlay.get("team").get("entries"):
		var item: Dictionary = overlay.get("team").get("entries")[key]
		result[key] = {"alpha": item.get("base_alpha", 0.0), "xray_alpha": item.get("xray_alpha", 0.0), "visible": item["sprite"].visible, "depth_slot": item["sprite"].get_parent().get_parent().name}
	return result

func _check_movie_states() -> void:
	_check(samples[0]["team"]["player"]["visible"] and samples[-1]["team"]["player"]["visible"], "Normal rim begins and ends the walk")
	var fully_replaced: bool = false
	var fades: bool = false
	var walking: bool = false
	for sample: Dictionary in samples:
		var hero: Dictionary = sample["team"]["player"]
		fully_replaced = fully_replaced or (not bool(hero["visible"]) and float(hero["xray_alpha"]) >= 0.8)
		fades = fades or (float(hero["xray_alpha"]) > 0.0 and float(hero["xray_alpha"]) < 0.8)
		walking = walking or str(sample["hero_pose"].get("clip")) == "walk"
	_check(fully_replaced and fades and walking, "Walk has live poses, full x-ray replacement and threshold fades")
	_check(is_zero_approx(samples[0]["team"]["player"]["xray_alpha"]) and is_zero_approx(samples[-1]["team"]["player"]["xray_alpha"]), "Hero starts and finishes outside x-ray occlusion")
