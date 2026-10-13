extends SceneTree

func _initialize() -> void:
	var probe: Script = load("res://tests/en05_enemies_probe.gd")
	var contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/en05_enemies_probe_contract.json"))
	var valid: bool = probe != null and probe.can_instantiate() and contract["required_images"].size() == 11 and str(probe.get_script_constant_map().get("OUTPUT_ROOT", "")).begins_with("user://")
	print("EN05 PROBE CONTRACT: %s (script loads; 11 native capture requirements; no renderer capture attempted)" % ("PASS" if valid else "FAIL"))
	var threats_probe: Script = load("res://tests/threats_at_rest_probe.gd")
	var threats_contract: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/threats_at_rest_probe_contract.json"))
	var threats_valid: bool = threats_probe != null and threats_probe.can_instantiate() and threats_contract["min_images"] == 13 and threats_contract["required_images"].size() == 13
	print("WAVE E2 THREATS PROBE CONTRACT: %s (script loads; 13 native capture requirements; no renderer capture attempted)" % ("PASS" if threats_valid else "FAIL"))
	quit(0 if valid and threats_valid else 1)
