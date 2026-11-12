extends "res://scripts/combat_board_view.gd"

var proof_intent_rect := Rect2()

func enemy_intent_visual_global_rect(actor_key: String) -> Rect2:
	return proof_intent_rect if proof_intent_rect.has_area() else super.enemy_intent_visual_global_rect(actor_key)

var slot_placements: int = 0

func _place_targeted_tile_floor_layer() -> void:
	slot_placements += 1
	super._place_targeted_tile_floor_layer()
