extends RefCounted
## Native timing. The frame span uses resolved RenderingDevice markers instead
## of matching delayed viewport timestamps to this frame's script requests.

const Metrics = preload("res://tools/grd01/surface_metrics.gd")
# Godot 4.6.1's RenderingDevice returns nanoseconds from the Vulkan driver.
const NANOSECONDS_PER_MILLISECOND: float = 1000000.0
const FRAME_BEGIN: String = "Frame Begin"
const VIEWPORTS_END: String = "< Render Viewports"

var board_ms: Array[float]
var whole_frame_ms: Array[float]
var cell_ms: Array[float]
var cell_requests: int
var _last_capture: int = -1

func record(device: RenderingDevice, board: RID, cell: RID, cell_requested: bool) -> void:
	var board_time: float = RenderingServer.viewport_get_measured_render_time_gpu(board)
	if board_time > 0.0:
		board_ms.append(board_time)
	if cell_requested:
		cell_requests += 1
	if device == null or device.get_captured_timestamps_count() == 0:
		return
	var frame: int = device.get_captured_timestamps_frame()
	if frame == _last_capture:
		return
	_last_capture = frame
	var cell_begin_name: String = "vp_begin_%d" % cell.get_id() if cell.is_valid() else ""
	var cell_end_name: String = "vp_end_%d" % cell.get_id() if cell.is_valid() else ""
	var frame_begin: int = -1
	var frame_end: int = -1
	var cell_begin: int = -1
	var cell_end: int = -1
	for i: int in device.get_captured_timestamps_count():
		var marker: String = device.get_captured_timestamp_name(i)
		if marker == FRAME_BEGIN:
			frame_begin = device.get_captured_timestamp_gpu_time(i)
		elif marker == VIEWPORTS_END:
			frame_end = device.get_captured_timestamp_gpu_time(i)
		elif marker == cell_begin_name:
			cell_begin = device.get_captured_timestamp_gpu_time(i)
		elif marker == cell_end_name:
			cell_end = device.get_captured_timestamp_gpu_time(i)
	if frame_begin >= 0 and frame_end > frame_begin:
		whole_frame_ms.append(float(frame_end - frame_begin) / NANOSECONDS_PER_MILLISECOND)
	if cell_begin >= 0 and cell_end > cell_begin:
		cell_ms.append(float(cell_end - cell_begin) / NANOSECONDS_PER_MILLISECOND)

func summary(sample_frames: int) -> Dictionary:
	var whole: Dictionary = Metrics.stats(whole_frame_ms) if not whole_frame_ms.is_empty() else {}
	var board: Dictionary = Metrics.stats(board_ms) if not board_ms.is_empty() else {}
	var cell: Dictionary = Metrics.stats(cell_ms) if not cell_ms.is_empty() else {}
	var cell_status: String = "not_applicable"
	if cell_requests > 0:
		cell_status = "unavailable" if cell.is_empty() else "recorded"

	# Retain the previous board metric and the component estimate for
	# comparison with earlier runs. The estimate weights only cell updates.
	var combined: Variant = null
	if not board.is_empty():
		combined = board["mean"] + cell.get("mean", 0.0) * cell_requests / sample_frames
	var source: String = "unavailable"
	var note: String = "GPU timestamps unavailable."
	var includes_cell: bool = false
	var mean: Variant = null
	if not whole.is_empty():
		source = "whole_frame"
		mean = whole["mean"]
		includes_cell = true
		note = "The all-viewport span includes cell rendering even when individual cell timestamps are unavailable."
	elif combined != null:
		mean = combined
		if not cell.is_empty() and cell_requests > 0:
			source = "board_plus_cell_estimate"
			includes_cell = true
			note = "Whole-frame timestamps unavailable. Using the board and a weighted estimate from resolved cell updates."
		else:
			source = "board_viewport"
			note = "Whole-frame timestamps unavailable. Using the board viewport."
			if cell_requests > 0:
				note += " Cell timestamps unavailable, so offscreen cell GPU time is missing."
	return {
		"mean_ms_per_frame": mean, "timing_source": source, "timing_note": note,
		"includes_offscreen_cell_gpu": includes_cell,
		"whole_frame_ms": whole, "whole_frame_samples": whole_frame_ms.size(),
		"board_viewport_ms": board, "board_viewport_samples": board_ms.size(),
		"cell_viewport_ms_per_update": cell, "cell_update_frames": cell_requests,
		"cell_timestamp_samples": cell_ms.size(), "cell_timestamp_status": cell_status,
		"combined_mean_ms_per_frame": combined,
	}
