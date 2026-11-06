extends SceneTree

## Count-based regression guard on production RunScene submissions. No sleeps,
## wall-clock thresholds or renderer claims. Endpoint ramps are explicitly
## exempt from the cruise-speed floor, but never from the stationary guard.
const Scene = preload("sampling_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Timing = preload("res://scripts/maquette_cutout_runtime/playback_timing.gd")
const PathMovement = preload("res://scripts/maquette_cutout_runtime/path_movement.gd")
const Depth = preload("res://scripts/maquette_cutout_runtime/board_depth.gd")
const Fixture = preload("res://tests/maquette_cutout/runtime_suite.gd")
const PROOF_SIZE := Vector2(1920, 1080)
const GUARD_RATIO: float = 0.60
const POSITION_EPSILON: float = 0.0001
const ROOT_ALIGNMENT_EPSILON: float = 0.001
const PROFILE_DERIVATIVE_STEP: float = 0.00001
const CANVAS_SAMPLE_COUNT: int = 12
const SKIP_TEST_STRIDE: int = 11
const PROOF_DIRECTIONS := [Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT, Vector2i.UP,
	Vector2i(1, 1), Vector2i(-1, -1), Vector2i(1, -1), Vector2i(-1, 1)]
const EXPECTED_TILE_SECONDS := {"ember_tick": 0.20, "ember_hoarder": 0.20, "lightning_wisp": 0.22,
	"arc_thrall": 0.24, "burrow_grub": 0.26, "hoarfrost_seer": 0.26, "bile_bloomer": 0.28}
var checks: int = 0
var errors: Array[String]
var report: Dictionary = {"roster": [], "speed_rows": {}, "errors": []}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var board := Board.new()
	board.size = PROOF_SIZE
	var scene := Scene.new()
	scene.board_view = board
	scene._combat_pacing.enemies_active = true
	var baseline_only: bool = OS.get_cmdline_user_args().has("--authored-baseline")
	var types: Array[String]
	types.assign(Action.Presentation.CREATURES.keys())
	# Shrike's dedicated adapter also names its traveling clip move. Older
	# cutouts name theirs walk and are covered by the preservation controls.
	types.append("gust_shrike")
	for type: String in types:
		if type != "gust_shrike" and not Action.data_for(type).get("clips", {}).has("move"): continue
		var state: Dictionary = Fixture.fixture(type)
		var unit: Dictionary = state["enemies"][0].duplicate(true)
		unit["key"] = "enemy_1"
		var path: Array[Vector2i]
		path.assign([unit["pos"], unit["pos"] + Vector2i.RIGHT, unit["pos"] + Vector2i.RIGHT * 2, unit["pos"] + Vector2i.RIGHT * 3])
		var start: Vector2 = board.world_position_for_unit_origin(unit, path[0])
		var step: Vector2 = board.world_position_for_unit_origin(unit, path[1]) - start
		scene.submissions.clear()
		scene.scheduled.clear()
		await scene._animate_actor_along_path(state, "enemy_1", path, {})
		var after: Dictionary = _speeds(scene.submissions, start, step)
		var before: Dictionary = _speeds(_authored(type, start, step), start, step) if Action.handles(type) else after
		var measured: Dictionary = before if baseline_only else after
		_expect(int(measured["slow_cruise_frames"]) == 0, type + ": no cruise frame below 60% of median distance")
		_expect(int(measured["stationary_frames"]) == 0, type + ": no stationary frame inside the path")
		_expect(scene._sfx_router.arrivals == 3, type + ": three walk sound arrivals")
		_expect((scene.submissions[-1]["unit_world_positions"]["enemy_1"] as Vector2).distance_to(start + step * 3) < POSITION_EPSILON, type + ": exact endpoint")
		var schedule: Dictionary = scene.scheduled[0]
		var data: Dictionary = Action.data_for(type)
		var tile_phase_unchanged: bool = true
		var count: int = int(schedule["frames"]) / 3
		for index: int in range(scene.submissions.size()):
			tile_phase_unchanged = tile_phase_unchanged and is_equal_approx(scene.submissions[index][type + "_motion"]["enemy_1"]["phase"], float(index % count + 1) / count)
		_expect(tile_phase_unchanged, type + ": limb/lift phase keeps one unchanged authored cycle per tile")
		if Timing.uses_continuous_root(data):
			# walk-01 gives reviewed humanoids their authored tile clock even
			# when a remaining root track still needs continuous interpolation.
			var authored_humanoid: bool = Timing.uses_parity(data) and Timing.AUTHORED_HUMANOID_TILE_TYPES.has(type)
			var expected_seconds: float = float(data["clips"]["move"]["seconds"]) if authored_humanoid else float(EXPECTED_TILE_SECONDS[type])
			_expect(is_equal_approx(float(schedule["frame_seconds"]) * schedule["frames"] / 3.0, expected_seconds), type + (": authored humanoid tile clock" if authored_humanoid else ": director tile clock"))
		else:
			_expect(not scene.submissions[0][type + "_motion"]["enemy_1"].has("root_forward_override"), type + ": linear rig unchanged")
		if type in ["ember_tick", "burrow_grub"]:
			report["speed_rows"][type] = {"before": before, "after": after,
				"before_seconds": 3 * Action.frames_for(type, "move") * roundi(1000000.0 / Action.FPS) / 1000000.0,
				"after_seconds": schedule["seconds"], "tile_pixels": step.length()}
		if type == "ember_tick":
			_expect(int(before["slow_cruise_frames"]) > 0 and int(before["stationary_frames"]) > 0, "negative control: today's Tick curve fails the guard")
		if not baseline_only:
			_check_depth(board, unit, scene.submissions, type)
			if Timing.uses_continuous_root(data): await _check_canvas(type, scene.submissions, board.source_pixel_scale_for_type(type))
		report["roster"].append({"type": type, "frames": schedule["frames"], "cruise_slow": measured["slow_cruise_frames"], "stationary": measured["stationary_frames"]})
	if not baseline_only:
		_check_profiles()
		await _check_controls(scene, board)
		_check_older_variants()
		await _check_directions(scene, board)
	report["errors"] = errors
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--output"):
		FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	scene.board_view = null
	scene._combat_pacing.free()
	scene.free()
	board.free()
	for error: String in errors: printerr(error)
	print("MV01 PATH MOVEMENT: %s (%d types; %d checks; %d failures; authored_baseline=%s; headless counts only)" % ["PASS" if errors.is_empty() else "FAIL", report["roster"].size(), checks, errors.size(), str(baseline_only)])
	quit(0 if errors.is_empty() else 1)

func _authored(type: String, start: Vector2, step: Vector2) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var count: int = Action.frames_for(type, "move")
	for tile: int in range(3):
		for frame: int in range(1, count + 1):
			var phase: float = float(frame) / count
			var shown: Dictionary = {"unit_footprint_world_positions": {"enemy_1": start + step * (tile + phase)}}
			Action.movement_frame(shown, type, "enemy_1", start + step * tile, start + step * (tile + 1), Vector2i.RIGHT, phase, false)
			result.append(shown)
	return result

func _speeds(frames: Array[Dictionary], start: Vector2, step: Vector2) -> Dictionary:
	var distances: Array[float]
	var floor_distances: Array[float]
	var previous: Vector2 = start
	var previous_ground: Vector2 = start
	var progress: Array[float]
	for shown: Dictionary in frames:
		var body: Vector2 = shown["unit_world_positions"]["enemy_1"]
		var ground: Vector2 = shown["unit_footprint_world_positions"]["enemy_1"]
		distances.append(previous.distance_to(body) / step.length())
		floor_distances.append((body - previous).dot(step.normalized()) / step.length())
		progress.append((previous_ground - start).dot(step) / step.length_squared())
		previous = body
		previous_ground = ground
	var ordered: Array[float] = distances.duplicate()
	ordered.sort()
	var median: float = ordered[ordered.size() / 2]
	var slow: int = 0
	var stationary: int = 0
	for index: int in range(distances.size()):
		if distances[index] <= POSITION_EPSILON / step.length(): stationary += 1
		# The explicitly designed first/last quarter-tile acceleration ramps are
		# not cruise frames. Interior tile boundaries are always covered.
		if progress[index] >= PathMovement.RAMP_TILES and progress[index] <= 3.0 - PathMovement.RAMP_TILES and distances[index] < GUARD_RATIO * median: slow += 1
	return {"body_tiles_per_frame": distances, "path_projected_tiles_per_frame": floor_distances,
		"median": median, "slow_cruise_frames": slow, "stationary_frames": stationary}

func _check_depth(board: Control, unit: Dictionary, frames: Array[Dictionary], type: String) -> void:
	if not Timing.uses_continuous_root(Action.data_for(type)): return
	var maximum: float = 0.0
	for shown: Dictionary in frames:
		maximum = maxf(maximum, Depth.position(board, unit, shown).distance_to(shown["unit_footprint_world_positions"]["enemy_1"]))
	_expect(maximum < POSITION_EPSILON, type + ": board depth follows overridden ground root")

func _check_canvas(type: String, frames: Array[Dictionary], scale: float) -> void:
	var renderer: Node = Action.Presentation.renderer_script(type).new()
	root.add_child(renderer)
	renderer.set_process(false)
	var maximum: float = 0.0
	for index: int in range(0, frames.size(), maxi(1, frames.size() / CANVAS_SAMPLE_COUNT)):
		var shown: Dictionary = frames[index]
		var motion: Dictionary = shown[type + "_motion"]["enemy_1"].duplicate(false)
		motion["screen_pixel_scale"] = scale
		renderer.present(motion, false)
		var rig: Node2D = renderer.rigs[renderer.facing]
		var bind: Vector2 = Action.Motion.point(rig.layout["joints"]["root"]["position"])
		var offset: Vector2 = ((rig.bones["root"] as Bone2D).position - bind) * scale
		if renderer.mirrored: offset.x = -offset.x
		var actual: Vector2 = shown["unit_texture_origins"]["enemy_1"] + offset
		maximum = maxf(maximum, actual.distance_to(shown["unit_world_positions"]["enemy_1"]))
	_expect(maximum < ROOT_ALIGNMENT_EPSILON, type + ": live Bone2D root agrees with world/HUD/shadow position (%.6fpx)" % maximum)
	# Even a stale movement field must have no effect on other clips.
	var motion: Dictionary = {"clip": "hit", "phase": 0.5, "screen_pixel_scale": scale}
	renderer.present(motion, false)
	var rig: Node2D = renderer.rigs[renderer.facing]
	var before: Dictionary = {}
	for bone: String in rig.bones: before[bone] = (rig.bones[bone] as Bone2D).transform
	motion["root_forward_override"] = frames[-1][type + "_motion"]["enemy_1"]["root_forward_override"]
	renderer.present(motion, false)
	var unchanged: bool = true
	for bone: String in rig.bones: unchanged = unchanged and before[bone] == (rig.bones[bone] as Bone2D).transform
	_expect(unchanged, type + ": non-move poses unchanged by travel field")
	renderer.reset_prepared_state()
	_expect(renderer.root_forward_override.is_empty(), type + ": prepared renderer clears path override")
	renderer.queue_free()
	await process_frame

func _check_profiles() -> void:
	for count: int in [1, 3]:
		var profile := PathMovement.new()
		var points: Array[Vector2]
		for index: int in range(count + 1): points.append(Vector2(index, 0))
		profile.configure(points)
		_expect(profile.distance_at(0.0) == 0.0 and is_equal_approx(profile.distance_at(1.0), count), "profile exact endpoints")
		var rise: float = 2.0 * profile.ramp_in / profile.speed
		_expect(profile.distance_at(PROFILE_DERIVATIVE_STEP) / PROFILE_DERIVATIVE_STEP < ROOT_ALIGNMENT_EPSILON, "profile starts at zero velocity")
		_expect((count - profile.distance_at(1.0 - PROFILE_DERIVATIVE_STEP)) / PROFILE_DERIVATIVE_STEP < ROOT_ALIGNMENT_EPSILON, "profile ends at zero velocity")
		_expect(is_equal_approx(profile.distance_at(rise), 0.25), "quadratic ramp covers first quarter tile")
		_expect(is_equal_approx(profile.distance_at(1.0 - rise), count - 0.25), "quadratic ramp covers last quarter tile")
		for join: float in [rise, 1.0 - rise]:
			var left: float = (profile.distance_at(join) - profile.distance_at(join - PROFILE_DERIVATIVE_STEP)) / PROFILE_DERIVATIVE_STEP
			var right: float = (profile.distance_at(join + PROFILE_DERIVATIVE_STEP) - profile.distance_at(join)) / PROFILE_DERIVATIVE_STEP
			_expect(absf(left - right) < ROOT_ALIGNMENT_EPSILON, "profile velocity continuous at ramp/cruise join")

func _check_controls(scene: Control, board: Control) -> void:
	var state: Dictionary = Fixture.fixture("ember_tick")
	var start: Vector2i = state["enemies"][0]["pos"]
	var path: Array[Vector2i]
	path.assign([start, start + Vector2i.RIGHT, start + Vector2i.RIGHT + Vector2i.DOWN, start + Vector2i.RIGHT * 2 + Vector2i.DOWN])
	scene.submissions.clear()
	await scene._animate_actor_along_path(state, "enemy_1", path, {})
	var facing_unchanged: bool = true
	var count: int = Action.frames_for("ember_tick", "move")
	for index: int in range(scene.submissions.size()):
		var tile: int = index / count
		facing_unchanged = facing_unchanged and scene.submissions[index]["ember_tick_motion"]["enemy_1"]["direction"] == path[tile + 1] - path[tile]
	_expect(facing_unchanged, "corner facing changes keep the authored tile clock")
	var ground_distances: Array[float]
	var previous: Vector2 = board.world_position_for_unit_origin(state["enemies"][0], start)
	for shown: Dictionary in scene.submissions:
		var current: Vector2 = shown["unit_footprint_world_positions"]["enemy_1"]
		ground_distances.append(previous.distance_to(current))
		previous = current
	var interior: Array[float] = ground_distances.slice(ground_distances.size() / 3, ground_distances.size() * 2 / 3)
	_expect(interior.min() >= float(interior.max()) * GUARD_RATIO, "turning path keeps corner speed")
	_expect(scene._sfx_router.arrivals == 3, "corner sounds still tick per tile")
	scene.stride = SKIP_TEST_STRIDE
	scene.submissions.clear()
	await scene._animate_actor_along_path(state, "enemy_1", path, {})
	_expect(scene._sfx_router.arrivals == 3, "skipped frames retain all sound ticks")
	_expect(scene.submissions[-1]["unit_world_positions"]["enemy_1"] == previous, "skipped frames land on exact endpoint")
	scene.stride = 1
	scene.reduced = true
	scene.submissions.clear()
	scene.scheduled.clear()
	await scene._animate_actor_along_path(state, "enemy_1", path, {})
	_expect(not scene.submissions[0].has("unit_texture_origins") and not scene.submissions[0]["ember_tick_motion"]["enemy_1"].has("root_forward_override"), "reduced motion retains still art and interpolated travel")
	_expect(is_equal_approx(scene.scheduled[0]["frame_seconds"], 1.0 / Action.FPS), "reduced creature travel keeps its authored clock")
	var counts: Array[int]
	counts.assign([Action.frames_for("hoarfrost_seer", "move")])
	_expect(is_equal_approx(Timing.movement_frame_seconds(Action.data_for("hoarfrost_seer"), scene._combat_pacing, "enemy_1", counts, 1.0 / Action.FPS, true), scene._combat_pacing.walk_frame_seconds("enemy_1", counts, 1.0 / Action.FPS)), "reduced Seer travel keeps its existing parity clock")
	scene.reduced = false
	scene._combat_pacing.enemies_active = false
	scene.scheduled.clear()
	await scene._animate_actor_along_path(state, "enemy_1", path, {})
	_expect(is_equal_approx(scene.scheduled[0]["frame_seconds"], 1.0 / Action.FPS), "tile clock applies only during enemy phases")
	state = Fixture.fixture("ash_hound")
	scene._combat_pacing.enemies_active = true
	for key: String in ["enemy_1", "player"]:
		scene.submissions.clear()
		await scene._animate_actor_along_path(state, key, path, {})
		_expect(not scene.submissions[0].has("unit_texture_origins"), key + ": legacy/hero travel receives no maquette root override")

func _check_older_variants() -> void:
	for type: String in ["hoarfrost_seer", "arc_thrall"]:
		var data: Dictionary = Action.Motion.data_for({"motion_data": "res://assets/units/" + type + "_cutout/compiled_motion.json"})
		_expect(Timing.uses_continuous_root(data), type + ": legacy compiled variant also receives nonlinear-root policy")
		var counts: Array[int]
		counts.assign([roundi(float(data["clips"]["move"]["seconds"]) * Action.FPS)])
		var pacing := Node.new()
		pacing.set_script(preload("res://scripts/combat_pacing.gd"))
		pacing.enemies_active = true
		_expect(is_equal_approx(Timing.movement_frame_seconds(data, pacing, "enemy_1", counts, 1.0 / Action.FPS) * counts[0], EXPECTED_TILE_SECONDS[type]), type + ": legacy variant tile clock")
		pacing.free()
		for facing: String in ["front", "rear"]:
			# Historical layouts include mesh parts no longer supported by the
			# generic sprite presenter. Exercise their protected compiled sampler
			# directly; live adapters above cover the production v2 canvas.
			var layout: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/units/" + type + "_cutout/" + facing + ".json"))
			layout["motion_data"] = "res://assets/units/" + type + "_cutout/compiled_motion.json"
			layout["screen_pixel_scale"] = 1.0
			layout["step_distance_px"] = 1.0
			layout["root_forward_override"] = {"forward_px": 0.5, "axis": Vector2.RIGHT}
			var pose: Dictionary = Action.Motion.sample_pose("move", 0.5, layout, facing)
			var values: Dictionary = Action.Motion.channels_at(data, "move", 0.5, facing, 1.0)
			var expected: Vector2 = Action.Motion.point(layout["joints"]["root"]["position"]) + Vector2(0.5, -float(values.get("root", {}).get("lift_px", 0.0)))
			_expect((pose["root"]["position"] as Vector2).distance_to(expected) < ROOT_ALIGNMENT_EPSILON, type + ": legacy " + facing + " sampler root override")

func _check_directions(scene: Control, board: Control) -> void:
	scene._combat_pacing.enemies_active = true
	for type: String in ["ember_tick", "burrow_grub", "hoarfrost_seer"]:
		var state: Dictionary = Fixture.fixture(type)
		var start: Vector2i = state["enemies"][0]["pos"]
		for direction: Vector2i in PROOF_DIRECTIONS:
			var path: Array[Vector2i]
			path.assign([start, start + direction])
			scene.submissions.clear()
			await scene._animate_actor_along_path(state, "enemy_1", path, {})
			await _check_canvas(type, scene.submissions, board.source_pixel_scale_for_type(type))
			_check_depth(board, {"type": type, "key": "enemy_1", "pos": start}, scene.submissions, type)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: errors.append(message)
