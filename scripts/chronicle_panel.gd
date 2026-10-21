extends Control

signal closed

const Rules = preload("res://scripts/chronicle_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Frame = preload("res://scripts/ui_gilded_frame.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Specials = preload("res://scripts/special_encounter_library.gd")
const Tooltip = preload("res://scripts/ui_tooltip_panel.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const Router = preload("res://scripts/input_router.gd")
const PromptBar = preload("res://scripts/controller_prompt_bar.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const RunSfx = preload("res://scripts/run_sfx_library.gd")
const CardTile = preload("res://scripts/chronicle_card_tile.gd")
const PreviewBuilders = preload("res://scripts/item_preview_builders.gd")
const PANEL_SIZE := Vector2(1800, 860)
const ROW_HEIGHT: float = 68.0
const DETAIL_WIDTH: float = 1142.0
const DETAIL_HEIGHT: float = 718.0 # Fits five path sections and two spell rows, including badge overhang.
const COLUMN_WIDTH: float = 358.0
const DETAIL_ROW_GAP: float = 28.0
const PATH_COLUMN_WIDTH: float = 740.0
const BUILD_COLUMN_GAP: float = 40.0
const TILE_INK := Color("0f0c09")
const TILE_EDGE := Color("5a4630")
const RESULT_COLORS := {"defeat": Color("d07a6c"), "victory": Palette.GOLD_BRIGHT, "embrace": Palette.TEXT_2}

class HistoryRow extends Button:
	var selected: bool = false
	func _draw() -> void:
		var rect := Rect2(Vector2.ZERO, size)
		if selected:
			Frame.draw_glow(self, rect, Color(Palette.EMBER, 0.15), 18, 0)
			draw_rect(rect, Color(Palette.GOLD, 0.07))
			draw_rect(rect.grow(-0.5), Palette.GOLD, false, 1)
		else:
			draw_line(Vector2(0, size.y - 1), Vector2(size.x, size.y - 1), Color(Palette.GOLD_DIM, 0.18), 1)

class RecordIcon extends Button:
	const CIRCLE_SEGMENTS: int = 64
	const RING_INSET: float = 0.5
	const ICON_CLIP_INSET: float = 2.0
	var texture: Texture2D
	var round_room: bool = false
	var ring: Color = TILE_EDGE
	var terminal_defeat: bool = false
	var tooltip_title: String = ""
	var tooltip_body := PackedStringArray()
	var equipment_id: String = ""
	var tooltip_builder: Callable
	func _draw() -> void:
		var center: Vector2 = size * 0.5
		var border: Color = Palette.GOLD if has_focus() or is_hovered() else ring
		if round_room:
			draw_circle(center, size.x * 0.5 - 1, TILE_INK)
			draw_arc(center, size.x * 0.5 - RING_INSET, 0, TAU, CIRCLE_SEGMENTS, border, 1, true)
		else:
			draw_rect(Rect2(Vector2.ZERO, size), TILE_INK)
			draw_rect(Rect2(Vector2.ONE * 0.5, size - Vector2.ONE), border, false, 1)
		if terminal_defeat:
			var delta: float = size.x * 0.22
			draw_line(center - Vector2(delta, delta), center + Vector2(delta, delta), Palette.DANGER, 2, true)
			draw_line(center - Vector2(delta, -delta), center + Vector2(delta, -delta), Palette.DANGER, 2, true)
		elif texture != null:
			var extent: Vector2 = size - Vector2.ONE * 4
			var texture_size: Vector2 = texture.get_size()
			var fitted: Vector2 = texture_size * minf(extent.x / texture_size.x, extent.y / texture_size.y)
			var texture_rect := Rect2(center - fitted * 0.5, fitted)
			if round_room:
				_draw_clipped_texture(center, texture_rect)
			else:
				draw_texture_rect(texture, texture_rect, false)
	func _draw_clipped_texture(center: Vector2, texture_rect: Rect2) -> void:
		# Draw only the circular part of the approved texture, leaving two pixels
		# inside the ring clear. This covers room, dragon and terminal slots alike.
		var radius: float = size.x * 0.5 - RING_INSET - ICON_CLIP_INSET
		var circle := PackedVector2Array()
		for index: int in range(CIRCLE_SEGMENTS):
			circle.append(center + Vector2.from_angle(TAU * index / CIRCLE_SEGMENTS) * radius)
		# Intersect with the fitted bounds so non-square icons retain their aspect
		# and transparent margins rather than sampling beyond the texture's UVs.
		var bounds := PackedVector2Array([texture_rect.position, Vector2(texture_rect.end.x, texture_rect.position.y), texture_rect.end, Vector2(texture_rect.position.x, texture_rect.end.y)])
		for polygon: PackedVector2Array in Geometry2D.intersect_polygons(circle, bounds):
			var uvs := PackedVector2Array()
			for point: Vector2 in polygon:
				uvs.append((point - texture_rect.position) / texture_rect.size)
			draw_polygon(polygon, PackedColorArray([Color.WHITE]), uvs, texture)
	func _make_custom_tooltip(_for_text: String) -> Object:
		if round_room:
			return Tooltip.make_text(tooltip_title + "\nAlready visited")
		return tooltip_builder.call() if tooltip_builder.is_valid() else Tooltip.make_icon_lines(texture, tooltip_title, tooltip_body)

var records: Array[Dictionary]
var selected_index: int = -1
var _panel: Control
var _list: ScrollContainer
var _rows: VBoxContainer
var _detail_scroll: ScrollContainer
var _detail: VBoxContainer
var _chips: HBoxContainer
var _close: Button
var _focus_tooltip: Control
var _focus_anchor: Control
var _stick_direction: int = 0
var _analytics := Analytics.new()
var _prompt_bar: PanelContainer
var _page_sound: AudioStreamPlayer
var _tooltip_host: RefCounted
var _spell_grid: GridContainer
var _spell_groups: Array[Dictionary]
var _detail_tiles: Array[Control]

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.75)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scrim)
	_panel = Control.new()
	_panel.name = "ChronicleFrame"
	_panel.size = PANEL_SIZE
	add_child(_panel)
	_panel.draw.connect(_draw_frame)
	_panel.add_child(_label("CHRONICLE", 15, Palette.GOLD_DIM, Typography.ui_font(), Rect2(48, 34, 600, 22), 5))
	_panel.add_child(_label("Your Descents", 44, Palette.GOLD_BRIGHT, Typography.ui_font(), Rect2(48, 56, 600, 60)))
	_chips = HBoxContainer.new()
	_chips.name = "LifetimeTotals"
	_chips.add_theme_constant_override("separation", 12)
	_panel.add_child(_chips)
	_chips.resized.connect(_position_chips)
	_close = TooltipButton.new()
	_close.name = "ChronicleClose"
	_close.text = "✕"
	_close.position = Vector2(1726, 26)
	_close.size = Vector2(44, 44)
	UiSkin.new().apply_button_stylebox_overrides(_close)
	_close.add_theme_font_override("font", Typography.ui_font())
	_close.add_theme_font_size_override("font_size", 20)
	_close.add_theme_color_override("font_color", Palette.GOLD)
	_close.pressed.connect(close)
	_panel.add_child(_close)
	_list = ScrollContainer.new()
	_list.name = "DescentList"
	_list.position = Vector2(48, 130)
	_list.size = Vector2(520, 690)
	_list.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_list.follow_focus = true
	_panel.add_child(_list)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_rows.add_theme_constant_override("separation", 0)
	_list.add_child(_rows)
	_detail_scroll = ScrollContainer.new()
	_detail_scroll.position = Vector2(610, 130)
	_detail_scroll.size = Vector2(DETAIL_WIDTH, DETAIL_HEIGHT)
	_detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_detail_scroll.follow_focus = true
	_panel.add_child(_detail_scroll)
	_detail = VBoxContainer.new()
	_detail.name = "DescentDetail"
	_detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail.add_theme_constant_override("separation", 0)
	_detail_scroll.add_child(_detail)
	_detail.resized.connect(_refresh_spell_tiles)
	_detail_scroll.get_v_scroll_bar().value_changed.connect(func(_value: float) -> void: _position_focus_tooltip())
	_prompt_bar = PromptBar.new()
	_prompt_bar.name = "ChronicleControllerPrompts"
	add_child(_prompt_bar)
	_prompt_bar.resized.connect(_layout)
	_prompt_bar.set_prompts([{"action": &"controller_dpad", "label": "Select"}, {"action": Router.ACTION_CANCEL, "label": "Back"}])
	resized.connect(_layout)
	_layout()
	visible = false

func _layout() -> void:
	_panel.position = (size - PANEL_SIZE) * 0.5
	_prompt_bar.position = Vector2(size.x - _prompt_bar.size.x - 60, size.y - _prompt_bar.size.y - 24)

func _position_chips() -> void:
	_chips.position = Vector2(PANEL_SIZE.x - 48 - _chips.size.x, 70)

func _draw_frame() -> void:
	var rect := Rect2(Vector2.ZERO, PANEL_SIZE)
	Frame.draw_fill(_panel, rect, Color("1f1913"), Color("0f0c09"), 3)
	_panel.draw_rect(rect.grow(-0.5), Palette.GOLD_DIM, false, 1)
	_panel.draw_rect(rect.grow(-7), Color(Palette.GOLD_DIM, 0.55), false, 1)
	Frame.draw_corner_brackets(_panel, rect.grow(2), Palette.GOLD, 46, 4, 0)

func open(profile: Dictionary = {}, log_event: bool = true) -> void:
	var data: Dictionary = Store.load_data() if profile.is_empty() else profile
	records = Store.chronicle_records(data)
	visible = true
	_clear(_rows)
	_clear(_chips)
	var totals: Dictionary = Store.chronicle_totals(data)
	for key: String in ["runs", "escapes", "best_score", "dragons_slain", "deepest_depth"]:
		if key == "deepest_depth" and not totals.has(key):
			continue
		var chip := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color("17120e")
		style.border_color = Color("4a3a28")
		style.set_border_width_all(1)
		style.set_corner_radius_all(20)
		style.content_margin_left = 14
		style.content_margin_right = 14
		style.content_margin_top = 7
		style.content_margin_bottom = 7
		chip.add_theme_stylebox_override("panel", style)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		row.add_child(_label(Rules.Score.grouped_number(int(totals[key])), 17, Palette.TEXT, Typography.ui_font()))
		row.add_child(_label(str({"runs": "runs", "escapes": "escapes", "best_score": "best score", "dragons_slain": "dragons slain", "deepest_depth": "deepest depth"}[key]), 17, Palette.TEXT_2))
		chip.add_child(row)
		_chips.add_child(chip)
	_chips.reset_size()
	_chips.position = Vector2(PANEL_SIZE.x - 48 - _chips.get_combined_minimum_size().x, 70)
	for index: int in range(records.size()):
		_add_row(index)
	selected_index = -1
	if records.is_empty():
		var empty := _label("No descents yet.", 18, Palette.TEXT_3)
		empty.custom_minimum_size = _list.size
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_rows.add_child(empty)
		_clear(_detail)
		_detail.add_child(_label("Your first descent will be written here.", 21, Palette.TEXT_2))
		_close.grab_focus()
	else:
		select_record(0, true)
	if log_event:
		_analytics.write_event("chronicle_opened", {}, {"records": records.size(), "runs": int(totals["runs"])})
		_play_page_sound(RunSfx.MENU_OPEN_ID)
	_layout()

func close() -> void:
	_clear_focus_tooltip()
	_play_page_sound(RunSfx.MENU_CLOSE_ID)
	visible = false
	closed.emit()

func _exit_tree() -> void:
	_tooltip_host = null

func _add_row(index: int) -> void:
	var record: Dictionary = records[index]
	var row := HistoryRow.new()
	row.name = "DescentRow%d" % index
	row.custom_minimum_size = Vector2(0, ROW_HEIGHT)
	for state: String in ["normal", "hover", "pressed", "focus"]:
		row.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var word := _label(Rules.result_word(record), 15, RESULT_COLORS[record["outcome"]], Typography.ui_font(), Rect2(14, 0, 128, ROW_HEIGHT), 3)
	word.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(word)
	var where_label := _label(Rules.where_text(record), 18, Palette.TEXT, null, Rect2(154, 11, 268, 26))
	where_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(where_label)
	row.tooltip_text = Rules.where_text(record)
	row.add_child(_label("%s · %d min" % [record["ended_at"], floori(float(record["run_seconds"]) / 60)], 15, Palette.TEXT_3, null, Rect2(154, 37, 270, 20)))
	var score := _label(Rules.Score.grouped_number(int(record["score_total"])), 22, Palette.TEXT, Typography.ui_font(), Rect2(422, 11, 84, 30))
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(score)
	if int(record.get("umbra_depth", 0)) >= 1:
		var depth := _label("DEPTH %d" % record["umbra_depth"], 14, Palette.UMBRA, Typography.ui_font(), Rect2(422, 40, 84, 20), 2)
		depth.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(depth)
	row.pressed.connect(select_record.bind(index, true))
	row.focus_entered.connect(select_record.bind(index, false))
	_rows.add_child(row)

func select_record(index: int, focus: bool = false) -> void:
	if records.is_empty():
		return
	index = clampi(index, 0, records.size() - 1)
	var changed: bool = selected_index != index
	selected_index = index
	for child: Node in _rows.get_children():
		if child is HistoryRow:
			child.selected = child.get_index() == selected_index
			child.queue_redraw()
	var row: Control = _rows.get_child(index)
	if focus:
		row.grab_focus()
	_list.ensure_control_visible(row)
	if changed:
		_clear_focus_tooltip()
		_build_detail(records[index])
		var feedback: Node = get_node_or_null("/root/CursorFeedback")
		if feedback != null:
			feedback.call("play_focus_feedback", row)

func _build_detail(record: Dictionary) -> void:
	_detail_tiles.clear()
	_spell_grid = null
	_clear(_detail)
	if not is_instance_valid(_tooltip_host):
		_tooltip_host = PreviewBuilders.new()
	_tooltip_host.definitions = {}
	for pair: Array in record["deck"]:
		_tooltip_host.definitions[pair[0]] = Rules.card_definition(pair[0], record.get("deck_card_definitions", {}))
	_detail_scroll.scroll_vertical = 0
	var title_row := HBoxContainer.new()
	title_row.custom_minimum_size.y = 70
	var title := _label(Rules.result_word(record), 56, Color("ddd3c4"), Typography.display_font())
	title.name = "ChronicleOutcome"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_shadow_color", Color("2b1d3d"))
	title.add_theme_constant_override("shadow_offset_y", 3)
	title_row.add_child(title)
	var score_stack := VBoxContainer.new()
	score_stack.add_theme_constant_override("separation", 0)
	score_stack.add_child(_label("SCORE", 14, Palette.GOLD_DIM, Typography.ui_font(), Rect2(), 4))
	var score := _label(Rules.Score.grouped_number(int(record["score_total"])), 44, Palette.GOLD_BRIGHT, Typography.ui_font())
	score.name = "ChronicleScore"
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	score_stack.add_child(score)
	title_row.add_child(score_stack)
	_detail.add_child(title_row)
	var subline := RichTextLabel.new()
	subline.name = "ChronicleSubline"
	subline.bbcode_enabled = true
	subline.fit_content = true
	subline.scroll_active = false
	subline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	subline.add_theme_font_override("normal_font", Typography.text_font())
	subline.add_theme_font_size_override("normal_font_size", 21)
	subline.add_theme_color_override("default_color", Palette.TEXT_2)
	var full: String = Rules.subline(record)
	var where_part: String = full.get_slice(" · %d min" % floori(float(record["run_seconds"]) / 60), 0)
	subline.text = "[color=#efe3c8]%s[/color]%s" % [_escape(where_part), _escape(full.substr(where_part.length()))]
	_detail.add_child(subline)
	var rule := Control.new()
	rule.custom_minimum_size.y = 42
	rule.draw.connect(func() -> void:
		Frame.draw_fading_line(rule, Vector2(0, 21), Vector2(rule.size.x, 21), Palette.GOLD_DIM)
		Frame.draw_diamond(rule, Vector2(4, 21), 6, Palette.GOLD)
	)
	_detail.add_child(rule)
	var path_row := HBoxContainer.new()
	path_row.name = "ChroniclePathRow"
	path_row.add_theme_constant_override("separation", BUILD_COLUMN_GAP)
	_detail.add_child(path_row)
	var path_column := VBoxContainer.new()
	path_column.name = "ChroniclePath"
	path_column.custom_minimum_size.x = PATH_COLUMN_WIDTH
	path_column.add_theme_constant_override("separation", 0)
	path_row.add_child(path_column)
	path_column.add_child(_heading("THE PATH"))
	_build_path(record, path_column)
	var feats_column := _column(path_row, "FEATS")
	feats_column.name = "ChronicleFeats"
	if (record["feats"] as Array).is_empty():
		feats_column.add_child(_label("No feats this time.", 17, Palette.TEXT_3))
	else:
		for feat: Dictionary in record["feats"]:
			var feat_row := HBoxContainer.new()
			feat_row.add_child(_label("◆", 17, Palette.GOLD))
			var text := _label("%s — %s" % [feat["title"], feat["detail"]], 17, Palette.GOLD_BRIGHT)
			text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			feat_row.add_child(text)
			feats_column.add_child(feat_row)
	_spacer(_detail, DETAIL_ROW_GAP)
	var build_row := HBoxContainer.new()
	build_row.name = "ChronicleBuildRow"
	build_row.add_theme_constant_override("separation", BUILD_COLUMN_GAP)
	_detail.add_child(build_row)
	var gear_column := _column(build_row, "GEAR")
	gear_column.name = "ChronicleGear"
	gear_column.custom_minimum_size.x = maxi(0, record["gear"].size() * 60 - 8)
	gear_column.size_flags_horizontal = Control.SIZE_FILL
	_build_items(gear_column, record["gear"], false)
	var relic_column := _column(build_row, "RELICS")
	relic_column.name = "ChronicleRelics"
	relic_column.custom_minimum_size.x = 0
	_build_items(relic_column, record["relics"], true)
	_spacer(_detail, DETAIL_ROW_GAP)
	_detail.add_child(_heading("SPELLS"))
	_spell_groups = CardTile.grouped_deck(record["deck"], _tooltip_host.definitions)
	_spell_grid = GridContainer.new()
	_spell_grid.name = "ChronicleSpells"
	_spell_grid.add_theme_constant_override("h_separation", CardTile.TILE_GAP)
	_spell_grid.add_theme_constant_override("v_separation", CardTile.TILE_GAP)
	_detail.add_child(_spell_grid)
	_refresh_spell_tiles()
	# The count pill extends below the last tile row; include that overhang in
	# scrollable content so a bottom-row count is never clipped by the viewport.
	_spacer(_detail, CardTile.BADGE_OVERLAP)
	_link_tile_focus()

func _refresh_spell_tiles() -> void:
	if not is_instance_valid(_spell_grid):
		return
	var columns: int = CardTile.columns_for_width(_detail.size.x if _detail.size.x > 0 else DETAIL_WIDTH)
	if _spell_grid.columns == columns and _spell_grid.get_child_count() > 0:
		return
	var focused_id: String = ""
	var focus: Control = get_viewport().gui_get_focus_owner()
	if focus is CardTile:
		focused_id = focus.name
		_clear_focus_tooltip()
	_clear(_spell_grid)
	_spell_grid.columns = columns
	var shown: int = CardTile.shown_count(_spell_groups.size(), columns)
	for index: int in range(shown):
		var group: Dictionary = _spell_groups[index]
		var tile := CardTile.new()
		tile.name = "Spell_" + str(group["id"])
		tile.configure(group["id"], group["count"], group["definition"])
		_tooltip_host.definitions[group["id"]] = tile.card_definition
		tile.tooltip_builder = _tooltip_host.card_tooltip
		_add_spell_tile(tile)
	if shown < _spell_groups.size():
		var overflow := CardTile.new()
		overflow.name = "ChronicleSpellsOverflow"
		overflow.configure_overflow(_spell_groups.slice(shown))
		_add_spell_tile(overflow)
	_link_tile_focus()
	if not focused_id.is_empty():
		var replacement: Control = _spell_grid.get_node_or_null(NodePath(focused_id))
		if replacement == null:
			replacement = _spell_grid.get_child(_spell_grid.get_child_count() - 1)
		replacement.grab_focus()

func _add_spell_tile(tile: Control) -> void:
	tile.socket_ink = TILE_INK
	tile.socket_edge = TILE_EDGE
	tile.focus_entered.connect(_show_focus_tooltip.bind(tile))
	tile.focus_exited.connect(_clear_focus_tooltip)
	_spell_grid.add_child(tile)

func _link_tile_focus() -> void:
	_detail_tiles.clear()
	var path_tiles: Array[Node] = _detail.find_children("PathSection*Room*", "Button", true, false)
	for prefix: String in ["Gear_", "Relic_", "Spell_", "ChronicleSpellsOverflow"]:
		for tile: Node in _detail.find_children(prefix + "*", "Button", true, false):
			_detail_tiles.append(tile as Control)
	for index: int in range(_detail_tiles.size()):
		var tile: Control = _detail_tiles[index]
		var before: Control = _detail_tiles[index - 1] if index > 0 else _rows.get_child(selected_index)
		if index == 0 and not path_tiles.is_empty():
			before = path_tiles.back() as Control
		var after: Control = _detail_tiles[index + 1] if index + 1 < _detail_tiles.size() else _close
		tile.focus_previous = tile.get_path_to(before)
		tile.focus_next = tile.get_path_to(after)
		tile.focus_neighbor_left = tile.focus_previous
		tile.focus_neighbor_right = tile.focus_next
		tile.focus_neighbor_top = tile.focus_previous
		tile.focus_neighbor_bottom = tile.focus_next
	if not _detail_tiles.is_empty() or not path_tiles.is_empty():
		var row: Control = _rows.get_child(selected_index)
		var first: Control = _detail_tiles[0] if not _detail_tiles.is_empty() else path_tiles[0] as Control
		row.focus_neighbor_right = row.get_path_to(first)
		row.focus_next = row.focus_neighbor_right
		# Path icons remain keyboard/controller reachable before the build chain.
		for index: int in range(path_tiles.size()):
			var tile: Control = path_tiles[index] as Control
			var before: Control = path_tiles[index - 1] as Control if index > 0 else row
			var after: Control = path_tiles[index + 1] as Control if index + 1 < path_tiles.size() else (_detail_tiles[0] if not _detail_tiles.is_empty() else _close)
			tile.focus_previous = tile.get_path_to(before)
			tile.focus_next = tile.get_path_to(after)
			tile.focus_neighbor_left = tile.focus_previous
			tile.focus_neighbor_right = tile.focus_next
			tile.focus_neighbor_top = tile.focus_previous
			tile.focus_neighbor_bottom = tile.focus_next
		if not path_tiles.is_empty():
			row.focus_next = row.get_path_to(path_tiles[0])

func _build_path(record: Dictionary, parent: VBoxContainer) -> void:
	var path: Array = record["path"]
	for index: int in range(path.size()):
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 0)
		parent.add_child(row)
		var section_name: String = str(record["section_names"][index]) if index < record["section_names"].size() else Rules.TODO_DESIGN_SECTION_NAME
		var section := _label("%s · %s" % [Rules.Score.roman(index + 1), section_name], 16, Palette.TEXT_2)
		section.custom_minimum_size.x = 150
		section.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		section.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(section)
		var steps := GridContainer.new()
		steps.columns = 16
		steps.add_theme_constant_override("h_separation", 6)
		steps.add_theme_constant_override("v_separation", 6)
		row.add_child(steps)
		for step: int in range((path[index] as Array).size()):
			var kind: String = str(path[index][step])
			var dragon: bool = kind in ["boss", "dragon"]
			var ended_here: bool = index == path.size() - 1 and step == path[index].size() - 1
			var icon := RecordIcon.new()
			icon.name = "PathSection%dRoom%d" % [index, step]
			icon.round_room = true
			icon.terminal_defeat = ended_here and record["outcome"] == "defeat"
			icon.ring = Palette.DANGER if icon.terminal_defeat else (Palette.GOLD if dragon or (ended_here and record["outcome"] == "embrace") else TILE_EDGE)
			var boss_id: String = str(record["dragon_ids"][index]) if index < record["dragon_ids"].size() else ""
			var icon_id: String = "boss_" + boss_id if dragon else str({"hearth": "campfire", "relic": "treasure", "mystery": "event"}.get(kind, kind))
			var guardian: Dictionary = Guardians.for_boss(boss_id) if kind == "guardian" else {}
			if kind == "guardian" and not str(guardian.get("id", "")).is_empty():
				icon_id = "guardian_" + str(guardian["id"])
			icon.texture = Icons.icon_texture(icon_id)
			icon.tooltip_title = Rules.Score.dragon_name(boss_id) if dragon else str({"combat": "Standard combat", "guardian": "Guardian combat", "event": "Event", "scavenger": "Scavenger", "graftwright": "Graftwright", "treasure": "Relic", "relic": "Relic", "campfire": "Ember Hearth", "hearth": "Ember Hearth"}.get(kind, kind))
			if kind.begins_with("special_"):
				icon.tooltip_title = str(Specials.definition(kind.trim_prefix("special_")).get("name", "ERROR_MISSING_SPECIAL_NAME"))
			if not guardian.is_empty():
				icon.tooltip_title = "%s · Guardian combat" % str(guardian["name"])
			_configure_icon(icon, 34 if icon.terminal_defeat or not dragon else 44)
			steps.add_child(icon)
		_spacer(parent, 8)

func _build_items(parent: Node, ids: Array, relics: bool) -> void:
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	parent.add_child(flow)
	for id: String in ids:
		var data: Dictionary = GameData.relic_def(id) if relics else GameData.equipment_def(id)
		var icon := RecordIcon.new()
		icon.name = ("Relic_" if relics else "Gear_") + id
		icon.texture = Assets.load_texture(str(data.get("icon_path", "")))
		icon.tooltip_title = str(data.get("name", id))
		if relics:
			icon.tooltip_body.append(str(data.get("description", "")))
			icon.tooltip_builder = _relic_tooltip.bind(id)
		else:
			icon.equipment_id = id
			icon.tooltip_body.append("%s | %s" % [GameData.equipment_slot(id).capitalize(), GameData.equipment_rarity(id).capitalize()])
			icon.tooltip_builder = _tooltip_host.equipment_tooltip.bind(id)
		_configure_icon(icon, 52)
		flow.add_child(icon)

func _relic_tooltip(id: String) -> Control:
	return PreviewBuilders.relic_tooltip(id)

func _configure_icon(icon: RecordIcon, extent: int) -> void:
	icon.custom_minimum_size = Vector2.ONE * extent
	icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.tooltip_text = icon.tooltip_title
	icon.mouse_default_cursor_shape = Control.CURSOR_HELP
	for state: String in ["normal", "hover", "pressed", "focus"]:
		icon.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	icon.mouse_entered.connect(icon.queue_redraw)
	icon.mouse_exited.connect(icon.queue_redraw)
	icon.focus_entered.connect(_show_focus_tooltip.bind(icon))
	icon.focus_exited.connect(_clear_focus_tooltip)
	icon.focus_entered.connect(icon.queue_redraw)
	icon.focus_exited.connect(icon.queue_redraw)

func _show_focus_tooltip(icon: Control) -> void:
	_clear_focus_tooltip()
	_focus_tooltip = icon._make_custom_tooltip(icon.tooltip_text) as Control
	if _focus_tooltip == null:
		return
	_focus_tooltip.z_index = 100
	_focus_tooltip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_focus_anchor = icon
	add_child(_focus_tooltip)
	call_deferred("_position_focus_tooltip")

func _position_focus_tooltip() -> void:
	if not is_instance_valid(_focus_tooltip) or not is_instance_valid(_focus_anchor):
		return
	_focus_tooltip.global_position = focus_tooltip_position(_focus_anchor.get_global_rect(), _focus_tooltip.size, get_global_rect())

static func focus_tooltip_position(anchor: Rect2, extent: Vector2, bounds: Rect2) -> Vector2:
	var x: float = clampf(anchor.position.x, bounds.position.x, bounds.end.x - extent.x)
	var y: float = clampf(anchor.position.y, bounds.position.y, bounds.end.y - extent.y)
	var candidates: Array[Vector2] = [Vector2(x, anchor.end.y), Vector2(x, anchor.position.y - extent.y), Vector2(anchor.end.x, y), Vector2(anchor.position.x - extent.x, y)]
	for at: Vector2 in candidates:
		if bounds.encloses(Rect2(at, extent)):
			return at
	# If no side has room, keep the entire preview on screen.
	return Vector2(x, y)

func _clear_focus_tooltip() -> void:
	if is_instance_valid(_focus_tooltip):
		_focus_tooltip.queue_free()
	_focus_tooltip = null
	_focus_anchor = null

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var router: Node = get_node_or_null("/root/InputRouter")
	if router != null:
		router.call("record_input_activity", event)
	if event.is_action_pressed(Router.ACTION_CANCEL) or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
		return
	var focused: Control = get_viewport().gui_get_focus_owner()
	# Let native keyboard/D-pad focus traverse the detail controls. History
	# selection and bumper paging stay on the list; analog movement uses the
	# same explicit neighbor paths as the native actions.
	if focused != null and _detail.is_ancestor_of(focused):
		if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
			var next: int = int(signf(event.axis_value)) if absf(event.axis_value) >= Router.JOYSTICK_ACTIVITY_THRESHOLD else 0
			if next != 0 and next != _stick_direction:
				var target: NodePath = focused.focus_next if next > 0 else focused.focus_previous
				if not target.is_empty():
					(focused.get_node(target) as Control).grab_focus()
			_stick_direction = next
			get_viewport().set_input_as_handled()
		return
	var direction: int = 0
	if event.is_action_pressed("ui_up", true):
		direction = -1
	elif event.is_action_pressed("ui_down", true):
		direction = 1
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y:
		var next_direction: int = int(signf(event.axis_value)) if absf(event.axis_value) >= Router.JOYSTICK_ACTIVITY_THRESHOLD else 0
		direction = next_direction if next_direction != _stick_direction else 0
		_stick_direction = next_direction
		get_viewport().set_input_as_handled()
	var page: int = maxi(1, floori(_list.size.y / ROW_HEIGHT))
	if event is InputEventJoypadButton and event.is_action_pressed(Router.ACTION_HAND_PREVIOUS):
		direction = -page
	elif event is InputEventJoypadButton and event.is_action_pressed(Router.ACTION_HAND_NEXT):
		direction = page
	if direction != 0:
		select_record(selected_index + direction, true)
		get_viewport().set_input_as_handled()

func _column(parent: Node, heading: String) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = COLUMN_WIDTH
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", 0)
	parent.add_child(column)
	column.add_child(_heading(heading))
	return column

func _heading(text: String) -> Label:
	var label := _label(text, 14, Palette.GOLD_DIM, Typography.ui_font(), Rect2(), 4)
	label.custom_minimum_size.y = 28
	return label

func _label(text: String, font_size: int, color: Color, font: Font = null, rect: Rect2 = Rect2(), spacing: int = 0) -> Label:
	var label := Label.new()
	label.text = text
	label.position = rect.position
	label.size = rect.size
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var selected_font: Font = Typography.text_font() if font == null else font
	if spacing > 0:
		var spaced := FontVariation.new()
		spaced.base_font = selected_font
		spaced.spacing_glyph = spacing
		selected_font = spaced
	label.add_theme_font_override("font", selected_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _spacer(parent: Node, height: float) -> void:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(spacer)

func _clear(parent: Node) -> void:
	for child: Node in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

func _escape(text: String) -> String:
	return text.replace("[", "[lb]")

func _play_page_sound(cue: String) -> void:
	var entry: Dictionary = RunSfx.entry(cue)
	if _page_sound == null:
		_page_sound = AudioStreamPlayer.new()
		add_child(_page_sound)
	_page_sound.bus = str(entry["bus"])
	_page_sound.volume_db = float(entry["volume_db"])
	_page_sound.stream = Assets.load_audio_stream(str(entry["path"]))
	_page_sound.play()
