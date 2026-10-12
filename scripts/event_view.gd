extends Control
class_name EventView

const Events = preload("res://scripts/event_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Text = preload("res://scripts/event_view_text.gd")
const Choice = preload("res://scripts/event_view_choice.gd")
const Gilding = preload("res://scripts/ui_gilded_frame.gd")
const Rule = preload("res://scripts/ui_gilded_rule.gd")
const Router = preload("res://scripts/input_router.gd")
const Sounds = preload("res://scripts/run_sfx_library.gd")

signal choice_requested(choice_id: String)
signal interaction_changed
signal closed

const REFERENCE_SIZE: Vector2 = Vector2(1920, 1080)
const PANEL_RECT: Rect2 = Rect2(140, 150, 1640, 780)
const ART_RECT: Rect2 = Rect2(26, 26, 1062, 728)
const COLUMN_ORIGIN: Vector2 = Vector2(1060, 52)
const COLUMN_WIDTH: float = 540
const COLUMN_BOTTOM: float = 754
const CHOICE_GAP: float = 14
const CONTINUE_HEIGHT: float = 78 # CSS min-height 52 + 13 px vertical padding twice.
const OUTCOME_ROW_FADE_SECONDS: float = 0.18
const PAINTING_FADE_SECONDS: float = 0.22
const SCRIM_SHADER: String = """
shader_type canvas_item;
uniform sampler2D screen_texture : hint_screen_texture, filter_linear;
void fragment() {
 vec2 d = SCREEN_PIXEL_SIZE * 2.0;
 vec3 board = (texture(screen_texture, SCREEN_UV).rgb * 4.0
  + texture(screen_texture, SCREEN_UV + vec2(d.x,0)).rgb
  + texture(screen_texture, SCREEN_UV - vec2(d.x,0)).rgb
  + texture(screen_texture, SCREEN_UV + vec2(0,d.y)).rgb
  + texture(screen_texture, SCREEN_UV - vec2(0,d.y)).rgb) / 8.0;
 board = mix(vec3(dot(board,vec3(0.2126,0.7152,0.0722))), board, 0.7) * 0.35;
 float edge = clamp(length((UV-0.5)*2.0)/0.75,0.0,1.0);
 vec3 ink = mix(vec3(8,6,5)/255.0,vec3(4,3,2)/255.0,edge);
 COLOR = vec4(mix(board,ink,mix(0.35,0.86,edge)), COLOR.a);
}
"""
const ART_SHADER: String = """
shader_type canvas_item;
uniform float zoom = 1.0;
uniform vec2 rect_size = vec2(1062.0,728.0);
varying vec2 mask_uv;
varying vec4 painting_tint;
// Fragment COLOR already includes TEXTURE. Capture the untextured modulation
// in vertex(), so the painting is sampled once rather than RGB being squared.
void vertex() { mask_uv = VERTEX / rect_size; painting_tint = COLOR; }
void fragment() {
 vec4 paint = texture(TEXTURE,(UV-0.5)/zoom+0.5);
 float mask = clamp((1.0-mask_uv.x)/0.18,0.0,1.0)
  * clamp(mask_uv.y/0.07,0.0,1.0) * clamp((1.0-mask_uv.y)/0.10,0.0,1.0);
 COLOR = vec4(paint.rgb,paint.a*mask) * painting_tint;
}
"""

var run_state: Dictionary = {}
var reduced_motion: bool = false
var page: String = "choices"
var panel: PanelContainer
var art: TextureRect
var column: Control
var choices: Array[Button]
var outcome_rows: Array[RichTextLabel]
var continue_button: Button
var body_size: int = 22
var effect_size: int = 19
var fit_errors: Array[String]
var _canvas: Control
var _scrim: ColorRect
var _skin := UiSkin.new()
var _signature: int = 0
var _focused_index: int = 0
var _old_column: Control
var _transition: Tween
var _opening: Tween
var _painting: Tween
var _zoom: Tween
var _closing: bool = false
var _busy: bool = false
var _request_pending: bool = false
var _art_started: bool = false
var _content_bottom: float = 0
var _sound: Callable
var _built: bool = false
var _stick_direction: int = 0

func _ready() -> void:
	_build()
	hide()
	resized.connect(_layout_canvas)

func _shader(code: String) -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = code
	var result := ShaderMaterial.new()
	result.shader = shader
	return result

func _build() -> void:
	if _built: return
	_built = true
	name = "EventView"
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_as_relative = false
	z_index = 1200
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim = ColorRect.new()
	_scrim.name = "EventScrim"
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.material = _shader(SCRIM_SHADER)
	add_child(_scrim)
	_canvas = Control.new()
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.size = REFERENCE_SIZE
	add_child(_canvas)
	panel = PanelContainer.new()
	panel.name = "IllustratedEventPanel"
	panel.position = PANEL_RECT.position
	panel.size = PANEL_RECT.size
	panel.set_meta("panel_safe_inset", 0)
	_canvas.add_child(panel)
	_skin.apply_panel_surface(panel)
	# Shared major-dialog material, with the CSS' bold outer brackets.
	panel.draw.connect(func() -> void: Gilding.draw_corner_brackets(panel, Rect2(Vector2.ZERO, panel.size), Palette.GOLD, 46, 4, -3))
	var content := Control.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(content)
	art = TextureRect.new()
	art.name = "EventPainting"
	art.position = ART_RECT.position
	art.size = ART_RECT.size
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.material = _shader(ART_SHADER)
	content.add_child(art)
	column = Control.new()
	column.name = "EventRightColumn"
	column.position = COLUMN_ORIGIN
	column.size = Vector2(548, COLUMN_BOTTOM - COLUMN_ORIGIN.y)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(column)
	_layout_canvas()

func _layout_canvas() -> void:
	if _canvas == null: return
	var factor: float = minf(size.x / REFERENCE_SIZE.x, size.y / REFERENCE_SIZE.y)
	_canvas.scale = Vector2.ONE * factor
	_canvas.position = (size - REFERENCE_SIZE * factor) * 0.5

func present(state: Dictionary, motion_reduced: bool = false, sound: Callable = Callable()) -> void:
	_build()
	var signature: int = hash([state.get("event_state", {}), state.get("player_hp"), state.get("player_max_hp"), state.get("held_embers"), state.get("unbanked_embers"), state.get("equipped_equipment"), state.get("item_inventory"), state.get("equipped_items"), state.get("attuned_magic_cards"), state.get("rooms")])
	set_reduced_motion(motion_reduced)
	if visible and not _closing and signature == _signature:
		release_request()
		return
	release_request()
	_signature = signature
	_sound = sound
	var already_open: bool = visible and not _closing
	run_state = state.duplicate(true)
	_closing = false
	show()
	move_to_front()
	if already_open:
		if _transition != null: _transition.kill()
		_clear_old_column()
		_old_column = column
		column = Control.new()
		column.name = "EventRightColumn"
		column.position = COLUMN_ORIGIN
		column.size = Vector2(548, COLUMN_BOTTOM - COLUMN_ORIGIN.y)
		column.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_old_column.get_parent().add_child(column)
		_rebuild()
		_busy = true
		column.modulate.a = 0
		_stagger_outcomes()
		_transition = create_tween().set_parallel(true)
		_transition.tween_property(_old_column, "modulate:a", 0.0, 0.18)
		_transition.tween_property(column, "modulate:a", 1.0, 0.18)
		_transition.chain().tween_callback(func() -> void: _busy = false; _clear_old_column())
	else:
		if _transition != null: _transition.kill()
		_rebuild()
		_play(Sounds.MENU_OPEN_ID)
		_open_animation()

func _rebuild() -> void:
	page = str(run_state.get("event_state", {}).get("page", "choices"))
	art.texture = Assets.load_texture(Events.art_path(Events.current_id(run_state)))
	body_size = 22
	effect_size = 19
	_build_column()
	if _content_bottom > COLUMN_BOTTOM:
		body_size = 20
		_build_column()
	if _content_bottom > COLUMN_BOTTOM:
		effect_size = 18
		_build_column()
	fit_errors.clear()
	if _content_bottom > COLUMN_BOTTOM:
		fit_errors.append("%s/%s content ends at %.1f > %.1f" % [Events.current_id(run_state), page, _content_bottom, COLUMN_BOTTOM])
	focus_initial()
	interaction_changed.emit()

func _build_column() -> void:
	for child: Node in column.get_children():
		column.remove_child(child)
		child.queue_free()
	choices.clear()
	outcome_rows.clear()
	continue_button = null
	var definition: Dictionary = Data.event_def(Events.current_id(run_state))
	var brow := Label.new()
	brow.text = "EVENT"
	var eyebrow := FontVariation.new()
	eyebrow.base_font = Typography.ui_font()
	eyebrow.spacing_glyph = 5
	brow.add_theme_font_override("font", eyebrow)
	brow.add_theme_font_size_override("font_size", 15)
	brow.add_theme_color_override("font_color", Palette.GOLD_DIM)
	column.add_child(brow)
	var title := Label.new()
	title.name = "EventTitle"
	title.text = str(definition.get("title", ""))
	title.add_theme_font_override("font", Typography.ui_font())
	var title_size: int = 44
	while title_size > 34 and Typography.ui_font().get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, title_size).x > COLUMN_WIDTH: title_size -= 2
	title.add_theme_font_size_override("font_size", title_size)
	title.add_theme_color_override("font_color", Palette.GOLD_BRIGHT)
	title.position.y = brow.get_minimum_size().y + 6
	column.add_child(title)
	var rule := Rule.new()
	rule.position = Vector2(0, title.position.y + title.get_minimum_size().y + 14)
	rule.size = Vector2(COLUMN_WIDTH, 14)
	rule.span_ratio = 1.0
	column.add_child(rule)
	var result: bool = page == "result"
	var body_text: String = str(run_state.get("event_state", {}).get("result_text", "")) if result else str(definition.get("body", ""))
	var body: RichTextLabel = Text.label(body_text, COLUMN_WIDTH, body_size, Color("d8c9a8") if result else Palette.TEXT, result, false, 1.42)
	body.name = "EventBody"
	body.position.y = rule.position.y + 14 + 18
	column.add_child(body)
	var y: float = body.position.y + Text.height(body) + (30 if result else 32)
	if result:
		if not Events.outcome_lines(run_state).is_empty():
			var well := PanelContainer.new()
			well.name = "OutcomeWell"
			well.set_meta("panel_safe_inset", 0)
			well.position.y = y
			well.size.x = COLUMN_WIDTH
			column.add_child(well)
			_skin.apply_panel_surface(well, UiSkin.SURFACE_CHOICE)
			var rows := Control.new()
			rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
			well.add_child(rows)
			var row_y: float = 13
			for line: String in Events.outcome_lines(run_state):
				var row: RichTextLabel = Text.label(line, COLUMN_WIDTH - 36, effect_size, Palette.TEXT_2, false, true)
				rows.add_child(row)
				row.position = Vector2(18, row_y)
				row_y += Text.height(row) + 4
				outcome_rows.append(row)
			well.size.y = row_y + 9
			y += well.size.y
		continue_button = Button.new()
		continue_button.name = "EventContinue"
		continue_button.text = "Continue"
		_skin.apply_button_native_size(continue_button, int(CONTINUE_HEIGHT), 548, false, UiSkin.VARIANT_SELECTED)
		_skin.apply_button_stylebox_overrides(continue_button, UiSkin.VARIANT_SELECTED)
		_skin.apply_button_text_overrides(continue_button)
		Typography.apply_button_role(continue_button, Typography.ROLE_SECTION)
		continue_button.add_theme_font_size_override("font_size", 24)
		column.add_child(continue_button)
		continue_button.size = Vector2(548, CONTINUE_HEIGHT)
		continue_button.position.y = PANEL_RECT.size.y - 40 - CONTINUE_HEIGHT - COLUMN_ORIGIN.y
		continue_button.pressed.connect(activate_continue)
		continue_button.focus_entered.connect(interaction_changed.emit)
		_content_bottom = maxf(y + COLUMN_ORIGIN.y, continue_button.position.y + COLUMN_ORIGIN.y + CONTINUE_HEIGHT)
		if y + 14 > continue_button.position.y: _content_bottom = COLUMN_BOTTOM + 1
	else:
		var index: int = 0
		for choice_def: Dictionary in definition.get("choices", []):
			var button := Choice.new()
			column.add_child(button)
			button.configure(index, choice_def, Events.choice_effect_lines(run_state, Events.current_id(run_state), str(choice_def["id"])), Events.choice_block_reason(run_state, Events.current_id(run_state), str(choice_def["id"])), effect_size)
			button.position.y = y
			y += button.size.y + CHOICE_GAP
			button.pressed.connect(activate_choice.bind(index, true))
			button.focus_entered.connect(func() -> void:
				_focused_index = choices.find(button)
				interaction_changed.emit())
			choices.append(button)
			index += 1
		for focus_index: int in range(choices.size()):
			var button: Button = choices[focus_index]
			button.focus_neighbor_top = button.get_path_to(choices[posmod(focus_index - 1, choices.size())])
			button.focus_neighbor_bottom = button.get_path_to(choices[(focus_index + 1) % choices.size()])
			button.focus_next = button.focus_neighbor_bottom
			button.focus_previous = button.focus_neighbor_top
		_content_bottom = y - CHOICE_GAP + COLUMN_ORIGIN.y

func focus_initial() -> void:
	if page == "result":
		continue_button.grab_focus()
		return
	for button: Button in choices:
		if button.available:
			button.grab_focus()
			return
	if not choices.is_empty(): choices[0].grab_focus()

func focused_choice_index() -> int:
	for index: int in range(choices.size()):
		if choices[index].has_focus(): return index
	return -1

func controller_action_label() -> String:
	if page == "result": return "Continue"
	var index: int = focused_choice_index()
	return choices[index].choice_label if index >= 0 else ""

func move_focus(direction: int) -> void:
	if page == "result" or choices.is_empty(): return
	choices[posmod(focused_choice_index() + direction, choices.size())].grab_focus()

func activate_choice(index: int, pointer: bool = false) -> void:
	if _busy or _request_pending or _closing or page != "choices" or index < 0 or index >= choices.size(): return
	if not choices[index].available: return
	_request_pending = true
	if not pointer:
		var feedback: Node = get_node_or_null("/root/CursorFeedback")
		if feedback != null: feedback.call("play_action_confirmation")
	choice_requested.emit(choices[index].choice_id)

func activate_continue() -> void:
	if _busy or _request_pending or _closing or page != "result": return
	_request_pending = true
	_play(Sounds.MENU_CLOSE_ID)
	choice_requested.emit("continue")

func release_request() -> void:
	_request_pending = false

func restore_choice_focus() -> void:
	if page == "result" and continue_button != null: continue_button.grab_focus()
	elif not choices.is_empty(): choices[maxi(0, _focused_index)].grab_focus()

func handle_input(event: InputEvent) -> bool:
	if not visible: return false
	if (event is InputEventKey and event.keycode == KEY_ESCAPE) or event.is_action(Router.ACTION_MENU): return false
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null: router.call("record_input_activity", event)
	if event is InputEventJoypadMotion:
		if event.axis == JOY_AXIS_LEFT_Y:
			var direction: int = int(signf(event.axis_value)) if absf(event.axis_value) >= Router.JOYSTICK_ACTIVITY_THRESHOLD else 0
			if direction != 0 and direction != _stick_direction: move_focus(direction)
			_stick_direction = direction
		return true
	if not event.is_pressed() or event.is_echo(): return not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag)
	if event is InputEventKey and not (event.alt_pressed or event.ctrl_pressed or event.meta_pressed):
		if event.keycode >= KEY_1 and event.keycode <= KEY_3: activate_choice(event.keycode - KEY_1); return true
		if event.keycode == KEY_UP: move_focus(-1); return true
		if event.keycode == KEY_DOWN: move_focus(1); return true
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER: _activate_focused(); return true
	if event.is_action_pressed("ui_up"): move_focus(-1); return true
	if event.is_action_pressed("ui_down"): move_focus(1); return true
	if event.is_action_pressed(Router.ACTION_ACCEPT) or event.is_action_pressed("ui_accept"): _activate_focused(); return true
	if event.is_action_pressed(Router.ACTION_CANCEL) or event.is_action_pressed("ui_cancel"): activate_continue(); return true
	return not (event is InputEventMouse or event is InputEventScreenTouch or event is InputEventScreenDrag)

func _activate_focused() -> void:
	if page == "result": activate_continue()
	else: activate_choice(focused_choice_index())

func _play(id: String) -> void:
	if _sound.is_valid(): _sound.call(Sounds.entry(id))

func _open_animation() -> void:
	if _opening != null: _opening.kill()
	if _painting != null: _painting.kill()
	if _zoom != null: _zoom.kill()
	_busy = true
	_art_started = false
	art.modulate.a = 0
	_scrim.modulate.a = 0
	panel.modulate.a = 0
	column.modulate.a = 1
	panel.position = PANEL_RECT.position + Vector2(0, 0 if reduced_motion else 12)
	_set_zoom(1.0 if reduced_motion else 1.04)
	_opening = create_tween().set_parallel(true)
	_opening.tween_property(_scrim, "modulate:a", 1.0, 0.18)
	_opening.tween_method(_panel_progress, 0.0, 1.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_opening.chain().tween_callback(func() -> void: _busy = false)

func _panel_progress(value: float) -> void:
	panel.modulate.a = value
	panel.position.y = PANEL_RECT.position.y + (0 if reduced_motion else 12 * (1 - value))
	if value >= 0.8 and not _art_started:
		_art_started = true
		if _painting != null: _painting.kill()
		_painting = create_tween()
		_painting.tween_property(art, "modulate:a", 1.0, PAINTING_FADE_SECONDS)
		if not reduced_motion:
			if _zoom != null: _zoom.kill()
			_zoom = create_tween()
			_zoom.tween_method(_set_zoom, 1.04, 1.0, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func set_reduced_motion(enabled: bool) -> void:
	reduced_motion = enabled
	if not enabled or not _built: return
	# A settings change may arrive during a rise/settle or with an unchanged
	# event signature. Stop spatial motion immediately, preserving opacity fades.
	if _zoom != null: _zoom.kill()
	panel.position = PANEL_RECT.position
	_set_zoom(1.0)

func _set_zoom(value: float) -> void:
	(art.material as ShaderMaterial).set_shader_parameter("zoom", value)

func _stagger_outcomes() -> void:
	for index: int in range(outcome_rows.size()):
		var row: RichTextLabel = outcome_rows[index]
		row.modulate.a = 0
		create_tween().tween_property(row, "modulate:a", 1.0, OUTCOME_ROW_FADE_SECONDS).set_delay(index * 0.08)

func dismiss() -> void:
	if not visible or _closing: return
	release_request()
	_closing = true
	_busy = true
	if _opening != null: _opening.kill()
	if _painting != null: _painting.kill()
	if _zoom != null: _zoom.kill()
	if _transition != null: _transition.kill()
	_clear_old_column()
	_transition = create_tween().set_parallel(true)
	_transition.tween_property(panel, "modulate:a", 0.0, 0.16)
	_transition.tween_property(_scrim, "modulate:a", 0.0, 0.16)
	_transition.chain().tween_callback(func() -> void: hide(); _closing = false; _busy = false; closed.emit())

# Headless fit proof uses the live font shaper and exact live controls.
func fit_report() -> Array[String]:
	var report: Array[String] = fit_errors.duplicate()
	for child: Node in column.get_children():
		if child is RichTextLabel:
			var label: RichTextLabel = child as RichTextLabel
			if label.get_content_height() > label.size.y + 1: report.append("Clipped body")
		if child is Label and child.name == "EventTitle":
			var title: Label = child as Label
			if title.get_minimum_size().x > COLUMN_WIDTH: report.append("Overflowing title: " + title.text)
	for button: Button in choices:
		if Typography.ui_font().get_string_size(button.choice_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x > 472: report.append("Overflowing choice label: " + button.choice_label)
		for row: RichTextLabel in button.rows:
			if row.get_content_height() > row.size.y + 1: report.append("Clipped choice row: " + str(row.get_meta("event_source_text")))
	for row: RichTextLabel in outcome_rows:
		if row.get_content_height() > row.size.y + 1: report.append("Clipped outcome row")
	return report

func finish_animation_for_test() -> void:
	if _opening != null: _opening.kill()
	if _painting != null: _painting.kill()
	if _zoom != null: _zoom.kill()
	if _transition != null: _transition.kill()
	_clear_old_column()
	_rebuild()
	_busy = false
	panel.modulate.a = 1
	panel.position = PANEL_RECT.position
	_scrim.modulate.a = 1
	art.modulate.a = 1
	column.modulate.a = 1
	_set_zoom(1)

func _clear_old_column() -> void:
	if is_instance_valid(_old_column):
		_old_column.get_parent().remove_child(_old_column)
		_old_column.queue_free()
	_old_column = null
