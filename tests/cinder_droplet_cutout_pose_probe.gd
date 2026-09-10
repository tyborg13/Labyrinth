extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/cinder_droplet_poses"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.world_2d = World2D.new()
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var rig := CaseRig.new()
	viewport.add_child(rig)
	if not rig.configure("res://experiments/cutouts/cinder_droplet/v01/cutout.json"):
		push_error(str(rig.load_errors))
		quit(1)
		return
	for view: String in ["front","rear"]:
		rig.set_facing(view)
		rig.position = Vector2(128,128)
		for clip: String in ["rest","idle","walk","attack"]:
			for phase: float in [0.0,.25,.38,.52,.75]:
				rig.apply_pose(clip,phase)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(OUTPUT.path_join("%s_%s_%02d.png" % [view,clip,roundi(phase*100)]))
	rig.free()
	viewport.free()
	print("Saved "+ProjectSettings.globalize_path(OUTPUT))
	print("CINDER DROPLET POSE PROBE: PASS")
	quit()
