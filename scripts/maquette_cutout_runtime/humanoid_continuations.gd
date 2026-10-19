extends RefCounted

## Copy existing, density-treated edge texels only during gait playback. The
## unchanged skin field carries these hidden continuations along the segment.
static func apply(rig: Node2D, gait: bool) -> void:
	for name: String in rig.layout.get("gait_continuations", {}):
		var recipe: Dictionary = rig.layout["gait_continuations"][name]
		var part: Dictionary
		var donor: Dictionary
		for item: Dictionary in rig.layout["parts"]:
			if item["name"] == name: part = item
			if item["name"] == recipe["donor"]: donor = item
		var node: Node2D = rig.get_node_or_null(NodePath(name))
		if node == null: node = rig.bones[part["bone"]].get_node(NodePath(name))
		if gait and not node.has_meta("gait_texture"):
			var original: Texture2D = node.get("texture")
			# Source-first textures may expose their cached Image. Never mutate it:
			# every non-gait clip and other rig instance must retain the original.
			var image: Image = original.get_image().duplicate()
			var paint: Image = rig._texture(donor["file"]).get_image()
			for texel: Array in recipe["texels"]:
				var colour: Color = Color(1, 1, 0, 1) if rig.get_meta("gait_proof_checks", false) else paint.get_pixel(int(texel[2]), int(texel[3]))
				image.set_pixel(int(texel[0]), int(texel[1]), colour)
			node.set_meta("gait_original_texture", original)
			node.set_meta("gait_texture", ImageTexture.create_from_image(image))
		if node.has_meta("gait_texture"):
			node.set("texture", node.get_meta("gait_texture" if gait else "gait_original_texture"))
