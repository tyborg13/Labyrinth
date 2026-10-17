extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const TEST_SEED: int = 1
const TEST_SECTION: int = 0
const FORCED_NODE_BUDGET: int = 0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(TEST_SEED * 7919 + TEST_SECTION * 104729 + 3491)
	var stats: Dictionary = {"enabled": true}
	Graph._section_layout_v5(rng, TEST_SEED, TEST_SECTION, stats, {}, Callable(), FORCED_NODE_BUDGET)
	var exhausted: int = int(stats.get("solver_budget_exhausted", 0))
	var structural: int = int(stats.get("structural_exhausted", 0))
	var legal: bool = exhausted > 0 and exhausted + structural == Graph.SECTION_ATTEMPTS and int(stats.get("fallback", 0)) == 1 and int(stats.get("solver_nodes", 0)) == 0 and int(stats.get("solver_unsatisfiable", 0)) == 0
	print("Section map type rejection: %s (%d budget-exhausted, %d structural-exhausted, %d fallback)" % ["PASS" if legal else "FAIL", exhausted, structural, int(stats.get("fallback", 0))])
	quit(0 if legal else 1)
