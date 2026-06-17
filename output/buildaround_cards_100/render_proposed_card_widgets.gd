extends SceneTree

const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const CARD_SIZE := Vector2(250.0, 352.0)
const PREVIEW_VIEWPORT_SIZE := Vector2i(1600, 1080)
const TEXT_RULE_ART_HEIGHT := 90.0
const TEXT_RULE_DETAILS_HEIGHT := 164.0
const TEXT_MIN_SIZE := 5
const TEXT_MAX_SIZE := 8
const OUT_DIR := "res://output/buildaround_cards_100/card_widget_previews"
const PACK_PATH := "res://output/buildaround_cards_100/proposed_cards_game_ready.json"

func _initialize() -> void:
	root.size = PREVIEW_VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var pack := _load_pack()
	if pack.is_empty():
		push_error("No proposed card pack found.")
		quit(1)
		return
	var wanted := _wanted_ids()
	var background := ColorRect.new()
	background.color = Color("20170f")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	root.add_child(background)
	await process_frame
	var rendered := 0
	for card_id_var: Variant in pack.keys():
		var card_id := str(card_id_var)
		if not wanted.is_empty() and not wanted.has(card_id):
			continue
		var card := (pack.get(card_id, {}) as Dictionary).duplicate(true)
		var art_path := str(card.get("art_path", ""))
		if not FileAccess.file_exists(art_path):
			continue
		await _render_card(card_id, card)
		rendered += 1
	background.queue_free()
	await process_frame
	print("rendered proposed card widgets: %d" % rendered)
	quit()

func _wanted_ids() -> Dictionary:
	var wanted := {}
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--cards="):
			for raw_id: String in arg.trim_prefix("--cards=").split(",", false):
				wanted[raw_id.strip_edges()] = true
	return wanted

func _load_pack() -> Dictionary:
	var file := FileAccess.open(PACK_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}

func _render_card(card_id: String, card: Dictionary) -> void:
	var slot := Control.new()
	slot.position = Vector2(72.0, 48.0)
	slot.custom_minimum_size = CARD_SIZE
	slot.size = CARD_SIZE
	root.add_child(slot)
	var widget: CardWidget = CardWidgetScene.instantiate()
	widget.custom_minimum_size = CARD_SIZE
	widget.size = CARD_SIZE
	slot.add_child(widget)
	await process_frame
	widget.configure(card_id, false, false, true, false, false, true, card)
	await process_frame
	await _apply_text_forward_preview(widget, card)
	await process_frame
	await process_frame
	var viewport_texture := root.get_viewport().get_texture()
	if viewport_texture == null:
		push_warning("No viewport texture available for %s" % card_id)
		slot.queue_free()
		await process_frame
		return
	var image: Image = viewport_texture.get_image()
	if image == null or image.is_empty():
		push_warning("No viewport image available for %s" % card_id)
		slot.queue_free()
		await process_frame
		return
	image = _crop_to_control(image, widget, 22.0)
	image.save_png("%s/%s_card.png" % [ProjectSettings.globalize_path(OUT_DIR), card_id])
	slot.queue_free()
	await process_frame

func _crop_to_control(image: Image, control: Control, padding: float) -> Image:
	var viewport_rect: Rect2 = root.get_viewport().get_visible_rect()
	if viewport_rect.size.x <= 0.0 or viewport_rect.size.y <= 0.0:
		return image
	var scale := Vector2(float(image.get_width()) / viewport_rect.size.x, float(image.get_height()) / viewport_rect.size.y)
	var control_rect: Rect2 = control.get_global_rect().grow(padding)
	var crop_rect := Rect2i(
		Vector2i(
			maxi(0, int(floor(control_rect.position.x * scale.x))),
			maxi(0, int(floor(control_rect.position.y * scale.y)))
		),
		Vector2i(
			int(ceil(control_rect.size.x * scale.x)),
			int(ceil(control_rect.size.y * scale.y))
		)
	)
	crop_rect.size.x = mini(crop_rect.size.x, image.get_width() - crop_rect.position.x)
	crop_rect.size.y = mini(crop_rect.size.y, image.get_height() - crop_rect.position.y)
	if crop_rect.size.x <= 0 or crop_rect.size.y <= 0:
		return image
	return image.get_region(crop_rect)

func _apply_text_forward_preview(widget: CardWidget, card: Dictionary) -> void:
	widget.set_display_overrides(" ", [], [])
	widget.art_frame.custom_minimum_size = Vector2(0.0, TEXT_RULE_ART_HEIGHT)
	widget.details_panel.custom_minimum_size = Vector2(0.0, TEXT_RULE_DETAILS_HEIGHT)
	widget.desc_label.custom_minimum_size = Vector2(0.0, TEXT_RULE_DETAILS_HEIGHT - 8.0)
	widget.desc_label.visible = false
	await process_frame
	var overlay := RichTextLabel.new()
	overlay.name = "TextRulePreview"
	overlay.bbcode_enabled = true
	overlay.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay.fit_content = false
	overlay.scroll_active = false
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_theme_color_override("default_color", Color("503d2c"))
	overlay.add_theme_constant_override("line_separation", -1)
	overlay.text = _preview_bbcode(card)
	widget.add_child(overlay)
	overlay.z_index = 20
	var local_details_pos: Vector2 = widget.details_panel.get_global_rect().position - widget.get_global_rect().position
	overlay.position = local_details_pos + Vector2(32.0, 12.0)
	overlay.size = widget.details_panel.size - Vector2(64.0, 22.0)
	overlay.custom_minimum_size = overlay.size
	await process_frame
	await _fit_preview_text(overlay, overlay.size.y)

func _preview_bbcode(card: Dictionary) -> String:
	var costs: Array[String] = []
	if bool(card.get("burn", false)):
		costs.append("[color=#7b2f25][b]EXHAUST[/b][/color]")
	var health_cost := int(card.get("health_cost", 0))
	if health_cost > 0:
		costs.append("[color=#7b2f25][b]LOSE %d HEALTH[/b][/color]" % health_cost)
	var body := _bbcode_escape(_rule_line_breaks(str(card.get("description", ""))))
	if costs.is_empty():
		return body
	return "%s\n%s" % ["  |  ".join(costs), body]

func _rule_line_breaks(text: String) -> String:
	return text.replace(". For this combat,", ".\nFor this combat,").replace(". At ", ".\nAt ").replace(". Until ", ".\nUntil ")

func _fit_preview_text(label: RichTextLabel, available_height: float) -> void:
	for size: int in range(TEXT_MAX_SIZE, TEXT_MIN_SIZE - 1, -1):
		_set_rich_text_size(label, size)
		await process_frame
		if label.get_content_height() <= available_height:
			return
	_set_rich_text_size(label, TEXT_MIN_SIZE)

func _set_rich_text_size(label: RichTextLabel, size: int) -> void:
	for property_name: String in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		label.add_theme_font_size_override(property_name, size)

func _bbcode_escape(text: String) -> String:
	var escaped := text.replace("[", "__BB_LB__").replace("]", "__BB_RB__")
	return escaped.replace("__BB_LB__", "[lb]").replace("__BB_RB__", "[rb]")
