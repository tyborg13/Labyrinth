extends RefCounted

const Pixel = preload("res://scripts/pixel_fx_layer.gd")
const TARGET_WIDTHS: PackedInt32Array = [100, 126, 147, 184]
const DECK_SIZE := Vector2i(1280, 800)
const DECK_WIDTH: int = 100
const MAX_WIDTH_ERROR: float = 0.02
const MIN_RATIO: float = 0.91
const MAX_RATIO: float = 1.10

static func logical_size(render_size: Vector2i) -> Vector2i:
	# Match the project's 1920x1080 canvas_items stretch with expanded aspect.
	var scale: float = minf(render_size.x / 1920.0, render_size.y / 1080.0)
	return Vector2i((Vector2(render_size) / scale).round())

static func fit(board: Control, target_tile_px: float) -> void:
	# A proof-only fit envelope lets the production room framing settle at a
	# known size without changing its tile-width calculation or using zoom.
	var scale: Vector2 = board.get_viewport().get_stretch_transform().get_scale().abs()
	var framing: RefCounted = board.get("_room_framing")
	var envelope: Rect2 = framing.bounds(target_tile_px / scale.x)
	var fit_center: Vector2 = board.get_viewport_rect().size * Vector2(0.5, 0.43)
	var fit_rect := Rect2(fit_center - envelope.size * 0.5, envelope.size)
	var exclusions: Array[Rect2]
	board.call("set_room_framing", fit_rect, exclusions, Rect2())
	assert(absf(physical_tile_width(board) - target_tile_px) <= MAX_WIDTH_ERROR)

static func physical_tile_width(board: Control) -> float:
	var scale: Vector2 = (board.get_viewport().get_stretch_transform() * board.get_global_transform()).get_scale().abs()
	return float(board.call("_tile_width")) * scale.x
