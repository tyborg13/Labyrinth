extends "res://tests/event_rules_test.gd"

## Independent matrix partition; the same helper and assertions also remain
## available through the unpartitioned event_rules_test entry point.
func _run() -> void:
	preload("res://tests/helpers/event_preview_checks.gd")._exhaustive(preload("res://scripts/run_engine.gd").new(), func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("Event preview matrix suite: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)
