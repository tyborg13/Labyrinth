extends RefCounted

func frame(_tree: SceneTree) -> void:
	await RenderingServer.frame_post_draw

func wait_seconds(tree: SceneTree, seconds: float) -> void:
	await tree.create_timer(seconds, true, false, true).timeout

func image(view: SubViewport) -> Image:
	return view.get_texture().get_image()

func tag() -> String:
	return "native readback"
