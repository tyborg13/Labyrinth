extends "res://scripts/run_scene.gd"

# Run the production input/preview resolver without hundreds of animated save
# commits. Separate native probes exercise actual payment, animation and UI.
var commits: int = 0
var committed_result: Dictionary = {}
var committed_targets: Array[Vector2i]

func _refresh_card_preview_ui() -> void:
	_refresh_action_step_tracker()

func _play_player_card(hand_index: int, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	commits += 1
	committed_targets = selected_targets.duplicate()
	committed_result = _combat_engine.finish_player_card(resolved_state, hand_index, _combat_engine.card_plays_spent_for_actions(actions), {"play_mode":"play"})
	_reset_card_resolution()
