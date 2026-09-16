extends "res://scripts/run_scene.gd"

# Observe the real playback path without replacing its timing, renderer or audio.
var feedback_trace_enabled: bool = false
var feedback_sound_ids: Array[String]
var feedback_presentations: Array[Dictionary]

func begin_feedback_trace() -> void:
	feedback_sound_ids.clear()
	feedback_presentations.clear()
	feedback_trace_enabled = true

func _play_sfx(entry: Dictionary) -> float:
	if feedback_trace_enabled: feedback_sound_ids.append(str(entry.get("id", "")))
	return super._play_sfx(entry)

func _animate_floating_text_presentation(display_state: Dictionary, presentation: Dictionary, initial_elapsed_seconds: float = 0.0, overlap_with_next_action: bool = false, companion_completion: Dictionary = {}) -> void:
	if feedback_trace_enabled: feedback_presentations.append(presentation.duplicate(true))
	await super._animate_floating_text_presentation(display_state, presentation, initial_elapsed_seconds, overlap_with_next_action, companion_completion)
