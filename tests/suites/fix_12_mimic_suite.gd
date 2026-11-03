extends RefCounted

const Fixtures = preload("res://tests/suites/en06_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
# Test-only reproduction from the round-0 investigation.
const START := Vector2i(2, 4)
const MID := Vector2i(3, 4)
const ARRIVAL := Vector2i(4, 4)
const HERO := Vector2i(5, 4)
const WALL := Vector2i(6, 4)
const TRAP_DAMAGE: int = 1
const COLLISION_DAMAGE: int = 2
const COPIED_CARD: String = "quick_stab"
const MODES: Array = ["firing", "shocked", "out_of_range"]

static func state_for(mode: String = "firing", hazard: bool = true) -> Dictionary:
	var state: Dictionary = Fixtures.mirror(COPIED_CARD, START, HERO)
	if hazard: state["traps"] = [{"id": "fix_12_mimic_air", "pos": ARRIVAL, "element": "air", "damage": TRAP_DAMAGE}]
	if mode == "out_of_range":
		# The Air trap pushes the hero outside the copied melee range, onto a
		# second trap. Its injury belongs entirely to the approach move.
		state["traps"].append({"id": "fix_12_mimic_fire", "pos": WALL, "element": "fire", "damage": TRAP_DAMAGE})
	else: state["grid"][WALL.y][WALL.x] = "wall"
	if mode == "shocked": state["enemies"][0]["shock"] = 1
	return state

static func action(phase: Dictionary) -> Dictionary:
	for step: Dictionary in phase["steps"]:
		if str(step.get("action_type", "")) == "ranged": return step
	return {}

static func copied_damage(state: Dictionary) -> int:
	return int(state["enemies"][0]["intent"]["actions"][0]["damage"])

static func hp_loss(losses: Array, key: String) -> int:
	var total: int = 0
	for loss: Dictionary in losses:
		if str(loss.get("key", "")) == key: total += int(loss.get("hp_loss", 0))
	return total

static func run(expect: Callable) -> void:
	preload("res://tests/suites/mim01_suite.gd").run(expect)
