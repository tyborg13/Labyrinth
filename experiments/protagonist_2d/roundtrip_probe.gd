extends SceneTree

## Load the saved editable scenes and compare their real renders with fresh rigs.
const Rig = preload("res://experiments/protagonist_2d/cutout_rig.gd")
var live_view: SubViewport
var saved_view: SubViewport
var live: Node2D
var saved: Node2D

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _viewport() -> SubViewport:
	var result := SubViewport.new()
	result.size = Vector2i(512, 512)
	result.transparent_bg = true
	result.disable_3d = true
	result.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	result.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(result)
	return result

func _run() -> void:
	var output: String = ProjectSettings.globalize_path("user://protagonist_2d_roundtrip")
	DirAccess.make_dir_recursive_absolute(output)
	live_view = _viewport()
	saved_view = _viewport()
	live = Rig.new()
	live.position = Vector2(128, 128)
	live_view.add_child(live)
	assert(live.load_rig())
	var checked: Array = []
	for facing: String in ["front", "rear"]:
		live.set_facing(facing)
		var path: String = "res://experiments/protagonist_2d/rigs/reaver_" + facing + ".tscn"
		var scene := load(path) as PackedScene
		assert(scene != null, "Saved scene must load: " + path)
		saved = scene.instantiate() as Node2D
		saved_view.add_child(saved)
		var player := saved.get_node("Animations") as AnimationPlayer
		assert(player != null and player.get_animation_list().size() == 5, "Saved rig retains all five editable animations")
		assert((saved.get_node("Skeleton") as Skeleton2D).get_bone_count() == 20, "Saved skeleton retains twenty bones")
		for action: String in live.specs:
			live.set_clip(action)
			var frame: int = int(live.get_frame_count() * 0.43)
			live.seek_frame(frame)
			player.play(action)
			player.pause()
			player.seek(float(frame) / live.get_fps(), true)
			for wait_frame: int in range(3):
				await process_frame
			await RenderingServer.frame_post_draw
			var expected: Image = live_view.get_texture().get_image()
			var actual: Image = saved_view.get_texture().get_image()
			assert(actual.get_data() == expected.get_data(), "Saved scene render differs: " + facing + "/" + action)
			if action == "walk":
				assert(actual.save_png(output.path_join(facing + "_saved_walk.png")) == OK)
			checked.append({"facing": facing, "action": action, "frame": frame, "pixel_identical": true})
		saved_view.remove_child(saved)
		saved.free()
	var file := FileAccess.open(output.path_join("validation.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"saved_scene_reload": true, "cases": checked}, "\t"))
	file.close()
	print(output)
	print("SAVED 2D RIG ROUNDTRIP: PASS")
	quit()
