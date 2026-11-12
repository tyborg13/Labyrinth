extends SceneTree

# Compile the windowed probe without executing its renderer entry point.
func _initialize() -> void:
	var script: Script = load("res://tools/ptf07/forecast_probe.gd")
	var ok: bool = script != null and script.can_instantiate()
	print("PTF07 PROBE COMPILE: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
