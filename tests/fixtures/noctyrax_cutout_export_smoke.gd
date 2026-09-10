extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/noctyrax_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor") and not DirAccess.dir_exists_absolute("res://experiments") and not DirAccess.dir_exists_absolute("res://tools")
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 22
		for clip: String in ["idle","walk","claw","breath","coil","eclipse"]:
			rig.call("apply_pose", clip, 0.42)
	renderer.queue_free()
	await get_tree().process_frame
	print("NOCTYRAX CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)
