extends Node
## Entry scene for the isolated PCK test, run by an unmodified export template.
func _ready() -> void:
	var renderer_script: Script = load("res://scripts/harrier_cutout/renderer.gd") as Script
	var renderer: Node = renderer_script.new()
	add_child(renderer)
	var passed: bool = not OS.has_feature("editor") and not DirAccess.dir_exists_absolute("res://experiments") and not DirAccess.dir_exists_absolute("res://tools")
	for facing: String in ["front", "rear"]:
		var rig: Node = renderer.get("rigs")[facing]
		passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 18
		for clip: String in ["idle", "walk", "retreat", "attack", "cast"]:
			rig.call("apply_pose", clip, 0.42)
	var action: Script = load("res://scripts/harrier_cutout/action.gd") as Script
	if action != null and action.can_instantiate():
		var cast: Dictionary = action.call("motion_for_effect", {"kind":"ranged", "from":Vector2i(3,3), "to":Vector2i(3,5)}, 0.18)
		passed = passed and is_equal_approx(float(cast.get("phase", -1.0)), 0.55) and bool(cast.get("authored_phase", false))
	else:
		passed = false
	var texture_id: int = renderer.call("texture").get_instance_id()
	for direction: Vector2i in [Vector2i(0,1),Vector2i(1,0),Vector2i(0,-1),Vector2i(-1,0)]:
		renderer.call("present",{"clip":"attack","family":"ranged","phase":0.55,"authored_phase":true,"direction":direction},false)
		passed = passed and renderer.call("snapshot")["clip"] == "cast" and renderer.call("texture").get_instance_id() == texture_id
		passed = passed and (renderer.call("source_release_socket",direction) as Vector2).is_finite()
	renderer.queue_free()
	await get_tree().process_frame
	print("HARRIER CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)
