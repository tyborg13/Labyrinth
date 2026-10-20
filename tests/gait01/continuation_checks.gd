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
			for clip: String in ["rest"] + Motion.data_for(rig.layout)["clips"].keys():
				rig.apply_pose(clip, PROOF_MOVE_PHASE if clip == "move" else PROOF_NON_MOVE_PHASE)
				for part: Dictionary in rig.layout["parts"]:
					var recipe: Dictionary = rig.layout["gait_continuations"].get(part["name"], {})
					var active: bool = false
					if not recipe.is_empty(): active = (recipe["clips"] as Array).has(clip) if recipe.has("clips") else clip == "move"
					var expected: Image = rig._texture(part["file"]).get_image().duplicate()
					if active:
						var donor_part: Dictionary = {}
						for item: Dictionary in rig.layout["parts"]:
							if item["name"] == recipe["donor"]: donor_part = item
						var donor: Image = rig._texture(donor_part["file"]).get_image()
						for texel: Array in recipe["texels"]:
							checks += 1
							expected.set_pixel(int(texel[0]), int(texel[1]), donor.get_pixel(int(texel[2]), int(texel[3])))
					checks += 1
					var actual: PackedByteArray = (node_for(rig, part).get("texture") as Texture2D).get_image().get_data()
					if actual != (expected.get_data() if active else originals[part["name"]]):
						failures.append("Clip texture differs: " + clip + "/" + part["name"])
			rig.free()
	for failure: String in failures: push_error(failure)
	print("GAIT CONTINUATION TEXTURES: %s (%d own-edge/clip-selection checks; case and production)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
