extends RefCounted
## Static, gear-independent coverage. Only polygon arithmetic happens at runtime;
## the production rig and its alpha sources belong to the offline generator.
const Coverage = preload("res://assets/generated/hero_rest_coverage.tres")
const GEAR_DILATION: float = 6.0
static var _front: Dictionary = _dilated("front")
static var _rear: Dictionary = _dilated("rear")

static func data_for(facing: String) -> Dictionary:
	return _rear if facing == "rear" else _front

static func _dilated(facing: String) -> Dictionary:
	var polygons: Array[PackedVector2Array]
	var holes: Array[PackedVector2Array]
	# The generator verifies one connected bare-rest contour per facing. Native
	# dilation can close a concavity into a hole; keep its opposite winding as
	# transparent coverage rather than filling or double-counting that area.
	for expanded: PackedVector2Array in Geometry2D.offset_polygon(Coverage.facings[facing][0], GEAR_DILATION, Geometry2D.JOIN_ROUND):
		if Geometry2D.is_polygon_clockwise(expanded): polygons.append(expanded)
		else: holes.append(expanded)
	var bounds := Rect2()
	var first: bool = true
	for polygon: PackedVector2Array in polygons:
		for point: Vector2 in polygon:
			if first:
				bounds = Rect2(point, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(point)
	return {"polygons": polygons, "holes": holes, "bounds": bounds}
