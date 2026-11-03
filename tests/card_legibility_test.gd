extends SceneTree

const LiveContexts = preload("res://tests/helpers/card_legibility_contexts.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Sources = preload("res://tests/helpers/card_legibility_sources.gd")
const OUTPUT_DIR: String = "res://tests/pt13_03"
const OVERFLOW_FIXTURE_REPEAT: int = 120
const BADGE_FIXTURE_VALUE: int = 9999
const EDGE_ANCHOR_SIZE := Vector2.ONE
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	root.content_scale_size = Audit.VIEWPORT_SIZE
	root.size = Audit.VIEWPORT_SIZE
	var audit := Audit.new()
	audit.setup(self)
	await process_frame
	if OS.get_cmdline_user_args().has("--coverage-capture") or OS.get_cmdline_user_args().has("--coverage-capture-plan"):
		var capture: bool = OS.get_cmdline_user_args().has("--coverage-capture")
		_expect(not capture or DisplayServer.get_name() != "headless", "Captures require the design owner's window server")
		if failures.is_empty(): await preload("res://tests/helpers/card_legibility_capture.gd").run_coverage_gaps(self, audit, _expect, capture)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD LEGIBILITY COVERAGE CAPTURE %s: %s (%d checks, %d failures)" % ["RESULT" if capture else "PLAN", "PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--negative-fixtures"):
		await preload("res://tests/helpers/card_legibility_negative.gd").run(self, audit, _expect)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD LEGIBILITY NEGATIVE FIXTURES: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--scavenger-inspection"):
		await preload("res://tests/helpers/scavenger_readability_evidence.gd").new().run(self, _expect)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("SCAVENGER INSPECTION RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--bounds-only"):
		await _equipment_bounds(audit)
		var report_path: String = OUTPUT_DIR.path_join("audit.json")
		var report: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(report_path))
		report["equipment_bounds"] = audit.get_meta("equipment_bounds")
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		file.store_string(JSON.stringify(report) + "\n")
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD LEGIBILITY EQUIPMENT BOUNDS TEST: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--reading-layouts"):
		var proof_viewport = preload("res://tests/helpers/card_legibility_viewport.gd")
		var viewport: SubViewport = proof_viewport.create(self)
		proof_viewport.verify(self, viewport, _expect)
		var surface := Control.new()
		surface.size = Vector2(Audit.VIEWPORT_SIZE)
		viewport.add_child(surface)
		var reading := preload("res://tests/helpers/card_reading_contexts.gd").new()
		await reading.run(self, surface, _expect, func(_name: String) -> void: pass)
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR.path_join("feedback3")))
		var file := FileAccess.open(OUTPUT_DIR.path_join("feedback3/layouts.json"), FileAccess.WRITE)
		file.store_string(JSON.stringify(reading.layouts, "\t") + "\n")
		proof_viewport.dispose(viewport)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD READING LAYOUT RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--focused-shared"):
		preload("res://tests/suites/tooltip_consistency_suite.gd").run(_expect)
		preload("res://tests/suites/card_keywords_suite.gd").run(_expect)
		await _equipment_bounds(audit)
		await _no_self_shrink(audit)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD WIDGET/TOOLTIP/ITEM PREVIEW FOCUSED RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
		quit(0 if failures.is_empty() else 1)
		return
	if OS.get_cmdline_user_args().has("--capture") or OS.get_cmdline_user_args().has("--capture-plan"):
		var capture: bool = OS.get_cmdline_user_args().has("--capture")
		_expect(not capture or DisplayServer.get_name() != "headless", "Captures require the design owner's window server")
		if failures.is_empty(): await preload("res://tests/helpers/card_legibility_capture.gd").run(self, audit, _expect, capture)
		audit.cleanup()
		for failure: String in failures: push_error(failure)
		print("CARD LEGIBILITY CAPTURE PLAN: %s" % ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	var entries: Array = Audit.definitions()
	var contexts: Array = audit.contexts()
	_expect(Audit.EXEMPT_CONTEXTS.size() == 7, "Only the seven director-approved contexts are exempt")
	for id: String in Audit.EXEMPT_CONTEXTS:
		_expect(contexts.any(func(c: Dictionary) -> bool: return c["id"] == id), "Allowlist names a live context: " + id)
	if OS.get_cmdline_user_args().has("--context-smoke"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["iron_wheel", "headlong", "thorn_crown_pact"].has(e["id"]) and e["variant"] == "base")
	if OS.get_cmdline_user_args().has("--card-02-trails"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["cinder_trail", "fan_the_flames"].has(e["id"]) and e["variant"] == "base")
	if OS.get_cmdline_user_args().has("--mutation-contexts"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["iron_wheel", "headlong", "thorn_crown_pact"].has(e["id"]) and e["variant"] == "base")
		contexts = contexts.filter(func(c: Dictionary) -> bool: return ["grimoire_equipment", "purge_picker"].has(c["id"]))
	if OS.get_cmdline_user_args().has("--coverage-gaps"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["iron_wheel", "headlong", "thorn_crown_pact"].has(e["id"]) and e["variant"] == "base")
		contexts = contexts.filter(func(c: Dictionary) -> bool: return ["chronicle_card", "chronicle_equipment", "graftwright_inspection"].has(c["id"]))
	if OS.get_cmdline_user_args().has("--fixed-contexts"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["iron_wheel", "headlong", "thorn_crown_pact"].has(e["id"]) and e["variant"] == "base")
		contexts = contexts.filter(func(c: Dictionary) -> bool: return Audit.FIXED_CONTEXTS.has(c["id"]))
	if OS.get_cmdline_user_args().has("--regressions-only"):
		entries = entries.filter(func(e: Dictionary) -> bool: return ["iron_wheel", "headlong", "thorn_crown_pact"].has(e["id"]) and e["variant"] == "base")
		contexts = contexts.filter(func(c: Dictionary) -> bool: return ["equipment_tooltip", "card_tooltip", "purge_confirmation"].has(c["id"]))
	_expect(not entries.is_empty() and not contexts.is_empty(), "Audit requires nonempty definitions and contexts")
	if entries.is_empty() or contexts.is_empty():
		audit.cleanup()
		quit(1)
		return
	var samples: Array = []
	var minimums: Array = []
	var live := LiveContexts.new()
	await live.setup(self, mini(LiveContexts.POOL_SIZE, entries.size()))
	for context: Dictionary in contexts:
		_expect(["base", "modified", "both"].has(context["definition_source"]) and not str(context["production_builder_call"]).is_empty(), "Context has an explicit production definition source: " + context["id"])
		var context_entries: Array = Sources.entries_for(context, entries)
		_expect(not context_entries.is_empty(), "Context has eligible definitions: " + context["id"])
		if context_entries.is_empty(): continue
		var summary: Dictionary = {"context": context["id"], "definition_source": context["definition_source"], "production_builder_call": context["production_builder_call"], "definition_counts": Sources.counts(context_entries), "definitions": context_entries.size(), "text_px": {"rules": null, "token_number": null, "footer": null}, "icon_px": null, "overflow_count": 0, "floor_failure_count": 0, "shrunk_count": 0, "exemption": context["exemption"], "samples": 0, "sample_failure_count": 0, "production_ancestors": [], "production_initial": []}
		var faces: Array = await live.open(context)
		_expect(faces.size() == live.workers.size(), "Production context provides every live face: " + context["id"])
		if faces.size() != live.workers.size():
			summary["error"] = "missing production face"
			minimums.append(summary)
			_expect(false, "Empty or incomplete production context: " + context["id"])
			continue
		var initial_settle: Dictionary = await Settle.wait_for(self, faces)
		if str(context["id"]).begins_with("chronicle"):
			for worker: Dictionary in live.workers:
				var panel: Control = worker["menu"].get("_chronicle")
				_expect(panel.get_parent() == worker["menu"] and panel.is_ancestor_of(worker["face"]) and panel.is_visible_in_tree() and not worker["menu"].get("menu_column").visible, "Chronicle uses MainMenu's open path and native preview: " + context["id"])
		_expect(initial_settle["settled"], "%s: %s" % [context["id"], initial_settle.get("error", "settled")])
		if not initial_settle["settled"]:
			summary["error"] = initial_settle["error"]
			minimums.append(summary)
			continue
		var initial_measurements: Array = []
		for worker: Dictionary in live.workers:
			var initial: Dictionary = Audit.measure(worker["face"], worker.get("initial_definition", {}))
			var initial_errors: Array = Audit.floor_errors(initial) if not context["exempt"] else []
			_expect(initial.get("visible", false) and initial_errors.is_empty(), "%s production face before overrides: %s" % [context["id"], initial_errors])
			initial["floor_errors"] = initial_errors
			initial.erase("runs")
			initial_measurements.append(initial)
		summary["production_ancestors"] = initial_settle["ancestors"]
		summary["production_initial"] = initial_measurements
		for start: int in range(0, context_entries.size(), live.workers.size()):
			var batch_entries: Array = context_entries.slice(start, start + live.workers.size())
			var batch: Array = []
			for index: int in range(batch_entries.size()):
				var worker: Dictionary = live.workers[index]
				if worker["face"] == null: continue
				live.configure_face(worker, batch_entries[index], context)
				batch.append(worker["face"])
			var settled: Dictionary = await Settle.wait_for(self, batch)
			_expect(settled["settled"], "%s batch %d: %s" % [context["id"], start, settled.get("error", "settled")])
			if not settled["settled"]: break
			for index: int in range(batch.size()):
				var entry: Dictionary = batch_entries[index]
				var measured: Dictionary = Audit.measure(batch[index], entry["definition"])
				var errors: Array = Audit.sample_errors(measured, entry, context)
				var floor_errors: Array = Audit.floor_errors(measured)
				measured.merge({"context": context["id"], "definition_source": context["definition_source"], "card": entry["id"], "variant": entry["variant"], "floor_errors": floor_errors, "validation_errors": errors, "exemption": summary["exemption"], "node_path": str(batch[index].get_path()), "settled_frames": settled["stable_frames"]})
				for role: String in measured["text_px"]:
					if measured["text_px"][role] != null: Audit._minimum(summary["text_px"], role, measured["text_px"][role])
				if measured["icon_px"] != null: Audit._minimum(summary, "icon_px", measured["icon_px"])
				summary["floor_failure_count"] += int(not floor_errors.is_empty())
				summary["sample_failure_count"] += int(not errors.is_empty())
				summary["samples"] += 1
				summary["overflow_count"] += int(float(measured["overflow_px"]["x"]) > Audit.EPSILON or float(measured["overflow_px"]["y"]) > Audit.EPSILON)
				summary["shrunk_count"] += int(measured["shrunk"])
				_expect(errors.is_empty(), "%s/%s/%s: %s" % [context["id"], entry["id"], entry["variant"], errors])
				measured.erase("runs")
				samples.append(measured)
		_expect(Audit.coverage_errors(context, summary["samples"]).is_empty(), "Nonempty production context: " + context["id"])
		_expect(summary["samples"] == context_entries.size(), "Every eligible definition sampled in " + context["id"])
		minimums.append(summary)
		var printed: Dictionary = summary.duplicate()
		printed.erase("production_ancestors")
		printed.erase("production_initial")
		print("CARD LEGIBILITY CONTEXT: %s" % JSON.stringify(printed))
	live.cleanup()
	await _equipment_bounds(audit)
	await _no_self_shrink(audit)
	if not OS.get_cmdline_user_args().has("--regressions-only") and not OS.get_cmdline_user_args().has("--fixed-contexts") and not OS.get_cmdline_user_args().has("--context-smoke") and not OS.get_cmdline_user_args().has("--mutation-contexts") and not OS.get_cmdline_user_args().has("--coverage-gaps"):
		_write_report(entries, minimums, samples, audit.get_meta("equipment_bounds"))
	audit.cleanup()
	for failure: String in failures.slice(0, 30): push_error(failure)
	print("CARD LEGIBILITY TEST RESULT: %s (%d definitions, %d contexts, %d samples, %d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", entries.size(), contexts.size(), samples.size(), checks, failures.size()])
	quit(0 if failures.is_empty() or OS.get_cmdline_user_args().has("--report-only") else 1)

func _no_self_shrink(audit: RefCounted) -> void:
	var context: Dictionary = {"factory": "scaled", "size": Audit.Card.BASE_CARD_SIZE}
	var entry: Dictionary = {"id": "iron_wheel", "definition": Audit.Data.card_def("iron_wheel"), "rows": [[Audit.Icons.rules_text_token("Overflow fixture. ".repeat(OVERFLOW_FIXTURE_REPEAT))]]}
	var instance: Dictionary = audit.make_card(context, entry)
	root.add_child(instance["surface"])
	for frame: int in range(Audit.SETTLE_FRAMES): await process_frame
	var widget: Control = instance["widget"]
	var label: Label = widget.find_child("SummaryRulesText", true, false)
	_expect(label != null and label.get_theme_font_size("font_size") == 16, "Overflowing rules retain the authored 16 px type")
	_expect(is_equal_approx(widget.art_frame.custom_minimum_size.y, Audit.Card.ART_MIN_HEIGHT), "Overflow gives up art height down to the existing minimum")
	var measured: Dictionary = Audit.measure(widget)
	_expect(float(measured["overflow_px"]["y"]) > 0.0, "Remaining rules overflow is observable in pixels")
	var badge: Control = widget.get("_time_badge")
	badge.set("value", BADGE_FIXTURE_VALUE)
	_expect(badge.value_font_size() >= 16, "Long token numbers cannot shrink below the context's rules size")
	# Exercise the plain-description path as well as summary/Rite rules.
	var plain: Dictionary = Audit.Data.card_def("iron_wheel")
	plain["actions"] = []
	plain["description"] = "Overflow fixture. ".repeat(OVERFLOW_FIXTURE_REPEAT)
	widget.set_display_overrides()
	widget.configure("iron_wheel", false, false, true, false, false, true, plain)
	for frame: int in range(Audit.SETTLE_FRAMES): await process_frame
	_expect(widget.desc_label.visible and widget.desc_label.get_theme_font_size("normal_font_size") == 16, "Plain overflowing rules retain 16 px type")
	_expect(is_equal_approx(widget.art_frame.custom_minimum_size.y, Audit.Card.ART_MIN_HEIGHT), "Plain rules borrow art down to the existing minimum")
	_expect(float(Audit.measure(widget)["overflow_px"]["y"]) > 0.0, "Plain rules report remaining overflow")
	widget.footer_label.text = "Footer fixture"
	widget.footer_label.show()
	_expect(float(Audit.measure(widget)["text_px"]["footer"]) >= 16.0, "Visible card footers retain the context's rules size")
	# Reusing a dense face must not permanently reduce the next card's art.
	widget.set_display_overrides()
	widget.configure("quick_stab")
	var reused_art: float = widget.art_frame.custom_minimum_size.y
	var fresh: Control = Audit.CardScene.instantiate()
	fresh.configure("quick_stab")
	root.add_child(fresh)
	_expect(is_equal_approx(reused_art, fresh.art_frame.custom_minimum_size.y), "Pooled faces return the art loan")
	fresh.free()
	instance["surface"].free()

func _equipment_bounds(audit: RefCounted) -> void:
	var maximum := Vector2.ZERO
	var widest: String = ""
	var two_card_count: int = 0
	var footer_px: float = INF
	for id: String in Audit.Data.equipment():
		if Audit.Data.equipment_cards(id).size() != 2: continue
		# The combat lock footer is the largest existing version of this panel.
		var builder := Audit.Previews.new()
		builder.equipment_locked = true
		var panel: Control = builder.equipment_tooltip(id)
		root.add_child(panel)
		for frame: int in range(Audit.SETTLE_FRAMES): await process_frame
		var extent: Vector2 = panel.get_combined_minimum_size()
		for label: Node in panel.find_children("*", "Label", true, false):
			if str(label.get("text")) == "Locked in combat":
				var px: float = float((label as Control).get_theme_font_size("font_size")) * (label as Control).get_global_transform_with_canvas().get_scale().abs().y
				footer_px = minf(footer_px, px)
				_expect(px + Audit.EPSILON >= Audit.TEXT_FLOOR, "Equipment lock footer retains the text floor: " + id)
		if extent.x > maximum.x:
			maximum = extent
			widest = id
		for point: Vector2 in [Vector2.ZERO, Vector2(Audit.VIEWPORT_SIZE), Vector2(Audit.VIEWPORT_SIZE) * 0.5]:
			var anchor := Rect2(point, EDGE_ANCHOR_SIZE)
			var placed: Vector2 = Audit.Chronicle.focus_tooltip_position(anchor, extent, Rect2(Vector2.ZERO, Vector2(Audit.VIEWPORT_SIZE)))
			_expect(Rect2(Vector2.ZERO, Vector2(Audit.VIEWPORT_SIZE)).encloses(Rect2(placed, extent)), "Equipment focus preview fits at viewport edge: " + id)
		two_card_count += 1
		panel.free()
	print("CARD LEGIBILITY EQUIPMENT BOUNDS: %s %s (%d two-card items)" % [widest, maximum, two_card_count])
	_expect(Audit.Previews.EQUIPMENT_TOOLTIP_CARD_SIZE == Audit.Previews.CARD_TOOLTIP_SIZE, "Equipment and card tooltip sizes match")
	audit.set_meta("equipment_bounds", {"item": widest, "width": maximum.x, "height": maximum.y, "two_card_items": two_card_count, "combat_locked": true, "footer_px": footer_px})

func _write_report(entries: Array, minimums: Array, samples: Array, equipment_bounds: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var coverage: Array = []
	for entry: Dictionary in entries: coverage.append({"card": entry["id"], "variant": entry["variant"], "aliases": entry["aliases"]})
	var report: Dictionary = {"viewport": [1920, 1080], "ui_scale": 1.0, "text_floor_px": Audit.TEXT_FLOOR, "icon_floor_px": Audit.ICON_FLOOR, "exempt_contexts": Audit.EXEMPT_CONTEXTS, "definitions": entries.size(), "definition_counts": Sources.counts(entries), "coverage": coverage, "equipment_bounds": equipment_bounds, "minimums": minimums, "samples": samples}
	var file := FileAccess.open(OUTPUT_DIR.path_join("audit.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report) + "\n")
	Sources.write_result(OUTPUT_DIR.path_join("result.md"), entries, minimums, samples.size())

func _expect(condition: bool, message: String) -> void:
	checks += 1
	if not condition: failures.append(message)
