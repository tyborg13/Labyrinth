extends RefCounted

## Keep the registered rest placeholder until the live canvas has a first frame.
static func show_when_drawn(art: TextureRect, cutout: Node) -> void:
	if DisplayServer.get_name() != "headless":
		await art.get_tree().process_frame
		await RenderingServer.frame_post_draw
	if not is_instance_valid(art) or not is_instance_valid(cutout):
		return
	var crop := AtlasTexture.new()
	crop.atlas = cutout.call("texture")
	crop.region = Rect2(Vector2(128, 128), Vector2(255, 255))
	art.texture = crop
