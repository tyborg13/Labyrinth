extends SceneTree

## Headless texture inspection of source and density-treated production rigs.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const PROOF_PHASE: float = 0.37
const PROOF_TRANSITION_PASSES: int = 2
var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func node_for(rig: Node2D, part: Dictionary) -> Node2D:
	var mesh: Node2D = rig.get_node_or_null(NodePath(part["name"]))
	return mesh if mesh != null else rig.bones[part["bone"]].get_node(NodePath(part["name"]))

func _run() -> void:
	for production: bool in [false, true]:
		for proof_checks: bool in [false, true]:
			for view: String in ["front", "rear"]:
				var rig: Node2D = preload("res://assets/units/briar_weaver_cutout/rig.gd").new() if production else Rig.new()
				if not production: rig.case_directory = "res://experiments/cutouts/briar_weaver/mq9"
				rig.facing = view
				root.add_child(rig)
				if not rig.load_rig(): failures.append(str(rig.load_errors))
				rig.set_meta("gait_proof_checks", proof_checks)
				var originals: Dictionary = {}
				for part: Dictionary in rig.layout["parts"]:
					originals[part["name"]] = (node_for(rig, part).get("texture") as Texture2D).get_image().duplicate()
				var clips: Array[String]
				clips.assign(Motion.data_for(rig.layout)["clips"].keys())
				clips.append("rest")
				# Revisit every texture after a different clip has populated it.
				for pass_index: int in range(PROOF_TRANSITION_PASSES):
					clips.reverse()
					for clip: String in clips:
						rig.apply_pose(clip, PROOF_PHASE)
						var recipes: Dictionary = rig.layout.get("gait_continuations", {}) if clip == "move" else rig.layout.get("clip_continuations", {}).get(clip, {})
						for part: Dictionary in rig.layout["parts"]:
							var expected: Image = originals[part["name"]].duplicate()
							if recipes.has(part["name"]):
								var recipe: Dictionary = recipes[part["name"]]
								var donor: Dictionary
								for candidate: Dictionary in rig.layout["parts"]:
									if candidate["name"] == recipe["donor"]: donor = candidate
								var paint: Image = rig._texture(donor["file"]).get_image()
								for texel: Array in recipe["texels"]:
									expected.set_pixel(int(texel[0]), int(texel[1]), Color.YELLOW if proof_checks else paint.get_pixel(int(texel[2]), int(texel[3])))
							checks += 1
							var actual: Image = (node_for(rig, part).get("texture") as Texture2D).get_image()
							if actual.get_data() != expected.get_data(): failures.append(view + "/" + clip + "/" + part["name"] + ": continuation selection/copy differs")
				rig.free()
	for failure: String in failures: push_error(failure)
	print("RR21 CONTINUATION TEXTURES: %s (%d full-image checks; source/production, paint/masks, both views, repeated transitions)" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)
