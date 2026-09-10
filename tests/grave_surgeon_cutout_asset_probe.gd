extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProductionRig = preload("res://scripts/grave_surgeon_cutout/rig.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const OUTPUT: String = "user://probes/grave_surgeon_cutout_assets"
var _errors: Array[String]
var _samples: Array[Dictionary]
var _refresh_bake: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_refresh_bake = OS.get_cmdline_user_args().has("--bake")
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var actual: SubViewport = _viewport()
	var accepted: SubViewport = _viewport()
	var source_view: SubViewport = _viewport()
	var original := Sprite2D.new()
	original.centered = false
	original.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	original.position = Vector2(128,128)
	original.texture = AssetLoader.load_texture_source_first("res://assets/art/enemies/grave_surgeon.png")
	source_view.add_child(original)
	var source_equal: bool = false
	var compared: int = 0
	var exposed_compared: int = 0
	for facing: String in ["front","rear"]:
		var production := ProductionRig.new()
		production.facing = facing
		actual.add_child(production)
		_check(production.load_rig(),"Production rig loads "+facing)
		var reference := CaseRig.new()
		accepted.add_child(reference)
		_check(reference.configure("res://experiments/cutouts/grave_surgeon/v01/cutout.json"),"Selected case loads")
		_check(reference.set_facing(facing),"Selected facing loads")
		for reflected: bool in [false,true]:
			var label: String = facing+("_reflected" if reflected else "")
			var folder: String = OUTPUT.path_join(label)
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
			production.position = Vector2(383,128) if reflected else Vector2(128,128)
			reference.position = production.position
			production.scale = Vector2(-1,1) if reflected else Vector2.ONE
			reference.scale = production.scale
			for clip: String in ["rest","idle","walk","attack","treat","ward"]:
				var frames: int = 1 if clip == "rest" else 32 if clip == "walk" else 40 if clip == "attack" else 24
				for index: int in range(frames):
					var phase: float = float(index)/float(frames-1 if clip in ["attack","treat","ward"] else frames)
					production.apply_pose(clip,phase)
					reference.apply_pose(clip,phase)
					await _draw()
					var image: Image = actual.get_texture().get_image()
					var bound: Rect2i = image.get_used_rect()
					_check(image.get_data() == accepted.get_texture().get_image().get_data(),"%s %s %d remains pixel-identical to the case" % [label,clip,index])
					_check(bound.has_area() and bound.position.x>=3 and bound.position.y>=3 and bound.end.x<=509 and bound.end.y<=509,"Complete canvas bounds contain "+label+"/"+clip)
					compared += 1
					_check(image.save_png(folder.path_join("%s_%03d.png" % [clip,index]))==OK,"Save native full-cycle frame")
					_samples.append({"facing":facing,"reflected":reflected,"clip":clip,"phase":phase,"bounds":[bound.position.x,bound.position.y,bound.size.x,bound.size.y]})
					if clip == "rest" and not reflected:
						_check(image.get_region(Rect2i(128,128,255,255)).save_png(OUTPUT.path_join(facing+"_rest.png"))==OK,"Save fresh registered rest bake")
						if facing == "front":
							source_equal = image.get_data() == source_view.get_texture().get_image().get_data()
							source_view.get_texture().get_image().save_png(OUTPUT.path_join("original_front_canvas.png"))
						var baked: Image = Image.load_from_file("res://assets/units/grave_surgeon_cutout/"+facing+"/rest.png")
						if not _refresh_bake:
							_check(image.get_region(Rect2i(128,128,255,255)).get_data()==baked.get_data(),"Shipped rest equals the fresh native assembly")
					if not reflected:
						_slot_visible(production, "cloak", false)
						_slot_visible(reference, "cloak", false)
						await _draw()
						var exposed: Image = actual.get_texture().get_image()
						_check(exposed.get_data()==accepted.get_texture().get_image().get_data(), "Exposed anatomy matches the editable case")
						_check(exposed.save_png(folder.path_join("%s_exposed_%03d.png" % [clip,index]))==OK, "Save native exposed anatomy")
						exposed_compared += 1
						_slot_visible(production, "cloak", true)
						_slot_visible(reference, "cloak", true)
		production.free()
		reference.free()
	var output := FileAccess.open(OUTPUT.path_join("comparison.json"),FileAccess.WRITE)
	output.store_string(JSON.stringify({"ok":_errors.is_empty(),"rest_mode":"refresh_bake" if _refresh_bake else "verify_shipped_bake","native_identical_frames":compared,"exposed_identical_frames":exposed_compared,"front_original_native_pixel_identical":source_equal,"samples":_samples,"errors":_errors},"\t"))
	output.close()
	actual.free()
	accepted.free()
	source_view.free()
	for error: String in _errors:
		push_error(error)
	print("Saved "+ProjectSettings.globalize_path(OUTPUT))
	print("GRAVE SURGEON ASSET PROBE: "+("PASS" if _errors.is_empty() else "FAIL"))
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

func _slot_visible(rig: Node, slot: String, visible: bool) -> void:
	for child: Node in rig.find_children("*", "CanvasItem", true, false):
		if str(child.get_meta("equipment_slot", "")) == slot:
			(child as CanvasItem).visible = visible
