extends "res://tests/special_encounter_test.gd"

func _initialize() -> void:
	_run_seed_range(Suite.SEED_COUNT / Suite.SEED_PARTS, Suite.SEED_COUNT, false)
