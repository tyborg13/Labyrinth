extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board := CombatBoardView.new()
	var enemy: Dictionary = {"id": 1, "type": "crawler", "role": "enemy", "key": "enemy:1", "hp": 10, "petrify": 1}
	for badge: Dictionary in board._unit_status_badges(enemy):
		_expect(badge.get("icon") != "petrify", "A legacy status never renders a Petrify badge")
	enemy["type"] = "iskaldra"
	var traits: Array[Dictionary] = board._unit_status_badges(enemy).filter(
		func(badge: Dictionary) -> bool: return badge.get("icon") == "stagger"
	)
	_expect(traits.size() == 1 and traits[0].get("tooltip") == "Steadfast\nTakes half Stagger.", "A dragon shows the exact Steadfast trait")
	board.free()
	var scene := RunScene.new()
	var entry: Dictionary = {"kind": "enemy", "name": "Crawler", "eta": 3, "stagger_preview": 6}
	_expect(scene._turn_order_projection_badge_text(entry) == "Stagger +6", "The rail labels the projected delay")
	entry["stagger_preview"] = 3
	_expect(scene._turn_order_projection_badge_text(entry) == "Stagger +3", "The rail labels the dragon's halved delay")
	_expect(scene._turn_order_tooltip(entry, 0).is_empty(), "Enemy rail entries retain their tooltip policy")
	_expect(ActionIcons.tooltip("stagger") == "Stagger\nDelay the target's next turn by X Time.", "The Stagger tooltip is one sentence")
	scene.free()
	for failure: String in _failures:
		push_error(failure)
	print("STAGGER BADGE/TURN-ORDER TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d failures)" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
