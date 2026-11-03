extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Mimic = preload("res://tests/suites/fix_12_mimic_suite.gd")
const Owners = preload("res://tests/suites/fix_14_owner_matrix_cases.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
# Shared Mimic/Retaliate board ownership, with test-only geometry.
const OOZE_ID: int = 3
const OOZE_HP: int = 1
const DIRECT_ACTOR := Vector2i(3, 3)
const CHARGE_HERO := Vector2i(4, 3)
const MIMIC := Vector2i(4, 4)
const MIMIC_HERO := Vector2i(5, 4)
const MIMIC_OOZE := Vector2i(3, 4)
const RETALIATE_DAMAGE: int = 2
const RETALIATE_PUSH: int = 1
const STATUS_COUNTER: int = 1
const DROPLETS: int = 2
const NEWBORN_SPAWN_HP: int = 4
const NONLETHAL_TRAP_DAMAGE: int = 1
const NEWBORN_TRAP_TILE := Vector2i(3, 3)
const DUMMY_TILE := Vector2i(1, 1)

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result
