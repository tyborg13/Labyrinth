extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const GameData = preload("res://scripts/game_data.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const CardWidgetScene = preload("res://scenes/card_widget.tscn")
const RunSceneScript = preload("res://scripts/run_scene.gd")

const OUTPUT_DIR: String = "user://probes/item_card_art"
const PRODUCTION_SIZE: Vector2i = Vector2i(1920, 1080)
const CARD_IDS: Array = [
	"crimson_draught",
	"mossglass_elixir",
	"nail_bomb",
	"pitch_firebomb",
	"frost_snare",
	"storm_jar",
	"smoke_bomb",
	"jaw_trap",
	"bone_ward_charm",
	"grave_dust_satchel",
]

var _errors: Array[String] = []
var _stamp: int = 0


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_stamp = int(Time.get_unix_time_from_system())
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await _capture_full_cards()
	await _capture_compact_badges()
	if _errors.is_empty():
		print("ITEM CARD ART VISUAL PROBE: PASS")
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
	else:
		for message: String in _errors:
			push_error(message)
		print("ITEM CARD ART VISUAL PROBE: FAIL (%d errors)" % _errors.size())
		quit(1)


func _capture_full_cards() -> void:
	var viewport: SubViewport = _production_viewport()
	var background: ColorRect = _background(Color("17110d"))
	viewport.add_child(background)
	_add_heading(background, "ITEM CARD ART — ACTUAL 250×352 CARDWIDGETS", 28.0)
	var configured_widgets: Array = []
	for index: int in range(CARD_IDS.size()):
		var card_id: String = str(CARD_IDS[index])
		var column: int = index % 5
		var row: int = index / 5
		var slot := Control.new()
		slot.position = Vector2(271.0 + float(column) * 282.0, 105.0 + float(row) * 440.0)
		slot.custom_minimum_size = Vector2(250.0, 352.0)
		slot.size = Vector2(250.0, 352.0)
		background.add_child(slot)
		var widget: CardWidget = CardWidgetScene.instantiate()
		widget.custom_minimum_size = Vector2(250.0, 352.0)
		widget.size = Vector2(250.0, 352.0)
		slot.add_child(widget)
		widget.configure(card_id, false, false, true, false, false, true, GameData.card_def(card_id))
		configured_widgets.append({"card_id": card_id, "widget": widget})
	await _settle_render()
	for configured_var: Variant in configured_widgets:
		var configured: Dictionary = configured_var as Dictionary
		_validate_widget_art(configured.get("widget") as CardWidget, str(configured.get("card_id", "")))
	await _save_viewport(viewport, "item_cards_actual_size_%d.png" % _stamp)
	viewport.queue_free()
	await process_frame


func _capture_compact_badges() -> void:
	var viewport: SubViewport = _production_viewport()
	var background: ColorRect = _background(Color("11181b"))
	viewport.add_child(background)
	_add_heading(background, "ITEM CARD ART — ACTUAL CHARACTER-SHEET BADGES", 250.0)
	var run_scene: Node = RunSceneScript.new()
	for index: int in range(CARD_IDS.size()):
		var card_id: String = str(CARD_IDS[index])
		var accent: Color = run_scene.call("_item_card_accent", card_id) as Color
		var badge: Control = run_scene.call("_build_equipment_card_badge", card_id, accent) as Control
		_expect(badge != null, "%s should build a compact character-sheet badge" % card_id)
		if badge == null:
			continue
		var column: int = index % 5
		var row: int = index / 5
		badge.position = Vector2(486.0 + float(column) * 205.0, 455.0 + float(row) * 96.0)
		badge.size = Vector2(164.0, 42.0)
		background.add_child(badge)
	await _settle_render()
	await _save_viewport(viewport, "item_badges_actual_size_%d.png" % _stamp)
	viewport.queue_free()
	run_scene.free()
	await process_frame


func _production_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = PRODUCTION_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ALWAYS
	root.add_child(viewport)
	return viewport


func _background(color: Color) -> ColorRect:
	var background := ColorRect.new()
	background.color = color
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	return background


func _add_heading(parent: Control, text: String, top: float) -> void:
	var heading := Label.new()
	heading.text = text
	heading.position = Vector2(0.0, top)
	heading.size = Vector2(1920.0, 42.0)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("e6cfa7"))
	heading.add_theme_color_override("font_outline_color", Color("0d0805"))
	heading.add_theme_constant_override("outline_size", 3)
	parent.add_child(heading)


func _validate_widget_art(widget: CardWidget, card_id: String) -> void:
	var card: Dictionary = GameData.card_def(card_id)
	_expect(not card.is_empty() and bool(card.get("item", false)), "%s should remain an item card" % card_id)
	var art: TextureRect = widget.get_node_or_null("Margin/VBox/ArtBleed/ArtFrame/Art") as TextureRect
	_expect(art != null and art.texture != null, "%s should load its art into the real CardWidget" % card_id)
	if art != null and art.texture != null:
		_expect(art.texture.get_size() == Vector2(256.0, 144.0), "%s should retain native 256×144 source art" % card_id)
		_expect(art.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, "%s should use the production covered art crop" % card_id)


func _settle_render() -> void:
	await process_frame
	await process_frame
	await create_timer(0.16).timeout
	await process_frame


func _save_viewport(viewport: SubViewport, file_name: String) -> void:
	if DisplayServer.get_name() == "headless":
		_expect(false, "Item card art proof requires a real renderer")
		return
	var image: Image = viewport.get_texture().get_image()
	var output_path: String = ProjectSettings.globalize_path("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(image.get_size() == PRODUCTION_SIZE, "%s should capture at 1920×1080" % file_name)
	_expect(image.save_png(output_path) == OK, "%s should save successfully" % file_name)
	print(output_path)


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_errors.append(message)
