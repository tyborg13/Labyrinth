extends SceneTree

const CardWidget = preload("res://scripts/card_widget.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const RunSceneScript = preload("res://scripts/run_scene.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTooltipButton = preload("res://scripts/ui_tooltip_button.gd")

const OUTPUT_DIR: String = "user://tooltip_consistency_probe_v1"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()

	var surface := Control.new()
	surface.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(surface)
	var background := ColorRect.new()
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.color = Color("100b09")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	surface.add_child(background)

	var board: Control = CombatBoardView.new()
	board.position = Vector2(24.0, 112.0)
	board.size = Vector2(1060.0, 936.0)
	surface.add_child(board)
	await process_frame
	board.call("set_combat_state", _probe_state())

	var host: Node = RunSceneScript.new()
	board.set("equipment_tooltip_builder", Callable(host, "_build_equipment_tooltip_panel"))
	var trigger: String = str(board.call("_loot_tooltip_text", {
		"kind": "equipment",
		"equipment_id": "iron_cleaver"
	}))
	_require(trigger == "equipment:iron_cleaver", "Board pickup should request the shared equipment preview")
	var equipment_tooltip: Control = board.call("_make_custom_tooltip", trigger) as Control
	_require(equipment_tooltip != null, "Board pickup should build a rich equipment tooltip")
	if equipment_tooltip != null:
		equipment_tooltip.name = "CollectibleEquipmentTooltip"
		equipment_tooltip.position = Vector2(1160.0, 112.0)
		surface.add_child(equipment_tooltip)

	var generic_source: Button = UiTooltipButton.new()
	var generic_tooltip: Control = generic_source.call(
		"_make_custom_tooltip",
		"MAP\nOpen the full labyrinth map."
	) as Control
	_require(generic_tooltip != null, "Standard text tooltips should build a framed panel")
	if generic_tooltip != null:
		generic_tooltip.name = "StandardFramedTooltip"
		generic_tooltip.position = Vector2(640.0, 700.0)
		generic_tooltip.z_index = 10
		surface.add_child(generic_tooltip)
	generic_source.free()

	await process_frame
	await process_frame
	await create_timer(0.12).timeout
	_validate_equipment_preview(equipment_tooltip)
	RenderingServer.force_draw(true)
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var texture: Texture2D = root.get_texture()
		if texture != null:
			image = texture.get_image()
	if image == null:
		image = Image.create(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("100b09"))
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path: String = "%s/tooltip_consistency_1920x1080.png" % OUTPUT_DIR
	var error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	_require(error == OK, "Tooltip consistency proof screenshot should save")

	if equipment_tooltip != null:
		var equipment_rect: Rect2 = equipment_tooltip.get_global_rect()
		_require(equipment_rect.position.x >= 1120.0 and equipment_rect.end.x <= VIEWPORT_SIZE.x - 16.0, "Equipment tooltip should fit beside the board")
		_require(equipment_rect.end.y <= 760.0, "Equipment tooltip should leave room for the standard framed tooltip")
	if generic_tooltip != null:
		_require(
			generic_tooltip.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null,
			"Standard tooltip should render the shared asymmetric frame"
		)

	if _failures.is_empty():
		print("TOOLTIP_CONSISTENCY_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		print("TEST RESULT: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)


func _probe_state() -> Dictionary:
	return {
		"name": "Collectible Equipment Tooltip Probe",
		"room_coord": Vector2i(7, -2),
		"grid": [
			["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "stone", "stone", "stone", "stone", "stone", "stone", "stone", "wall"],
			["wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall", "wall"]
		],
		"player": {
			"pos": Vector2i(2, 4),
			"hp": 300,
			"max_hp": 300,
			"block": 0,
			"stoneskin": 0
		},
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(6, 3),
			"hp": 90,
			"max_hp": 90,
			"block": 0,
			"intent": {}
		}],
		"loot": [{
			"id": "tooltip_probe_equipment",
			"kind": "equipment",
			"equipment_id": "iron_cleaver",
			"pos": Vector2i(4, 3)
		}],
		"terrain": [],
		"traps": []
	}


func _validate_equipment_preview(tooltip: Control) -> void:
	if tooltip == null:
		return
	var expected_cards: Array = GameData.equipment_cards("iron_cleaver")
	var preview_ids: Array[String] = []
	for node: Node in tooltip.find_children("*", "Button", true, false):
		if node.get_script() == CardWidget:
			preview_ids.append(str(node.get("card_id")))
	_require(preview_ids.size() == expected_cards.size(), "Equipment tooltip should render every supplied card preview")
	for card_id_var: Variant in expected_cards:
		_require(preview_ids.has(str(card_id_var)), "Equipment tooltip should render %s" % str(card_id_var))


func _clear_probe_output() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
