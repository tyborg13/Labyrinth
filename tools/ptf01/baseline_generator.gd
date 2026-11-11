extends "res://scripts/room_generator.gd"
## Proof only: restores the original depth-tier picker and unrestricted expansion.
## Same RNG calls, weights, history and global max_units as the pre-change code.
func generate_room(run_seed: int, room: Dictionary, travel_dir: Vector2i) -> Dictionary:
	var old_room: Dictionary = room.duplicate(true)
	old_room["encounter_legacy"] = true
	return super.generate_room(run_seed, old_room, travel_dir)
