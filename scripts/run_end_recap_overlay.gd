extends Control
class_name RunEndRecapOverlay

const CombatEngine = preload("res://scripts/combat_engine.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const HEADER_FONT = preload("res://fonts/LabyrinthCrumble-Header.tres")
const REGULAR_FONT = preload("res://fonts/LabyrinthCrumble-Regular.tres")

signal new_run_pressed
signal main_menu_pressed

const VICTORY_INTRO_SECONDS: float = 0.62
const DEFEAT_PANEL_DELAY_SECONDS: float = 1.04
const DEFEAT_PANEL_INTRO_SECONDS: float = 0.58
const PANEL_MAX_SIZE: Vector2 = Vector2(710.0, 660.0)
const PANEL_MIN_WIDTH: float = 548.0
const PANEL_EDGE_MARGIN: float = 42.0
const BUTTON_HEIGHT: float = 54.0
const BUTTON_MIN_WIDTH: float = 226.0
const NEW_BEST_COLOR: Color = Color("72c78c")
const STAT_SPECS := [
	{"id": "enemies_killed", "label": "ENEMIES KILLED"},
	{"id": "damage_dealt", "label": "DAMAGE DEALT"},
	{"id": "damage_received", "label": "DAMAGE TAKEN"},
	{"id": "depth", "label": "DEPTH"},
	{"id": "rooms_cleared", "label": "ROOMS CLEARED"},
	{"id": "bosses_defeated", "label": "BOSSES"}
]

var _ui_skin: UiSkin = UiSkin.new()
var _model: Dictionary = {}
var _model_fingerprint: String = ""
var _motion_enabled: bool = true
var _elapsed: float = 0.0

var _death_shroud: DeathEngulfOverlay
var _panel: PanelContainer
var _kicker_label: Label
var _title_label: Label
var _summary_label: Label
var _accent_rule: ColorRect
var _stat_value_labels: Dictionary = {}
var _stat_best_labels: Dictionary = {}
var _ember_label: Label
var _ember_value: Label
var _recovery_value: Label
var _new_run_button: Button
var _main_menu_button: Button

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_build_children()

static func result_stats(run_state: Dictionary) -> Dictionary:
	var rooms: Dictionary = run_state.get("rooms", {}) as Dictionary
	var current_coord: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = {}
	var current_key: String = "%d,%d" % [current_coord.x, current_coord.y]
	if rooms.has(current_key) and typeof(rooms[current_key]) == TYPE_DICTIONARY:
		current_room = rooms[current_key] as Dictionary
	var rooms_cleared: int = 0
	var bosses_defeated: int = 0
	for room_var: Variant in rooms.values():
		if typeof(room_var) != TYPE_DICTIONARY:
			continue
		var room: Dictionary = room_var as Dictionary
		if not bool(room.get("cleared", false)) or int(room.get("depth", 0)) <= 0:
			continue
		rooms_cleared += 1
		if str(room.get("type", "")) == "boss":
			bosses_defeated += 1
	var combat_stats: Dictionary = CombatEngine.normalized_run_stats(run_state.get("run_stats", {}))
	return {
		"enemies_killed": int(combat_stats.get("enemies_killed", 0)),
		"damage_dealt": int(combat_stats.get("damage_dealt", 0)),
		"damage_received": int(combat_stats.get("damage_received", 0)),
		"depth": maxi(0, int(current_room.get("depth", _coord_depth(current_coord)))),
		"rooms_cleared": rooms_cleared,
		"bosses_defeated": bosses_defeated
	}

static func build_model(run_state: Dictionary, progression: Dictionary, outcome: String, ember_amount: int) -> Dictionary:
	var normalized_outcome: String = "victory" if outcome == "victory" else "defeat"
	var stats: Dictionary = result_stats(run_state)
	var boss_result: String
	if normalized_outcome == "victory":
		boss_result = "Final boss defeated"
	elif int(stats.get("bosses_defeated", 0)) > 0:
		var boss_count: int = int(stats.get("bosses_defeated", 0))
		boss_result = "%d guardian%s defeated" % [boss_count, "" if boss_count == 1 else "s"]
	else:
		boss_result = "Final boss not reached"

	var marker: Dictionary = ProgressionStore.recovery_marker(progression)
	var recovery_status: String
	if marker.is_empty():
		if normalized_outcome == "defeat":
			recovery_status = "No marker · no embers left behind" if ember_amount <= 0 else "No recovery marker created"
		else:
			recovery_status = "No recovery marker active"
	else:
		var marker_coord: Vector2i = ProgressionStore.recovery_coord(progression)
		var marker_depth: int = _coord_depth(marker_coord)
		var marker_amount: int = int(marker.get("amount", 0))
		var next_progression: Dictionary = ProgressionStore.prepare_for_new_run(progression)
		var next_marker: Dictionary = ProgressionStore.recovery_marker(next_progression)
		if next_marker.is_empty():
			recovery_status = "Marker expires · %d embers unrecovered" % marker_amount
		else:
			var marker_verb: String = "set" if normalized_outcome == "defeat" and marker_amount == maxi(0, ember_amount) else "active"
			recovery_status = "Recovery marker %s · Depth %d · %d embers" % [marker_verb, marker_depth, marker_amount]

	var run_result: Dictionary = run_state.get("run_result", {}) as Dictionary
	var new_bests: Array[String] = []
	for stat_id_var: Variant in run_result.get("new_bests", []):
		var stat_id: String = str(stat_id_var)
		if ProgressionStore.BEST_ELIGIBLE_STAT_IDS.has(stat_id) and not new_bests.has(stat_id):
			new_bests.append(stat_id)
	return {
		"outcome": normalized_outcome,
		"kicker": "THE LABYRINTH YIELDS" if normalized_outcome == "victory" else "THE UMBRA CLOSES IN",
		"title": "ASCENT COMPLETE" if normalized_outcome == "victory" else "RUN ENDED",
		"summary": "The ascent is complete. Carried embers are secure." if normalized_outcome == "victory" else "The room remains. The Umbra waits.",
		"stats": stats,
		"new_bests": new_bests,
		"depth": int(stats.get("depth", 0)),
		"rooms_cleared": int(stats.get("rooms_cleared", 0)),
		"bosses_defeated": int(stats.get("bosses_defeated", 0)),
		"boss_result": boss_result,
		"ember_label": "EMBERS BANKED" if normalized_outcome == "victory" else "EMBERS LOST",
		"ember_amount": maxi(0, ember_amount),
		"recovery_status": recovery_status
	}

static func _coord_depth(coord: Vector2i) -> int:
	return maxi(abs(coord.x), abs(coord.y))

func present(model: Dictionary) -> void:
	var next_model: Dictionary = model.duplicate(true)
	var fingerprint: String = JSON.stringify(next_model)
	var restart_motion: bool = not visible or fingerprint != _model_fingerprint
	_model = next_model
	_model_fingerprint = fingerprint
	_apply_model()
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	if restart_motion:
		_elapsed = 0.0 if _motion_enabled else _presentation_duration()
		if _is_victory():
			_death_shroud.reset()
		else:
			_death_shroud.set_motion_enabled(_motion_enabled)
			_death_shroud.play()
	set_process(_motion_enabled and _elapsed < _presentation_duration())
	_update_presentation()

func reset() -> void:
	_model.clear()
	_model_fingerprint = ""
	_elapsed = 0.0
	visible = false
	set_process(false)
	if _death_shroud != null:
		_death_shroud.reset()
	queue_redraw()

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if _death_shroud != null:
		_death_shroud.set_motion_enabled(enabled)
	if visible and not _motion_enabled:
		_elapsed = _presentation_duration()
		set_process(false)
		if not _is_victory():
			_death_shroud.seek_seconds(DeathEngulfOverlay.ENGULF_SECONDS)
		_update_presentation()

func motion_enabled() -> bool:
	return _motion_enabled

func seek_presentation(seconds: float) -> void:
	_elapsed = clampf(seconds, 0.0, _presentation_duration())
	if not _is_victory() and _death_shroud != null:
		_death_shroud.seek_seconds(minf(_elapsed, DeathEngulfOverlay.ENGULF_SECONDS))
	set_process(_motion_enabled and _elapsed < _presentation_duration())
	_update_presentation()

func presentation_duration() -> float:
	return _presentation_duration()

func recap_model() -> Dictionary:
	return _model.duplicate(true)

func shroud_progress() -> float:
	return _death_shroud.engulf_progress() if _death_shroud != null and _death_shroud.visible else 0.0

func final_shroud_alpha() -> float:
	return DeathEngulfOverlay.FINAL_SHROUD_ALPHA

func has_decorative_edge_strokes() -> bool:
	return _death_shroud.has_decorative_edge_strokes() if _death_shroud != null else false

func sample_shroud_alpha(normalized_position: Vector2, progress_override: float = -1.0) -> float:
	return _death_shroud.sample_alpha(normalized_position, progress_override) if _death_shroud != null else 0.0

func _process(delta: float) -> void:
	_elapsed = minf(_presentation_duration(), _elapsed + minf(delta, 1.0 / 30.0))
	if _elapsed >= _presentation_duration():
		set_process(false)
	_update_presentation()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and visible and _panel != null:
		_update_presentation()

func _draw() -> void:
	if not visible or _model.is_empty() or not _is_victory():
		return
	var progress: float = _intro_progress()
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.035, 0.025, 0.018, 0.24 * progress), true)

func _build_children() -> void:
	_death_shroud = DeathEngulfOverlay.new()
	_death_shroud.name = "DeathShroud"
	_death_shroud.set_anchors_preset(Control.PRESET_FULL_RECT)
	_death_shroud.anchor_right = 1.0
	_death_shroud.anchor_bottom = 1.0
	add_child(_death_shroud)

	_panel = PanelContainer.new()
	_panel.name = "OutcomeRecap"
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	_panel.add_child(margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)

	_kicker_label = _label("OutcomeKicker", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(_kicker_label)

	_title_label = _label("OutcomeTitle", 44, HORIZONTAL_ALIGNMENT_LEFT)
	_title_label.add_theme_font_override("font", HEADER_FONT)
	_title_label.add_theme_constant_override("outline_size", 5)
	content.add_child(_title_label)

	_accent_rule = ColorRect.new()
	_accent_rule.name = "OutcomeAccentRule"
	_accent_rule.custom_minimum_size = Vector2(0.0, 3.0)
	_accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_accent_rule)

	_summary_label = _label("OutcomeSummary", UiTypography.SIZE_BODY_LARGE, HORIZONTAL_ALIGNMENT_LEFT)
	_summary_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_summary_label.custom_minimum_size = Vector2(420.0, 38.0)
	content.add_child(_summary_label)

	var stat_grid := GridContainer.new()
	stat_grid.name = "RunStatGrid"
	stat_grid.columns = 3
	stat_grid.custom_minimum_size = Vector2(0.0, 184.0)
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(stat_grid)
	for spec_var: Variant in STAT_SPECS:
		_add_stat_metric(stat_grid, spec_var as Dictionary)

	var ember_panel := PanelContainer.new()
	ember_panel.name = "EmberResult"
	ember_panel.custom_minimum_size = Vector2(0.0, 94.0)
	content.add_child(ember_panel)
	var ember_margin := MarginContainer.new()
	ember_margin.add_theme_constant_override("margin_left", 16)
	ember_margin.add_theme_constant_override("margin_top", 9)
	ember_margin.add_theme_constant_override("margin_right", 16)
	ember_margin.add_theme_constant_override("margin_bottom", 9)
	ember_panel.add_child(ember_margin)
	var ember_row := HBoxContainer.new()
	ember_row.add_theme_constant_override("separation", 14)
	ember_margin.add_child(ember_row)
	var amount_box := VBoxContainer.new()
	amount_box.custom_minimum_size = Vector2(178.0, 0.0)
	amount_box.add_theme_constant_override("separation", 1)
	ember_row.add_child(amount_box)
	_ember_label = _label("EmberLabel", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	amount_box.add_child(_ember_label)
	_ember_value = _label("EmberValue", UiTypography.SIZE_HERO, HORIZONTAL_ALIGNMENT_LEFT)
	_ember_value.add_theme_font_override("font", HEADER_FONT)
	amount_box.add_child(_ember_value)
	var recovery_box := VBoxContainer.new()
	recovery_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	recovery_box.alignment = BoxContainer.ALIGNMENT_CENTER
	ember_row.add_child(recovery_box)
	var recovery_heading := _label("RecoveryHeading", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	recovery_heading.text = "NEXT RUN"
	recovery_box.add_child(recovery_heading)
	_recovery_value = _label("RecoveryValue", UiTypography.SIZE_BODY, HORIZONTAL_ALIGNMENT_LEFT)
	_recovery_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_recovery_value.custom_minimum_size = Vector2(240.0, 38.0)
	recovery_box.add_child(_recovery_value)

	var button_row := HBoxContainer.new()
	button_row.name = "OutcomeActions"
	button_row.alignment = BoxContainer.ALIGNMENT_CENTER
	button_row.add_theme_constant_override("separation", 14)
	content.add_child(button_row)
	_new_run_button = _button("NewRunButton", "New Run")
	_new_run_button.pressed.connect(func() -> void: new_run_pressed.emit())
	button_row.add_child(_new_run_button)
	_main_menu_button = _button("MainMenuButton", "Main Menu")
	_main_menu_button.pressed.connect(func() -> void: main_menu_pressed.emit())
	button_row.add_child(_main_menu_button)

func _add_stat_metric(host: GridContainer, spec: Dictionary) -> void:
	var stat_id: String = str(spec.get("id", ""))
	var panel := PanelContainer.new()
	panel.name = "%sMetric" % stat_id.to_pascal_case()
	panel.custom_minimum_size = Vector2(156.0, 88.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _inset_style(Color("6e5946"), Color(0.035, 0.030, 0.028, 0.86)))
	host.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 11)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 11)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 0)
	margin.add_child(box)
	var heading := _label("%sHeading" % stat_id.to_pascal_case(), UiTypography.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	heading.text = str(spec.get("label", stat_id.to_upper()))
	box.add_child(heading)
	var value := _label("%sValue" % stat_id.to_pascal_case(), 30, HORIZONTAL_ALIGNMENT_LEFT)
	value.add_theme_font_override("font", HEADER_FONT)
	value.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(value)
	var best := _label("%sBest" % stat_id.to_pascal_case(), UiTypography.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	best.text = "NEW BEST"
	best.custom_minimum_size = Vector2(0.0, 15.0)
	best.add_theme_color_override("font_color", NEW_BEST_COLOR)
	best.add_theme_color_override("font_outline_color", Color("102217"))
	best.add_theme_constant_override("outline_size", 2)
	box.add_child(best)
	_stat_value_labels[stat_id] = value
	_stat_best_labels[stat_id] = best

func _label(node_name: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", REGULAR_FONT)
	UiTypography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", Color("f2e8d2"))
	label.add_theme_color_override("font_outline_color", Color("160f0c"))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_font_override("font", REGULAR_FONT)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_LARGE)
	_ui_skin.apply_button_text_overrides(button)
	UiTypography.set_button_size(button, UiTypography.SIZE_SECTION)
	_ui_skin.apply_button_native_size(button, BUTTON_HEIGHT, BUTTON_MIN_WIDTH, true, UiSkin.VARIANT_LARGE)
	return button

func _apply_model() -> void:
	if _panel == null or _model.is_empty():
		return
	var victory: bool = _is_victory()
	var accent: Color = _accent_color()
	_kicker_label.text = str(_model.get("kicker", ""))
	_title_label.text = str(_model.get("title", ""))
	_summary_label.text = str(_model.get("summary", ""))
	var stats: Dictionary = _model.get("stats", {}) as Dictionary
	var new_bests: Array = _model.get("new_bests", []) as Array
	for stat_id_var: Variant in _stat_value_labels.keys():
		var stat_id: String = str(stat_id_var)
		var value_label: Label = _stat_value_labels.get(stat_id) as Label
		var best_label: Label = _stat_best_labels.get(stat_id) as Label
		if value_label != null:
			value_label.text = str(int(stats.get(stat_id, 0)))
		if best_label != null:
			best_label.visible = new_bests.has(stat_id)
	_ember_label.text = str(_model.get("ember_label", ""))
	_ember_value.text = str(int(_model.get("ember_amount", 0)))
	_recovery_value.text = str(_model.get("recovery_status", ""))
	_panel.add_theme_stylebox_override("panel", _panel_style(victory, accent))
	_accent_rule.color = accent
	_kicker_label.add_theme_color_override("font_color", accent.lightened(0.20))
	_title_label.add_theme_color_override("font_color", Color("fff1c8") if victory else Color("ffd8cf"))
	_title_label.add_theme_color_override("font_outline_color", Color("28170b") if victory else Color("250609"))
	_ember_label.add_theme_color_override("font_color", accent.lightened(0.22))
	_ember_value.add_theme_color_override("font_color", Color("ffd27a") if victory else Color("f3987d"))
	_recovery_value.add_theme_color_override("font_color", Color("e7d7b7") if victory else Color("efc2b6"))
	var ember_panel: PanelContainer = _panel.find_child("EmberResult", true, false) as PanelContainer
	if ember_panel != null:
		ember_panel.add_theme_stylebox_override("panel", _inset_style(accent, Color(accent.r * 0.12, accent.g * 0.10, accent.b * 0.08, 0.92)))

func _panel_style(victory: bool, accent: Color) -> StyleBoxFlat:
	var background: Color = Color(0.075, 0.052, 0.035, 0.965) if victory else Color(0.055, 0.030, 0.034, 0.95)
	var style := _ui_skin.make_plain_card_style(background, accent, 0.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 12
	style.corner_radius_top_right = 12
	style.corner_radius_bottom_right = 12
	style.corner_radius_bottom_left = 12
	style.shadow_color = Color(0.0, 0.0, 0.0, 0.58)
	style.shadow_size = 22
	style.shadow_offset = Vector2(0.0, 8.0)
	return style

func _inset_style(border: Color, background: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = Color(border.r, border.g, border.b, 0.62)
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	return style

func _accent_color() -> Color:
	return Color("e7b85a") if _is_victory() else Color("bd4b43")

func _is_victory() -> bool:
	return str(_model.get("outcome", "defeat")) == "victory"

func _presentation_duration() -> float:
	return VICTORY_INTRO_SECONDS if _is_victory() else maxf(DeathEngulfOverlay.ENGULF_SECONDS, DEFEAT_PANEL_DELAY_SECONDS + DEFEAT_PANEL_INTRO_SECONDS)

func _intro_progress() -> float:
	if not _motion_enabled:
		return 1.0
	var start: float = 0.0 if _is_victory() else DEFEAT_PANEL_DELAY_SECONDS
	var duration: float = VICTORY_INTRO_SECONDS if _is_victory() else DEFEAT_PANEL_INTRO_SECONDS
	var t: float = clampf((_elapsed - start) / duration, 0.0, 1.0)
	return 1.0 - pow(1.0 - t, 3.0)

func _update_presentation() -> void:
	if _panel == null or not visible:
		return
	var progress: float = _intro_progress()
	var content_minimum: Vector2 = _panel.get_combined_minimum_size()
	var width: float = clampf(size.x * 0.41, PANEL_MIN_WIDTH, PANEL_MAX_SIZE.x)
	width = maxf(width, content_minimum.x)
	width = minf(width, maxf(320.0, size.x - 32.0))
	var available_height: float = maxf(320.0, size.y - 20.0)
	var desired_height: float = maxf(480.0, ceilf(content_minimum.y) + 4.0)
	var height: float = minf(desired_height, minf(PANEL_MAX_SIZE.y, available_height))
	var edge_margin: float = minf(PANEL_EDGE_MARGIN, maxf(16.0, size.x * 0.035))
	var base_x: float = size.x - width - edge_margin
	if base_x < 16.0:
		base_x = (size.x - width) * 0.5
	var base_y: float = (size.y - height) * 0.5
	var slide: float = (1.0 - progress) * 46.0
	_panel.position = Vector2(base_x + slide, base_y)
	_panel.size = Vector2(width, height)
	_panel.pivot_offset = _panel.size * 0.5
	var beat: float = sin(clampf(_elapsed / _presentation_duration(), 0.0, 1.0) * PI) * 0.010 if _motion_enabled else 0.0
	_panel.scale = Vector2.ONE * (0.985 + 0.015 * progress + beat)
	_panel.modulate = Color(1.0, 1.0, 1.0, progress)
	queue_redraw()
