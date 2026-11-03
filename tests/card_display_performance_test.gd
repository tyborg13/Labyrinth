extends SceneTree

const Display = preload("res://scripts/card_display_overrides.gd")
const Bindings = preload("res://scripts/card_display_bindings.gd")
const Data = preload("res://scripts/game_data.gd")
const CardScene = preload("res://scenes/card_widget.tscn")
const COUNTS: Array = [20, 60]
const SAMPLES: int = 25
const TARGET_USEC: int = 2000
const FIXTURE: Dictionary = {"relics": ["bloodglass_knife"], "player_hp": 24, "player_max_hp": 24}
const OUTPUT_PATH: String = "res://proof/card-02/feedback3/performance.json"
var _measurements: Array = []
var _failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	for count: int in COUNTS:
		for unique: bool in [false, true]:
			var host := Control.new()
			root.add_child(host)
			Bindings.reset_cache()
			var catalog: Array = Data.cards().keys()
			var layout: String = "unique" if unique else "duplicate"
			for index: int in range(count):
				var face: Control = CardScene.instantiate()
				face.configure(str(catalog[index]) if unique else "quick_stab")
				host.add_child(face)
				Display.bind(face, FIXTURE)
			Display.refresh(host, FIXTURE)
			var general: Array = []
			var irrelevant: Array = []
			var hidden: Array = []
			var changed: Array = []
			var no_text_change: Array = []
			var unchanged_status: Array = []
			for sample: int in range(SAMPLES):
				var start: int = Time.get_ticks_usec()
				Display.refresh(host, FIXTURE)
				general.append(Time.get_ticks_usec() - start)
				var ui: Dictionary = FIXTURE.duplicate(true)
				ui["notice"] = str(sample)
				ui["held_embers"] = sample
				start = Time.get_ticks_usec()
				Display.refresh(host, ui)
				irrelevant.append(Time.get_ticks_usec() - start)
			host.hide()
			var calculations: int = Bindings.calculations
			for sample: int in range(SAMPLES):
				var health: Dictionary = FIXTURE.duplicate(true)
				health["player_hp"] = sample
				var start: int = Time.get_ticks_usec()
				Display.refresh(host, health)
				hidden.append(Time.get_ticks_usec() - start)
			_expect(Bindings.calculations == calculations, "Hidden Health invalidation performs no projection")
			host.show()
			var unchanged_state: Dictionary = FIXTURE.duplicate(true)
			unchanged_state["player_hp"] = 13
			Display.refresh(host, unchanged_state)
			await process_frame
			var before: Array = _snapshot(host)
			calculations = Bindings.calculations
			var signals: Dictionary = {"count": 0}
			for face: Control in host.get_children():
				face.display_overrides_changed.connect(func() -> void: signals["count"] += 1)
			for sample: int in range(SAMPLES):
				var health: Dictionary = FIXTURE.duplicate(true)
				health["player_hp"] = 13 + sample % 11
				var start: int = Time.get_ticks_usec()
				Display.refresh(host, health)
				no_text_change.append(Time.get_ticks_usec() - start)
				_expect(_snapshot(host) == before, "Health moving within 13..23/24 changes no definition, text, rows or badge")
			_expect(Bindings.calculations == calculations and signals["count"] == 0, "Unchanged Health predicate performs zero projections and emits zero display signals")
			print("CARD DISPLAY NO TEXT CHANGE count=%d layout=%s extra_projections=%d display_signals=%d" % [count, layout, Bindings.calculations - calculations, signals["count"]])
			var status_state: Dictionary = FIXTURE.duplicate(true)
			Display.refresh(host, status_state)
			await process_frame
			before = _snapshot(host)
			calculations = Bindings.calculations
			signals["count"] = 0
			for sample: int in range(SAMPLES):
				status_state["player_bleed"] = sample + 1
				var start: int = Time.get_ticks_usec()
				Display.refresh(host, status_state)
				unchanged_status.append(Time.get_ticks_usec() - start)
				_expect(_snapshot(host) == before, "Bleed changes no definition, text, rows or badge")
				await process_frame
			_expect(Bindings.calculations == calculations and signals["count"] == 0, "Unchanged Bleed performs zero projections and emits zero display signals")
			print("CARD DISPLAY BLEED NO TEXT CHANGE count=%d layout=%s extra_projections=%d display_signals=%d" % [count, layout, Bindings.calculations - calculations, signals["count"]])
			for sample: int in range(SAMPLES):
				var health: Dictionary = FIXTURE.duplicate(true)
				health["player_hp"] = 12 if sample % 2 == 0 else 24
				var start: int = Time.get_ticks_usec()
				Display.refresh(host, health)
				changed.append(Time.get_ticks_usec() - start)
				# A real UI refresh yields a frame; drain queued old row controls.
				await process_frame
			var cards: Array = []
			for index: int in range(count): cards.append(str(catalog[index]) if unique else "quick_stab")
			var pile: Array = []
			for sample: int in range(SAMPLES):
				var start: int = Time.get_ticks_usec()
				Display.definition_signature(cards, FIXTURE)
				pile.append(Time.get_ticks_usec() - start)
			for row: Array in [["general", general], ["irrelevant_ui", irrelevant], ["hidden_health", hidden], ["visible_health_unchanged_text", no_text_change], ["visible_bleed_unchanged_text", unchanged_status], ["visible_health_changed_text", changed], ["pile_signature", pile]]:
				var timings: Array = row[1]
				timings.sort()
				print("CARD DISPLAY CPU count=%d layout=%s case=%s median_us=%d max_us=%d samples=%d" % [count, layout, row[0], timings[timings.size()/2], timings[-1], timings.size()])
				_measurements.append({"count": count, "layout": layout, "case": row[0], "median_us": timings[timings.size()/2], "max_us": timings[-1], "samples": timings.size()})
				# Only faces whose text actually changes are exempt from the budget.
				if preload("res://tests/helpers/perf_group.gd").enabled() and row[0] != "visible_health_changed_text": _expect(int(timings[-1]) <= TARGET_USEC, "Unchanged-text refresh stays below 2 ms: count=%d layout=%s case=%s" % [count, layout, row[0]])
			host.free()
			await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_PATH.get_base_dir()))
	var output := FileAccess.open(OUTPUT_PATH, FileAccess.WRITE)
	output.store_string(JSON.stringify(_measurements, "  ") + "\n")
	for failure: String in _failures: push_error(failure)
	print("CARD DISPLAY CACHE PERFORMANCE RESULT: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	quit(0 if _failures.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _snapshot(host: Control) -> Array:
	var result: Array = []
	for face: Control in host.get_children():
		result.append(var_to_bytes([face.call("_display_card_def"), face.display_summary_rows(), face.get("_time_badge").value, _text(face)]))
	return result

func _text(node: Node) -> Array:
	var result: Array = []
	if node is Label or node is RichTextLabel: result.append(node.text)
	for child: Node in node.get_children():
		if not child.is_queued_for_deletion(): result.append_array(_text(child))
	return result
