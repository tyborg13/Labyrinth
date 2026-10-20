extends SceneTree

## Headless texture selection proof; renderer acceptance belongs to the director.
const Rig = preload("res://scripts/maquette_cutout_runtime/rig.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const PROOF_PHASE: float = 0.0
const CASES = {"hoarfrost_seer": "rr10", "hollow_mimic": "rr20"}
var errors: Array[String]
var checked: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for unit: String in CASES:
		for production: bool in [false, true]:
			for view: String in ["front", "rear"]:
				var rig: Node2D
				if production:
					rig = load("res://assets/units/%s_cutout/rig.gd" % unit).new()
				else:
					rig = Rig.new()
				rig.character_id = unit
				if not production:
					rig.case_directory = "res://experiments/cutouts/%s/%s" % [unit, CASES[unit]]
				rig.facing = view
				root.add_child(rig)
				if not rig.load_rig():
					errors.append("Cannot load rig: %s/%s/%s" % [unit, production, view])
					rig.free()
					continue
				var originals: Dictionary = {}
				for part: Dictionary in rig.layout["parts"]:
					originals[part["name"]] = rig._texture(part["file"]).get_image().duplicate()
				var data: Dictionary = Motion.data_for(rig.layout)
				var clips: Array[String]
				clips.assign(["rest"])
				for clip: String in data["clips"]: clips.append(clip)
				clips.append("idle") # Verify restoration after the final action too.
				for clip: String in clips:
					rig.apply_pose(clip, PROOF_PHASE)
					for name: String in rig.layout.get("gait_continuations", {}):
						var recipe: Dictionary = rig.layout["gait_continuations"][name]
						var expected: Image = originals[name].duplicate()
						if (recipe["clips"] as Array).has(clip):
							var donor: Image = originals[recipe["donor"]]
							for texel: Array in recipe["texels"]:
								expected.set_pixel(int(texel[0]), int(texel[1]), donor.get_pixel(int(texel[2]), int(texel[3])))
						var node: Node2D = rig.get_node_or_null(NodePath(name))
						if node == null:
							for part: Dictionary in rig.layout["parts"]:
								if part["name"] == name: node = rig.bones[part["bone"]].get_node(NodePath(name))
						var actual: Image = (node.get("texture") as Texture2D).get_image()
						if actual.get_data() != expected.get_data():
							errors.append("Texture differs: %s/%s/%s/%s/%s" % [unit, production, view, clip, name])
						checked += 1
				rig.free()
	for error: String in errors: push_error(error)
	print("RR28 RUNTIME CONTINUATION TEXTURES: %s (%d case/production clip-piece checks)" % ["PASS" if errors.is_empty() else "FAIL", checked])
	quit(0 if errors.is_empty() else 1)
