extends RefCounted

## Isolated native part surfaces measure shimmer without occlusion being counted
## as resampling noise. These are data, never generic screenshot evidence.
const Samples = preload("pixel_samples.gd")
const SIZE := Vector2i(512, 512)
const ORIGIN := Vector2(128, 128)
var surfaces: Dictionary = {}
var frames: Array[Dictionary]
var samples: Array[Dictionary]
var output: String

func setup(tree: SceneTree, rigs: Dictionary, directory: String) -> void:
	output = directory
	for view: String in rigs:
		var rig: Node2D = rigs[view]
		surfaces[view] = {}
		for part: Dictionary in rig.layout["parts"]:
			var pair: Dictionary = {}
			var original: Sprite2D = (rig.bones[part["bone"]] as Bone2D).get_node(NodePath(part["name"]))
			for kind: String in ["before", "after"]:
				var viewport := SubViewport.new()
				viewport.size = SIZE
				viewport.transparent_bg = true
				viewport.disable_3d = true
				viewport.world_2d = World2D.new()
				viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
				tree.root.add_child(viewport)
				var sprite := Sprite2D.new()
				sprite.texture = original.texture
				sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				sprite.centered = false
				viewport.add_child(sprite)
				pair[kind] = {"viewport": viewport, "sprite": sprite}
			surfaces[view][part["name"]] = pair

func stage(view: String, rig: Node2D, before: Dictionary, frame: int, phase: float, presented: float) -> void:
	var parts: Dictionary = Samples.parts_for(rig)
	for name: String in parts:
		parts[name]["before"] = before[name]
		for kind: String in ["before", "after"]:
			var values: Array = before[name] if kind == "before" else parts[name]["transform"]
			var transform := Transform2D(Vector2(values[0], values[1]), Vector2(values[2], values[3]), Vector2(values[4], values[5]) + ORIGIN)
			var surface: Dictionary = surfaces[view][name][kind]
			(surface["sprite"] as Sprite2D).transform = transform
			(surface["sprite"] as Sprite2D).modulate.a = float(parts[name]["alpha"])
			(surface["viewport"] as SubViewport).render_target_update_mode = SubViewport.UPDATE_ALWAYS
	samples.append({"view": view, "clip": "idle", "frame": frame, "phase": phase, "presented_phase": presented, "parts": parts})

func capture(view: String, frame: int) -> void:
	for name: String in surfaces[view]:
		var row: Dictionary = {"view": view, "part": name, "frame": frame}
		for kind: String in ["before", "after"]:
			var relative: String = "pixels/%s/%s/%s_%04d.png" % [view, name, kind, frame]
			var path: String = output.path_join(relative)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
			var viewport: SubViewport = surfaces[view][name][kind]["viewport"]
			viewport.get_texture().get_image().save_png(path)
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			row[kind] = relative
			row[kind + "_sha256"] = FileAccess.get_sha256(path)
		frames.append(row)

func finish(inputs: Dictionary) -> void:
	var file := FileAccess.open(output.path_join("pixel_frames.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"native_pixels": true, "inputs": inputs, "frames": frames, "samples": samples}))
