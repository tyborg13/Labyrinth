extends "res://scripts/run_scene.gd"

## Observe every actual board submission, including the one-frame reduced-motion
## attack callback. Sampling process_frame alone can miss that transition.
var continuity_trace_enabled: bool = false
var continuity_samples: Array[Dictionary]

func begin_continuity_trace() -> void:
	continuity_samples.clear()
	continuity_trace_enabled = true

func _render_board_state(display_state: Dictionary, next_presentation: Dictionary, state_stable_since_last_submission: bool = false) -> void:
	super._render_board_state(display_state, next_presentation, state_stable_since_last_submission)
	if not continuity_trace_enabled:
		return
	var player: Dictionary = display_state.get("player", {})
	if player.is_empty() or int(player.get("hp", 0)) > 0:
		return
	var visible_player: Dictionary = {}
	for unit: Dictionary in board_view.call("_visible_units"):
		if str(unit.get("key", "")) == "player":
			visible_player = unit
			break
	var shown: Dictionary = board_view.get("presentation")
	var effect: Dictionary = shown.get("effect", {})
	continuity_samples.append({
		"visible": not visible_player.is_empty(),
		"death_progress": float(visible_player.get("death_progress", -1.0)),
		"death_animation": bool(visible_player.get("death_animation", false)),
		"tile": visible_player.get("pos", Vector2i(-1, -1)),
		"resolved_tile": player.get("pos", Vector2i(-1, -1)),
		"effect_kind": str(effect.get("kind", "")),
		"effect_progress": float(shown.get("effect_progress", -1.0)),
		"trap_effects": not (shown.get("trap_effects", []) as Array).is_empty(),
	})
