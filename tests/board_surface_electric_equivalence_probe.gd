extends SceneTree

## Same-clock comparison for all electrical branches, two board scales, seeded
## layouts and Stormcoal opacity. Use check_board_surface_cache_proof.py on
## the visual runner manifest to enforce native pixel equivalence.
const Art = preload("res://scripts/board_surface_presentation.gd")
const Retained = preload("res://scripts/board_surface_electric_layer.gd")
class Reference extends Node2D:
	var phase: float
	func _draw() -> void:
		for row: int in range(3):
			for col: int in range(4):
				draw_set_transform(Vector2(240.13 + col * 460.27, 190.37 + row * 345.43))
				Art._draw_electric(self, Vector2.ZERO, 370.27 if row == 0 else 170.73, phase + row * 0.73, 1009 + col * 503, 0.75 if row == 2 else 1.0)
		draw_set_transform(Vector2.ZERO)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var output: String = "user://probes/electric"
	DirAccess.make_dir_recursive_absolute(output)
	var view := SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.msaa_2d = Viewport.MSAA_4X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(view)
	var background := ColorRect.new()
	background.color = Color("39312e")
	background.size = Vector2(1920, 1080)
	view.add_child(background)
	var reference := Reference.new()
	view.add_child(reference)
	var layers: Array[Node2D]
	for row: int in range(3):
		for col: int in range(4):
			var layer := Retained.new()
			view.add_child(layer)
			layers.append(layer)
	for phase: float in [0.37, 12.0, 12.73, 13.21]:
		for cached: bool in [false, true]:
			Art.retained_cache_enabled = cached
			reference.visible = not cached
			reference.phase = phase
			reference.queue_redraw()
			for i: int in range(layers.size()):
				var row: int = i / 4
				var col: int = i % 4
				layers[i].visible = cached
				layers[i].configure(Vector2(240.13 + col * 460.27, 190.37 + row * 345.43), 370.27 if row == 0 else 170.73, 1009 + col * 503, phase + row * 0.73, 0.75 if row == 2 else 1.0)
			for wait: int in range(4): await RenderingServer.frame_post_draw
			var path: String = output.path_join("electric_%s_%s.png" % [str(phase).replace(".", "_"), "cached" if cached else "reference"])
			assert(view.get_texture().get_image().save_png(ProjectSettings.globalize_path(path)) == OK)
	print("ELECTRIC EQUIVALENCE PROBE: PASS")
	quit()
