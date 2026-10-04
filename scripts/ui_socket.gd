extends Button

# setup(icon, tooltip = "", badge = ""); native pressed/focus/activation.
# socket_size is in layout pixels. Set interactive=false for display-only use,
# selected for the inner gilt ring, and icon_filter for non-pixel-art icons.
# inspect_only keeps help focus without activation; dimmed changes appearance only.
# accent_color frames identity; status_color sits inside it when both are present.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const RING_PATH: String = "res://assets/art/ui/visual_pass_4/medallion_ring.png"
const GEOMETRY_PATH: String = "res://assets/art/ui/visual_pass_4/medallion_ring.json"
const ACTIVE_RING_TINT := Color(1.5, 1.36, 1.12, 1.0)
const DISABLED_RING_TINT := Color(0.72, 0.68, 0.62, 1.0)

static var _geometry_cache: Dictionary = {}
static var _cropped_icons: Dictionary = {}

var socket_size: float = 50.0:
	set(value):
		socket_size = maxf(1.0, value)
		custom_minimum_size = Vector2.ONE * Typography.scaled_value(self, socket_size)
var interactive: bool = true:
	set(value):
		interactive = value
		focus_mode = Control.FOCUS_ALL if value or inspect_only else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP if value or inspect_only else Control.MOUSE_FILTER_IGNORE
		set_meta("cursor_feedback_context", "help" if inspect_only else "action" if value else "inert")
		queue_redraw()
var inspect_only: bool = false:
	set(value):
		inspect_only = value
		focus_mode = Control.FOCUS_ALL if value or interactive else Control.FOCUS_NONE
		mouse_filter = Control.MOUSE_FILTER_STOP if value or interactive else Control.MOUSE_FILTER_IGNORE
		mouse_default_cursor_shape = Control.CURSOR_HELP if value else Control.CURSOR_POINTING_HAND
		button_mask = 0 if value else MOUSE_BUTTON_MASK_LEFT
		set_meta("cursor_feedback_context", "help" if value else "action" if interactive else "inert")
		set_meta("hud_inspect_only", value)
		queue_redraw()
var dimmed: bool = false:
	set(value):
		dimmed = value
		_update_icon_material()
		queue_redraw()
var status_color := Color.TRANSPARENT:
	set(value):
		status_color = value
		queue_redraw()
var accent_color := Color.TRANSPARENT:
	set(value):
		accent_color = value
		queue_redraw()
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var ring_tint := Color(1.14, 1.06, 0.96, 1.0):
	set(value):
		ring_tint = value
		queue_redraw()
var icon_filter: CanvasItem.TextureFilter = CanvasItem.TEXTURE_FILTER_NEAREST:
	set(value):
		icon_filter = value
		_icon.texture_filter = value
		_update_icon_texture()

var _ring := TextureRect.new()
var _icon := TextureRect.new()
var _inner_rings := Control.new()
var _badge := Label.new()
var _glow: Texture2D = Surface.radial_texture(Color(Palette.EMBER, 0.55))
var _geometry: Dictionary = {}
var _source_icon: Texture2D

func _init() -> void:
	Surface.clear_button_style(self)
	focus_mode = Control.FOCUS_ALL
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if _geometry_cache.is_empty():
		_geometry_cache = JSON.parse_string(FileAccess.get_file_as_string(GEOMETRY_PATH)) as Dictionary
	_geometry = _geometry_cache
	_ring.name = "Ring"
	_ring.texture = Surface.mipmapped_texture(RING_PATH)
	_ring.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_ring.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ring)
	_icon.name = "Icon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = icon_filter
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_update_icon_material()
	add_child(_icon)
	_inner_rings.name = "InnerRings"
	_inner_rings.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_inner_rings)
	_inner_rings.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_inner_rings.draw.connect(_draw_inner_rings)
	_badge.name = "Badge"
	_badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_badge)
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(queue_redraw)
	resized.connect(_layout)
	setup(null)

func _ready() -> void:
	_layout()
	update_minimum_size()

func _gui_input(event: InputEvent) -> void:
	if inspect_only and event.is_action("ui_accept"):
		accept_event()

func _socket_active() -> bool:
	return interactive and not disabled and (is_hovered() or has_focus())

func _socket_dimmed() -> bool:
	return dimmed or disabled

func _update_icon_material() -> void:
	if _icon != null:
		_icon.material = Surface.socket_material(0.35 if _socket_dimmed() else 1.0)

func setup(icon: Texture2D, tooltip: String = "", badge: String = "") -> void:
	_source_icon = icon
	_update_icon_texture()
	tooltip_text = tooltip
	_badge.text = badge
	_badge.visible = not badge.is_empty()
	_layout()
	queue_redraw()

func _update_icon_texture() -> void:
	var pixel_art: bool = icon_filter in [CanvasItem.TEXTURE_FILTER_NEAREST, CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, CanvasItem.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC]
	_icon.texture = _cropped_icon(_source_icon) if pixel_art else _source_icon

static func _cropped_icon(texture: Texture2D) -> Texture2D:
	if texture == null:
		return null
	if not _cropped_icons.has(texture):
		var used: Rect2i = AssetLoader.texture_used_rect(texture)
		var cropped: Texture2D = texture
		if used.has_area() and used != Rect2i(Vector2i.ZERO, Vector2i(texture.get_size())):
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(used)
			cropped = atlas
		_cropped_icons[texture] = cropped
	return _cropped_icons[texture] as Texture2D

func _layout() -> void:
	custom_minimum_size = Vector2.ONE * Typography.scaled_value(self, socket_size)
	var diameter: float = minf(size.x, size.y)
	var rect := Rect2((size - Vector2.ONE * diameter) * 0.5, Vector2.ONE * diameter)
	_ring.position = rect.position
	_ring.size = rect.size
	var center: Vector2 = _ring_center(rect)
	var outer_diameter: float = _ring_radius(rect, "outer_radius") * 2.0
	var opening_ratio: float = float(_geometry["inner_radius"]) / float(_geometry["outer_radius"])
	var icon_size: float = outer_diameter * opening_ratio * 0.92
	_icon.position = center - Vector2.ONE * icon_size * 0.5
	_icon.size = Vector2.ONE * icon_size
	Surface.label_style(_badge, 13, Palette.GOLD_BRIGHT)
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = Palette.INK_2
	badge_style.border_color = Palette.GOLD
	badge_style.set_border_width_all(maxi(1, roundi(Typography.scaled_value(self, 1.0))))
	badge_style.set_corner_radius_all(roundi(Typography.scaled_value(self, 5.0)))
	badge_style.content_margin_left = Typography.scaled_value(self, 5.0)
	badge_style.content_margin_right = Typography.scaled_value(self, 5.0)
	_badge.add_theme_stylebox_override("normal", badge_style)
	_badge.size = _badge.get_minimum_size()
	_badge.position = rect.end - _badge.size
	queue_redraw()

func _ring_center(rect: Rect2) -> Vector2:
	var center: Array = _geometry["center"]
	return rect.position + Vector2(float(center[0]), float(center[1])) * rect.size.x / float(_geometry["size"][0])

func _ring_radius(rect: Rect2, key: String) -> float:
	return float(_geometry[key]) * rect.size.x / float(_geometry["size"][0])

func _draw() -> void:
	var diameter: float = minf(size.x, size.y)
	if diameter <= 0.0:
		return
	var rect := Rect2((size - Vector2.ONE * diameter) * 0.5, Vector2.ONE * diameter)
	var center: Vector2 = _ring_center(rect)
	var radius: float = _ring_radius(rect, "inner_radius")
	var active: bool = _socket_active()
	if active:
		var glow_radius: float = _ring_radius(rect, "outer_radius") + Typography.scaled_value(self, 7.0)
		draw_texture_rect(_glow, Rect2(center - Vector2.ONE * glow_radius, Vector2.ONE * glow_radius * 2.0), false)
	draw_texture_rect(Surface.socket_fill(), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	_ring.modulate = DISABLED_RING_TINT if _socket_dimmed() else (ACTIVE_RING_TINT if active else ring_tint)
	if _icon.texture == null:
		_ring.modulate.a *= 0.45
		for index: int in range(16):
			var start: float = TAU * float(index) / 16.0
			draw_arc(center, radius * 0.88, start, start + TAU / 32.0, 5, Color(Palette.GOLD_DIM, 0.35), Typography.scaled_value(self, 1.0), true)
	_update_icon_material()
	_inner_rings.queue_redraw()

func _draw_inner_rings() -> void:
	var diameter: float = minf(size.x, size.y)
	if diameter <= 0.0:
		return
	var rect := Rect2((size - Vector2.ONE * diameter) * 0.5, Vector2.ONE * diameter)
	var center: Vector2 = _ring_center(rect)
	var radius: float = _ring_radius(rect, "inner_radius") - Typography.scaled_value(self, 1.0)
	var width: float = Typography.scaled_value(self, 2.0)
	# Draw above the icon so a second, inset status ring stays visible.
	if accent_color.a > 0.0:
		_inner_rings.draw_arc(center, maxf(1.0, radius), 0.0, TAU, 64, Color(accent_color, 0.9), width, true)
		radius -= width
	var inner_color: Color = status_color if status_color.a > 0.0 else Palette.GOLD_BRIGHT if selected else Color.TRANSPARENT
	if inner_color.a > 0.0:
		_inner_rings.draw_arc(center, maxf(1.0, radius), 0.0, TAU, 64, inner_color, width, true)
