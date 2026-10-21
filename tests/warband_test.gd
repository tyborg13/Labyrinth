extends SceneTree
const Suite = preload("res://tests/suites/warband_suite.gd")
var failures: Array[String]
const OPENING_DAMAGE_REPORT_FLAG: String = "--opening-damage-report"
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var report_index: int = args.find(OPENING_DAMAGE_REPORT_FLAG)
	var report: Dictionary = Suite.run(_expect, report_index >= 0)
	if report_index >= 0:
		if report_index + 1 >= args.size():
			_expect(false, OPENING_DAMAGE_REPORT_FLAG + " needs an output path")
		else:
			var file := FileAccess.open(args[report_index + 1], FileAccess.WRITE)
			_expect(file != null, "Opening damage report output must be writable")
			if file != null:
				file.store_string(JSON.stringify(report, "\t") + "\n")
				file.close()
				print("Warband opening damage report: " + args[report_index + 1])
	for failure: String in failures: push_error(failure)
	print("Warband suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)
