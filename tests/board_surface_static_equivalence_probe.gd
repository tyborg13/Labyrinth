extends SceneTree

const Art = preload("res://scripts/board_surface_presentation.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")

class Materials extends Node2D:
	var sample: int
	func _draw() -> void:
		for index: int in range(8):
			var center := Vector2(275.13 + float(index % 4) * 448.17, 355.37 + float(index / 4) * 410.11)
			draw_set_transform(center)
			var width: float = 370.17 if index < 4 else 170.37
			var seed: int = 701 + sample * 113 + index * 307
			if index % 2 == 0: Art._draw_rubble(self, Vector2.ZERO, width, seed)
			else: Art._draw_ice_material(self, Vector2.ZERO, width, seed)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var output: String = "user://probes/static_materials"
	DirAccess.make_dir_recursive_absolute(output)
	Fx.prepare()
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.msaa_2d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("39312e")
	background.size = Vector2(1920, 1080)
	view.add_child(background)
	var materials := Materials.new()
	view.add_child(materials)
	for sample: int in range(4):
		materials.sample = sample
		for cached: bool in [false, true]:
			Art.retained_static_batch_enabled = cached
			materials.queue_redraw()
			for frame: int in range(3): await RenderingServer.frame_post_draw
			var path: String = output.path_join("static_%s_%s.png" % [sample, "cached" if cached else "reference"])
			assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK)
	print("STATIC MATERIAL EQUIVALENCE PROBE: PASS")
	quit()
