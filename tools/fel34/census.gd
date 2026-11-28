extends SceneTree
## Load the observer after Godot mounts the diagnostic main pack.

func _initialize() -> void:
	call_deferred("_start")

func _start() -> void:
	var engine: Script = load("res://scripts/combat_engine.gd")
	if engine == null or not engine.can_instantiate() or not engine.new().has_method("_fel30_enemy_count"):
		push_error("FEL34: launch with a diagnostic main pack")
		quit(1)
		return
	var replay: Script = load("res://tools/fel34/replay.gd")
	if replay == null or not replay.can_instantiate():
		quit(1)
		return
	var observer: Node = replay.new()
	root.add_child(observer)
	observer.start(self)
