extends RefCounted

## Native, independent layers for the interior-tear/underlay-protrusion gates in every pose.
## These surfaces never appear in the review composition.
const Samples = preload("pixel_samples.gd")
const SIZE := Vector2i(512, 512)
const ORIGIN := Vector2(128, 128)
var surfaces: Dictionary = {}
var frames: Array[Dictionary]
var output: String
var reference_parts: Dictionary = {}
var reference_samples: Dictionary = {}
var reference_transforms: Dictionary = {}

func setup(tree: SceneTree, rigs: Dictionary, directory: String) -> void:
	output = directory
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		var definition: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rig.case_directory.path_join("seams.json")))
		reference_parts[view] = str(definition["reference_body_bones"][view])
		var references: Dictionary = preload("reference_masks.gd").images(rig.case_directory, rig.layout)
		surfaces[view] = {}
		for kind: String in ["parts", "seams", "rest", "interior"]:
			var viewport := SubViewport.new()
			viewport.size = SIZE
			viewport.transparent_bg = true
			viewport.disable_3d = true
			viewport.world_2d = World2D.new()
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			tree.root.add_child(viewport)
			var sprites: Dictionary = {}
			if references.has(kind):
				var sprite := Sprite2D.new()
				sprite.texture = ImageTexture.create_from_image(references[kind])
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.centered = false
				viewport.add_child(sprite)
				sprites[reference_parts[view]] = sprite
			for part: Dictionary in rig.layout["parts"]:
				if references.has(kind): continue
				if bool(part.get("seam_underlay", false)) != (kind == "seams"): continue
				var original: Sprite2D = rig.bones[part["bone"]].get_node(NodePath(part["name"]))
				var sprite := Sprite2D.new()
				sprite.texture = original.texture
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.centered = false
				sprite.z_index = int(part["z_index"])
				viewport.add_child(sprite)
				sprites[part["name"]] = sprite
			surfaces[view][kind] = {"viewport": viewport, "sprites": sprites}

func stage(view: String, rig: Node2D) -> void:
	var parts: Dictionary = Samples.parts_for(rig)
	reference_samples[view] = parts[reference_parts[view]]
	var reference_offset := Vector2.ZERO
	for part: Dictionary in rig.layout["parts"]:
		if part["name"] == reference_parts[view]: reference_offset = Vector2(float(part["offset"][0]), float(part["offset"][1]))
	for kind: String in surfaces[view]:
		var layer: Dictionary = surfaces[view][kind]
		for name: String in layer["sprites"]:
			var values: Array = parts[name]["transform"]
			var sprite: Sprite2D = layer["sprites"][name]
			sprite.transform = Transform2D(Vector2(values[0], values[1]), Vector2(values[2], values[3]), Vector2(values[4], values[5]) + ORIGIN)
			if kind == "rest" or kind == "interior":
				sprite.transform = sprite.transform * Transform2D(0.0, -reference_offset)
				var source: Transform2D = sprite.transform
				source.origin -= ORIGIN
				reference_transforms[view] = Samples.values(source)
			sprite.modulate.a = float(parts[name]["alpha"])
		(layer["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS

func capture(view: String, clip: String, frame: int) -> void:
	var row: Dictionary = {"view": view, "clip": clip, "frame": frame,
		"reference": reference_samples[view], "reference_transform": reference_transforms[view]}
	for kind: String in surfaces[view]:
		var relative: String = "silhouette_layers/%s_%s/%s_%04d.png" % [view, clip, kind, frame]
		var path: String = output.path_join(relative)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var viewport: SubViewport = surfaces[view][kind]["viewport"]
		viewport.get_texture().get_image().save_png(path)
		viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		row[kind + "_file"] = relative
		row[kind + "_sha256"] = FileAccess.get_sha256(path)
	frames.append(row)

func finish(inputs: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("seam_frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_pixels": true, "inputs": inputs, "frames": frames}))
