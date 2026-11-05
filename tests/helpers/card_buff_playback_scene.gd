extends "res://scripts/run_scene.gd"

## Observe the production card-step dispatch without renderer waits. The native
## probe uses the real scene and presentation clock instead.
var submissions: Array[Dictionary]

func _ensure_sfx_bank() -> void:
	if _sfx_router == null:
		_sfx_router = preload("res://scripts/sfx_cue_router.gd").new(null)

func _set_action_banner(_text: String) -> void:
	pass

func _animate_floating_text_presentation(_state: Dictionary, presentation: Dictionary, initial_elapsed_seconds: float = 0.0, overlap_with_next_action: bool = false, _companion_completion: Dictionary = {}) -> void:
	submissions.append({"presentation": presentation.duplicate(true), "initial_elapsed": initial_elapsed_seconds, "overlap": overlap_with_next_action})

func _animate_turn_order_alongside_defeats(_before: Dictionary, _after: Dictionary, _presentation: Dictionary = {}, _skip_terrain: bool = false, _order_before: Dictionary = {}) -> void:
	pass

func _animate_board_pickup_acquisitions(_before: Dictionary, _after: Dictionary) -> void:
	pass
