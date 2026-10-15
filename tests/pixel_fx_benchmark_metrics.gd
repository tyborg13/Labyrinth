extends RefCounted

const MIN_GPU_SAMPLE_RATIO: float = 0.9

static func stats(values: Array) -> Dictionary:
	if values.is_empty(): return {"mean_ms": 0.0, "median_ms": 0.0, "p95_ms": 0.0, "samples": 0}
	var sorted: Array = values.duplicate()
	sorted.sort()
	var total: float = 0.0
	for value: float in sorted: total += value
	return {"mean_ms": total / sorted.size(), "median_ms": (float(sorted[(sorted.size() - 1) / 2]) + float(sorted[sorted.size() / 2])) * 0.5, "p95_ms": sorted[ceili(sorted.size() * 0.95) - 1], "samples": sorted.size()}

static func summarize(samples: Dictionary, metric: String) -> Dictionary:
	var off: Array[float]
	var on: Array[float]
	var deltas: Array[float]
	for index: int in range(samples["off"].size()):
		var a: float = samples["off"][index][metric]
		var b: float = samples["on"][index][metric]
		var valid_a: bool = metric != "gpu" or (is_finite(a) and a > 0.0)
		var valid_b: bool = metric != "gpu" or (is_finite(b) and b > 0.0)
		if valid_a: off.append(a)
		if valid_b: on.append(b)
		if valid_a and valid_b: deltas.append(b - a)
	return {"off": stats(off), "on": stats(on), "paired_delta": stats(deltas)}

static func gpu_verdict(gpu: Dictionary, sample_pairs: int, budget_ms: float, gate_budget: bool) -> Dictionary:
	var required: int = ceili(sample_pairs * MIN_GPU_SAMPLE_RATIO)
	var valid: bool = int(gpu["off"]["samples"]) >= required and int(gpu["on"]["samples"]) >= required
	return {"valid_samples": valid, "minimum_nonzero_samples_per_variant": required,
		"budget_applies": gate_budget, "passed": valid and (not gate_budget or float(gpu["paired_delta"]["median_ms"]) <= budget_ms)}
