extends RefCounted
## Card summary changes re-enter the metric pass at the same native size.
## Validate the live override, rather than a remembered scale: pooled controls,
## theme edits and resize callers must still repair their output synchronously.

const Typography = preload("res://scripts/ui_typography.gd")

static func constant_override(control: Control, key: StringName, value: int) -> void:
	if not control.has_theme_constant_override(key) or control.get_theme_constant(key) != value:
		control.add_theme_constant_override(key, value)

static func font_size_override(control: Control, key: StringName, value: int) -> void:
	if not control.has_theme_font_size_override(key) or control.get_theme_font_size(key) != value:
		control.add_theme_font_size_override(key, value)

static func label_size(label: Label, value: int) -> void:
	font_size_override(label, &"font_size", Typography.scaled_size(label, value))

static func rich_text_size(label: RichTextLabel, value: int) -> void:
	var scaled: int = Typography.scaled_size(label, value)
	for key: StringName in [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size", &"mono_font_size"]:
		font_size_override(label, key, scaled)

static func horizontal_margins(style: StyleBox, left: float, right: float) -> void:
	if style.content_margin_left != left:
		style.content_margin_left = left
	if style.content_margin_right != right:
		style.content_margin_right = right

static func apply_scaled_node_metrics(card: Control) -> void:
	var margin: MarginContainer = card.get_node("Margin") as MarginContainer
	if margin != null:
		constant_override(margin, "margin_left", card._scaled_card_int(16, 6))
		constant_override(margin, "margin_top", card._scaled_card_int(14, 5))
		constant_override(margin, "margin_right", card._scaled_card_int(16, 6))
		constant_override(margin, "margin_bottom", card._scaled_card_int(14, 5))
	constant_override(card.vbox, "separation", card._scaled_card_int(7, 2))
	card.title_label.custom_minimum_size = Vector2(0.0, card._scaled_card_value(40.0, 22.0))
	var art_bleed: MarginContainer = card.get_node("Margin/VBox/ArtBleed") as MarginContainer
	if art_bleed != null:
		constant_override(art_bleed, "margin_left", -card._scaled_card_int(5, 1))
		constant_override(art_bleed, "margin_top", -card._scaled_card_int(2, 1))
		constant_override(art_bleed, "margin_right", -card._scaled_card_int(5, 1))
		constant_override(art_bleed, "margin_bottom", -card._scaled_card_int(1, 1))
	var details_margin: MarginContainer = card.get_node("Margin/VBox/DetailsPanel/DetailsMargin") as MarginContainer
	if details_margin != null:
		constant_override(details_margin, "margin_left", card._scaled_card_int(7, 2))
		constant_override(details_margin, "margin_top", card._scaled_card_int(3, 1))
		constant_override(details_margin, "margin_right", card._scaled_card_int(7, 2))
		constant_override(details_margin, "margin_bottom", card._scaled_card_int(3, 1))
	constant_override(card.details_vbox, "separation", card._scaled_card_int(5, 1))
	if card._summary_icon_box != null:
		constant_override(card._summary_icon_box, "separation", card._scaled_card_int(5, 1))
	# Rules-text cards (Rites) keep their words on the parchment, inside the
	# frame border that the outer and details margins alone do not clear.
	if card._desc_text_inset == null:
		card._desc_text_inset = StyleBoxEmpty.new()
		card.desc_label.add_theme_stylebox_override("normal", card._desc_text_inset)
		card.desc_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var inset: float = card._scaled_card_value(card.CARD_FRAME_MARGIN - 13.0, 4.0)
	horizontal_margins(card._desc_text_inset, inset, inset)
