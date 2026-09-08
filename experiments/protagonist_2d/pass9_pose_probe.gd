extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const NewRig = preload("res://scripts/protagonist_cutout/rig.gd")
const OldRig = preload("res://experiments/protagonist_2d/references/pass9/baseline/rig.gd")
const OldMotion = preload("res://experiments/protagonist_2d/references/pass9/baseline/motion.gd")
const NewMotion = preload("res://scripts/protagonist_cutout/motion.gd")
const SIZE := Vector2i(1920, 1080)
var surface: SubViewport
var rigs: Array[Node2D] = []
var title: Label

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = SIZE
	surface = SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	var background := ColorRect.new()
	background.color = Color("303437")
	background.size = SIZE
	surface.add_child(background)
	for i: int in range(4):
		var rig: Node2D = OldRig.new() if i % 2 == 0 else NewRig.new()
		rig.facing = "front" if i < 2 else "rear"
		rig.position = Vector2(float(i * 480) + 20, 280)
		rig.scale = Vector2(1.8, 1.8)
		surface.add_child(rig)
		assert(rig.load_rig())
		rigs.append(rig)
		var label := Label.new()
		label.text = ("Pass 8" if i % 2 == 0 else "Pass 9") + " / " + rig.facing
		label.position = Vector2(i * 480 + 60, 200)
		label.add_theme_font_size_override("font_size", 28)
		surface.add_child(label)
	for i: int in [0, 2]:
		for sample_index: int in range(33):
			var phase: float = float(sample_index) / 32.0
			assert(OldMotion.sample_pose("attack", phase, rigs[i].layout, rigs[i].facing) == NewMotion.sample_pose("attack", phase, rigs[i+1].layout, rigs[i+1].facing), "Accepted attack pose changed")
	print("ACCEPTED_ATTACK_POSES: PASS (33 phases per facing)")
	title = Label.new()
	title.position = Vector2(40, 70)
	title.add_theme_font_size_override("font_size", 36)
	surface.add_child(title)
	var output: String = "user://probes/cutout_refinement_poses"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	var images: Array[Image] = []
	var names: Array[String] = []
	for clip: String in ["idle", "walk", "attack"]:
		var count: int = 24 if clip == "walk" else 8
		for index: int in range(count):
			var phase: float = float(index) / float(count if clip != "attack" else count-1)
			for rig: Node2D in rigs:
				rig.apply_pose(clip, phase)
			title.text = "%s / phase %.3f / painted parts at 1.8x" % [clip.capitalize(), phase]
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			images.append(surface.get_texture().get_image())
			names.append("%s_%02d.png" % [clip,index])
	for i: int in range(images.size()):
		var path: String = output.path_join(names[i])
		assert(images[i].save_png(path) == OK)
		print("Saved ", ProjectSettings.globalize_path(path))
	print("POSE_REFINEMENT_RESULT: PASS")
	quit(0)
