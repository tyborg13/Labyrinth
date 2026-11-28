extends SceneTree
## Focused load check for the diagnostics pack and production scene dependency.

func _initialize() -> void:
	var board: Script = load("res://scripts/combat_board_view.gd")
	var scene: Script = load("res://scripts/run_scene.gd")
	var engine: Script = load("res://scripts/combat_engine.gd")
	var ok: bool = board.can_instantiate() and scene.can_instantiate() and engine.new().has_method("_fel30_enemy_count")
	if ok: print("FEL30 OVERLAY LOAD OK")
	quit(0 if ok else 1)
