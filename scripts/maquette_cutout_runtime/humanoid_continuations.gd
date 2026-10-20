extends RefCounted

## Copy existing, density-treated edge texels for gait playback or an explicitly
## declared clip. Rest/idle retain the original texture; skin fields never change.
## A gait recipe's optional "clips" list replaces gait-only playback (rr-22);
## "clip_continuations" declares per-clip recipes (rr-21) and wins on overlap.
static func apply(rig: Node2D, gait: bool, clip: String = "") -> void:
	var active: Dictionary = {}
	for name: String in rig.layout.get("gait_continuations", {}):
		var recipe: Dictionary = rig.layout["gait_continuations"][name]
		if ((recipe["clips"] as Array).has(clip) if recipe.has("clips") else gait): active[name] = recipe
	if not gait: active.merge(rig.layout.get("clip_continuations", {}).get(clip, {}), true)
	var all_parts: Dictionary = rig.layout.get("gait_continuations", {}).duplicate()
	for recipes: Dictionary in rig.layout.get("clip_continuations", {}).values(): all_parts.merge(recipes, true)
	for name: String in all_parts:
		var part: Dictionary
		var donor: Dictionary
		for item: Dictionary in rig.layout["parts"]:
			if item["name"] == name: part = item
			if active.has(name) and item["name"] == active[name]["donor"]: donor = item
		var node: Node2D = rig.get_node_or_null(NodePath(name))
		if node == null: node = rig.bones[part["bone"]].get_node(NodePath(name))
		if not node.has_meta("gait_original_texture"):
			if not active.has(name): continue
			node.set_meta("gait_original_texture", node.get("texture"))
		var key: String = "continuation_texture_" + clip
		if active.has(name) and not node.has_meta(key):
			var recipe: Dictionary = active[name]
			var original: Texture2D = node.get_meta("gait_original_texture")
			# Source-first textures may expose their cached Image. Never mutate it:
			# unlisted clips and other rig instances retain the original.
			var image: Image = original.get_image().duplicate()
			var paint: Image = rig._texture(donor["file"]).get_image()
			for texel: Array in recipe["texels"]:
				var colour: Color = Color.YELLOW if rig.get_meta("gait_proof_checks", false) else paint.get_pixel(int(texel[2]), int(texel[3]))
				image.set_pixel(int(texel[0]), int(texel[1]), colour)
			node.set_meta(key, ImageTexture.create_from_image(image))
		node.set("texture", node.get_meta(key if active.has(name) else "gait_original_texture"))
