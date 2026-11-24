extends SceneTree
## Adapted from crd-28. Export the live widget's neutral rules model.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Face = preload("res://scripts/card_face_spec.gd")
const Hover = preload("res://scripts/card_keyword_hover.gd")
const Population = preload("res://tools/txt43/population.gd")
const Widget = preload("res://scenes/card_widget.tscn")
const FIXTURE_CARD_SIZE := Vector2(250, 352)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	var args := OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Usage: dump_cards.gd -- <output.json>")
		quit(2)
		return
	var sources: Dictionary = Population.collect()
	var ids: Array = Data.cards().keys()
	ids.sort()
	var cards: Dictionary = {}
	var widget: CardWidget = Widget.instantiate()
	widget.size = FIXTURE_CARD_SIZE
	get_root().add_child(widget)
	for id: String in ids:
		var card: Dictionary = Data.card_def_for_progression(id, {})
		widget.configure(id, false, false, true, false, false, true, card)
		widget.set_display_overrides()
		var catalog: Dictionary = _presentation(widget)
		var display: Dictionary = Display.for_card(id, {}, card)
		Display.apply_projection(widget, card, display)
		var hand: Dictionary = _presentation(widget)
		cards[id] = {
			"name": card["name"], "catalog": catalog,
			"hand": hand if hand != catalog else {},
			"legacy": {},
		}
		var legacy: Dictionary = Data.card_def_for_progression(id, {Data.LEGACY_STARTER_CARDS_KEY: true})
		if legacy != card:
			widget.configure(id, false, false, true, false, false, true, legacy)
			Display.apply_projection(widget, legacy, Display.for_card(id, {Data.LEGACY_STARTER_CARDS_KEY: true}, legacy))
			cards[id]["legacy"] = _presentation(widget)
	widget.free()
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write card inventory: %s" % FileAccess.get_open_error())
		quit(1)
		return
	file.store_string(JSON.stringify({"cards": cards, "sources": sources}, "  ") + "\n")
	file.close()
	print("CRD32 EXPORT: %d catalog IDs; %d source lists" % [cards.size(), sources.size()])
	quit(0)

func _presentation(widget: CardWidget) -> Dictionary:
	var rows: Array = widget.display_summary_rows()
	var sentence: Dictionary = widget._resolved_sentence_face(rows)
	var actual_rows: Array = []
	if sentence.is_empty():
		var spec: Dictionary = Face.spec_for(widget.card_id)
		actual_rows = Face.ordered_icon_rows(widget.card_id, Face.display_icon_rows(spec, rows))
	else:
		for segment: Dictionary in sentence["sentence"]:
			if segment.has("pattern"):
				var id: String = segment["pattern"]
				segment["offsets"] = Face.pattern_offsets(id)
				segment["show_origin"] = Face.pattern_shows_origin(id)
	var panels: Array[Dictionary]
	for row: Array in actual_rows:
		for token: Dictionary in row:
			token["audit_display"] = Icons.plain_text_for_tokens([token])
	for panel: Dictionary in Hover.entries_for(widget):
		panels.append({
			"icon": panel["icon"], "term": panel["glossary_key"], "title": panel["title"],
			"text": panel["description"], "display": panel.get("display_description", panel["description"]),
		})
	var native: Array[Dictionary]
	var summary: Control = widget.get("_summary_icon_box")
	if summary.visible:
		_collect_tooltips(summary, native)
	var badge: Control = widget.get_node("TimeCostBadge")
	return {
		"rows": actual_rows, "sentence": sentence,
		"plain_face": widget.desc_label.text if widget.desc_label.visible else "",
		"face": Icons.plain_text_for_rows(actual_rows),
		"panels": panels, "native": native,
		"time": badge.get("value"), "time_hover": badge.tooltip_text,
		"empower": Display.empower_panel(widget._display_card_def(), {}).get("card_tooltip", "")
			if not (widget._display_card_def().get("empower", {}) as Dictionary).is_empty() else "",
	}

func _collect_tooltips(node: Node, entries: Array[Dictionary]) -> void:
	if node is Control:
		var text: String = node.tooltip_text
		if not text.is_empty():
			var route: Dictionary = node.get_meta("tooltip_loop_route", {})
			var entry: Dictionary = {"term": route.get("term", ""), "text": text}
			if not entries.has(entry):
				entries.append(entry)
	for child: Node in node.get_children(): _collect_tooltips(child, entries)
