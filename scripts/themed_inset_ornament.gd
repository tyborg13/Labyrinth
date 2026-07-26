extends Node2D

# Compact, code-native companion to the authored corner-and-rail frame kit.
# It is intentionally reserved for subordinate facts, rows, tooltips, and HUD
# widgets where full corner art would become noisy. The silhouette, cast
# shadow, inset lip, side clasp, and state edge still make it a physical object
# rather than a flat rectangle.

const VARIANT_DIALOG: String = "dialog"
const VARIANT_PARCHMENT: String = "parchment"
const VARIANT_HUD: String = "hud"
const VARIANT_CHOICE: String = "choice"
const VARIANT_DANGER: String = "danger"
const TOOLTIP_SHADOW_OFFSET: Vector2 = Vector2(0.0, 2.0)
const TOOLTIP_SHADOW_RESERVE: float = 4.0
const TOOLTIP_WRAPPER_SANITIZED_META: String = "tooltip_wrapper_sanitized"

var _panel: PanelContainer
var _variant: String = VARIANT_DIALOG


func configure(panel: PanelContainer, variant: String) -> void:
	_panel = panel
	_variant = variant
	name = "ThemedInsetOrnament"
	show_behind_parent = true
	position = Vector2.ZERO
	z_index = -1
	var redraw := Callable(self, "queue_redraw")
	if not panel.resized.is_connected(redraw):
		panel.resized.connect(redraw)
	queue_redraw()


func _ready() -> void:
	call_deferred("_sanitize_native_tooltip_wrapper")


func set_variant(variant: String) -> void:
	_variant = variant
	queue_redraw()


func _draw() -> void:
	var draw_size: Vector2 = surface_size()
	if _panel == null or draw_size.x < 24.0 or draw_size.y < 18.0:
		return
	var palette: Dictionary = _palette()
	var notch: float = clampf(minf(draw_size.x, draw_size.y) * 0.13, 5.0, 14.0)
	var disabled: bool = bool(_panel.get_meta("panel_disabled", false))
	var selected: bool = bool(_panel.get_meta("panel_selected", false))
	var hovered: bool = bool(_panel.get_meta("panel_hovered", false))
	var tooltip_surface: bool = _is_tooltip_surface()
	var body_rect: Rect2 = _surface_body_rect(tooltip_surface)
	var body_points: PackedVector2Array = _surface_points(body_rect, notch)
	var accent: Color = Color(_panel.get_meta("panel_surface_accent", palette["edge"]))
	var shadow_offset: Vector2 = TOOLTIP_SHADOW_OFFSET if tooltip_surface else Vector2(0.0, 5.0)

	draw_colored_polygon(
		_offset_points(body_points, shadow_offset),
		Color(0.0, 0.0, 0.0, 0.18 if disabled else (0.28 if tooltip_surface else 0.54))
	)
	draw_colored_polygon(body_points, palette["outer"])

	var inset_rect: Rect2 = body_rect.grow(-3.0)
	var inset_points: PackedVector2Array = _surface_points(inset_rect, maxf(2.0, notch - 2.5))
	var inner: Color = palette["inner"]
	if disabled:
		inner = inner.lerp(Color("111116"), 0.52)
	elif selected:
		inner = inner.lerp(accent.darkened(0.48), 0.36)
	elif hovered:
		inner = inner.lightened(0.045)
	draw_colored_polygon(inset_points, inner)

	var state_alpha: float = 0.86 if selected else (0.72 if hovered else 0.34)
	if disabled:
		state_alpha = 0.18
	var state_edge := Color(accent.r, accent.g, accent.b, state_alpha)
	draw_polyline(_closed_points(inset_points), state_edge, 2.0 if hovered or selected else 1.0, true)

	var top_left: Vector2 = inset_points[0]
	var top_right: Vector2 = inset_points[1]
	draw_line(top_left, top_right, Color(1.0, 0.86, 0.62, 0.16 if not disabled else 0.06), 1.0, true)
	var bottom_start: Vector2 = inset_points[4]
	var bottom_end: Vector2 = inset_points[5]
	draw_line(bottom_start, bottom_end, Color(0.0, 0.0, 0.0, 0.58), 2.0, true)
	_draw_side_clasp(accent, hovered or selected, disabled)


func visual_bounds() -> Rect2:
	var tooltip_surface: bool = _is_tooltip_surface()
	var body_rect: Rect2 = _surface_body_rect(tooltip_surface)
	if not tooltip_surface:
		return body_rect.merge(Rect2(body_rect.position + Vector2(0.0, 5.0), body_rect.size))
	return body_rect.merge(Rect2(body_rect.position + TOOLTIP_SHADOW_OFFSET, body_rect.size))


func _surface_body_rect(tooltip_surface: bool) -> Rect2:
	var reserve: float = TOOLTIP_SHADOW_RESERVE if tooltip_surface else 0.0
	return Rect2(Vector2(1.0, 1.0), surface_size() - Vector2(2.0, 2.0 + reserve))


func surface_size() -> Vector2:
	return _panel.size if _panel != null else Vector2.ZERO


func _is_tooltip_surface() -> bool:
	return (
		_panel != null
		and (
			bool(_panel.get_meta("tooltip_surface", false))
			or _is_native_tooltip_root()
		)
	)


func _is_native_tooltip_root() -> bool:
	var wrapper: Window = _native_tooltip_wrapper()
	if wrapper == null or _panel == null:
		return false
	var ancestor: Node = _panel.get_parent()
	while ancestor != null and ancestor != wrapper:
		if ancestor is PanelContainer:
			return false
		ancestor = ancestor.get_parent()
	return ancestor == wrapper


func _native_tooltip_wrapper() -> Window:
	var ancestor: Node = _panel.get_parent() if _panel != null else null
	while ancestor != null:
		if ancestor is Window and str((ancestor as Window).theme_type_variation) == "TooltipPanel":
			return ancestor as Window
		ancestor = ancestor.get_parent()
	return null


func _sanitize_native_tooltip_wrapper() -> void:
	if _is_tooltip_surface():
		_normalize_tooltip_label_minimums()
	var wrapper: Window = _native_tooltip_wrapper()
	if (
		wrapper == null
		or not _is_native_tooltip_root()
		or bool(wrapper.get_meta(TOOLTIP_WRAPPER_SANITIZED_META, false))
	):
		return
	var wrapper_theme := Theme.new()
	if wrapper.theme != null:
		wrapper_theme = wrapper.theme.duplicate(true) as Theme
	var empty_style := StyleBoxEmpty.new()
	wrapper_theme.set_stylebox("panel", "TooltipPanel", empty_style)
	wrapper_theme.set_stylebox("panel", "PopupPanel", empty_style)
	wrapper.theme = wrapper_theme
	wrapper.transparent_bg = true
	wrapper.borderless = true
	wrapper.wrap_controls = false
	wrapper.set_meta(TOOLTIP_WRAPPER_SANITIZED_META, true)
	var queue_tighten := Callable(self, "_queue_native_tooltip_tighten")
	if not wrapper.about_to_popup.is_connected(queue_tighten):
		wrapper.about_to_popup.connect(queue_tighten)
	if not wrapper.visibility_changed.is_connected(queue_tighten):
		wrapper.visibility_changed.connect(queue_tighten)
	_queue_native_tooltip_tighten()


func _queue_native_tooltip_tighten() -> void:
	call_deferred("_tighten_native_tooltip_wrapper")
	_tighten_native_tooltip_after_layout()


func _tighten_native_tooltip_after_layout() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	_tighten_native_tooltip_wrapper()


func _normalize_tooltip_label_minimums() -> void:
	if _panel == null:
		return
	for label_var: Variant in _panel.find_children("*", "Label", true, false):
		var label: Label = label_var as Label
		if label == null or _has_button_ancestor(label):
			continue
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		if font == null or font_size <= 0:
			continue
		# Before the first container layout, wrapped labels can report one line
		# per character because their width is still zero. Reserve authored
		# lines here; normal Label minimum-size calculation handles soft wraps
		# once the tooltip width is established.
		var line_count: int = maxi(1, label.text.count("\n") + 1)
		var line_separation: int = label.get_theme_constant("line_spacing")
		var required_height: float = (
			font.get_height(font_size) * float(line_count)
			+ float(maxi(0, line_count - 1) * line_separation)
		)
		if label.custom_minimum_size.y + 0.5 >= required_height:
			continue
		label.custom_minimum_size.y = ceilf(required_height)
		label.update_minimum_size()
	_panel.update_minimum_size()


func _has_button_ancestor(node: Node) -> bool:
	var ancestor: Node = node.get_parent()
	while ancestor != null and ancestor != _panel:
		if ancestor is Button:
			return true
		ancestor = ancestor.get_parent()
	return false


func _tighten_native_tooltip_wrapper() -> void:
	var wrapper: Window = _native_tooltip_wrapper()
	if wrapper == null or _panel == null or not _panel.is_inside_tree():
		return
	var desired_size := Vector2i(
		ceili(_panel.get_combined_minimum_size().x),
		ceili(_panel.get_combined_minimum_size().y)
	)
	if desired_size.x <= 0 or desired_size.y <= 0:
		return
	var viewport_size: Vector2 = get_tree().root.get_visible_rect().size
	var available_size := Vector2(
		maxf(1.0, viewport_size.x - 32.0),
		maxf(1.0, viewport_size.y - 32.0)
	)
	var content_scale: float = minf(
		1.0,
		minf(
			available_size.x / float(desired_size.x),
			available_size.y / float(desired_size.y)
		)
	)
	var wrapper_size := Vector2i(
		ceili(float(desired_size.x) * content_scale),
		ceili(float(desired_size.y) * content_scale)
	)
	if wrapper.size != wrapper_size:
		wrapper.size = wrapper_size
	_panel.position = Vector2.ZERO
	_panel.size = Vector2(desired_size)
	_panel.pivot_offset = Vector2.ZERO
	_panel.scale = Vector2.ONE * content_scale
	_panel.set_meta("tooltip_content_scale", content_scale)
	wrapper.set_meta("tooltip_native_wrapper_size", wrapper_size)


func _draw_side_clasp(accent: Color, emphasized: bool, disabled: bool) -> void:
	var draw_size: Vector2 = surface_size()
	var clasp_height: float = clampf(draw_size.y * 0.28, 8.0, 18.0)
	var center_y: float = draw_size.y * 0.5
	var clasp := PackedVector2Array([
		Vector2(0.0, center_y - clasp_height * 0.5),
		Vector2(5.0, center_y - clasp_height * 0.36),
		Vector2(5.0, center_y + clasp_height * 0.36),
		Vector2(0.0, center_y + clasp_height * 0.5),
	])
	var alpha: float = 0.22 if disabled else (0.90 if emphasized else 0.52)
	draw_colored_polygon(clasp, Color(accent.r, accent.g, accent.b, alpha))
	draw_line(clasp[1], clasp[2], Color(1.0, 0.89, 0.68, alpha * 0.55), 1.0, true)


func _surface_points(rect: Rect2, notch: float) -> PackedVector2Array:
	var left: float = rect.position.x
	var top: float = rect.position.y
	var right: float = rect.end.x
	var bottom: float = rect.end.y
	return PackedVector2Array([
		Vector2(left + notch, top),
		Vector2(right - notch * 0.55, top),
		Vector2(right, top + notch * 0.72),
		Vector2(right, bottom - notch),
		Vector2(right - notch, bottom),
		Vector2(left + notch * 0.55, bottom),
		Vector2(left, bottom - notch * 0.72),
		Vector2(left, top + notch),
	])


func _palette() -> Dictionary:
	if _is_tooltip_surface():
		return {
			"outer": Color("251d1b"),
			"inner": Color(0.012, 0.012, 0.016, 0.992),
			"edge": Color("8f6b3d"),
		}
	var outer := Color("5b4630")
	var inner := Color(0.045, 0.034, 0.036, 0.98)
	var edge := Color("a77f49")
	match _variant:
		VARIANT_PARCHMENT:
			outer = Color("6b4a2e")
			inner = Color(0.105, 0.063, 0.040, 0.98)
			edge = Color("c89a59")
		VARIANT_HUD:
			outer = Color("403739")
			inner = Color(0.026, 0.024, 0.030, 0.95)
			edge = Color("8f7b68")
		VARIANT_CHOICE:
			outer = Color("69472d")
			inner = Color(0.080, 0.047, 0.034, 0.985)
			edge = Color("d0a05c")
		VARIANT_DANGER:
			outer = Color("6b3034")
			inner = Color(0.086, 0.026, 0.032, 0.985)
			edge = Color("d46f62")
	return {
		"outer": outer,
		"inner": inner,
		"edge": edge,
	}


func _offset_points(points: PackedVector2Array, offset: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		result.append(point + offset)
	return result


func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = points.duplicate()
	if not result.is_empty():
		result.append(result[0])
	return result
