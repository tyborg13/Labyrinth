extends "res://tests/section_map_v2_test.gd"

## The remaining deterministic seeds; ancillary cases and contract I/O belong
## to the first partition. The main body still invokes the complete suite.
func _initialize() -> void:
	_run_seed_range(Suite.SEED_COUNT / Suite.SEED_PARTS, Suite.SEED_COUNT, false)
