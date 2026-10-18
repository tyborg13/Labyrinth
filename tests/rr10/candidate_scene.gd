extends "res://tests/rr07/capture_scene.gd"

## Replace only the proof Seer through the board's existing renderer registry.
## All resolver steps, clip clocks, SFX and effects remain production callbacks.
func _render_board_state(display_state: Dictionary, presentation: Dictionary, state_stable_since_last_submission: bool = false) -> void:
	ensure_candidate(display_state)
	super._render_board_state(display_state, presentation, state_stable_since_last_submission)

func ensure_candidate(display_state: Dictionary) -> void:
	if is_instance_valid(board_view):
		var registry: Dictionary = board_view._rr07_renderers["hoarfrost_seer"]
		for enemy: Dictionary in display_state.get("enemies", []):
			if str(enemy.get("type", "")) != "hoarfrost_seer": continue
			var key: String = "enemy_%d" % int(enemy["id"])
			var old: Node = registry.get(key)
			if old != null and old.has_meta("rr10_candidate"): continue
			if is_instance_valid(old): old.queue_free()
			var candidate := preload("candidate_renderer.gd").new()
			candidate.set_meta("rr10_candidate", true)
			board_view.add_child(candidate)
			registry[key] = candidate
