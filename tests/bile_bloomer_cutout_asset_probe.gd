extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/bile_bloomer_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/bile_bloomer_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var samples: Array[Dictionary]
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/bile_bloomer/v01/cutout.json"), "Case loads")
		_check(reference.set_facing(facing), "Facing loads")
		for reflected: bool in [false, true]:
			production.position = Vector2(383, 128) if reflected else Vector2(128, 128)
			production.scale = Vector2(-1, 1) if reflected else Vector2.ONE
			reference.position = production.position
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "burst", "mark"]:
				var specification: Dictionary = reference.config["clips"].get(clip, {"frames": 1, "loop": false})
				var frames: int = int(specification["frames"])
				var folder: String = "%s_%s_%s" % [facing, "reflected" if reflected else "painted", clip]
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
				for index: int in range(frames):
					var phase: float = float(index) / float(maxi(1, frames if specification["loop"] else frames - 1))
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					var identical: bool = image.get_data() == accepted.get_texture().get_image().get_data()
					_check(identical, "Native production and case pixels differ: " + folder + "/" + str(index))
					var bounds: Rect2i = image.get_used_rect()
					_check(bounds.has_area() and bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, "Fixed reflected canvas is clipped")
					var file: String = folder.path_join("pose_%03d.png" % index)
					_check(image.save_png(OUTPUT.path_join(file)) == OK, "Save complete native cycle")
					samples.append({"file": file, "phase": phase, "identical": identical, "bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y]})
					if clip == "rest" and not reflected:
						var logical: Image = image.get_region(Rect2i(128, 128, 255, 255))
						var baked: Image = Image.load_from_file("res://assets/units/bile_bloomer_cutout/" + facing + "/rest.png")
						_check(logical.get_data() == baked.get_data(), "Shipped rest bake equals the current native assembly")
						_check(logical.save_png(OUTPUT.path_join(facing + "_rest.png")) == OK, "Save fresh rest bake")
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_frames": samples.size(), "samples": samples, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("BILE BLOOMER ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512, 512)
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
	if not condition and not _errors.has(message):
		_errors.append(message)
