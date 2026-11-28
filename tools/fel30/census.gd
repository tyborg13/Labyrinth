extends SceneTree
## Enter the diagnostic descent after Godot mounts the main pack.

func _initialize() -> void:
	call_deferred("_start")


func _start() -> void:
	var engine: Script = load("res://scripts/combat_engine.gd")
	if engine == null or not engine.can_instantiate() or not engine.new().has_method("_fel30_enemy_count"):
		push_error("FEL30: start with the probe's diagnostic main pack")
		quit(1)
		return
	var script: Script = load("res://tools/fel30/descent.gd")
	if script == null or not script.can_instantiate():
		quit(1)
		return
	var descent: Node = script.new()
	root.add_child(descent)
	descent.start(self)
