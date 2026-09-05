extends PanelContainer
class_name CombatObjectiveHud

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const INTRO_START_SCALE: float = 0.88
const INTRO_POP_SCALE: float = 2.65
const INTRO_VERTICAL_RATIO: float = 0.28
const INTRO_TEXT_SIZE := Vector2(1280.0, 220.0)
const INTRO_KICKER_START_FONT_SIZE: int = 40
const INTRO_KICKER_FONT_SIZE: int = 46
const INTRO_TITLE_START_FONT_SIZE: int = 82
const INTRO_TITLE_FONT_SIZE: int = 92
const INTRO_TEXT_TARGET_SCALE: float = 0.32
const INTRO_KICKER_SHADOW_COLOR := Color(0.008, 0.003, 0.012, 0.68)
const INTRO_TITLE_SHADOW_COLOR := Color(0.008, 0.003, 0.012, 0.78)
const INTRO_POP_SECONDS: float = 0.24
const INTRO_HOLD_SECONDS: float = 0.56
const INTRO_TRAVEL_SECONDS: float = 0.64
const INTRO_REDUCED_HOLD_SECONDS: float = 0.65
const INTRO_SHADOW_FADE_SECONDS: float = 0.22
const INTRO_CHROME_DELAY_SECONDS: float = 0.20
const INTRO_CHROME_FADE_SECONDS: float = 0.26
const INTRO_TEXT_FADE_DELAY_SECONDS: float = 0.36
const INTRO_TEXT_FADE_SECONDS: float = 0.12
const INTRO_CONTENT_DELAY_SECONDS: float = 0.52
const INTRO_CONTENT_FADE_SECONDS: float = 0.12
const PANEL_BACKGROUND_COLOR := Color(0.055, 0.038, 0.062, 0.96)
const PANEL_BORDER_COLOR := Color(0.66, 0.48, 0.27, 0.92)
const PANEL_SHADOW_COLOR := Color(0.0, 0.0, 0.0, 0.58)

var _icon: TextureRect
var _title: Label
var _detail: Label
var _content_row: HBoxContainer
var _intro_text_stack: VBoxContainer
var _intro_kicker: Label
var _intro_title: Label
var _panel_style: StyleBoxFlat
var _presentation_signature: String = ""
var intro_active: bool = false
var intro_phase: String = ""
var intro_chrome_progress: float = 1.0
var intro_content_progress: float = 1.0
var intro_shadow_progress: float = 0.0
var _intro_tween: Tween

func _ready() -> void:
	_build()

func set_combat_state(state: Dictionary) -> bool:
	if _icon == null:
		_build()
	var objective: Dictionary = state.get("objective", {}) as Dictionary
	if objective.is_empty():
		var changed: bool = visible or not _presentation_signature.is_empty()
		visible = false
		_presentation_signature = ""
		return changed
	var objective_type: String = str(objective.get("type", CombatObjectiveRules.KILL_ALL))
	var icon_path: String = CombatObjectiveRules.icon_path(objective_type)
	var title_text: String = CombatObjectiveRules.display_name(objective_type).to_upper()
	var detail_text: String = _live_detail(state, objective)
	var next_tooltip: String = "%s\n%s" % [CombatObjectiveRules.display_name(objective_type), CombatObjectiveRules.description(objective_type)]
	var next_signature: String = "%s|%s|%s|%s" % [icon_path, title_text, detail_text, next_tooltip]
	if visible and next_signature == _presentation_signature:
		return false
	_presentation_signature = next_signature
	visible = true
	_icon.texture = AssetLoader.load_texture(icon_path)
	_title.text = title_text
	_detail.text = detail_text
	_intro_title.text = title_text
	tooltip_text = next_tooltip
	return true

func _build() -> void:
	if _icon != null:
		return
	name = "CombatObjectiveHud"
	custom_minimum_size = Vector2(350.0, 68.0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_HELP
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_BACKGROUND_COLOR
	style.border_color = PANEL_BORDER_COLOR
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = PANEL_SHADOW_COLOR
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	_panel_style = style
	var row := HBoxContainer.new()
	_content_row = row
	row.add_theme_constant_override("separation", 12)
	add_child(row)
	var icon_frame := PanelContainer.new()
	icon_frame.custom_minimum_size = Vector2(50.0, 50.0)
	var icon_style := StyleBoxFlat.new()
	icon_style.bg_color = Color(0.11, 0.075, 0.10, 0.98)
	icon_style.border_color = Color(0.82, 0.62, 0.32, 0.78)
	icon_style.set_border_width_all(1)
	icon_style.set_corner_radius_all(5)
	icon_style.set_content_margin_all(4.0)
	icon_frame.add_theme_stylebox_override("panel", icon_style)
	row.add_child(icon_frame)
	_icon = TextureRect.new()
	_icon.name = "ObjectiveIcon"
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon_frame.add_child(_icon)
	var text_stack := VBoxContainer.new()
	text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	text_stack.add_theme_constant_override("separation", 0)
	row.add_child(text_stack)
	var kicker := Label.new()
	kicker.text = "OBJECTIVE"
	UiTypography.apply_label_role(kicker, UiTypography.ROLE_CAPTION)
	kicker.add_theme_font_size_override("font_size", 11)
	kicker.add_theme_color_override("font_color", Color("b99768"))
	kicker.add_theme_color_override("font_outline_color", Color("160e0c"))
	kicker.add_theme_constant_override("outline_size", 1)
	text_stack.add_child(kicker)
	_title = Label.new()
	_title.name = "ObjectiveTitle"
	_title.clip_text = true
	_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.apply_label_role(_title, UiTypography.ROLE_SECTION)
	_title.add_theme_font_size_override("font_size", 20)
	_title.add_theme_color_override("font_color", Color("f3d59a"))
	_title.add_theme_color_override("font_outline_color", Color("160e0c"))
	_title.add_theme_constant_override("outline_size", 2)
	text_stack.add_child(_title)
	_detail = Label.new()
	_detail.name = "ObjectiveLiveDetail"
	_detail.clip_text = true
	_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UiTypography.apply_label_role(_detail, UiTypography.ROLE_BODY)
	_detail.add_theme_font_size_override("font_size", 13)
	_detail.add_theme_color_override("font_color", Color("c9c4b2"))
	text_stack.add_child(_detail)

	_intro_text_stack = VBoxContainer.new()
	_intro_text_stack.name = "ObjectiveIntroText"
	_intro_text_stack.top_level = true
	_intro_text_stack.z_as_relative = false
	_intro_text_stack.z_index = 61
	_intro_text_stack.custom_minimum_size = INTRO_TEXT_SIZE
	_intro_text_stack.size = INTRO_TEXT_SIZE
	_intro_text_stack.alignment = BoxContainer.ALIGNMENT_CENTER
	_intro_text_stack.add_theme_constant_override("separation", 0)
	_intro_text_stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_intro_text_stack.visible = false
	add_child(_intro_text_stack)
	_intro_kicker = Label.new()
	_intro_kicker.name = "ObjectiveIntroKicker"
	_intro_kicker.text = "OBJECTIVE"
	_intro_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_kicker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_intro_kicker, UiTypography.ROLE_CAPTION)
	_intro_kicker.add_theme_color_override("font_color", Color("d2ad72"))
	_intro_kicker.add_theme_color_override("font_outline_color", Color("12090a"))
	_intro_kicker.add_theme_constant_override("outline_size", 4)
	_intro_kicker.add_theme_constant_override("shadow_offset_x", 3)
	_intro_kicker.add_theme_constant_override("shadow_offset_y", 6)
	_intro_kicker.add_theme_constant_override("shadow_outline_size", 3)
	_intro_text_stack.add_child(_intro_kicker)
	_intro_title = Label.new()
	_intro_title.name = "ObjectiveIntroTitle"
	_intro_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_intro_title.clip_text = true
	_intro_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_intro_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_label_role(_intro_title, UiTypography.ROLE_TITLE)
	_intro_title.add_theme_color_override("font_color", Color("fff0c7"))
	_intro_title.add_theme_color_override("font_outline_color", Color("12090a"))
	_intro_title.add_theme_constant_override("outline_size", 7)
	_intro_title.add_theme_constant_override("shadow_offset_x", 4)
	_intro_title.add_theme_constant_override("shadow_offset_y", 8)
	_intro_title.add_theme_constant_override("shadow_outline_size", 4)
	_intro_text_stack.add_child(_intro_title)
	_set_intro_font_progress(1.0)
	_set_intro_shadow_progress(0.0)

func set_hud_rect(rect: Rect2) -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	offset_left = rect.position.x
	offset_top = rect.position.y
	offset_right = rect.end.x
	offset_bottom = rect.end.y

func prepare_intro(target_rect: Rect2, viewport_size: Vector2) -> bool:
	cancel_intro()
	if not visible or not is_inside_tree():
		return false
	var intro_center := Vector2(
		viewport_size.x * 0.5,
		viewport_size.y * INTRO_VERTICAL_RATIO
	)
	var intro_rect := Rect2(
		intro_center - target_rect.size * 0.5,
		target_rect.size
	)
	intro_active = true
	intro_phase = "prepared"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = target_rect.size * 0.5
	set_hud_rect(intro_rect)
	scale = Vector2.ONE * INTRO_START_SCALE
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	_set_intro_chrome_progress(0.0)
	_set_intro_content_progress(0.0)
	_set_intro_font_progress(0.0)
	_set_intro_shadow_progress(0.0)
	_intro_text_stack.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_intro_text_stack.size = INTRO_TEXT_SIZE
	_intro_text_stack.position = intro_center - INTRO_TEXT_SIZE * 0.5
	_intro_text_stack.pivot_offset = INTRO_TEXT_SIZE * 0.5
	_intro_text_stack.scale = Vector2.ONE
	_intro_text_stack.visible = true
	_intro_text_stack.modulate = Color.TRANSPARENT
	return true

func play_intro(target_rect: Rect2, viewport_size: Vector2, reduced_motion: bool) -> void:
	if not intro_active or intro_phase != "prepared":
		if not prepare_intro(target_rect, viewport_size):
			return

	if reduced_motion:
		scale = Vector2.ONE * INTRO_POP_SCALE
		modulate = Color.WHITE
		_set_intro_font_progress(1.0)
		_set_intro_shadow_progress(1.0)
		_intro_text_stack.scale = Vector2.ONE
		_intro_text_stack.modulate = Color.WHITE
		intro_phase = "reduced_hold"
		await get_tree().create_timer(INTRO_REDUCED_HOLD_SECONDS).timeout
		if not _intro_can_continue():
			return
		_finish_intro(target_rect)
		return

	intro_phase = "appearing"
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(
		self,
		"scale",
		Vector2.ONE * INTRO_POP_SCALE,
		INTRO_POP_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(
		self,
		"modulate:a",
		1.0,
		INTRO_POP_SECONDS * 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_property(
		_intro_text_stack,
		"modulate:a",
		1.0,
		INTRO_POP_SECONDS * 0.72
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(
		_set_intro_font_progress,
		0.0,
		1.0,
		INTRO_POP_SECONDS
	).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(
		_set_intro_shadow_progress,
		0.0,
		1.0,
		INTRO_POP_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _intro_tween.finished
	if not _intro_can_continue():
		return

	intro_phase = "holding"
	await get_tree().create_timer(INTRO_HOLD_SECONDS).timeout
	if not _intro_can_continue():
		return

	intro_phase = "traveling"
	_intro_tween = create_tween().set_parallel(true)
	_intro_tween.tween_property(
		self,
		"position",
		target_rect.position,
		INTRO_TRAVEL_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(
		_intro_text_stack,
		"position",
		target_rect.position + target_rect.size * 0.5 - INTRO_TEXT_SIZE * 0.5,
		INTRO_TRAVEL_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(
		_intro_text_stack,
		"scale",
		Vector2.ONE * INTRO_TEXT_TARGET_SCALE,
		INTRO_TRAVEL_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(
		self,
		"scale",
		Vector2.ONE,
		INTRO_TRAVEL_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_property(
		_intro_text_stack,
		"modulate:a",
		0.0,
		INTRO_TEXT_FADE_SECONDS
	).set_delay(INTRO_TEXT_FADE_DELAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_intro_tween.tween_method(
		_set_intro_shadow_progress,
		1.0,
		0.0,
		INTRO_SHADOW_FADE_SECONDS
	).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_intro_tween.tween_method(
		_set_intro_chrome_progress,
		0.0,
		1.0,
		INTRO_CHROME_FADE_SECONDS
	).set_delay(INTRO_CHROME_DELAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_intro_tween.tween_method(
		_set_intro_content_progress,
		0.0,
		1.0,
		INTRO_CONTENT_FADE_SECONDS
	).set_delay(INTRO_CONTENT_DELAY_SECONDS).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await _intro_tween.finished
	if not _intro_can_continue():
		return
	_finish_intro(target_rect)

func cancel_intro() -> void:
	if _intro_tween != null and _intro_tween.is_valid():
		_intro_tween.kill()
	_intro_tween = null
	intro_active = false
	intro_phase = ""
	z_index = 34
	mouse_filter = Control.MOUSE_FILTER_STOP
	scale = Vector2.ONE
	modulate = Color.WHITE
	_set_intro_chrome_progress(1.0)
	_set_intro_content_progress(1.0)
	_set_intro_shadow_progress(0.0)
	if _intro_text_stack != null:
		_intro_text_stack.visible = false
		_intro_text_stack.modulate = Color.TRANSPARENT
		_intro_text_stack.scale = Vector2.ONE

func _intro_can_continue() -> bool:
	return intro_active and visible and is_inside_tree()

func _set_intro_chrome_progress(progress: float) -> void:
	intro_chrome_progress = clampf(progress, 0.0, 1.0)
	if _panel_style != null:
		_panel_style.bg_color = Color(
			PANEL_BACKGROUND_COLOR.r,
			PANEL_BACKGROUND_COLOR.g,
			PANEL_BACKGROUND_COLOR.b,
			PANEL_BACKGROUND_COLOR.a * intro_chrome_progress
		)
		_panel_style.border_color = Color(
			PANEL_BORDER_COLOR.r,
			PANEL_BORDER_COLOR.g,
			PANEL_BORDER_COLOR.b,
			PANEL_BORDER_COLOR.a * intro_chrome_progress
		)
		_panel_style.shadow_color = Color(
			PANEL_SHADOW_COLOR.r,
			PANEL_SHADOW_COLOR.g,
			PANEL_SHADOW_COLOR.b,
			PANEL_SHADOW_COLOR.a * intro_chrome_progress
		)

func _set_intro_content_progress(progress: float) -> void:
	intro_content_progress = clampf(progress, 0.0, 1.0)
	if _content_row != null:
		_content_row.modulate = Color(1.0, 1.0, 1.0, intro_content_progress)

func _set_intro_font_progress(progress: float) -> void:
	var amount: float = clampf(progress, 0.0, 1.0)
	if _intro_kicker != null:
		_intro_kicker.add_theme_font_size_override(
			"font_size",
			roundi(lerpf(INTRO_KICKER_START_FONT_SIZE, INTRO_KICKER_FONT_SIZE, amount))
		)
	if _intro_title != null:
		_intro_title.add_theme_font_size_override(
			"font_size",
			roundi(lerpf(INTRO_TITLE_START_FONT_SIZE, INTRO_TITLE_FONT_SIZE, amount))
		)

func _set_intro_shadow_progress(progress: float) -> void:
	intro_shadow_progress = clampf(progress, 0.0, 1.0)
	if _intro_kicker != null:
		_intro_kicker.add_theme_color_override(
			"font_shadow_color",
			Color(
				INTRO_KICKER_SHADOW_COLOR.r,
				INTRO_KICKER_SHADOW_COLOR.g,
				INTRO_KICKER_SHADOW_COLOR.b,
				INTRO_KICKER_SHADOW_COLOR.a * intro_shadow_progress
			)
		)
	if _intro_title != null:
		_intro_title.add_theme_color_override(
			"font_shadow_color",
			Color(
				INTRO_TITLE_SHADOW_COLOR.r,
				INTRO_TITLE_SHADOW_COLOR.g,
				INTRO_TITLE_SHADOW_COLOR.b,
				INTRO_TITLE_SHADOW_COLOR.a * intro_shadow_progress
			)
		)

func _finish_intro(target_rect: Rect2) -> void:
	intro_active = false
	intro_phase = "settled"
	_intro_tween = null
	z_index = 34
	mouse_filter = Control.MOUSE_FILTER_STOP
	scale = Vector2.ONE
	modulate = Color.WHITE
	_set_intro_chrome_progress(1.0)
	_set_intro_content_progress(1.0)
	_set_intro_shadow_progress(0.0)
	if _intro_text_stack != null:
		_intro_text_stack.visible = false
		_intro_text_stack.modulate = Color.TRANSPARENT
		_intro_text_stack.scale = Vector2.ONE
	set_hud_rect(target_rect)

func _live_detail(state: Dictionary, objective: Dictionary) -> String:
	var filters_hidden_enemies: bool = state.has("visible_enemy_ids")
	var visible_enemy_ids: Array = state.get("visible_enemy_ids", []) as Array
	match str(objective.get("type", CombatObjectiveRules.KILL_ALL)):
		CombatObjectiveRules.KILL_LEADER:
			var leader_id: int = int(objective.get("leader_id", -1))
			if filters_hidden_enemies and not visible_enemy_ids.has(leader_id):
				return "Leader concealed"
			for enemy_var: Variant in state.get("enemies", []):
				if typeof(enemy_var) != TYPE_DICTIONARY:
					continue
				var enemy: Dictionary = enemy_var
				if int(enemy.get("id", -2)) != leader_id:
					continue
				var enemy_name: String = str(GameData.enemy_def(str(enemy.get("type", ""))).get("name", "Leader"))
				var hp: int = maxi(0, int(enemy.get("hp", 0)))
				return "%s · %d/%d HP" % [enemy_name, hp, int(enemy.get("max_hp", hp))]
			return "The leader has fallen"
		CombatObjectiveRules.SURVIVE:
			var current_clock: int = int(state.get("initiative_clock", 0))
			var target_clock: int = int(objective.get("target_clock", 0))
			var remaining: int = maxi(0, target_clock - current_clock)
			var next_wave: int = int(objective.get("next_reinforcement_clock", target_clock))
			if next_wave < target_clock:
				return "%d time remaining · Reinforcements in %d" % [remaining, maxi(0, next_wave - current_clock)]
			return "%d time remaining · Final wave deployed" % remaining
		CombatObjectiveRules.REACH_EXIT:
			var exit_count: int = CombatObjectiveRules.exit_target_tiles(objective).size()
			return "Reach any of %d marked threshold%s" % [exit_count, "s" if exit_count != 1 else ""]
		_:
			var live_count: int = 0
			for enemy_var: Variant in state.get("enemies", []):
				if typeof(enemy_var) != TYPE_DICTIONARY:
					continue
				var enemy: Dictionary = enemy_var as Dictionary
				if filters_hidden_enemies and not visible_enemy_ids.has(int(enemy.get("id", -1))):
					continue
				if int(enemy.get("hp", 0)) > 0:
					live_count += 1
			if filters_hidden_enemies:
				return "%d known foe%s remaining" % [live_count, "s" if live_count != 1 else ""]
			return "%d enem%s remaining" % [live_count, "ies" if live_count != 1 else "y"]
