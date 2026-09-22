extends RefCounted
class_name RelicChestProp

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ArtTreatment = preload("res://scripts/combat_art_treatment.gd")
const ROOT: String = "res://assets/art/props/relic_chest_hinge_v1/"
const LOGICAL_SIZE := Vector2(96.0, 96.0)
const CANVAS_SIZE := Vector2(128.0, 160.0)
const CANVAS_OFFSET := Vector2(16.0, 40.0)
const HINGE_LEFT := Vector2(9.0, 36.0)
const HINGE_RIGHT := Vector2(70.0, 26.0)

# Registered stationary body plus two painted faces of one rigid lid. The
# sloping back hinge stays planted; projected depth changes only about it.
# Source ownership/landmarks: experiments/cutouts/relic_chest/v01/registration.json.
static func draw(canvas: CanvasItem, closed_texture: Texture2D, rect: Rect2, progress: float, tint: Color) -> void:
	var amount: float = clampf(progress, 0.0, 1.0)
	if amount <= 0.001:
		ArtTreatment.draw_rect(canvas, closed_texture, rect, tint, ArtTreatment.PROP)
		return
	var inner_alpha: float = smoothstep(0.08, 0.42, amount)
	var inner_tint := Color(tint, tint.a * inner_alpha)
	_draw_part(canvas, "lid_interior", rect, inner_tint, lerpf(0.16, 1.0, amount))
	_draw_part(canvas, "cavity", rect, Color(tint, tint.a * smoothstep(0.0, 0.28, amount)))
	if inner_alpha < 1.0:
		_draw_part(canvas, "lid_exterior", rect, Color(tint, tint.a * (1.0 - inner_alpha)), lerpf(1.0, 0.45, smoothstep(0.0, 0.42, amount)))
	_draw_part(canvas, "body", rect, tint)

static func _draw_part(canvas: CanvasItem, part: String, rect: Rect2, tint: Color, hinge_projection: float = 1.0) -> void:
	var texture: Texture2D = AssetLoader.load_texture(ROOT + part + ".png")
	if texture == null:
		return
	var points := PackedVector2Array()
	for corner: Vector2 in [Vector2.ZERO, Vector2(CANVAS_SIZE.x, 0.0), CANVAS_SIZE, Vector2(0.0, CANVAS_SIZE.y)]:
		var point: Vector2 = corner - CANVAS_OFFSET
		point = project_lid_point(point, hinge_projection)
		points.append(rect.position + point / LOGICAL_SIZE * rect.size)
	var uvs := PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN])
	ArtTreatment.draw_polygon(canvas, points, PackedColorArray([tint]), uvs, texture, ArtTreatment.PROP)

static func project_lid_point(point: Vector2, hinge_projection: float) -> Vector2:
	var hinge_y: float = HINGE_LEFT.y + (point.x - HINGE_LEFT.x) * (HINGE_RIGHT.y - HINGE_LEFT.y) / (HINGE_RIGHT.x - HINGE_LEFT.x)
	return Vector2(point.x, hinge_y + (point.y - hinge_y) * hinge_projection)
