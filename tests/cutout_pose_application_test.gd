extends SceneTree
## Compare composed runtime bone transforms with the original Node2D setter
## sequence across production samplers, facings, and authored action families.
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GuardianRenderer = preload("res://scripts/guardian_cutout/renderer.gd")
const RIG_IDS = ["protagonist", "crawler", "stone_warden", "acolyte", "bile_bloomer", "chainbound_gaoler", "cinder_droplet", "cinder_ooze", "frostglass_lancer", "grave_surgeon", "harrier", "iskaldra", "noctyrax", "tharokh", "vaeloryx", "veilbound_acolyte", "vyraketh", "zekarion"]
const CLIPS = ["rest", "idle", "walk", "attack", "lunge", "coil", "strike", "cast", "brace", "thrust", "mark", "burst", "claw", "breath", "eclipse", "faultline", "talon", "lance", "storm", "mantle", "dive", "guard", "maw", "bite", "spit"]
var _errors: Array[String] = []
var _poses: int = 0
var _bone_samples: int = 0
var _nonidentical: int = 0
var _max_error: float = 0.0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var cases: Dictionary = {}
	for actor: String in RIG_IDS: cases[actor] = actor
	for actor: String in GuardianRenderer.ACTOR_IDS: cases[actor] = "guardian"
	var reference := Bone2D.new()
	for actor: String in cases:
		var rig_script: Script = load("res://scripts/%s_cutout/rig.gd" % cases[actor])
		var motion: Script = load("res://scripts/%s_cutout/motion.gd" % cases[actor])
		for facing: String in ["front", "rear"]:
			var rig: Node2D = rig_script.new()
			rig.set("facing", facing)
			if cases[actor] == "guardian": rig.set("character_id", actor)
			root.add_child(rig)
			_check(rig.call("load_rig"), actor + " loads " + facing)
			for clip: String in CLIPS:
				for frame: int in range(8):
					var phase: float = float(frame) / 7.0
					var pose: Dictionary = motion.call("sample_pose", clip, phase, rig.get("layout"), facing)
					rig.call("apply_pose", clip, phase)
					_poses += 1
					for name: String in rig.get("bones"):
						var bone: Bone2D = rig.get("bones")[name]
						var override: Dictionary = pose.get(name, {})
						reference.transform = rig.get("rest_transforms")[name]
						reference.position = override.get("position", reference.position)
						reference.rotation = float(override.get("rotation", 0.0))
						reference.scale = override.get("scale", Vector2.ONE)
						reference.skew = float(override.get("skew", 0.0))
						if bone.transform != reference.transform:
							_nonidentical += 1
							_max_error = maxf(_max_error, maxf(bone.transform.x.distance_to(reference.transform.x), maxf(bone.transform.y.distance_to(reference.transform.y), bone.transform.origin.distance_to(reference.transform.origin))))
						_check(bone.transform.is_equal_approx(reference.transform), "%s/%s/%s/%d/%s preserves the original transform" % [actor, facing, clip, frame, name])
						if override.has("visible"):
							_check(bone.visible == bool(override["visible"]), actor + " preserves part visibility")
						_bone_samples += 1
			rig.free()
	reference.free()
	for error: String in _errors: push_error(error)
	print("CUTOUT POSE NUMERICS: %d nonidentical transforms, maximum component-vector error %.9f" % [_nonidentical, _max_error])
	print("CUTOUT POSE APPLICATION: %d poses, %d bone samples; %s" % [_poses, _bone_samples, "PASS" if _errors.is_empty() else "FAIL"])
	quit(0 if _errors.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	if not condition and _errors.size() < 30: _errors.append(message)
