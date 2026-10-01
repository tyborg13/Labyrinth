extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const ManeuverSuite = preload("res://tests/suites/maneuver_suite.gd")

const OUTPUT_DIR := "user://probes/maneuver_cards"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
var CARD_IDS: Array[String] = []

var _run_scene: Node
var _sheet_nodes: Array[Node] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	# Wave-4 family B fixture cards (tests/suites/maneuver_suite.gd), card rows only.
	ManeuverSuite._install_fixtures()
	for card_id: String in ManeuverSuite.FIXTURES.keys():
		CARD_IDS.append(card_id)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		push_error("Maneuver contact sheet requires RunScene")
		quit(1)
		return
	_run_scene = packed.instantiate()
	root.add_child(_run_scene)
	if _run_scene is CanvasItem:
		(_run_scene as CanvasItem).visible = false
	_hide_canvas_layers(_run_scene)
	for sheet_index: int in range(ceili(float(CARD_IDS.size()) / 8.0)):
		await _capture_sheet(sheet_index)
		_clear_sheet()
		await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()


func _hide_canvas_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_canvas_layers(child)


func _capture_sheet(sheet_index: int) -> void:
	var background := ColorRect.new()
	background.color = Color("17110d")
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.z_index = -10
	root.add_child(background)
	_sheet_nodes.append(background)
	var heading := Label.new()
	heading.text = "WAVE-4 FAMILY B FIXTURE CARDS · %d/%d · ACTUAL 250×352 SIZE" % [sheet_index + 1, ceili(float(CARD_IDS.size()) / 8.0)]
	heading.position = Vector2(0.0, 38.0)
	heading.size = Vector2(1920.0, 36.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 22)
	heading.add_theme_color_override("font_color", Color("dbc39a"))
	root.add_child(heading)
	_sheet_nodes.append(heading)
	var start_index: int = sheet_index * 8
	var end_index: int = mini(start_index + 8, CARD_IDS.size())
	for card_index: int in range(start_index, end_index):
		var local_index: int = card_index - start_index
		var column: int = local_index % 4
		var row: int = local_index / 4
		var slot := Control.new()
		slot.position = Vector2(292.0 + float(column) * 340.0, 118.0 + float(row) * 440.0)
		slot.size = Vector2(250.0, 352.0)
		root.add_child(slot)
		_sheet_nodes.append(slot)
		var card_id: String = CARD_IDS[card_index]
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = Vector2(250.0, 352.0)
		widget.size = Vector2(250.0, 352.0)
		slot.add_child(widget)
		var display: Dictionary = _run_scene.call("_card_widget_display", card_id, {})
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	RenderingServer.force_draw()
	await process_frame
	if DisplayServer.get_name() == "headless":
		push_error("Maneuver contact sheet requires a real renderer")
		quit(1)
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path: String = "%s/cards_%02d.png" % [OUTPUT_DIR, sheet_index + 1]
	if image.save_png(output_path) != OK:
		push_error("Could not save %s" % output_path)
		quit(1)


func _clear_sheet() -> void:
	for node: Node in _sheet_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_sheet_nodes.clear()
