extends RefCounted

const Base = preload("res://tests/suites/fix_12_suite.gd")
const Owners = preload("res://tests/suites/fix_14_owner_matrix_cases.gd")
# Reviewer reproductions and debug-only geometry, never gameplay tuning.
const LETHAL_HP: int = 1
const RESTORED_HP: int = 8
const CHARGES: int = 1
const RETALIATE_AMOUNT: int = 2
const MIMIC_DAMAGE: int = 6

static func _enable(state: Dictionary) -> void:
	state["defiance_capacity"] = CHARGES
	state["defiance_remaining"] = CHARGES

static func _revival(phase: String, source_id: int, loss: int) -> Dictionary:
	return {"phase": phase, "source_id": source_id, "revision": 1, "restored_hp": RESTORED_HP, "lethal_hp_loss": loss}

static func cases() -> Array[Dictionary]:
	# Both Tether and Mirror compound fixtures are retired.
	var result: Array[Dictionary]
	return result
