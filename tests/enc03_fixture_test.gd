extends "res://tests/enc03_lob_probe.gd"

func _initialize() -> void:
	check_only = true
	if OS.get_cmdline_user_args().has("--old-data"):
		preload("res://scripts/game_data.gd").enemies()["slag_mortar"] = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/enc03_slag_before.json"))
	super._initialize()
