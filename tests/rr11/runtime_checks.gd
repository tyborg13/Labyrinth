extends SceneTree

## Production adapters, rigid idle groups and contact selectors. No GUI proof.
const CASE: String = "res://experiments/cutouts/arc_thrall/rr11"
const FPS: int = 60
const EPSILON: float = 0.0001
const PROOF_IDLE_SEED: float = 0.37
const PROOF_ACTION_PHASE: float = 0.45
const FIXTURE_PELVIS_DIP_PX: float = 1.0
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Humanoid = preload("res://scripts/maquette_cutout_runtime/humanoid_motion.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)

func _run() -> void:
	var renderer := preload("res://assets/units/arc_thrall_cutout/renderer.gd").new()
	renderer.seed_idle_phase(PROOF_IDLE_SEED)
	root.add_child(renderer)
	check(renderer.rigs.size() == 2, "both production views load")
	check(is_equal_approx(float(renderer.snapshot()["phase"]), PROOF_IDLE_SEED), "per-actor idle seed retained")
	check(Action.data_for("arc_thrall")["rig"] == "humanoid_v2", "contact selector reads the v2 data")
	check(Action.clip_for({"intent_id": "tether", "kind": "tether_beam"}, {"type": "arc_thrall"}) == "tether", "tether selector")
	check(Action.clip_for({"intent_id": "arc_jab", "kind": "move_toward"}, {"type": "arc_thrall"}) == "move", "arc_jab movement selector")
	check(Action.clip_for({"intent_id": "arc_jab", "kind": "melee"}, {"type": "arc_thrall"}) == "jab", "arc_jab contact selector")
	renderer.present({"clip": "jab", "phase": PROOF_ACTION_PHASE}, false)
	check(renderer.snapshot()["clip"] == "jab", "production action routes")
	var portrait: AtlasTexture = preload("res://scripts/maquette_cutout_runtime/portrait.gd").source_texture(renderer, "arc_thrall")
	check(portrait.atlas == renderer.texture(), "portrait uses live production texture")
	check(portrait.region == Rect2(128,128,255,255), "portrait registration retained")
	check(Presentation.asset_directory("arc_thrall").ends_with("humanoid_v2"), "pre-battle/rest registration uses v2")
	var anatomy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CASE.path_join("anatomy.json")))
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		check(rig.base_path().ends_with("humanoid_v2"), "production-only closure: " + view)
		check(not rig.bones.has("hand_near") and not rig.bones.has("club"), "tube has no hand or club")
		check(rig.bones.has("tube_tip"), "tube cap is an IK target")
		var visible_meshes: int = 0
		for mesh: Dictionary in rig.layout["joint_meshes"]:
			if not mesh.get("hidden_material", false): visible_meshes += 1
		check(visible_meshes == 4, "four complete skinned surfaces")
		var source: Transform2D = rig.global_transform.affine_inverse()
		var count: int = roundi(float(renderer.motion_data()["clips"]["idle"]["seconds"]) * FPS)
		for frame: int in range(count):
			rig.apply_pose("idle", float(frame) / count)
			for group: String in anatomy["idle_groups"]:
				var definition: Dictionary = anatomy["idle_groups"][group]
				var offsets: Array[Vector2]
				for name: String in definition["bones"]:
					var pose: Transform2D = source * rig.bones[name].global_transform
					var bind: Vector2 = Motion.point(rig.layout["joints"][name]["position"])
					var delta: Vector2 = pose.origin - bind
					check(pose.x.distance_to(Vector2.RIGHT) < EPSILON and pose.y.distance_to(Vector2.DOWN) < EPSILON, "idle basis rigid: " + name)
					check(delta.distance_to(delta.round()) < EPSILON, "idle whole-pixel offsets")
					if not offsets.is_empty(): check(delta.distance_to(offsets[0]) < EPSILON, "idle group is rigid: " + group)
					if definition["stationary"]: check(delta.length() < EPSILON, "idle lower body planted")
					offsets.append(delta)
		# Case-owned unkeyed supports must plant under a reachable pelvis dip.
		# This diagnostic modifies a copy, never the protected director data.
		var layout: Dictionary = rig.layout.duplicate(true)
		var data: Dictionary = renderer.motion_data().duplicate(true)
		var fixture_tracks: Array[Dictionary]
		fixture_tracks.assign([{"bone": "pelvis", "channel": "lift_px", "forward_mode": "pixels", "keys": [{"at": 0.0, "value": -FIXTURE_PELVIS_DIP_PX}]}])
		data["view_tracks"][view]["hit"] = fixture_tracks
		var planted: Dictionary = Humanoid.world_transforms(data, "hit", 0.0, layout, view)
		for side: String in ["near", "far"]:
			var foot: String = "foot_" + side
			var expected: Vector2 = Motion.point(layout["joints"][foot]["position"])
			if foot not in layout["planted_bones"]: expected += Vector2(0.0, FIXTURE_PELVIS_DIP_PX)
			check((planted[foot] as Transform2D).origin.distance_to(expected) < EPSILON, "declared supports plant while other feet follow the body")
	renderer.free()
	for failure: String in failures: push_error(failure)
	print("RR11 RUNTIME: %s (%d checks; headless logic only)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
