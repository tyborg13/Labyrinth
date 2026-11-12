extends SceneTree

var checks: int = 0
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(_draw_boundary)
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var domain: String = args[args.find("--domain") + 1] if args.has("--domain") else "all"
	if domain in ["all", "hover"]:
		await preload("res://tests/perf/hover_equivalence.gd").run(self, _check)
		_report("hover")
	if domain in ["all", "input"]:
		preload("res://tests/suites/controller_input_suite.gd").run(_check)
		preload("res://tests/suites/card_drag_play_suite.gd").run(_check)
		await preload("res://tests/suites/card_drag_play_suite.gd").run_live(self, _check)
		_report("input")
	if domain in ["all", "shortcut"]:
		var suite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
		suite.run(_check)
		await suite.run_live(self, _check)
		suite.run_visible_terrain(_check)
		await suite.run_visible_terrain_live(self, _check)
		_report("shortcut")
	if domain in ["all", "targeting-audit"]:
		await preload("res://tests/suites/card_targeting_audit_suite.gd").run(self, _check)
		_report("targeting-audit")
	if domain in ["all", "enemy-intent"]:
		var suite = preload("res://tests/suites/enemy_intent_continuity_suite.gd")
		suite.run(_check)
		_report("enemy-intent")
	for failure: String in failures: push_error(failure)
	print("PTF09 FOCUSED: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _report(domain: String) -> void:
	print("PTF09 DOMAIN %s: %d checks, %d cumulative failures" % [domain, checks, failures.size()])

func _draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
