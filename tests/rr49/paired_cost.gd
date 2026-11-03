extends RefCounted

## Match exact poses across live production, its generic fallback and the
## independently frozen optimized submission. No participant reuses a cache.
const StableSkin = preload("res://scripts/maquette_cutout_runtime/stable_skin.gd")
const Reference = preload("res://tests/rr49/reference_submission.gd")
const MINIMUM_SPEEDUP: float = 1.6
const MAXIMUM_REFERENCE_FACTOR: float = 1.3
const REFERENCE_FACTOR_PERCENTILE: float = 0.9
const PAIR_ROUNDS: int = 3
const WARMUP_POSES: int = 3
const IMPLEMENTATIONS: int = 3

static func measure(rig: Node2D, clips: Array[String], pose_count: int, sample: Callable) -> Dictionary:
	var optimized: Dictionary = {}
	var fallback: Dictionary = {}
	var reference: Dictionary = {}
	var reference_paint: GDScript = Reference.paint_script()
	for node: Node in rig.get_children():
		if not node.has_meta("stable_skin"): continue
		optimized[node] = node.get_meta("stable_skin")
		var skin: RefCounted = StableSkin.new(node.get_meta("stable_source"), rig.layout["joints"])
		for group: Dictionary in skin.singles: group["indices"] = PackedInt32Array()
		skin.pairs.clear()
		skin.blended = PackedInt32Array(range(skin.offsets.size() - 1))
		fallback[node] = skin
		reference[node] = Reference.StableSkin.new(node.get_meta("stable_source"), rig.layout["joints"])
	var fast: Array[int]
	var slow: Array[int]
	var frozen: Array[int]
	var reference_factors: Array[float]
	var helpers: Array[Dictionary]
	helpers.assign([optimized, fallback, reference])
	for clip: String in clips:
		if clip in ["rest", "idle"]: continue
		for frame: int in range(WARMUP_POSES):
			for index: int in range(IMPLEMENTATIONS):
				_select(helpers[index])
				sample.call(rig, clip, float(frame) / (pose_count - 1), reference_paint if index == 2 else null)
		for round_index: int in range(PAIR_ROUNDS):
			for frame: int in range(pose_count):
				var costs := PackedInt64Array([0, 0, 0])
				# Rotate all three positions, reversing on alternating poses.
				# Each implementation occupies each position once per 3 rounds.
				for slot: int in range(IMPLEMENTATIONS):
					var step: int = slot if frame % 2 == 0 else IMPLEMENTATIONS - 1 - slot
					var index: int = (step + frame + round_index) % IMPLEMENTATIONS
					_select(helpers[index])
					var times: Vector2i = sample.call(rig, clip, float(frame) / (pose_count - 1), reference_paint if index == 2 else null)
					costs[index] = times.x
				fast.append(costs[0])
				slow.append(costs[1])
				frozen.append(costs[2])
				reference_factors.append(float(costs[0]) / maxf(1.0, costs[2]))
	for node: Node in optimized:
		node.set_meta("stable_skin", optimized[node])
		optimized[node].cache_enabled = true
	fast.sort()
	slow.sort()
	frozen.sort()
	reference_factors.sort()
	var ratio: float = float(slow[slow.size() / 2]) / maxf(1.0, fast[fast.size() / 2])
	# Guard the slower same-pose samples, without letting a single scheduler
	# interruption dominate. A median can hide the 30% boundary regression.
	var rank: int = ceili(reference_factors.size() * REFERENCE_FACTOR_PERCENTILE) - 1
	var factor: float = reference_factors[rank]
	return {"samples": fast.size(), "fast_median_us": fast[fast.size() / 2],
		"fallback_median_us": slow[slow.size() / 2], "speedup": ratio,
		"minimum_speedup": MINIMUM_SPEEDUP, "fallback_ok": ratio >= MINIMUM_SPEEDUP,
		"reference_revision": Reference.REVISION, "reference_median_us": frozen[frozen.size() / 2],
		"production_reference_factor": factor, "maximum_reference_factor": MAXIMUM_REFERENCE_FACTOR,
		"reference_factor_percentile": REFERENCE_FACTOR_PERCENTILE,
		"reference_median_factor": reference_factors[reference_factors.size() / 2],
		"reference_ok": factor <= MAXIMUM_REFERENCE_FACTOR,
		"ok": ratio >= MINIMUM_SPEEDUP and factor <= MAXIMUM_REFERENCE_FACTOR}

static func _select(helpers: Dictionary) -> void:
	for node: Node in helpers:
		helpers[node].cache_enabled = false
		node.set_meta("stable_skin", helpers[node])
