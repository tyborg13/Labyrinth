extends Control

# dlg-01 presentation only. RunScene owns dialogue, input, reveal and choices.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Frame = preload("res://scripts/ui_gilded_frame.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Seat = preload("res://scripts/hud_seat_scrim.gd")
const Wording = preload("res://scripts/input_wording.gd")
const Data = preload("res://scripts/game_data.gd")
const Paint = preload("res://scripts/dialogue_ink_paint.gd")
const PORTRAIT_CLIP = preload("res://scripts/dialogue_portrait_clip.gdshader")
const PortraitPaint = preload("res://scripts/dialogue_portrait_paint.gd")
const BrushChoice = preload("res://scripts/dialogue_brush_choice.gd")

const WIDTH: float = 1500.0
const LINE_HEIGHT: float = 220.0
const CHOICE_HEIGHT: float = 262.0
# Compatibility alias for RunScene; the director uses one frame for all speakers.
const PORTRAIT_SIZE := Vector2(340.0, 236.0)
const OPEN_SECONDS: float = 0.18
const FRAME_SECONDS: float = 0.20
const BUST_SECONDS: float = 0.26
const BUST_DELAY: float = 0.06
const OPEN_END: float = BUST_DELAY + BUST_SECONDS
const BODY_RIGHT_PADDING: float = 120.0
const WIPE_SECONDS: float = 0.20
const BAND_WIPE_SECONDS: float = 0.24
const CLOSE_SECONDS: float = 0.12
const BOB_PERIOD: float = 1.1
# Director 2026-11-16: two text lines plus choices use the mockup's 262 px band.
const TWO_LINE_CHOICE_HEIGHT: float = 262.0
# Director 2026-11-16: every real action is a primary (ember) brush; only a
# dismissal is the quiet brush. An explicit option.primary still wins.
const DISMISS_ACTIONS: Array[String] = Array(["close"], TYPE_STRING, "", null)

class Cue extends Control:
	var halo: Texture2D = Frame.blurred_disc_texture(Color(Palette.EMBER, 0.35), 28.0, 6.0)
	func _draw() -> void:
		draw_texture_rect(halo, Rect2(-halo.get_size() * 0.5, halo.get_size()), false)
		Frame.draw_solid_diamond(self, Vector2.ZERO, 7.0, Palette.EMBER)

var host: Node
var panel: PanelContainer
var portrait_frame: PanelContainer
var portrait: TextureRect
var speaker_name: Label
var body: RichTextLabel
var footer: HBoxContainer
var hint: Label
var choices: HBoxContainer
var _content: Control
var _band_wipe: Control
var _band: TextureRect
var _band_size := Vector2i.ZERO
var _portrait_clip: ShaderMaterial
var _portrait_center_x: float = 0.0
var _portrait_shadow: TextureRect
var _portrait_rim: TextureRect
var _hood_clip: Control
var _hood_halo: TextureRect
var _wipe: Control
var _brush: TextureRect
var _hint_row: HBoxContainer
var _cue: Control
var _speaker: String = ""
var _open_elapsed: float = OPEN_SECONDS
var _speaker_elapsed: float = WIPE_SECONDS
var _close_elapsed: float = -1.0
var _bob_elapsed: float = 0.0
var _options: bool = false
var _complete: bool = false

func build(owner_scene: Node) -> void:
	host = owner_scene
	name = "DialogueOverlay"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 260
	host.get("ui_root").add_child(self)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	set_meta("cursor_feedback_context_provider", Callable(host, "_dialogue_cursor_feedback_context"))
	gui_input.connect(Callable(host, "_on_dialogue_overlay_gui_input"))
	var scrim := Seat.new()
	scrim.configure_bottom_seat(600.0, 0.62, 1.6, Palette.INK_0)
	add_child(scrim)
	panel = PanelContainer.new()
	panel.name = "DialogueDialog"
	panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	_content = Control.new()
	_content.name = "DialogueContentRow"
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_content)
	_band_wipe = Control.new()
	_band_wipe.name = "DialogueBandWipe"
	_band_wipe.clip_contents = true
	_band_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_band_wipe)
	_band = TextureRect.new()
	_band.name = "DialogueInkBand"
	_band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_band_wipe.add_child(_band)
	_build_portrait()
	_wipe = Control.new()
	_wipe.name = "DialogueNameplateWipe"
	_wipe.clip_contents = true
	_wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_wipe)
	_brush = TextureRect.new()
	_brush.texture = Assets.load_texture("res://assets/art/ui/turn_order_ink/brush_a.png")
	_brush.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_brush.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_brush.modulate = Color(Palette.DIALOGUE_NAME_INK, 0.91)
	_brush.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_wipe.add_child(_brush)
	speaker_name = Label.new()
	speaker_name.name = "DialogueName"
	_style_eyebrow(speaker_name, 20, 3.5, Palette.GOLD_BRIGHT)
	speaker_name.add_theme_color_override("font_outline_color", Palette.TEXT_OUTLINE)
	speaker_name.add_theme_constant_override("outline_size", 6)
	_content.add_child(speaker_name)
	body = RichTextLabel.new()
	body.name = "DialogueText"
	body.bbcode_enabled = true
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.fit_content = true
	body.scroll_active = false
	body.visible_characters = 0
	# BBCode emphasis retains the existing scene theme fonts.
	body.add_theme_font_override("normal_font", Typography.text_font())
	Typography.set_rich_text_size(body, 25)
	body.add_theme_color_override("default_color", Palette.TEXT)
	body.add_theme_constant_override("line_separation", roundi(35.0 - Typography.text_font().get_height(25)))
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(body)
	footer = HBoxContainer.new()
	footer.name = "DialogueFooter"
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(footer)
	_hint_row = HBoxContainer.new()
	_hint_row.name = "DialogueHintRow"
	_hint_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_hint_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	footer.add_child(_hint_row)
	hint = Label.new()
	hint.name = "DialogueHint"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_style_eyebrow(hint, Typography.SIZE_CAPTION, 3.0, Palette.TEXT_2)
	_hint_row.add_child(hint)
	Wording.bind_dialogue(hint)
	_hint_row.get_node("DialogueInputPrompt").alignment = BoxContainer.ALIGNMENT_END
	choices = HBoxContainer.new()
	choices.name = "DialogueChoices"
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choices.alignment = BoxContainer.ALIGNMENT_END
	choices.add_theme_constant_override("separation", 24)
	choices.mouse_filter = Control.MOUSE_FILTER_IGNORE
	choices.visible = false
	footer.add_child(choices)
	_cue = Cue.new()
	_cue.name = "DialogueContinueDiamond"
	_cue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(_cue)
	resized.connect(sync_layout)

func _style_eyebrow(label: Label, font_size: int, spacing: float, color: Color) -> void:
	Typography.apply_spaced_eyebrow(label, font_size, spacing, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _build_portrait() -> void:
	var materials: Dictionary = PortraitPaint.frame()
	_portrait_shadow = _portrait_texture("DialoguePortraitShadow", materials["shadow"])
	_content.add_child(_portrait_shadow)
	portrait_frame = PanelContainer.new()
	portrait_frame.name = "DialoguePortraitFrame"
	portrait_frame.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	portrait_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_content.add_child(portrait_frame)
	portrait_frame.add_child(_portrait_texture("DialoguePortraitFace", materials["face"]))
	_hood_clip = Control.new()
	_hood_clip.name = "DialogueHoodHaloClip"
	_hood_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hood_clip.clip_contents = true
	_content.add_child(_hood_clip)
	_hood_halo = _portrait_texture("DialogueHoodHalo", null)
	_hood_clip.add_child(_hood_halo)
	_portrait_rim = _portrait_texture("DialoguePortraitRim", materials["rim"])
	_content.add_child(_portrait_rim)
	# The bust is a sibling after the rim, never a clipped child of the frame.
	portrait = _portrait_texture("DialoguePortrait", null)
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_portrait_clip = ShaderMaterial.new()
	_portrait_clip.shader = PORTRAIT_CLIP
	portrait.material = _portrait_clip
	_content.add_child(portrait)

func _portrait_texture(node_name: String, texture: Texture2D) -> TextureRect:
	var result := TextureRect.new()
	result.name = node_name
	result.texture = texture
	result.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	result.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func apply_frame(_accent: Color) -> void:
	pass # Compatibility call: the director's v4 frame has fixed authored inks.

func set_portrait(npc_id: String) -> void:
	var definition: Dictionary = Data.npc_def(npc_id) if not npc_id.is_empty() else {}
	var path: String = str(definition.get("art_path", ""))
	var texture: Texture2D = PortraitPaint.source_texture(path) if not path.is_empty() else null
	_portrait_center_x = float((definition.get("portrait_bust", {}) as Dictionary).get("center_x", 0)) * int(definition.get("portrait_scale", 0))
	var painted: Dictionary = PortraitPaint.portrait(definition, texture)
	var has_portrait: bool = not painted.is_empty()
	portrait.texture = painted.get("bust", null)
	_hood_halo.texture = painted.get("halo", null)
	for layer: Control in [portrait_frame, _portrait_shadow, _hood_clip, _portrait_rim, portrait]: layer.visible = has_portrait

func create_choice(option: Dictionary) -> Button:
	var button := BrushChoice.new()
	button.configure(str(option.get("label", "Continue")), bool(option.get("primary", not DISMISS_ACTIONS.has(str(option.get("action", ""))))))
	return button

func open() -> void:
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	modulate.a = 1.0
	_close_elapsed = -1.0
	_open_elapsed = OPEN_END if _reduced_motion() else 0.0
	_speaker = ""
	set_process(true)

func show_speaker(speaker: String) -> void:
	if speaker != _speaker:
		_speaker = speaker
		_speaker_elapsed = WIPE_SECONDS if _reduced_motion() else 0.0
		speaker_name.text = speaker

# Owner 2026-11-16: the line scrolls out once the box has settled (bust landed).
func is_settled() -> bool:
	return _open_elapsed >= OPEN_END

func finish_open() -> void:
	_open_elapsed = OPEN_END
	_speaker_elapsed = WIPE_SECONDS
	sync_layout()

func close() -> void:
	if not visible: return
	# Logical close/input is synchronous; the last painted surface may fade.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _reduced_motion():
		visible = false
		set_process(false)
	else:
		_close_elapsed = 0.0
		set_process(true)

func set_footer(has_options: bool, complete: bool) -> void:
	if complete and not _complete: _bob_elapsed = 0.0
	_options = has_options
	_complete = complete
	_hint_row.visible = not (has_options and complete)
	choices.visible = has_options and complete
	_cue.visible = complete and not has_options and footer.visible
	sync_layout()

func _reduced_motion() -> bool:
	return bool(host.call("_reduced_motion_enabled"))

func _process(delta: float) -> void:
	if not visible: return
	_open_elapsed = minf(OPEN_END, _open_elapsed + delta)
	_speaker_elapsed = minf(WIPE_SECONDS, _speaker_elapsed + delta)
	_bob_elapsed += delta
	if _close_elapsed >= 0.0:
		_close_elapsed += delta
		modulate.a = 1.0 - clampf(_close_elapsed / CLOSE_SECONDS, 0.0, 1.0)
		if _close_elapsed >= CLOSE_SECONDS:
			visible = false
			set_process(false)
	sync_layout()

func sync_layout() -> void:
	if panel == null: return
	_cue.visible = _complete and not _options and footer.visible
	var reduced: bool = _reduced_motion()
	var bust_size: Vector2 = portrait.texture.get_size() if portrait.texture != null else Vector2.ZERO
	var column: float = 456.0 if portrait_frame.visible else 120.0
	var seated: bool = host.get("_opening_boon_flow").seats_dialogue()
	var width: float = panel.size.x if seated else WIDTH
	body.position = Vector2(column, 74.0)
	body.size.x = width - column - BODY_RIGHT_PADDING
	var lines: int = maxi(1, body.get_line_count())
	var show_choices: bool = _options and _complete
	var height: float = (CHOICE_HEIGHT + 35.0 * maxi(0, lines - 2)) if show_choices else LINE_HEIGHT + 35.0 * (lines - 1)
	var band_rise: float = 0.0
	if seated:
		height = panel.size.y
	else:
		panel.custom_minimum_size = Vector2(width, height)
		panel.size = panel.custom_minimum_size
		var open_t: float = 1.0 if reduced else clampf(_open_elapsed / OPEN_SECONDS, 0.0, 1.0)
		band_rise = 16.0 * pow(1.0 - open_t, 3.0)
		panel.position = Vector2(190.0 + (size.x - 1920.0) * 0.5, size.y - 26.0 - height + band_rise)
	var open_alpha: float = 1.0 if reduced else _ease_out(_open_elapsed / OPEN_SECONDS)
	# Content follows the band fade; frame and bust have independent timings.
	panel.modulate.a = 1.0
	for control: Control in [_band_wipe, _wipe, speaker_name, body, footer, _cue]: control.modulate.a = open_alpha
	body.size.y = body.get_content_height()
	var dimensions := Vector2i(roundi(width), roundi(height))
	if dimensions != _band_size:
		_band.texture = Paint.band(dimensions)
		_band_size = dimensions
	_band.position = Vector2.ZERO
	_band.size = _band.texture.get_size()
	_band_wipe.position = Vector2(-4.0, 0.0)
	_band_wipe.size = Vector2(_band.size.x * (1.0 if reduced else _ease_out(_open_elapsed / BAND_WIPE_SECONDS)), _band.size.y)
	var frame_t: float = 1.0 if reduced else _ease_out(_open_elapsed / FRAME_SECONDS)
	var bust_t: float = 1.0 if reduced else _ease_out((_open_elapsed - BUST_DELAY) / BUST_SECONDS)
	portrait_frame.custom_minimum_size = Vector2(PortraitPaint.SIZE)
	portrait_frame.size = Vector2(PortraitPaint.SIZE)
	portrait_frame.position = Vector2(60.0, height - 24.0 - PortraitPaint.SIZE.y + 12.0 * (1.0 - frame_t) - band_rise)
	portrait_frame.modulate.a = frame_t
	_portrait_shadow.position = portrait_frame.position + Vector2(8, 12) - Vector2.ONE * PortraitPaint.SHADOW_PADDING
	_portrait_shadow.size = _portrait_shadow.texture.get_size()
	_portrait_shadow.modulate.a = frame_t
	_portrait_rim.position = portrait_frame.position
	_portrait_rim.size = portrait_frame.size
	_portrait_rim.modulate.a = frame_t
	portrait.position = Vector2(60.0 + PortraitPaint.SIZE.x * 0.5 - _portrait_center_x, height - 24.0 - bust_size.y + 20.0 * (1.0 - bust_t) - band_rise)
	portrait.size = bust_size
	_portrait_clip.set_shader_parameter("frame_window", Vector4(portrait_frame.position.x + 3.0 - portrait.position.x, portrait_frame.position.y - portrait.position.y, portrait_frame.position.x + portrait_frame.size.x - 3.0 - portrait.position.x, portrait_frame.position.y + portrait_frame.size.y - portrait.position.y))
	portrait.modulate.a = bust_t
	var padding: float = PortraitPaint.HALO_PADDING
	_hood_clip.position = Vector2(portrait_frame.position.x - padding, portrait.position.y - padding)
	_hood_clip.size = Vector2(portrait_frame.size.x + padding * 2.0, maxf(0.0, portrait_frame.position.y + 20.0 - _hood_clip.position.y))
	_hood_halo.position = portrait.position - Vector2.ONE * padding - _hood_clip.position
	if _hood_halo.texture != null: _hood_halo.size = _hood_halo.texture.get_size()
	_hood_clip.modulate.a = bust_t
	speaker_name.size = speaker_name.get_minimum_size()
	var font: Font = speaker_name.get_theme_font("font")
	var font_size: int = speaker_name.get_theme_font_size("font_size")
	var baseline: float = (speaker_name.size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	speaker_name.position = Vector2(column, 49.0 - baseline * speaker_name.scale.y)
	_brush.size = Vector2(300.0, 58.0)
	_wipe.position = Vector2(column - 24.0, 12.0)
	_wipe.size = Vector2(300.0 * (1.0 if reduced else clampf(_speaker_elapsed / WIPE_SECONDS, 0.0, 1.0)), 58.0)
	var footer_width: float = maxf(width - column - 120.0, choices.get_combined_minimum_size().x) if show_choices else width - column - 140.0
	footer.position = Vector2(width - 120.0 - footer_width if show_choices else column, height - 92.0 if show_choices else height - 66.0)
	footer.size = Vector2(footer_width, 62.0 if show_choices else 28.0)
	choices.custom_minimum_size.y = 62.0 if show_choices else 0.0
	_cue.position = Vector2(width - 120.0, height - 52.0 + (0.0 if reduced else 3.0 * sin(TAU * _bob_elapsed / BOB_PERIOD)))

func _ease_out(progress: float) -> float:
	return 1.0 - pow(1.0 - clampf(progress, 0.0, 1.0), 3.0)
