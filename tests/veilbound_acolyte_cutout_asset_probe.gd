extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/veilbound_acolyte_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/veilbound_acolyte_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var compared: int = 0
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/veilbound_acolyte/v01/cutout.json"), "Reviewed case loads")
		_check(reference.set_facing(facing), "Reviewed facing loads")
		production.position = Vector2(128, 128)
		reference.position = Vector2(128, 128)
		for clip: String in ["rest", "idle", "walk", "cast", "attack"]:
			var frames: int = 1 if clip == "rest" else 24 if clip == "idle" else 32
			for index: int in range(frames):
				var phase: float = float(index) / float(frames - 1 if clip in ["cast", "attack"] else frames)
				production.apply_pose(clip, phase)
				reference.apply_pose(clip, phase)
				await _draw()
				var image: Image = actual.get_texture().get_image()
				_check(image.get_data() == accepted.get_texture().get_image().get_data(), "%s %s %d remains pixel-identical" % [facing, clip, index])
				compared += 1
				if clip in ["cast", "attack"] and index in [3, 6, 10, 13, 17, 21]:
					image.save_png(OUTPUT.path_join("%s_%s_%02d.png" % [facing, clip, index]))
				if clip == "rest":
					var baked: Image = Image.load_from_file("res://assets/units/veilbound_acolyte_cutout/" + facing + "/rest.png")
					if not "--bake" in OS.get_cmdline_user_args():
						_check(image.get_region(Rect2i(128, 128, 255, 255)).get_data() == baked.get_data(), "Shipped rest silhouette matches the current assembly")
					_check(image.save_png(OUTPUT.path_join(facing + "_canvas.png")) == OK, "Save native rest canvas")
					_check(image.get_region(Rect2i(128, 128, 255, 255)).save_png(OUTPUT.path_join(facing + "_rest.png")) == OK, "Save logical rest silhouette")
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": compared, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("VEILBOUND ACOLYTE ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
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
	if not condition:
		_errors.append(message)
