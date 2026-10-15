extends Control
class_name RunEndRecapOverlay

const AssetLoader = preload("res://scripts/asset_loader.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const DeathEngulfOverlay = preload("res://scripts/death_engulf_overlay.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const DepthRules = preload("res://scripts/depth_rules.gd")
const RunScoreRules = preload("res://scripts/run_score_rules.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const DISPLAY_FONT = preload("res://fonts/LabyrinthCrumble-Display.tres")
const UI_FONT = preload("res://fonts/LabyrinthCrumble-UI.tres")
const TEXT_FONT = preload("res://fonts/LabyrinthCrumble-Text.tres")

signal new_run_pressed
signal main_menu_pressed

const DEFEAT_WINDOW_CENTER_NORMALIZED: Vector2 = Vector2(0.325, 0.470)
const COLUMN_ORIGIN: Vector2 = Vector2(1010.0, 82.0)
const COLUMN_WIDTH: float = 780.0
const SCORE_WIDTH: float = 560.0
const ROW_MIN_HEIGHT: float = 38.0
const ROWS_TOP: float = 288.0
const TITLE_FADE_SECONDS: float = 0.3
const COPY_DELAY_SECONDS: float = 0.25
const ROW_REVEAL_SECONDS: float = 0.11
const TOTAL_COUNT_SECONDS: float = 0.8
const BEST_POP_SECONDS: float = 0.25
const SINGLE_COLUMN_ROW_LIMIT: int = 9
const SPLIT_SCORE_WIDTH: float = 380.0
const SCORE_COLUMN_GAP: float = 20.0
const QUIP_SKEW: float = 0.2
const TITLE_GLOW_RADIUS: int = 18
const TITLE_GLOW_ALPHA: float = 0.25
const RULE_DIAMOND_SIDE: float = 9.0
const SCORE_VALUE_MIN_WIDTH: float = 64.0
const SCORE_DETAIL_GAPS: float = 12.0
const LABEL_DETAIL_GAP: float = 8.0

class GildedRule:
	extends Control
	func _draw() -> void:
		var start := Vector2(0, 6)
		var finish := start + Vector2(SCORE_WIDTH, 0)
		draw_polygon(PackedVector2Array([start, finish, finish + Vector2(0, 1), start + Vector2(0, 1)]), PackedColorArray([Palette.GOLD_DIM, Color(Palette.GOLD_DIM, 0), Color(Palette.GOLD_DIM, 0), Palette.GOLD_DIM]))
		var half_side: float = RULE_DIAMOND_SIDE * 0.5
		var corners := PackedVector2Array([Vector2(-half_side, -half_side), Vector2(half_side, -half_side), Vector2(half_side, half_side), Vector2(-half_side, half_side)])
		for index: int in range(corners.size()):
			corners[index] = start + Vector2(half_side, 0) + corners[index].rotated(PI * 0.25)
		draw_colored_polygon(corners, Palette.GOLD)

class PortraitRing:
	extends Control
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5 - 0.5, Palette.GOLD_DIM, false, 1.0, true)

class RoundPortrait:
	extends Control
	var texture: Texture2D
	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		var image := TextureRect.new()
		image.texture = texture
		image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		image.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		image.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(image)
		var ring := PortraitRing.new()
		ring.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		add_child(ring)
	func _draw() -> void:
		draw_circle(size * 0.5, size.x * 0.5, Color.WHITE)
	func set_texture(value: Texture2D) -> void:
		texture = value
		if get_child_count() > 0:
			(get_child(0) as TextureRect).texture = value

# The approved UI face has proportional digits and no tnum substitution.
# Center its existing glyphs in equal advances; no alternate font is loaded.
class TabularValue:
	extends Label
	var ink: Color = Palette.TEXT
	func digit_advance() -> float:
		var font: Font = get_theme_font("font")
		var font_size: int = get_theme_font_size("font_size")
		var advance: float = 0.0
		for digit: String in ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9"]:
			advance = maxf(advance, font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		return advance
	func _draw() -> void:
		var font: Font = get_theme_font("font")
		var font_size: int = get_theme_font_size("font_size")
		var advance: float = digit_advance()
		var x: float = size.x - text.length() * advance
		var baseline: float = (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
		for digit: String in text:
			var width: float = font.get_string_size(digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
			draw_string(font, Vector2(x + (advance - width) * 0.5, baseline), digit, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, ink)
			x += advance

var _ui_skin := UiSkin.new()
var _model: Dictionary = {}
var _model_fingerprint: String = ""
var _motion_enabled: bool = true
var _elapsed: float = 0.0
var _death_site_normalized: Vector2 = DEFEAT_WINDOW_CENTER_NORMALIZED
var _glow_site_normalized: Vector2 = DEFEAT_WINDOW_CENTER_NORMALIZED
var _death_shroud: DeathEngulfOverlay
var _layout_root: Control
var _column: Control
var _kicker: Label
var _title: Label
var _title_glow: Control
var _quip: Label
var _cause: Label
var _portrait: RoundPortrait
var _ledger: Control
var _rows: VBoxContainer
var _feat_rows: VBoxContainer
var _row_controls: Array[Control]
var _total: Control
var _total_value: Label
var _best: Label
var _embers: RichTextLabel
var _new_run_button: Button
var _chronicle_button: Button
var _main_menu_button: Button
var _run_host: Node
var _clock_run_id: String = ""
var _clock_last_usec: int = 0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	set_process(false)
	_build_children()
	# The recap is installed for the lifetime of RunScene, including while
	# hidden. Keep the new clock in this unit's adapter without modifying the
	# scene's dialogue-driven _process enable/disable lifecycle.
	var ancestor: Node = get_parent()
	while ancestor != null:
		if ancestor.has_method("_show_run_end_recap"):
			_run_host = ancestor
			call_deferred("_attach_to_viewport_ui")
			break
		ancestor = ancestor.get_parent()

func _attach_to_viewport_ui() -> void:
	# StageRoot excludes margins and the live HUD. The recap is specified in
	# viewport coordinates and must shade the same entire board in every outcome.
	var viewport_ui: Control = _run_host.get_node("UiLayer/UiRoot") as Control
	if get_parent() != viewport_ui:
		reparent(viewport_ui, false)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout()

func _physics_process(_delta: float) -> void:
	var now_usec: int = Time.get_ticks_usec()
	var elapsed_seconds: float = float(now_usec - _clock_last_usec) / 1000000.0 if _clock_last_usec > 0 else 0.0
	_clock_last_usec = now_usec
	if _run_host == null or not _run_host.is_visible_in_tree():
		return
	var state: Dictionary = _run_host.get("_run_state") as Dictionary
	if state.is_empty():
		return
	var run_id: String = RunEngine.run_result_id(state)
	if run_id != _clock_run_id:
		_clock_run_id = run_id
		return # Initial scene construction/new-run loading is not play time.
	var pause_menu: Control = _run_host.get("_menu_scrim") as Control
	RunEngine.advance_play_time(state, elapsed_seconds, get_tree().paused or (pause_menu != null and pause_menu.visible))
	var active_combat: Dictionary = _run_host.get("_combat_state") as Dictionary
	var active_stats: Dictionary = active_combat.get("run_stats", {}) as Dictionary
	# Passive drag/cancel and previews retain their exact combat snapshot. Only
	# a committed card resolution needs its independently owned clock updated.
	if bool(active_stats.get("card_resolution_active", false)):
		var combat_stats: Dictionary = RunEngine.normalized_run_stats(active_stats)
		combat_stats["run_seconds"] = float(state["run_stats"]["run_seconds"])
		active_combat["run_stats"] = combat_stats

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
	var metrics: Dictionary = {
		"enemies_killed": int(combat_stats.get("enemies_killed", 0)),
		"damage_dealt": int(combat_stats.get("damage_dealt", 0)),
		"damage_received": int(combat_stats.get("damage_received", 0)),
		"depth": maxi(0, int(current_room.get("depth", _coord_depth(current_coord)))),
		"rooms_cleared": rooms_cleared,
		"bosses_defeated": bosses_defeated
	}
	var outcome: String = str(run_state.get("mode", ""))
	if outcome in ["victory", "defeat", "embrace"]:
		var scored: Dictionary = RunScoreRules.score(run_state, outcome)
		var location: Dictionary = RunScoreRules.location(run_state)
		metrics["_score_result"] = {"scored": scored, "killer": combat_stats["killer"], "section": location["section"], "biome": location["biome"], "outcome": outcome, "context": RunScoreRules.analytics_context(run_state), "escaped_noctyrax": (combat_stats["dragons_slain"] as Array).has("noctyrax")}
	return metrics


static func build_model(run_state: Dictionary, progression: Dictionary, outcome: String, ember_amount: int) -> Dictionary:
	var normalized_outcome: String = outcome if outcome in ["victory", "embrace"] else "defeat"
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
			recovery_status = "No marker · no Embers left behind" if ember_amount <= 0 else "No recovery marker created"
		else:
			recovery_status = "No recovery marker active"
	else:
		var marker_coord: Vector2i = ProgressionStore.recovery_coord(progression)
		var marker_depth: int = _coord_depth(marker_coord)
		var marker_amount: int = int(marker.get("amount", 0))
		var next_progression: Dictionary = ProgressionStore.prepare_for_new_run(progression)
		var next_marker: Dictionary = ProgressionStore.recovery_marker(next_progression)
		if next_marker.is_empty():
			recovery_status = "Marker expires · %d Embers unrecovered" % marker_amount
		else:
			var marker_verb: String = "set" if normalized_outcome == "defeat" and marker_amount == maxi(0, ember_amount) else "active"
			recovery_status = "Recovery marker %s · Depth %d · %d Embers" % [marker_verb, marker_depth, marker_amount]

	var run_result: Dictionary = run_state.get("run_result", {}) as Dictionary
	var new_bests: Array[String] = []
	for stat_id_var: Variant in run_result.get("new_bests", []):
		var stat_id: String = str(stat_id_var)
		if ProgressionStore.BEST_ELIGIBLE_STAT_IDS.has(stat_id) and not new_bests.has(stat_id):
			new_bests.append(stat_id)
	var model: Dictionary = {
		"outcome": normalized_outcome,
		"kicker": "THE LABYRINTH YIELDS" if normalized_outcome == "victory" else "THE UMBRA CLOSES IN",
		"title": "ASCENT COMPLETE" if normalized_outcome == "victory" else "RUN ENDED",
		"summary": "The ascent is complete. Carried Embers are secure." if normalized_outcome == "victory" else "",
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
	var location: Dictionary = RunScoreRules.location(run_state)
	var copy: Dictionary = RunScoreRules.seeded_text(RunScoreRules.identity(run_state), normalized_outcome)
	var scored: Dictionary = RunScoreRules.score(run_state, normalized_outcome)
	var killer: Dictionary = RunScoreRules.normalized_stats(run_state.get("run_stats", {}))["killer"]
	model.merge(location, true)
	model.merge(copy, true)
	if run_result.get("score") != null:
		scored = {"total": int(run_result["score"]), "lines": run_result.get("lines", []), "feats": run_result.get("feats", [])}
	model["score"] = scored
	model["killer"] = killer
	model["cause"] = RunScoreRules.cause_text(killer, normalized_outcome, ember_amount)
	var biome_copy: String = " · %s" % location["biome_name"] if not str(location["biome_name"]).is_empty() else ""
	model["eyebrow"] = "Section %s%s · Room %d of %d" % [RunScoreRules.roman(int(location["section"])), biome_copy, int(location["step"]), int(location["room_count"])] if int(location["section"]) > 0 else "Depth %d" % int(model["depth"])
	if DepthRules.depth(run_state) > 0: model["eyebrow"] += " · Umbra Depth %d" % DepthRules.depth(run_state)
	model["new_best_score"] = bool(run_result.get("new_best_score", int(scored["total"]) > int(progression.get("best_score", 0))))
	model["embers_text"] = "Embers carried %s." % RunScoreRules.grouped_number(ember_amount)
	if normalized_outcome == "defeat":
		model["embers_text"] = "Embers lost %s. They wait where you fell, in Section %s of your next run." % [RunScoreRules.grouped_number(ember_amount), RunScoreRules.roman(int(location["section"]))] if ember_amount > 0 else "No marker · no Embers left behind"
		if int(location["section"]) <= 0 and ember_amount > 0:
			model["embers_text"] = "%s %d\n%s" % [model["ember_label"], ember_amount, recovery_status]
	return model

# Pure terminal preparation for the campfire scene connection. Banked
# currency/recovery state remains authoritative in the supplied progression.
static func embrace_state(run_state: Dictionary, progression: Dictionary) -> Dictionary:
	var terminal: Dictionary = run_state.duplicate(true)
	terminal["mode"] = "embrace"
	terminal["game_over"] = false # This legacy flag means defeat, not withdrawal.
	terminal["victory"] = false
	terminal["run_stats"] = RunScoreRules.normalized_stats(terminal.get("run_stats", {}))
	terminal["run_stats"]["killer"] = {}
	var recorded: Dictionary = ProgressionStore.record_run_result(progression, RunEngine.run_result_id(terminal), result_stats(terminal))
	terminal["run_result"] = recorded["result"]
	terminal["progression"] = recorded["data"]
	return terminal

static func _coord_depth(coord: Vector2i) -> int:
	return maxi(abs(coord.x), abs(coord.y))

func _label(node_name: String, text: String, font: Font, font_size: int, color: Color, rect: Rect2) -> Label:
	var label := Label.new()
	label.name = node_name
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spaced_font(spacing: int) -> FontVariation:
	var font := FontVariation.new()
	font.base_font = UI_FONT
	font.spacing_glyph = spacing
	return font

func _build_children() -> void:
	_death_shroud = DeathEngulfOverlay.new()
	_death_shroud.name = "DeathShroud"
	_death_shroud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_death_shroud)
	_layout_root = Control.new()
	_layout_root.name = "LastLightRecap"
	_layout_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_layout_root)
	_column = Control.new()
	_column.name = "OutcomeRecap"
	_column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout_root.add_child(_column)
	_kicker = _label("OutcomeKicker", "", _spaced_font(5), 15, Palette.UMBRA, Rect2(0, 0, COLUMN_WIDTH, 22))
	_column.add_child(_kicker)
	_title = _label("OutcomeTitle", "", DISPLAY_FONT, 112, Color("ddd3c4"), Rect2(0, 30, COLUMN_WIDTH, 112))
	_title.add_theme_constant_override("shadow_offset_x", 0)
	_title.add_theme_constant_override("shadow_offset_y", 3)
	_title_glow = Control.new()
	_title_glow.name = "TitleGlow"
	_title_glow.position = _title.position
	_title_glow.size = _title.size
	_title_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_title_glow)
	# Nested glyph outlines give a soft falloff over the approved 18 px radius.
	# Their combined inner alpha is exactly the approved 25%.
	for radius: int in range(TITLE_GLOW_RADIUS, 0, -1):
		var glow := _label("GlowRadius%d" % radius, "", DISPLAY_FONT, 112, Color.TRANSPARENT, Rect2(Vector2.ZERO, _title.size))
		glow.add_theme_constant_override("outline_size", radius)
		glow.add_theme_color_override("font_shadow_color", Color.TRANSPARENT)
		_title_glow.add_child(glow)
	_column.add_child(_title)
	var italic := FontVariation.new()
	italic.base_font = TEXT_FONT
	# Synthetic italic implements the approved CSS font-style on the same font.
	italic.variation_transform = Transform2D(0.0, Vector2.ONE, QUIP_SKEW, Vector2.ZERO)
	_quip = _label("OutcomeQuip", "", italic, 24, Palette.TEXT_2, Rect2(0, 142, COLUMN_WIDTH, 35))
	_column.add_child(_quip)
	_portrait = RoundPortrait.new()
	_portrait.name = "KillerPortrait"
	_portrait.position = Vector2(0, 188)
	_portrait.size = Vector2(44, 44)
	_column.add_child(_portrait)
	_cause = _label("OutcomeCause", "", TEXT_FONT, 20, Palette.TEXT, Rect2(56, 190, COLUMN_WIDTH - 56, 44))
	_cause.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_cause)
	var rule := GildedRule.new()
	rule.name = "GildedRule"
	rule.position = Vector2(0, 256)
	rule.size = Vector2(SCORE_WIDTH, 14)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(rule)
	_ledger = Control.new()
	_ledger.name = "ScoreLedger"
	_ledger.position = Vector2(0, ROWS_TOP)
	_ledger.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_column.add_child(_ledger)
	_rows = VBoxContainer.new()
	_rows.name = "ScoreRows"
	_rows.custom_minimum_size.x = SCORE_WIDTH
	_rows.add_theme_constant_override("separation", 0)
	_ledger.add_child(_rows)
	_feat_rows = VBoxContainer.new()
	_feat_rows.name = "FeatRows"
	_feat_rows.position.x = SPLIT_SCORE_WIDTH + SCORE_COLUMN_GAP
	_feat_rows.add_theme_constant_override("separation", 0)
	_ledger.add_child(_feat_rows)
	_total = Control.new()
	_total.name = "ScoreTotal"
	_total.size = Vector2(SCORE_WIDTH, 66)
	_column.add_child(_total)
	_total.add_child(_label("ScoreHeading", "SCORE", _spaced_font(4), 18, Palette.GOLD, Rect2(0, 30, 150, 28)))
	_total_value = _label("ScoreValue", "0", DISPLAY_FONT, 52, Palette.GOLD_BRIGHT, Rect2(250, 0, 190, 66))
	_total_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_total.add_child(_total_value)
	_best = _label("NewBestTag", "NEW BEST", _spaced_font(3), 13, Color("1b0f06"), Rect2(454, 28, 106, 24))
	_best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_best.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var tag_style := StyleBoxFlat.new()
	tag_style.bg_color = Palette.EMBER
	tag_style.set_corner_radius_all(2)
	_best.add_theme_stylebox_override("normal", tag_style)
	_total.add_child(_best)
	_embers = RichTextLabel.new()
	_embers.name = "EmberResult"
	_embers.size = Vector2(COLUMN_WIDTH, 56)
	_embers.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_embers.bbcode_enabled = true
	_embers.scroll_active = false
	_embers.add_theme_font_override("normal_font", TEXT_FONT)
	_embers.add_theme_font_size_override("normal_font_size", 19)
	_embers.add_theme_color_override("default_color", Palette.TEXT_2)
	_embers.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_column.add_child(_embers)
	_new_run_button = _button("NewRunButton", "Rise Again")
	_chronicle_button = _button("ChronicleButton", "Chronicle")
	_chronicle_button.disabled = true
	_chronicle_button.tooltip_text = "Coming soon"
	_chronicle_button.focus_mode = Control.FOCUS_NONE
	_main_menu_button = _button("MainMenuButton", "Main Menu")
	_new_run_button.pressed.connect(func() -> void: new_run_pressed.emit())
	_main_menu_button.pressed.connect(func() -> void: main_menu_pressed.emit())
	_new_run_button.focus_neighbor_left = _new_run_button.get_path_to(_main_menu_button)
	_new_run_button.focus_neighbor_right = _new_run_button.get_path_to(_main_menu_button)
	_main_menu_button.focus_neighbor_left = _main_menu_button.get_path_to(_new_run_button)
	_main_menu_button.focus_neighbor_right = _main_menu_button.get_path_to(_new_run_button)
	for button: Button in [_new_run_button, _main_menu_button]:
		button.focus_entered.connect(_select_action.bind(button))
		button.mouse_entered.connect(_select_action.bind(button))

func _button(node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.add_theme_font_override("font", UI_FONT)
	button.add_theme_font_size_override("font_size", 22)
	add_child(button)
	return button

func _select_action(button: Button) -> void:
	for action: Button in [_new_run_button, _main_menu_button]:
		action.set_meta("umbra_selected", action == button)
		action.queue_redraw()

func _add_score_row(data: Dictionary, parent: VBoxContainer, width: float) -> void:
	var row := Control.new()
	row.name = "ScoreRow%d" % _row_controls.size()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.clip_contents = true
	var feat: bool = bool(data.get("feat", false))
	var label_text: String = str(data["label"])
	var label_x: float = 17.0 if feat else 0.0
	var label_width: float = UI_FONT.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
	var detail_x: float = label_x + label_width + LABEL_DETAIL_GAP
	var detail_text: String = str(data.get("detail", ""))
	row.custom_minimum_size = Vector2(width, ROW_MIN_HEIGHT)
	parent.add_child(row)
	if feat:
		row.add_child(_label("FeatDiamond", "◆", UI_FONT, 12, Palette.GOLD, Rect2(0, 9, 14, 20)))
	row.add_child(_label("ScoreLabel", label_text, UI_FONT, 20, Palette.GOLD_BRIGHT if feat else Palette.TEXT_2, Rect2(label_x, 4, label_width, 30)))
	var value := TabularValue.new()
	value.name = "ScorePoints"
	value.text = str(data["points"])
	value.add_theme_font_override("font", UI_FONT)
	value.add_theme_font_size_override("font_size", 22)
	var value_width: float = maxf(SCORE_VALUE_MIN_WIDTH, value.digit_advance() * value.text.length())
	var detail_width: float = maxf(0, width - label_x - label_width - value_width - SCORE_DETAIL_GAPS)
	var detail := _label("ScoreDetail", "", TEXT_FONT, 16, Palette.TEXT_3, Rect2(detail_x, 9, detail_width, 24))
	detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	detail.clip_text = true
	detail.text = detail_text
	detail.tooltip_text = detail_text
	detail.mouse_filter = Control.MOUSE_FILTER_PASS
	# Font overrides set a Label's natural minimum before clipping is enabled.
	# Reapply the final bounds after clipping, so long text cannot retain that size.
	detail.size = Vector2(detail_width, 24)
	row.add_child(detail)
	detail.set_deferred("size", Vector2(detail_width, 24))
	value.position = Vector2(width - value_width, 3)
	value.clip_text = true
	value.size = Vector2(value_width, 30)
	value.ink = Palette.GOLD_BRIGHT if feat else Palette.TEXT
	value.mouse_filter = Control.MOUSE_FILTER_IGNORE
	value.add_theme_color_override("font_color", Color.TRANSPARENT)
	row.add_child(value)
	var hairline := ColorRect.new()
	hairline.color = Color(Palette.GOLD_DIM, 0.18)
	hairline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hairline.position = Vector2(0, row.custom_minimum_size.y - 1)
	hairline.size = Vector2(width, 1)
	row.add_child(hairline)
	_row_controls.append(row)

func _apply_model() -> void:
	_kicker.text = str(_model.get("eyebrow", "" )).to_upper()
	_kicker.add_theme_color_override("font_color", Palette.UMBRA if _is_defeat() else Palette.GOLD)
	_title.text = str(_model.get("title", ""))
	_title.add_theme_color_override("font_shadow_color", Color("2b1d3d") if _is_defeat() else Palette.EMBER_DEEP)
	var glow_color: Color = Palette.UMBRA if _is_defeat() else Palette.EMBER
	var layer_alpha: float = 1.0 - pow(1.0 - TITLE_GLOW_ALPHA, 1.0 / TITLE_GLOW_RADIUS)
	for layer: Label in _title_glow.get_children():
		layer.text = _title.text
		layer.add_theme_color_override("font_outline_color", Color(glow_color, layer_alpha))
	_quip.text = str(_model.get("quip", ""))
	_quip.visible = not _quip.text.is_empty()
	_cause.text = str(_model.get("cause", ""))
	var killer: Dictionary = _model.get("killer", {}) as Dictionary
	var enemy_type: String = str(killer.get("enemy_type", ""))
	var portrait_path: String = "res://assets/art/portraits/%s.png" % enemy_type
	if _run_host != null:
		var approved_path: String = str(_run_host.call("_combat_portrait_path", enemy_type))
		if not approved_path.is_empty():
			portrait_path = approved_path
	_portrait.visible = _is_defeat() and (ResourceLoader.exists(portrait_path) or FileAccess.file_exists(portrait_path))
	_portrait.set_texture(AssetLoader.load_texture(portrait_path) if _portrait.visible else null)
	_cause.position.x = 56.0 if _portrait.visible else 0.0
	_cause.size.x = COLUMN_WIDTH - _cause.position.x
	for row: Control in _row_controls:
		row.get_parent().remove_child(row)
		row.queue_free()
	_row_controls.clear()
	var scored: Dictionary = _model.get("score", {}) as Dictionary
	var split: bool = (scored.get("lines", []) as Array).size() + (scored.get("feats", []) as Array).size() > SINGLE_COLUMN_ROW_LIMIT
	var ledger_width: float = SPLIT_SCORE_WIDTH if split else SCORE_WIDTH
	_rows.custom_minimum_size.x = ledger_width
	_rows.size.x = ledger_width
	_feat_rows.custom_minimum_size.x = SPLIT_SCORE_WIDTH
	_feat_rows.size.x = SPLIT_SCORE_WIDTH
	_feat_rows.visible = split
	for line: Dictionary in scored.get("lines", []):
		_add_score_row(line, _rows, ledger_width)
	for feat: Dictionary in scored.get("feats", []):
		_add_score_row(feat, _feat_rows if split else _rows, ledger_width)
	var row_count: int = maxi(_rows.get_child_count(), _feat_rows.get_child_count()) if split else _rows.get_child_count()
	_ledger.size = Vector2(COLUMN_WIDTH if split else SCORE_WIDTH, row_count * ROW_MIN_HEIGHT)
	_total.position = Vector2(0, ROWS_TOP + _ledger.size.y + 14)
	_embers.position = Vector2(0, _total.position.y + 82)
	var embers_copy: String = str(_model.get("embers_text", ""))
	var amount: String = RunScoreRules.grouped_number(int(_model.get("ember_amount", 0)))
	_embers.text = embers_copy.replace(amount, "[font=res://fonts/LabyrinthCrumble-UI.tres][font_size=22][color=#e8893a]%s[/color][/font_size][/font]" % amount) if embers_copy.contains(amount) else embers_copy
	for button: Button in [_new_run_button, _chronicle_button, _main_menu_button]:
		var variant: String = UiSkin.VARIANT_UMBRA if _is_defeat() else UiSkin.VARIANT_LARGE
		_ui_skin.apply_button_stylebox_overrides(button, variant)
		_ui_skin.apply_button_text_overrides(button)
		button.set_meta("umbra_selected", button == _new_run_button)
		var width: float = (COLUMN_WIDTH - 2.0 * 16.0) / 3.0
		var button_height: float = (width + 4.0) / (1024.0 / 224.0) - 10.0 if _is_defeat() else width / 3.25
		button.size = Vector2(width, button_height)
		button.custom_minimum_size = button.size
	_layout()

func _layout() -> void:
	if _column == null:
		return
	var factor: float = minf(size.x / 1920.0, size.y / 1080.0)
	_column.position = COLUMN_ORIGIN * factor
	_column.size = Vector2(COLUMN_WIDTH, 900)
	_column.scale = Vector2.ONE * factor
	var x: float = COLUMN_ORIGIN.x
	for button: Button in [_new_run_button, _chronicle_button, _main_menu_button]:
		button.position = Vector2(x, 952) * factor
		button.scale = Vector2.ONE * factor
		x += button.size.x + 16

func present(model: Dictionary, death_site_normalized: Vector2 = DEFEAT_WINDOW_CENTER_NORMALIZED) -> void:
	var fingerprint: String = JSON.stringify(model)
	var restart: bool = not visible or fingerprint != _model_fingerprint
	_model = model.duplicate(true)
	_model_fingerprint = fingerprint
	set_death_site_normalized(death_site_normalized)
	set_glow_site_normalized(death_site_normalized)
	if restart:
		_apply_model()
		_elapsed = 0.0 if _motion_enabled else presentation_duration()
		if _is_defeat():
			_death_shroud.set_motion_enabled(_motion_enabled)
			_death_shroud.play()
		else:
			_death_shroud.reset()
	visible = true
	set_process(_motion_enabled and _elapsed < presentation_duration())
	_update_presentation()
	call_deferred("_focus_primary_action")

func _focus_primary_action() -> void:
	if visible:
		_new_run_button.grab_focus()

func _is_defeat() -> bool:
	return str(_model.get("outcome", "")) == "defeat"

func presentation_duration() -> float:
	return maxf(DeathEngulfOverlay.ENGULF_SECONDS if _is_defeat() else 0.0, _total_start() + TOTAL_COUNT_SECONDS + BEST_POP_SECONDS)

func _total_start() -> float:
	return TITLE_FADE_SECONDS + COPY_DELAY_SECONDS + float(_row_controls.size()) * ROW_REVEAL_SECONDS

func _update_presentation() -> void:
	_title.modulate.a = clampf(_elapsed / TITLE_FADE_SECONDS, 0, 1)
	_title_glow.modulate.a = _title.modulate.a
	var copy_shown: bool = _elapsed >= TITLE_FADE_SECONDS + COPY_DELAY_SECONDS
	_quip.modulate.a = 1.0 if copy_shown else 0.0
	_cause.modulate.a = _quip.modulate.a
	_portrait.modulate.a = _quip.modulate.a
	var row_start: float = TITLE_FADE_SECONDS + COPY_DELAY_SECONDS
	for index: int in range(_row_controls.size()):
		var shown: bool = _elapsed >= row_start + float(index) * ROW_REVEAL_SECONDS
		_row_controls[index].modulate.a = 1.0 if shown else 0.0
	var count: float = clampf((_elapsed - _total_start()) / TOTAL_COUNT_SECONDS, 0, 1)
	_total.modulate.a = 1.0 if _elapsed >= _total_start() else 0.0
	var score: int = int((_model.get("score", {}) as Dictionary).get("total", 0))
	_total_value.text = str(roundi(score * (1.0 - pow(1.0 - count, 3.0))))
	_best.visible = bool(_model.get("new_best_score", false)) and count >= 1.0
	var pop: float = clampf((_elapsed - _total_start() - TOTAL_COUNT_SECONDS) / BEST_POP_SECONDS, 0, 1)
	_best.pivot_offset = _best.size * 0.5
	_best.scale = Vector2.ONE * lerpf(1.25, 1.0, pop)
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed = minf(presentation_duration(), _elapsed + delta)
	_update_presentation()
	if _elapsed >= presentation_duration():
		set_process(false)

func _input(event: InputEvent) -> void:
	if not visible or _elapsed >= presentation_duration():
		return
	if event.is_pressed() or event is InputEventMouseMotion or event is InputEventScreenDrag or (event is InputEventJoypadMotion and absf(event.axis_value) >= InputRouter.JOYSTICK_ACTIVITY_THRESHOLD):
		skip_presentation()
		get_viewport().set_input_as_handled()

func skip_presentation() -> void:
	seek_presentation(presentation_duration())

func seek_presentation(seconds: float) -> void:
	_elapsed = clampf(seconds, 0, presentation_duration())
	if _is_defeat():
		_death_shroud.seek_seconds(minf(_elapsed, DeathEngulfOverlay.ENGULF_SECONDS))
	set_process(_motion_enabled and _elapsed < presentation_duration())
	_update_presentation()

func set_motion_enabled(enabled: bool) -> void:
	_motion_enabled = enabled
	if _death_shroud != null:
		_death_shroud.set_motion_enabled(enabled)
	if visible and not enabled:
		skip_presentation()

func motion_enabled() -> bool:
	return _motion_enabled

func reset() -> void:
	_model.clear()
	_model_fingerprint = ""
	visible = false
	set_process(false)
	if _death_shroud != null:
		_death_shroud.reset()

func recap_model() -> Dictionary:
	return _model.duplicate(true)

func set_death_site_normalized(value: Vector2) -> void:
	_death_site_normalized = value.clamp(Vector2(0.08, 0.10), Vector2(0.92, 0.90))
	if _death_shroud != null:
		_death_shroud.set_death_site_normalized(_death_site_normalized)

func set_glow_site_normalized(value: Vector2) -> void:
	_glow_site_normalized = value.clamp(Vector2(0.08, 0.10), Vector2(0.92, 0.90))
	if _death_shroud != null:
		_death_shroud.set_glow_site_normalized(_glow_site_normalized)

func death_site_normalized() -> Vector2:
	return _death_site_normalized

func glow_site_normalized() -> Vector2:
	return _glow_site_normalized

func death_site_ember_position() -> Vector2:
	return _death_shroud.ember_position() if _death_shroud != null else Vector2.ZERO

func shroud_progress() -> float:
	return _death_shroud.engulf_progress() if _death_shroud != null and _death_shroud.visible else 0.0

func final_shroud_alpha() -> float:
	return DeathEngulfOverlay.FINAL_SHROUD_ALPHA

func has_decorative_edge_strokes() -> bool:
	return _death_shroud.has_decorative_edge_strokes() if _death_shroud != null else false

func sample_shroud_alpha(normalized_position: Vector2, progress_override: float = -1.0) -> float:
	return _death_shroud.sample_alpha(normalized_position, progress_override) if _death_shroud != null else 0.0

func _notification(what: int) -> void:
	if what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED]:
		_clock_last_usec = Time.get_ticks_usec()
	if what == NOTIFICATION_RESIZED and is_node_ready():
		_layout()

func _draw() -> void:
	if not visible or _column == null:
		return
	# Approved mockup's right scrim and gilded line/diamond separator.
	var left: float = size.x * 0.30
	var right: float = size.x * 0.52
	draw_polygon(PackedVector2Array([Vector2(left, 0), Vector2(right, 0), Vector2(right, size.y), Vector2(left, size.y)]), PackedColorArray([Color(0.02, 0.016, 0.012, 0), Color(0.02, 0.016, 0.012, 0.82), Color(0.02, 0.016, 0.012, 0.82), Color(0.02, 0.016, 0.012, 0)]))
	draw_polygon(PackedVector2Array([Vector2(right, 0), Vector2(size.x, 0), Vector2(size.x, size.y), Vector2(right, size.y)]), PackedColorArray([Color(0.02, 0.016, 0.012, 0.82), Color(0.02, 0.016, 0.012, 0.94), Color(0.02, 0.016, 0.012, 0.94), Color(0.02, 0.016, 0.012, 0.82)]))
