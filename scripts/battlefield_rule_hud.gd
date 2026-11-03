extends PanelContainer

## The fight's battlefield rule, docked above the objective as its twin: the rule's
## icon, its name and its one sentence (el-04; spec/peer_benchmark/element_rules/el-04_design.md).

const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const GildedFrame = preload("res://scripts/ui_gilded_frame.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")

const KICKER: String = "BATTLEFIELD"
const TITLE_FONT_SIZE: int = 19
const DETAIL_FONT_SIZE: int = 14
const DETAIL_MAX_LINES: int = 3
const ICON_WELL_SIZE: float = 50.0
const ROW_SEPARATION: float = 12.0
const TITLE_ARROW_GAP: float = 8.0
const MARGIN_LEFT: float = 12.0
const MARGIN_RIGHT: float = 16.0
const MARGIN_VERTICAL: float = 8.0

# The objective's icon well, drawn with the shared plate.
class IconWell extends PanelContainer:
	func _draw() -> void:
		Surface.draw_plate(self, Rect2(Vector2.ZERO, size), Palette.INK_0, Palette.INK_0, 3.0, Color(Palette.GOLD_DIM, 0.95))

var _icon: TextureRect
var _kicker: Label
var _title: Label
var _arrow: Control
var _detail: Label
var _signature: String = ""
var rule_id: String = ""

func _ready() -> void:
	_build()

## Returns true when what the panel shows changed.
func set_combat_state(state: Dictionary, engine: RefCounted) -> bool:
	_build()
	var room_rule: Dictionary = preload("res://scripts/hoarder_room_rules.gd").panel(state) if not state.is_empty() else {}
	if not room_rule.is_empty(): return _set_room_rule(room_rule)
	var panel: Dictionary = BattlefieldRules.panel(state) if not state.is_empty() else {}
	if panel.is_empty():
		var changed: bool = visible or not _signature.is_empty()
		visible = false
		_signature = ""
		rule_id = ""
		return changed
	var instance: Dictionary = BattlefieldRules.active(state)
	var kicker_text: String = KICKER
	if instance.has("beats_remaining"):
		var beats: int = int(instance["beats_remaining"])
		kicker_text += " · %d BEAT%s LEFT" % [beats, "" if beats == 1 else "S"]
	var heading := Vector2.ZERO
	var forecast: Dictionary = BattlefieldRules.forecast(engine, state) if engine != null else {}
	if forecast.has("direction"):
		heading = WindView.screen_direction(forecast["direction"])
	var next_signature: String = "%s|%s|%s|%s|%s" % [panel["icon"], kicker_text, panel["name"], panel["sentence"], heading]
	if visible and next_signature == _signature:
		return false
	_signature = next_signature
	rule_id = str(panel["rule"])
	_icon.texture = Icons.icon_texture(str(panel["icon"]))
	_kicker.text = kicker_text
	_title.text = str(panel["name"]).to_upper()
	_arrow.visible = heading != Vector2.ZERO
	_arrow.set("heading", heading)
	_arrow.queue_redraw()
	_detail.text = str(panel["sentence"])
	tooltip_text = Icons.tooltip(str(panel["icon"]))
	visible = true
	return true

## A special room's own rule (the Ember Hoarder's clock) in this same panel:
## kicker with the turns left, then name, icon and sentence, all from data.
func _set_room_rule(panel: Dictionary) -> bool:
	var icon_path: String = str(panel["icon_path"])
	var next_signature: String = "%s|%s|%s|%s" % [icon_path, panel["kicker"], panel["name"], panel["sentence"]]
	if visible and next_signature == _signature:
		return false
	_signature = next_signature
	rule_id = str(panel["rule"])
	# A TODO_DESIGN placeholder leaves the icon well empty instead of loading a missing file.
	_icon.texture = null if icon_path.begins_with("TODO_DESIGN") else preload("res://scripts/asset_loader.gd").load_texture(icon_path)
	_kicker.text = str(panel["kicker"])
	_title.text = str(panel["name"]).to_upper()
	_arrow.visible = false
	_arrow.set("heading", Vector2.ZERO)
	_detail.text = str(panel["sentence"])
	tooltip_text = str(panel["sentence"])
	visible = true
	return true

## Height for a given width, so the panel docks exactly above the objective.
func preferred_height(width: float) -> float:
	_build()
	var text_width: float = maxf(1.0, width - MARGIN_LEFT - MARGIN_RIGHT - ICON_WELL_SIZE - ROW_SEPARATION)
	var detail_font: Font = _detail.get_theme_font("font")
	var line_height: float = detail_font.get_height(DETAIL_FONT_SIZE)
	var wrapped: float = detail_font.get_multiline_string_size(_detail.text, HORIZONTAL_ALIGNMENT_LEFT, text_width, DETAIL_FONT_SIZE).y
	var lines: int = clampi(ceili(wrapped / line_height - 0.01), 1, DETAIL_MAX_LINES)
	# A Label adds its theme line spacing between wrapped lines.
	var detail_height: float = lines * line_height + (lines - 1) * _detail.get_theme_constant("line_spacing")
	var stack: float = _kicker.get_theme_font("font").get_height(UiTypography.SIZE_CAPTION) + _title.get_theme_font("font").get_height(TITLE_FONT_SIZE) + detail_height
	return MARGIN_VERTICAL * 2.0 + maxf(ICON_WELL_SIZE, stack)

func set_hud_rect(rect: Rect2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = rect.position.x
	offset_top = rect.position.y
	offset_right = rect.end.x
	offset_bottom = rect.end.y

func _draw() -> void:
	if size.x < 40.0 or size.y < 30.0:
		return
	# The objective's own frame, so the two panels read as one stack.
	GildedFrame.draw_panel(self, Rect2(Vector2.ZERO, size), {
		"top": Color(Palette.INK_2, 0.95),
		"bottom": Color(Palette.INK_1, 0.95),
		"cut": 5.0,
		"shadow_spread": 12.0,
		"inner_inset": 3.0,
	})

func _build() -> void:
	if _icon != null:
		return
	name = "BattlefieldRuleHud"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	var style := StyleBoxEmpty.new()
	style.content_margin_left = MARGIN_LEFT
	style.content_margin_top = MARGIN_VERTICAL
	style.content_margin_right = MARGIN_RIGHT
	style.content_margin_bottom = MARGIN_VERTICAL
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", int(ROW_SEPARATION))
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)
	var icon_frame := IconWell.new()
	icon_frame.custom_minimum_size = Vector2.ONE * ICON_WELL_SIZE
	icon_frame.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	icon_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_margin := StyleBoxEmpty.new()
	icon_margin.set_content_margin_all(4.0)
	icon_frame.add_theme_stylebox_override("panel", icon_margin)
	row.add_child(icon_frame)
	_icon = TextureRect.new()
	_icon.name = "RuleIcon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_icon)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 0)
	text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(text_stack)
	_kicker = Label.new()
	_kicker.name = "RuleKicker"
	UiTypography.apply_eyebrow(_kicker, UiTypography.SIZE_CAPTION, Palette.GOLD)
	_kicker.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	_kicker.add_theme_constant_override("outline_size", 1)
	text_stack.add_child(_kicker)
	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", int(TITLE_ARROW_GAP))
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_stack.add_child(title_row)
	_title = Label.new()
	_title.name = "RuleTitle"
	UiTypography.apply_label_role(_title, UiTypography.ROLE_SECTION)
	_title.add_theme_font_size_override("font_size", TITLE_FONT_SIZE)
	_title.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	_title.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	_title.add_theme_constant_override("outline_size", 3)
	title_row.add_child(_title)
	_arrow = WindView.DirectionArrow.new()
	_arrow.name = "RuleDirection"
	_arrow.custom_minimum_size = Vector2.ONE * float(TITLE_FONT_SIZE)
	_arrow.visible = false
	_arrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_child(_arrow)
	_detail = Label.new()
	_detail.name = "RuleSentence"
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.max_lines_visible = DETAIL_MAX_LINES
	_detail.custom_minimum_size = Vector2(1.0, 0.0)
	UiTypography.apply_label_role(_detail, UiTypography.ROLE_BODY)
	_detail.add_theme_font_size_override("font_size", DETAIL_FONT_SIZE)
	_detail.add_theme_color_override("font_color", Palette.TEXT_2)
	text_stack.add_child(_detail)
