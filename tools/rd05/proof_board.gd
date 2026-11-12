extends "res://scripts/combat_board_view.gd"

# Debug-only fixed cadence makes the two 120-frame idle windows comparable.
const PROOF_FRAME_DELTA: float = 1.0 / 60.0
var redraw_requests: Dictionary = {}

func _process(delta: float) -> void:
	super._process(PROOF_FRAME_DELTA)

func _queue_render_layer_redraw(layer: Control, clock_only: bool = false) -> void:
	if is_instance_valid(layer):
		var key: String = str(layer.get("_render_layer_kind"))
		redraw_requests[key] = int(redraw_requests.get(key, 0)) + 1
	super._queue_render_layer_redraw(layer, clock_only)
