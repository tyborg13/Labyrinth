extends "res://scripts/card_widget.gd"
## The shop scales the complete canonical face. Only text below the Deck floor
## steps up; the frame, art, icons and all other card contexts keep their sizes.
const MINIMUM_PHYSICAL_TEXT_PX: float = 9.0
const READABLE_SUMMARY_CARD_ID: String = "flame_jet"
const TYPE_STEPS := [UiTypography.SIZE_CAPTION, UiTypography.SIZE_SMALL,
	UiTypography.SIZE_BODY, UiTypography.SIZE_BODY_LARGE, UiTypography.SIZE_SECTION,
	UiTypography.SIZE_SECTION_LARGE, UiTypography.SIZE_TITLE, UiTypography.SIZE_HERO,
	UiTypography.SIZE_BANNER]

func _summary_value_label(value_text: String, tooltip: String, label_size: int, token: Dictionary, conditional: bool = false) -> Label:
	var label: Label = super._summary_value_label(value_text, tooltip, label_size, token, conditional)
	if card_id == READABLE_SUMMARY_CARD_ID:
		label.add_theme_font_size_override("font_size", _readable_size(label.get_theme_font_size("font_size")))
	return label

func _readable_size(current: int) -> int:
	if not is_inside_tree() or not UiTypography.is_handheld_output(self): return current
	var transform: Transform2D = get_viewport().get_final_transform() * get_global_transform_with_canvas()
	var physical_scale: float = absf(transform.get_scale().y)
	# Focus lifts the offer temporarily. A refit during that lift must still meet
	# the floor after it returns to rest; never borrow readability from hover.
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor is Control and ancestor.has_meta("shop_item_id"):
			physical_scale /= absf((ancestor as Control).scale.y)
			break
		ancestor = ancestor.get_parent()
	if current * physical_scale >= MINIMUM_PHYSICAL_TEXT_PX: return current
	for step: int in TYPE_STEPS:
		if step > current and step * physical_scale >= MINIMUM_PHYSICAL_TEXT_PX: return step
	return current
