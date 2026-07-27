extends RefCounted
class_name UiSkin

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ThemedButtonOrnament = preload("res://scripts/themed_button_ornament.gd")
const ThemedInsetOrnament = preload("res://scripts/themed_inset_ornament.gd")
const ThemedPanelOrnament = preload("res://scripts/themed_panel_ornament.gd")

const TEXTURES := {
	"panel_main": {
		"path": "res://assets/art/ui/panel_wood_parchment.png"
	},
	"panel_inset": {
		"path": "res://assets/art/ui/panel_silver_inset.png"
	}
}

const PANEL_MARGIN := 12.0
const INSET_MARGIN := 10.0
const BUTTON_MARGIN_H := 16.0
const BUTTON_MARGIN_V := 7.0
const BUTTON_HEIGHT_SMALL: float = 38.0
const BUTTON_HEIGHT_STANDARD: float = 46.0
const BUTTON_HEIGHT_LARGE: float = 52.0
const BUTTON_HEIGHT_ACTION: float = 58.0
const BUTTON_FONT_COLOR := Color("f0e6cf")
const BUTTON_FONT_OUTLINE_COLOR := Color("09090b")
const BUTTON_FONT_FOCUS_COLOR := Color("fff7dd")
const BUTTON_FONT_DISABLED_COLOR := Color("91897b")
const BUTTON_FONT_OUTLINE_SIZE := 2
const ACCENT_TEXT_COLOR := Color("b8860b")
const ACCENT_TEXT_OUTLINE_COLOR := Color("3e2f22")

const VARIANT_COMPACT: String = "compact"
const VARIANT_STANDARD: String = "standard"
const VARIANT_LARGE: String = "large"
const VARIANT_DESTRUCTIVE: String = "destructive"
const VARIANT_SELECTED: String = "selected"
const VARIANT_ICON: String = "icon"

const STATE_NORMAL: String = "normal"
const STATE_HOVER: String = "hover"
const STATE_PRESSED: String = "pressed"
const STATE_DISABLED: String = "disabled"
const STATE_SELECTED: String = "selected"
const STATE_FOCUS: String = "focus"

const BUTTON_ORNAMENT_NAME: String = "ThemedButtonOrnament"
const PANEL_INSET_ORNAMENT_NAME: String = "ThemedInsetOrnament"
const PANEL_ORNAMENT_NAME: String = "ThemedPanelOrnament"
const OUTER_PANEL_RENDERER_NAME: String = "OuterFrameRenderer"
const OUTER_PANEL_BASELINE_STYLE_META: String = "outer_panel_baseline_style"

const SURFACE_DIALOG: String = "dialog"
const SURFACE_PARCHMENT: String = "parchment"
const SURFACE_HUD: String = "hud"
const SURFACE_CHOICE: String = "choice"
const SURFACE_DANGER: String = "danger"

var _cache: Dictionary = {}
# Controls may share these application-only templates because UiSkin never mutates
# them after construction. Callers that customize a StyleBox still receive an
# isolated resource from make_button_style().
var _applied_button_styles: Dictionary = {}
var _applied_button_style_sets: Dictionary = {}

func texture(key: String) -> Texture2D:
	if _cache.has(key):
		return _cache[key]
	if not TEXTURES.has(key):
		push_error("Unknown UI texture key: %s" % key)
		return null
	var spec: Dictionary = TEXTURES[key]
	var path: String = str(spec.get("path", ""))
	var region: Rect2i = spec.get("region", Rect2i())
	var tint: Color = spec.get("tint", Color.WHITE)
	var tex: Texture2D = AssetLoader.load_texture_region(path, region) if region.size.x > 0 and region.size.y > 0 else AssetLoader.load_texture(path)
	if tex != null:
		tex = AssetLoader.modulate_texture(tex, tint)
	_cache[key] = tex
	return tex

func make_panel_style(texture_key: String, margin: float = PANEL_MARGIN, content_margin: float = 16.0) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture(texture_key)
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func make_inset_panel_style(content_margin: float = 14.0) -> StyleBoxTexture:
	return make_panel_style("panel_inset", INSET_MARGIN, content_margin)

func make_board_frame_style(content_margin: float = 26.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("2f2f34")
	style.border_color = Color("d1a65e")
	style.border_width_left = 6
	style.border_width_top = 6
	style.border_width_right = 6
	style.border_width_bottom = 6
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.30)
	style.shadow_size = 12
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	style.expand_margin_left = 4
	style.expand_margin_top = 4
	style.expand_margin_right = 4
	style.expand_margin_bottom = 4
	return style

func make_plain_card_style(background: Color = Color("e8dcc0"), border: Color = Color("8a6d49"), content_margin: float = 12.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.18)
	style.shadow_size = 4
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style

func make_button_style(variant: String = VARIANT_STANDARD, state: String = STATE_NORMAL) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	var palette: Dictionary = _button_palette(variant, state)
	var radius: int = _button_corner_radius(variant)
	var pressed_offset: float = 2.0 if state == STATE_PRESSED else 0.0
	var compact: bool = variant == VARIANT_COMPACT

	style.bg_color = palette.get("background", Color.TRANSPARENT)
	style.border_color = palette.get("border", Color("80653c"))
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 3 if state != STATE_PRESSED else 2
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.anti_aliasing = true
	style.anti_aliasing_size = 0.8
	style.content_margin_left = 11.0 if compact else BUTTON_MARGIN_H
	style.content_margin_top = (5.0 if compact else BUTTON_MARGIN_V) + pressed_offset
	style.content_margin_right = 11.0 if compact else BUTTON_MARGIN_H
	style.content_margin_bottom = maxf(3.0, (5.0 if compact else BUTTON_MARGIN_V) - pressed_offset)

	if state == STATE_FOCUS:
		style.bg_color = Color.TRANSPARENT
		style.border_width_left = 2
		style.border_width_top = 2
		style.border_width_right = 2
		style.border_width_bottom = 2
		style.expand_margin_left = 3.0
		style.expand_margin_top = 3.0
		style.expand_margin_right = 3.0
		style.expand_margin_bottom = 3.0
		style.shadow_color = Color(0.94, 0.69, 0.32, 0.18)
		style.shadow_size = 5
		return style

	if state == STATE_HOVER:
		style.expand_margin_left = 1.0
		style.expand_margin_top = 1.0
		style.expand_margin_right = 1.0
		style.expand_margin_bottom = 1.0
		style.shadow_color = Color(0.86, 0.55, 0.22, 0.15)
		style.shadow_size = 6
		style.shadow_offset = Vector2(0.0, 2.0)
	elif state == STATE_DISABLED:
		style.shadow_color = Color.TRANSPARENT
		style.shadow_size = 0
	elif state == STATE_PRESSED:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.34)
		style.shadow_size = 2
		style.shadow_offset = Vector2(0.0, 1.0)
	else:
		style.shadow_color = Color(0.0, 0.0, 0.0, 0.42)
		style.shadow_size = 4 if compact else 5
		style.shadow_offset = Vector2(0.0, 3.0)
	return style

func button_native_size(height: float, min_width: float = 0.0, variant: String = VARIANT_STANDARD) -> Vector2:
	var width_ratio: float = 2.8
	match variant:
		VARIANT_COMPACT:
			width_ratio = 2.25
		VARIANT_LARGE:
			width_ratio = 3.25
		VARIANT_DESTRUCTIVE:
			width_ratio = 3.0
		VARIANT_SELECTED:
			width_ratio = 2.8
		VARIANT_ICON:
			width_ratio = 1.0
	return Vector2(maxf(min_width, height * width_ratio), height)

func apply_button_native_size(
	button: BaseButton,
	height: float = BUTTON_HEIGHT_STANDARD,
	min_width: float = 0.0,
	center_in_parent: bool = true,
	variant: String = VARIANT_STANDARD
) -> void:
	if button == null:
		return
	button.custom_minimum_size = button_native_size(height, min_width, variant)
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if center_in_parent:
		button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

func apply_button_stylebox_overrides(
	button: BaseButton,
	variant: String = VARIANT_STANDARD
) -> void:
	if button == null:
		return
	var styles: Dictionary = _applied_button_style_set(variant, button.toggle_mode)
	button.add_theme_stylebox_override("normal", styles[STATE_NORMAL])
	button.add_theme_stylebox_override("hover", styles[STATE_HOVER])
	button.add_theme_stylebox_override("pressed", styles["pressed_override"])
	button.add_theme_stylebox_override("hover_pressed", styles["hover_pressed_override"])
	button.add_theme_stylebox_override("focus", styles[STATE_FOCUS])
	button.add_theme_stylebox_override("disabled", styles[STATE_DISABLED])
	button.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	button.set_meta("button_variant", variant)
	if button is Button:
		(button as Button).alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ensure_button_ornament(button, variant)

func _applied_button_style_set(variant: String, toggle_mode: bool) -> Dictionary:
	var cache_key: String = "%s:%s" % [variant, "toggle" if toggle_mode else "plain"]
	if _applied_button_style_sets.has(cache_key):
		return _applied_button_style_sets[cache_key]
	var selected_hover_variant: String = VARIANT_SELECTED if toggle_mode and variant == VARIANT_STANDARD else variant
	var styles: Dictionary = {
		STATE_NORMAL: _applied_button_style(variant, STATE_NORMAL),
		STATE_HOVER: _applied_button_style(variant, STATE_HOVER),
		"pressed_override": _applied_button_style(variant, STATE_SELECTED if toggle_mode else STATE_PRESSED),
		"hover_pressed_override": _applied_button_style(selected_hover_variant, STATE_HOVER),
		STATE_FOCUS: _applied_button_style(variant, STATE_FOCUS),
		STATE_DISABLED: _applied_button_style(variant, STATE_DISABLED),
	}
	_applied_button_style_sets[cache_key] = styles
	return styles

func _applied_button_style(variant: String, state: String) -> StyleBoxFlat:
	var variant_styles: Dictionary = _applied_button_styles.get(variant, {})
	if variant_styles.has(state):
		return variant_styles[state]
	var style: StyleBoxFlat = make_button_style(variant, state)
	variant_styles[state] = style
	_applied_button_styles[variant] = variant_styles
	return style

func apply_button_text_overrides(
	button: BaseButton,
	font_color: Color = BUTTON_FONT_COLOR,
	outline_color: Color = BUTTON_FONT_OUTLINE_COLOR,
	disabled_color: Color = BUTTON_FONT_DISABLED_COLOR,
	outline_size: int = BUTTON_FONT_OUTLINE_SIZE
) -> void:
	button.add_theme_color_override("font_color", font_color)
	button.add_theme_color_override("font_focus_color", BUTTON_FONT_FOCUS_COLOR)
	button.add_theme_color_override("font_hover_color", BUTTON_FONT_FOCUS_COLOR)
	button.add_theme_color_override("font_pressed_color", font_color)
	button.add_theme_color_override("font_hover_pressed_color", BUTTON_FONT_FOCUS_COLOR)
	button.add_theme_color_override("font_disabled_color", disabled_color)
	button.add_theme_color_override("font_outline_color", outline_color)
	button.add_theme_constant_override("outline_size", outline_size)

func _ensure_button_ornament(button: BaseButton, variant: String) -> void:
	var ornament: Control = button.get_node_or_null(BUTTON_ORNAMENT_NAME) as Control
	if ornament == null:
		ornament = ThemedButtonOrnament.new()
		ornament.name = BUTTON_ORNAMENT_NAME
		button.add_child(ornament)
		ornament.call("configure", button, variant)
	else:
		ornament.call("set_variant", variant)

func apply_panel_surface(panel: PanelContainer, variant: String = SURFACE_DIALOG) -> void:
	if panel == null:
		return
	var current_style: StyleBox = panel.get_theme_stylebox("panel")
	var layout_style := StyleBoxFlat.new()
	var safe_inset: float = 12.0 if variant == SURFACE_HUD else 20.0
	var has_explicit_safe_inset: bool = panel.has_meta("panel_safe_inset")
	safe_inset = float(panel.get_meta("panel_safe_inset", safe_inset))
	if current_style != null:
		layout_style.content_margin_left = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_LEFT))
		layout_style.content_margin_top = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_TOP))
		layout_style.content_margin_right = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_RIGHT))
		layout_style.content_margin_bottom = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_BOTTOM))
	else:
		layout_style.content_margin_left = safe_inset
		layout_style.content_margin_top = safe_inset
		layout_style.content_margin_right = safe_inset
		layout_style.content_margin_bottom = safe_inset
	layout_style.bg_color = Color.TRANSPARENT
	layout_style.border_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", layout_style)
	panel.set_meta("surface_variant", variant)
	_ensure_panel_ornament(panel, variant)

func apply_outer_panel_frame(panel: PanelContainer, variant: String = SURFACE_DIALOG) -> void:
	if panel == null:
		return
	# Major menus keep their baseline panel fill, shadow, margins, and internals.
	# The raster is the sole visible outline so a second code-native border cannot
	# peek out around its authored rails and corners.
	_suppress_outer_panel_outline(panel)
	panel.set_meta("surface_variant", variant)
	panel.set_meta("panel_outer_frame_only", true)
	panel.set_meta("panel_frame_scale", 0.14)
	var ornament: Node2D = _ensure_outer_panel_ornament(panel, variant)
	if ornament != null:
		panel.move_child(ornament, panel.get_child_count() - 1)

func apply_inset_surface(panel: PanelContainer, variant: String = SURFACE_DIALOG) -> void:
	if panel == null:
		return
	var current_style: StyleBox = panel.get_theme_stylebox("panel")
	var layout_style := StyleBoxFlat.new()
	var safe_inset: float = 10.0 if variant == SURFACE_HUD else 12.0
	var has_explicit_safe_inset: bool = panel.has_meta("panel_safe_inset")
	safe_inset = float(panel.get_meta("panel_safe_inset", safe_inset))
	if current_style != null:
		layout_style.content_margin_left = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_LEFT))
		layout_style.content_margin_top = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_TOP))
		layout_style.content_margin_right = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_RIGHT))
		layout_style.content_margin_bottom = safe_inset if has_explicit_safe_inset else maxf(safe_inset, current_style.get_content_margin(SIDE_BOTTOM))
	else:
		layout_style.content_margin_left = safe_inset
		layout_style.content_margin_top = safe_inset
		layout_style.content_margin_right = safe_inset
		layout_style.content_margin_bottom = safe_inset
	layout_style.bg_color = Color.TRANSPARENT
	layout_style.border_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", layout_style)
	panel.set_meta("surface_variant", variant)
	panel.set_meta("surface_treatment", "inset")
	var ornament: Node = panel.get_node_or_null(PANEL_INSET_ORNAMENT_NAME)
	if ornament == null:
		ornament = ThemedInsetOrnament.new()
		panel.add_child(ornament)
		ornament.call("configure", panel, variant)
	else:
		ornament.call("set_variant", variant)

func refresh_panel_surface(panel: PanelContainer) -> void:
	if panel == null:
		return
	for ornament_name: String in [PANEL_ORNAMENT_NAME, PANEL_INSET_ORNAMENT_NAME]:
		var ornament: CanvasItem = panel.get_node_or_null(ornament_name) as CanvasItem
		if ornament != null:
			ornament.queue_redraw()
			var renderer: CanvasItem = ornament.get_node_or_null(OUTER_PANEL_RENDERER_NAME) as CanvasItem
			if renderer != null:
				renderer.queue_redraw()

func _ensure_panel_ornament(panel: PanelContainer, variant: String) -> Control:
	var ornament: Control = panel.get_node_or_null(PANEL_ORNAMENT_NAME) as Control
	if ornament == null:
		ornament = ThemedPanelOrnament.new()
		ornament.name = PANEL_ORNAMENT_NAME
		panel.add_child(ornament)
		ornament.call("configure", panel, variant)
	else:
		ornament.call("set_variant", variant)
	return ornament

func _suppress_outer_panel_outline(panel: PanelContainer) -> void:
	var baseline_style: StyleBox = null
	if panel.has_meta(OUTER_PANEL_BASELINE_STYLE_META):
		baseline_style = panel.get_meta(OUTER_PANEL_BASELINE_STYLE_META) as StyleBox
	if baseline_style == null:
		baseline_style = panel.get_theme_stylebox("panel")
		if baseline_style != null:
			panel.set_meta(OUTER_PANEL_BASELINE_STYLE_META, baseline_style)
	if not baseline_style is StyleBoxFlat:
		return
	var raster_backing_style: StyleBoxFlat = baseline_style.duplicate() as StyleBoxFlat
	raster_backing_style.set_border_width_all(0)
	raster_backing_style.border_color = Color.TRANSPARENT
	panel.add_theme_stylebox_override("panel", raster_backing_style)

func _ensure_outer_panel_ornament(panel: PanelContainer, variant: String) -> Node2D:
	var host: Node2D = panel.get_node_or_null(PANEL_ORNAMENT_NAME) as Node2D
	if host == null:
		host = Node2D.new()
		host.name = PANEL_ORNAMENT_NAME
		host.z_index = 1
		panel.add_child(host)
	var renderer: Control = host.get_node_or_null(OUTER_PANEL_RENDERER_NAME) as Control
	if renderer == null:
		renderer = ThemedPanelOrnament.new()
		renderer.name = OUTER_PANEL_RENDERER_NAME
		host.add_child(renderer)
		renderer.call("configure", panel, variant)
	else:
		renderer.call("set_variant", variant)
		renderer.call("sync_outer_frame_rect")
	return host

func _button_corner_radius(variant: String) -> int:
	match variant:
		VARIANT_COMPACT:
			return 4
		VARIANT_LARGE:
			return 8
		VARIANT_ICON:
			return 7
		_:
			return 6

func _button_palette(variant: String, state: String) -> Dictionary:
	var background := Color("151820")
	var border := Color("80653c")
	if variant == VARIANT_ICON:
		background = Color("11151d")
		border = Color("725b38")
	elif variant == VARIANT_LARGE:
		background = Color("17181e")
		border = Color("92703f")
	elif variant == VARIANT_SELECTED:
		background = Color("3b2815")
		border = Color("d5a454")
	elif variant == VARIANT_DESTRUCTIVE:
		background = Color("35171a")
		border = Color("a84c43")

	match state:
		STATE_HOVER:
			background = background.lightened(0.10)
			border = Color("e2b86e") if variant != VARIANT_DESTRUCTIVE else Color("ef8069")
		STATE_PRESSED:
			background = background.darkened(0.16)
			border = Color("c58e48") if variant != VARIANT_DESTRUCTIVE else Color("c95a4d")
		STATE_DISABLED:
			background = Color("111217")
			border = Color("59554e")
		STATE_SELECTED:
			background = Color("3c2815") if variant != VARIANT_DESTRUCTIVE else Color("4b1c20")
			border = Color("e0ad55") if variant != VARIANT_DESTRUCTIVE else Color("e8705d")
		STATE_FOCUS:
			background = Color.TRANSPARENT
			border = Color("ffe3a0")
	return {"background": background, "border": border}

func apply_button_label_overrides(
	label: Label,
	font_color: Color = BUTTON_FONT_COLOR,
	outline_color: Color = BUTTON_FONT_OUTLINE_COLOR,
	outline_size: int = BUTTON_FONT_OUTLINE_SIZE
) -> void:
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_outline_color", outline_color)
	label.add_theme_constant_override("outline_size", outline_size)

func apply_accent_label_overrides(label: Label, outline_size: int = BUTTON_FONT_OUTLINE_SIZE) -> void:
	apply_button_label_overrides(label, ACCENT_TEXT_COLOR, ACCENT_TEXT_OUTLINE_COLOR, outline_size)

func make_scenario_list_button_style(selected: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("edd39d") if selected else (Color("f5e8c8") if hovered else Color("e5dac0"))
	style.border_color = Color("c27c24") if selected else (Color("bb8a49") if hovered else Color("8a6d49"))
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.22)
	style.shadow_size = 5
	style.content_margin_left = BUTTON_MARGIN_H
	style.content_margin_top = BUTTON_MARGIN_V + 2.0
	style.content_margin_right = BUTTON_MARGIN_H
	style.content_margin_bottom = BUTTON_MARGIN_V + 2.0
	style.expand_margin_left = 2.0
	style.expand_margin_top = 2.0
	style.expand_margin_right = 2.0
	style.expand_margin_bottom = 2.0
	return style

func make_flat_panel_style(color: Color, content_margin: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.content_margin_left = content_margin
	style.content_margin_top = content_margin
	style.content_margin_right = content_margin
	style.content_margin_bottom = content_margin
	return style
