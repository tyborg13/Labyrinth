extends SceneTree
## pla-03 headless checks for sentence card faces (data/card_faces.json):
## every entry validates, every live widget face fits, and at every layout
## scale and context text size each chip, line and diagram stays inside the
## parchment comfort margin (recomputed from the plan's own geometry).
## Prints FACE lines per card and "TEST RESULT: PASS|FAIL".
## Run: python3 tools/godot_task_runner.py --task-id pla-03 --stream -- \
##   godot --headless --path . --script res://tools/pla03/face_fit_check.gd

const FaceSpec = preload("res://scripts/card_face_spec.gd")
const FaceLayout = preload("res://scripts/card_face_layout.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const WidgetScene = preload("res://scenes/card_widget.tscn")
const GameData = preload("res://scripts/game_data.gd")
const ActionIconsScript = preload("res://scripts/action_icon_library.gd")

# Widget sizes in use (250x352 everywhere in the game; 240x336 and 220x308 in
# the surface feedback test; 190x268 is the compact threshold).
const WIDGET_SIZES: Array = [Vector2(250, 352), Vector2(240, 336), Vector2(220, 308), Vector2(190, 268)]
# Context text boosts: UiTypography.ui_scale tops out at 1.12.
const TEXT_BOOSTS: Array = [1.0, 1.06, 1.12]

var _failures: Array = []
var _checks: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var faces: Dictionary = FaceSpec.faces()
	_expect(not faces.is_empty(), "data/card_faces.json loads")
	for card_id: String in faces:
		_expect(not GameData.card_def(card_id).is_empty(), "%s is a card" % card_id)
		for problem: Variant in FaceSpec.validate(card_id, faces[card_id]):
			_expect(false, str(problem))
	var report: Dictionary = {}
	for widget_size: Vector2 in WIDGET_SIZES:
		for card_id: String in faces:
			var widget: CardWidget = WidgetScene.instantiate()
			widget.custom_minimum_size = widget_size
			widget.size = widget_size
			root.add_child(widget)
			widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
			await process_frame
			await process_frame
			var plan: Dictionary = widget.sentence_face_plan()
			var spec: Dictionary = faces[card_id]
			if bool(spec.get("simple", false)) or FaceSpec.uses_icon_rows(spec):
				_check_icon_rows(card_id, widget_size, widget, plan, spec)
				widget.queue_free()
				await process_frame
				continue
			if spec.has("rows"):
				_check_simple_face(card_id, widget_size, widget, spec["rows"])
			else:
				_expect(not plan.is_empty(), "%s at %s shows its sentence face" % [card_id, widget_size])
			if not plan.is_empty():
				var metrics: Dictionary = _unlent_metrics(widget, plan)
				var art_lent: float = float(metrics["max_relief"]) - float(plan["lend"])
				_check_plan(card_id, plan, widget, widget_size)
				if widget_size == WIDGET_SIZES[0]:
					report[card_id] = plan
					print("FACE %-17s size=%d lend=%.1f wrap=%.0f under=%.1f lines=%d height=%.1f fits=%s breaks=%s art_left=%.1f" % [card_id, int(plan["text_size"]), float(plan["lend"]), float(plan["wrap_width"]), float(plan["under_scale"]), (plan["lines"] as Array).size(), float(plan["height"]), str(plan["fits"]), str(plan.get("phrase_breaks", false)), art_lent])
					for line: Dictionary in plan["lines"]:
						print("      | %s" % str(line["text"]))
				# Boosted context sizes on the same geometry.
				for boost: float in TEXT_BOOSTS:
					var boosted: Dictionary = metrics.duplicate()
					var floor_size: int = int((metrics["text_sizes"] as Array).back())
					var sizes: Array = []
					for text_size: int in range(int(round(float(floor_size) * boost)), floor_size - 1, -1):
						sizes.append(text_size)
					boosted["text_sizes"] = sizes
					boosted["chip_size"] = maxi(1, int(round(float(metrics["chip_size"]) * boost)))
					boosted["max_relief"] = float(metrics["max_relief"])
					var face: Dictionary = widget.call("_resolved_sentence_face", widget.display_summary_rows())
					var boosted_plan: Dictionary = FaceLayout.plan(face, boosted)
					_check_geometry("%s %s x%.2f" % [card_id, widget_size, boost], boosted_plan, boosted)
			widget.queue_free()
			await process_frame
	await _check_live_binding()
	await _check_live_relic_faces()
	# A card without a face keeps its icon rows.
	var plain: CardWidget = WidgetScene.instantiate()
	plain.size = WIDGET_SIZES[0]
	root.add_child(plain)
	plain.configure("quick_stab", false, false, true, false, false, true, GameData.card_def("quick_stab"))
	await process_frame
	_expect(plain.sentence_face_plan().is_empty(), "quick_stab keeps its icon rows")
	_expect(plain.get("_summary_icon_box").get_child_count() > 0, "quick_stab has icon rows")
	plain.queue_free()
	await process_frame
	for failure: Variant in _failures:
		push_error(str(failure))
	print("FACE FIT CHECKS: %d checks, %d failures" % [_checks, _failures.size()])
	print("TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _check_icon_rows(card_id: String, widget_size: Vector2, widget: CardWidget, plan: Dictionary, spec: Dictionary) -> void:
	var label: String = "%s %s" % [card_id, widget_size]
	var box: Control = widget.get("_summary_icon_box")
	_expect(plan.is_empty() and box.visible and box.get_child_count() > 0, label + " uses visible icon rows")
	if FaceSpec.uses_icon_rows(spec):
		var actual: Array = []
		for row: Array in FaceSpec.display_icon_rows(spec, widget.display_summary_rows()):
			var icons: Array = []
			for token: Dictionary in row:
				icons.append(ActionIconsScript.token_value_text(token) if token.get("kind") == "text" else str(token.get("icon", "")))
			actual.append(icons)
		_expect(actual == spec["icon_rows"], "%s shows approved live icons: %s" % [label, actual])
	var box_rect: Rect2 = box.get_global_rect()
	var layout_scale: float = float(widget.call("_card_layout_scale"))
	var lower_bound: float = (FaceLayout.PARCHMENT_TOP_Y + FaceLayout.PARCHMENT_HALF_WIDTH.size()) * layout_scale
	for row: Control in box.get_children():
		var rect: Rect2 = row.get_global_rect()
		_expect(rect.end.y <= lower_bound + 1.0, label + " icon row ends on the parchment")
		_expect(rect.size.x <= box_rect.size.x + 1.0, label + " icon row fits in the summary")
	if widget_size == WIDGET_SIZES[0]:
		print("ROWS %s: %s" % [card_id, ActionIconsScript.plain_text_for_rows(widget.display_summary_rows()).replace("\n", " / ")])

func _check_simple_face(card_id: String, widget_size: Vector2, widget: CardWidget, expected: Array) -> void:
	var rows: Array = FaceSpec.ordered_icon_rows(card_id, widget.display_summary_rows())
	var rendered: Control = widget.get("_summary_icon_box")
	_expect(widget.sentence_face_plan().is_empty() and rendered.get_child_count() > 0, "%s has live icon rows" % card_id)
	var actual: Array = []
	for row: Array in rows:
		var report: Array = []
		for token: Dictionary in row:
			var value: Variant = token.get("value") if token.get("kind") != "surface_condition" else null
			if value is String and value.is_valid_int():
				value = int(value)
			report.append({"icon": token.get("icon"), "number": value})
		actual.append(report)
	var approved: Array = expected.duplicate(true)
	for row: Array in approved:
		for token: Dictionary in row:
			if token["number"] != null:
				token["number"] = int(token["number"])
	_expect(actual == approved, "%s at %s has v5 rows: %s" % [card_id, widget_size, actual])
	for child: Control in rendered.get_children():
		_expect(child.position.x >= -1.0 and child.position.x + child.size.x <= rendered.size.x + 1.0,
			"%s at %s keeps its icon row within the rules panel" % [card_id, widget_size])
	if widget_size == WIDGET_SIZES[0]:
		print("FACE %-17s icon rows=%d" % [card_id, actual.size()])

## Live numbers: a changed printed value shows on the face, a modified row
## value shows in the rows' tone, a structural change falls back to icon rows,
## and every term carries a tooltip.
func _check_live_binding() -> void:
	var widget: CardWidget = WidgetScene.instantiate()
	widget.size = WIDGET_SIZES[0]
	root.add_child(widget)
	var vent: Dictionary = GameData.card_def("magma_vent")
	# pla-04: Magma Vent is a 4-damage tile hit, then its follow-up Burst.
	((vent["actions"] as Array)[1] as Dictionary)["damage"] = 9
	((vent["actions"] as Array)[0] as Dictionary)["range"] = 4
	widget.configure("magma_vent", false, false, true, false, false, true, vent)
	await process_frame
	var text: String = _plan_text(widget.sentence_face_plan())
	_expect(text.contains("{burst}Burst~#9") and text.contains("{ranged}#4."), "Magma Vent with a 9 Burst shows Burst 9 and keeps its 4: " + text)
	_expect(str((widget.sentence_face_plan()["chip"]["items"] as Array).back()["text"]) == "4", "Magma Vent's chip shows the live range 4")
	var maul: Dictionary = GameData.card_def("tectonic_maul")
	var rows: Array = ActionIconsScript.rows_for_card(maul)
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("field", "")) == "damage":
				token["value"] = 13
				token["tone"] = "bonus"
				token["modifiers"] = [{"source": "Test relic", "amount": 2}]
	widget.configure("tectonic_maul", false, false, true, false, false, true, maul)
	widget.set_display_overrides("", [], rows)
	await process_frame
	text = _plan_text(widget.sentence_face_plan())
	_expect(text.contains("{melee}#13 and") and text.contains("{melee}#4."), "Tectonic Maul with +2 damage shows 13 and keeps its unbound 4: " + text)
	var face: Control = widget.get("_sentence_face")
	var style: Dictionary = face.get("_style")
	_expect((style["tones"] as Dictionary).get(0) == Color(CardWidget.DAMAGE_BONUS_COLOR), "A modified number uses the bonus ink")
	var tooltips: int = 0
	for child: Node in face.get_children():
		if not str((child as Control).tooltip_text).is_empty():
			tooltips += 1
			var point: Vector2 = (child as Control).get_global_rect().get_center()
			_expect(not str(widget.call("_tooltip_for_icon_at", point)).is_empty(), "Face hover target %s answers the card tooltip" % child.name)
	_expect(tooltips >= 5, "Tectonic Maul's terms and diagram carry tooltips")
	var modified: String = str(widget.call("_tooltip_for_icon_at", (face.get_node("Term0") as Control).get_global_rect().get_center()))
	_expect(modified.contains("Test relic"), "The modified damage names its modifier: " + modified)
	var squall: Dictionary = GameData.card_def("squall_shot")
	(squall["actions"] as Array).append({"type": "draw", "amount": 1})
	widget.set_display_overrides()
	widget.configure("squall_shot", false, false, true, false, false, true, squall)
	await process_frame
	_expect(widget.sentence_face_plan().is_empty(), "A card with an added action falls back to its icon rows")
	_expect((widget.get("_summary_icon_box") as Control).get_child_count() > 0, "The fallback shows icon rows")
	widget.configure("squall_shot", false, false, true, false, false, true, GameData.card_def("squall_shot"))
	await process_frame
	_expect(not widget.sentence_face_plan().is_empty(), "The pooled widget returns to the sentence face")
	var keg: Dictionary = GameData.card_def("powder_keg")
	keg["actions"][0]["health"] = 4
	widget.configure("powder_keg", false, false, true, false, false, true, keg)
	await process_frame
	_expect(_plan_text(widget.sentence_face_plan()).contains("{health}Health~#4."), "Powder Keg prints the live terrain Health")
	widget.configure("spark_focus", false, false, true, false, false, true, GameData.card_def("spark_focus"))
	await process_frame
	var spark: Dictionary = widget.call("_resolved_sentence_face", widget.display_summary_rows())
	_expect((spark.get("sentence", []) as Array).any(func(segment: Dictionary) -> bool: return segment.get("term") == "vision" and str(segment.get("tooltip", "")).contains("For 2 turns")), "The Vision face term uses its separate duration token")
	widget.queue_free()
	await process_frame

func _check_live_relic_faces() -> void:
	var widget: CardWidget = WidgetScene.instantiate()
	widget.size = WIDGET_SIZES[0]
	root.add_child(widget)
	var display = preload("res://scripts/card_display_overrides.gd")
	var state: Dictionary = {"player": {"pos": Vector2i(2, 2), "hp": 30, "stoneskin": 1}, "relics": ["reinforced_shield"]}
	for card_id: String in ["sun_flash", "hoarfrost_ward"]:
		var expected_block: int = 9 if card_id == "hoarfrost_ward" else 8
		var card: Dictionary = GameData.card_def_for_progression(card_id, state)
		widget.configure(card_id, false, false, true, false, false, true, card)
		display.apply_projection(widget, card, display.for_card(card_id, state, card))
		await process_frame
		var shown: bool = false
		for row: Array in widget.display_summary_rows():
			for token: Dictionary in row:
				if token.get("icon") == "block" and str(token.get("value")) == str(expected_block): shown = true
		_expect(shown, "%s shows Reinforced Shield's Block %d" % [card_id, expected_block])
	state["relics"] = ["sunlit_edge"]
	state["umbra"] = {"light_sources": [{"pos": Vector2i(2, 2), "radius": 2}]}
	var shatter: Dictionary = GameData.card_def_for_progression("shatter", state)
	widget.configure("shatter", false, false, true, false, false, true, shatter)
	display.apply_projection(widget, shatter, display.for_card("shatter", state, shatter))
	await process_frame
	var pierces: bool = false
	for row: Array in widget.display_summary_rows():
		for token: Dictionary in row:
			if token.get("icon") == "pierce": pierces = true
	_expect(pierces, "Shatter in Light shows Sunlit Edge's Pierce token")
	widget.queue_free()
	await process_frame

func _plan_text(plan: Dictionary) -> String:
	var lines: PackedStringArray = PackedStringArray()
	for line: Dictionary in plan.get("lines", []):
		lines.append(str(line["text"]))
	return " / ".join(lines)

## The widget's own geometry: the face sits in the rows box at the lent height.
func _check_plan(card_id: String, plan: Dictionary, widget: CardWidget, widget_size: Vector2) -> void:
	var label: String = "%s %s" % [card_id, widget_size]
	_expect(bool(plan["fits"]), label + " fits the parchment")
	var metrics: Dictionary = _unlent_metrics(widget, plan)
	var box: Control = widget.get("_summary_icon_box")
	_expect(box.custom_minimum_size.y + 0.01 >= float(plan["height"]), label + " rows box holds the face")
	_expect(is_equal_approx(box.custom_minimum_size.y, float(metrics["details_height"]) + float(plan["lend"])), label + " rows box carries the art lend")
	_check_geometry(label, plan, metrics)

## The widget's metrics before the face borrowed art height.
func _unlent_metrics(widget: CardWidget, plan: Dictionary) -> Dictionary:
	var metrics: Dictionary = widget.call("_sentence_face_metrics")
	var lend: float = float(plan["lend"])
	metrics["details_height"] = float(metrics["details_height"]) - lend
	metrics["max_relief"] = float(metrics["max_relief"]) + lend
	metrics["rows_top"] = float(metrics["rows_top"]) + lend
	return metrics

## Every drawn item's horizontal extent is inside the allowed half-width at its
## card height, and the face ends above the parchment's torn lower edge.
func _check_geometry(label: String, plan: Dictionary, metrics: Dictionary) -> void:
	var layout_scale: float = float(metrics["scale"])
	var top: float = float(metrics["rows_top"]) - float(plan["lend"])
	_expect(bool(plan["fits"]), label + " fits")
	_expect(float(plan["lend"]) <= float(metrics["max_relief"]) + 0.001, label + " lend %.1f within %.1f" % [float(plan["lend"]), float(metrics["max_relief"])])
	var chip: Dictionary = plan["chip"]
	if not chip.is_empty():
		var y0: float = top + float(chip["y"])
		_expect(float(chip["width"]) * 0.5 <= FaceLayout.allowed_half_width(y0, y0 + float(chip["height"]), layout_scale) + 0.001, label + " chip clears the parchment edge")
	for line: Dictionary in plan["lines"]:
		var y0: float = top + float(line["y"])
		var allowed: float = FaceLayout.allowed_half_width(y0, y0 + float(line["height"]), layout_scale)
		for piece: Dictionary in line["pieces"]:
			var left: float = float(piece["x"])
			var right: float = left + float(piece.get("w", 0.0))
			_expect(-left <= allowed + 0.001 and right <= allowed + 0.001, "%s '%s' piece %s inside %.1f (%.1f..%.1f)" % [label, str(line["text"]), str(piece.get("text", piece.get("icon", piece.get("pattern", "")))), allowed, left, right])
	var under: Dictionary = plan["under"]
	if not under.is_empty():
		var y0: float = top + float(under["y"])
		var allowed: float = FaceLayout.allowed_half_width(y0, y0 + float(under["height"]), layout_scale)
		for item: Dictionary in under["items"]:
			_expect(-float(item["x"]) <= allowed + 0.001 and float(item["x"]) + float(item["w"]) <= allowed + 0.001, label + " diagram inside the parchment")

func _expect(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(message)
