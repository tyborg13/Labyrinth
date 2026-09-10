extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const OUTPUT: String = "user://probes/crawler_pose_audit"

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
	if not rig.configure("res://experiments/cutouts/crawler/v01/cutout.json"):
		push_error(str(rig.load_errors))
		quit(1)
		return
	rig.position = Vector2(128,128)
	for facing: String in ["front","rear"]:
		rig.set_facing(facing)
		for clip: String in ["rest","walk","attack","lunge"]:
			for phase: float in [0.0,0.25,0.33,0.5,0.52,0.75]:
				rig.apply_pose(clip,phase)
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				viewport.get_texture().get_image().save_png(OUTPUT.path_join("%s_%s_%03d.png" % [facing,clip,roundi(phase*100)]))
	viewport.free()
	print("Saved " + ProjectSettings.globalize_path(OUTPUT))
	print("CRAWLER POSE AUDIT: PASS")
	quit()
