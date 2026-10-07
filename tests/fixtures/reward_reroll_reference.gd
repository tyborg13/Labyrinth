extends "res://tests/fixtures/reward_choice_reference.gd"

# Frozen real action and synchronous choices before speculative UI preparation.
func _prepare_reward_reroll_choices() -> void:
	pass

func _on_reward_reroll_pressed() -> void:
	if _animation_lock or str(_run_state.get("mode", "room")) != "reward":
		return
	if _guided_tutorial_hard_gate_active():
		_guided_tutorial_reject("Choose a reward before rerolling on the guided run.")
		return
	var before_state: Dictionary = _run_state.duplicate(true)
	_run_state = _run_engine.reroll_card_reward(_run_state)
	if _run_state == before_state:
		return
	_persist_committed_boundary("reward_rerolled")
	_refresh_ui()
