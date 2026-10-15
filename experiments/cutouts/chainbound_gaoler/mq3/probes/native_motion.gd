extends SceneTree

## Native RGBA, ownership, arm/body and visible-rest-dark provenance captures.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const SIZE := Vector2i(1920, 1080)
const POSE_SIZE := Vector2i(512, 512)
const SURFACE_COUNT: int = 5
const OUTPUT: String = "user://probes/maquette_motion"
const MASK_SHADER: String = "shader_type canvas_item; render_mode unshaded; uniform vec3 id_rgb; void fragment() { COLOR = vec4(id_rgb, texture(TEXTURE, UV).a); }"
var rigs: Array[Node2D]
var surfaces: Array[SubViewport]
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"] = 1.0
	preload("res://scripts/settings_store.gd").set_storage_path("user://maquette_motion_settings.json")
	preload("res://scripts/settings_store.gd").save_settings(settings)
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find("--case")
	if index < 0 or index + 1 >= args.size():
		push_error("Use -- --case /absolute/cutout.json")
		quit(1)
		return
	if args.has("--check-poses"):
		_check_capture_poses(args[index + 1])
		return
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var overview := SubViewport.new()
	overview.size = SIZE
	overview.disable_3d = true
	overview.world_2d = World2D.new()
	overview.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(overview)
	for number: int in range(SURFACE_COUNT):
		var surface := SubViewport.new()
		surface.size = POSE_SIZE
		surface.transparent_bg = true
		surface.disable_3d = true
		surface.world_2d = World2D.new()
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		var rig := Rig.new()
		rig.position = Vector2(128, 128)
		surface.add_child(rig)
		if not rig.configure(args[index + 1]):
			push_error(str(rig.load_errors))
			quit(1)
			return
		rigs.append(rig)
		surfaces.append(surface)
		var display := Sprite2D.new()
		display.centered = false
		display.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		display.texture = surface.get_texture()
		display.position = Vector2(20 + 550 * (number % 3), 20 + 528 * (number / 3))
		overview.add_child(display)
	var primary: Node2D = rigs[0]
	var directory: String = primary.case_directory
	var inputs: Dictionary = {}
	var paths: Array = primary.config["sources"].duplicate()
	paths.append_array(["cutout.json", str(primary.config["motion"]), "probes/native_motion.gd"])
	for facing: String in primary.config["layouts"]:
		paths.append(str(primary.config["layouts"][facing]))
		primary.set_facing(facing)
		for part: Dictionary in primary.layout["parts"]:
			paths.append(str(part["file"]))
	for path: String in paths:
		var relative: String = path.trim_prefix(directory + "/")
		inputs[relative] = FileAccess.get_sha256(directory.path_join(relative))
	var manifest: Dictionary = {"ok": false, "basis": "Native 512px RGBA, painted-node IDs, unoccluded fist-arm mask, torso/head/coat mask and visible-rest-dark provenance IDs; 1920x1080 overview, 100% UI scale", "inputs": inputs, "views": {}, "frames": [], "errors": []}
	var kinds: PackedStringArray = PackedStringArray(["rgba", "owners", "arm", "body", "rest_dark"])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for facing: String in primary.config["layouts"]:
		for rig: Node2D in rigs:
			rig.set_facing(facing)
		manifest["views"][facing] = _configure_masks()
		var clips: Array = primary.config["clips"].keys()
		clips.push_front("rest")
		for clip: String in clips:
			var count: int = 1 if clip == "rest" else int(primary.config["clips"][clip]["frames"])
			var folder: String = facing + "_" + clip
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
			for frame: int in range(count):
				_show_capture_frame(clip, frame)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var files: Dictionary = {}
				for number: int in range(SURFACE_COUNT):
					var image: Image = surfaces[number].get_texture().get_image()
					image.convert(Image.FORMAT_RGBA8)
					var file: String = folder.path_join("%s_%04d.png" % [kinds[number], frame])
					_check(image.save_png(OUTPUT.path_join(file)) == OK, "Save " + file)
					files[kinds[number]] = file
				manifest["frames"].append({"view": facing, "clip": clip, "frame": frame, "files": files})
				if frame in [0, count / 2, count - 1]:
					_check(overview.get_texture().get_image().save_png(OUTPUT.path_join(folder + "_%04d.png" % frame)) == OK, "Save overview")
	for path: String in inputs:
		_check(FileAccess.get_sha256(directory.path_join(path)) == inputs[path], "Input changed during capture: " + path)
	manifest["ok"] = failures.is_empty()
	manifest["errors"] = failures
	var file := FileAccess.open(OUTPUT.path_join("native_motion_manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest, "\t"))
	file.close()
	print("Saved ", ProjectSettings.globalize_path(OUTPUT))
	print("MAQUETTE_NATIVE_MOTION: " + ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _show_capture_frame(clip: String, frame: int) -> void:
	for rig: Node2D in rigs:
		# Rest is a sampler pose, not an authored clip with a frame count.
		if clip == "rest":
			rig.apply_pose("rest", 0.0)
		else:
			rig.show_frame(clip, frame)
		_check(rig.load_errors.is_empty(), str(rig.load_errors))

func _check_capture_poses(case_path: String) -> void:
	# Exercise the native probe's actual five-rig pose/mask setup headlessly.
	# GPU readback remains a separate windowed proof requirement.
	for number: int in range(SURFACE_COUNT):
		var rig := Rig.new()
		root.add_child(rig)
		if not rig.configure(case_path):
			_check(false, str(rig.load_errors))
			quit(1)
			return
		rigs.append(rig)
	var primary: Node2D = rigs[0]
	var frames: int = 0
	for facing: String in primary.config["layouts"]:
		for rig: Node2D in rigs:
			_check(rig.set_facing(facing), "Load " + facing)
		var ids: Dictionary = _configure_masks()
		_check(ids.size() == primary.layout["parts"].size(), "Complete paint-node IDs")
		var clips: Array = primary.config["clips"].keys()
		clips.push_front("rest")
		for clip: String in clips:
			var count: int = 1 if clip == "rest" else int(primary.config["clips"][clip]["frames"])
			for frame: int in range(count):
				_show_capture_frame(clip, frame)
				for rig: Node2D in rigs:
					for bone_name: String in primary.bones:
						var bone: Bone2D = rig.bones[bone_name]
						_check(bone.transform.is_finite(), "Finite capture bone " + bone_name)
						_check(bone.transform.is_equal_approx(primary.bones[bone_name].transform), "Identical five-surface pose " + bone_name)
				frames += 1
		# Also test rest after motion, including resetting attack draw order.
		_show_capture_frame("strike", 3)
		_show_capture_frame("rest", 0)
		for rig: Node2D in rigs:
			for bone_name: String in rig.bones:
				_check(rig.bones[bone_name].transform.is_equal_approx(rig.rest_transforms[bone_name]), "Rest reset " + facing + "/" + bone_name)
			for part: Dictionary in rig.layout["parts"]:
				var matches: Array[Node] = rig.find_children(str(part["name"]), "Sprite2D", true, false)
				_check(matches.size() == 1 and (matches[0] as Sprite2D).z_index == int(part["z_index"]), "Rest layer reset " + str(part["name"]))
	print("MAQUETTE_NATIVE_POSES: ", "PASS" if failures.is_empty() else "FAIL", " (", frames, " poses; five surfaces; GPU readback not exercised)")
	quit(0 if failures.is_empty() else 1)

func _configure_masks() -> Dictionary:
	var result: Dictionary = {}
	var shader := Shader.new()
	shader.code = MASK_SHADER
	var parts: Array = rigs[0].layout["parts"]
	for index: int in range(parts.size()):
		var part: Dictionary = parts[index]
		var id: int = index + 1
		result[str(id)] = {"node": part["name"], "logical_part": part.get("logical_part", part["name"]), "bone": part["bone"], "hidden": part.get("hidden_material", false)}
		for number: int in range(1, SURFACE_COUNT):
			var matches: Array[Node] = rigs[number].find_children(str(part["name"]), "Sprite2D", true, false)
			_check(matches.size() == 1, "Unique paint node " + str(part["name"]))
			if matches.size() != 1:
				continue
			var sprite: Sprite2D = matches[0] as Sprite2D
			var material := ShaderMaterial.new()
			material.shader = shader
			material.set_shader_parameter("id_rgb", Vector3(float(id & 255) / 255.0, float((id >> 8) & 255) / 255.0, 0.0) if number in [1, 4] else Vector3.ONE)
			sprite.material = material
			if number == 2:
				sprite.visible = part["bone"] in ["upper_fist", "fore_fist", "hand_fist"]
			elif number == 3:
				sprite.visible = part.get("logical_part", part["name"]) in ["head", "torso", "coat_near", "coat_far"]
			elif number == 4:
				var baseline_path: String = str(rigs[number].layout.get("visible_dark_baselines", {}).get(part.get("logical_part", part["name"]), ""))
				sprite.visible = not baseline_path.is_empty()
				if sprite.visible:
					var baseline: Image = Image.load_from_file(rigs[number].case_directory.path_join(baseline_path))
					var original: Image = Image.load_from_file(str(part["file"]))
					_check(baseline != null and original != null, "Load visible-dark provenance " + baseline_path)
					if baseline == null or original == null:
						continue
					var mask: Image = Image.create(original.get_width(), original.get_height(), false, Image.FORMAT_RGBA8)
					var offset: Vector2i = Vector2i(int(part["offset"][0]), int(part["offset"][1]))
					for y: int in range(original.get_height()):
						for x: int in range(original.get_width()):
							if original.get_pixel(x, y).a > 0.5 and baseline.get_pixel(x + offset.x, y + offset.y).a > 0.5:
								mask.set_pixel(x, y, Color.WHITE)
					sprite.texture = ImageTexture.create_from_image(mask)
	return result

func _check(condition: bool, message: String) -> void:
	if not condition and message not in failures:
		failures.append(message)
		push_error(message)
