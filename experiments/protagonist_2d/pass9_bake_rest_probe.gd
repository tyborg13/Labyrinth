extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Rig = preload("res://scripts/protagonist_cutout/rig.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://probes/cutout_rest_bake"))
	for facing: String in ["front", "rear"]:
		var surface := SubViewport.new()
		surface.size = Vector2i(255, 255)
		surface.transparent_bg = true
		surface.disable_3d = true
		surface.world_2d = World2D.new()
		surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(surface)
		var rig := Rig.new()
		rig.facing = facing
		surface.add_child(rig)
		assert(rig.load_rig())
		rig.apply_pose("rest", 0.0)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = "user://probes/cutout_rest_bake/%s_assembled_rest_v9.png" % facing
		var image: Image = surface.get_texture().get_image()
		assert(image.save_png(path) == OK)
		print("Saved ", ProjectSettings.globalize_path(path))
		surface.queue_free()
		await process_frame
	print("CUTOUT_REST_BAKE: PASS")
	quit(0)
