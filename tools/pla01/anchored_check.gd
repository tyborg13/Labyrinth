extends SceneTree
# pla-01 scratch evidence (not a test): do Push and Pull move the anchored enemies?
const Suite = preload("res://tests/suites/forced_movement_suite.gd")

func _initialize() -> void:
	var combat := preload("res://scripts/combat_engine.gd").new()
	for type: String in ["crawler", "gale_herald", "gallows_roc"]:
		var enemy: Dictionary = Suite._enemy(1, Vector2i(4, 4))
		enemy["type"] = type
		var state: Dictionary = Suite._state(combat, [enemy])
		var pushed: Dictionary = combat._force_move_actor(state.duplicate(true), "enemy", 1, Vector2i.RIGHT, 2, {}, true)
		var pulled: Dictionary = combat._force_move_actor(state.duplicate(true), "enemy", 1, Vector2i.LEFT, 2, {}, false)
		print("PLA01 ANCHORED %s: push %s -> %s, pull %s -> %s, card legal %s" % [type, enemy["pos"], Suite._unit(pushed, 1)["pos"], enemy["pos"], Suite._unit(pulled, 1)["pos"], combat._force_action_affects_enemy(state, 0, {"type": "push", "amount": 2}, Vector2i(3, 4))])
	quit(0)
