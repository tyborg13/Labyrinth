extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/vaeloryx_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor") and not DirAccess.dir_exists_absolute("res://experiments") and not DirAccess.dir_exists_absolute("res://tools")
	var wind: Script = load("res://scripts/vaeloryx_cutout/wind_feedback.gd") as Script
	passed = passed and wind != null and bool(wind.call("handles", {"enemy_type": "vaeloryx", "kind": "pull"}))
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 15
		for clip: String in ["idle", "walk", "dive", "gale", "pull", "guard"]:
			rig.call("apply_pose", clip, 0.42)
	renderer.queue_free()
	await get_tree().process_frame
	print("VAELORYX CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)
