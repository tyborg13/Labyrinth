extends SceneTree

const Rig = preload("res://experiments/protagonist_2d/cutout_rig.gd")
var viewport: SubViewport
var rig: Node2D
var output: String

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	output = ProjectSettings.globalize_path("user://protagonist_2d_frames")
	DirAccess.make_dir_recursive_absolute(output)
	viewport = SubViewport.new()
	viewport.size = Vector2i(512, 512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)
	rig = Rig.new()
	rig.name = "ReaverCutout"
	rig.position = Vector2(128, 128)
	viewport.add_child(rig)
	assert(rig.load_rig(), str(rig.load_errors))
	var requested: String = OS.get_environment("LABYRINTH_2D_CAPTURE_FACINGS")
	var facings: PackedStringArray = PackedStringArray(["front", "rear"]) if requested.is_empty() else requested.split(",", false)
	var manifest: Dictionary = {"canvas": [512, 512], "source_offset": [128, 128], "source_size": [255, 255], "per_clip_timing": true, "facings": {}, "rest_reconstruction": {}, "input_sha256": _input_hashes()}
	for facing: String in facings:
		assert(rig.has_facing(facing), "Required actual facing missing: " + facing)
		rig.set_facing(facing)
		assert(rig.load_errors.is_empty(), str(rig.load_errors))
		rig.show_rest()
		var rest: Image = await _image()
		assert(rest.save_png(output.path_join(facing + "_rest.png")) == OK)
		var source: Image = rig.get_rest_texture().get_image()
		var reconstructed: Image = rest.get_region(Rect2i(128, 128, 255, 255))
		source.convert(Image.FORMAT_RGBA8)
		reconstructed.convert(Image.FORMAT_RGBA8)
		var alpha_mismatches: int = 0
		var color_mismatches: int = 0
		var max_color_difference: float = 0.0
		for y: int in range(255):
			for x: int in range(255):
				var a: Color = source.get_pixel(x, y)
				var b: Color = reconstructed.get_pixel(x, y)
				if absf(a.a - b.a) > 0.5 / 255.0:
					alpha_mismatches += 1
				if a.a > 0.99 and b.a > 0.99:
					var difference: float = maxf(absf(a.r - b.r), maxf(absf(a.g - b.g), absf(a.b - b.b)))
					max_color_difference = maxf(max_color_difference, difference)
					if difference > 1.1 / 255.0:
						color_mismatches += 1
		manifest["rest_reconstruction"][facing] = {"alpha_mismatches": alpha_mismatches, "color_mismatches_over_one_code": color_mismatches, "max_color_difference": max_color_difference, "bones": rig.bones.size(), "target": str(rig.layout.get("rest_source", rig.layout.get("source", "")))}
		assert(alpha_mismatches == 0, "Rest silhouette changed: " + str(alpha_mismatches))
		assert(color_mismatches == 0, "Opaque source colors changed: " + str(color_mismatches))
		assert(rig.save_editable_scene(output.path_join("reaver_" + facing + ".tscn")) == OK)
		var clips: Dictionary = {}
		var requested_actions: String = OS.get_environment("LABYRINTH_2D_CAPTURE_ACTIONS")
		for action: String in rig.specs:
			if not requested_actions.is_empty() and action not in requested_actions.split(",", false):
				continue
			rig.set_clip(action)
			var folder: String = output.path_join(facing + "_" + action)
			DirAccess.make_dir_recursive_absolute(folder)
			var poses: Array = []
			for frame: int in range(rig.get_frame_count()):
				rig.seek_frame(frame)
				var image: Image = await _image()
				var occupied: Rect2i = image.get_used_rect()
				assert(occupied.size != Vector2i.ZERO, "Empty animation frame")
				assert(occupied.position.x >= 3 and occupied.position.y >= 3 and occupied.end.x <= 509 and occupied.end.y <= 509, "Animation clips the fixed canvas")
				assert(image.save_png(folder.path_join("%03d.png" % frame)) == OK)
				var points: Dictionary = {}
				for name_value: String in ["hand_r", "foot_r", "foot_l", "head"]:
					var point: Vector2 = rig.to_local((rig.bones[name_value] as Bone2D).global_position)
					points[name_value] = [point.x, point.y]
				poses.append({"frame": frame, "bounds": [occupied.position.x, occupied.position.y, occupied.end.x, occupied.end.y], "points": points})
			clips[action] = {"frames": rig.get_frame_count(), "fps": rig.get_fps(), "loop": bool((rig.specs[action] as Dictionary).get("loop", false)), "folder": folder, "poses": poses}
		manifest["facings"][facing] = clips
	var file := FileAccess.open(output.path_join("render_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print(output)
	print("PROTAGONIST 2D SKELETAL RENDER: PASS")
	viewport.queue_free()
	await process_frame
	quit()

func _image() -> Image:
	for frame: int in range(2):
		await process_frame
	await RenderingServer.frame_post_draw
	return viewport.get_texture().get_image()

func _input_hashes() -> Dictionary:
	var prefix: String = "res://experiments/protagonist_2d/"
	var paths: Dictionary = {}
	for name: String in ["cutout_rig.gd", "cutout_motion.gd", "render_frames_probe.gd", "cutout_layout.json", "cutout_layout_rear.json", "references/rear.png"]:
		paths[prefix + name] = true
	paths["res://assets/placeholders/units/player_reaver.png"] = true
	for name: String in ["cutout_layout.json", "cutout_layout_rear.json"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(prefix + name))
		if data.has("rest_source"):
			paths[prefix + str(data["rest_source"])] = true
		for part: Dictionary in data.get("parts", []):
			paths[prefix + str(part["file"])] = true
		for mesh: Dictionary in data.get("joint_meshes", []):
			paths[prefix + str(mesh["file"])] = true
		var cape: Dictionary = data.get("cape_mesh", {})
		if not cape.is_empty():
			paths[prefix + str(cape["file"])] = true
	var result: Dictionary = {}
	for path: String in paths:
		var digest: String = FileAccess.get_sha256(path)
		assert(not digest.is_empty(), "Missing render input: " + path)
		result[path] = digest
	return result
