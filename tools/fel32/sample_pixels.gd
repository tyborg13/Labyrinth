extends RefCounted
## Pair screen pixels along the diamond edges. The solid stroke mask uses the
## mitered geometry of the submitted polylines. AA fringe is outside this measure.

const EDGE_STEPS := 16
const EDGE_END_MARGIN := 0.15
const RED_DEPTH := 1.0
const BAND_DEPTH := 3.5
const FRAME_COLOR_TOLERANCE := 2.0 / 255.0

static func pairs(polygon: PackedVector2Array) -> Array[Array]:
	var samples: Array[Array]
	var center: Vector2 = (polygon[0] + polygon[2]) * 0.5
	for edge: int in 4:
		var a: Vector2 = polygon[edge]
		var b: Vector2 = polygon[(edge + 1) % 4]
		var normal: Vector2 = (b - a).orthogonal().normalized()
		if (center - (a + b) * 0.5).dot(normal) < 0.0: normal = -normal
		for step: int in EDGE_STEPS:
			var t: float = lerpf(EDGE_END_MARGIN, 1.0 - EDGE_END_MARGIN, (step + 0.5) / EDGE_STEPS)
			var origin: Vector2 = a.lerp(b, t)
			var red: Vector2 = pixel_center(origin + normal * RED_DEPTH)
			var inside: Vector2 = pixel_center(origin + normal * BAND_DEPTH)
			var depth: float = (inside - origin).dot(normal)
			if depth >= 3.0 and depth <= 4.0: samples.append([red, inside])
	return samples


static func pixel_center(point: Vector2) -> Vector2:
	return point.floor() + Vector2(0.5, 0.5)


static func rgb(color: Color) -> Array:
	return [color.r, color.g, color.b]


static func sample_floor(board: Control, tile: Vector2i, polygon: PackedVector2Array, floor_pixels: RefCounted, fire: bool) -> Array[Array]:
	var floor: Dictionary = floor_pixels.stone(board, tile)
	var result: Array[Array]
	for pair: Array in pairs(polygon):
		var values: Array[Array]
		for point: Vector2 in pair:
			values.append([[point.x, point.y], rgb(floor_pixels.sample(point, floor, fire))])
		result.append(values)
	return result


static func has_red_core(image: Image, tiles: Array, red: Color, outline_alpha: float) -> bool:
	var bounds := Rect2i(Vector2i.ZERO, image.get_size())
	for tile: Dictionary in tiles:
		var polygon := PackedVector2Array()
		for point: Array in tile["diamond"]: polygon.append(Vector2(point[0], point[1]))
		var alpha: float = outline_alpha * float(tile["alpha"])
		for pair: Array in pairs(polygon):
			var pixel := Vector2i(pair[0])
			if not bounds.has_point(pixel): continue
			var color: Color = image.get_pixelv(pixel)
			# Bound the contribution an unknown floor pixel can make under the red.
			if color.r >= alpha * red.r - FRAME_COLOR_TOLERANCE and color.r > color.g and color.r > color.b \
					and color.g <= alpha * red.g + 1.0 - alpha + FRAME_COLOR_TOLERANCE \
					and color.b <= alpha * red.b + 1.0 - alpha + FRAME_COLOR_TOLERANCE:
				return true
	return false
