extends SceneTree

const Batch = preload("res://tests/helpers/program_sub_suite_batch.gd")
const Programs = preload("res://tests/helpers/program_sub_suites.gd")
const BUG_01_PROGRAMS = ["prepared_other_character_view_test", "retained_character_inventory_equivalence_test", "shop_retained_content_test", "static_floor_cache_equivalence_test"]
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var suites: Array[String]
	suites.assign(BUG_01_PROGRAMS)
	Batch.run(suites, _expect, Time.get_ticks_usec(), Programs.SUITE_TIMEOUT_SECONDS, Programs.PROGRAM_BUDGET_SECONDS)
	print("BUG-01 PROGRAM RESULT: %s" % ("PASS" if _errors.is_empty() else "FAIL: " + str(_errors)))
	quit(0 if _errors.is_empty() else 1)

func _expect(ok: bool, message: String) -> void:
	if not ok: _errors.append(message)
