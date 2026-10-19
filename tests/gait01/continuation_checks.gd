extends SceneTree

## Inspect the actual rig's texture selection/copies without renderer readback.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const PROOF_MOVE_PHASE: float = 0.22
const PROOF_NON_MOVE_PHASE: float = 0.37
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func node_for(rig: Node2D, part: Dictionary) -> Node2D:
	var mesh: Node2D = rig.get_node_or_null(NodePath(part["name"]))
	return mesh if mesh != null else rig.bones[part["bone"]].get_node(NodePath(part["name"]))

func _run() -> void:
	for production: bool in [false, true]:
		for view: String in ["front", "rear"]:
			var rig: Node2D = preload("res://assets/units/arc_thrall_cutout/rig.gd").new() if production else Rig.new()
			if not production: rig.case_directory = "res://experiments/cutouts/arc_thrall/rr11"
			rig.facing = view
			root.add_child(rig)
			if not rig.load_rig(): failures.append(str(rig.load_errors))
			var originals: Dictionary = {}
			for part: Dictionary in rig.layout["parts"]:
				originals[part["name"]] = (node_for(rig, part).get("texture") as Texture2D).get_image().get_data()
			rig.apply_pose("move", PROOF_MOVE_PHASE)
			for name: String in rig.layout["gait_continuations"]:
				var recipe: Dictionary = rig.layout["gait_continuations"][name]
				var parts: Dictionary = {}
				for part: Dictionary in rig.layout["parts"]: parts[part["name"]] = part
				var image: Image = (node_for(rig, parts[name]).get("texture") as Texture2D).get_image()
				var donor: Image = rig._texture(parts[recipe["donor"]]["file"]).get_image()
				for texel: Array in recipe["texels"]:
					checks += 1
					if image.get_pixel(int(texel[0]), int(texel[1])) != donor.get_pixel(int(texel[2]), int(texel[3])):
						failures.append("Own-edge copy differs: " + name)
			for clip: String in ["rest"] + Motion.data_for(rig.layout)["clips"].keys():
				if clip == "move": continue
				rig.apply_pose(clip, PROOF_NON_MOVE_PHASE)
				for part: Dictionary in rig.layout["parts"]:
					checks += 1
					if (node_for(rig, part).get("texture") as Texture2D).get_image().get_data() != originals[part["name"]]:
						failures.append("Non-move texture changed: " + clip + "/" + part["name"])
			rig.free()
	for failure: String in failures: push_error(failure)
	print("GAIT CONTINUATION TEXTURES: %s (%d own-edge/non-move checks; case and production)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
