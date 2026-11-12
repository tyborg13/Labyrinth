extends "res://tools/rd05/plate_visibility_proof.gd"

# Keep the protected rd-05 proof intact. Its cross-setting chip-equality
# assertion predates rd-07's explicitly different contextual placement. Replace
# only that assertion with the owner's new exact anchor contract; all other
# original visibility, aim, change-hold, input, rail and idle checks still run.
func _check(ok: bool, message: String) -> void:
	if message == "Intent chip geometry unchanged across settings":
		var measured: Array = Badges.layouts(board, board.presentation.get("threats_at_rest", {}).get("badges", []))
		var by_key: Dictionary = board.call("_units_by_key", board.call("_visible_units"))
		var valid: bool = not measured.is_empty()
		for badge: Dictionary in measured:
			valid = valid and bool(badge.get("contextual", false)) and badge.center == preload("res://scripts/intent_chip_placement.gd").compact_anchor(board, by_key[badge.key])
		super._check(valid, "rd-07 replaces cross-setting chip equality with exact contextual anchors")
		print("RD05 ADAPTATION: cross-setting chip equality superseded by rd-07 exact contextual anchor contract")
	else: super._check(ok, message)

func _finish() -> void:
	var file := FileAccess.open("/private/tmp/labyrinth_codex/rd-07/rd05-regression.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures, "evidence": evidence}, "\t"))
	for failure: String in failures: push_error(failure)
	print("RD05 RD07 REGRESSION: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	if is_instance_valid(scene): scene.queue_free(); await process_frame
	quit(0 if failures.is_empty() else 1)
