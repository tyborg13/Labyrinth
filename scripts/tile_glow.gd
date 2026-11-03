extends RefCounted

## Four feathered triangles, never a tile outline. Scratch buffers are retained;
## repeated overlay paints do not build arrays or per-tile cache entries.
## A four-corner alpha buffer preserves Warband's radial/edge falloff exactly.
static var _points := PackedVector2Array([Vector2.ZERO, Vector2.ZERO, Vector2.ZERO])
static var _colours := PackedColorArray([Color.WHITE, Color.WHITE, Color.WHITE])

static func draw(canvas: Object, polygon: PackedVector2Array, color: Color, centre_alpha: float, corner_alpha: Variant) -> void:
	if polygon.size() < 4: return
	_points[0] = (polygon[0] + polygon[2]) * 0.5
	_colours[0] = Color(color, centre_alpha)
	for edge: int in range(4):
		var next: int = (edge + 1) % 4
		_points[1] = polygon[edge]
		_points[2] = polygon[next]
		_colours[1] = Color(color, float(corner_alpha[edge]) if corner_alpha is PackedFloat64Array else float(corner_alpha))
		_colours[2] = Color(color, float(corner_alpha[next]) if corner_alpha is PackedFloat64Array else float(corner_alpha))
		canvas.draw_polygon(_points, _colours)

# Director feedback 1: every other transient wash keeps 30% at its corners.
const TRANSIENT_CORNER_FRACTION: float = 0.30

static func draw_wash(canvas: Object, polygon: PackedVector2Array, color: Color, centre_alpha: float) -> void:
	draw(canvas, polygon, color, centre_alpha, centre_alpha * TRANSIENT_CORNER_FRACTION)
