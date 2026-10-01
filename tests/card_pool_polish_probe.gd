extends SceneTree

# Real-renderer card-face proof for the card pool polish pass (1920x1080,
# 100% UI scale). Run through tools/visual_probe_runner.py.
#   LABYRINTH_POLISH_MODE=all    every live card at its real 250x352 size
#   LABYRINTH_POLISH_MODE=focus  Rite and condition cards at hand (172/208),
#                                native (250) and reward (292) sizes, built
#                                with RunScene's own scaled card slots
#   LABYRINTH_POLISH_TAG=<name>  fresh versioned output folder
#   LABYRINTH_POLISH_IDS=a,b     limit either mode to these card ids
# Every rendered card is also audited: each summary leaf (icon, value, label,
# rules text) must sit on the parchment, inside the frame border, and no chip
# may print a float ("4.0") or an empty row.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const UiTypographyScript = preload("res://scripts/ui_typography.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const NATIVE_SIZE := Vector2(250.0, 352.0)
# Parchment interior of the 250x352 frame art (local widget units).
# The frame art's light parchment starts ~37 px in; 40 leaves a comfortable rim.
const PARCHMENT_LEFT: float = 37.0
const PARCHMENT_RIGHT: float = 213.0
const PARCHMENT_BOTTOM: float = 322.0
const COMFORT_LEFT: float = 40.0
const COMFORT_RIGHT: float = 210.0
const FOCUS_CARD_IDS: Array[String] = [
	"rite_of_the_pyre", "salamander_heart", "rite_of_hoarfrost", "rite_of_the_storm",
	"tempest_form", "rite_of_tailwinds", "rite_of_the_mountain", "rite_of_noon",
	"thorn_crown_pact", "hallowed_strike", "sunlance", "blinding_bash",
	"dazzle", "butcher_chop", "scorch", "thorn_skewer",
	"tectonic_maul", "polar_guard", "worldroot_stride", "spike_mantle",
	"static_lash", "stonefist", "couched_lance", "iron_wheel",
]
const FOCUS_WIDTHS: Array[float] = [172.0, 208.0, 292.0]

var _run_scene: Node
var _sheet_nodes: Array[Node] = []
var _output_dir: String = ""
var _audit: Array[Dictionary] = []
var _failed: bool = false
var _focus_ids: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	var tag: String = OS.get_environment("LABYRINTH_POLISH_TAG").strip_edges()
	if tag.is_empty():
		tag = "v1"
	var mode: String = OS.get_environment("LABYRINTH_POLISH_MODE").strip_edges()
	if mode.is_empty():
		mode = "focus"
	_output_dir = "user://probes/card_pool_polish/%s_%s" % [tag, mode]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_output_dir))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		push_error("Card polish probe requires RunScene")
		quit(1)
		return
	_run_scene = packed.instantiate()
	root.add_child(_run_scene)
	if _run_scene is CanvasItem:
		(_run_scene as CanvasItem).visible = false
	_hide_canvas_layers(_run_scene)
	# Keep the software cursor glyph out of the card sheets.
	var cursor_feedback: Node = root.get_node_or_null("CursorFeedback")
	if cursor_feedback != null and cursor_feedback.has_method("set_glyph_visibility_suppressed"):
		cursor_feedback.call("set_glyph_visibility_suppressed", "card_pool_polish_probe", true)
	if DisplayServer.get_name() == "headless":
		push_error("Card polish probe requires a real renderer")
		quit(1)
		return
	var requested_ids: Array[String] = _requested_card_ids()
	_focus_ids = FOCUS_CARD_IDS.duplicate()
	if not requested_ids.is_empty():
		_focus_ids = requested_ids
	if mode == "all":
		var live_ids: Array[String] = _live_card_ids()
		if not requested_ids.is_empty():
			live_ids = requested_ids
		var per_sheet: int = 12
		var sheet_count: int = ceili(float(live_ids.size()) / float(per_sheet))
		for sheet_index: int in range(sheet_count):
			await _capture_native_sheet(live_ids, sheet_index, per_sheet, sheet_count)
	else:
		var per_sheet: int = 4
		var sheet_count: int = ceili(float(_focus_ids.size()) / float(per_sheet))
		for sheet_index: int in range(sheet_count):
			await _capture_focus_sheet(sheet_index, per_sheet, sheet_count)
	_write_audit()
	print(ProjectSettings.globalize_path(_output_dir))
	quit(1 if _failed else 0)


func _live_card_ids() -> Array[String]:
	var ids: Array[String] = []
	var cards: Dictionary = GameData.cards()
	for card_id_var: Variant in cards.keys():
		var card: Dictionary = cards[card_id_var] as Dictionary
		if bool(card.get("retired", false)):
			continue
		ids.append(str(card_id_var))
	ids.sort()
	return ids


func _requested_card_ids() -> Array[String]:
	var ids: Array[String] = []
	for id_text: String in OS.get_environment("LABYRINTH_POLISH_IDS").split(",", false):
		var card_id: String = id_text.strip_edges()
		if GameData.cards().has(card_id):
			ids.append(card_id)
		elif not card_id.is_empty():
			push_error("Unknown card id %s" % card_id)
			_failed = true
	return ids


func _hide_canvas_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_canvas_layers(child)


func _sheet_background(heading_text: String) -> void:
	var background := ColorRect.new()
	background.color = Color("17110d")
	background.position = Vector2.ZERO
	background.size = Vector2(VIEWPORT_SIZE)
	background.z_index = -10
	root.add_child(background)
	_sheet_nodes.append(background)
	var heading := Label.new()
	heading.text = heading_text
	heading.position = Vector2(0.0, 22.0)
	heading.size = Vector2(1920.0, 36.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("dbc39a"))
	root.add_child(heading)
	_sheet_nodes.append(heading)


func _caption(text: String, position: Vector2, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.size = Vector2(width, 24.0)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color("a99678"))
	root.add_child(label)
	_sheet_nodes.append(label)


func _configured_widget(card_id: String) -> CardWidget:
	var widget: CardWidget = CardWidgetScene.instantiate()
	var display: Dictionary = _run_scene.call("_card_widget_display", card_id, {})
	widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
	widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	return widget


func _capture_native_sheet(card_ids: Array[String], sheet_index: int, per_sheet: int, sheet_count: int) -> void:
	_sheet_background("ALL LIVE CARDS · %d/%d · ACTUAL 250×352 SIZE" % [sheet_index + 1, sheet_count])
	var widgets: Array[Dictionary] = []
	var start_index: int = sheet_index * per_sheet
	var end_index: int = mini(start_index + per_sheet, card_ids.size())
	for card_index: int in range(start_index, end_index):
		var local_index: int = card_index - start_index
		var column: int = local_index % 6
		var row: int = local_index / 6
		var origin := Vector2(57.0 + float(column) * 306.0, 76.0 + float(row) * 498.0)
		var slot := Control.new()
		slot.position = origin
		slot.size = NATIVE_SIZE
		root.add_child(slot)
		_sheet_nodes.append(slot)
		var card_id: String = card_ids[card_index]
		var widget: CardWidget = _configured_widget(card_id)
		widget.custom_minimum_size = NATIVE_SIZE
		widget.size = NATIVE_SIZE
		slot.add_child(widget)
		_caption(card_id, origin + Vector2(0.0, NATIVE_SIZE.y + 8.0), NATIVE_SIZE.x)
		widgets.append({"card_id": card_id, "widget": widget, "size": 250})
	await _settle_and_save("cards_%02d.png" % (sheet_index + 1), widgets)


func _capture_focus_sheet(sheet_index: int, per_sheet: int, sheet_count: int) -> void:
	_sheet_background("RITE AND CONDITION CARDS · %d/%d · HAND 172 / 208 · REWARD 292 (RUNSCENE SCALED SLOTS)" % [sheet_index + 1, sheet_count])
	var widgets: Array[Dictionary] = []
	var start_index: int = sheet_index * per_sheet
	var end_index: int = mini(start_index + per_sheet, _focus_ids.size())
	for card_index: int in range(start_index, end_index):
		var local_index: int = card_index - start_index
		var group_x: float = 120.0 + float(local_index % 2) * 880.0
		var group_y: float = 70.0 + float(local_index / 2) * 500.0
		var cursor_x: float = group_x
		var card_id: String = _focus_ids[card_index]
		for width: float in FOCUS_WIDTHS:
			var card_size: Vector2 = _run_scene.call("_card_size_from_width", width)
			var widget: CardWidget = _configured_widget(card_id)
			var slot: Control = _run_scene.call("_scaled_card_slot", widget, card_size)
			slot.position = Vector2(cursor_x, group_y + (411.0 - card_size.y))
			root.add_child(slot)
			_sheet_nodes.append(slot)
			_caption("%s · %d" % [card_id, int(width)], Vector2(cursor_x, group_y + 418.0), card_size.x)
			widgets.append({"card_id": card_id, "widget": widget, "size": int(width)})
			cursor_x += card_size.x + 24.0
	await _settle_and_save("focus_%02d.png" % (sheet_index + 1), widgets)


func _settle_and_save(file_name: String, widgets: Array[Dictionary]) -> void:
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	RenderingServer.force_draw()
	await process_frame
	for entry: Dictionary in widgets:
		_audit_widget(entry.get("widget") as CardWidget, str(entry.get("card_id", "")), int(entry.get("size", 250)), file_name)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	if image.save_png("%s/%s" % [_output_dir, file_name]) != OK:
		push_error("Could not save %s" % file_name)
		_failed = true
	for node: Node in _sheet_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_sheet_nodes.clear()
	await process_frame


func _audit_widget(widget: CardWidget, card_id: String, size_label: int, sheet: String) -> void:
	if widget == null:
		return
	var issues: PackedStringArray = []
	var to_local: Transform2D = widget.get_global_transform().affine_inverse()
	var summary: Control = widget.get("_summary_icon_box") as Control
	var desc: Control = widget.get("desc_label") as Control
	var leaves: Array[Control] = []
	if summary != null and summary.visible:
		_collect_leaves(summary, leaves)
		for row: Node in summary.get_children():
			if row is Control and (row as Control).visible and (row as Control).get_child_count() == 0:
				issues.append("empty row")
	if desc != null and desc.visible and not str(desc.get("text")).strip_edges().is_empty():
		leaves.append(desc)
	if (summary == null or not summary.visible) and (desc == null or not desc.visible):
		issues.append("no rules content")
	for leaf: Control in leaves:
		var rect: Rect2 = _local_rect(to_local, leaf)
		var text: String = _leaf_text(leaf)
		var name_text: String = text if not text.is_empty() else leaf.name
		if OS.get_environment("LABYRINTH_POLISH_DEBUG") == card_id:
			var font_size: int = leaf.get_theme_font_size("normal_font_size") if leaf is RichTextLabel else leaf.get_theme_font_size("font_size")
			print("LEAF %s @%d %s %s font=%d" % [card_id, size_label, name_text, str(rect), font_size])
		if rect.position.x < PARCHMENT_LEFT - 0.5 or rect.end.x > PARCHMENT_RIGHT + 0.5:
			issues.append("x-overflow %s [%.1f..%.1f]" % [name_text, rect.position.x, rect.end.x])
		elif rect.position.x < COMFORT_LEFT - 0.5 or rect.end.x > COMFORT_RIGHT + 0.5:
			issues.append("near-edge %s [%.1f..%.1f]" % [name_text, rect.position.x, rect.end.x])
		if rect.end.y > PARCHMENT_BOTTOM + 0.5:
			issues.append("y-overflow %s [bottom %.1f]" % [name_text, rect.end.y])
		if leaf is Label and (leaf as Label).autowrap_mode != TextServer.AUTOWRAP_OFF:
			issues.append_array(_wrapped_line_issues(leaf as Label, to_local))
		if leaf is Label:
			var regex := RegEx.new()
			regex.compile("\\d\\.\\d")
			if regex.search(text) != null:
				issues.append("float text '%s'" % text)
			if text in ["0", "+0", "-0"]:
				issues.append("zero value")
	var entry: Dictionary = {"card_id": card_id, "size": size_label, "sheet": sheet, "issues": Array(issues)}
	_audit.append(entry)
	if not issues.is_empty():
		print("AUDIT %s @%d: %s" % [card_id, size_label, "; ".join(issues)])


# The light parchment narrows toward its torn lower edge (the contiguous span
# brighter than the shaded rim, measured from the frame art in 250x352 local
# units). Each wrapped rules line must sit on it.
func _parchment_span(y: float) -> Vector2:
	if y < 260.0:
		return Vector2(40.0, 211.0)
	if y < 278.0:
		return Vector2(44.0, 204.0)
	if y < 290.0:
		return Vector2(48.0, 203.0)
	if y < 296.0:
		return Vector2(57.0, 199.0)
	if y < 302.0:
		return Vector2(62.0, 196.0)
	return Vector2(125.0, 125.0)


func _wrapped_line_issues(label: Label, to_local: Transform2D) -> PackedStringArray:
	var issues := PackedStringArray()
	var font: Font = label.get_theme_font("font")
	var font_size: int = label.get_theme_font_size("font_size")
	if font == null or label.text.is_empty():
		return issues
	var paragraph := TextParagraph.new()
	paragraph.add_string(label.text, font, font_size)
	paragraph.width = label.size.x
	paragraph.break_flags = TextServer.BREAK_MANDATORY | TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	var xform: Transform2D = to_local * label.get_global_transform()
	var line_top: float = 0.0
	var line_spacing: float = float(label.get_theme_constant("line_spacing"))
	for line: int in range(paragraph.get_line_count()):
		var line_size: Vector2 = paragraph.get_line_size(line)
		var left: float = (label.size.x - line_size.x) * 0.5
		var middle: Vector2 = xform * Vector2(left, line_top + line_size.y * 0.5)
		var right: Vector2 = xform * Vector2(left + line_size.x, line_top + line_size.y * 0.5)
		var span: Vector2 = _parchment_span(middle.y)
		if middle.x < span.x - 1.0 or right.x > span.y + 1.0:
			issues.append("rules line %d off parchment [%.1f..%.1f at y %.1f]" % [line + 1, middle.x, right.x, middle.y])
		line_top += line_size.y + line_spacing
	return issues


func _collect_leaves(node: Node, leaves: Array[Control]) -> void:
	for child: Node in node.get_children():
		if not (child is Control) or not (child as Control).visible:
			continue
		var control: Control = child as Control
		if control is Label or control is TextureRect or control is RichTextLabel or control.get_child_count() == 0:
			leaves.append(control)
			continue
		_collect_leaves(control, leaves)


func _leaf_text(leaf: Control) -> String:
	if leaf is Label:
		return (leaf as Label).text
	if leaf is RichTextLabel:
		return (leaf as RichTextLabel).get_parsed_text()
	return ""


func _local_rect(to_local: Transform2D, control: Control) -> Rect2:
	var xform: Transform2D = to_local * control.get_global_transform()
	var box := Rect2(Vector2.ZERO, control.size)
	if control is RichTextLabel:
		# Rules text wraps inside its stylebox content margins.
		var text_label: RichTextLabel = control as RichTextLabel
		var style: StyleBox = text_label.get_theme_stylebox("normal")
		var left: float = style.content_margin_left if style != null else 0.0
		var right: float = style.content_margin_right if style != null else 0.0
		var top: float = style.content_margin_top if style != null and style.content_margin_top > 0.0 else 0.0
		box = Rect2(Vector2(left, top), Vector2(maxf(0.0, control.size.x - left - right), float(text_label.get_content_height())))
	var rect := Rect2(xform * box.position, Vector2.ZERO)
	rect = rect.expand(xform * Vector2(box.end.x, box.position.y))
	rect = rect.expand(xform * Vector2(box.position.x, box.end.y))
	rect = rect.expand(xform * box.end)
	# Labels report their box; measure centred text by its rendered line width.
	if control is Label and not (control as Label).text.is_empty() and (control as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		var label: Label = control as Label
		var font: Font = label.get_theme_font("font")
		var font_size: int = label.get_theme_font_size("font_size")
		if font != null:
			var text_width: float = font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x * absf(xform.get_scale().x)
			if text_width < rect.size.x:
				var inset: float = (rect.size.x - text_width) * (0.5 if label.horizontal_alignment == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
				rect = Rect2(rect.position.x + inset, rect.position.y, text_width, rect.size.y)
	return rect


func _write_audit() -> void:
	var flagged: Array[Dictionary] = []
	for entry: Dictionary in _audit:
		if not (entry.get("issues", []) as Array).is_empty():
			flagged.append(entry)
	var file := FileAccess.open(ProjectSettings.globalize_path(_output_dir.path_join("audit.json")), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"audited": _audit.size(), "flagged": flagged}, "\t"))
		file.close()
	print("CARD POLISH AUDIT: %d card faces, %d flagged" % [_audit.size(), flagged.size()])
