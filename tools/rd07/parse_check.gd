extends SceneTree
func _initialize() -> void:
	for path: String in ["res://scripts/board_plate_visibility.gd", "res://scripts/intent_badges.gd", "res://scripts/combat_board_view.gd", "res://scripts/turn_order_slots.gd", "res://scripts/run_scene.gd"]:
		var script: Script = load(path)
		if script == null or not script.can_instantiate(): quit(1); return
	print("RD07 RUNTIME PARSE: PASS")
	quit()
