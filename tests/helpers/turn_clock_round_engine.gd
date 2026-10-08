extends "res://scripts/combat_engine.gd"

var finish_calls: int = 0
var activation_kinds: Array[String]
var _advancing: bool = false

func finish_player_activation(state: Dictionary) -> Dictionary:
	finish_calls += 1
	return super.finish_player_activation(state)

func advance_one_activation_with_steps(state: Dictionary, include_commit_steps: bool = true) -> Dictionary:
	_advancing = true
	var result: Dictionary = super.advance_one_activation_with_steps(state, include_commit_steps)
	_advancing = false
	return result

func _pop_next_actor(state: Dictionary) -> Dictionary:
	var result: Dictionary = super._pop_next_actor(state)
	# Forecasts and the banner's read-only probe also select actors. Count only
	# activations in the real round, and exclude objective completion on pop.
	if _advancing and combat_outcome(result.get("state", state)) == "":
		activation_kinds.append(str((result.get("entry", {}) as Dictionary).get("kind", "player")))
	return result
