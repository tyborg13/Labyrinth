extends RefCounted
## Presentation only. Hides an instant screen swap behind a fading copy of the last drawn frame, so the
## swap itself never waits: state, focus and input have already moved on underneath.

# Above every modal surface in a run, below the cursor (120).
const LAYER: int = 110

static func play(host: Node, seconds: float) -> void:
	if DisplayServer.get_name() == "headless": return
	var frame: Image = host.get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty(): return
	var layer := CanvasLayer.new()
	layer.name = "ScreenCrossfade"
	layer.layer = LAYER
	var ghost := TextureRect.new()
	ghost.texture = ImageTexture.create_from_image(frame)
	ghost.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ghost.stretch_mode = TextureRect.STRETCH_SCALE
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(ghost)
	host.add_child(layer)
	var tween: Tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_callback(layer.queue_free)
