extends "res://tools/scn01/census.gd"
## Reuse the census checkpoint and settle checks for framing controls.

const PROOF_PIXEL_PRECISION: float = 0.01


func _finish(error: String) -> void:
	if error.is_empty():
		if _screen.get("_run_end_board_reframe_active"):
			# Sample the production endpoint. The tiny residual easing otherwise
			# varies with the frame in which the headless layout settles.
			_screen.call("_seek_run_end_board_reframe", 1.0)
			_screen.call("_retarget_run_end_board_reframe")
		var stage: Dictionary = StageState.read(_screen)
		var board: Control = _screen.get("board_view")
		var fit: Rect2 = board.get("presentation").get("board_fit_rect", Rect2())
		_result["frame"] = {
			"fit_origin": [fit.position.x, fit.position.y],
			"fit_size": stage["board_fit_size"],
			"tile_width": stage["tile_width"],
			"board_rect": (stage["board_rect"] as Array).map(func(value: float) -> float: return snappedf(value, PROOF_PIXEL_PRECISION)),
			"board_visible": stage["board_in_tree_visible"],
		}
	super._finish(error)
