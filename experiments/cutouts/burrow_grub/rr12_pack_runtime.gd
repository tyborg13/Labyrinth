extends Node

## Run only from the isolated PCK with the unchanged official export template.
const Presentation = preload("res://scripts/maquette_cutout_runtime/presentation.gd")
var failures: Array[String]
var checks: int = 0

func _ready() -> void:
	check(not OS.has_feature("editor"), "Official non-editor runtime")
	check(not DirAccess.dir_exists_absolute("res://experiments"), "No experiment tree")
	check(not DirAccess.dir_exists_absolute("res://tools"), "No tool tree")
	for creature: String in ["burrow_grub", "ember_tick"]:
		var renderer: Node = Presentation.renderer_script(creature).new()
		add_child(renderer)
		await get_tree().process_frame
		var texture: Texture2D = renderer.texture()
		check(texture != null, creature + " persistent texture")
		for view: String in ["front", "rear"]:
			var rig: Node2D = renderer.rigs[view]
			check(rig.load_errors.is_empty(), creature + " " + view + " painted rig loads")
			for clip: String in renderer.motion_data()["clips"]:
				for phase: float in [0.0, 0.35, 0.5, 1.0]:
					rig.apply_pose(clip, phase)
					for bone: String in rig.bones:
						check(rig.bones[bone].transform.is_finite(), creature + " packed bone " + bone)
		check(renderer.texture() == texture, creature + " retains texture")
		renderer.queue_free()
		await get_tree().process_frame
	for error: String in failures: push_error(error)
	print("RR12 PACKAGE RUNTIME: %s (%d checks; editor=%s)" % ["PASS" if failures.is_empty() else "FAIL", checks, str(OS.has_feature("editor"))])
	get_tree().quit(0 if failures.is_empty() else 1)

func check(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
