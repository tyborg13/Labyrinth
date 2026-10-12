extends SceneTree
const Suite = preload("res://tests/suites/section_map_v2_suite.gd")
const PROOF_CONTRACT_PATH: String = "/private/tmp/labyrinth-inspection-manifests/map-01-visual-contract.json"
const PROOF_IMAGE_SIZE: Vector2i = Vector2i(1920, 1080)
var failures: Array[String] = []
func _initialize() -> void:
	_write_visual_contract()
	if OS.get_cmdline_user_args().has("--proof-contract-only"):
		quit(0)
		return
	Suite.run(func(ok: bool, message: String) -> void:
		if not ok and not failures.has(message): failures.append(message)
	)
	for failure: String in failures: push_error(failure)
	print("Section map v2 suite: %d failures (64 seeds x 6 sections)" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _write_visual_contract() -> void:
	var required: Array[Dictionary] = []
	for filename: String in ["01_entry.png", "02_three_rooms.png", "02b_available_pulse.png", "02c_reduced_motion.png", "03_focus.png", "03b_unknown_targeting.png", "04_scouted.png", "04b_scout_exhausted.png", "05_history.png", "domain_5_fog.png"]:
		required.append({"pattern": "*" + filename, "width": PROOF_IMAGE_SIZE.x, "height": PROOF_IMAGE_SIZE.y})
	for index: int in range(6):
		required.append({"pattern": "*domain_%d.png" % index, "width": PROOF_IMAGE_SIZE.x, "height": PROOF_IMAGE_SIZE.y})
	var contract: Dictionary = {"min_images": required.size(), "expected_sizes": ["1920x1080"], "required_images": required}
	DirAccess.make_dir_recursive_absolute(PROOF_CONTRACT_PATH.get_base_dir())
	var file: FileAccess = FileAccess.open(PROOF_CONTRACT_PATH, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write section map visual proof contract")
		failures.append("Visual proof contract writes successfully")
		return
	file.store_string(JSON.stringify(contract, "\t"))
	print("Section map v2 visual proof contract: " + PROOF_CONTRACT_PATH)
