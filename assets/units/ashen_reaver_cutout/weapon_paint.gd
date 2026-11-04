extends RefCounted

## The old composites are exact held-presentation caches. At the existing
## release, the complete weapon and the donor-painted empty fist replace them.
## No extra node, clock, pose key, or runtime-wide policy is introduced.
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")

static func part_at(part: Dictionary, clip: String, phase: float) -> Dictionary:
	var variant: Dictionary = part.get("release_texture", {})
	if phase < float(variant.get("release_at", {}).get(clip, INF)): return part
	var active: Dictionary = part.duplicate()
	for key: String in ["file", "offset", "bbox"]: active[key] = variant[key]
	return active

static func apply(rig: Node2D, clip: String, phase: float, authored: bool = false) -> void:
	for part: Dictionary in rig.layout["parts"]:
		if not part.has("release_texture"): continue
		var active: Dictionary = part_at(part, clip, phase)
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Sprite2D
		var checks: bool = rig.get_meta("gait_proof_checks", false)
		var path: String = str(active["file"])
		if checks:
			path = str(part["release_texture"]["mask"] if active != part else rig.layout["proof_layers"][part["name"]]["mask"])
		sprite.texture = rig._texture(path)
		# The fist crops keep their original bounds. Only the weapon crop grows.
		if authored and part["name"] == "falchion":
			sprite.transform = Transform2D(0.0, Motion.point(active["offset"]) - Motion.point(rig.layout["joints"]["falchion"]["position"]))
