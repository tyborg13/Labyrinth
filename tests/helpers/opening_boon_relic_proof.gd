extends RefCounted

const Boons = preload("res://scripts/opening_boon_rules.gd")
const Card = preload("res://scripts/opening_boon_card.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Data = preload("res://scripts/game_data.gd")
const Elements = preload("res://scripts/element_data.gd")
const TypedArrays = preload("res://scripts/typed_arrays.gd")
const BODY_LINES: int = 4
const SMALL_LINES: int = 5

static func run(viewport: SubViewport, scene: Node, expect: Callable, output: String, baseline: bool) -> Dictionary:
	var result: Dictionary = {"cards": 0, "maximum_lines": 0, "maximum_height": 0, "smaller_body_cards": 0, "grown_cards": 0, "overflowing_cards": 0}
	var table := FileAccess.open(output, FileAccess.WRITE)
	expect.call(table != null, "The boon fit sweep table is writable")
	if table != null:
		table.store_csv_line(PackedStringArray(["boon", "relic", "variant", "lines", "size_step", "font_px", "fits", "content_height", "rules_height", "card_height"]))
	var holder := Control.new()
	viewport.add_child(holder)
	var card: Control
	for offer: Dictionary in _offers():
		card = Card.new()
		holder.add_child(card)
		card.configure(scene, offer)
		# Let the production controls settle before checking the final layout.
		await viewport.get_tree().process_frame
		await viewport.get_tree().process_frame
		_record(card, offer, expect, table, result, baseline)
		card.free()
	holder.free()
	if table != null: table.close()
	print("BOON FIT SWEEP TABLE: " + ProjectSettings.globalize_path(output))
	print("BOON FIT SWEEP: " + JSON.stringify(result))
	return result

static func _offers() -> Array[Dictionary]:
	var offers: Array[Dictionary]
	var definitions: Dictionary = Boons.definitions()
	var starters: Dictionary = Data.starting_equipped_equipment()
	for column: Dictionary in definitions["columns"]:
		for boon: String in column["boons"]:
			var spec: Dictionary = definitions["boons"][boon]
			var base: Dictionary = {"boon": boon, "column": column["label"]}
			match boon:
				"trinket", "pawned_light":
					# Retain the existing cross-rarity stress cases in addition to every rollable relic.
					var relics: Array[String] = Boons.relic_pool("common", {})
					relics.append_array(Boons.relic_pool("rare", {}))
					for id: String in relics:
						offers.append(_with_fields(base, {"relic": id}))
				"armory":
					var slots: Dictionary = Boons.equipment_pool({"equipped_equipment": starters})
					for slot: String in slots:
						for id: String in slots[slot]:
							offers.append(_with_fields(base, {"item": id, "starter": starters[slot]}))
				"elemental_gift", "focus":
					for element: String in Elements.all_elements():
						_spell_offers(offers, _with_fields(base, {"element": element}), Boons.spell_pool(spec["rarity"], element), int(spec["count"]))
				"blood_price":
					_spell_offers(offers, base, Boons.spell_pool(spec["rarity"]), int(spec["count"]))
				_:
					offers.append(base)
	for id: String in Data.equipment_ids():
		if Boons.heirloom_pieces({"equipped_equipment": {Data.equipment_slot(id): id}}).has(id):
			offers.append({"boon": "heirloom", "column": definitions["columns"][0]["label"], "item": id})
	return offers

static func _with_fields(base: Dictionary, fields: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate()
	result.merge(fields)
	return result

static func _spell_offers(offers: Array[Dictionary], base: Dictionary, pool: Array[String], count: int) -> void:
	if pool.size() < count: return
	# Each strip has the same name layout, so cover every name in fixed-size groups.
	for offset: int in range(0, pool.size(), count):
		var spells: Array[String] = TypedArrays.strings(pool.slice(mini(offset, pool.size() - count), mini(offset + count, pool.size())))
		offers.append(_with_fields(base, {"spells": spells}))

static func _record(card: Control, offer: Dictionary, expect: Callable, table: FileAccess, result: Dictionary, baseline: bool) -> void:
	var rich: RichTextLabel = card.get_node("BoonRules")
	var font_size: int = rich.get_theme_font_size("normal_font_size")
	var lines: int = rich.get_line_count()
	var content_height: int = rich.get_content_height()
	var body: bool = font_size == Typography.scaled_size(rich, Typography.SIZE_BODY)
	var grown: bool = card.size.y > Card.CARD_SIZE.y
	var line_limit: int = BODY_LINES if body else SMALL_LINES
	var step: String = "body" if body else "small"
	var variant: String = str(offer.get("item", offer.get("element", "")))
	if offer.has("spells"): variant += " " + ",".join(PackedStringArray(offer["spells"]))
	var context: String = "%s/%s %s" % [offer["boon"], offer.get("relic", ""), variant]
	var fits: bool = (lines <= line_limit or grown) and content_height <= rich.size.y and rich.get_content_width() <= rich.size.x
	fits = _preview_text_fits(card) and fits
	if offer.has("relic"):
		var suffix: String = "" if offer["boon"] == "trinket" else " Start at half @kw(health|Health)."
		expect.call(Boons.text(offer) == str(Data.relic_def(offer["relic"])["description"]) + suffix, "Authored effect and keyword survive: " + context)
	expect.call(rich.position.x == Card.RULES_RECT.position.x and rich.size.x == Card.RULES_RECT.size.x, "Rules retain the authored width and padding: " + context)
	if not baseline:
		expect.call(body or font_size == Typography.scaled_size(rich, Typography.SIZE_SMALL), "Rules use an existing body step: " + context)
		expect.call(fits, "Full boon text fits: " + context)
	if table != null:
		table.store_csv_line(PackedStringArray([offer["boon"], offer.get("relic", ""), variant, str(lines), step, str(font_size), str(fits), str(content_height), str(rich.size.y), str(card.size.y)]))
	result["cards"] += 1
	result["maximum_lines"] = maxi(int(result["maximum_lines"]), lines)
	result["maximum_height"] = maxi(int(result["maximum_height"]), content_height)
	if not body: result["smaller_body_cards"] += 1
	if grown: result["grown_cards"] += 1
	if not fits: result["overflowing_cards"] += 1

static func _preview_text_fits(card: Control) -> bool:
	for label: Label in card.find_children("*", "Label", true, false):
		if not label.visible or label.text.is_empty(): continue
		if label.get_visible_line_count() < label.get_line_count(): return false
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			var font: Font = label.get_theme_font("font")
			if font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x > label.size.x + 1.0: return false
	return true
