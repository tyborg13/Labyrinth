extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/start_room_map_suite.gd")
const PROOF_CONTRACT_PATH: String = "/private/tmp/labyrinth-inspection-manifests/ux-01-start-room-map-contract.json"
const PROOF_IMAGE_SIZE: Vector2i = Vector2i(1920, 1080)
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_write_visual_contract()
	if OS.get_cmdline_user_args().has("--proof-contract-only"):
		quit(0)
		return
	_run.call_deferred()

func _run() -> void:
	Suite.run(Callable(self, "_expect"))
	await Suite.run_live(self, Callable(self, "_expect"))
	for failure: String in failures: push_error(failure)
	print("START ROOM MAP RESULT: %d failures" % failures.size())
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: failures.append(message)

func _write_visual_contract() -> void:
	var required: Array[Dictionary]
	for filename: String in ["01_narration.png", "02_auto_map.png", "03_travel_started.png", "04_close_hint.png", "05_controller_focus.png", "06_controller_hint.png"]:
		required.append({"pattern": "*" + filename, "width": PROOF_IMAGE_SIZE.x, "height": PROOF_IMAGE_SIZE.y})
	var contract: Dictionary = {"min_images": required.size(), "expected_sizes": ["1920x1080"], "required_images": required}
	DirAccess.make_dir_recursive_absolute(PROOF_CONTRACT_PATH.get_base_dir())
	var file := FileAccess.open(PROOF_CONTRACT_PATH, FileAccess.WRITE)
	if file == null:
		_expect(false, "Visual proof contract writes successfully")
		return
	file.store_string(JSON.stringify(contract, "\t"))
	print("START ROOM MAP PROOF CONTRACT: " + PROOF_CONTRACT_PATH)
