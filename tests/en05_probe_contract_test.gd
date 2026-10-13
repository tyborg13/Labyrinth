extends SceneTree

func _initialize() -> void:
	var probe: Script = load("res://tests/en05_enemies_probe.gd")
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/en05_enemies_probe_contract.json"))
	var valid: bool = probe != null and probe.can_instantiate() and contract["required_images"].size() == 11
	print("EN05 PROBE CONTRACT: %s (script loads; 11 native capture requirements; no renderer capture attempted)" % ("PASS" if valid else "FAIL"))
	quit(0 if valid else 1)
