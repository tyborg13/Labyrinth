extends "res://tests/perf/profiled_run_scene.gd"

## Same probe-only timer on both Git-baseline and candidate scenes.
var sample_hover: bool = false
var hover_samples: Array[int]

func _on_board_tile_hovered(tile: Vector2i) -> void:
	var started: int = Time.get_ticks_usec()
	super._on_board_tile_hovered(tile)
	if sample_hover:
		hover_samples.append(Time.get_ticks_usec() - started)
		FrameTrace.record("target_input", started, Time.get_ticks_usec(), 25)
