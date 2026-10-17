extends "res://scripts/run_scene.gd"

# Test-only counters observe the real card-resolution presentation dispatch.
var cbt_01_walk_presentations: int = 0
var cbt_01_blink_presentations: int = 0

func _animate_player_move_path(before_state: Dictionary, after_state: Dictionary, path: Array[Vector2i], presentation: Dictionary) -> void:
	cbt_01_walk_presentations += 1
	await super._animate_player_move_path(before_state, after_state, path, presentation)

func _player_blink_effect(from: Vector2i, to: Vector2i, exchange: Dictionary) -> Dictionary:
	cbt_01_blink_presentations += 1
	return super._player_blink_effect(from, to, exchange)
