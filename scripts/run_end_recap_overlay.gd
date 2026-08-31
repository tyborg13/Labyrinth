extends Control
class_name RunEndRecapOverlay

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const DISPLAY_FONT = preload("res://fonts/LabyrinthCrumble-Display.tres")
const UI_FONT = preload("res://fonts/LabyrinthCrumble-UI.tres")
const TEXT_FONT = preload("res://fonts/LabyrinthCrumble-Text.tres")

signal new_run_pressed
signal main_menu_pressed

const VICTORY_INTRO_SECONDS: float = 0.62
const DEFEAT_PANEL_DELAY_SECONDS: float = 1.18
const DEFEAT_PANEL_INTRO_SECONDS: float = 0.62
const PANEL_MAX_SIZE: Vector2 = Vector2(710.0, 620.0)
const PANEL_MIN_WIDTH: float = 548.0
const PANEL_EDGE_MARGIN: float = 42.0
const BUTTON_HEIGHT: float = 64.0
const BUTTON_MIN_WIDTH: float = 314.0
const NEW_BEST_COLOR: Color = Color("72c78c")
const DEFEAT_KICKER_COLOR: Color = Color("b98cff")
const DEFEAT_VALUE_COLOR: Color = Color("f1dcc3")
const LAST_LIGHT_TITLE_PATH: String = "res://assets/art/ui/run_end_last_light_title.png"
const EMBER_ICON_PATH: String = "res://assets/art/icons/ember.png"
const TITLE_KEY_SHADER_CODE: String = """
shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	float luminance = dot(source.rgb, vec3(0.2126, 0.7152, 0.0722));
	float alpha = smoothstep(0.035, 0.20, 1.0 - luminance);
	vec3 cooled = mix(source.rgb * vec3(0.78, 0.80, 0.86), source.rgb, 0.68);
	COLOR = vec4(cooled, alpha);
}
"""
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
var _death_site_normalized: Vector2 = Vector2(0.32, 0.62)

var _death_shroud: DeathEngulfOverlay
var _victory_panel: PanelContainer
var _victory_kicker: Label
var _victory_title: Label
var _victory_summary: Label
var _victory_accent_rule: ColorRect
var _victory_stat_values: Dictionary = {}
var _victory_stat_bests: Dictionary = {}
var _victory_ember_label: Label
var _victory_ember_value: Label
var _victory_recovery_value: Label

var _defeat_layout: Control
var _defeat_kicker: Label
var _defeat_title_raster: TextureRect
var _defeat_accessibility_title: Label
var _defeat_metrics: VBoxContainer
var _defeat_stat_values: Dictionary = {}
var _defeat_stat_bests: Dictionary = {}
var _defeat_ember_value: Label
var _defeat_recovery_value: Label
var _defeat_ember_result: Control

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
		"summary": "The ascent is complete. Carried embers are secure." if normalized_outcome == "victory" else "",
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

func present(model: Dictionary, death_site_normalized: Vector2 = Vector2(0.32, 0.62)) -> void:
	var next_model: Dictionary = model.duplicate(true)
	var normalized_site := Vector2(clampf(death_site_normalized.x, 0.08, 0.92), clampf(death_site_normalized.y, 0.10, 0.90))
	var fingerprint: String = "%s|%.4f|%.4f" % [JSON.stringify(next_model), normalized_site.x, normalized_site.y]
	var restart_motion: bool = not visible or fingerprint != _model_fingerprint
	_model = next_model
	_model_fingerprint = fingerprint
	_death_site_normalized = normalized_site
	_death_shroud.set_death_site_normalized(_death_site_normalized)
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
	call_deferred("_focus_primary_action")

func set_death_site_normalized(normalized_position: Vector2) -> void:
	_death_site_normalized = Vector2(
		clampf(normalized_position.x, 0.08, 0.92),
		clampf(normalized_position.y, 0.10, 0.90)
	)
	if _death_shroud != null:
		_death_shroud.set_death_site_normalized(_death_site_normalized)

func reset() -> void:
	_model.clear()
	_model_fingerprint = ""
	_elapsed = 0.0
	visible = false
	set_process(false)
	if _death_shroud != null:
		_death_shroud.reset()

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

func death_site_normalized() -> Vector2:
	return _death_site_normalized

func death_site_ember_position() -> Vector2:
	return _death_shroud.ember_position() if _death_shroud != null else Vector2.ZERO

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
	if what == NOTIFICATION_RESIZED and visible:
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

	_build_victory_panel()
	_build_defeat_layout()
	_build_shared_actions()

func _build_victory_panel() -> void:
	_victory_panel = PanelContainer.new()
	_victory_panel.name = "OutcomeRecap"
	_victory_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_victory_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 30)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_right", 30)
	margin.add_theme_constant_override("margin_bottom", 22)
	_victory_panel.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 9)
	margin.add_child(content)
	_victory_kicker = _label("VictoryOutcomeKicker", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	content.add_child(_victory_kicker)
	_victory_title = _label("VictoryOutcomeTitle", 44, HORIZONTAL_ALIGNMENT_LEFT)
	_victory_title.add_theme_font_override("font", DISPLAY_FONT)
	_victory_title.add_theme_constant_override("outline_size", 5)
	UiTypography.apply_stone_text(_victory_title, 0.13, 4.0)
	content.add_child(_victory_title)
	_victory_accent_rule = ColorRect.new()
	_victory_accent_rule.custom_minimum_size = Vector2(0.0, 3.0)
	_victory_accent_rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_victory_accent_rule)
	_victory_summary = _label("VictoryOutcomeSummary", UiTypography.SIZE_BODY_LARGE, HORIZONTAL_ALIGNMENT_LEFT)
	_victory_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_summary.custom_minimum_size = Vector2(420.0, 38.0)
	content.add_child(_victory_summary)
	var stat_grid := GridContainer.new()
	stat_grid.name = "VictoryRunStatGrid"
	stat_grid.columns = 3
	stat_grid.custom_minimum_size = Vector2(0.0, 184.0)
	stat_grid.add_theme_constant_override("h_separation", 8)
	stat_grid.add_theme_constant_override("v_separation", 8)
	content.add_child(stat_grid)
	for spec_var: Variant in STAT_SPECS:
		_add_victory_stat_metric(stat_grid, spec_var as Dictionary)
	var ember_panel := PanelContainer.new()
	ember_panel.name = "VictoryEmberResult"
	ember_panel.custom_minimum_size = Vector2(0.0, 94.0)
	content.add_child(ember_panel)
	var ember_margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		ember_margin.add_theme_constant_override("margin_%s" % side, 16)
	ember_margin.add_theme_constant_override("margin_top", 9)
	ember_margin.add_theme_constant_override("margin_bottom", 9)
	ember_panel.add_child(ember_margin)
	var ember_row := HBoxContainer.new()
	ember_row.add_theme_constant_override("separation", 14)
	ember_margin.add_child(ember_row)
	var amount_box := VBoxContainer.new()
	amount_box.custom_minimum_size = Vector2(178.0, 0.0)
	ember_row.add_child(amount_box)
	_victory_ember_label = _label("VictoryEmberLabel", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	amount_box.add_child(_victory_ember_label)
	_victory_ember_value = _label("VictoryEmberValue", UiTypography.SIZE_HERO, HORIZONTAL_ALIGNMENT_LEFT)
	_victory_ember_value.add_theme_font_override("font", UI_FONT)
	amount_box.add_child(_victory_ember_value)
	var recovery_box := VBoxContainer.new()
	recovery_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ember_row.add_child(recovery_box)
	var recovery_heading := _label("VictoryRecoveryHeading", UiTypography.SIZE_SMALL, HORIZONTAL_ALIGNMENT_LEFT)
	recovery_heading.text = "NEXT RUN"
	recovery_box.add_child(recovery_heading)
	_victory_recovery_value = _label("VictoryRecoveryValue", UiTypography.SIZE_BODY, HORIZONTAL_ALIGNMENT_LEFT)
	_victory_recovery_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_victory_recovery_value.custom_minimum_size = Vector2(240.0, 38.0)
	recovery_box.add_child(_victory_recovery_value)

func _build_defeat_layout() -> void:
	_defeat_layout = Control.new()
	_defeat_layout.name = "LastLightRecap"
	_defeat_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_defeat_layout)

	_defeat_kicker = _label("OutcomeKicker", 22, HORIZONTAL_ALIGNMENT_LEFT)
	_defeat_kicker.add_theme_font_override("font", UI_FONT)
	_defeat_kicker.add_theme_color_override("font_color", DEFEAT_KICKER_COLOR)
	_defeat_kicker.add_theme_color_override("font_outline_color", Color("140d20"))
	_defeat_kicker.add_theme_constant_override("outline_size", 3)
	_defeat_layout.add_child(_defeat_kicker)

	_defeat_title_raster = TextureRect.new()
	_defeat_title_raster.name = "DefeatTitleRaster"
	_defeat_title_raster.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_title_raster.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_defeat_title_raster.texture = AssetLoader.load_texture_source_first(LAST_LIGHT_TITLE_PATH)
	_defeat_title_raster.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_defeat_title_raster.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_defeat_title_raster.material = _title_key_material()
	_defeat_layout.add_child(_defeat_title_raster)

	_defeat_accessibility_title = _label("OutcomeTitle", 18, HORIZONTAL_ALIGNMENT_LEFT)
	_defeat_accessibility_title.modulate = Color(1.0, 1.0, 1.0, 0.0)
	_defeat_accessibility_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_defeat_layout.add_child(_defeat_accessibility_title)

	_defeat_metrics = VBoxContainer.new()
	_defeat_metrics.name = "DefeatStatLedger"
	_defeat_metrics.add_theme_constant_override("separation", 3)
	_defeat_layout.add_child(_defeat_metrics)
	for spec_var: Variant in STAT_SPECS:
		_add_defeat_stat_metric(_defeat_metrics, spec_var as Dictionary)

	_defeat_ember_result = Control.new()
	_defeat_ember_result.name = "EmberResult"
	_defeat_layout.add_child(_defeat_ember_result)
	var ember_icon := TextureRect.new()
	ember_icon.name = "LostEmberRaster"
	ember_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ember_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ember_icon.texture = AssetLoader.load_texture_source_first(EMBER_ICON_PATH)
	ember_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ember_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ember_icon.position = Vector2(0.0, 9.0)
	ember_icon.size = Vector2(44.0, 44.0)
	_defeat_ember_result.add_child(ember_icon)
	var ember_heading := _label("EmberLabel", 15, HORIZONTAL_ALIGNMENT_LEFT)
	ember_heading.text = "EMBERS LOST"
	ember_heading.position = Vector2(54.0, 1.0)
	ember_heading.size = Vector2(230.0, 25.0)
	ember_heading.add_theme_color_override("font_color", Color("d19879"))
	_defeat_ember_result.add_child(ember_heading)
	_defeat_ember_value = _label("EmberValue", 36, HORIZONTAL_ALIGNMENT_LEFT)
	_defeat_ember_value.add_theme_font_override("font", UI_FONT)
	_defeat_ember_value.position = Vector2(53.0, 22.0)
	_defeat_ember_value.size = Vector2(240.0, 48.0)
	_defeat_ember_value.add_theme_color_override("font_color", Color("ff9a63"))
	_defeat_ember_result.add_child(_defeat_ember_value)

	_defeat_recovery_value = _label("RecoveryValue", 17, HORIZONTAL_ALIGNMENT_LEFT)
	_defeat_recovery_value.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_defeat_recovery_value.add_theme_color_override("font_color", Color("d9c8e3"))
	_defeat_layout.add_child(_defeat_recovery_value)

func _build_shared_actions() -> void:
	_new_run_button = _button("NewRunButton", "New Run")
	_new_run_button.pressed.connect(func() -> void: new_run_pressed.emit())
	add_child(_new_run_button)
	_main_menu_button = _button("MainMenuButton", "Main Menu")
	_main_menu_button.pressed.connect(func() -> void: main_menu_pressed.emit())
	add_child(_main_menu_button)
	_new_run_button.focus_neighbor_bottom = _main_menu_button.get_path()
	_main_menu_button.focus_neighbor_top = _new_run_button.get_path()
	for button: Button in [_new_run_button, _main_menu_button]:
		button.mouse_entered.connect(_select_action.bind(button))
		button.focus_entered.connect(_select_action.bind(button))
	_new_run_button.set_meta("umbra_selected", true)

func _add_victory_stat_metric(host: GridContainer, spec: Dictionary) -> void:
	var stat_id: String = str(spec.get("id", ""))
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(156.0, 88.0)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _inset_style(Color("6e5946"), Color(0.035, 0.030, 0.028, 0.86)))
	host.add_child(panel)
	var margin := MarginContainer.new()
	for side: String in ["left", "right"]:
		margin.add_theme_constant_override("margin_%s" % side, 11)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	margin.add_child(box)
	var heading := _label("Victory%sHeading" % stat_id.to_pascal_case(), UiTypography.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	heading.text = str(spec.get("label", stat_id.to_upper()))
	box.add_child(heading)
	var value := _label("Victory%sValue" % stat_id.to_pascal_case(), 30, HORIZONTAL_ALIGNMENT_LEFT)
	value.add_theme_font_override("font", UI_FONT)
	box.add_child(value)
	var best := _label("Victory%sBest" % stat_id.to_pascal_case(), UiTypography.SIZE_CAPTION, HORIZONTAL_ALIGNMENT_LEFT)
	best.text = "NEW BEST"
	best.add_theme_color_override("font_color", NEW_BEST_COLOR)
	box.add_child(best)
	_victory_stat_values[stat_id] = value
	_victory_stat_bests[stat_id] = best

func _add_defeat_stat_metric(host: VBoxContainer, spec: Dictionary) -> void:
	var stat_id: String = str(spec.get("id", ""))
	var row := Control.new()
	row.name = "%sMetric" % stat_id.to_pascal_case()
	row.custom_minimum_size = Vector2(520.0, 62.0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(row)
	var heading := _label("%sHeading" % stat_id.to_pascal_case(), 17, HORIZONTAL_ALIGNMENT_RIGHT)
	heading.text = str(spec.get("label", stat_id.to_upper()))
	heading.position = Vector2(0.0, 13.0)
	heading.size = Vector2(174.0, 36.0)
	heading.add_theme_color_override("font_color", Color("c6ac90"))
	row.add_child(heading)
	var value := _label("%sValue" % stat_id.to_pascal_case(), 34, HORIZONTAL_ALIGNMENT_CENTER)
	value.add_theme_font_override("font", UI_FONT)
	value.position = Vector2(184.0, 6.0)
	value.size = Vector2(86.0, 50.0)
	value.add_theme_color_override("font_color", DEFEAT_VALUE_COLOR)
	row.add_child(value)
	var best := _label("%sBest" % stat_id.to_pascal_case(), 14, HORIZONTAL_ALIGNMENT_LEFT)
	best.text = "NEW BEST"
	best.position = Vector2(286.0, 16.0)
	best.size = Vector2(126.0, 32.0)
	best.add_theme_color_override("font_color", NEW_BEST_COLOR)
	best.add_theme_color_override("font_outline_color", Color("102217"))
	best.add_theme_constant_override("outline_size", 2)
	row.add_child(best)
	_defeat_stat_values[stat_id] = value
	_defeat_stat_bests[stat_id] = best

func _title_key_material() -> ShaderMaterial:
	var shader := Shader.new()
	shader.code = TITLE_KEY_SHADER_CODE
	var material := ShaderMaterial.new()
	material.shader = shader
	return material

func _label(node_name: String, font_size: int, alignment: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.name = node_name
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", TEXT_FONT)
	UiTypography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", Color("f2e8d2"))
	label.add_theme_color_override("font_outline_color", Color("160f0c"))
	label.add_theme_constant_override("outline_size", 1)
	return label

func _button(node_name: String, button_text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = button_text
	button.focus_mode = Control.FOCUS_ALL
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_override("font", UI_FONT)
	_ui_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_UMBRA)
	_ui_skin.apply_button_text_overrides(button, Color("f3e5c5"), Color("080606"), Color("8d806b"), 5)
	UiTypography.set_button_size(button, 20)
	_ui_skin.apply_button_native_size(button, BUTTON_HEIGHT, BUTTON_MIN_WIDTH, false, UiSkin.VARIANT_UMBRA)
	return button

func _select_action(button: Button) -> void:
	if button == null:
		return
	_new_run_button.set_meta("umbra_selected", button == _new_run_button)
	_main_menu_button.set_meta("umbra_selected", button == _main_menu_button)
	_new_run_button.queue_redraw()
	_main_menu_button.queue_redraw()

func _focus_primary_action() -> void:
	if not visible or _new_run_button == null:
		return
	_select_action(_new_run_button)
	_new_run_button.grab_focus()

func _apply_model() -> void:
	if _model.is_empty():
		return
	var victory: bool = _is_victory()
	var stats: Dictionary = _model.get("stats", {}) as Dictionary
	var new_bests: Array = _model.get("new_bests", []) as Array
	_victory_panel.visible = victory
	_defeat_layout.visible = not victory
	_victory_kicker.text = str(_model.get("kicker", ""))
	_victory_title.text = str(_model.get("title", ""))
	_victory_summary.text = str(_model.get("summary", ""))
	_victory_ember_label.text = str(_model.get("ember_label", ""))
	_victory_ember_value.text = str(int(_model.get("ember_amount", 0)))
	_victory_recovery_value.text = str(_model.get("recovery_status", ""))
	_defeat_kicker.text = str(_model.get("kicker", ""))
	_defeat_accessibility_title.text = str(_model.get("title", ""))
	_defeat_layout.tooltip_text = "%s — %s" % [_defeat_accessibility_title.text, _defeat_kicker.text]
	_defeat_ember_value.text = str(int(_model.get("ember_amount", 0)))
	_defeat_recovery_value.text = str(_model.get("recovery_status", ""))
	for stat_id_var: Variant in _victory_stat_values.keys():
		var stat_id: String = str(stat_id_var)
		(_victory_stat_values.get(stat_id) as Label).text = str(int(stats.get(stat_id, 0)))
		(_victory_stat_bests.get(stat_id) as Label).visible = new_bests.has(stat_id)
	for stat_id_var: Variant in _defeat_stat_values.keys():
		var stat_id: String = str(stat_id_var)
		(_defeat_stat_values.get(stat_id) as Label).text = str(int(stats.get(stat_id, 0)))
		(_defeat_stat_bests.get(stat_id) as Label).visible = new_bests.has(stat_id)
	var accent := Color("e7b85a")
	_victory_panel.add_theme_stylebox_override("panel", _panel_style(accent))
	_victory_accent_rule.color = accent
	_victory_kicker.add_theme_color_override("font_color", accent.lightened(0.20))
	_victory_title.add_theme_color_override("font_color", Color("fff1c8"))
	_victory_ember_label.add_theme_color_override("font_color", accent.lightened(0.22))
	_victory_ember_value.add_theme_color_override("font_color", Color("ffd27a"))
	_victory_recovery_value.add_theme_color_override("font_color", Color("e7d7b7"))
	var ember_panel: PanelContainer = _victory_panel.find_child("VictoryEmberResult", true, false) as PanelContainer
	if ember_panel != null:
		ember_panel.add_theme_stylebox_override("panel", _inset_style(accent, Color(accent.r * 0.12, accent.g * 0.10, accent.b * 0.08, 0.92)))

func _panel_style(accent: Color) -> StyleBoxFlat:
	var style := _ui_skin.make_plain_card_style(Color(0.075, 0.052, 0.035, 0.965), accent, 0.0)
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
	if not visible or size.x <= 0.0 or size.y <= 0.0:
		return
	var progress: float = _intro_progress()
	if _is_victory():
		_update_victory_layout(progress)
	else:
		_update_defeat_layout(progress)
	queue_redraw()

func _update_victory_layout(progress: float) -> void:
	var content_minimum: Vector2 = _victory_panel.get_combined_minimum_size()
	var width: float = clampf(size.x * 0.41, PANEL_MIN_WIDTH, PANEL_MAX_SIZE.x)
	width = minf(maxf(width, content_minimum.x), maxf(320.0, size.x - 32.0))
	var height: float = minf(maxf(450.0, ceilf(content_minimum.y) + 4.0), minf(PANEL_MAX_SIZE.y, maxf(320.0, size.y - 120.0)))
	var edge_margin: float = minf(PANEL_EDGE_MARGIN, maxf(16.0, size.x * 0.035))
	var base_x: float = size.x - width - edge_margin
	var base_y: float = maxf(12.0, (size.y - height - 84.0) * 0.5)
	_victory_panel.position = Vector2(base_x + (1.0 - progress) * 46.0, base_y)
	_victory_panel.size = Vector2(width, height)
	_victory_panel.modulate = Color(1.0, 1.0, 1.0, progress)
	var button_width: float = minf(BUTTON_MIN_WIDTH, width * 0.46)
	var button_y: float = minf(size.y - BUTTON_HEIGHT - 12.0, base_y + height + 12.0)
	_new_run_button.custom_minimum_size = Vector2(button_width, BUTTON_HEIGHT)
	_main_menu_button.custom_minimum_size = Vector2(button_width, BUTTON_HEIGHT)
	_new_run_button.position = Vector2(base_x, button_y)
	_new_run_button.size = Vector2(button_width, BUTTON_HEIGHT)
	_main_menu_button.position = Vector2(base_x + width - button_width, button_y)
	_main_menu_button.size = Vector2(button_width, BUTTON_HEIGHT)
	_new_run_button.modulate = Color(1.0, 1.0, 1.0, progress)
	_main_menu_button.modulate = Color(1.0, 1.0, 1.0, progress)

func _update_defeat_layout(progress: float) -> void:
	var content_x: float = size.x * 0.505
	var content_width: float = minf(size.x * 0.430, 800.0)
	var top: float = size.y * 0.025
	var hidden_slide: float = (1.0 - progress) * 54.0
	_defeat_layout.modulate = Color(1.0, 1.0, 1.0, progress)
	_defeat_kicker.position = Vector2(content_x + content_width * 0.10 + hidden_slide, top)
	_defeat_kicker.size = Vector2(content_width * 0.90, size.y * 0.052)
	_defeat_title_raster.position = Vector2(content_x - content_width * 0.10 + hidden_slide, top + size.y * 0.025)
	_defeat_title_raster.size = Vector2(content_width * 1.08, size.y * 0.235)
	_defeat_accessibility_title.position = _defeat_title_raster.position
	_defeat_accessibility_title.size = _defeat_title_raster.size
	_defeat_metrics.position = Vector2(content_x - 28.0 + hidden_slide, top + size.y * 0.250)
	_defeat_metrics.size = Vector2(520.0, size.y * 0.345)
	_defeat_ember_result.position = Vector2(size.x * 0.405 + hidden_slide, top + size.y * 0.690)
	_defeat_ember_result.size = Vector2(250.0, 78.0)
	_defeat_recovery_value.position = Vector2(size.x * 0.505 + hidden_slide, top + size.y * 0.710)
	_defeat_recovery_value.size = Vector2(minf(560.0, size.x * 0.34), 44.0)
	var actions_y: float = minf(size.y - 82.0, top + size.y * 0.840)
	# The ornament draws four pixels wider and ten pixels taller than the Button.
	# These dimensions retain the source bitmap's exact 1024:224 aspect on screen.
	var new_run_size := Vector2(361.7143, 70.0)
	var main_menu_size := Vector2(297.7143, 56.0)
	var action_gap: float = 34.0
	var action_group_width: float = new_run_size.x + action_gap + main_menu_size.x
	var actions_x: float = minf(size.x * 0.465, size.x - action_group_width - 24.0) + hidden_slide
	_new_run_button.custom_minimum_size = new_run_size
	_main_menu_button.custom_minimum_size = main_menu_size
	_new_run_button.position = Vector2(actions_x, actions_y)
	_new_run_button.size = new_run_size
	_main_menu_button.position = Vector2(actions_x + new_run_size.x + action_gap, actions_y + (new_run_size.y - main_menu_size.y) * 0.5)
	_main_menu_button.size = main_menu_size
	_new_run_button.modulate = Color(1.0, 1.0, 1.0, progress)
	_main_menu_button.modulate = Color(1.0, 1.0, 1.0, progress)
