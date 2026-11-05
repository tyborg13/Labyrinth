extends RefCounted

## Variant B (sb-01): one geometry contract for paint, hover and HUD obstacles.
# Feedback 1 makes mock_status.py's fill-derived row anchors authoritative.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Elements = preload("res://scripts/element_data.gd")
const PreviewPulse = preload("res://scripts/combat_preview_pulse.gd")
const Forecast = preload("res://scripts/combat_hud_forecast.gd")
const PopTracker = preload("res://scripts/status_pop_tracker.gd")
const CLASS_ORDER: PackedStringArray = ["control", "vulnerable", "buff", "trait"]
const PLATE_HEIGHT: float = 24.0
const PILL_HEIGHT: float = 22.0
const PLATE_GAP: float = 3.0
const PILL_GAP: float = 4.0
const PILL_ROW_GAP: float = 3.0
const PILL_ROW_WIDTH: float = 260.0
# The existing health bar draws a 1 px border over the fill's outer edge.
const HEALTH_BAR_BORDER_WIDTH: float = 1.0
const ICON_ALPHA_THRESHOLD: float = 0.1
const BORDER_WIDTH: int = 2
const ICON_BORDER_CLEARANCE: float = 1.0
# Board status producers, keyword-status producers, illusions and defenses.
# Kept exhaustive by the independent live-producer inventory test.
const BOARD_ICON_KEYS: PackedStringArray = ["freeze", "petrify", "shock", "immobilize", "chilled", "bleed", "expose", "truesight", "frost_armor", "retaliate", "quicken", "next_attack", "anchored", "skate", "fireproof", "reflect", "flying", "charge", "burrow", "burst", "wind", "ranged", "block", "stoneskin"]
static var _styles: Dictionary = {}
static var _icon_visible_bounds: Dictionary = {}
static var icon_bounds_computations: int = 0
static var _skin := UiSkin.new()

static func status_class(badge: Dictionary) -> String:
	# Source annotations distinguish restrictions from effects using the same icon.
	return str(badge.get("status_class", "buff"))

static func class_border(kind: String) -> Color:
	match kind:
		"control": return Palette.EMBER
		"vulnerable": return Palette.DANGER_BRIGHT
		"trait": return Palette.TEXT_2
	return Palette.GOLD_BRIGHT

static func ordered_badges(badges: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary]
	# Stable partition: preserve the existing order within each semantic class.
	for kind: String in CLASS_ORDER:
		for source: Dictionary in badges:
			if status_class(source) != kind: continue
			var badge: Dictionary = source.duplicate()
			var label: String = str(badge.get("status_word", ""))
			var counted: bool = false
			if label.is_empty():
				label = str(badge.get("count_text", ""))
				if label.is_empty() and (int(badge.get("count", 0)) > 0 or bool(badge.get("show_count", false))):
					label = str(int(badge.get("count", 0)))
				counted = not label.is_empty()
			if bool(badge.get("predicted", false)): label = "→ " + label
			badge["status_class"] = kind
			badge["label"] = label
			badge["label_font_size"] = 15 if counted else 14
			badge["presentation_border"] = class_border(kind)
			badge["presentation_alpha"] = 0.7 if bool(badge.get("predicted", false)) else 1.0
			result.append(badge)
	return result

static func defense_entries(unit: Dictionary, frame: Rect2, preview: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if bool(unit.get("death_animation", false)): return result
	var font: Font = Typography.heavy_ui_font()
	var x: float = frame.end.x + 2.0
	for key: String in ["block", "stoneskin"]:
		var amount: int = int(preview.get(key, unit.get(key, 0)))
		var spent: bool = int(preview.get(key + "_loss", 0)) > 0
		if amount <= 0 and not spent: continue
		var label: String = str(amount)
		var width: float = 4.0 + 20.0 + 3.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 17).x + 9.0
		var rect := Rect2(Vector2(x, frame.get_center().y - PLATE_HEIGHT * 0.5), Vector2(width, PLATE_HEIGHT))
		result.append({"rect": rect, "icon": key, "label": label, "label_font_size": 17,
			"presentation_border": Palette.DANGER if spent else Palette.STEEL if key == "block" else Elements.accent(Elements.EARTH),
			"presentation_alpha": 1.0, "hud_forecast": Forecast.field_is_preview(unit, key, preview), "defense_plate": true, "tooltip": Icons.tooltip(key)})
		x = rect.end.x + PLATE_GAP
	return result

static func status_entries(badges: Array[Dictionary], fill: Rect2, hero: bool) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var font: Font = Typography.heavy_ui_font()
	var origin := Vector2(fill.position.x - (4.0 if hero else 10.0), fill.end.y + 9.0)
	var position: Vector2 = origin
	for badge: Dictionary in badges:
		var label: String = str(badge["label"])
		# mock_status.py: 22 + (6 + number/word width, or 2 for icon only) + 4.
		var width: float = 22.0 + (6.0 + font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, int(badge["label_font_size"])).x if not label.is_empty() else 2.0) + 4.0
		if position.x > origin.x and position.x + width > origin.x + PILL_ROW_WIDTH:
			position = Vector2(origin.x, position.y + PILL_HEIGHT + PILL_ROW_GAP)
		var entry: Dictionary = badge.duplicate()
		entry["rect"] = Rect2(position, Vector2(width, PILL_HEIGHT))
		entry["tooltip"] = str(badge.get("tooltip", Icons.tooltip(str(badge.get("icon", "")))))
		result.append(entry)
		position.x += width + PILL_GAP
	return result

static func rects(entries: Array[Dictionary]) -> Array[Rect2]:
	var result: Array[Rect2]
	for entry: Dictionary in entries: result.append(entry["rect"] as Rect2)
	return result

# A landing pop scales the badge itself once. Reduced Motion keeps it still.
static func draw_entry(view: Object, entry: Dictionary, texture: Texture2D, number_scale: float = 1.0, pop: float = -1.0, still: bool = false, forecast_presentation: Dictionary = {}) -> void:
	var rect: Rect2 = entry["rect"]
	var plate: bool = bool(entry.get("defense_plate", false))
	var forecast: bool = bool(entry.get("predicted", false)) or bool(entry.get("hud_forecast", false))
	var alpha: float = PreviewPulse.alpha(forecast_presentation) if forecast else float(entry["presentation_alpha"])
	var border: Color = entry["presentation_border"]
	var outer := Transform2D.IDENTITY
	if pop >= 0.0 and not forecast:
		if not still:
			var swell: float = PopTracker.pill_scale(pop)
			var center: Vector2 = rect.get_center()
			outer = Transform2D(0.0, Vector2(swell, swell), 0.0, center - center * swell)
			view.draw_set_transform_matrix(outer)
	view.draw_style_box(_style(border, 5 if plate else 11, alpha, forecast), rect)
	if plate:
		view.draw_line(rect.position + Vector2(3.0, 3.0), Vector2(rect.end.x - 3.0, rect.position.y + 3.0), Color(border, 0.35 * alpha), 1.0, true)
	if texture != null:
		var geometry: Dictionary = icon_geometry(entry, texture)
		if not geometry.is_empty():
			view.draw_texture_rect_region(texture, geometry["rect"], geometry["source"], Color(1.0, 1.0, 1.0, alpha))
	var label: String = str(entry["label"])
	if not label.is_empty():
		var font: Font = Typography.heavy_ui_font()
		var font_size: int = int(entry["label_font_size"])
		var baseline: float = (rect.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
		var origin: Vector2 = rect.position + Vector2(27.0 if plate else 24.0, baseline)
		if not is_equal_approx(number_scale, 1.0):
			var pivot: Vector2 = origin + Vector2(font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x * 0.5, -font.get_ascent(font_size) * 0.5)
			view.draw_set_transform_matrix(outer * Transform2D(0.0, Vector2.ONE * number_scale, 0.0, pivot))
			origin -= pivot
		view.draw_string_outline(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, 2 if plate else 1, Color(Palette.TEXT_OUTLINE, alpha))
		view.draw_string(font, origin, label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color(Palette.TEXT, alpha))
		if not is_equal_approx(number_scale, 1.0): view.draw_set_transform_matrix(outer)
	if outer != Transform2D.IDENTITY: view.draw_set_transform_matrix(Transform2D.IDENTITY)
	view._register_tooltip(rect, str(entry["tooltip"]))

static func icon_fit_box(entry: Dictionary) -> Rect2:
	var rect: Rect2 = entry["rect"]
	var plate: bool = bool(entry.get("defense_plate", false))
	var side: float = 20.0 if plate else 18.0
	var slot := Rect2(rect.position + Vector2(4.0 if plate else 3.0, 2.0), Vector2.ONE * side)
	return slot.intersection(rect.grow(-float(BORDER_WIDTH) - ICON_BORDER_CLEARANCE))

static func icon_visible_bounds(texture: Texture2D) -> Rect2i:
	if texture == null: return Rect2i()
	# Keep the texture as the key: retained board layers share it, and instance-ID
	# reuse cannot give a different texture stale bounds. Never alter tooltip art.
	if _icon_visible_bounds.has(texture): return _icon_visible_bounds[texture]
	icon_bounds_computations += 1
	var bounds := Rect2i()
	var image: Image = Assets.texture_source_image(texture)
	if image != null and not image.is_empty():
		if image.is_compressed(): image.decompress()
		var first: Vector2i = image.get_size()
		var last := Vector2i(-1, -1)
		var used: Rect2i = image.get_used_rect()
		for y: int in range(used.position.y, used.end.y):
			for x: int in range(used.position.x, used.end.x):
				if image.get_pixel(x, y).a <= ICON_ALPHA_THRESHOLD: continue
				first = first.min(Vector2i(x, y))
				last = last.max(Vector2i(x, y))
		if last.x >= first.x: bounds = Rect2i(first, last - first + Vector2i.ONE)
	_icon_visible_bounds[texture] = bounds
	return bounds

static func prewarm_icon(icon: String, texture: Texture2D) -> void:
	if texture == null or not BOARD_ICON_KEYS.has(icon): return
	# Called by each icon-loading job, including staged board preparation. Move
	# both image readbacks off the first status-application draw. The per-texture
	# miss path above remains available for replacement/unanticipated textures.
	icon_visible_bounds(texture)
	Assets.texture_used_rect(texture)

static func icon_geometry(entry: Dictionary, texture: Texture2D) -> Dictionary:
	var visible := Rect2(icon_visible_bounds(texture))
	if not visible.has_area(): return {}
	var source := Rect2(Assets.texture_used_rect(texture))
	var fit: Rect2 = icon_fit_box(entry)
	# The visible origin snaps inward; the far edge can remain fractional. This
	# keeps already-fitting art at its old scale on moving/subpixel HUDs too.
	var pixel_fit := Rect2(fit.position.ceil(), fit.end - fit.position.ceil())
	if not source.has_area() or not pixel_fit.has_area(): return {}
	var side: float = 20.0 if bool(entry.get("defense_plate", false)) else 18.0
	# Preserve the old source crop and nominal scale; only shrink when needed.
	var scale: float = minf(side / maxf(source.size.x, source.size.y), minf(pixel_fit.size.x / visible.size.x, pixel_fit.size.y / visible.size.y))
	var size: Vector2 = visible.size * scale
	var origin: Vector2 = (fit.get_center() - size * 0.5).round()
	origin = origin.clamp(pixel_fit.position, (pixel_fit.end - size).floor())
	var destination := Rect2(origin - (visible.position - source.position) * scale, source.size * scale)
	return {"rect": destination, "source": source}

static func _style(border: Color, radius: int, alpha: float, animated: bool = false) -> StyleBoxFlat:
	# A continuous alpha must not allocate a distinct cached style every frame.
	var key: Array = [border, radius, "preview" if animated else alpha]
	if not _styles.has(key):
		var style: StyleBoxFlat = _skin.make_flat_panel_style(Color(Palette.INK_1, 0.93 * alpha), 0.0)
		style.border_color = Color(border, alpha)
		style.set_border_width_all(BORDER_WIDTH)
		style.set_corner_radius_all(radius)
		_styles[key] = style
	var result: StyleBoxFlat = _styles[key]
	if animated:
		result.bg_color.a = 0.93 * alpha
		result.border_color.a = alpha
	return result
