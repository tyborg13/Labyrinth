extends SceneTree

## Extends the reviewer's 51-pose sequence to every clip/view. Timings include
## every joint mesh and exact-source quad; authored pose cost is also reported.
const Rig = preload("res://assets/units/chainbound_gaoler_cutout/rig.gd")
const Paint = preload("res://scripts/maquette_cutout_runtime/stable_paint.gd")
const Legacy = preload("res://experiments/cutouts/chainbound_gaoler/rr49/fixtures/submission_2bd5ea39a/legacy_paint.gd")
const Pixels = preload("res://scripts/maquette_cutout_runtime/pixel_presentation.gd")
const Presentation = preload("res://scripts/maquette_cutout_runtime/humanoid_presentation.gd")
const Motion = preload("res://scripts/maquette_cutout_runtime/motion.gd")
const Paired = preload("res://tests/rr49/paired_cost.gd")
const POSE_COUNT: int = 51
const MOTION_MEDIAN_US: int = 2000
const MOTION_MAX_US: int = 3000
const HELD_MAX_US: int = 500
const INTERLEAVED_CLIPS := ["move", "reel", "death"]
var _factor: float = 1.0
var _legacy: bool = false
var _disabled: bool = false
var _errors: Array[String]
var _rows: Array[Dictionary]
var _multi: Array[Dictionary]
var _paired: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	await process_frame
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--headroom"): _factor = float(args[args.find("--headroom") + 1])
	_legacy = args.has("--legacy-submission")
	_disabled = args.has("--disable-cache")
	for view: String in ["front", "rear"]:
		var rig: Node2D = _new_rig(view)
		var clips: Array[String]
		for clip: String in Motion.data_for(rig.layout)["clips"]: clips.append(clip)
		clips.append("rest")
		for clip: String in clips:
			if _disabled and clip not in ["rest", "idle"]: continue
			_clear(rig)
			if _legacy: Legacy._vertices.clear()
			var held: bool = clip in ["rest", "idle"]
			if held:
				for frame: int in range(POSE_COUNT): _sample(rig, clip, float(frame) / (POSE_COUNT - 1))
			var stable: Array[int]
			var whole: Array[int]
			for frame: int in range(POSE_COUNT):
				var times: Vector2i = _sample(rig, clip, float(frame) / (POSE_COUNT - 1))
				stable.append(times.x)
				whole.append(times.y)
			var row: Dictionary = _metrics(stable, whole)
			row.merge({"view": view, "clip": clip, "held_after_cycle": held})
			_check_times(row, held)
			_rows.append(row)
			print("RR49 COST CLIP: ", JSON.stringify(row))
		if not _legacy and not _disabled:
			var paired: Dictionary = Paired.measure(rig, clips, POSE_COUNT, _sample)
			paired["view"] = view
			_paired.append(paired)
			if not paired["fallback_ok"]: _errors.append("Paired fast-path speedup: " + str(paired))
			if not paired["reference_ok"]: _errors.append("Immutable optimized reference cost: " + str(paired))
			print("RR50 PAIRED COST: ", JSON.stringify(paired))
		rig.free()
		if not _legacy: _interleaved(view)
	var report: Dictionary = {"ok": _errors.is_empty(), "headroom_factor": _factor, "samples_per_clip": POSE_COUNT,
		"motion_median_budget_us": MOTION_MEDIAN_US, "motion_max_budget_us": MOTION_MAX_US, "held_budget_us": HELD_MAX_US,
		"legacy_mutation": _legacy, "disabled_cache_mutation": _disabled, "clips": _rows, "interleaved": _multi, "paired": _paired, "errors": _errors}
	if args.has("--output"): FileAccess.open(args[args.find("--output") + 1], FileAccess.WRITE).store_string(JSON.stringify(report, "\t"))
	print("RR49 SUBMISSION COST: ", "PASS" if report["ok"] else "FAIL", " (", _rows.size(), " clip/views; ", _multi.size(), " interleaved views; headroom=", _factor, ")")
	quit(0 if report["ok"] else 1)

func _new_rig(view: String) -> Node2D:
	var rig := Rig.new()
	rig.facing = view
	root.add_child(rig)
	assert(rig.load_rig())
	rig.apply_pose("rest", 0.0)
	if _legacy:
		# The frozen scalar oracle predates rr-50's removal of this dead
		# production field. Supply its historical key only in the fixture.
		for node: Node in rig.get_children():
			if not node.has_meta("stable_source"): continue
			var data: Dictionary = node.get_meta("stable_source")
			var sha := HashingContext.new()
			sha.start(HashingContext.HASH_SHA256)
			sha.update(var_to_bytes([data["vertices"], data["weights"], rig.layout["joints"], node.get_meta("stable_polygon")]))
			data["_stable_definition"] = sha.finish().hex_encode()
	if _disabled:
		for node: Node in rig.get_children():
			if node.has_meta("stable_skin"): node.get_meta("stable_skin").cache_enabled = false
	return rig

func _clear(rig: Node2D) -> void:
	for node: Node in rig.get_children():
		if not node.has_meta("stable_skin"): continue
		var skin: RefCounted = node.get_meta("stable_skin")
		skin.cache.clear()
		skin.idle_cache.clear()
		skin.cache_order.clear()
		skin.hits = 0
		skin.misses = 0

func _sample(rig: Node2D, clip: String, phase: float, submission: Script = null) -> Vector2i:
	var paint: Script = submission if submission != null else (Legacy if _legacy else Paint)
	var start: int = Time.get_ticks_usec()
	rig.apply_authored_pose(clip, Pixels.phase_for(Motion.data_for(rig.layout), clip, phase))
	Presentation.apply(rig, clip, phase)
	var submitted: int = Time.get_ticks_usec()
	paint.apply(rig, clip)
	var finish: int = Time.get_ticks_usec()
	return Vector2i(finish - submitted, finish - start)

func _metrics(stable: Array[int], whole: Array[int]) -> Dictionary:
	stable.sort()
	whole.sort()
	return {"stable_median_us": stable[stable.size() / 2], "stable_max_us": stable[-1],
		"whole_median_us": whole[whole.size() / 2], "whole_max_us": whole[-1]}

func _check_times(row: Dictionary, held: bool) -> void:
	var label: String = str(row)
	if row["stable_median_us"] > (HELD_MAX_US if held else MOTION_MEDIAN_US) * _factor: _errors.append("Median cost: " + label)
	if row["stable_max_us"] > (HELD_MAX_US if held else MOTION_MAX_US) * _factor: _errors.append("Max cost: " + label)

func _stats(rig: Node2D) -> Vector2i:
	var result := Vector2i.ZERO
	for node: Node in rig.get_children():
		if node.has_meta("stable_skin"):
			result.x += node.get_meta("stable_skin").hits
			result.y += node.get_meta("stable_skin").misses
	return result

func _interleaved(view: String) -> void:
	var rigs: Array[Node2D]
	for _clip: String in INTERLEAVED_CLIPS: rigs.append(_new_rig(view))
	var first: Array[int]
	var repeat: Array[int]
	var cache_rows: Array[Dictionary]
	var repeat_hits: Array[int]
	var repeat_misses: Array[int]
	for _rig: Node2D in rigs:
		repeat_hits.append(0)
		repeat_misses.append(0)
	# A repeat must stay inside the bounded working set. A 51-pose full cycle
	# would intentionally evict its beginning from the 16-entry motion LRU.
	# Interleave all three actors before repeating each exact pose.
	for frame: int in range(POSE_COUNT):
		for cycle: int in range(2):
			for index: int in range(rigs.size()):
				var before: Vector2i = _stats(rigs[index])
				var cost: int = _sample(rigs[index], INTERLEAVED_CLIPS[index], float(frame) / (POSE_COUNT - 1)).x
				if cycle == 0: first.append(cost)
				else:
					repeat.append(cost)
					var delta: Vector2i = _stats(rigs[index]) - before
					repeat_hits[index] += delta.x
					repeat_misses[index] += delta.y
	for index: int in range(rigs.size()):
		cache_rows.append({"clip": INTERLEAVED_CLIPS[index], "repeat_hits": repeat_hits[index], "repeat_misses": repeat_misses[index]})
		if repeat_misses[index] != 0: _errors.append(view + ": interleaved repeat cache misses: " + str(repeat_misses[index]))
		if repeat_hits[index] == 0: _errors.append(view + ": interleaved repeat has no cache hits")
	first.sort()
	repeat.sort()
	var row: Dictionary = {"view": view, "rigs": rigs.size(), "first_max_us": first[-1], "repeat_max_us": repeat[-1], "repeat_median_us": repeat[repeat.size() / 2], "caches": cache_rows}
	if first[-1] > MOTION_MAX_US * _factor or repeat[-1] > MOTION_MAX_US * _factor: _errors.append("Interleaved cost: " + str(row))
	_multi.append(row)
	for rig: Node2D in rigs: rig.free()
