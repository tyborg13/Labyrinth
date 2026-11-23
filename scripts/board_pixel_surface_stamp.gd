extends Node2D

const SHADER = preload("res://shaders/ground_surface_stamp.gdshader")
var rect: Rect2
var _paint_bounds: Rect2
var _ink := ShaderMaterial.new()

func _ready() -> void:
	_ink.shader = SHADER
	material = _ink

func present_atlas(ground: Node2D, texture: Texture2D, source: Rect2i, destination: Rect2, ramp: PackedColorArray,
		kind: int, core: Vector2i) -> void:
	_set_rect(destination)
	material = _ink
	_ink.set_shader_parameter("art_texture", texture)
	_ink.set_shader_parameter("art_rect", Vector4(source.position.x, source.position.y, source.size.x, source.size.y))
	_ink.set_shader_parameter("ramp", ramp)
	_ink.set_shader_parameter("kind", kind)
	_ink.set_shader_parameter("ground_texel", ground.render_texel)
	_ink.set_shader_parameter("contact_core", core)
	_ink.set_shader_parameter("reflection", false)

func present_reflection(ground: Node2D, texture: Texture2D, body: Rect2, foot: Vector2,
		tile: Vector2i, height: int, opacity: float) -> void:
	var destination := Rect2(body.position.x, foot.y, body.size.x, height * ground.render_texel)
	_set_rect(destination)
	ground.bind_region(_ink)
	_ink.set_shader_parameter("art_texture", texture)
	_ink.set_shader_parameter("art_rect", Vector4(body.position.x, body.position.y, body.size.x, body.size.y))
	_ink.set_shader_parameter("owner_tile", tile)
	_ink.set_shader_parameter("reflection_opacity", opacity)
	_ink.set_shader_parameter("reflection", true)

func _set_rect(destination: Rect2) -> void:
	rect = destination
	_ink.set_shader_parameter("dest_rect", _as_vector(rect))
	_set_paint_bounds(destination)

static func _as_vector(bounds: Rect2) -> Vector4:
	return Vector4(bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y)

func _set_paint_bounds(bounds: Rect2) -> void:
	if _paint_bounds == bounds:
		return
	_paint_bounds = bounds
	queue_redraw()

func _draw() -> void:
	draw_rect(_paint_bounds, Color.WHITE)
