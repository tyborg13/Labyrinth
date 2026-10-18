extends "res://tests/helpers/counted_program.gd"

const Suite = preload("res://tests/suites/section_map_v5_suite.gd")
const PARTITION_COUNT: int = 2

func _initialize() -> void:
	_expect(Suite.LEGACY_SEED_COUNT % PARTITION_COUNT == 0, "Legacy seed partitions cover the complete fixed sweep")
	var count: int = int(Suite.LEGACY_SEED_COUNT / PARTITION_COUNT)
	var first_seed: int = 1 + _partition_index() * count
	Suite._test_legacy_hashes(Callable(self, "_expect"), count, first_seed)
	_finish("SECTION MAP LEGACY HASHES PROGRAM RESULT")

func _partition_index() -> int:
	return 0
