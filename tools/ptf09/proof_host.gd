extends "res://tests/card_targeting_audit_host.gd"

## Observe production dispatch without persistence or animated commits.
var committed_tile := Vector2i(-1, -1)
var proof_pointer := Vector2(-1000, -1000)

func _current_mouse_position() -> Vector2:
	return proof_pointer

func _play_player_card(hand_index: int, resolved_state: Dictionary, actions: Array, selected_targets: Array[Vector2i]) -> void:
	# Compound shortcuts include an automatic approach before the player's foe
	# decision. The last target is the same decision tile logged by analytics.
	committed_tile = selected_targets[-1] if not selected_targets.is_empty() else Vector2i(-1, -1)
	super._play_player_card(hand_index, resolved_state, actions, selected_targets)

func _commit_player_movement(target_tile: Vector2i) -> void:
	committed_tile = target_tile
	commits += 1

func _commit_surface_skill_tile(target_tile: Vector2i) -> void:
	if _surface_skill_tiles.has(target_tile):
		committed_tile = target_tile
		commits += 1
