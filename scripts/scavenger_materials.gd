extends RefCounted
## Authored Scavenger leather, timber and brass, registered from one retained atlas.
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ShadedType = preload("res://scripts/graftwright_type.gdshader")
const ATLAS := "res://assets/art/ui/scavenger_shop/materials_v3.png"
const REGIONS := {
	"action": Rect2(32, 138, 712, 211),
	"plaque": Rect2(782, 139, 722, 273),
	"tray": Rect2(29, 464, 710, 431),
	"dialogue": Rect2(782, 479, 722, 414),
}
static var _texture: Texture2D

static func paint(canvas: CanvasItem, kind: String, target: Rect2, tint: Color = Color.WHITE) -> void:
	if _texture == null: _texture = AssetLoader.load_texture(ATLAS)
	var source: Rect2 = REGIONS.get(kind, REGIONS["tray"])
	# Independent source/destination borders retain painted strap and corner
	# proportions, rather than stretching a command plate into every shape.
	var src_edge := Vector2(128, 68) if kind == "action" else Vector2(83, 90)
	var dst_edge := Vector2(minf(target.size.x * 0.16, 48), minf(target.size.y * 0.28, 24)) if kind == "action" else Vector2(minf(target.size.x * 0.18, 28), minf(target.size.y * 0.26, 28))
	var sx: Array = [source.position.x, source.position.x + src_edge.x, source.end.x - src_edge.x, source.end.x]
	var sy: Array = [source.position.y, source.position.y + src_edge.y, source.end.y - src_edge.y, source.end.y]
	var dx: Array = [target.position.x, target.position.x + dst_edge.x, target.end.x - dst_edge.x, target.end.x]
	var dy: Array = [target.position.y, target.position.y + dst_edge.y, target.end.y - dst_edge.y, target.end.y]
	for y: int in range(3):
		for x: int in range(3):
			canvas.draw_texture_rect_region(_texture, Rect2(dx[x], dy[y], dx[x + 1] - dx[x], dy[y + 1] - dy[y]), Rect2(sx[x], sy[y], sx[x + 1] - sx[x], sy[y + 1] - sy[y]), tint)

static func shade(label: Label, font_size: int, line_height: float) -> void:
	Typography.apply_label_role(label, Typography.ROLE_TITLE if font_size >= Typography.SIZE_SECTION else Typography.ROLE_BODY_LARGE)
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", Color("f0ddba"))
	label.add_theme_color_override("font_outline_color", Color("191016"))
	label.add_theme_constant_override("outline_size", 1)
	label.add_theme_color_override("font_shadow_color", Color(0.025, 0.016, 0.02, 0.95))
	label.add_theme_constant_override("shadow_offset_y", 2)
	label.add_theme_constant_override("shadow_outline_size", 1)
	var material := ShaderMaterial.new()
	material.shader = ShadedType
	material.set_shader_parameter("line_height", maxf(line_height, font_size))
	label.material = material
