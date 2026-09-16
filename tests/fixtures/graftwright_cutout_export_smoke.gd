extends Node
func _ready() -> void:
	var rig: Node = load("res://scripts/graftwright_cutout/rig.gd").new()
	add_child(rig)
	var passed: bool = not OS.has_feature("editor") and not DirAccess.dir_exists_absolute("res://experiments") and not DirAccess.dir_exists_absolute("res://tools")
	passed = bool(rig.call("load_rig")) and passed
	passed = passed and (rig.get("load_errors") as PackedStringArray).is_empty() and (rig.get("bones") as Dictionary).size() == 5
	for phase: float in [0.0, 0.25, 0.5, 0.75, 1.0]:
		rig.call("apply_pose", "idle", phase)
	for node: Node in rig.find_children("*", "Polygon2D", true, false):
		passed = passed and (node as Polygon2D).texture.get_size() == Vector2(1448, 1448)
	rig.queue_free()
	await get_tree().process_frame
	print("GRAFTWRIGHT CUTOUT EXPORT RUNTIME: " + ("PASS" if passed else "FAIL") + " (editor=" + str(OS.has_feature("editor")) + ")")
	get_tree().quit(0 if passed else 1)
