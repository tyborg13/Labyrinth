extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")

const OUTPUT_DIR: String = "user://probes/flurry_card_pack"
const CARD_IDS: Array[String] = [
	"windlass_volley",
	"crank_reload",
	"blade_dance",
	"gathering_rhythm",
	"cinder_fusillade",
	"storm_salvo",
	"razor_gale"
]

var _run_scene: Node
var _proof_nodes: Array[Node] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://labyrinth_progression_flurry_card_pack_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_flurry_card_pack_probe.save")
	ProgressionStore.clear_saved_run()
	DisplayServer.window_set_size(Vector2i(1280, 800))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		push_error("Run scene should load for Flurry card-pack proof.")
		quit(1)
		return
	_run_scene = packed.instantiate()
	root.add_child(_run_scene)
	if _run_scene is CanvasItem:
		(_run_scene as CanvasItem).visible = false
	_hide_canvas_layers(_run_scene)
	await process_frame
	await process_frame
	await _capture_card_widgets()
	_clear_proof_nodes()
	await process_frame
	await _capture_character_badges()
	_run_scene.queue_free()
	await process_frame
	quit()

func _hide_canvas_layers(node: Node) -> void:
	for child: Node in node.get_children():
		if child is CanvasLayer:
			(child as CanvasLayer).visible = false
		_hide_canvas_layers(child)

func _capture_card_widgets() -> void:
	_add_background(Color("18110d"))
	for index: int in range(CARD_IDS.size()):
		var card_id: String = CARD_IDS[index]
		var column: int = index % 4
		var row: int = index / 4
		var position := Vector2(58.0 + float(column) * 304.0, 34.0 + float(row) * 382.0)
		var slot := Control.new()
		slot.position = position
		slot.custom_minimum_size = Vector2(250.0, 352.0)
		slot.size = Vector2(250.0, 352.0)
		root.add_child(slot)
		_proof_nodes.append(slot)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = Vector2(250.0, 352.0)
		widget.size = Vector2(250.0, 352.0)
		slot.add_child(widget)
		var display: Dictionary = _run_scene.call("_card_widget_display", card_id, {})
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		widget.set_display_overrides(str(display.get("summary_bbcode", "")), display.get("modifier_lines", []), display.get("summary_rows", []))
	await _settle_render()
	var output_path: String = "%s/flurry_cards_%d.png" % [OUTPUT_DIR, int(Time.get_unix_time_from_system())]
	_save_root_screenshot(output_path)
	print(ProjectSettings.globalize_path(output_path))

func _capture_character_badges() -> void:
	_add_background(Color("11181b"))
	var title := Label.new()
	title.text = "FLURRY GEAR + MAGICK BADGES"
	title.position = Vector2(52.0, 34.0)
	title.size = Vector2(1176.0, 38.0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color("ead8ba"))
	root.add_child(title)
	_proof_nodes.append(title)
	for index: int in range(CARD_IDS.size()):
		var card_id: String = CARD_IDS[index]
		var card: Dictionary = GameData.card_def(card_id)
		var accent: Color = ElementData.accent(GameData.card_element(card_id))
		if GameData.card_element(card_id) == ElementData.NONE:
			accent = Color(str(card.get("accent", "#8f9499")))
		var badge: Control
		if bool(card.get("reward_pool", true)):
			badge = _run_scene.call("_build_magic_card_tile", card_id, "attuned", index) as Control
		else:
			badge = _run_scene.call("_build_equipment_card_badge", card_id, accent) as Control
		if badge == null:
			continue
		var column: int = index % 2
		var row: int = index / 2
		badge.position = Vector2(94.0 + float(column) * 598.0, 104.0 + float(row) * 158.0)
		root.add_child(badge)
		_proof_nodes.append(badge)
	await _settle_render()
	var output_path: String = "%s/flurry_badges_%d.png" % [OUTPUT_DIR, int(Time.get_unix_time_from_system())]
	_save_root_screenshot(output_path)
	print(ProjectSettings.globalize_path(output_path))

func _add_background(color: Color) -> void:
	var background := ColorRect.new()
	background.color = color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.z_index = -10
	root.add_child(background)
	_proof_nodes.append(background)

func _settle_render() -> void:
	await process_frame
	await process_frame
	await create_timer(0.20).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.save_png(output_path) != OK:
		push_error("Failed to save Flurry proof screenshot: %s" % output_path)

func _clear_proof_nodes() -> void:
	for node: Node in _proof_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_proof_nodes.clear()
