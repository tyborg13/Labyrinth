extends RefCounted

const Audit = preload("res://tests/helpers/card_legibility_audit.gd")
const Settle = preload("res://tests/helpers/card_legibility_settle.gd")
const DELAY_SECONDS: float = 1.0
const TWEEN_SECONDS: float = 0.05
const SUBTITLE_FIXTURE_TEXT: String = "Audit subtitle"

class Unstable extends Control:
	func _process(_delta: float) -> void:
		scale.x = 0.9 if scale.x == 1.0 else 1.0

static func run(tree: SceneTree, audit: RefCounted, expect: Callable) -> void:
	var context: Dictionary = {"id": "negative", "factory": "scaled", "size": Audit.Card.BASE_CARD_SIZE, "exempt": false}
	var entry: Dictionary = {"id": "thorn_crown_pact", "definition": Audit.Data.card_def("thorn_crown_pact")}
	var instance: Dictionary = audit.make_card(context, entry)
	tree.root.add_child(instance["surface"])
	await Settle.wait_for(tree, [instance["widget"]])
	instance["widget"].hide()
	expect.call(Audit.sample_errors(Audit.measure(instance["widget"]), entry, context).has("sample face hidden"), "Negative hidden face is rejected")
	instance["surface"].free()
	instance = audit.make_card(context, entry)
	tree.root.add_child(instance["surface"])
	await Settle.wait_for(tree, [instance["widget"]])
	var summary: Node = instance["widget"].get("_summary_icon_box")
	if summary != null:
		instance["widget"].set("_summary_icon_box", null)
		summary.free()
	instance["widget"].get("desc_label").hide()
	var missing: Array = Audit.sample_errors(Audit.measure(instance["widget"]), entry, context)
	expect.call(missing.has("missing rules content nodes"), "Negative missing rules node is rejected even with a time numeral")
	expect.call(missing.has("missing expected icon measurement"), "Negative missing expected icons are rejected")
	instance["surface"].free()
	expect.call(not Audit.coverage_errors(context, 0).is_empty(), "Negative empty context is rejected")
	instance = audit.make_card(context, entry)
	tree.root.add_child(instance["surface"])
	var tween: Tween = instance["surface"].create_tween()
	tween.tween_property(instance["surface"], "scale", Vector2.ONE * 0.5, TWEEN_SECONDS).set_delay(DELAY_SECONDS)
	var waited: Dictionary = await Settle.wait_for(tree, [instance["widget"]])
	expect.call(waited["settled"] and waited["elapsed_ms"] >= int(DELAY_SECONDS * 1000), "Settler waits through the one-second delayed tween")
	expect.call(not Audit.sample_errors(Audit.measure(instance["widget"]), entry, context).is_empty(), "Delayed scale mutation fails after its real resting transform")
	instance["surface"].free()
	var unstable := Unstable.new()
	tree.root.add_child(unstable)
	var never: Dictionary = await Settle.wait_for(tree, [unstable])
	expect.call(not never["settled"] and never["elapsed_ms"] >= 3000, "An unsettled ancestor fails at the 3-second cap")
	unstable.free()
	await _rules_body_fixtures(tree, expect)

static func _rules_body_fixtures(tree: SceneTree, expect: Callable) -> void:
	var live := preload("res://tests/helpers/card_legibility_contexts.gd").new()
	await live.setup(tree, 1)
	var context: Dictionary = {"id": "graftwright_inspection", "factory": "rules_tooltip", "exempt": false}
	var faces: Array = await live.open(context)
	expect.call(faces.size() == 1, "Negative rules fixtures open the production Graftwright inspection")
	if faces.is_empty():
		live.cleanup()
		return
	var settled: Dictionary = await Settle.wait_for(tree, faces)
	expect.call(settled["settled"], "Production Graftwright rules fixture settles")
	var panel: Control = faces[0]
	var source: Control = live.workers[0]["scene"].find_child("GraftwrightView", true, false).find_child("SourceCard_0", true, false)
	var id: String = str(source.get_meta("graft_card_id"))
	var entry: Dictionary = {"id": id, "definition": Audit.Data.card_def(id)}
	# Capture the authored fixture nodes before rearranging them. Do not use the
	# locator under test to choose which label gets hidden or emptied.
	var content: Control = panel.get_child(0)
	var body: Control = content.get_child(1)
	expect.call(body is Label or body is RichTextLabel, "Production Graftwright has an identifiable rules body")
	if not (body is Label or body is RichTextLabel):
		live.cleanup()
		return
	var baseline: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(baseline, entry, context).is_empty() and Audit.rules_body(panel, entry["definition"]) == body and baseline["rules_body_match_count"] == 1 and baseline["content_text_runs"] == 1 and baseline["runs"][0]["path"] == str(panel.get_path_to(body)), "Only the real visible, nonempty Graftwright rules body is measured")
	# A visible title and Back action cannot rescue hidden/empty/missing rules.
	body.hide()
	var hidden: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(hidden, entry, context).has("rules body hidden") and hidden["text_px"]["rules"] == null, "Negative hidden Graftwright rules body is rejected")
	body.show()
	content.move_child(body, 0)
	expect.call(Audit.floor_errors(Audit.measure(panel, entry["definition"])).is_empty(), "Reordering a visible rules body preserves its content identity")
	body.hide()
	var swapped: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(swapped, entry, context).has("rules body hidden") and swapped["text_px"]["rules"] == null, "Swapped title cannot mask the hidden rules body")
	body.show()
	content.move_child(body, 1)
	var subtitle := Label.new()
	subtitle.name = "AuditSubtitle"
	subtitle.text = SUBTITLE_FIXTURE_TEXT
	content.add_child(subtitle)
	content.move_child(subtitle, 1)
	expect.call(Audit.rules_body(panel, entry["definition"]) == body and Audit.floor_errors(Audit.measure(panel, entry["definition"])).is_empty(), "Inserted subtitle is not confused with visible rules")
	body.hide()
	var subtitle_hidden: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(subtitle_hidden, entry, context).has("rules body hidden") and subtitle_hidden["text_px"]["rules"] == null, "Inserted subtitle cannot mask hidden rules")
	body.show()
	body.set("text", "")
	var subtitle_empty: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(subtitle_empty, entry, context).has("missing rules body") and subtitle_empty["rules_body_match_count"] == 0, "Inserted subtitle cannot mask empty rules")
	subtitle.free()
	_restore_rules_body(body, entry["definition"])
	var duplicate := Label.new()
	duplicate.text = Audit.Icons.card_rules_text(entry["definition"])
	content.add_child(duplicate)
	var ambiguous: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(ambiguous, entry, context).has("ambiguous rules body") and ambiguous["rules_body_match_count"] == 2 and ambiguous["text_px"]["rules"] == null, "Two matching rules nodes are rejected without measuring either")
	duplicate.hide()
	expect.call(Audit.floor_errors(Audit.measure(panel, entry["definition"])).has("ambiguous rules body"), "A hidden duplicate still makes rules identity ambiguous")
	duplicate.free()
	var formatted: Dictionary = entry["definition"].duplicate(true)
	formatted["description"] = " [b]" + str(formatted.get("description", "")) + "[/b]\n\t"
	expect.call(Audit.floor_errors(Audit.measure(panel, formatted)).is_empty(), "Expected rules use the same BBCode and whitespace normalization")
	body.set("text", " [b]" + Audit.Icons.card_rules_text(entry["definition"]) + "[/b]\n\t")
	expect.call(Audit.floor_errors(Audit.measure(panel, entry["definition"])).is_empty(), "Actual rules use the same BBCode and whitespace normalization")
	_restore_rules_body(body, entry["definition"])
	expect.call(Audit.floor_errors(Audit.measure(panel)).has("missing rules body"), "Missing expected definition cannot infer rules identity from panel labels")
	body.set("text", "")
	var empty: Dictionary = Audit.measure(panel, entry["definition"])
	expect.call(Audit.sample_errors(empty, entry, context).has("missing rules body") and empty["rules_body_match_count"] == 0 and empty["content_text_runs"] == 0, "Negative emptied Graftwright rules body is rejected")
	body.set("text", " \n\t")
	expect.call(Audit.sample_errors(Audit.measure(panel, entry["definition"]), entry, context).has("missing rules body"), "Whitespace-only Graftwright rules are rejected")
	body.set("text", SUBTITLE_FIXTURE_TEXT)
	expect.call(Audit.sample_errors(Audit.measure(panel, entry["definition"]), entry, context).has("missing rules body"), "Nonempty unrelated text cannot substitute for expected rules")
	body.free()
	expect.call(Audit.sample_errors(Audit.measure(panel, entry["definition"]), entry, context).has("missing rules body"), "Back action cannot substitute for a missing Graftwright rules body")
	live.cleanup()

static func _restore_rules_body(body: Control, definition: Dictionary) -> void:
	var text: String = Audit.Icons.card_rules_text(definition)
	if body is RichTextLabel: Audit.InlineText.apply_to(body, text)
	else: body.set("text", text)
