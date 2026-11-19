extends "res://tools/atk06/capture.gd"

const Pair = preload("res://tools/red04/red_audit.gd")
var receipt: Dictionary

func _prepare_frame(scene: Node, _board: Control, _target: String) -> void:
	receipt = Pair.repro(scene, false, OS.get_cmdline_user_args().has("--before"))
	_check(receipt["ok"], "Walk (2,5) settled footprint matches the requested red-04 witness")
	print("RED04 WALK REPRO: " + JSON.stringify(receipt))

func _proof_fields() -> Dictionary:
	return {"red04": receipt}
