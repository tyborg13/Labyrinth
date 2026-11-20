extends RefCounted

const Typography = preload("res://scripts/ui_typography.gd")

static func fit_row(row: HBoxContainer, width_limit: float, minimum_width: float) -> void:
	var actions: Array[Button]
	var remaining: float = width_limit
	var separation: int = row.get_theme_constant("separation")
	for button: Button in row.get_children():
		if not button.visible: continue
		remaining -= separation
		if button.has_meta("reward_heal_result_hp") and not button.get_meta("reward_heal_fully_wasted"):
			actions.append(button)
		else:
			remaining -= button.get_combined_minimum_size().x
	if actions.is_empty(): return
	remaining = maxf(1.0, remaining + separation) / actions.size()
	for button: Button in actions:
		_fit(button, remaining, minimum_width)

static func _fit(button: Button, width_limit: float, minimum_width: float) -> void:
	var font: Font = button.get_theme_font("font")
	var padding: Vector2 = button.get_theme_stylebox("normal").get_minimum_size()
	var reserved: float = padding.x
	# An expanded icon still occupies its height-limited width when painted.
	if button.icon != null and button.icon_alignment != HORIZONTAL_ALIGNMENT_CENTER:
		var icon_width: float = button.icon.get_width()
		var max_icon_width: int = button.get_theme_constant("icon_max_width")
		if max_icon_width > 0: icon_width = minf(icon_width, max_icon_width)
		if button.expand_icon:
			var inner_height: float = maxf(0.0, button.custom_minimum_size.y - padding.y)
			icon_width = minf(icon_width, inner_height * button.icon.get_size().aspect())
		reserved += icon_width + button.get_theme_constant("h_separation")
	var font_size: int = Typography.scaled_size(button, Typography.SIZE_BODY_LARGE)
	var required: float = _width(button, font, font_size, reserved)
	if required > width_limit:
		font_size = Typography.scaled_size(button, Typography.SIZE_BODY)
		required = _width(button, font, font_size, reserved)
	if font_size != button.get_theme_font_size("font_size"):
		button.add_theme_font_size_override("font_size", font_size)
	button.custom_minimum_size.x = minf(width_limit, maxf(minimum_width, required))

static func _width(button: Button, font: Font, font_size: int, reserved: float) -> float:
	var line := TextLine.new()
	line.add_string(button.text, font, font_size, button.language)
	return ceilf(line.get_line_width() + reserved)
