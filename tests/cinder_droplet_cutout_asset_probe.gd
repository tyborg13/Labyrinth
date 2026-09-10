extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/cinder_droplet_cutout/rig.gd")
const Cutout = preload("res://scripts/cinder_droplet_cutout/renderer.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const OUTPUT: String = "user://probes/cinder_droplet_cutout_assets"
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var still: SubViewport = _viewport()
	var source_sprite := Sprite2D.new()
	source_sprite.centered = false
	source_sprite.position = Vector2(128,128)
	source_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	source_sprite.texture = AssetLoader.load_texture_source_first("res://assets/art/enemies/cinder_droplet.png")
	still.add_child(source_sprite)
	var compared: int = 0
	var records: Array[Dictionary]
	for facing: String in ["front","rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(),"Production rig loads " + facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/cinder_droplet/v01/cutout.json"),"Current case loads")
		_check(reference.set_facing(facing),"Current facing loads")
		for mirror: bool in [false,true]:
			production.position = Vector2(383,128) if mirror else Vector2(128,128)
			production.scale = Vector2(-1,1) if mirror else Vector2.ONE
			reference.position = production.position
			reference.scale = production.scale
			var view_name: String = facing + ("_reflected" if mirror else "")
			for clip: String in ["rest","idle","walk","retreat","attack"]:
				var frames: int = 1 if clip == "rest" else int(reference.config["clips"][clip]["frames"])
				var folder: String = OUTPUT.path_join(view_name+"_"+clip)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
				var clip_record: Dictionary = {"view":view_name,"clip":clip,"frames":frames,"bounds":[],"pixel_identical":true}
				for index: int in range(frames):
					var phase: float = float(index)/float(frames-1 if clip=="attack" else frames)
					if clip=="attack":
						phase = Cutout.attack_pose_phase(phase,.42)
					production.apply_pose(clip,phase)
					reference.apply_pose(clip,phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					var identical: bool = image.get_data()==accepted.get_texture().get_image().get_data()
					_check(identical,"Case and production match every native pose: %s %s %d" % [view_name,clip,index])
					clip_record["pixel_identical"] = bool(clip_record["pixel_identical"]) and identical
					var bounds: Rect2i = image.get_used_rect()
					_check(bounds.has_area() and bounds.position.x>=3 and bounds.position.y>=3 and bounds.end.x<=509 and bounds.end.y<=509,"Complete fixed canvas contains the full action")
					clip_record["bounds"].append([bounds.position.x,bounds.position.y,bounds.size.x,bounds.size.y])
					_check(image.save_png(folder.path_join("pose_%04d.png" % index))==OK,"Save native pose")
					compared += 1
					if clip=="rest" and not mirror:
						var bake: Image = Image.load_from_file("res://assets/units/cinder_droplet_cutout/"+facing+"/rest.png")
						_check(image.get_region(Rect2i(128,128,255,255)).get_data()==bake.get_data(),"Shipped neutral registration matches the current assembly")
						if facing=="front":
							_check(image.get_data()==still.get_texture().get_image().get_data(),"Assembled neutral front is pixel-identical to the accepted source rendered through the same native pipeline")
				records.append(clip_record)
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok":_errors.is_empty(),"native_identical_frames":compared,"clips":records,"errors":_errors},"\t"))
	output.close()
	actual.free()
	accepted.free()
	still.free()
	for error: String in _errors:
		push_error(error)
	print("Saved "+ProjectSettings.globalize_path(OUTPUT))
	print("CINDER DROPLET ASSET PROBE: "+("PASS" if _errors.is_empty() else "FAIL"))
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
	if not condition and not _errors.has(message):
		_errors.append(message)
