extends "res://tests/brs02_test.gd"

const PROOF_DIR: String = "/private/tmp/labyrinth_codex/brs-02/proof"
const PROOF_CONTRACT: String = "res://tests/proof_contracts/brs02.json"
const CAPTURE_SETTLE_FRAMES: int = 2
var _output_dir: String = PROOF_DIR

func _initialize() -> void:
	if OS.get_cmdline_user_args().has("--check-only"):
		var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(PROOF_CONTRACT))
		assert(contract["expected_sizes"] == ["1920x1080"] and int(contract["min_images"]) == 14)
		print("BRS02 PROBE CONTRACT: PASS (1920x1080; 100% UI scale; normal and reduced motion)")
		quit()
		return
	if DisplayServer.get_name() == "headless":
		push_error("BRS02 native capture requires a windowed renderer")
		quit(1)
		return
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output-dir="): _output_dir = argument.trim_prefix("--output-dir=")
	DirAccess.make_dir_recursive_absolute(_output_dir)
	super._initialize()

func _configure_scene(scene: Playback) -> void:
	root.content_scale_factor = 1.0
	var settings: Dictionary = scene.get("_settings").duplicate(true)
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["combat_speed"] = "normal"
	preload("res://scripts/settings_store.gd").apply_settings(settings, root, false)
	scene._on_settings_changed(settings)
	scene.proof_output_dir = _output_dir

func _finish_proof(scene: Playback) -> void:
	for frame: int in range(CAPTURE_SETTLE_FRAMES): await process_frame
	var file := FileAccess.open(_output_dir.path_join("proof.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"captures": scene.captures, "failures": failures, "checks": checks}, "\t"))
	print("BRS02 PROOF: " + _output_dir.path_join("proof.json"))
