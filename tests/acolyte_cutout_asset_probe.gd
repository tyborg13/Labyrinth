extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/acolyte_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/acolyte_cutout_assets"
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
		_check(reference.configure("res://experiments/cutouts/acolyte/v01/cutout.json"), "Case loads")
		_check(reference.set_facing(facing), "Facing loads")
		for mirror: bool in [false, true]:
			production.position = Vector2(383,128) if mirror else Vector2(128,128)
			reference.position = production.position
			production.scale = Vector2(-1,1) if mirror else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest", "idle", "walk", "dust_bolt", "siphon"]:
				var frames: int = 1 if clip == "rest" else 24 if clip == "idle" else 36 if clip == "walk" else 40
				var folder: String = facing + ("_reflected" if mirror else "") + "_" + clip
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
				for index: int in range(frames):
					var phase: float = float(index) / float(frames - 1 if clip in ["dust_bolt", "siphon"] else frames)
					production.apply_pose(clip, phase)
					reference.apply_pose(clip, phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					_check(image.get_data() == accepted.get_texture().get_image().get_data(), "%s %d remains pixel-identical" % [folder,index])
					var bounds: Rect2i = image.get_used_rect()
					_check(bounds.position.x > 2 and bounds.position.y > 2 and bounds.end.x < 510 and bounds.end.y < 510, "Full canvas clears all paint in " + folder)
					_check(image.save_png(OUTPUT.path_join(folder).path_join("pose_%04d.png" % index)) == OK, "Retain native full-cycle sample")
					compared += 1
					if clip == "rest" and not mirror:
						var logical: Image = image.get_region(Rect2i(128,128,255,255))
						var path: String = "res://assets/units/acolyte_cutout/" + facing + "/rest.png"
						if OS.get_cmdline_user_args().has("--bake"):
							_check(logical.save_png(path) == OK, "Bake production neutral silhouette")
						else:
							_check(logical.get_data() == Image.load_from_file(path).get_data(), "Production rest bake remains current")
						logical.save_png(OUTPUT.path_join(facing + "_rest.png"))
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"), FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok": _errors.is_empty(), "native_identical_frames": compared, "reflections": true, "errors": _errors}, "\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors:
		push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("ACOLYTE ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
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
