extends RefCounted
## History contains only poses actually submitted by the renderer. It is scoped
## to one delivery; repeated retained-layer syncs replace the same frame.
const Points = preload("res://scripts/enemy_strike_points.gd")
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Geometry = preload("res://scripts/enemy_strike_geometry.gd")
const WINDOW_CLOCK_EPSILON: float = 0.000001
var _identity: Array = []
var _samples: Array[Dictionary]
var _last_progress: float = -1.0
var _reach_start: float = -1.0
var _reach: bool = false
var _reach_axis := Vector2.ZERO

func clear() -> void:
	_identity = []
	_samples.clear()
	_last_progress = -1.0
	_reach_start = -1.0
	_reach = false
	_reach_axis = Vector2.ZERO

func begin(renderer: Node, effect: Dictionary, progress: float) -> void:
	var identity: Array = [renderer.get_instance_id() if is_instance_valid(renderer) else 0, hash(effect)]
	if identity != _identity or progress < _last_progress:
		_samples.clear()
		_reach_start = -1.0
		_reach = false
		_reach_axis = Vector2.ZERO
	_identity = identity
	_last_progress = progress

func weapon(renderer: Node, settings: Dictionary, progress: float, contact: float,
		body: Rect2, target: Vector2, reach_test: Dictionary, scale: float, contact_point: Vector2) -> Dictionary:
	var current: Dictionary = Points.live_sample(renderer, settings, progress)
	if current.is_empty(): return {}
	var window: Vector2 = settings["window"]
	var tip: Vector2 = project_point(current["tip"], body)
	var inner: Vector2 = project_point(current["inner"], body)
	# Reach classification is measured in screen pixels by the board caller.
	# Displayed endpoints and retained history always come from the live pose.
	# Vector2 windows are float32; an invisible boundary roundoff must not
	# consume the first visible reach frame before travel begins.
	if _reach_start < 0.0 and progress > window.x+WINDOW_CLOCK_EPSILON:
		_reach = str(settings["kind"]) == "streak" and bool(reach_test.get("reaches_target",false))
		_reach_start = progress
		_reach_axis = (target-contact_point).normalized()
	var leading: Vector2 = tip
	if _reach:
		var travel: float = clampf(inverse_lerp(_reach_start,contact,progress),0.0,1.0) if contact>_reach_start else 1.0
		leading = tip.lerp(target, travel)
		inner = leading - (_reach_axis if progress>=contact else (target-tip).normalized()) * scale
	var sample: Dictionary = {"progress":progress, "tip":leading, "inner":inner}
	if _samples.is_empty() and progress > window.x:
		_samples.append({"progress":window.x, "tip":leading, "inner":inner})
	if not _samples.is_empty() and is_equal_approx(float(_samples[-1]["progress"]), progress): _samples[-1] = sample
	else: _samples.append(sample)
	var displayed: Array[Dictionary] = _grid_samples(window)
	var result: Dictionary = {"kind":settings["kind"], "samples":displayed, "fallback":false,
		"strike_point":tip, "live_tip":tip, "leading_tip":leading, "target_anchor":_reach,
		"reach_start":_reach_start, "sampler":"presented_pose"}
	result.merge(reach_test,false)
	if str(settings["kind"]) == "streak":
		# Retain the existing axis treatment and lane/tail/glint drawing.
		var adjusted: Dictionary = Geometry.resolve(displayed, "streak", body.get_center(), target, scale, contact, window, Geometry.SHORT_PATH * scale)
		result["samples"] = adjusted["samples"]
		if _reach: result["glint_anchor"] = target
	return result

func _grid_samples(window: Vector2) -> Array[Dictionary]:
	# Keep the existing fixed emission cadence and sample indices for sparks.
	# Interpolation joins observed poses; it never predicts an authored pose.
	var result: Array[Dictionary]
	var end: float = float(_samples[-1]["progress"])
	for index: int in range(ceili(maxf(0.0,end-window.x)/Trail.SAMPLE_STEP)):
		result.append(Trail.sample_at(_samples,window.x+float(index)*Trail.SAMPLE_STEP))
	result.append(_samples[-1])
	return result

static func project_point(point: Vector2, body: Rect2) -> Vector2:
	return body.position + point * body.size / 255.0

## Project through the same padded and pixel-aligned rect as the painted canvas.
static func body_rect(board: Control, source: Dictionary, renderer: Node) -> Rect2:
	var center: Vector2 = board.call("_unit_center", source)
	var padded: Rect2 = board.call("_unit_texture_draw_rect", source, center)
	var geometry: Dictionary = renderer.canvas_geometry() if renderer.has_method("canvas_geometry") else {"offset":renderer.SOURCE_OFFSET, "size":renderer.CANVAS_SIZE}
	var unit_size: Vector2 = padded.size * 255.0 / Vector2(geometry["size"])
	return Rect2(padded.position + (geometry["offset"] as Vector2) * unit_size / 255.0, unit_size)
