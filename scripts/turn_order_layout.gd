extends RefCounted
## Compact column geometry. Engine order and all forecast facts remain untouched.
const Ink = preload("res://scripts/turn_order_ink.gd")
const MIN_SCALE: float = 0.72
const FIT_PRECISION_ITERATIONS: int = 20
const DETAILS_PASS_GAP: float = 12.0
const PROJECTION_WIDTH: float = 149.0
const OVERFLOW_PORTRAIT_OFFSET := Vector2(6, -4)

static func baseline_size(scene: Node, index: int) -> Vector2:
	if index == 0: return scene.TURN_ORDER_ACTIVE_SIZE
	var factor: float = maxf(scene.TURN_ORDER_QUEUED_MIN_WIDTH / scene.TURN_ORDER_ACTIVE_SIZE.x, 0.88 - float(index - 1) * 0.04)
	var width: float = roundf(scene.TURN_ORDER_ACTIVE_SIZE.x * factor)
	return Vector2(width, roundf(width * scene.TURN_ORDER_PORTRAIT_SIZE.y / scene.TURN_ORDER_PORTRAIT_SIZE.x))

static func solve(scene: Node, count: int, height: float) -> Dictionary:
	var factor: float = 1.0
	var plan: Dictionary = _measure(scene, count, factor)
	if float(plan.height) > height:
		factor = MIN_SCALE
		plan = _measure(scene, count, factor)
		if float(plan.height) <= height:
			# Choose the largest uniform multiplier that fits, without quantized
			# scale jumps. This is numerical precision, not presentation tuning.
			var lower: float = MIN_SCALE
			var upper: float = 1.0
			for iteration: int in range(FIT_PRECISION_ITERATIONS):
				var middle: float = (lower + upper) * 0.5
				if float(_measure(scene, count, middle).height) <= height: lower = middle
				else: upper = middle
			factor = lower
			plan = _measure(scene, count, factor)
	var visible: int = count
	while visible > 1 and float(plan.height) > height:
		visible -= 1
		plan = _measure(scene, visible, factor)
	# The final visible slot is replaced by the in-rail overflow portrait.
	var overflow: int = count - visible + 1 if visible < count else 0
	plan["visible"] = maxi(0, visible - 1) if overflow > 0 else visible
	if overflow > 0:
		var positions: Array[Vector2] = plan.positions
		var sizes: Array[Vector2] = plan.sizes
		positions[-1].x = float(plan.width) - maxf(Ink.BLEED_RIGHT, OVERFLOW_PORTRAIT_OFFSET.x * 2.0) - sizes[-1].x
	plan["overflow"] = overflow
	plan["scale"] = factor
	return plan

static func _measure(scene: Node, count: int, factor: float) -> Dictionary:
	var sizes: Array[Vector2]
	var positions: Array[Vector2]
	var height: float = 0.0
	for index: int in range(count):
		var slot: Vector2 = baseline_size(scene, index) * (1.0 if index == 0 else factor)
		sizes.append(slot)
	var width: float = column_width(scene)
	var next_y: float = 0.0
	for index: int in range(count):
		var slot: Vector2 = sizes[index]
		var x: float = width - Ink.BLEED_RIGHT - slot.x
		var y: float = next_y
		positions.append(Vector2(x, y))
		height = maxf(height, y + _paint_height(slot, index == 0))
		next_y = height + scene.TURN_ORDER_SLOT_GAP
	return {"sizes": sizes, "positions": positions, "height": height, "width": width}

static func _paint_height(slot: Vector2, active: bool) -> float:
	# The outlined numeral extends to 110% of the portrait height. Include its
	# existing outline; the rail clips all paint/motion at its reserved boundary.
	return slot.y * (Ink.BAND_CENTER_RATIO + 0.5) + (7.0 if active else 5.0)

static func column_width(scene: Node) -> float:
	return maxf(scene.TURN_ORDER_PANEL_MIN_WIDTH, scene.TURN_ORDER_ACTIVE_SIZE.x + Ink.BLEED_LEFT + Ink.BLEED_RIGHT)
