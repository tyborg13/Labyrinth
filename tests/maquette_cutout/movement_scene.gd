extends "res://tests/maquette_cutout/capture_scene.gd"

## Observe actual submissions, including the endpoint before idle replaces it.
var movement_observer: Callable

func _render_board_state(state: Dictionary, presentation: Dictionary, stable: bool = false) -> void:
	super._render_board_state(state, presentation, stable)
	if movement_observer.is_valid(): movement_observer.call()
