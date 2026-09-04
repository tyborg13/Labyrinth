extends PanelContainer
class_name CombatObjectiveHud

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const GameData = preload("res://scripts/game_data.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const INTRO_START_SCALE: float = 0.82
const INTRO_POP_SCALE: float = 1.90
const INTRO_REDUCED_SCALE: float = 1.32
const INTRO_POP_SECONDS: float = 0.24
const INTRO_HOLD_SECONDS: float = 0.56
const INTRO_TRAVEL_SECONDS: float = 0.56
const INTRO_REDUCED_HOLD_SECONDS: float = 0.65

var _icon: TextureRect
var _title: Label
var _detail: Label
var _presentation_signature: String = ""
var intro_active: bool = false
var intro_phase: String = ""
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
	style.bg_color = Color(0.055, 0.038, 0.062, 0.96)
	style.border_color = Color(0.66, 0.48, 0.27, 0.92)
	style.set_border_width_all(2)
	style.set_corner_radius_all(7)
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0.0, 3.0)
	style.content_margin_left = 12.0
	style.content_margin_top = 8.0
	style.content_margin_right = 16.0
	style.content_margin_bottom = 8.0
	add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
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
	var center_rect := Rect2(
		(viewport_size - target_rect.size) * 0.5,
		target_rect.size
	)
	intro_active = true
	intro_phase = "prepared"
	z_index = 60
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	pivot_offset = target_rect.size * 0.5
	set_hud_rect(center_rect)
	scale = Vector2.ONE * INTRO_START_SCALE
	modulate = Color(1.0, 1.0, 1.0, 0.0)
	return true

func play_intro(target_rect: Rect2, viewport_size: Vector2, reduced_motion: bool) -> void:
	if not intro_active or intro_phase != "prepared":
		if not prepare_intro(target_rect, viewport_size):
			return

	if reduced_motion:
		scale = Vector2.ONE * INTRO_REDUCED_SCALE
		modulate = Color.WHITE
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
		self,
		"scale",
		Vector2.ONE,
		INTRO_TRAVEL_SECONDS
	).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
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

func _intro_can_continue() -> bool:
	return intro_active and visible and is_inside_tree()

func _finish_intro(target_rect: Rect2) -> void:
	intro_active = false
	intro_phase = "settled"
	_intro_tween = null
	z_index = 34
	mouse_filter = Control.MOUSE_FILTER_STOP
	scale = Vector2.ONE
	modulate = Color.WHITE
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
