extends RefCounted

const CONTRACT_PATH: String = "res://tests/opening_boon_probe_contract.json"
const Layout = preload("res://scripts/opening_boon_secondary_layout.gd")

static func contract() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string(CONTRACT_PATH)) as Dictionary

static func rect_near(actual: Rect2, expected: Array, expect: Callable, label: String) -> void:
	var wanted := Rect2(float(expected[0]), float(expected[1]), float(expected[2]), float(expected[3]))
	var tolerance: float = float(contract()["geometry_tolerance_px"])
	expect.call(actual.position.distance_to(wanted.position) <= tolerance and actual.size.distance_to(wanted.size) <= tolerance, "%s: %s expected %s (1px tolerance)" % [label, actual, wanted])

static func offer(scene: Node, modal: Control, expect: Callable) -> void:
	var geometry: Dictionary = contract()["geometry"]
	var row: Control = modal.find_child("OpeningBoonColumns", true, false)
	expect.call(row != null and row.get_child_count() == 3, "Three separate boon slots replace the shared outer frame")
	expect.call(modal.find_child("OpeningBoonPanel", true, false) == null, "The former single framed panel is absent")
	if row == null: return
	rect_near(row.get_global_rect(), geometry["OpeningBoonColumns"], expect, "Offer row")
	for index: int in range(3):
		var slot: Control = row.get_child(index)
		rect_near(slot.get_global_rect(), geometry["BoonSlots"][index], expect, slot.name)
		var card: Control = slot.get_child(0)
		rect_near(Rect2(Vector2.ZERO, card.size), [0, 0, 300, 400], expect, card.name + " size")
		var title: Label = card.find_child("BoonTitle", true, false)
		expect.call(absf(title.position.y - 40.0) <= 1.0, "Title uses the approved y+40 position")
		var zone: Control = card.find_child("BoonPreviewZone", true, false)
		rect_near(Rect2(zone.position, zone.size), geometry["BoonPreviewZone"], expect, "Local preview zone")
		for child: Control in zone.get_children():
			expect.call(zone.get_global_rect().grow(1.0).encloses(child.get_global_rect()), "%s fits its 140px zone: %s inside %s" % [child.name, child.get_global_rect(), zone.get_global_rect()])
		var tag: Control = card.find_child("BoonColumnTag", true, false)
		expect.call(absf(tag.position.x + tag.size.x * 0.5 - 150.0) <= 1.0 and absf(tag.position.y + tag.size.y * 0.5) <= 1.0, "Column tag centres on the top border")
		expect.call(tag.get_child(0).get_theme_font_size("font_size") == 16, "Column tags use 16px small caps")
		var rules: RichTextLabel = card.find_child("BoonRules", true, false)
		expect.call(rules.position.x == 24.0 and rules.size.x == 252.0, "Rules have 24px side padding and 252px width")
		expect.call(rules.get_content_height() <= rules.size.y, "%s rules remain unclipped: %dpx in %dpx" % [card.name, rules.get_content_height(), rules.size.y])
		var typography = preload("res://scripts/ui_typography.gd")
		var font_size: int = rules.get_theme_font_size("normal_font_size")
		expect.call((font_size == typography.SIZE_BODY and rules.get_line_count() <= 4) or (font_size == typography.SIZE_SMALL and rules.get_line_count() <= 5), "Rules use at most four body lines or five next-smaller body lines")
		if card.name != "Boon_purge": rect_near(Rect2(rules.position, rules.size), geometry["BoonRules"], expect, "Local rules zone")
		for socket: Control in zone.find_children("BoonContent_*", "Button", true, false):
			rect_near(Rect2(Vector2.ZERO, socket.size), [0, 0, 96, 96], expect, "Object socket")
		var glyph: Control = zone.find_child("BoonKeywordGlyph", true, false)
		if glyph != null: rect_near(Rect2(Vector2.ZERO, glyph.size), [0, 0, 64, 64], expect, "Keyword glyph")
	_action(modal.find_child("DeclineOpeningBoon", true, false), expect)
	rect_near(scene.get("_dialogue_dialog").get_global_rect(), geometry["OfferDialogue"], expect, "Existing NPC dialogue")
	expect.call(scene.get("_dialogue_overlay").visible and scene.get("_dialogue_portrait_frame").visible, "Actual NPC dialogue and portrait remain visible")
	expect.call(not scene.get("_dialogue_footer").visible and scene.get("_dialogue_choice_bar").get_child_count() == 0, "Offer dialogue has no buttons or advance hint")
	expect.call(scene.call("_board_status_label", {}) == "", "Room status placard is hidden while choosing")

static func secondary(scene: Node, modal: Control, count: int, expect: Callable) -> void:
	var geometry: Dictionary = contract()["geometry"]
	var row: Control = modal.find_child("BoonSpellChoices", true, false)
	expect.call(row != null and row.get_child_count() == count, "Secondary row contains each full spell card and duplicate")
	if row == null: return
	var limits: Dictionary = contract()["secondary"]
	var reward_size: Vector2 = scene.call("_reward_choice_card_size", count, true)
	var card_size: Vector2 = row.get_child(0).size
	var gap: float = float(limits["three_card_gap"] if count == 3 else limits["four_to_six_card_gap"])
	var width: float = count * card_size.x + (count - 1) * gap
	rect_near(row.get_global_rect(), [(1920.0 - width) * 0.5, row.global_position.y, width, card_size.y], expect, "Centred secondary row")
	expect.call(card_size.x <= reward_size.x + 1.0 and card_size.y <= reward_size.y + 1.0, "Cards retain reward size whenever the fixed bounds allow it")
	expect.call(absf(card_size.y / card_size.x - 352.0 / 250.0) <= 0.01, "Full spell cards preserve their native aspect ratio")
	expect.call(row.get_global_rect().end.y <= float(limits["action_top"]) + 1.0, "Secondary cards fit above the unchanged Back pill")
	for index: int in range(count):
		var slot: Control = row.get_child(index)
		rect_near(Rect2(slot.position, slot.size), [index * (card_size.x + gap), 0, card_size.x, card_size.y], expect, "Secondary slot %d" % index)
		var widget: Control = modal.get("_controls")[index]
		expect.call(widget.get_script() == preload("res://scripts/card_widget.gd"), "Secondary choices use production full-card widgets")
		medallion(modal, widget, expect)
	rect_near(modal.find_child("BoonSelectionBanner", true, false).get_global_rect(), geometry["BoonSelectionBanner"], expect, "Reward banner reference")
	var rules: Control = modal.find_child("BoonSecondaryRules", true, false)
	expect.call(absf(rules.global_position.y - 205.0) <= 1.0, "Secondary rules start at y205")
	_action(modal.find_child("BackFromBoonSpellChoice", true, false), expect)
	rect_near(scene.get("_dialogue_dialog").get_global_rect(), geometry["OfferDialogue"], expect, "Secondary NPC dialogue")

static func medallion(modal: Control, widget: Control, expect: Callable) -> void:
	var limits: Dictionary = contract()["secondary"]
	var rules: Control = modal.find_child("BoonSecondaryRules", true, false)
	var top: float = Layout.visual_watch_rect(widget).position.y
	expect.call(top >= float(limits["minimum_medallion_top"]) - 1.0, "Painted cost medallion stays at or below y245, including its crown and hover pose")
	expect.call(top - rules.get_global_rect().end.y >= float(limits["rules_to_medallion_clearance"]) - 1.0, "Cost medallion retains at least 16px below the rules line")

static func tooltip(modal: Control, expect: Callable) -> void:
	var stack: Control = modal.get("_secondary_tooltips")
	expect.call(stack != null and stack.visible and stack.entry_count() > 0, "Explicit inspection shows the real full keyword stack")
	if stack == null or not stack.visible: return
	var rules: Control = modal.find_child("BoonSecondaryRules", true, false)
	var minimum: float = rules.get_global_rect().end.y + float(contract()["secondary"]["rules_to_tooltip_clearance"])
	expect.call(stack.global_position.y >= minimum - 1.0, "Tooltip top stays at least 8px below the rules line")
	expect.call(not stack.get_global_rect().intersects(modal.find_child("BoonSelectionBanner", true, false).get_global_rect()), "The tooltip never covers the banner")

static func _action(button: Button, expect: Callable) -> void:
	expect.call(button != null, "The shared reward pill is present")
	if button == null: return
	expect.call(absf(button.global_position.y - 650.0) <= 1.0 and absf(button.get_global_rect().get_center().x - 960.0) <= 1.0, "Action pill centres at x960, top y650")
	expect.call(absf(button.size.y - preload("res://scripts/ui_skin.gd").BUTTON_HEIGHT_STANDARD) <= 1.0 and button.icon == null, "Action pill has the reward button height and no icon")
