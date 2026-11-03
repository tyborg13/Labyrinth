extends "res://tools/rebake_cutout_rests.gd"

## Promotion changes the assembly even if density cleanup changes zero texels.
## Always rebake both Chainbound Gaoler views; never certify this from a headless run.
func _initialize() -> void:
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	super._initialize()

func _parts_changed(entry: Dictionary, _facing: String) -> bool:
	return str(entry["id"]) == "ashen_reaver_cutout"


func _run() -> void:
	if OS.get_cmdline_user_args().has("--check-only"):
		var errors: Array[String]
		for view: String in ["front", "rear"]:
			var rig := preload("res://assets/units/ashen_reaver_cutout/rig.gd").new()
			rig.facing = view
			root.add_child(rig)
			if not rig.load_rig(): errors.append(str(rig.load_errors))
			rig.apply_pose("rest", 0.0)
			rig.free()
		print("RR48 REST REBAKE LOAD: %s (headless; no native pixels)" % ["PASS" if errors.is_empty() else "FAIL"])
		quit(0 if errors.is_empty() else 1)
		return
	if DisplayServer.get_name() == "headless":
		push_error("RR48 rest rebake requires the director's windowed renderer")
		quit(1)
		return
	await super._run()

