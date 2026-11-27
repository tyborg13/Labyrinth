extends RefCounted
## The authored reveal exposes fixed paths from tail to head.

const Lines = preload("res://scripts/pixel_fx_lines.gd")
const LENGTH: float = 46.0
const SPACING: float = 8.0
const REVEAL := Vector2(0.36, 0.44)
const MIN_SPACING_CELLS: float = 2.0
# The source bounds get extra cells for raster clearance and the head row.
const BOUNDS_PAD_CELLS: int = 6
const NEIGHBORS: Array[Vector2i] = [Vector2i.ZERO, Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

static func geometry(anchor: Vector2, direction: Vector2, ramp: PackedColorArray,
		alpha: float, scale: float, progress: float, still: bool = false) -> Dictionary:
	var reveal: float = clampf(inverse_lerp(REVEAL.x, REVEAL.y, progress), 0.0, 1.0)
	if reveal <= 0.0 or scale <= 0.0 or direction.is_zero_approx(): return {}
	var axis: Vector2 = direction.normalized()
	var length: float = LENGTH * scale
	var normal := Vector2(-axis.y, axis.x) * SPACING * scale
	var points := PackedVector2Array()
	for lane: int in range(-1, 2):
		var center: Vector2 = anchor + normal * float(lane)
		var lane_length: float = length * (1.15 if lane == 0 else 1.0)
		points.append(center - axis * lane_length * 0.5)
		points.append(center + axis * lane_length * (reveal - 0.5))
	return {"shape": "claws", "points": points, "center": anchor, "normal": normal,
		"alpha": alpha, "head_ink": ramp[3] if still else ramp[4], "tail_ink": ramp[3]}

static func cells(batch: Dictionary, to_cells: Transform2D, floor_alpha: float,
		thresholds: PackedFloat32Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var center := Vector2i((to_cells * (batch["center"] as Vector2)).floor())
	# Fade the group together so the number of marks stays readable.
	if not Lines.trail_cell_visible(batch["alpha"], center, floor_alpha, thresholds): return result
	var source_normal: Vector2 = to_cells.basis_xform(batch["normal"])
	var normal: Vector2 = source_normal.normalized()
	var cross: Vector2i = Lines.cardinal_axis(normal)
	if cross == Vector2i.ZERO: return result
	var extra: Vector2 = normal * maxf(0.0, MIN_SPACING_CELLS - source_normal.length())
	var points: PackedVector2Array = batch["points"]
	for index: int in range(3):
		var offset: Vector2 = extra * float(index - 1)
		var from := Vector2i((to_cells * points[index * 2] + offset).floor())
		var to := Vector2i((to_cells * points[index * 2 + 1] + offset).floor())
		result.append(_lane(Lines.trail_segment(from, to), cross, batch["head_ink"], batch["tail_ink"]))
	# Diagonal stair steps and a two-cell head can consume the nominal gap.
	# Move the two outer masks equally, by the minimum extra grid cells.
	var distance: int = 0
	while not _separated(result[1], result[0], -cross * distance) or not _separated(result[1], result[2], cross * distance):
		distance += 1
	if distance > 0:
		result[0] = _translate(result[0], -cross * distance)
		result[2] = _translate(result[2], cross * distance)
	return result

static func _lane(path: Array[Vector2i], cross: Vector2i, head: Color, tail: Color) -> Dictionary:
	var result: Dictionary
	var head_start: int = path.size() / 2
	var wide_start: int = path.size() - ceili(path.size() / 3.0)
	for index: int in path.size():
		result[path[index]] = head if index >= head_start else tail
		if index >= wide_start:
			result[path[index] + cross] = head
	return result

static func _separated(middle: Dictionary, outer: Dictionary, offset: Vector2i) -> bool:
	for cell: Vector2i in outer:
		for neighbor: Vector2i in NEIGHBORS:
			if middle.has(cell + offset + neighbor): return false
	return true

static func _translate(cells_value: Dictionary, offset: Vector2i) -> Dictionary:
	var result: Dictionary
	for cell: Vector2i in cells_value:
		result[cell + offset] = cells_value[cell]
	return result
