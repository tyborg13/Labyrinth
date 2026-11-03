extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ManeuverRules = preload("res://scripts/maneuver_rules.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const STATUS_TOOLTIP: String = "Petrified: skips its next turn (still paying its Time) and has 5 Block through your next turn. Dragons are immune."
const QUEUED_TOOLTIP: String = "Petrified: skips this turn (still costs its Time)"

var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var board := CombatBoardView.new()
	var enemy: Dictionary = {"id": 1, "type": "crawler", "role": "enemy", "key": "enemy:1", "petrify": 1, "block": 5}
	var badges: Array[Dictionary] = board._unit_status_badges(enemy)
	var petrified_badges: int = 0
	for badge: Dictionary in badges:
		if badge.get("icon") == "petrify":
			petrified_badges += 1
			_expect(badge.get("tooltip") == STATUS_TOOLTIP and badge.get("tooltip") == ManeuverRules.petrified_tooltip(), "The enemy badge uses the shared exact Petrified status wording")
	_expect(petrified_badges == 1, "The enemy has exactly one Petrified badge")
	enemy["petrify"] = 0
	for badge: Dictionary in board._unit_status_badges(enemy):
		_expect(badge.get("icon") != "petrify", "An enemy without Petrify has no Petrified badge")
	board.free()
	var scene := RunScene.new()
	var entry: Dictionary = {"kind": "enemy", "name": "Crawler", "eta": 3, "petrified": true}
	var lines: PackedStringArray = str(scene._turn_order_tooltip(entry, 0)).split("\n")
	_expect(lines.count(QUEUED_TOOLTIP) == 1 and QUEUED_TOOLTIP == ManeuverRules.petrified_tooltip(true), "The turn-order tooltip uses the shared exact queued-turn wording once")
	_expect(not lines.has(STATUS_TOOLTIP), "The turn-order tooltip stays specific to the queued turn")
	entry["petrified"] = false
	_expect(not scene._turn_order_tooltip(entry, 0).contains("Petrified"), "An unpetrified queued turn has no Petrified tooltip line")
	scene.free()
	for failure: String in _failures:
		push_error(failure)
	print("PETRIFY BADGE/TURN-ORDER TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL (%d failures)" % _failures.size()))
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
