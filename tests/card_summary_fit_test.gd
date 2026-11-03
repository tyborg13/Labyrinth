extends SceneTree

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Live = preload("res://tests/helpers/card_legibility_contexts.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const Measure = preload("res://tests/helpers/card_summary_fit_measure.gd")
const Pool = preload("res://tests/helpers/card_summary_fit_pool.gd")
const Baseline = preload("res://tests/helpers/card_summary_fit_baseline.gd")
const NATIVE_SCREEN_COUNT: int = 1
const TEST_MAX_FPS: int = 0
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _argument(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var index: int = args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else fallback

func _run() -> void:
	Engine.max_fps = TEST_MAX_FPS
	root.size = Audit.VIEWPORT_SIZE
	root.content_scale_size = Audit.VIEWPORT_SIZE
	var baseline: bool = OS.get_cmdline_user_args().has("--record-before")
	var full_matrix: bool = OS.get_cmdline_user_args().has("--full-matrix")
	var before: Dictionary = {} if baseline else Baseline.load_samples(full_matrix)
	_expect(baseline or not before.is_empty(), "Committed per-sample baseline is present")
	if baseline:
		_expect((Audit.Card as Script).source_code.sha256_text() == Baseline.SOURCE_WIDGET_SHA256, "Baseline recording uses the original approved CardWidget")
	var audit := Audit.new()
	audit.setup(self)
	var entries: Array = Audit.definitions()
	if not full_matrix:
		entries = Baseline.focused_entries(entries)
	var contexts: Array = audit.contexts().filter(func(c: Dictionary) -> bool: return not c["exempt"])
	var expected_contexts: Array = contexts.map(func(c: Dictionary) -> String: return c["id"])
	if not _argument("--only-context").is_empty():
		contexts = contexts.filter(func(c: Dictionary) -> bool: return c["id"] == _argument("--only-context"))
	var live := Live.new()
	await live.setup(self, NATIVE_SCREEN_COUNT)
	var pool := Pool.new()
	var samples: Dictionary = {}
	var minimums: Array = []
	var changed: Dictionary = {}
	var changed_faces: Array = []
	var regression_failures: Dictionary = {}
	var output: String = _argument("--output", "user://card_summary_fit.json")
	var catalog_sha256: String = JSON.stringify(entries).sha256_text()
	_expect(not entries.is_empty() and not contexts.is_empty(), "Sweep has definitions and reading contexts")
	for context: Dictionary in contexts:
		var context_started: int = Time.get_ticks_msec()
		var context_check_start: int = checks
		var context_failure_start: int = failures.size()
		var context_samples: Dictionary = {}
		var faces: Array = await pool.open(live, context, mini(Live.POOL_SIZE, entries.size()), _expect)
		_expect(faces.size() == pool.workers.size(), "Native context has every face: " + context["id"])
		if faces.size() != pool.workers.size(): continue
		# Drain opening animations before assigning catalog definitions. This is
		# warm-up only: no geometry is measured here. Every measured batch below
		# must independently satisfy the unchanged three-frame / three-second cap.
		var warmup: Dictionary = await Settle.wait_for(self, faces)
		var summary: Dictionary = {"context": context["id"], "warmup_settled": warmup["settled"], "samples": 0, "worst_margin_px": null, "floor_failures": 0, "overflow_count": 0, "vertical_overflow_count": 0, "changed_samples": 0}
		# This layout contract deliberately exercises base AND upgraded definitions
		# even on ID-only builders, without claiming their production provenance.
		for start: int in range(0, entries.size(), pool.workers.size()):
			var batch: Array = entries.slice(start, start + pool.workers.size())
			faces.clear()
			for index: int in range(batch.size()):
				live.configure_face(pool.workers[index], batch[index], context)
				faces.append(pool.workers[index]["face"])
			_expect((await Settle.wait_for(self, faces))["settled"], "%s batch %d settles" % [context["id"], start])
			for index: int in range(batch.size()):
				var entry: Dictionary = batch[index]
				var key: String = "%s/%s/%s" % [context["id"], entry["id"], entry["variant"]]
				if faces[index] is Audit.Card:
					_expect(pool.aligned(faces[index]), "Sample retains the live production frame's transform and size: " + key)
					_expect(faces[index].get("card_id") == entry["id"], "Printed card matches sample: " + key)
					_expect(faces[index].get("_card_override") == entry["definition"], "Printed definition matches sample: " + key)
					_expect(faces[index].get("_summary_rows") == entry.get("rows", []) and faces[index].get("_time_surcharge") == int(entry.get("time_surcharge", 0)), "Printed modifier rows and cost match sample: " + key)
				# The text-only Graftwright popover resolves base rules by ID. Its
				# upgraded CardWidget faces are covered in the graftwright context;
				# there is no summary row in this popover to override or wrap.
				var definition: Dictionary = Audit.Data.card_def(entry["id"]) if context["factory"] == "rules_tooltip" else entry["definition"]
				var measured: Dictionary = Measure.measure(faces[index], definition)
				samples[key] = measured
				context_samples[key] = measured
				summary["samples"] += 1
				summary["floor_failures"] += int(not measured["floor_errors"].is_empty())
				_expect(measured["floor_errors"].is_empty(), key + " floors: " + str(measured["floor_errors"]))
				_expect(measured["continuation_errors"].is_empty(), key + " continuation: " + str(measured["continuation_errors"]))
				_expect(float(measured["overflow_y"]) <= Audit.EPSILON, "Complete item bounds stay inside the card: " + key + " overflow_y=" + str(measured["overflow_y"]))
				summary["vertical_overflow_count"] += int(float(measured["overflow_y"]) > Audit.EPSILON)
				var margin: Variant = measured["margin_px"]
				var fits: bool = margin == null or float(margin) + Audit.EPSILON >= Measure.EDGE_INSET_PX
				if margin != null:
					summary["worst_margin_px"] = margin if summary["worst_margin_px"] == null else minf(summary["worst_margin_px"], margin)
				if not fits:
					summary["overflow_count"] += 1
					if Baseline.NAMED_CARDS.has(entry["id"]):
						regression_failures[entry["id"]] = true
				if not baseline: _expect(fits, key + " parchment margin: " + str(margin))
				if not baseline:
					_expect(before.has(key), "Committed before sample exists: " + key)
					if before.has(key):
						var previous: Dictionary = before[key]
						var identical: bool = previous["layout"] == measured["layout"]
						if not identical:
							changed[entry["id"]] = true
							changed_faces.append(key)
							summary["changed_samples"] += 1
						if previous["margin_px"] == null or float(previous["margin_px"]) + Audit.EPSILON >= Measure.EDGE_INSET_PX:
							_expect(identical, "Previously fitting layout is byte-identical: " + key)
		minimums.append(summary)
		summary["validation_failure_count"] = failures.size() - context_failure_start
		var checkpoint: Dictionary = {"baseline": baseline, "widget_sha256": (Audit.Card as Script).source_code.sha256_text(), "harness_sha256": (get_script() as Script).source_code.sha256_text(), "pool_sha256": (Pool as Script).source_code.sha256_text(), "catalog_sha256": catalog_sha256, "expected_contexts": expected_contexts, "definitions": entries.size(), "context": summary, "samples": context_samples, "regression_failures": regression_failures, "changed_card_ids": changed.keys(), "checks": checks - context_check_start, "failures": failures.slice(context_failure_start)}
		_save_json(output + ".contexts/" + str(context["id"]) + ".json", checkpoint)
		print("CARD SUMMARY CONTEXT: %s samples=%d worst_margin_px=%s overflow=%d floor_failures=%d changed=%d" % [summary["context"], summary["samples"], str(summary["worst_margin_px"]), summary["overflow_count"], summary["floor_failures"], summary["changed_samples"]])
		print("CARD SUMMARY CONTEXT RUNTIME: %s %.3fs" % [summary["context"], float(Time.get_ticks_msec() - context_started) / 1000.0])
	if baseline and _argument("--only-context").is_empty():
		for id: String in Baseline.NAMED_CARDS:
			_expect(regression_failures.has(id), "Named regression fails before: " + id)
	elif not before.is_empty() and _argument("--only-context").is_empty():
		_expect(samples.size() == before.size(), "Committed baseline and after coverage are identical")
	var changed_ids: Array = changed.keys()
	changed_ids.sort()
	var coverage: Array = []
	for entry: Dictionary in entries:
		coverage.append({"card": entry["id"], "variant": entry["variant"], "aliases": entry["aliases"]})
	var report: Dictionary = {"baseline": baseline, "full_matrix": full_matrix, "widget_sha256": (Audit.Card as Script).source_code.sha256_text(), "definitions": entries.size(), "coverage": coverage, "contexts": minimums, "samples": samples, "regression_failures": regression_failures, "changed_card_ids": changed_ids, "changed_faces": changed_faces, "checks": checks, "failures": failures}
	_save_json(output, report)
	pool.cleanup()
	live.cleanup()
	audit.cleanup()
	for failure: String in failures: push_error(failure)
	print("CARD SUMMARY CHANGED CARDS: %d %s" % [changed_ids.size(), str(changed_ids)])
	print("CARD SUMMARY CHANGED FACES: %d" % changed_faces.size())
	print("CARD SUMMARY %s RESULT: %s (%d checks, %d failures, %d samples)" % ["BEFORE" if baseline else "FIT", "PASS" if failures.is_empty() else "FAIL", checks, failures.size(), samples.size()])
	quit(0 if failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)

func _save_json(path: String, value: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value) + "\n")
