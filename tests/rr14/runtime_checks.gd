extends SceneTree

## Diagnostic source-space lengths/targets; no renderer or window server.
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const EPSILON: float = 0.0001
const FIXTURE_LENGTH_PX: float = 5.0
const FIXTURE_PELVIS_DIP_PX: float = 2.0
const FIXTURE_SWING_LIFT_PX: float = 4.0
const FIXTURE_SWING_CARRY_PX: float = 2.0
const FIXTURE_UNREACHABLE_LIFT_PX: float = -20.0
const PROOF_FPS: int = 60
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var directory: String = args[args.find("--case") + 1]
	var rig := Rig.new()
	rig.case_directory = directory
	root.add_child(rig)
	check(rig.load_rig(), "synthetic anatomy loads: " + str(rig.load_errors))
	var layout: Dictionary = rig.layout
	check(not layout["joints"].has("hand_near"), "tube arm has no near hand")
	check(not layout["joints"].has("hem_near"), "visible legs have no hem")
	check(rig.get_node_or_null("loincloth") != null, "loincloth is a skinned mesh")
	for phase: float in [0.0, 0.5, 1.0]:
		rig.apply_authored_pose("move", phase)
		for name: String in rig.bones:
			check((rig.bones[name] as Bone2D).global_transform.is_finite(), "finite synthetic bone: " + name)
		rig.apply_pose("move", phase)
	for side: String in ["near", "far"]:
		var stance: Dictionary = pose(layout, side, FIXTURE_PELVIS_DIP_PX, 0.0)
		var swing: Dictionary = pose(layout, side, FIXTURE_PELVIS_DIP_PX + FIXTURE_SWING_LIFT_PX, FIXTURE_SWING_CARRY_PX)
		var unreachable: Dictionary = pose(layout, side, FIXTURE_UNREACHABLE_LIFT_PX, 0.0)
		var ankle: Vector2 = Motion.point(layout["joints"]["foot_" + side]["position"])
		check((stance["foot_" + side] as Transform2D).origin.distance_to(ankle) < EPSILON, "stance planted ankle: " + side)
		check((swing["foot_" + side] as Transform2D).origin.distance_to(ankle + Vector2(FIXTURE_SWING_CARRY_PX, -FIXTURE_SWING_LIFT_PX)) < EPSILON, "swing lifted and carried: " + side)
		var stance_bend: float = verify_chain(layout, stance, side)
		var swing_bend: float = verify_chain(layout, swing, side)
		verify_chain(layout, unreachable, side, false)
		var rest_a: Vector2 = Motion.point(layout["joints"]["thigh_" + side]["position"])
		var rest_b: Vector2 = Motion.point(layout["joints"]["shin_" + side]["position"])
		var rest_c: Vector2 = Motion.point(layout["joints"]["foot_" + side]["position"])
		var rest_bend: float = absf((rest_b - rest_a).angle_to(rest_c - rest_b))
		check(stance_bend > rest_bend, "pelvis dip flexes stance knee: " + side)
		check(swing_bend > stance_bend, "swing knee bends more than stance: " + side)
		check((unreachable["foot_" + side] as Transform2D).origin.distance_to((unreachable["thigh_" + side] as Transform2D).origin) <= 2.0 * FIXTURE_LENGTH_PX + EPSILON, "unreachable target clamps without stretching: " + side)
	# A robe foot remains FK even when it has translation keys.
	var robe: Dictionary = layout.duplicate(true)
	robe["joints"]["hem_near"] = {"position": [20, 28], "parent": "root"}
	robe["joints"]["foot_near"]["parent"] = "hem_near"
	var robe_pose: Dictionary = pose(robe, "near", 2.0, 0.0)
	check(is_zero_approx((robe_pose["shin_near"] as Transform2D).get_rotation()), "robe feet do not invoke leg IK")
	check((robe_pose["foot_near"] as Transform2D).origin.distance_to(Vector2(20, 26)) < EPSILON, "robe feet retain parent-relative FK lift")
	if args.has("--report"):
		write_samples(rig, directory, args[args.find("--report") + 1])
	for failure: String in failures: push_error(failure)
	print("RR14 RUNTIME: %s (%d checks; headless synthetic anatomy and foot IK)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	rig.free()
	quit(0 if failures.is_empty() else 1)

func pose(layout: Dictionary, side: String, lift: float, carry: float) -> Dictionary:
	var data: Dictionary = Motion.data_for(layout).duplicate(true)
	var tracks: Array[Dictionary]
	for row: Array in [["pelvis", "lift_px", -FIXTURE_PELVIS_DIP_PX], ["foot_" + side, "lift_px", lift], ["foot_" + side, "forward_px", carry]]:
		tracks.append({"bone": row[0], "channel": row[1], "forward_mode": "pixels", "keys": [{"at": 0.0, "value": row[2], "interpolation": "hold"}]})
	data["view_tracks"]["front"]["move"] = tracks
	return Humanoid.world_transforms(data, "move", 0.0, layout, "front")

func verify_chain(layout: Dictionary, world: Dictionary, side: String, bent: bool = true) -> float:
	var first: String = "thigh_" + side
	var second: String = "shin_" + side
	var target: String = "foot_" + side
	var a: Vector2 = (world[first] as Transform2D).origin
	var b: Vector2 = (world[second] as Transform2D).origin
	var c: Vector2 = (world[target] as Transform2D).origin
	check(absf(a.distance_to(b) - FIXTURE_LENGTH_PX) < EPSILON, "thigh length preserved: " + side)
	check(absf(b.distance_to(c) - FIXTURE_LENGTH_PX) < EPSILON, "shin length preserved: " + side)
	var ra: Vector2 = Motion.point(layout["joints"][first]["position"])
	var rb: Vector2 = Motion.point(layout["joints"][second]["position"])
	var rc: Vector2 = Motion.point(layout["joints"][target]["position"])
	check(((world[first] as Transform2D) * (rb - ra)).distance_to(b) < EPSILON, "thigh rotation follows solved knee: " + side)
	check(((world[second] as Transform2D) * (rc - rb)).distance_to(c) < EPSILON, "shin rotation follows solved ankle: " + side)
	if bent:
		check((c-a).cross(b-a) * (rc-ra).cross(rb-ra) > EPSILON, "rest knee bend side retained: " + side)
	return absf((b-a).angle_to(c-b))

func write_samples(rig: Node2D, directory: String, output: String) -> void:
	var data: Dictionary = Motion.data_for(rig.layout)
	var rows: Array[Dictionary]
	for clip: String in data["clips"]:
		var phases: Array[float]
		phases.assign([0.0, 1.0])
		for track: Dictionary in data["view_tracks"]["front"][clip]:
			for index: int in range(track["keys"].size()):
				var at: float = float(track["keys"][index]["at"])
				if not phases.has(at): phases.append(at)
				if index > 0:
					var middle: float = (at + float(track["keys"][index-1]["at"])) / 2.0
					if not phases.has(middle): phases.append(middle)
		phases.sort()
		for phase: float in phases:
			rig.apply_authored_pose(clip, phase)
			rows.append(sample_row(rig, clip, phase, -1, "authored"))
		var count: int = roundi(float(data["clips"][clip]["seconds"]) * PROOF_FPS)
		for frame: int in range(count):
			var phase: float = float(frame) / float(count)
			rig.apply_pose(clip, phase)
			rows.append(sample_row(rig, clip, phase, frame, "presented"))
	DirAccess.make_dir_recursive_absolute(output.get_base_dir())
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify({"ok": failures.is_empty(), "errors": failures,
		"samples": rows, "fps": PROOF_FPS, "step_distance_px": 0.0, "screen_pixel_scale": 1.0,
		"compiled_sha256": FileAccess.get_sha256(directory.path_join("compiled_motion.json")),
		"inputs": preload("res://tests/rr10/bindings.gd").for_case(directory)}))

func sample_row(rig: Node2D, clip: String, phase: float, frame: int, kind: String) -> Dictionary:
	var bones: Dictionary = {}
	var source: Transform2D = rig.global_transform.affine_inverse()
	for name: String in rig.bones:
		var bone: Bone2D = rig.bones[name]
		bones[name] = {"global": preload("res://tests/rr10/samples.gd").matrix(source * bone.global_transform),
			"local": preload("res://tests/rr10/samples.gd").matrix(bone.transform)}
	return {"view": "front", "clip": clip, "phase": phase, "frame": frame, "kind": kind, "bones": bones}
