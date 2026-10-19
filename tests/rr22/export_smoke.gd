extends Node

const Renderer = preload("res://assets/units/slag_mortar_cutout/renderer.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
const PROOF_PHASE: float = 0.3
var failures: Array[String]

func _ready() -> void:
	if DirAccess.dir_exists_absolute("res://experiments") or DirAccess.dir_exists_absolute("res://tools"):
		failures.append("Authoring sources leaked into production package")
	if Presentation.renderer_script("slag_mortar") != Renderer: failures.append("Production script registry did not resolve")
	if not Presentation.asset_directory("slag_mortar").ends_with("humanoid_v2"): failures.append("Production layout declaration did not resolve")
	var renderer: Node = Presentation.renderer_script("slag_mortar").new()
	add_child(renderer)
	if renderer.rigs.size() != 2: failures.append("Both production views did not load")
	for view: String in renderer.rigs:
		var rig: Node2D = renderer.rigs[view]
		if not rig.load_errors.is_empty(): failures.append(str(rig.load_errors))
		for clip: String in renderer.motion_data()["clips"]:
			rig.apply_pose(clip, PROOF_PHASE)
		if str(rig.layout.get("rig", "")) != "humanoid_v2": failures.append("Wrong production rig")
	for failure: String in failures: push_error(failure)
	print("RR22 PRODUCTION PACK: %s (2 views; source-only PNG loading; editor=%s)" % ["PASS" if failures.is_empty() else "FAIL", OS.has_feature("editor")])
	renderer.queue_free()
	await get_tree().process_frame
	get_tree().quit(0 if failures.is_empty() else 1)
