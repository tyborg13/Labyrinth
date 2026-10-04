extends Button

# setup(card_id, display_name, count = 1, card_override = {}) uses CardWidget's
# art_path. Native pressed handles activation; hovered/unhovered include focus
# for inspection. selected adds an underline; locked also disables activation.
signal hovered(card_id: String)
signal unhovered(card_id: String)

const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")

static var _art_crops: Dictionary = {}

var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var locked: bool = false:
	set(value):
		locked = value
		disabled = value
		queue_redraw()
var card_id: String = ""
var _art := TextureRect.new()
var _name := Label.new()
var _count := Label.new()
var _finish := Control.new()
var _art_material: ShaderMaterial = Surface.texture_material(0.7)
var _inspection_active: bool = false

func _init() -> void:
	Surface.clear_button_style(self)
	focus_mode = Control.FOCUS_ALL
	_art.name = "Art"
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.material = _art_material
	_art.modulate = Color.WHITE
	_name.name = "Name"
	_name.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name.clip_text = true
	_count.name = "Count"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_art)
	add_child(_name)
	add_child(_count)
	_finish.name = "Finish"
	_finish.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_finish.draw.connect(_draw_finish)
	add_child(_finish)
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(_interaction_changed)
	resized.connect(_layout)

func _ready() -> void:
	_layout()
	update_minimum_size()

func setup(id: String, display_name: String, count: int = 1, card_override: Dictionary = {}) -> void:
	if _inspection_active:
		unhovered.emit(card_id)
	card_id = id
	var card: Dictionary = card_override.duplicate(true) if not card_override.is_empty() else GameData.card_def(id)
	_art.texture = _center_band(AssetLoader.load_texture(str(card.get("art_path", ""))))
	_name.text = display_name
	_count.text = "×%d" % count if count > 1 else ""
	_count.visible = count > 1
	_layout()
	update_minimum_size()
	if _inspection_active:
		hovered.emit(card_id)
	queue_redraw()

static func _center_band(source: Texture2D) -> Texture2D:
	if source == null:
		return null
	if not _art_crops.has(source):
		var height: float = minf(source.get_height() * 0.6, source.get_width() * 0.5)
		var crop_size := Vector2(height * 2.0, height)
		var atlas := AtlasTexture.new()
		atlas.atlas = source
		atlas.region = Rect2((source.get_size() - crop_size) * 0.5, crop_size)
		atlas.filter_clip = true
		atlas.set_meta("asset_source_path", source.get_meta("asset_source_path", ""))
		_art_crops[source] = atlas
	return _art_crops[source] as Texture2D

func _layout() -> void:
	Surface.label_style(_name, 15, Palette.TEXT_3 if disabled or locked else Palette.TEXT)
	Surface.label_style(_count, 14, Palette.GOLD_BRIGHT)
	var count_width: float = _count.get_minimum_size().x + Typography.scaled_value(self, 6.0) if _count.visible else 0.0
	custom_minimum_size = Vector2(Typography.scaled_value(self, 86.0) + count_width, Typography.scaled_value(self, 30.0))
	var layout_scale: float = Typography.ui_scale(self)
	_art.position = Vector2.ZERO
	_art.size = Vector2(54.0, 30.0) * layout_scale
	_art_material.set_shader_parameter("content_width", _art.size.x)
	_finish.size = size
	_count.size = Vector2(_count.get_minimum_size().x, size.y)
	_count.position = Vector2(size.x - _count.size.x - 6.0 * layout_scale, 0.0)
	_name.position = Vector2(60.0 * layout_scale, 0.0)
	var name_end: float = _count.position.x if _count.visible else size.x - 6.0 * layout_scale
	_name.size = Vector2(maxf(0.0, name_end - _name.position.x), size.y)
	queue_redraw()

func _interaction_changed() -> void:
	var active: bool = is_hovered() or has_focus(true)
	if active != _inspection_active:
		_inspection_active = active
		if active:
			hovered.emit(card_id)
		else:
			unhovered.emit(card_id)
	queue_redraw()

func _draw() -> void:
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var active: bool = not disabled and (is_hovered() or has_focus(true))
	if active:
		var glow := StyleBoxFlat.new()
		glow.bg_color = Color.TRANSPARENT
		glow.shadow_color = Color(Palette.EMBER, 0.12)
		glow.shadow_size = roundi(Typography.scaled_value(self, 5.0))
		glow.set_corner_radius_all(2)
		draw_style_box(glow, Rect2(Vector2.ZERO, size))
	Surface.draw_plate(self, Rect2(Vector2.ZERO, size), Color(Palette.INK_3, 0.95), Color(Palette.INK_1, 0.92), Typography.scaled_value(self, 2.0), Color(Palette.GOLD_BRIGHT, 0.7) if active else Color(Palette.GOLD, 0.25), true)
	var name_color: Color = Palette.TEXT_3 if disabled or locked else Palette.TEXT
	if _name.get_theme_color("font_color") != name_color:
		_name.add_theme_color_override("font_color", name_color)
	_art_material.set_shader_parameter("saturation", 0.0 if disabled or locked else 1.0)
	_finish.queue_redraw()

func _draw_finish() -> void:
	var active: bool = not disabled and (is_hovered() or has_focus(true))
	var outline := StyleBoxFlat.new()
	outline.bg_color = Color.TRANSPARENT
	outline.border_color = Color(Palette.GOLD_BRIGHT, 0.7) if active else Color(Palette.GOLD, 0.25)
	outline.set_border_width_all(maxi(1, roundi(Typography.scaled_value(self, 1.0))))
	outline.set_corner_radius_all(roundi(Typography.scaled_value(self, 2.0)))
	_finish.draw_style_box(outline, Rect2(Vector2.ZERO, size))
	if selected:
		var height: float = Typography.scaled_value(self, 2.0)
		_finish.draw_rect(Rect2(0.0, size.y - height, size.x, height), Palette.EMBER)
