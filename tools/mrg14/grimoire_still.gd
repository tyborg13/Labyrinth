extends "res://tools/ux18/proof.gd"

func _run() -> void:
	_router = root.get_node("InputRouter")
	var profile: Dictionary = _profile("played")
	_prepare_files(profile)
	await _title_case("played", profile, false)
	_router.call("clear_forced_state_for_test")
	print("MRG-14 GRIMOIRE STILL: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _capture(label: String, resolution: Vector2i) -> void:
	if label == "title_pointer" or label == "title_sections":
		await super._capture(label, resolution)
