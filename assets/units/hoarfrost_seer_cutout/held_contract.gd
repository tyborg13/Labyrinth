extends RefCounted

## rr-58: original composites remain the exact in-hand presentation cache.
## Release changes paint only. Sprite offsets accommodate a larger source crop
## without moving a bone/node, changing its snapped transform, or moving paint.
static func apply(rig: Node2D, clip: String, phase: float) -> void:
	for part: Dictionary in rig.layout["parts"]:
		var variant: Dictionary = part.get("release_texture", {})
		if variant.is_empty(): continue
		var released: bool = phase >= float(variant.get("release_at", {}).get(clip, INF))
		var checks: bool = rig.get_meta("gait_proof_checks", false)
		var path: String = str(variant["mask" if checks else "file"]) if released else str(rig.layout["proof_layers"][part["name"]]["mask"] if checks else part["file"])
		var sprite: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"])) as Sprite2D
		sprite.texture = rig._texture(path)
		var shift: Array = variant.get("sprite_offset", [0, 0])
		sprite.offset = Vector2(float(shift[0]), float(shift[1])) if released else Vector2.ZERO
