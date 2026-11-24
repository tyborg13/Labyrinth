extends RefCounted
## Check the live creature detail at the actual clip bounds of its scroll view.

const Assets = preload("res://scripts/asset_loader.gd")
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const Data = preload("res://scripts/game_data.gd")
const Split = preload("res://scripts/enemy_mechanics/split_trait_text.gd")
const Traits = preload("res://scripts/enemy_mechanics/unit_traits.gd")

const TOLERANCE: float = 1.0


static func inspect_top(book: Control, entry: Dictionary, expect: Callable) -> Dictionary:
	var enemy_id: String = entry["enemy_id"]
	var def: Dictionary = Data.enemy_def(enemy_id)
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	var title: Label = book._grimoire_detail_title
	var art: TextureRect = book._grimoire_detail_icon
	var body: RichTextLabel = book._grimoire_detail_body
	var bounds: Rect2 = scroll.get_global_rect().grow(TOLERANCE)
	expect.call(title.is_visible_in_tree() and title.text == entry["title"], enemy_id + " has the authored title")
	expect.call(art.is_visible_in_tree() and art.texture != null and art.texture == Assets.load_texture(def["art_path"]),
		enemy_id + " shows the catalog art")
	_check_label(title, title.get_parent().get_global_rect(), enemy_id, expect)
	expect.call(not art.get_global_rect().intersects(title.get_global_rect()), enemy_id + " art and title do not overlap")
	expect.call(title.get_global_rect().end.y <= bounds.position.y + TOLERANCE, enemy_id + " fixed title clears the scroll pane")
	var lore: Array = entry["lore"]
	expect.call(lore.size() == 2 and body.get_parsed_text() == "\n\n".join(lore), enemy_id + " renders both exact lore paragraphs")
	_check_label(body, bounds, enemy_id + " lore", expect)

	var unit: Dictionary = {"type": enemy_id}
	var trait_count: int = Traits.tokens(unit).size() + int(not Burst.trait_token(unit).is_empty()) 		+ int(not Split.trait_token(unit).is_empty())
	var traits: Control = _section(book, "Traits", trait_count, enemy_id, expect)
	var instance: Dictionary = BattlefieldRules.instance_for(enemy_id)
	var rule: Control = _section(book, "Battlefield Rule", int(not instance.is_empty()), enemy_id, expect)
	if bool(def.get("guardian", false)):
		expect.call(rule != null, enemy_id + " Guardian has a Battlefield Rule")
	if rule != null:
		var sentence: RichTextLabel = rule.get_child(1).get_child(1).get_child(1)
		expect.call(sentence.get_parsed_text() == instance["sentence"], enemy_id + " shows the exact Battlefield Rule")
	var intents: Array = def["intents"]
	var moves: Control = _section(book, "Moves", intents.size(), enemy_id, expect)
	if moves == null or moves.get_child_count() != intents.size() * 2 + 1:
		return {}
	for index: int in range(intents.size()):
		var row: Control = moves.get_child(index * 2 + 1)
		var name_label: Label = row.get_child(1).get_child(0)
		var time_label: Label = row.get_child(2)
		expect.call(name_label.text == intents[index]["name"] and time_label.text == "Time %d" % int(intents[index]["time"]),
			enemy_id + " has catalog move and Time at row %d" % (index + 1))
	var ordered: Array[Control]
	ordered.append(body)
	for section: Control in [rule, traits, moves]:
		if section == null:
			continue
		var previous: Rect2 = ordered.back().get_global_rect()
		var rect: Rect2 = section.get_global_rect()
		expect.call(previous.end.y <= rect.position.y + TOLERANCE, enemy_id + " sections are ordered without overlap")
		expect.call(rect.position.x >= bounds.position.x and rect.end.x <= bounds.end.x, enemy_id + " sections fit the scroll width")
		ordered.append(section)
	var bottom: float = moves.get_global_rect().end.y
	var overflow: bool = bottom > bounds.end.y
	var visible_at_top: Dictionary = _visible_rows(ordered, bounds)
	return {"id": enemy_id, "moves": intents.size(), "traits": trait_count, "rule": rule != null,
		"overflow": overflow, "sections": ordered, "visible_at_top": visible_at_top}


static func inspect_bottom(book: Control, page: Dictionary, expect: Callable) -> void:
	var scroll: ScrollContainer = book._grimoire_detail_scroll
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	expect.call(scroll.scroll_vertical > 0 and absf(bar.max_value - bar.page - bar.value) <= TOLERANCE,
		page["id"] + " scroll reaches the bottom")
	var bounds: Rect2 = scroll.get_global_rect().grow(TOLERANCE)
	var sections: Array[Control] = page["sections"]
	var moves: Control = sections.back()
	expect.call(bounds.encloses(moves.get_child(moves.get_child_count() - 2).get_global_rect()),
		page["id"] + " can show the full last move")
	var visible: Dictionary = page["visible_at_top"].duplicate()
	visible.merge(_visible_rows(sections, bounds))
	for section: Control in sections.slice(1):
		for child: Control in section.get_children():
			if child is HBoxContainer:
				expect.call(visible.has(child.get_instance_id()), page["id"] + " has a full view of each row in the two captures")


static func _visible_rows(sections: Array[Control], bounds: Rect2) -> Dictionary:
	var visible: Dictionary = {}
	for section: Control in sections.slice(1):
		for child: Control in section.get_children():
			if child is HBoxContainer and bounds.encloses(child.get_global_rect()):
				visible[child.get_instance_id()] = true
	return visible


static func _section(book: Control, title: String, count: int, enemy_id: String, expect: Callable) -> Control:
	var section: Control = book.find_child("Grimoire" + title.replace(" ", ""), true, false)
	var context: String = enemy_id + " " + title
	expect.call((section != null) == (count > 0), context + " presence matches the catalog")
	if section == null:
		return null
	expect.call(section.is_visible_in_tree() and section.get_child_count() == 1 + count * 2,
		context + " has one header and the expected row and separator count")
	_check_label(section.get_child(0).get_child(0), section.get_child(0).get_global_rect(), context, expect)
	for row: Control in section.get_children().slice(1):
		if not row is HBoxContainer:
			continue
		var bounds: Rect2 = row.get_global_rect()
		var icon: TextureRect = row.get_child(0).find_children("*", "TextureRect", true, false)[0]
		expect.call(icon.is_visible_in_tree() and icon.texture != null, context + " row has an icon")
		var previous: Control
		for column: Control in row.get_children():
			expect.call(bounds.grow(TOLERANCE).encloses(column.get_global_rect()), context + " row column fits")
			if previous != null:
				expect.call(previous.get_global_rect().end.x <= column.get_global_rect().position.x + TOLERANCE,
					context + " row columns do not overlap")
			previous = column
		for label: Node in row.find_children("*", "", true, false):
			if label is Label or label is RichTextLabel:
				_check_label(label, bounds, context, expect)
	return section


static func _check_label(label: Control, bounds: Rect2, context: String, expect: Callable) -> void:
	expect.call(label.is_visible_in_tree() and bounds.grow(TOLERANCE).encloses(label.get_global_rect()),
		"%s label fits layout (%s in %s)" % [context, label.get_global_rect(), bounds])
	if label is RichTextLabel:
		expect.call(label.get_content_width() > 0 and label.get_content_width() <= label.size.x + TOLERANCE
			and label.get_content_height() <= label.size.y + TOLERANCE, context + " rich text is nonempty and fits")
	elif label is Label:
		expect.call(not label.text.is_empty() and label.get_visible_line_count() == label.get_line_count(),
			context + " label is nonempty and shows all lines")
