extends SceneTree

var checks := 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	await preload("res://tests/perf/hover_equivalence.gd").run(self, _check)
	print("RD06 HOVER: %d checks, %d failures" % [checks, failures.size()])
	preload("res://tests/suites/enemy_intent_continuity_suite.gd").run(_check)
	print("RD06 HOVER + ENEMY INTENT: %d checks, %d failures" % [checks, failures.size()])
	for failure: String in failures: push_error(failure)
	quit(0 if failures.is_empty() else 1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
