extends "res://scripts/run_scene.gd"

## Headless proof clock. Production routing and authored frame counts are kept;
## only wall-clock waits and the unbounded popup tail are deterministic here.
const PROOF_POPUP_FRAMES: int = 8
var proof_label: String = ""
var proof_frames: Array[String]
var proof_observations: Array[Dictionary]

func _render_board_state(state: Dictionary, shown: Dictionary, stable: bool = false) -> void:
	super._render_board_state(state, shown, stable)
	if not proof_label.is_empty():
		var hero: Dictionary = board_view.protagonist_animation_snapshot()
		proof_frames.append("%s,%s,%s" % [proof_label, hero["facing"], int(hero["mirrored"])])
		proof_observations.append({"label": proof_label, "facing": hero["facing"], "mirrored": hero["mirrored"], "contact": (shown.get("impact_actor_keys", []) as Array).has("player"), "hp": state.get("player", {}).get("hp", 0), "effect": shown.get("effect", {}).get("kind", ""), "progress": shown.get("effect_progress", -1.0)})

func _play_timed_animation_frames(count: int, seconds: float, render_frame: Callable) -> void:
	for frame: int in range(count if seconds <= 0.0 else 1, count + 1):
		render_frame.call(frame)

func _animate_floating_text_presentation(state: Dictionary, base: Dictionary, initial: float = 0.0, _overlap: bool = false, _companion: Dictionary = {}) -> void:
	for frame: int in range(PROOF_POPUP_FRAMES + 1):
		var shown: Dictionary = base.duplicate(true)
		shown["floating_texts"] = FloatingCombatText.animate_entries(base.get("floating_texts", []), initial + float(frame) / PROOF_POPUP_FRAMES, _reduced_motion_enabled())
		_render_board_state(state, shown)
