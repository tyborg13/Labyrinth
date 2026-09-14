extends SceneTree
## Fast anatomy review of every new cutout using the real renderer. Complete
## per-case timing, contact and editable-scene proofs use cutout_workflow.py.
const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const Actors = preload("res://scripts/guardian_cutout/renderer.gd")
const SIZE := Vector2i(1920,1080)
const OUTPUT := "user://probes/guardian_cutout_gallery"
var failures: Array[String] = []
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	root.size = SIZE
	root.content_scale_size = SIZE
	var canvas := SubViewport.new()
	canvas.size = SIZE
	canvas.disable_3d = true
	canvas.world_2d = World2D.new()
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var backdrop := ColorRect.new()
	backdrop.color = Color("30343d")
	backdrop.size = Vector2(SIZE)
	canvas.add_child(backdrop)
	var puppet := SubViewport.new()
	puppet.size = Vector2i(512,512)
	puppet.transparent_bg = true
	puppet.disable_3d = true
	puppet.world_2d = World2D.new()
	puppet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(puppet)
	var records: Array[Dictionary] = []
	for id: String in Actors.ACTOR_IDS:
		var view := Control.new()
		canvas.add_child(view)
		var title := Label.new()
		title.text = id.replace("_"," ").capitalize() + " • Front and rear cutout review"
		title.position = Vector2(32,20)
		title.add_theme_font_size_override("font_size",26)
		view.add_child(title)
		var rig := Rig.new()
		puppet.add_child(rig)
		rig.position = Vector2(128,128)
		if not rig.configure("res://experiments/cutouts/%s/v01/cutout.json" % id):
			failures.append(id + ": " + str(rig.load_errors))
			continue
		var samples: Array = [["idle",0],["walk",0],["walk",5],["walk",10],["walk",15],["strike",8],["cast",8],["brace",8]]
		for row: int in range(2):
			var facing: String = "front" if row==0 else "rear"
			rig.set_facing(facing)
			for col: int in range(samples.size()):
				var clip: String = samples[col][0]
				var frame: int = samples[col][1]
				rig.show_frame(clip,frame)
				await _draw()
				var picture: Image = puppet.get_texture().get_image()
				var folder: String = OUTPUT.path_join(id).path_join(facing+"_"+clip)
				DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
				picture.save_png(folder.path_join("pose_%04d.png" % frame))
				var texture := TextureRect.new()
				texture.texture = ImageTexture.create_from_image(picture.get_region(Rect2i(96,96,320,320)))
				texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
				texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				texture.size = Vector2(232,232)
				texture.position = Vector2(16+col*238,150+row*460)
				view.add_child(texture)
				var label := Label.new()
				label.text = "%s • %s %d" % [facing,clip,frame]
				label.position = Vector2(24+col*238,120+row*460)
				label.add_theme_font_size_override("font_size",17)
				view.add_child(label)
				if not rig.load_errors.is_empty(): failures.append(id + ": " + str(rig.load_errors))
		await _draw()
		canvas.get_texture().get_image().save_png(OUTPUT.path_join(id+"_review.png"))
		records.append({"id":id,"facings":2,"samples_per_facing":8,"errors":rig.load_errors})
		puppet.remove_child(rig)
		rig.free()
		canvas.remove_child(view)
		view.free()
	var manifest := FileAccess.open(OUTPUT.path_join("manifest.json"),FileAccess.WRITE)
	manifest.store_string(JSON.stringify({"actors":records,"errors":failures,"size":[1920,1080],"ui_scale":1.0},"\t"))
	print("Saved ",ProjectSettings.globalize_path(OUTPUT))
	print("GUARDIAN CUTOUT GALLERY: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	quit(0 if failures.is_empty() else 1)
func _draw() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
