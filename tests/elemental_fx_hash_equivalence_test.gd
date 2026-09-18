extends SceneTree
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Fx = preload("res://scripts/elemental_spell_fx.gd")
const Reference = preload("res://tests/fixtures/elemental_spell_fx_reference.gd")
func _initialize() -> void:
	Runtime.apply_from_environment()
	var samples: Array[int]
	for seed: int in range(-32, 2080): samples.append(seed)
	samples.append_array([-1000000, 99999, 1000000])
	for seed: int in samples:
		assert(Fx._hash(seed) == Reference._hash(seed), "Cold hash fallback is exact")
	Fx._prepare_particle_hashes()
	assert(Fx._particle_hashes.size() == 1024, "Procedural hash memory is fixed at 8 KiB")
	for seed: int in samples:
		assert(Fx._hash(seed) == Reference._hash(seed), "Cached and out-of-range values retain exact float64 arithmetic")
	var totals: Dictionary = {}
	for variant: String in ["reference", "candidate", "candidate_repeat", "reference_repeat"]:
		var started: int = Time.get_ticks_usec()
		var sum: float = 0.0
		for repeat: int in range(400):
			for seed: int in range(512):
				sum += Reference._hash(seed) if variant.begins_with("reference") else Fx._hash(seed)
		totals[variant] = {"usec": Time.get_ticks_usec() - started, "checksum": sum}
	assert(totals["reference"]["checksum"] == totals["candidate"]["checksum"])
	for seed: int in range(-10, 2048): Fx._rock_shape(seed)
	assert(Fx._rock_shapes.size() == 32 and not Fx._rock_shapes.has(32) and not Fx._rock_shapes.has(-1), "Rock coefficients stay bounded to authored spell seeds")
	print("FX HASH RESULT: " + JSON.stringify({"equivalence_cases": samples.size() * 2, "timings": totals}))
	print("TEST RESULT: PASS")
	quit()
