extends SceneTree

var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	preload("res://tests/suites/combat_board_layout_suite.gd").run(_check)
	preload("res://tests/suites/actor_presentation_suite.gd").run(_check)
	preload("res://tests/suites/cutout_render_gate_suite.gd").run(self, _check)
	await preload("res://tests/suites/vyraketh_cutout_suite.gd").run(self, _check)
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_check)
	for failure: String in failures: push_error(failure)
	print("RD02 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
