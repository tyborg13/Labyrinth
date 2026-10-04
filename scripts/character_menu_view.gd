extends RefCounted

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const Strip = preload("res://scripts/ui_card_strip.gd")
const StatChip = preload("res://scripts/ui_stat_chip.gd")
const SectionHeader = preload("res://scripts/ui_section_header.gd")
const InkStage = preload("res://scripts/ui_ink_pool_stage.gd")
const Surface = preload("res://scripts/character_menu_surface.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const SKILL_POINT_ICON_PATH: String = "res://assets/art/icons/skill_point.png"
const MOLTSHARD_ICON_PATH: String = "res://assets/art/icons/moltshard.png"

class CloseGlyph:
	extends Label
	var socket: BaseButton

	func _init() -> void:
		name = "CharacterCloseGlyph"
		text = "✕"
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		Typography.set_label_size(self, 18)
		add_theme_font_override("font", Typography.ui_font())

	func _ready() -> void:
		for event: Signal in [socket.mouse_entered, socket.mouse_exited, socket.focus_entered, socket.focus_exited]:
			event.connect(_refresh)
		_refresh()

	func _refresh() -> void:
		add_theme_color_override("font_color", Palette.GOLD_BRIGHT if socket.is_hovered() or socket.has_focus() else Palette.TEXT_2)

static func label(text: String, size: int = 18, color: Color = Palette.TEXT) -> Label:
	var result := Label.new()
	result.text = text
	Typography.set_label_size(result, size)
	result.add_theme_font_override("font", Typography.ui_font())
	result.add_theme_color_override("font_color", color)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

static func eyebrow(text: String, size: int = 13, color: Color = Palette.TEXT_3) -> Label:
	var result := label(text, size, color)
	Typography.apply_eyebrow(result, size, color)
	return result

static func section(title: String, count: String = "") -> Control:
	var result := SectionHeader.new()
	result.setup(title, count)
	return result

static func column(panel_name: String, width: float, title: String, count: String = "") -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = panel_name
	panel.custom_minimum_size.x = Typography.scaled_value(panel, width)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var content := VBoxContainer.new()
	content.name = "ColumnContent"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", roundi(Typography.scaled_value(panel, 14.0)))
	panel.add_child(content)
	content.add_child(section(title, count))
	return panel

static func scroll_list(panel: PanelContainer, scroll_name: String = "", list_name: String = "") -> VBoxContainer:
	var scroll := ScrollContainer.new()
	if not scroll_name.is_empty():
		scroll.name = scroll_name
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.get_node("ColumnContent").add_child(scroll)
	var list := VBoxContainer.new()
	if not list_name.is_empty():
		list.name = list_name
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", roundi(Typography.scaled_value(panel, 8.0)))
	scroll.add_child(list)
	return list

static func empty_copy(text: String) -> Label:
	var result := label(text, 18, Palette.TEXT_3)
	result.custom_minimum_size.y = Typography.scaled_value(result, 72.0)
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return result

static func title_block() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	var level := eyebrow("", 15, Palette.TEXT_2)
	level.name = "ProgressionLevelLabel"
	column.add_child(level)
	var title := label("Character", 46, Palette.GOLD_BRIGHT)
	title.name = "CharacterTitle"
	title.add_theme_font_override("font", Typography.display_font())
	column.add_child(title)
	return column

static func stat(row: HBoxContainer, chip_name: String, icon: Texture2D, caption: String, color: Color) -> Label:
	var chip := StatChip.new()
	chip.name = "%sChip" % chip_name
	chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	chip.setup(icon, "0", caption, color)
	row.add_child(chip)
	var value: Label = chip.get_node("Value") as Label
	value.name = "%sLabel" % chip_name
	return value

static func refresh_stat(value: Label, text: String, caption: String) -> void:
	var chip: Control = value.get_parent() as Control
	chip.setup(chip.get_node("Socket").get("_source_icon"), text, caption, value.get_theme_color("font_color"))

static func resource_icon(path: String) -> Texture2D:
	# Do not cache missing art; a later rebuild can pick up newly delivered icons.
	if not FileAccess.file_exists(path) and not ResourceLoader.exists(path):
		return null
	return AssetLoader.load_texture(path)

static func close_socket() -> Button:
	var button := Socket.new()
	button.socket_size = 40.0
	button.name = "CloseCharacterOverlay"
	button.setup(null, "Close Character")
	var glyph := CloseGlyph.new()
	glyph.socket = button
	button.add_child(glyph)
	glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	return button

static func tabs_row() -> Control:
	var row := Control.new()
	row.name = "CharacterTabs"
	row.custom_minimum_size.y = Typography.scaled_value(row, 48.0)
	var rule := Surface.new()
	rule.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(rule)
	var buttons := HBoxContainer.new()
	buttons.name = "Buttons"
	buttons.add_theme_constant_override("separation", roundi(Typography.scaled_value(row, 6.0)))
	buttons.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.add_child(buttons)
	return row

static func style_tab(button: Button, active: bool) -> void:
	button.custom_minimum_size = Vector2(150.0, 48.0) * Typography.ui_scale(button)
	button.add_theme_font_override("font", Typography.ui_font())
	Typography.set_button_size(button, 21)
	for state: String in ["normal", "pressed", "hover", "hover_pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Palette.INK_2 if active else Color.TRANSPARENT
		style.border_color = Color(Palette.GOLD, 0.75)
		if active or state == "focus":
			style.border_width_top = 1
			style.border_width_left = 1
			style.border_width_right = 1
		button.add_theme_stylebox_override(state, style)
	for state: String in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Palette.GOLD_BRIGHT if active or state in ["font_hover_color", "font_focus_color"] else Palette.TEXT_2)
	if active:
		var underline := Surface.new()
		underline.kind = "underline"
		underline.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		button.add_child(underline)

static func finish_dialog(panel: PanelContainer) -> void:
	for decoration: String in ["SurfaceFinish", "ThemedPanelOrnament"]:
		var previous: Node = panel.get_node_or_null(decoration)
		if previous != null:
			panel.remove_child(previous)
			previous.queue_free()
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", style)
	var finish := Surface.new()
	finish.kind = "dialog"
	finish.name = "CharacterGlass"
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(finish)
	panel.move_child(finish, 0)

static func socket(icon: Texture2D, diameter: float, node_name: String = "EquipmentIconChip") -> Button:
	var result := Socket.new()
	result.name = node_name
	result.socket_size = diameter
	result.interactive = false
	result.setup(icon)
	return result

static func paper_doll(art: Control, slots: Dictionary) -> Control:
	var stage := Control.new()
	stage.name = "CharacterPaperDoll"
	stage.custom_minimum_size.y = Typography.scaled_value(stage, 398.0)
	var pool := InkStage.new()
	pool.name = "CharacterInkPool"
	pool.figure_width = 260.0
	pool.feet_anchor = Vector2(0.5, 0.87)
	pool.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	stage.add_child(pool)
	stage.add_child(art)
	for slot: String in slots:
		var caption := eyebrow(slot.to_upper(), 13, Palette.TEXT_3)
		caption.name = "%sSlotCaption" % slot.capitalize()
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stage.add_child(slots[slot])
		stage.add_child(caption)
	stage.resized.connect(func() -> void:
		var scale_value: float = Typography.ui_scale(stage)
		art.position = Vector2(stage.size.x * 0.5 - 130.0 * scale_value, 92.0 * scale_value)
		art.size = Vector2(260.0, 260.0) * scale_value
		var positions: Dictionary = {"trinket": Vector2(0.5, 0.0), "weapon": Vector2(0.13, 0.25), "armor": Vector2(0.13, 0.57), "offhand": Vector2(0.87, 0.25), "boots": Vector2(0.87, 0.57)}
		for slot: String in slots:
			var tile: Control = slots[slot] as Control
			var location: Vector2 = positions[slot]
			tile.size = Vector2.ONE * 62.0 * scale_value
			tile.position = Vector2(stage.size.x * location.x - tile.size.x * 0.5, stage.size.y * location.y)
			var caption: Control = stage.get_node("%sSlotCaption" % slot.capitalize()) as Control
			caption.position = tile.position + Vector2(-18.0, 65.0) * scale_value
			caption.size = Vector2(98.0, 22.0) * scale_value
	)
	return stage

static func row_style(active: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.INK_0, 0.45)
	style.border_color = Color(Palette.GOLD_BRIGHT if active else Palette.GOLD_DIM, 0.8 if active else 0.3)
	style.set_border_width_all(1)
	style.set_corner_radius_all(2)
	style.set_content_margin_all(8.0)
	if active:
		style.shadow_color = Color(Palette.EMBER, 0.12)
		style.shadow_size = 8
	return style

static func row_body(icon: Texture2D, type_text: String, name_text: String, summary: String = "", icon_name: String = "EquipmentIconChip") -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", roundi(Typography.scaled_value(row, 10.0)))
	row.add_child(socket(icon, 46.0, icon_name))
	var content := VBoxContainer.new()
	content.name = "RowText"
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_theme_constant_override("separation", 0)
	row.add_child(content)
	content.add_child(eyebrow(type_text.to_upper()))
	var title := label(name_text)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(title)
	if not summary.is_empty():
		var copy := label(summary, 14, Palette.TEXT_2)
		copy.clip_text = true
		copy.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		content.add_child(copy)
	passive(row)
	return row

static func passive(node: Control) -> void:
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.focus_mode = Control.FOCUS_NONE
	for child: Node in node.get_children():
		if child is Control:
			passive(child as Control)

static func clear_native_states(control: Control) -> void:
	for state: String in ["focus", "hover", "hover_pressed", "pressed"]:
		control.add_theme_stylebox_override(state, StyleBoxEmpty.new())

static func empty_row(panel: PanelContainer, text: String) -> void:
	clear_native_states(panel)
	panel.add_theme_stylebox_override("panel", row_style(false))
	var body: Control = row_body(null, "Empty slot", text, "", "ItemCardArtChip")
	panel.add_child(body)
	var finish := Surface.new()
	finish.kind = "empty"
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(finish)

static func empty_strip(panel: PanelContainer) -> void:
	clear_native_states(panel)
	panel.custom_minimum_size.y = Typography.scaled_value(panel, 34.0)
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var finish := Surface.new()
	finish.kind = "empty"
	finish.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.add_child(finish)

static func strip_content(card_id: String, count: int = 1, height: float = 30.0) -> Button:
	var result := Strip.new()
	result.name = "CharacterCardStrip"
	result.setup(card_id, str(GameData.card_def(card_id).get("name", card_id)), count)
	result.custom_minimum_size.y = Typography.scaled_value(result, height)
	result.get_node("Name").name = "CardBadgeName"
	result.get_node("Art").name = "CardBadgeArt"
	passive(result)
	return result

static func deck_group(heading: String, source: String, cards: Array, host: Node) -> Control:
	var group := VBoxContainer.new()
	group.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	group.add_theme_constant_override("separation", 4)
	var title := HBoxContainer.new()
	title.add_theme_constant_override("separation", 8)
	group.add_child(title)
	title.add_child(eyebrow(heading, 13, Palette.TEXT_2))
	if not source.is_empty():
		title.add_child(label(source, 16, Palette.TEXT))
	var grid := GridContainer.new()
	grid.name = "CharacterDeckGrid"
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	group.add_child(grid)
	var counts: Dictionary = {}
	for id: Variant in cards:
		var card_id: String = deck_card_id(str(id))
		if not card_id.is_empty():
			counts[card_id] = int(counts.get(card_id, 0)) + 1
	for id: String in counts:
		var badge: Control = host.call("_build_equipment_card_badge", id, Palette.GOLD_DIM)
		var strip: Control = badge.get_node("CharacterCardStrip") as Control
		strip.setup(id, str(GameData.card_def(id).get("name", id)), int(counts[id]))
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(badge)
	return group

static func deck_card_id(card_id: String) -> String:
	# Retired save IDs may resolve to the same printed card as their replacement.
	var raw_card: Dictionary = GameData.cards().get(card_id, {}) as Dictionary
	var replacement_id: String = str(raw_card.get("replacement_id", ""))
	if bool(raw_card.get("retired", false)) and not replacement_id.is_empty():
		if GameData.card_def(card_id) == GameData.card_def(replacement_id):
			return replacement_id
	return card_id

static func sync_tile(tile: PanelContainer, focused: bool, selected: bool = false) -> void:
	var active: bool = focused or bool(tile.get_meta("character_hovered", false)) or bool(tile.get_meta("character_swap_target", false))
	var feedback: Control = tile.get_node_or_null("CharacterTileFeedback") as Control
	if feedback != null:
		feedback.visible = active
	var strip: Button = tile.get_node_or_null("CharacterCardStrip") as Button
	if strip != null:
		strip.selected = selected
		tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		var finish: Control = strip.get_node("Finish") as Control
		# Native focus belongs to the behavior wrapper; the shared strip stays passive.
		finish.modulate = Color(1.3, 1.2, 1.0) if active else Color.WHITE
		return
	var ring: Button = tile.find_child("EquipmentIconChip", true, false) as Button
	if ring != null:
		ring.selected = focused or selected
		ring.ring_tint = Socket.ACTIVE_RING_TINT if active else Color(1.14, 1.06, 0.96, 1.0)
	if tile.has_meta("character_socket"):
		tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	else:
		tile.add_theme_stylebox_override("panel", row_style(active or selected))

static func tile_feedback(tile: PanelContainer, host: Node) -> void:
	clear_native_states(tile)
	var feedback := Surface.new()
	feedback.name = "CharacterTileFeedback"
	feedback.kind = "socket_glow" if tile.has_meta("character_socket") else "highlight"
	feedback.visible = false
	feedback.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tile.add_child(feedback)
	if tile.has_meta("character_socket"):
		tile.move_child(feedback, 0)
	for event: Signal in [tile.mouse_entered, tile.mouse_exited]:
		event.connect(func() -> void:
			tile.set_meta("character_hovered", event == tile.mouse_entered)
			host.call("_apply_controller_loadout_focus_style", tile, tile.has_focus())
		)

static func pack_actions(tile: PanelContainer, host: Node, equip: Callable, can_equip: bool) -> void:
	tile.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			tile.grab_focus()
	)
	var refresh: Callable = refresh_pack_actions.bind(tile, host, equip, can_equip)
	tile.focus_entered.connect(refresh.call_deferred)
	tile.focus_exited.connect(refresh.call_deferred)

static func refresh_pack_actions(tile_value: Variant, host_value: Variant, equip: Callable, can_equip: bool) -> void:
	if typeof(tile_value) != TYPE_OBJECT or not is_instance_valid(tile_value) or not is_instance_valid(host_value):
		return
	var tile: PanelContainer = tile_value as PanelContainer
	var host: Node = host_value as Node
	if tile == null or not tile.is_inside_tree():
		return
	var owner: Control = tile.get_viewport().gui_get_focus_owner()
	var active: bool = owner == tile or (owner != null and tile.is_ancestor_of(owner))
	var content: VBoxContainer = tile.find_child("RowText", true, false) as VBoxContainer
	var previous: Node = content.get_node_or_null("CharacterPackActions")
	sync_tile(tile, active)
	if previous != null:
		if not active:
			content.remove_child(previous)
			previous.queue_free()
		return
	if not active:
		return
	var actions := HBoxContainer.new()
	actions.name = "CharacterPackActions"
	actions.add_theme_constant_override("separation", 8)
	content.add_child(actions)
	for action: String in ["Equip", "Inspect"]:
		var button := Button.new()
		button.text = action
		button.custom_minimum_size = Vector2(100.0, 32.0) * Typography.ui_scale(tile)
		UiSkin.new().apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
		Typography.set_button_size(button, 16)
		if action == "Equip":
			button.disabled = not can_equip
			button.pressed.connect(equip)
		else:
			button.pressed.connect(show_inspection.bind(host, tile))
		var refresh: Callable = refresh_pack_actions.bind(tile, host, equip, can_equip)
		button.focus_entered.connect(refresh.call_deferred)
		button.focus_exited.connect(refresh.call_deferred)
		actions.add_child(button)

static func show_inspection(host: Node, tile: Control) -> void:
	if tile.focus_mode != Control.FOCUS_NONE:
		tile.grab_focus()
	host.call("_clear_controller_loadout_tooltip")
	var tooltip: Control = tile.call("_make_custom_tooltip", tile.tooltip_text) as Control
	if tooltip == null:
		return
	host.set("_controller_loadout_tooltip", tooltip)
	host.set("_controller_loadout_tooltip_anchor", tile)
	tooltip.name = "ControllerLoadoutTooltip"
	tooltip.z_index = 80
	passive(tooltip)
	host.get("_upgrade_scrim").add_child(tooltip)
	host.call_deferred("_position_controller_loadout_tooltip")
