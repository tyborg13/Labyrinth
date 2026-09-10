extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/cinder_ooze_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/cinder_ooze_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var compared: int = 0
	var records: Array[Dictionary]
	for facing: String in ["front", "rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(), "Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/cinder_ooze/v01/cutout.json"), "Case loads")
		_check(reference.set_facing(facing), "Case facing loads")
		for mirrored: bool in [false, true]:
			var position: Vector2 = Vector2(383,128) if mirrored else Vector2(128,128)
			var scale: Vector2 = Vector2(-1,1) if mirrored else Vector2.ONE
			production.position = position
			reference.position = position
			production.scale = scale
			reference.scale = scale
			for clip: String in ["rest", "idle", "walk", "attack", "bloom"]:
				var frames: int = 1 if clip == "rest" else 24 if clip == "idle" else 40 if clip == "bloom" else 36
				var folder: String = facing + ("_reflected" if mirrored else "") + "_" + clip
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT.path_join(folder)))
				for index: int in range(frames):
					var phase: float = float(index) / float(frames-1 if clip in ["attack","bloom"] else frames)
					production.apply_pose(clip,phase)
					reference.apply_pose(clip,phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					var bounds: Rect2i = image.get_used_rect()
					_check(image.get_data() == accepted.get_texture().get_image().get_data(), "%s %d case/production pixels match" % [folder,index])
					_check(bounds.has_area() and bounds.position.x >= 3 and bounds.position.y >= 3 and bounds.end.x <= 509 and bounds.end.y <= 509, folder + " keeps full fixed-canvas clearance")
					_check(image.save_png(OUTPUT.path_join(folder).path_join("pose_%04d.png" % index)) == OK, "Save native pose")
					compared += 1
					records.append({"facing":facing,"mirrored":mirrored,"clip":clip,"frame":index,"phase":phase,
						"bounds":[bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y]})
					if clip == "rest":
						var baked: Image = Image.load_from_file("res://assets/units/cinder_ooze_cutout/"+facing+"/rest.png")
						if mirrored: baked.flip_x()
						_check(image.get_region(Rect2i(128,128,255,255)).get_data() == baked.get_data(), "Shipped rest and reflected silhouette match current assembly")
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok":_errors.is_empty(),"native_identical_frames":compared,"samples":records,"errors":_errors},"\t"))
	output.close()
	actual.free()
	accepted.free()
	for error: String in _errors: push_error(error)
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("CINDER OOZE ASSET PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
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
	if not condition: _errors.append(message)
