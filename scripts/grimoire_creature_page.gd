extends RefCounted

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Burst = preload("res://scripts/enemy_mechanics/death_burst_view.gd")
const CombatBoard = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const Inspection = preload("res://scripts/pre_battle_inspection_view.gd")
const KnownMoveText = preload("res://scripts/known_move_text.gd")
const Typography = preload("res://scripts/ui_typography.gd")

const SECTION_GAP: int = 16
const ROW_MIN_HEIGHT: float = 52.0
const ROW_GAP: int = 12
const SOCKET_SIZE: float = 40.0
const RULE_HEIGHT: float = 1.0

static func populate(book: Control, target: VBoxContainer, enemy_id: String) -> void:
	var page := _column()
	target.add_child(page)
	_add_battlefield_rule(book, page, enemy_id)
	_add_traits(book, page, enemy_id)
	_add_moves(book, page, enemy_id)

static func _add_battlefield_rule(book: Control, page: VBoxContainer, enemy_id: String) -> void:
	var instance: Dictionary = BattlefieldRules.instance_for(enemy_id)
	if instance.is_empty():
		return
	for rule: Dictionary in BattlefieldRules.data()["rules"]:
		if rule["id"] != instance["rule"]:
			continue
		var section: VBoxContainer = _section(book, page, "Battlefield Rule")
		var text: VBoxContainer = _row(book, section, rule["icon"], rule["name"], instance["sentence"])
		var at_half_health: String = str(instance.get("at_half_health", {}).get("sentence", ""))
		if not at_half_health.is_empty():
			text.add_child(_caption("At half Health", Color.hex(book.ROW_NESTED_TEXT)))
			text.add_child(_summary(book, at_half_health))
		return

static func _add_traits(book: Control, page: VBoxContainer, enemy_id: String) -> void:
	# A detached board supplies badge order with no encounter state or status previews.
	var unit: Dictionary = {"type": enemy_id, "role": "enemy", "hp": GameData.enemy_property(enemy_id, "max_hp", 0)}
	var board := CombatBoard.new()
	var badges: Array[Dictionary] = board._unit_status_presentation_badges(unit)
	board.free()
	var section: VBoxContainer
	for badge: Dictionary in badges:
		if badge["status_class"] != "trait":
			continue
		if section == null:
			section = _section(book, page, "Traits")
		var icon: String = badge["icon"]
		if icon == Burst.BURST_ICON:
			# Keep the existing counted title and inline area diagram.
			var burst: Dictionary = Burst.trait_token(unit)
			_row(book, section, icon, burst["value"], Inspection.trait_details(burst))
			continue
		var tooltip: String = str(badge.get("tooltip", ""))
		if tooltip.is_empty():
			tooltip = ActionIcons.tooltip(icon, badge.get("count"))
		var parts: PackedStringArray = tooltip.split("\n", true, 1)
		var title: String = parts[0] if parts.size() > 1 else ActionIcons.label(icon)
		_row(book, section, icon, title, parts[-1])

static func _add_moves(book: Control, page: VBoxContainer, enemy_id: String) -> void:
	var intents: Array = GameData.enemy_def(enemy_id).get("intents", [])
	if intents.is_empty():
		return
	var section: VBoxContainer = _section(book, page, "Moves", "Base values")
	var unit: Dictionary = {"type": enemy_id}
	for raw_intent: Dictionary in intents:
		var intent: Dictionary = KnownMoveText.base_intent(raw_intent, intents)
		var rows: Array = KnownMoveText.rows(intent, unit, {}, true)
		_row(book, section, KnownMoveText.display_icon(intent, rows), intent["name"],
			KnownMoveText.summary(intent, rows), "Time %d" % int(intent["time"]))

static func _section(book: Control, page: VBoxContainer, title: String, note: String = "") -> VBoxContainer:
	var inset := MarginContainer.new()
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_theme_constant_override("margin_top", SECTION_GAP)
	page.add_child(inset)
	var section := _column()
	section.name = "Grimoire" + title.replace(" ", "")
	inset.add_child(section)
	var header := HBoxContainer.new()
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	section.add_child(header)
	var label: Label = book._grimoire_section_heading(title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(label)
	if not note.is_empty():
		var caption: Label = _caption(note, Color.hex(book.ROW_NESTED_TEXT))
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		header.add_child(caption)
	return section

static func _row(book: Control, section: VBoxContainer, key: String, title: String,
		summary: String, time: String = "") -> VBoxContainer:
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.custom_minimum_size.y = ROW_MIN_HEIGHT
	row.add_theme_constant_override("separation", ROW_GAP)
	section.add_child(row)
	var icon := TextureRect.new()
	icon.texture = ActionIcons.icon_texture(key)
	var socket: PanelContainer = book._grimoire_icon_socket(SOCKET_SIZE, icon)
	socket.mouse_filter = Control.MOUSE_FILTER_IGNORE
	socket.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(socket)
	var text := _column()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(text)
	var name_label := Label.new()
	name_label.text = title
	name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_label_role(name_label, Typography.ROLE_BODY)
	name_label.add_theme_color_override("font_color", Color.hex(book.ROW_TEXT))
	text.add_child(name_label)
	text.add_child(_summary(book, summary))
	if not time.is_empty():
		var time_label := _caption(time, Color.hex(book.GRANTED_CARDS_TEXT))
		time_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		time_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(time_label)
	var rule := ColorRect.new()
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rule.custom_minimum_size.y = RULE_HEIGHT
	rule.color = book._rgba(book.DETAIL_RULE_RGBA)
	section.add_child(rule)
	return text

static func _column() -> VBoxContainer:
	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 0)
	return column

static func _caption(text: String, ink: Color) -> Label:
	var label := Label.new()
	label.text = text
	Typography.apply_label_role(label, Typography.ROLE_BODY)
	Typography.set_label_size(label, Typography.SIZE_SMALL)
	label.add_theme_color_override("font_color", ink)
	label.add_theme_constant_override("outline_size", 0)
	return label

static func _summary(book: Control, markup: String) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.fit_content = true
	label.scroll_active = false
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	Typography.apply_rich_text_role(label, Typography.ROLE_BODY)
	Typography.set_rich_text_size(label, Typography.SIZE_SMALL)
	label.add_theme_color_override("default_color", Color.hex(book.ROW_TEXT))
	InlineIconText.append_to(label, markup, float(label.get_theme_font_size("normal_font_size")), false)
	return label
