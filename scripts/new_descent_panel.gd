extends Control
class_name NewDescentPanel

signal begin_requested(depth: int)
signal back_requested
signal depth_changed(depth: int)

const Rules = preload("res://scripts/depth_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Frame = preload("res://scripts/ui_gilded_frame.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const Rule = preload("res://scripts/ui_gilded_rule.gd")
const PANEL_SIZE: Vector2 = Vector2(860, 780)
const ARROW_SIZE: Vector2 = Vector2(54, 54)
const LIST_TOP: float = 236.0
const FOOTER_TOP: float = 680.0
const MOCKUP_ROW_HEIGHT: float = 44.0
const DENSE_ROW_PITCH: float = 30.0
const DENSE_COLUMN_GAP: float = 40.0
const UNLOCK_HINT_FONT_SIZE: int = 17

class DialogMaterial extends Control:
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		Frame.draw_shadow(self, rect, 80.0, 0.8, Vector2(0, 30), 3.0)
		Frame.draw_fill(self, rect, Color(Color("1f1913"), 0.97), Color(Color("0f0c09"), 0.98), 3)
		Frame.draw_gilding(self, rect, Palette.GOLD_DIM, 1.0, 7.0, 3.0, false)
		Frame.draw_corner_brackets(self, rect, Palette.GOLD, 46, 4, -2)

var selected_depth: int = 0
var unlocked_depth: int = 0
var _profile: Dictionary = {}
var _skin = UiSkin.new()
var _panel: Control
var _title: Label
var _title_glow: Control
var _subline: RichTextLabel
var _list: Control
var _unlock: Label
var _left: Button
var _right: Button
var _begin: Button
var _back: Button

func _ready() -> void:
	name = "NewDescentPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build()
	resized.connect(_layout)
	_layout()
	_refresh()

func configure(profile: Dictionary, chosen: int = -1) -> void:
	_profile = Store.normalized_data(profile)
	unlocked_depth = Store.unlocked_umbra_depth(_profile)
	selected_depth = Store.selected_umbra_depth(_profile) if chosen < 0 else clampi(chosen, 0, unlocked_depth)
	if _panel != null: _refresh()

func _build() -> void:
	var scrim := ColorRect.new()
	scrim.name = "DepthScrim"
	scrim.color = Color(0, 0, 0, 0.58)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	_panel = DialogMaterial.new()
	_panel.name = "DepthDialog"
	_panel.size = PANEL_SIZE
	add_child(_panel)
	var eyebrow: Label = _label("DepthEyebrow", "NEW DESCENT", _spaced_font(5), 15, Palette.UMBRA, Rect2(64, 46, 732, 22))
	eyebrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title = _label("DepthTitle", "", Typography.display_font(), 64, Palette.GOLD_BRIGHT, Rect2(146, 78, 568, 76))
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_color_override("font_shadow_color", Color("2b1d3d"))
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title_glow = Control.new()
	_title_glow.name = "DepthTitleGlow"
	_title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_title_glow)
	_panel.move_child(_title_glow, _title.get_index())
	for radius: int in range(1, 27):
		var glow: Label = _label("DepthGlow%d" % radius, "", Typography.display_font(), 64, Color.TRANSPARENT, Rect2(146, 78, 568, 76), _title_glow)
		glow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		glow.add_theme_color_override("font_outline_color", Color(Palette.UMBRA, 1.0 - pow(1.0 - 0.22, 1.0 / 26.0)))
		glow.add_theme_constant_override("outline_size", radius)
	_left = _arrow("DepthPrevious", "◀", Vector2(106, 87))
	_right = _arrow("DepthNext", "▶", Vector2(700, 87))
	_left.pressed.connect(change_depth.bind(-1))
	_right.pressed.connect(change_depth.bind(1))
	_subline = RichTextLabel.new()
	_subline.name = "DepthSubline"
	_subline.bbcode_enabled = true
	_subline.scroll_active = false
	_subline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_subline.position = Vector2(64, 158)
	_subline.size = Vector2(732, 30)
	_subline.add_theme_font_override("normal_font", Typography.text_font())
	_subline.add_theme_font_override("bold_font", Typography.ui_font())
	_subline.add_theme_font_size_override("normal_font_size", 20)
	_subline.add_theme_font_size_override("bold_font_size", 20)
	_subline.add_theme_color_override("default_color", Palette.TEXT_2)
	_panel.add_child(_subline)
	var rule = Rule.new()
	rule.name = "DepthGildedRule"
	rule.position = Vector2(170, 203)
	rule.size = Vector2(520, 14)
	rule.span_ratio = 1.0
	_panel.add_child(rule)
	_list = Control.new()
	_list.name = "DepthModifiers"
	_list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_list)
	_unlock = _label("DepthUnlockHint", "", Typography.text_font(), UNLOCK_HINT_FONT_SIZE, Palette.TEXT_3, Rect2(64, 640, 732, 30))
	_unlock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_back = _button("DepthBack", "Back", Rect2(249, FOOTER_TOP, 122, 56), false)
	_begin = _button("DepthBegin", "Begin Descent", Rect2(389, FOOTER_TOP, 222, 56), true)
	_back.pressed.connect(cancel)
	_begin.pressed.connect(begin)
	_back.focus_neighbor_right = _back.get_path_to(_begin)
	_begin.focus_neighbor_left = _begin.get_path_to(_back)

func _label(id: String, text: String, font: Font, font_size: int, color: Color, rect: Rect2, parent: Control = null) -> Label:
	var label := Label.new()
	label.name = id
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	if font_size >= 0: label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = rect.position
	label.size = rect.size
	(parent if parent != null else _panel).add_child(label)
	return label

func _spaced_font(spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = Typography.ui_font()
	font.spacing_glyph = spacing
	return font

func _arrow(id: String, text: String, at: Vector2) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.position = at
	button.size = ARROW_SIZE
	button.add_theme_font_override("font", Typography.ui_font())
	button.add_theme_font_size_override("font_size", 24)
	for state: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style := StyleBoxFlat.new()
		style.bg_color = Color("1a1510")
		style.border_color = Palette.GOLD if state in ["hover", "focus"] else Palette.GOLD_DIM
		style.set_border_width_all(1)
		style.set_corner_radius_all(27)
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", Palette.GOLD)
	button.add_theme_color_override("font_disabled_color", Palette.GOLD)
	preload("res://scripts/ui_button_feedback.gd").bind_button(button)
	_panel.add_child(button)
	return button

func _button(id: String, text: String, rect: Rect2, primary: bool) -> Button:
	var button := Button.new()
	button.name = id
	button.text = text
	button.add_theme_font_override("font", Typography.ui_font())
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Palette.TEXT)
	_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_SELECTED if primary else UiSkin.VARIANT_STANDARD)
	button.position = rect.position
	button.size = rect.size
	_panel.add_child(button)
	return button

func _layout() -> void:
	if _panel != null: _panel.position = (size - PANEL_SIZE) * 0.5

func _refresh() -> void:
	_title.text = "Umbra Depth %d" % selected_depth
	for glow: Label in _title_glow.get_children(): glow.text = _title.text
	_left.disabled = selected_depth == 0
	_right.disabled = selected_depth == unlocked_depth
	_left.modulate.a = 0.35 if _left.disabled else 1.0
	_right.modulate.a = 0.35 if _right.disabled else 1.0
	var deepest: int = Store.deepest_umbra_escape(_profile)
	var escapes: String = "Deepest escape: Depth %d" % deepest if deepest >= 0 else "No escapes yet"
	_subline.text = "[center]Score [color=#e8893a][b]+%d%%[/b][/color] · %s[/center]" % [Rules.score_percent({Rules.STATE_KEY: selected_depth}), escapes]
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var two_columns: bool = selected_depth > 10
	_list.position = Vector2(64 if two_columns else 130, LIST_TOP)
	_list.size = Vector2(732 if two_columns else 600, 0)
	var column_gap: float = DENSE_COLUMN_GAP if two_columns else 0.0
	var column_width: float = (_list.size.x - column_gap) * 0.5 if two_columns else _list.size.x
	var rows: int = mini(selected_depth, 10)
	var hint_visible: bool = selected_depth == unlocked_depth and unlocked_depth < Rules.MAX_DEPTH
	var list_limit: float = FOOTER_TOP - (40.0 if hint_visible else 18.0) - LIST_TOP
	var row_height: float = DENSE_ROW_PITCH if two_columns else minf(MOCKUP_ROW_HEIGHT, list_limit / maxi(1, rows))
	var bottom: float = 0
	if selected_depth == 0:
		_label("DepthZeroRule", "The Umbra as you first knew it.", Typography.text_font(), 21, Palette.TEXT_2, Rect2(0, 0, 600, 44), _list)
		bottom = 44
	for level: Dictionary in Rules.levels(selected_depth):
		var index: int = int(level["depth"]) - 1
		var column: int = int(index / 10) if two_columns else 0
		var row: int = index % 10 if two_columns else index
		var x: float = column * (column_width + column_gap)
		var y: float = row * row_height
		var newest: bool = int(level["depth"]) == selected_depth
		var number: Label = _label("ModifierNumber%d" % (index + 1), str(index + 1), Typography.ui_font(), 15, Palette.TEXT_3, Rect2(x, y, 28, row_height), _list)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var text_width: float = column_width - 44 - (68 if newest else 0)
		var body: Label = _label("ModifierText%d" % (index + 1), str(level["text"]), Typography.text_font(), 19 if two_columns else 21, Palette.TEXT if newest else Palette.TEXT_2, Rect2(x + 44, y, text_width, row_height), _list)
		body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# A wrapped newest row has no later row in its column. Keep the fixed
		# pitch while allowing its full text above the unlock hint.
		body.size.y = maxf(row_height, body.get_theme_font("font").get_multiline_string_size(body.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, body.get_theme_font_size("font_size")).y)
		if newest:
			var tag := Panel.new()
			tag.name = "DepthNewTag"
			var tag_style := StyleBoxFlat.new()
			tag_style.bg_color = Palette.EMBER
			tag_style.set_corner_radius_all(2)
			tag.add_theme_stylebox_override("panel", tag_style)
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.position = Vector2(x + column_width - 52, y + (row_height - 18) * 0.5)
			tag.size = Vector2(52, 18)
			_list.add_child(tag)
			var tag_text: Label = _label("DepthNewText", "NEW", _spaced_font(3), 12, Color("1b0f06"), Rect2(0, 0, 52, 18), tag)
			tag_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			tag_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		var divider := ColorRect.new()
		divider.color = Color(Palette.GOLD_DIM, 0.18)
		divider.position = Vector2(x, y + row_height - 1)
		divider.size = Vector2(column_width, 1)
		divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_list.add_child(divider)
		bottom = maxf(bottom, y + body.size.y)
	_list.size.y = bottom
	_unlock.text = "Escape at Depth %d to unlock Depth %d." % [selected_depth, selected_depth + 1]
	_unlock.visible = hint_visible
	_unlock.position.y = LIST_TOP + bottom + 8

func change_depth(delta: int) -> void:
	var next: int = clampi(selected_depth + delta, 0, unlocked_depth)
	if next == selected_depth: return
	selected_depth = next
	_feedback()
	_refresh()
	depth_changed.emit(selected_depth)

func focus_begin() -> void:
	_begin.grab_focus()

func begin() -> void:
	_feedback()
	begin_requested.emit(selected_depth)

func cancel() -> void:
	_feedback()
	back_requested.emit()

func _feedback() -> void:
	var feedback: Node = get_node_or_null("/root/CursorFeedback")
	if feedback != null: feedback.call("play_action_confirmation")

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if event is InputEventKey:
		var key := event as InputEventKey
		if not key.pressed or key.echo: return false
		match key.keycode:
			KEY_LEFT: change_depth(-1)
			KEY_RIGHT: change_depth(1)
			KEY_ENTER, KEY_KP_ENTER: begin()
			KEY_ESCAPE: cancel()
			_: return false
		return true
	if event is InputEventJoypadButton:
		var button := event as InputEventJoypadButton
		if not button.pressed: return false
		match button.button_index:
			JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_DPAD_LEFT: change_depth(-1)
			JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_DPAD_RIGHT: change_depth(1)
			JOY_BUTTON_A: begin()
			JOY_BUTTON_B: cancel()
			_: return false
		return true
	return false

static func update_run_header(subtitle: Label, state: Dictionary, layout_changed: Callable = Callable()) -> void:
	var parent: Node = subtitle.get_parent()
	var tag: Label = parent.get_node_or_null("UmbraDepthTag") as Label
	if Rules.depth(state) > 0 and tag == null:
		tag = Label.new()
		tag.name = "UmbraDepthTag"
		Typography.apply_eyebrow(tag, Typography.SIZE_SMALL + 1, Palette.UMBRA)
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(tag)
		parent.move_child(tag, subtitle.get_index() + 1)
		if layout_changed.is_valid(): tag.resized.connect(layout_changed)
	if tag != null:
		tag.text = "Umbra Depth %d" % Rules.depth(state)
		tag.visible = Rules.depth(state) > 0 and str(state.get("mode", "")) not in ["defeat", "victory", "embrace"]

static func header_minimum_width(subtitle: Label, width: float) -> float:
	var tag: Label = subtitle.get_parent().get_node_or_null("UmbraDepthTag") as Label
	return maxf(width, tag.get_combined_minimum_size().x) if tag != null and tag.visible else width

static func header_bottom(subtitle: Label, bottom: float) -> float:
	var tag: Label = subtitle.get_parent().get_node_or_null("UmbraDepthTag") as Label
	return maxf(bottom, tag.get_global_rect().end.y) if tag != null and tag.visible else bottom
