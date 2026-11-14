extends SceneTree

const Fixture = preload("res://tools/rd02/fixture.gd")
const Real = preload("res://tools/ptf09/real_fixture.gd")
const Outline = preload("res://scripts/board_occlusion_silhouettes.gd")
const Alpha = preload("res://scripts/board_occlusion_alpha.gd")
const Sources = preload("res://scripts/board_occlusion_sources.gd")
const Clock = preload("res://scripts/presentation_clock.gd")
const Team = preload("res://scripts/board_unit_team_outlines.gd")
const FRAMES: int = 90
const FPS: int = 30
const COMPACT_SIZE := Vector2i(1280, 800) # Proof-only compact viewport.
const SIZE := Vector2i(1920, 1080)
const IDLE_FRAMES: int = 30
const PHASE_FRAMES: int = 20 # Proof-only idle advance between front-cut checks.
const PIXEL_DIFF: float = 0.5 / 255.0 # Any 8-bit change; repeat grabs prove no noise.
const OPAQUE: float = 0.95 # Painted actors' solid areas; matches the rim shader.
const RING_VISIBLE: float = 0.10 # Drawn ring alpha that counts as ring; the shader cuts fully from here.
var failures: Array[String]
var samples: Array[Dictionary]
var check_only: bool = false
var clip: bool = false
var idle: bool = false
var case_name: String = "standard"
var manifest_path: String = ""
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
	idle = args.has("--idle")
	if args.has("--compact"): capture_size = COMPACT_SIZE
	if args.has("--case"): case_name = args[args.find("--case") + 1]
	output = Fixture.OUTPUT.path_join("clip" if clip else "stills").path_join(case_name)
	if args.has("--output-dir"): output = args[args.find("--output-dir") + 1]
	if args.has("--manifest"): manifest_path = args[args.find("--manifest") + 1]
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	if DisplayServer.get_name() == "headless" and not check_only:
		push_error("Native visual proof belongs to the design owner")
		quit(1)
		return
	if manifest_path.is_empty(): Fixture.install(case_name)
	else: Fixture.install_manifest(manifest_path)
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
		if not idle: _walk(path)
		var previous: int = -1
		var pose_updates: int = overlay.get("pose_updates")
		for frame: int in range(IDLE_FRAMES if idle else FRAMES):
			if check_only: await process_frame
			else: await RenderingServer.frame_post_draw
			var now: int = Clock.ticks_usec()
			if not check_only and previous >= 0: _check(absi(now - previous - 33333) <= 1, "One movie frame per 1/30 game second")
			previous = now
			samples.append({"frame": frame, "draw_frame": Engine.get_frames_drawn(), "clock_usec": now, "active": _active(), "team": _team_state(), "hero_pose": board.call("protagonist_animation_snapshot"), "fronts": _fronts(), "pose_updates": overlay.get("pose_updates")})
			if not check_only and frame < (IDLE_FRAMES if idle else FRAMES) - 1: await process_frame
		if idle:
			_check(int(overlay.get("pose_updates")) == pose_updates, "Idle poses move object rim cut-outs without CPU rim updates")
			_check(samples.any(func(sample: Dictionary) -> bool: return sample["hero_pose"] != samples[0]["hero_pose"]), "Hero idle pose animates during the strip")
			_check(not samples[0]["fronts"].is_empty(), "Idle strip has an object rim cut by a front unit")
		else: _check_movie_states()
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
		await _check_front_cut("phase0")
		overlay.set_tool_enabled(false)
		await _still("off")
		_check(check_only or before == Fixture.signature(board), "On/off captures have identical source pixels and placement")
		# The cut-out follows live poses: repeat the pixel rule at later idle phases.
		overlay.set_tool_enabled(true)
		for phase: int in [1, 2]:
			scene.process_mode = Node.PROCESS_MODE_INHERIT
			for frame: int in range(PHASE_FRAMES): await process_frame
			scene.process_mode = Node.PROCESS_MODE_DISABLED
			overlay.sync_coverage()
			overlay._process(0.15)
			await _check_front_cut("phase%d" % phase)
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

func _fronts() -> Dictionary:
	var result: Dictionary = {}
	for key: String in overlay.get("entries"):
		var entry: Dictionary = overlay.get("entries")[key]
		if not (entry.get("front", []) as Array).is_empty(): result[key] = (entry["front"] as Array).map(func(front: Dictionary) -> String: return str(front["key"]))
	return result

func _grab() -> Image:
	await process_frame
	await RenderingServer.frame_post_draw
	return canvas.get_texture().get_image()

# Drawn alpha of a team ring over a known background, from the ring colours
# that may be present; unknown (ring colour ~ background) counts as ring.
static func _ring_alpha(with_ring: Color, without: Color, colors: Array) -> float:
	var best: float = 0.0
	for color: Color in colors:
		var spread: float = 0.0
		var alpha: float = 0.0
		for channel: int in range(3):
			var span: float = color[channel] - without[channel]
			if absf(span) > spread:
				spread = absf(span)
				alpha = (with_ring[channel] - without[channel]) / span
		best = maxf(best, alpha if spread > 0.1 else (1.0 if with_ring != without else 0.0))
	return best

static func _differs(a: Image, b: Image, x: int, y: int) -> bool:
	var p: Color = a.get_pixel(x, y)
	var q: Color = b.get_pixel(x, y)
	return maxf(maxf(absf(p.r - q.r), absf(p.g - q.g)), maxf(absf(p.b - q.b), absf(p.a - q.a))) > PIXEL_DIFF

# occ-01 rule on real captured pixels: an object rim never lands on an opaque
# pixel of a unit painted in front of the object, nor on that unit's team-rim
# ring, and is cut nowhere else. Object rim pixels = all rims vs object rims
# hidden; front rings = object rims hidden vs front units' rims hidden too;
# drawn front bodies = those vs the bodies hidden too. A ring pixel is one the
# ring paints at >= 10% alpha (solved against its known team colour). Opacity is
# read from each front unit's current texture and must land on its drawn body.
# 1 px slack beyond the ring (or the body, for a unit without one).
func _check_front_cut(label: String) -> void:
	if check_only: return
	var entries: Dictionary = overlay.get("entries")
	var team: Dictionary = overlay.get("team").get("entries")
	var bodies: Dictionary = overlay.get("team").get("bodies")
	var objects: Array[Dictionary]
	var fronts: Dictionary = {}
	for key: String in entries:
		if str(entries[key]["source"]["kind"]) == "unit" or float(entries[key]["alpha"]) < 1.0: continue
		objects.append(entries[key])
		for front: Dictionary in entries[key]["front"]: fronts[str(front["key"])] = true
	var report: Dictionary = {"name": "front_cut_" + label, "hero_pose": board.call("protagonist_animation_snapshot"), "objects": {}}
	if objects.is_empty():
		samples.append(report)
		return
	var full: Image = await _grab()
	var again: Image = await _grab()
	for entry: Dictionary in objects: (entry["sprite"].material as ShaderMaterial).set_shader_parameter("front_count", 0)
	var uncut: Image = await _grab()
	for entry: Dictionary in objects: (entry["sprite"].material as ShaderMaterial).set_shader_parameter("front_count", (entry["front"] as Array).size())
	for entry: Dictionary in objects: (entry["sprite"] as Sprite2D).visible = false
	var no_objects: Image = await _grab()
	var hidden_nodes: Array[CanvasItem]
	for key: String in fronts:
		if team.has(key): hidden_nodes.append(team[key]["sprite"])
		if entries.has(key): hidden_nodes.append(entries[key]["sprite"])
	for node: CanvasItem in hidden_nodes: node.visible = false
	var no_rims: Image = await _grab()
	var body_nodes: Array[CanvasItem]
	for key: String in fronts:
		if bodies.has(key): body_nodes.append(bodies[key])
	for node: CanvasItem in body_nodes: node.visible = false
	var no_bodies: Image = await _grab()
	for node: CanvasItem in body_nodes: node.visible = true
	for node: CanvasItem in hidden_nodes: node.visible = true
	for entry: Dictionary in objects: (entry["sprite"] as Sprite2D).visible = true
	var folder: String = output.path_join("front_cut").path_join(label)
	DirAccess.make_dir_recursive_absolute(folder)
	for pair: Array in [["full", full], ["uncut", uncut], ["no_object_rims", no_objects], ["no_front_rims", no_rims], ["no_front_bodies", no_bodies]]:
		(pair[1] as Image).save_png(folder.path_join(str(pair[0]) + ".png"))
	var to_canvas: Transform2D = board.get_global_transform_with_canvas()
	for entry: Dictionary in objects:
		var source: Dictionary = entry["source"]
		var drawn: Rect2 = Sources.drawing(board, source)["rect"]
		var area: Rect2i = Rect2i(to_canvas * drawn.grow(8.0 * float(board.get("_navigation_zoom")))).intersection(Rect2i(Vector2i.ZERO, full.get_size()))
		var width: int = area.size.x
		var body := PackedByteArray()
		body.resize(area.get_area())
		var ring := PackedByteArray()
		ring.resize(area.get_area())
		var colors: Array = []
		for front: Dictionary in entry["front"]: colors.append(Team.color_for(front["data"]))
		for y: int in range(area.size.y):
			for x: int in range(width):
				body[y * width + x] = 1 if _differs(no_rims, no_bodies, area.position.x + x, area.position.y + y) else 0
				var at := Vector2i(area.position.x + x, area.position.y + y)
				ring[y * width + x] = 1 if _ring_alpha(no_objects.get_pixelv(at), no_rims.get_pixelv(at), colors) >= RING_VISIBLE else 0
		var opaque := PackedByteArray()
		opaque.resize(area.get_area())
		var from_canvas: Transform2D = to_canvas.affine_inverse()
		var layers: Array = []
		for front: Dictionary in entry["front"]:
			var live: Dictionary = Sources.drawing(board, front)
			layers.append([(live["texture"] as Texture2D).get_image(), live["rect"]])
		for y: int in range(area.size.y):
			for x: int in range(width):
				var point: Vector2 = from_canvas * (Vector2(area.position + Vector2i(x, y)) + Vector2(0.5, 0.5))
				for layer: Array in layers:
					var image: Image = layer[0]
					var uv: Vector2 = (point - (layer[1] as Rect2).position) / (layer[1] as Rect2).size
					if uv.x < 0.0 or uv.y < 0.0 or uv.x >= 1.0 or uv.y >= 1.0: continue
					if image.get_pixelv(Vector2i(uv * Vector2(image.get_size()))).a >= OPAQUE: opaque[y * width + x] = 1
		var counts: Dictionary = {"rim": 0, "uncut_rim": 0, "cut_away": 0, "front_body": 0, "front_ring": 0, "opaque": 0, "noise": 0, "rim_on_front": 0, "opaque_not_drawn": 0, "cut_off_front": 0}
		for y: int in range(1, area.size.y - 1):
			for x: int in range(1, width - 1):
				var px: int = area.position.x + x
				var py: int = area.position.y + y
				var inside: bool = true
				var near: bool = false
				var near_body: bool = false
				for dy: int in [-1, 0, 1]:
					for dx: int in [-1, 0, 1]:
						var at: int = (y + dy) * width + x + dx
						inside = inside and (opaque[at] == 1 or ring[at] == 1)
						near = near or body[at] == 1 or ring[at] == 1
						near_body = near_body or body[at] == 1
				if ring[y * width + x] == 1: counts["front_ring"] += 1
				if opaque[y * width + x] == 1:
					counts["opaque"] += 1
					if not near_body: counts["opaque_not_drawn"] += 1
				var rim: bool = _differs(full, no_objects, px, py)
				var was_rim: bool = _differs(uncut, no_objects, px, py)
				if _differs(full, again, px, py): counts["noise"] += 1
				if body[y * width + x] == 1: counts["front_body"] += 1
				if rim: counts["rim"] += 1
				if was_rim: counts["uncut_rim"] += 1
				if was_rim and not rim:
					counts["cut_away"] += 1
					if not near: counts["cut_off_front"] += 1
				if rim and inside: counts["rim_on_front"] += 1
		report["objects"][str(source["key"])] = counts
		var name: String = label + " " + str(source["key"])
		_check(counts["noise"] == 0, "Repeat grabs are pixel-identical: " + name)
		_check(counts["rim"] > 0 and counts["uncut_rim"] > counts["rim"], "Object rim stays on exposed edges and is cut by its front unit: " + name)
		_check(counts["opaque"] > 0 and counts["opaque_not_drawn"] == 0, "Front unit opacity maps onto its drawn body: " + name)
		_check(counts["rim_on_front"] == 0, "No object rim pixel on a front unit's opaque body or team ring: " + name)
		_check(counts["cut_off_front"] == 0, "Rim is cut only where a front unit or its ring is drawn (1 px): " + name)
		print("OCC01 FRONT CUT %s: %s" % [name, JSON.stringify(counts)])
	samples.append(report)


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
