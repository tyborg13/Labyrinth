extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/harrier_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/harrier_cutout_assets"
var _errors: Array[String]
var _bounds: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var bake: bool = OS.get_cmdline_user_args().has("--bake")
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var compared: int = 0
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production Harrier rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/harrier/v02/cutout.json"), "Current editable case loads")
		_check(reference.set_facing(facing), "Case facing loads")
		for mirror: bool in [false, true]:
			var folder: String = facing + ("_reflected" if mirror else "")
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
			production.position = Vector2(383, 128) if mirror else Vector2(128, 128)
			reference.position = production.position
			production.scale = Vector2(-1, 1) if mirror else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "retreat", "attack", "cast"]:
				var frames: int = 1 if clip == "rest" else 32 if clip == "idle" else 40
				for index: int in range(frames):
					var phase: float = float(index) / float(frames - 1 if clip in ["attack", "cast"] else frames)
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await _draw()
					var native: Image = actual.get_texture().get_image()
					_check(native.get_data() == accepted.get_texture().get_image().get_data(), "%s %s %d is pixel-identical to the editable case" % [folder, clip, index])
					var bounds: Rect2i = native.get_used_rect()
					_check(bounds.position.x > 0 and bounds.position.y > 0 and bounds.end.x < 512 and bounds.end.y < 512, "Full fixed canvas contains " + folder + "/" + clip)
					_bounds.append({"view": folder, "clip": clip, "frame": index, "bounds": [bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
					compared += 1
					native.save_png(OUTPUT.path_join(folder).path_join("%s_%03d.png" % [clip,index]))
					if clip == "rest" and not mirror:
						var rest: Image = native.get_region(Rect2i(128,128,255,255))
						rest.save_png(OUTPUT.path_join(facing + "_rest.png"))
						var cloth: Array[Node] = production.find_children("*", "CanvasItem", true, false)
						for node: Node in cloth:
							if str(node.get_meta("equipment_slot", "")) == "cloak":node.set("visible", false)
						await _draw()
						actual.get_texture().get_image().save_png(OUTPUT.path_join(facing + "_without_cloth.png"))
						for node: Node in cloth:
							if str(node.get_meta("equipment_slot", "")) == "cloak":node.set("visible", true)
						if not bake:
							var shipped: Image = Image.load_from_file("res://assets/units/harrier_cutout/" + facing + "/rest.png")
							_check(shipped.get_data() == rest.get_data(), "Shipped rest is the current native assembly")
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "bake_only": bake, "native_identical_frames": compared, "full_canvas_bounds": _bounds, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("HARRIER ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	return viewport

func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw

func _check(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
