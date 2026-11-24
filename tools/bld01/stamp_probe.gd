extends SceneTree

const BuildInfo = preload("res://scripts/build_info.gd")

func _initialize() -> void:
	var expected: String = OS.get_cmdline_user_args()[0]
	var actual: String = BuildInfo.label_text()
	if actual != expected:
		push_error("BLD01 expected %s, got %s" % [expected, actual])
		quit(1)
		return
	print("BLD01 STAMP LABEL: " + actual)
	quit()
