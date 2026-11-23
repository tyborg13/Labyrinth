extends SceneTree
## Headless semantic snapshot of the production card surfaces for this audit.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Display = preload("res://scripts/card_display_overrides.gd")
const Faces = preload("res://scripts/card_face_spec.gd")
const Patterns = preload("res://scripts/pattern_text.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")
const Widget = preload("res://scenes/card_widget.tscn")
const AUDIT_SIZE := Vector2(250, 352)

var _widget: Control
var _text := RichTextLabel.new()

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Runtime.apply_from_environment()
	var args := OS.get_cmdline_user_args()
	if args.is_empty() or args.size() > 2:
		push_error("Usage: dump_cards.gd -- <output.json> [<upgrade-output.json>]")
		_text.free()
		quit(2)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Cannot write card inventory: %s" % FileAccess.get_open_error())
		_text.free()
		quit(1)
		return
	_widget = Widget.instantiate()
	_widget.size = AUDIT_SIZE
	root.add_child(_widget)
	var cards: Dictionary = {}
	var skipped: Dictionary = {}
	var panel_count: int = 0
	var hand_differences: int = 0
	var item_variants: int = 0
	var legacy_variants: int = 0
	var upgrades: Dictionary = {}
	for id: String in Data.cards():
		var raw: Dictionary = Data.cards()[id]
		if raw.get("retired", false):
			skipped[id] = raw.get("replacement_id", "")
			continue
		var card: Dictionary = Data.card_def(id)
		var catalog: Dictionary = _surface(id, card, Icons.rows_for_card(card), false)
		var display: Dictionary = Display.for_card(id, {}, card)
		var hand: Dictionary = _surface(id, card, display["summary_rows"], true)
		var row: Dictionary = {"card": card, "catalog": catalog}
		panel_count += (catalog["panels"] as Array).size()
		if hand != catalog:
			row["hand"] = hand
			hand_differences += 1
		if Data.card_def(id, true) != card:
			row["legacy_starter"] = _progression_surface(id, {Data.LEGACY_STARTER_CARDS_KEY: true})
			legacy_variants += 1
		if Data.card_is_item(id):
			var ledger: Dictionary = _progression_surface(id, {"relics": ["quartermasters_ledger"]})
			if ledger != hand:
				row["once_per_combat"] = ledger
				item_variants += 1
			var retort: Dictionary = _progression_surface(id, {"relics": ["alchemists_retort"]})
			if retort != hand:
				row["alchemists_retort"] = retort
		elif args.size() == 2:
			upgrades[id] = _upgrade_surfaces(id)
		cards[id] = row
	file.store_string(JSON.stringify({"cards": cards, "skipped": skipped}, "", false) + "\n")
	file.close()
	_text.free()
	print("TXT25 INVENTORY: %d live cards, %d retired IDs, %d catalog panels, %d hand differences, %d item variants" % [cards.size(), skipped.size(), panel_count, hand_differences, item_variants])
	print("TXT25 LEGACY: %d resumable starter variants" % legacy_variants)
	if args.size() == 2:
		var upgrade_file := FileAccess.open(args[1], FileAccess.WRITE)
		if upgrade_file == null:
			push_error("Cannot write upgrade inventory: %s" % FileAccess.get_open_error())
			quit(1)
			return
		var variant_count: int = 0
		for variants: Array in upgrades.values():
			variant_count += variants.size()
		upgrade_file.store_string(JSON.stringify(upgrades, "", false) + "\n")
		upgrade_file.close()
		print("TXT25 UPGRADES: %d first-step previews across %d card IDs" % [variant_count, upgrades.size()])
	quit(0)

func _progression_surface(id: String, state: Dictionary) -> Dictionary:
	var card: Dictionary = Data.card_def_for_progression(id, state)
	var rows: Array = Display.for_card(id, state, card)["summary_rows"]
	return _surface(id, card, rows, true)

func _upgrade_surfaces(id: String) -> Array:
	var result: Array = []
	for element: Dictionary in Data.upgradeable_elements_for_card(id, {}):
		for option: Dictionary in Data.upgrade_options_for_element(id, element, {}):
			var card: Dictionary = Data.preview_card_with_mod(id, option, {})
			var rows: Array = Display.for_card(id, {}, card)["summary_rows"]
			result.append({"option": option, "display": _surface(id, card, rows, false)})
	return result

func _surface(id: String, card: Dictionary, rows: Array, hand: bool) -> Dictionary:
	_widget.card_id = id
	var face: Dictionary = _widget.call("_resolved_sentence_face", rows)
	var face_text: Array = []
	var face_patterns: Array = []
	if face.is_empty() and rows.is_empty():
		var empty_face: Dictionary = _content(Icons.card_rules_text(card))
		face_text.append(empty_face["text"])
		face_patterns.append_array(empty_face["diagrams"])
	elif face.is_empty():
		var face_rows: Array = Faces.ordered_icon_rows(id, Faces.display_icon_rows(Faces.spec_for(id), rows))
		for row: Array in face_rows:
			var tokens: Array = []
			for token: Dictionary in row:
				var kind: String = str(token.get("kind", ""))
				if kind == "aoe_pattern":
					face_patterns.append({"offsets": _offsets(token.get("pattern", [])), "origin_reference": token.get("show_origin", false)})
					tokens.append("[diagram %d]" % face_patterns.size())
				elif kind == "rules_text":
					var rendered: Dictionary = _content(Icons.token_value_text(token))
					for diagram: Dictionary in rendered["diagrams"]:
						face_patterns.append(diagram)
					tokens.append(rendered["text"])
				else:
					var icon: String = str(token.get("icon", ""))
					var value: String = Icons.token_value_text(token)
					var icon_tag: String = "[%s]" % icon if not icon.is_empty() else ""
					tokens.append((" ".join([icon_tag, value])).strip_edges())
			face_text.append(" · ".join(tokens))
	else:
		var chip: Variant = face.get("chip")
		if chip is Dictionary:
			face_text.append("%s [range] %s" % [chip["word"], chip["display"]])
		var sentence: String = ""
		for segment: Dictionary in face["sentence"]:
			if segment.has("pattern"):
				var pattern: String = segment["pattern"]
				face_patterns.append({"offsets": _offsets(Faces.pattern_offsets(pattern)), "origin_reference": Faces.pattern_shows_origin(pattern)})
				sentence += "[diagram %d]" % face_patterns.size()
			elif segment.has("text"):
				sentence += str(segment["text"])
			elif segment.has("duration"):
				sentence += str(segment.get("display", int(segment["duration"])))
			elif segment.has("term"):
				sentence += "[%s] %s" % [segment["term"], segment["word"]]
				if segment.get("number") != null:
					sentence += " " + str(segment["display"])
			else:
				sentence += "[%s] %s%s" % [segment["damage"], "+" if segment.get("bonus", false) else "", segment["display"]]
		face_text.append(sentence)
	var leading: Array = ["rite"] if Icons.card_is_rite(card) else []
	var panels: Array = []
	var embedded_panels: Array = []
	for panel: Dictionary in Icons.tooltip_entries_for_rows(rows, leading):
		var plain: String = panel["description"]
		var body: String = str(panel.get("display_description", plain))
		var content: Dictionary = _content(body)
		if plain != body:
			# The embedded item/equipment preview feeds the original body into
			# UiTooltipPanel, where the ordinary pattern rewrites still run.
			var embedded: Dictionary = _content(plain)
			if embedded != content:
				embedded_panels.append(_panel_copy(panel, embedded))
		if hand and body.begins_with("@pattern("):
			continue # CardFocusTooltipStack.show_for skips this panel in the hand.
		panels.append(_panel_copy(panel, content))
	var printed_cost: int = maxi(1, int(card["time"]))
	var cost: int = printed_cost + int(card.get("_item_time_surcharge", 0)) + int(card.get("_tempo_time_surcharge", 0))
	return {
		"time": cost, "face": face_text, "face_diagrams": face_patterns, "panels": panels,
		"embedded_panel_differences": embedded_panels,
		"inspection": _content(Display.rules_text(id, card, rows)),
		"catalog_description": _content(str(card["description"])),
	}

func _panel_copy(panel: Dictionary, content: Dictionary) -> Dictionary:
	return {"title": panel["title"], "term": panel["glossary_key"], "text": content["text"], "diagrams": content["diagrams"]}

func _content(text: String) -> Dictionary:
	var display: String = Patterns.display_rules(text)
	var diagrams: Array = []
	for token: RegExMatch in Patterns.matches(display):
		diagrams.append({"offsets": _offsets(Patterns.offsets(token.get_string(1), int(token.get_string(2)))), "origin": token.get_string(3)})
	Inline.apply_to(_text, display)
	return {"text": _text.get_parsed_text().strip_edges(), "diagrams": diagrams}

func _offsets(raw: Array) -> Array:
	var result: Array = []
	for offset: Variant in raw:
		if offset is Vector2i or offset is Vector2:
			result.append([int(offset.x), int(offset.y)])
		else:
			result.append([int(offset[0]), int(offset[1])])
	return result
