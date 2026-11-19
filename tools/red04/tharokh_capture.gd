extends "res://tools/qa110/interruptions.gd"

const Pair = preload("res://tools/red04/red_audit.gd")

func capture(label: String, viewport: Viewport = null) -> void:
	var before: bool = OS.get_cmdline_user_args().has("--before")
	var receipt: Dictionary = Pair.repro(scene, true, before)
	check(receipt["ok"], "Tharokh's settled footprint matches the requested red-04 witness")
	print("RED04 THAROKH REPRO: " + JSON.stringify(receipt))
	var file := FileAccess.open(output.path_join("red04.json"), FileAccess.WRITE)
	check(file != null, "write Tharokh proof receipt")
	if file != null:
		file.store_string(JSON.stringify(receipt, "  "))
		file.close()
	await super.capture(label, viewport)
