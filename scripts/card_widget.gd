extends Button
class_name CardWidget

signal activated
signal drag_started

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const DRAG_THRESHOLD: float = 10.0
const HOVER_LIFT: float = -12.0
const SELECTED_LIFT: float = -5.0
const HOVER_SCALE: float = 1.04
const SELECTED_SCALE: float = 1.01
const DAMAGE_NEUTRAL_COLOR: String = "#503d2c"
const DAMAGE_BONUS_COLOR: String = "#4f8a43"
const DAMAGE_PENALTY_COLOR: String = "#a34a42"

@onready var title_label: Label = $Margin/VBox/TopRow/Title
@onready var cost_badge: Label = $Margin/VBox/TopRow/CostBadge
@onready var element_icon: TextureRect = $Margin/VBox/TopRow/ElementIcon
@onready var art_frame: PanelContainer = $Margin/VBox/ArtFrame
@onready var art_rect: TextureRect = $Margin/VBox/ArtFrame/Art
@onready var desc_label: RichTextLabel = $Margin/VBox/Description
@onready var footer_label: Label = $Margin/VBox/Footer

var card_id: String = ""
var _selected: bool = false
var _dimmed: bool = false
var _usable: bool = true
var _previewed: bool = false
var _interactive: bool = true
var _printed_playable: bool = true
var _summary_bbcode: String = ""
var _modifier_tooltip_lines: PackedStringArray = []
var _left_pressed: bool = false
var _drag_emitted: bool = false
var _press_position: Vector2 = Vector2.ZERO
var _local_hovered: bool = false
var _pose_tween: Tween

func _ready() -> void:
	focus_mode = Control.FOCUS_NONE
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	text = ""
	title_label.add_theme_color_override("font_color", Color("39271b"))
	title_label.add_theme_color_override("font_outline_color", Color("f8f1dd"))
	title_label.add_theme_constant_override("outline_size", 2)
	title_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.add_theme_color_override("default_color", Color("503d2c"))
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_label.fit_content = true
	desc_label.scroll_active = false
	desc_label.scroll_following = false
	footer_label.add_theme_color_override("font_color", Color("6d5841"))
	footer_label.add_theme_color_override("font_outline_color", Color("f5ecdb"))
	footer_label.add_theme_constant_override("outline_size", 1)
	cost_badge.add_theme_color_override("font_color", Color("fff4dc"))
	cost_badge.add_theme_color_override("font_outline_color", Color("2f2018"))
	cost_badge.add_theme_constant_override("outline_size", 2)
	mouse_entered.connect(_on_local_mouse_entered)
	mouse_exited.connect(_on_local_mouse_exited)
	_update_layout_metrics()
	_apply_configuration()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_update_layout_metrics()
		pivot_offset = size * 0.5

func _gui_input(event: InputEvent) -> void:
	if not _interactive:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_left_pressed = true
			_drag_emitted = false
			_press_position = event.position
			accept_event()
			return
		if _left_pressed:
			_left_pressed = false
			accept_event()
			if not _drag_emitted:
				activated.emit()
			_drag_emitted = false
	elif event is InputEventMouseMotion and _left_pressed and not _drag_emitted:
		if event.position.distance_to(_press_position) >= DRAG_THRESHOLD:
			_drag_emitted = true
			drag_started.emit()
			accept_event()

func _get_tooltip(_at_position: Vector2) -> String:
	return "modifiers" if not _modifier_tooltip_lines.is_empty() else ""

func _make_custom_tooltip(_for_text: String) -> Object:
	if _modifier_tooltip_lines.is_empty():
		return null
	var panel := PanelContainer.new()
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.11, 0.08, 0.06, 0.96)
	panel_style.border_color = Color("9d7a50")
	panel_style.border_width_left = 2
	panel_style.border_width_top = 2
	panel_style.border_width_right = 2
	panel_style.border_width_bottom = 2
	panel_style.corner_radius_top_left = 10
	panel_style.corner_radius_top_right = 10
	panel_style.corner_radius_bottom_right = 10
	panel_style.corner_radius_bottom_left = 10
	panel_style.content_margin_left = 10.0
	panel_style.content_margin_top = 8.0
	panel_style.content_margin_right = 10.0
	panel_style.content_margin_bottom = 8.0
	panel.add_theme_stylebox_override("panel", panel_style)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)
	var title := Label.new()
	title.text = "MODIFIERS"
	UiTypography.set_label_size(title, 10)
	title.add_theme_color_override("font_color", Color("f0e6d2"))
	title.add_theme_color_override("font_outline_color", Color("2c1f16"))
	title.add_theme_constant_override("outline_size", 1)
	vbox.add_child(title)
	for line: String in _modifier_tooltip_lines:
		var label := Label.new()
		label.text = line
		UiTypography.set_label_size(label, 9)
		label.add_theme_color_override("font_color", Color("d7c6aa"))
		vbox.add_child(label)
	return panel

func configure(
	next_card_id: String,
	selected: bool = false,
	dimmed: bool = false,
	usable: bool = true,
	previewed: bool = false,
	interactive: bool = true,
	printed_playable: bool = true
) -> void:
	card_id = next_card_id
	_selected = selected
	_dimmed = dimmed
	_usable = usable
	_previewed = previewed
	_interactive = interactive
	_printed_playable = printed_playable
	if is_node_ready():
		_apply_configuration()

func set_display_overrides(summary_bbcode: String = "", modifier_lines: Array = []) -> void:
	_summary_bbcode = summary_bbcode
	_modifier_tooltip_lines = PackedStringArray()
	for line_var: Variant in modifier_lines:
		_modifier_tooltip_lines.append(str(line_var))
	tooltip_text = "modifiers" if not _modifier_tooltip_lines.is_empty() else ""
	if is_node_ready():
		_apply_configuration()

func _apply_configuration() -> void:
	if not is_node_ready():
		return
	var card: Dictionary = GameData.card_def(card_id)
	var element_id: String = GameData.card_element_from_def(card)
	var element: Dictionary = ElementData.def(element_id)
	title_label.text = str(card.get("name", card_id))
	desc_label.text = _summary_bbcode if not _summary_bbcode.is_empty() else _card_summary(card)
	var footer_parts: PackedStringArray = []
	if ElementData.is_elemental(element_id):
		footer_parts.append(str(element.get("short_label", "")).strip_edges())
	footer_parts.append(str(card.get("rarity", "common")).to_upper())
	footer_label.text = "  ".join(footer_parts)
	art_rect.texture = AssetLoader.load_texture(str(card.get("art_path", "")))
	element_icon.visible = ElementData.is_elemental(element_id)
	element_icon.texture = AssetLoader.load_texture(str(element.get("icon_path", ""))) if element_icon.visible else null
	element_icon.modulate = Color(str(element.get("accent", "#8a6b4a")))
	var accent: Color = ElementData.accent(element_id) if ElementData.is_elemental(element_id) else Color(str(card.get("accent", "#8a6b4a")))
	var background: Color = ElementData.card_background(element_id, _selected)
	if not ElementData.is_elemental(element_id):
		background = Color("ddd0bb") if _selected else Color("efe4cf")
	if _previewed and not _selected:
		background = background.lightened(0.03)
	if _dimmed:
		background = background.darkened(0.12)
	_apply_base_style(background, accent, _usable, _previewed, _printed_playable, ElementData.card_art_background(element_id))
	var badge_text: String = ""
	if bool(card.get("burn", false)):
		badge_text = "BURN"
	elif int(card.get("health_cost", 0)) > 0:
		badge_text = "-%d HP" % int(card.get("health_cost", 0))
	cost_badge.visible = not badge_text.is_empty()
	cost_badge.text = badge_text
	cost_badge.add_theme_stylebox_override("normal", _badge_style(accent))
	disabled = false
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if _interactive else Control.CURSOR_ARROW
	var alpha: float = 1.0
	if not _usable:
		alpha = 0.56
	elif _dimmed:
		alpha = 0.72
	elif not _printed_playable:
		alpha = 0.90
	modulate = Color(1.0, 1.0, 1.0, alpha)
	_update_pose(true)

func _update_layout_metrics() -> void:
	var width: float = size.x if size.x > 0.0 else custom_minimum_size.x
	var compact: bool = width <= 160.0
	var title_size: int = 10 if compact else 11
	var detail_size: int = 9 if compact else 10
	UiTypography.set_label_size(title_label, title_size)
	UiTypography.set_label_size(cost_badge, detail_size)
	UiTypography.set_rich_text_size(desc_label, detail_size)
	UiTypography.set_label_size(footer_label, detail_size)
	var art_height: float = clampf(width * 0.56, 78.0, 102.0)
	art_frame.custom_minimum_size = Vector2(0.0, art_height)
	desc_label.custom_minimum_size = Vector2(0.0, 42.0 if compact else 50.0)
	pivot_offset = size * 0.5

func _apply_base_style(background: Color, border: Color, usable: bool, previewed: bool, printed_playable: bool, art_background: Color) -> void:
	var edge_color: Color = border
	if not usable:
		edge_color = border.darkened(0.46)
	elif not printed_playable:
		edge_color = border.lerp(Color("bfa690"), 0.42)
	var normal := StyleBoxFlat.new()
	normal.bg_color = background
	normal.border_color = edge_color
	normal.border_width_left = 3
	normal.border_width_top = 3
	normal.border_width_right = 3
	normal.border_width_bottom = 3
	normal.corner_radius_top_left = 12
	normal.corner_radius_top_right = 12
	normal.corner_radius_bottom_right = 12
	normal.corner_radius_bottom_left = 12
	normal.shadow_color = Color(0.0, 0.0, 0.0, 0.20)
	normal.shadow_size = 12 if _local_hovered else 10 if previewed or _selected else 8
	var hover: StyleBoxFlat = normal.duplicate()
	hover.border_color = edge_color.lightened(0.18)
	hover.shadow_size = 12
	var pressed: StyleBoxFlat = normal.duplicate()
	pressed.bg_color = background.darkened(0.05)
	var disabled_style: StyleBoxFlat = normal.duplicate()
	disabled_style.bg_color = background.darkened(0.08)
	add_theme_stylebox_override("normal", normal)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", hover)
	add_theme_stylebox_override("disabled", disabled_style)
	var art_style := StyleBoxFlat.new()
	art_style.bg_color = art_background
	art_style.border_color = edge_color.darkened(0.14)
	art_style.border_width_left = 2
	art_style.border_width_top = 2
	art_style.border_width_right = 2
	art_style.border_width_bottom = 2
	art_style.corner_radius_top_left = 10
	art_style.corner_radius_top_right = 10
	art_style.corner_radius_bottom_right = 10
	art_style.corner_radius_bottom_left = 10
	art_style.content_margin_left = 4.0
	art_style.content_margin_top = 4.0
	art_style.content_margin_right = 4.0
	art_style.content_margin_bottom = 4.0
	art_frame.add_theme_stylebox_override("panel", art_style)

func _badge_style(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = accent.darkened(0.08)
	style.border_color = accent.lightened(0.14)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.content_margin_left = 7.0
	style.content_margin_top = 4.0
	style.content_margin_right = 7.0
	style.content_margin_bottom = 4.0
	return style

func _card_summary(card: Dictionary) -> String:
	var lines: PackedStringArray = []
	for action_var: Variant in card.get("actions", []):
		lines.append(_action_summary_line(action_var as Dictionary))
	if lines.is_empty():
		return str(card.get("description", ""))
	return "\n".join(lines)

func _action_summary_line(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"move":
			return "Move %d" % int(action.get("range", 0))
		"blink":
			return "Blink %d" % int(action.get("range", 0))
		"melee":
			return _append_action_tags("Strike %s" % _colored_number(int(action.get("damage", 0)), int(action.get("damage", 0))), action)
		"ranged":
			return _append_action_tags("Shoot %s  R%d" % [
				_colored_number(int(action.get("damage", 0)), int(action.get("damage", 0))),
				int(action.get("range", 0))
			], action)
		"blast":
			return _append_action_tags("Blast %s  R%d" % [
				_colored_number(int(action.get("damage", 0)), int(action.get("damage", 0))),
				int(action.get("range", 0))
			], action)
		"push":
			var text: String = "Push %d" % int(action.get("amount", 0))
			if int(action.get("damage", 0)) > 0:
				text += "  Hit %s" % _colored_number(int(action.get("damage", 0)), int(action.get("damage", 0)))
			if int(action.get("range", 0)) > 1:
				text += "  R%d" % int(action.get("range", 0))
			return _append_action_tags(text, action)
		"pull":
			var text: String = "Pull %d" % int(action.get("amount", 0))
			if int(action.get("damage", 0)) > 0:
				text += "  Hit %s" % _colored_number(int(action.get("damage", 0)), int(action.get("damage", 0)))
			if int(action.get("range", 0)) > 1:
				text += "  R%d" % int(action.get("range", 0))
			return _append_action_tags(text, action)
		"block":
			return "Block %d" % int(action.get("amount", 0))
		"stoneskin":
			return "Stoneskin %d" % int(action.get("amount", 0))
		"heal":
			return "Heal %d" % int(action.get("amount", 0))
		"draw":
			return "Draw %d" % int(action.get("amount", 0))
		_:
			return str(action.get("type", "")).capitalize()

func _colored_number(value: int, base_value: int) -> String:
	var color: String = DAMAGE_NEUTRAL_COLOR
	if value > base_value:
		color = DAMAGE_BONUS_COLOR
	elif value < base_value:
		color = DAMAGE_PENALTY_COLOR
	return "[color=%s]%d[/color]" % [color, value]

func _append_action_tags(base_text: String, action: Dictionary) -> String:
	var tags: PackedStringArray = []
	if int(action.get("burn", 0)) > 0:
		tags.append("Burn %d" % int(action.get("burn", 0)))
	if int(action.get("freeze", 0)) > 0:
		tags.append("Freeze")
	if int(action.get("shock", 0)) > 0:
		tags.append("Shock")
	if int(action.get("chain", 0)) > 0:
		tags.append("Chain")
	if int(action.get("push", 0)) > 0:
		tags.append("Push %d" % int(action.get("push", 0)))
	if int(action.get("pull", 0)) > 0:
		tags.append("Pull %d" % int(action.get("pull", 0)))
	if int(action.get("poison", 0)) > 0:
		tags.append("Poison %d" % int(action.get("poison", 0)))
	if tags.is_empty():
		return base_text
	return "%s  %s" % [base_text, "  ".join(tags)]

func _on_local_mouse_entered() -> void:
	_local_hovered = true
	_update_pose()

func _on_local_mouse_exited() -> void:
	_local_hovered = false
	_update_pose()

func _update_pose(immediate: bool = false) -> void:
	if not is_node_ready():
		return
	var lift: float = 0.0
	var target_scale: Vector2 = Vector2.ONE
	if _local_hovered and _interactive and not _dimmed:
		lift = HOVER_LIFT
		target_scale = Vector2.ONE * HOVER_SCALE
	elif _selected or _previewed:
		lift = SELECTED_LIFT
		target_scale = Vector2.ONE * SELECTED_SCALE
	z_index = 20 if lift < 0.0 else 0
	if _pose_tween != null:
		_pose_tween.kill()
	if top_level:
		scale = target_scale
		return
	if immediate or not is_inside_tree():
		position = Vector2(position.x, lift)
		scale = target_scale
		return
	_pose_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_pose_tween.tween_property(self, "position:y", lift, 0.12)
	_pose_tween.parallel().tween_property(self, "scale", target_scale, 0.12)
