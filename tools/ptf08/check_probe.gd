extends SceneTree

# Compile the windowed probe without executing its renderer entry point.
func _initialize() -> void:
	var script: Script = load("res://tools/ptf08/forecast_probe.gd")
	var movie: Script = load("res://tools/ptf08/movement_capture.gd")
	var actions: Script = load("res://tools/ptf08/action_capture.gd")
	var ok: bool = script != null and script.can_instantiate() and movie != null and movie.can_instantiate() and actions != null and actions.can_instantiate()
	print("PTF08 PROBE COMPILE: %s" % ("PASS" if ok else "FAIL"))
	quit(0 if ok else 1)
