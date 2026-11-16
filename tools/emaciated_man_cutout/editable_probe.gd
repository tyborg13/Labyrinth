extends SceneTree
const CaseRig = preload("res://tools/cutout_pipeline/rig.gd")
const CASE: String = "res://experiments/cutouts/emaciated_man/emac02/cutout.json"
const OUTPUT: String = "res://experiments/cutouts/emaciated_man/emac02/proof/front_editable.tscn"
const KEY_TIMES: Array = [0.0, 0.21, 0.84, 1.68, 2.52, 3.15]
var _failed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _check(ok: bool, message: String) -> void:
	if ok: return
	_failed = true
	push_error(message)

func _run() -> void:
	var rig := CaseRig.new()
	root.add_child(rig)
	_check(rig.configure(CASE), "Configure case")
	_check(rig.save_editable(OUTPUT) == OK, "Save editable idle scene")
	var packed: PackedScene = load(OUTPUT) as PackedScene
	_check(packed != null, "Reload editable scene")
	if packed == null:
		quit(1)
		return
	var restored: Node = packed.instantiate()
	root.add_child(restored)
	var player: AnimationPlayer = restored.get_node("Animations")
	for seconds: float in KEY_TIMES:
		rig.apply_pose("idle", seconds / 3.36)
		player.play("idle")
		player.seek(seconds, true)
		for name: String in rig.bones:
			var original: Bone2D = rig.bones[name]
			var replay: Bone2D = restored.get_node(rig.get_path_to(original))
			_check(original.transform.is_equal_approx(replay.transform), "Editable key differs: " + name + " at " + str(seconds))
		for channel: String in rig.get("_ember_overlay").overlays:
			var original: Sprite2D = rig.get("_ember_overlay").overlays[channel]
			var replay: Sprite2D = restored.get_node(rig.get_path_to(original))
			_check(is_equal_approx(float(original.material.get_shader_parameter("pulse_alpha")), float(replay.material.get_shader_parameter("pulse_alpha"))), "Editable glow key differs: " + channel)
	print("EMAC EDITABLE: %s; idle=3.36s; transform_and_glow_keys=6; %s" % ["FAIL" if _failed else "PASS", OUTPUT])
	rig.free()
	restored.free()
	quit(1 if _failed else 0)
