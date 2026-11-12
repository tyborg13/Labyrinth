extends SceneTree

var checks: int = 0
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	preload("res://scripts/settings_store.gd")._applied_board_health_bars = preload("res://scripts/settings_store.gd").BOARD_HEALTH_ALWAYS
	preload("res://tests/suites/board_status_plates_suite.gd").run(_check)
	preload("res://tests/suites/board_status_feedback_suite.gd").run(_check)
	await preload("res://tests/suites/board_status_cache_suite.gd").run(_check)
	preload("res://tests/suites/intent_chip_placement_suite.gd").run(_check)
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_check)
	preload("res://tests/suites/initiative_order_suite.gd").run(_check)
	await preload("res://tests/suites/turn_clock_hud_suite.gd").run(self, _check)
	preload("res://scripts/settings_store.gd")._applied_board_health_bars = preload("res://scripts/settings_store.gd").BOARD_HEALTH_ALWAYS
	await preload("res://tests/perf/hover_equivalence.gd").run(self, _check)
	preload("res://tests/settings_probe.gd").verify_board_health_settings(_check)
	for failure: String in failures: push_error(failure)
	print("RD08 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
