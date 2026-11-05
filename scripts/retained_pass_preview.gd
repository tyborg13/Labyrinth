extends RefCounted

const AssetLoader = preload("res://scripts/asset_loader.gd")
const TurnClockForecastLine = preload("res://scripts/turn_clock_forecast_line.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

static func forecast_unchanged(label: Label, row: Control, entries: Array[Dictionary], wait_time: int) -> bool:
	# Both owners keep private copies already. Comparing their exact values also
	# detects a caller's in-place edit; a hash or the combat revision cannot.
	return row.get_meta("pass_preview_wait_time", -1) == wait_time and label.get_meta("pass_preview_wait_time", -1) == wait_time and row.get_meta("pass_preview_values", null) == entries and label.get_meta("pass_preview_values", null) == entries

# Keep the authored control and its signal/focus identity; only its values change.
static func build(scene: Control) -> Button:
	var summary: Dictionary = scene._pass_preview_summary()
	var card_defiance_spent: int = scene._pending_card_defiance_spent()
	if summary.is_empty():
		return null
	# This is one actual button: its art, labels, and forecast are visual children
	# with mouse input ignored, so keyboard and pointer activation share one focus stop.
	var chip := UiTooltipButton.new()
	chip.name = "PassPreviewChip"
	chip.dismiss_tooltip_when_disabled = true
	var chip_size: Vector2 = scene.PASS_PREVIEW_CHIP_SIZE
	chip.custom_minimum_size = chip_size
	chip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.mouse_filter = Control.MOUSE_FILTER_STOP
	chip.flat = true
	chip.set_disabled_with_tooltip(not scene._pass_preview_action_available())
	chip.focus_mode = Control.FOCUS_NONE if chip.disabled else Control.FOCUS_ALL
	var tooltip_text: String = scene._pass_preview_tooltip(summary)
	if card_defiance_spent > 0:
		tooltip_text = "Playing this card spends %d Defiance.\n%s" % [card_defiance_spent, tooltip_text]
	chip.mouse_default_cursor_shape = scene.TOOLTIP_ONLY_CURSOR_SHAPE if not tooltip_text.is_empty() else Control.CURSOR_ARROW
	chip.tooltip_text = tooltip_text
	for state_name: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		chip.add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	chip.set_meta("combined_pass_forecast", true)
	chip.pressed.connect(scene._on_pass_turn_pressed)
	var art_host := TextureRect.new()
	art_host.name = "PassForecastFrameArtHost"
	art_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	art_host.anchor_right = 1.0
	art_host.anchor_bottom = 1.0
	art_host.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art_host.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art_host.texture = AssetLoader.load_texture(scene.PASS_FORECAST_FRAME_TEXTURE_PATH)
	art_host.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	art_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art_host.z_index = 2
	art_host.set_meta("expected_target_size", Vector2i(270, 100))
	art_host.set_meta("pass_forecast_art_state", "normal")
	chip.add_child(art_host)

	var content := Control.new()
	content.name = "PassForecastContent"
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.anchor_right = 1.0
	content.anchor_bottom = 1.0
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.z_index = 3
	chip.add_child(content)
	var focus_edge := PanelContainer.new()
	focus_edge.name = "PassFocusEdgeCue"
	# Keyboard/controller focus is the only code-drawn state treatment. Pointer
	# hover and press use their authored native frames without a colored wash.
	focus_edge.position = Vector2(8.0, 6.0)
	focus_edge.size = Vector2(254.0, 58.0)
	focus_edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_edge.visible = false
	focus_edge.z_index = 4
	content.add_child(focus_edge)
	var action_label := Label.new()
	action_label.name = "PassActionLabel"
	# Targetless confirmations hide the action tracker. The disabled Pass face
	# makes this card's lethal payment visible beside the separate turn-end risk.
	action_label.text = "CARD COST\nDEFIANCE -%d" % card_defiance_spent if card_defiance_spent > 0 else "PASS"
	action_label.position = Vector2(18.0, 10.0)
	action_label.size = Vector2(234.0, 50.0)
	action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	action_label.add_theme_font_override("font", UiTypography.eyebrow_font())
	UiTypography.set_label_size(action_label, UiTypography.SIZE_SECTION + 3 if card_defiance_spent <= 0 else UiTypography.SIZE_BODY)
	action_label.add_theme_color_override("font_color", UiPalette.GOLD_BRIGHT.lerp(Color.WHITE, 0.35))
	action_label.add_theme_color_override("font_outline_color", scene.PASS_ACTION_OUTLINE_COLOR)
	action_label.add_theme_constant_override("outline_size", 4)
	action_label.z_index = 5
	content.add_child(action_label)
	var forecast_title := Label.new()
	forecast_title.name = "PassPreviewTitle"
	forecast_title.text = ""
	forecast_title.visible = false
	forecast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	forecast_title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	forecast_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.set_label_size(forecast_title, UiTypography.SIZE_SMALL)
	forecast_title.add_theme_color_override("font_color", scene.PASS_FORECAST_TITLE_COLOR)
	content.add_child(forecast_title)

	var damage_row := Control.new()
	damage_row.name = "PassPreviewDamageRow"
	# The lower authored ribbon ends above the distressed lower edge. Keep the
	# forecast vertically contained inside it instead of centering against the
	# whole lower strip.
	damage_row.position = Vector2(12.0, 71.0)
	damage_row.size = Vector2(246.0, 18.0)
	damage_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(damage_row)
	var forecast_entries: Array[Dictionary] = scene._pass_preview_forecast_entries(summary)
	damage_row.set_meta("pass_preview_values", forecast_entries.duplicate(true))
	var forecast_line := TurnClockForecastLine.new()
	forecast_line.tooltip_text = tooltip_text
	damage_row.add_child(forecast_line)
	forecast_line.position = Vector2.ZERO
	forecast_line.size = damage_row.size
	scene._refresh_pass_forecast_line(forecast_line, damage_row, forecast_entries, int(summary.get("wait_time", 0)))
	var danger_state: bool = (
		card_defiance_spent > 0
		or bool(summary.get("defeat", false))
		or bool(summary.get("unrevealed_before_player", false))
		or bool(summary.get("umbra_unknown_before_player", false))
	)
	var accent: Color = scene._action_context_risk_color("danger" if danger_state else str(summary.get("tone", "safe")))
	chip.set_meta("panel_surface_accent", accent)
	chip.set_meta("panel_selected", danger_state)
	chip.set_meta("pass_interaction_state", "disabled" if chip.disabled else "idle")
	chip.mouse_entered.connect(func() -> void: scene._set_pass_preview_pointer_hover(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	chip.mouse_exited.connect(func() -> void: scene._set_pass_preview_pointer_exit(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	chip.focus_entered.connect(func() -> void: scene._set_pass_preview_focus_entered(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	chip.focus_exited.connect(func() -> void: scene._set_pass_preview_focus_exited(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	chip.button_down.connect(func() -> void: scene._set_pass_preview_pressed(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	chip.button_up.connect(func() -> void: scene._set_pass_preview_released(chip, art_host, content, focus_edge, chip.get_meta("panel_surface_accent")))
	scene._refresh_pass_preview_interaction(chip, art_host, content, focus_edge, accent)

	if scene._choice_buttons_use_overlay():
		scene._pass_preview_overlay.add_child(chip)
	else:
		scene.choice_bar.add_child(chip)

	return chip

static func refresh(scene: Control) -> void:
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip") if scene._pass_preview_overlay != null else scene.choice_bar.get_node_or_null("PassPreviewChip")
	if chip == null:
		build(scene)
		return
	var summary: Dictionary = scene._pass_preview_summary()
	if summary.is_empty():
		chip.hide()
		return
	chip.show()
	chip.set_disabled_with_tooltip(not scene._pass_preview_action_available())
	chip.focus_mode = Control.FOCUS_NONE if chip.disabled else Control.FOCUS_ALL
	var spent: int = scene._pending_card_defiance_spent()
	var tooltip: String = scene._pass_preview_tooltip(summary)
	if spent > 0: tooltip = "Playing this card spends %d Defiance.\n%s" % [spent, tooltip]
	chip.tooltip_text = tooltip
	chip.mouse_default_cursor_shape = scene.TOOLTIP_ONLY_CURSOR_SHAPE if not tooltip.is_empty() else Control.CURSOR_ARROW
	var content: Control = chip.get_node("PassForecastContent")
	var action: Label = content.get_node("PassActionLabel")
	action.text = "CARD COST\nDEFIANCE -%d" % spent if spent > 0 else "PASS"
	UiTypography.set_label_size(action, UiTypography.SIZE_SECTION + 3 if spent <= 0 else UiTypography.SIZE_BODY)
	var row: Control = content.get_node("PassPreviewDamageRow")
	var line: Label = row.get_child(0)
	line.tooltip_text = tooltip
	scene._refresh_pass_forecast_line(line, row, scene._pass_preview_forecast_entries(summary), int(summary.get("wait_time", 0)))
	var danger: bool = spent > 0 or bool(summary.get("defeat", false)) or bool(summary.get("unrevealed_before_player", false)) or bool(summary.get("umbra_unknown_before_player", false))
	var accent: Color = scene._action_context_risk_color("danger" if danger else str(summary.get("tone", "safe")))
	chip.set_meta("panel_surface_accent", accent)
	chip.set_meta("panel_selected", danger)
	if chip.disabled: chip.set_meta("pass_pressed", false)
	scene._refresh_pass_preview_interaction(chip, chip.get_node("PassForecastFrameArtHost"), content, content.get_node("PassFocusEdgeCue"), accent)
