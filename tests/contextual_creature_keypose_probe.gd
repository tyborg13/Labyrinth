extends SceneTree

## Native 1920x1080 review plates at fixed source scale. Full-cycle authoring
## proof remains separate; these make the recoil/settle and reflected joints
## easy to inspect without waiting for thousands of individual PNG statistics.
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const CHARACTERS: PackedStringArray = ["crawler", "harrier", "stone_warden", "bile_bloomer", "lightning_wisp", "cinder_ooze", "cinder_droplet"]
const OUTPUT: String = "user://probes/contextual_creature_keyposes"
var failures: PackedStringArray = []

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1920,1080)
	var surface := SubViewport.new()
	surface.size = Vector2i(1920,1080)
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	for character: String in CHARACTERS:
		var stage := Node2D.new()
		surface.add_child(stage)
		var background := ColorRect.new()
		background.size = Vector2(1920,1080)
		background.color = Color("252a30")
		stage.add_child(background)
		for row: int in range(4):
			var facing: String = "front" if row < 2 else "rear"
			var reflected: bool = row % 2 == 1
			for column: int in range(5):
				var clip: String = "idle" if column == 0 else "hit" if column == 1 else "death"
				var phase: float = [0.0,0.15,0.33,0.66,1.0][column]
				var rig := CaseRig.new()
				stage.add_child(rig)
				if not rig.configure("res://output/contextual-animation-polish/creatures/cases/"+character+"/cutout.json") or not rig.set_facing(facing):
					failures.append(character+" "+facing+" could not load")
				rig.position = Vector2(column*384+64+(255 if reflected else 0),row*270+6)
				rig.scale = Vector2(-1,1) if reflected else Vector2.ONE
				rig.apply_pose(clip,phase)
				var label := Label.new()
				label.position = Vector2(column*384+6,row*270+250)
				label.add_theme_font_size_override("font_size",13)
				label.text = "%s %s%s %s %.2f" % [character,facing," mirrored" if reflected else "",clip,phase]
				stage.add_child(label)
		await process_frame
		await RenderingServer.frame_post_draw
		await process_frame
		await RenderingServer.frame_post_draw
		var image: Image = surface.get_texture().get_image()
		if image.save_png(OUTPUT.path_join(character+".png")) != OK:
			failures.append(character+" could not save")
		stage.free()
	for failure: String in failures:push_error(failure)
	print("Saved "+ProjectSettings.globalize_path(OUTPUT))
	print("CONTEXTUAL CREATURE KEYPOSE PROOF: "+("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
