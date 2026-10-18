extends Node

const Renderer = preload("res://assets/units/hoarfrost_seer_cutout/renderer.gd")
const PROOF_PHASE: float = 0.3
var failures: Array[String]

func _ready() -> void:
	if DirAccess.dir_exists_absolute("res://experiments") or DirAccess.dir_exists_absolute("res://tools"):
		failures.append("Authoring sources leaked into production package")
	var renderer := Renderer.new()
	add_child(renderer)
	if renderer.rigs.size() != 2: failures.append("Both production views did not load")
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		if not rig.load_errors.is_empty(): failures.append(str(rig.load_errors))
		for clip: String in renderer.motion_data()["clips"]:
			rig.apply_pose(clip, PROOF_PHASE)
		if str(rig.layout.get("rig", "")) != "humanoid_v2": failures.append("Wrong production rig")
	for failure: String in failures: push_error(failure)
	print("RR10 PRODUCTION PACK: %s (2 views; source-only PNG loading; editor=%s)" % ["PASS" if failures.is_empty() else "FAIL", OS.has_feature("editor")])
	renderer.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
