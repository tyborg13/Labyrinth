extends "res://scripts/opening_boon_card.gd"

## The boon choice plate and tab are inherited, including their selected finish.
## All geometry below is the approved heirloom brief, in native screen pixels.
const HEIRLOOM_SIZE := Vector2(316.0, 540.0)
const MEDALLION_SIZE: float = 204.0
const ART_SIZE: float = 192.0
const LIFT: float = 14.0
# The mockup specifies a 26px accent glow with alpha aa.
const FOCUS_GLOW_RADIUS: int = 26
const FOCUS_GLOW_ALPHA: float = 170.0 / 255.0
const DIM_BRIGHTNESS: float = 0.72
const Gilding = preload("res://scripts/ui_gilded_frame.gd")
const MEDALLION_CENTER_HEX: int = 0x2c2219ff
const MEDALLION_EDGE_HEX: int = 0x120d0aff
var item_id: String
var medallion: Control
var art: TextureRect
var accent: Color
var emphasized: bool = false
var brightening: float = 0.0

func configure(host: Node, item: Dictionary) -> void:
	_host = host
	item_id = str(item["id"])
	name = "HeirloomCard_" + item_id
	size = HEIRLOOM_SIZE
	custom_minimum_size = HEIRLOOM_SIZE
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	accent = Color.from_string(Data.equipment_accent(item_id), Palette.GOLD)
	_surface = PanelContainer.new()
	_surface.name = "BoonSurface"
	_surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_surface)
	_surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_skin.apply_panel_surface(_surface, UiSkin.SURFACE_CHOICE)
	_tag(Data.equipment_slot(item_id).to_upper())
	var tag: Control = get_node("BoonColumnTag")
	tag.position.x = (HEIRLOOM_SIZE.x - tag.size.x) * 0.5
	var title: Label = label_at(self, "HeirloomTitle", str(Data.equipment_def(item_id)["name"]), Vector2(0.0, 36.0), Vector2(316.0, 0.0), 27, Palette.GOLD_BRIGHT, true)
	medallion = Control.new()
	medallion.name = "HeirloomMedallion"
	medallion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(medallion)
	medallion.position = Vector2(56.0, title.position.y + title.size.y + 16.0)
	medallion.size = Vector2.ONE * MEDALLION_SIZE
	medallion.draw.connect(_draw_medallion)
	art = TextureRect.new()
	art.name = "HeirloomArt"
	art.texture = Assets.load_texture(str(Data.equipment_def(item_id).get("icon_path", "")))
	art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	medallion.add_child(art)
	art.position = Vector2.ONE * 6.0
	art.size = Vector2.ONE * ART_SIZE
	var rarity: Label = label_at(self, "HeirloomRarity", Data.equipment_rarity(item_id).capitalize(), Vector2(0.0, medallion.position.y + MEDALLION_SIZE + 12.0), Vector2(316.0, 0.0), 17, accent)
	var divider := Control.new()
	divider.name = "HeirloomDivider"
	divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(divider)
	divider.position = Vector2(28.0, rarity.position.y + rarity.size.y + 16.0)
	divider.size = Vector2(260.0, 1.0)
	divider.draw.connect(func() -> void: Gilding.draw_rule(divider, Vector2.ZERO, Vector2(260.0, 0.0), Palette.GOLD_DIM, 1.0, false))
	var heading: Label = label_at(self, "HeirloomSpellsHeading", "ITS SPELLS", Vector2(0.0, divider.position.y + 13.0), Vector2(316.0, 0.0), 14, Palette.TEXT_3, true)
	space_eyebrow(heading, 0.24)
	var cards: Array = Data.equipment_cards(item_id, item.get("state", {}))
	for index: int in range(cards.size()): _spell_row(str(cards[index]), heading.position.y + heading.size.y + 10.0 + index * 44.0)
	gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			activated.emit()
	)

static func label_at(parent: Control, node_name: String, text: String, point: Vector2, extent: Vector2, pixels: int, color: Color, ui: bool = false) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", Typography.ui_font() if ui else Typography.text_font())
	Typography.set_label_size(label, pixels)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	label.position = point
	label.size = Vector2(extent.x, maxf(extent.y, label.get_minimum_size().y))
	return label

static func space_eyebrow(label: Label, em: float) -> void:
	var font: FontVariation = Typography.eyebrow_font().duplicate()
	font.spacing_glyph = em * label.get_theme_font_size("font_size")
	label.add_theme_font_override("font", font)

func _spell_row(id: String, top: float) -> void:
	var row := Control.new()
	row.name = "HeirloomSpell_" + id
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(row)
	row.position = Vector2(30.0, top)
	row.size = Vector2(256.0, 36.0)
	var thumbnail := TextureRect.new()
	thumbnail.name = "Thumbnail"
	thumbnail.texture = Assets.load_texture(str(Data.card_def(id).get("art_path", "")))
	thumbnail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	thumbnail.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	thumbnail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(thumbnail)
	thumbnail.size = Vector2(64.0, 36.0)
	row.draw.connect(func() -> void:
		var corners := PackedVector2Array([Vector2.ZERO, Vector2(64.0, 0.0), Vector2(64.0, 36.0), Vector2(0.0, 36.0), Vector2.ZERO])
		row.draw_polyline(corners, Palette.GOLD_DIM, 1.0)
	)
	var label: Label = label_at(row, "SpellName", str(Data.card_def(id).get("name", id)), Vector2(76.0, 0.0), Vector2(180.0, 36.0), 18, Palette.TEXT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.mouse_entered.connect(func() -> void: preview_requested.emit(row, id, "spell"))
	row.mouse_exited.connect(func() -> void: preview_hidden.emit())

func set_emphasis(value: bool, immediate: bool = false) -> void:
	emphasized = value
	_skin.apply_choice_finish(_surface, Palette.GOLD, emphasized)
	medallion.queue_redraw()
	z_index = 20 if emphasized else 0
	var target_y: float = -LIFT if emphasized else 0.0
	if _tween != null: _tween.kill()
	if immediate or Motion.applied_reduced_motion_enabled(): position.y = target_y
	else:
		_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_tween.tween_property(self, "position:y", target_y, REWARD_POSE_SECONDS)

func _draw_medallion() -> void:
	var center: Vector2 = medallion.size * 0.5
	if emphasized:
		for radius: int in range(102 + FOCUS_GLOW_RADIUS, 102, -1):
			medallion.draw_circle(center, float(radius), Color(accent, FOCUS_GLOW_ALPHA / FOCUS_GLOW_RADIUS * (102.0 + FOCUS_GLOW_RADIUS - radius) / FOCUS_GLOW_RADIUS))
	medallion.draw_circle(center, 103.0, Palette.GOLD_DIM)
	medallion.draw_circle(center, 102.0, accent)
	medallion.draw_circle(center, 98.0, Color.hex(MEDALLION_EDGE_HEX))
	for radius: int in range(96, 0, -1):
		var blend: float = clampf((float(radius) / 96.0) / 0.70, 0.0, 1.0)
		medallion.draw_circle(center, float(radius), Color.hex(MEDALLION_CENTER_HEX).lerp(Color.hex(MEDALLION_EDGE_HEX), blend).lerp(Palette.GOLD_BRIGHT, brightening))

# The heirloom view owns focus/hover so there is one emphasized piece at a time.
func _pose() -> void:
	pass

func freeze_pose() -> void:
	if _tween != null: _tween.kill()
