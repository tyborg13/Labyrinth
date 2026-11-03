extends RefCounted

const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const RunScene = preload("res://scripts/run_scene.gd")
# Shared loss helpers and the retained Hollow Mimic approach regressions.
const TRAP_DAMAGE: int = 1

static func hp_loss(losses: Array, key: String) -> int:
	var total: int = 0
	for loss: Dictionary in losses:
		if str(loss.get("key", "")) == key: total += int(loss.get("hp_loss", 0))
	return total


static func run(expect: Callable) -> void:
	preload("res://tests/suites/fix_12_mimic_suite.gd").run(expect)
