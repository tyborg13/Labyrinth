extends SceneTree

const Graph = preload("res://scripts/section_map_graph.gd")
const TEST_SEED: int = 1
const TEST_SECTION: int = 0

func _initialize() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = TEST_SEED
	var diagnostics: Dictionary = {"enabled": true}
	var reject: Callable = func(_layout: Dictionary, _count: int) -> bool: return false
	var started: int = Time.get_ticks_msec()
	var layout: Dictionary = Graph._section_layout_v5(rng, TEST_SEED, TEST_SECTION, diagnostics, {}, reject)
	var expected_samples: int = Graph.SECTION_ATTEMPTS * Graph.V5_STRUCTURAL_PROPOSALS
	var ok: bool = not layout.is_empty()
	ok = ok and int(diagnostics.get("structural_samples", 0)) == expected_samples
	ok = ok and int(diagnostics.get("structural_exhausted", 0)) == Graph.SECTION_ATTEMPTS
	ok = ok and int(diagnostics.get("solver_nodes", 0)) == 0
	ok = ok and int(diagnostics.get("fallback", 0)) == 1
	if not ok: push_error("Forced structural rejection did not exhaust bounded batches and reach exactly one fallback: " + str(diagnostics))
	print("Section map structural rejection: %s (%d proposals, %d exhausted batches, %dms)" % ["PASS" if ok else "FAIL", expected_samples, int(diagnostics.get("structural_exhausted", 0)), Time.get_ticks_msec() - started])
	quit(0 if ok else 1)
