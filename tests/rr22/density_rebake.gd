extends "res://tools/rebake_cutout_rests.gd"

## Promotion changes the assembly even if density cleanup changes zero texels.
## Always rebake both Slag Mortar views; never certify this from a headless run.
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	super._initialize()

func _parts_changed(entry: Dictionary, _facing: String) -> bool:
	return str(entry["id"]) == "slag_mortar_cutout"

func _update_rest_fingerprint(layout_path: String, rest_path: String) -> void:
	super._update_rest_fingerprint(layout_path, rest_path)
	super._update_rest_fingerprint(layout_path.get_base_dir().path_join("humanoid_v2").path_join(layout_path.get_file()), rest_path)

const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_PAINT_SCALE: float = 2.0

func _finish() -> void:
	if DisplayServer.get_name() == "headless":
		super._finish()
		return
	_summary.call_deferred()

func _summary() -> void:
	var backdrop := ColorRect.new()
	backdrop.size = Vector2(PROOF_SIZE)
	backdrop.color = Color("1e1e24")
	root.add_child(backdrop)
	for index: int in range(_pending.size()):
		var paint := TextureRect.new()
		paint.texture = ImageTexture.create_from_image(_pending[index]["image"])
		paint.size = Vector2(255, 255) * PROOF_PAINT_SCALE
		paint.position = Vector2(PROOF_SIZE.x * (0.25 if index == 0 else 0.75), PROOF_SIZE.y * 0.5) - paint.size * 0.5
		paint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		paint.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		root.add_child(paint)
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT.path_join("rr22_density_pair.png")
	root.get_texture().get_image().save_png(path)
	print(ProjectSettings.globalize_path(path))
	super._finish()
