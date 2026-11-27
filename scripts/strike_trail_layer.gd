extends Node2D
## Retained trail painter at the original board depth, beneath its parent's text.
const Trail = preload("res://scripts/strike_trail_fx.gd")
const Pixel = preload("res://scripts/pixel_fx_layer.gd")

var _batches: Array[Dictionary]
var _element: String = "none"
var _ramp_id: String
var _pixels := Pixel.new()
var submission_revision: int = 0
var drawn_submission_revision: int = -1
var draw_count: int = 0
var instrumentation_owner: Control
var instrumentation_section: String = "effect_overlay"
var measure_trail: bool
var trail_submit_usec: int
var trail_raster_usec: int
var trail_draw_usec: int

func _init() -> void:
	name = "StrikeTrailLight"
	show_behind_parent = true

func _ready() -> void:
	add_child(_pixels)
	_ramp_id = Pixel.trail_ramp_id(_element)
	_pixels.reserve_trail_run(instrumentation_section == "effect_overlay")
	if instrumentation_section == "effect_overlay" and DisplayServer.get_name() != "headless":
		_pixels.warm_trail_run(self)
		RenderingServer.frame_post_draw.connect(_finish_warmup, CONNECT_ONE_SHOT)

func _finish_warmup() -> void:
	if submission_revision == 0:
		_pixels.clear_cell_trail()
		_pixels.clear_trail_run()

func submit(batches: Array[Dictionary], element: String = "none") -> void:
	if batches.is_empty() and _batches.is_empty(): return
	var started: int = Time.get_ticks_usec() if measure_trail else 0
	_batches = batches
	if batches.is_empty():
		_pixels.clear_cell_trail()
		_pixels.clear_trail_run()
	else:
		if _element != element:
			_element = element
			_ramp_id = Pixel.trail_ramp_id(element)
		_submit_pixels()
	if measure_trail: trail_submit_usec += Time.get_ticks_usec() - started

func _draw() -> void:
	# PixelFxLayer requests a redraw if the physical viewport changes.
	if not _batches.is_empty():
		_submit_pixels()

func _submit_pixels() -> void:
	var shape: String = _batches[0]["shape"]
	if shape == "crescent" or shape == "streak":
		if _pixels.submit_cell_trail(self, _ramp_id, _draw_trail, _batches):
			submission_revision += 1
		return
	submission_revision += 1
	_pixels.clear_cell_trail()
	_pixels.begin(self)
	_pixels.submit(_ramp_id, _draw_trail, [_batches], Transform2D.IDENTITY, Trail.bounds(_batches))
	_pixels.finish()

func _draw_trail(canvas: Node2D, batches: Array[Dictionary]) -> void:
	var started: int = Time.get_ticks_usec()
	if measure_trail:
		canvas.measure_trail = true
		canvas.raster_usec = 0
	Trail.draw(canvas, batches)
	drawn_submission_revision = submission_revision
	draw_count += 1
	if measure_trail:
		trail_raster_usec += canvas.raster_usec
		trail_draw_usec += Time.get_ticks_usec() - started - canvas.raster_usec
	if is_instance_valid(instrumentation_owner):
		instrumentation_owner.call("_record_render_section_time", instrumentation_section, started)

func pixel_snapshot() -> Dictionary:
	var sample: Dictionary = _pixels.trail_snapshot()
	if sample.is_empty(): return sample
	sample["ramp"] = sample["element"]
	sample["glow"] = _batches.any(func(batch: Dictionary) -> bool: return batch.get("glow", false))
	return sample
