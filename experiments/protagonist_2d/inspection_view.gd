extends Control

const Board = preload("res://experiments/protagonist_2d/inspection_board.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Settings = preload("res://scripts/settings_store.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Motion = preload("res://experiments/protagonist_2d/cutout_motion.gd")
const RIG_PATH: String = "res://experiments/protagonist_2d/cutout_rig.gd"
const ACTIONS: PackedStringArray = ["walk", "attack"]
const FACINGS: PackedStringArray = ["front", "rear"]
const CANVAS_SIZE := Vector2i(512, 512)
const SOURCE_OFFSET := Vector2(128, 128)
const SOURCE_SIZE := Vector2(255, 255)
const START_TILE := Vector2i(3, 5)
const TRAVEL_CYCLES: int = 3

var board: Control
var puppet_viewport: SubViewport
var detail_viewport: SubViewport
var puppet: Node2D
var detail_puppet: Node2D
var animation: String = "walk"
var cloak_visible: bool = true
var _cloak_button: Button
var facing: String = "front"
var frame_index: int = 0
var playing: bool = true
var reference_on_board: bool = false
var bones_visible: bool = false
var detail_zoom: bool = true
var travel_enabled: bool = true
var travel_frame_index: int = 0
var load_errors: PackedStringArray = []
var _elapsed: float = 0.0
var _skin := UiSkin.new()
var _detail_transform: Node2D
var _source_image: TextureRect
var _source_label: Label
var _frame_label: Label
var _board_label: Label
var _detail_label: Label
var _pause_button: Button
var _step_button: Button
var _source_button: Button
var _bones_button: Button
var _zoom_button: Button
var _travel_button: Button
var _action_buttons: Dictionary = {}
var _facing_buttons: Dictionary = {}

func _ready() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://protagonist_2d_inspection_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	RenderingServer.set_default_clear_color(Color("100e12"))
	_load_puppets()
	_build_view()
	if load_errors.is_empty():
		select_clip(animation, facing)
	else:
		_frame_label.text = "Rig unavailable — see console"
		for message: String in load_errors:
			push_error(message)
		set_process(false)

func _new_puppet_viewport() -> SubViewport:
	var viewport := SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.handle_input_locally = false
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	# The source is pixel art; preserve its pixel edges before the game's normal
	# final canvas rendering. Bone deformation/rotation remains the rig's work.
	viewport.msaa_2d = Viewport.MSAA_DISABLED
	add_child(viewport)
	return viewport

func _load_puppets() -> void:
	puppet_viewport = _new_puppet_viewport()
	detail_viewport = _new_puppet_viewport()
	_detail_transform = Node2D.new()
	detail_viewport.add_child(_detail_transform)
	if not FileAccess.file_exists(RIG_PATH):
		load_errors.append("Missing cutout rig: " + RIG_PATH)
		return
	var script: Script = load(RIG_PATH) as Script
	if script == null:
		load_errors.append("Could not load cutout rig script")
		return
	puppet = script.new() as Node2D
	detail_puppet = script.new() as Node2D
	if puppet == null or detail_puppet == null:
		load_errors.append("Cutout rig must extend Node2D")
		return
	puppet.position = SOURCE_OFFSET
	detail_puppet.position = SOURCE_OFFSET
	puppet_viewport.add_child(puppet)
	_detail_transform.add_child(detail_puppet)
	for method: String in ["load_rig", "set_clip", "set_facing", "has_facing", "seek_frame", "get_frame_count", "get_fps", "get_anchor"]:
		if not puppet.has_method(method):
			load_errors.append("Cutout rig is missing " + method)
	if not load_errors.is_empty():
		return
	for rig: Node2D in [puppet, detail_puppet]:
		if not bool(rig.call("load_rig")):
			load_errors.append("Cutout rig could not load its actual source parts")
		if rig.has_method("set_debug_bones"):
			rig.call("set_debug_bones", false)
	if not load_errors.is_empty():
		return
	var anchor: Variant = puppet.call("get_anchor")
	if not anchor is Vector2 or anchor.x < 0.0 or anchor.x > 1.0 or anchor.y < 0.0 or anchor.y > 1.0:
		load_errors.append("Rig anchor must be normalized to its 512px canvas")

func has_facing(which: String) -> bool:
	return puppet != null and puppet.has_method("has_facing") and bool(puppet.call("has_facing", which))

func reference_texture(which: String) -> Texture2D:
	if puppet != null and puppet.has_method("get_reference_texture"):
		var texture: Texture2D = puppet.call("get_reference_texture", which) as Texture2D
		if texture != null:
			return texture
	if which == "front":
		return AssetLoader.load_texture("res://assets/placeholders/units/player_reaver.png")
	return null

func _build_view() -> void:
	var background := ColorRect.new()
	background.color = Color("100e12")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_label("Protagonist • 2D skeletal animation", Vector2(32, 20), Vector2(1270, 48), Typography.ROLE_HERO)
	_label("New Reaver artwork · Walk and attack study", Vector2(32, 70), Vector2(1250, 28), Typography.ROLE_BODY_LARGE)
	board = Board.new()
	board.position = Vector2(20, 134)
	board.size = Vector2(1280, 790)
	add_child(board)
	Typography.apply_board_font(self, board)
	var state: Dictionary = Combat.new().create_combat(71471, _layout(), {"hp": 30, "max_hp": 30, "deck_cards": ["quick_stab", "guarded_step"], "relics": []})
	var shown: Dictionary = {"reduced_motion": true, "ambient_time_seconds": 12.0, "puppet_live": false, "puppet_texture": puppet_viewport.get_texture(), "puppet_reference": reference_texture("front"), "board_framing_mode": "combat", "board_safe_global_rect": Rect2(32, 148, 1250, 756)}
	board.call("set_combat_state", state, [], [], START_TILE, "", "", {}, {}, shown)
	board.call("set_navigation_zoom", 1.12)
	board.call("set_navigation_pan", Vector2.ZERO)
	_board_label = _label("Board: live cutout", Vector2(42, 120), Vector2(680, 30), Typography.ROLE_SECTION)
	_travel_button = _button("Walk across board", 248, true, true)
	_travel_button.position = Vector2(1020, 90)
	_travel_button.pressed.connect(func() -> void: set_travel_enabled(not travel_enabled))
	add_child(_travel_button)
	var comparison := PanelContainer.new()
	comparison.position = Vector2(1320, 22)
	comparison.size = Vector2(568, 966)
	_skin.apply_panel_surface(comparison, UiSkin.SURFACE_HUD)
	add_child(comparison)
	_label("Reference and live character", Vector2(1340, 42), Vector2(520, 36), Typography.ROLE_TITLE)
	_source_label = _label("Original", Vector2(1340, 102), Vector2(250, 28), Typography.ROLE_SECTION)
	_label("Live cutout", Vector2(1610, 102), Vector2(250, 28), Typography.ROLE_SECTION)
	_source_image = _texture_view(Vector2(1340, 145), SOURCE_SIZE)
	_source_image.texture = reference_texture("front")
	var candidate: TextureRect = _texture_view(Vector2(1610, 145), SOURCE_SIZE)
	var crop := AtlasTexture.new()
	crop.atlas = puppet_viewport.get_texture()
	crop.region = Rect2(SOURCE_OFFSET, SOURCE_SIZE)
	crop.filter_clip = true
	candidate.texture = crop
	_label("Original framing • 1×", Vector2(1340, 408), Vector2(520, 24), Typography.ROLE_CAPTION)
	_detail_label = _label("Pose detail • 1.75×", Vector2(1340, 440), Vector2(270, 32), Typography.ROLE_SECTION)
	_bones_button = _button("Bones", 104, true, true)
	_bones_button.position = Vector2(1620, 438)
	_bones_button.disabled = detail_puppet == null or not detail_puppet.has_method("set_debug_bones")
	_bones_button.pressed.connect(func() -> void: set_bones_visible(not bones_visible))
	add_child(_bones_button)
	_zoom_button = _button("Full pose", 140, false, true)
	_zoom_button.position = Vector2(1734, 438)
	_zoom_button.pressed.connect(func() -> void: set_detail_zoom(not detail_zoom))
	add_child(_zoom_button)
	var detail: TextureRect = _texture_view(Vector2(1348, 475), Vector2(512, 512))
	detail.texture = detail_viewport.get_texture()
	var actions := HBoxContainer.new()
	actions.position = Vector2(32, 930)
	actions.add_theme_constant_override("separation", 10)
	add_child(actions)
	for action: String in ACTIONS:
		var button: Button = _button(action.capitalize(), 128, true)
		button.disabled = not load_errors.is_empty()
		button.pressed.connect(select_clip.bind(action, ""))
		actions.add_child(button)
		_action_buttons[action] = button
	_cloak_button = _button("Show cloak", 184, true)
	_cloak_button.position = Vector2(350, 930)
	_cloak_button.button_pressed = true
	_cloak_button.pressed.connect(func() -> void: set_cloak_visible(not cloak_visible))
	add_child(_cloak_button)
	var facing_row := HBoxContainer.new()
	facing_row.position = Vector2(744, 930)
	facing_row.add_theme_constant_override("separation", 10)
	add_child(facing_row)
	for which: String in FACINGS:
		var button: Button = _button(which.capitalize(), 166, true)
		button.disabled = not has_facing(which)
		button.pressed.connect(select_clip.bind("", which))
		facing_row.add_child(button)
		_facing_buttons[which] = button
	var transport := HBoxContainer.new()
	transport.position = Vector2(32, 1002)
	transport.add_theme_constant_override("separation", 12)
	add_child(transport)
	_pause_button = _button("Pause", 132)
	_pause_button.pressed.connect(func() -> void: set_playing(not playing))
	transport.add_child(_pause_button)
	_step_button = _button("Next frame", 150)
	_step_button.pressed.connect(step_frame)
	transport.add_child(_step_button)
	_source_button = _button("Show static reference", 264)
	_source_button.pressed.connect(func() -> void: set_reference_on_board(not reference_on_board))
	transport.add_child(_source_button)
	_frame_label = _label("", Vector2(640, 1007), Vector2(648, 32), Typography.ROLE_BODY_LARGE)
	_label("Pause / step to inspect the poses", Vector2(1340, 1012), Vector2(532, 28), Typography.ROLE_BODY)
	(_action_buttons["walk"] as Button).grab_focus()
	set_detail_zoom(true)

func _button(text_value: String, width: float, toggles: bool = false, compact: bool = false) -> Button:
	var button := Button.new()
	button.text = text_value
	button.toggle_mode = toggles
	button.custom_minimum_size = Vector2(width, UiSkin.BUTTON_HEIGHT_SMALL if compact else UiSkin.BUTTON_HEIGHT_STANDARD)
	_skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_COMPACT if compact else UiSkin.VARIANT_STANDARD)
	_skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_BODY if compact else Typography.ROLE_BODY_LARGE)
	return button

func _label(text_value: String, at: Vector2, extent: Vector2, role: String) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = at
	label.size = extent
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_color_override("font_color", Color("eee4d4"))
	Typography.apply_label_role(label, role)
	add_child(label)
	return label

func _texture_view(at: Vector2, extent: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.position = at
	picture.size = extent
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(picture)
	return picture

func select_clip(next_animation: String, next_facing: String) -> void:
	if not load_errors.is_empty():
		return
	if not next_facing.is_empty():
		if not has_facing(next_facing):
			return
		facing = next_facing
	if not next_animation.is_empty():
		animation = next_animation
	for rig: Node2D in [puppet, detail_puppet]:
		rig.call("set_facing", facing)
		rig.call("set_clip", animation)
	frame_index = 0
	travel_frame_index = 0
	_elapsed = 0.0
	for action: String in _action_buttons:
		(_action_buttons[action] as Button).set_pressed_no_signal(action == animation)
	for which: String in _facing_buttons:
		(_facing_buttons[which] as Button).set_pressed_no_signal(which == facing)
	_source_image.texture = reference_texture(facing)
	_source_label.text = "Original" if facing == "front" else "Rear reference"
	_travel_button.disabled = animation != "walk"
	_travel_button.set_pressed_no_signal(travel_enabled)
	_apply_frame()

func frame_count() -> int:
	return int(puppet.call("get_frame_count")) if puppet != null else 0

func fps() -> float:
	return float(puppet.call("get_fps")) if puppet != null else 1.0

func set_playing(next_playing: bool) -> void:
	playing = next_playing and load_errors.is_empty()
	_pause_button.text = "Pause" if playing else "Play"
	_elapsed = float(travel_frame_index) / maxf(1.0, fps())
	_apply_frame()

func step_frame() -> void:
	set_playing(false)
	if frame_count() <= 0:
		return
	var next_frame: int = travel_frame_index + 1 if _travel_active() else frame_index + 1
	seek_timeline_frame(next_frame)

func _travel_active() -> bool:
	return travel_enabled and animation == "walk"

func timeline_frame_count() -> int:
	return frame_count() * (TRAVEL_CYCLES if _travel_active() else 1)

func seek_timeline_frame(index: int) -> void:
	travel_frame_index = posmod(index, maxi(1, timeline_frame_count()))
	frame_index = travel_frame_index % maxi(1, frame_count())
	_elapsed = float(travel_frame_index) / maxf(1.0, fps())
	_apply_frame()

func set_travel_enabled(enabled: bool) -> void:
	travel_enabled = enabled
	_travel_button.set_pressed_no_signal(enabled)
	seek_timeline_frame(frame_index)

func travel_source_offset() -> Vector2:
	if not _travel_active():
		return Vector2.ZERO
	var info: Dictionary = Motion.walk_cycle_info(puppet.get("layout") as Dictionary, facing)
	var displacement: Vector2 = info["travel_per_cycle"]
	return displacement * (float(travel_frame_index) / float(frame_count()) - float(TRAVEL_CYCLES) * 0.5)

func set_reference_on_board(enabled: bool) -> void:
	reference_on_board = enabled
	_source_button.text = "Show live cutout" if enabled else "Show static reference"
	_apply_frame()

func set_bones_visible(enabled: bool) -> void:
	bones_visible = enabled and detail_puppet != null and detail_puppet.has_method("set_debug_bones")
	_bones_button.set_pressed_no_signal(bones_visible)
	if detail_puppet != null and detail_puppet.has_method("set_debug_bones"):
		detail_puppet.call("set_debug_bones", bones_visible)

func set_detail_zoom(enabled: bool) -> void:
	detail_zoom = enabled
	var zoom: float = 1.75 if enabled else 1.0
	_detail_transform.scale = Vector2.ONE * zoom
	_detail_transform.position = Vector2(256.0, 256.0) - Vector2(255.5, 255.5) * zoom
	_detail_label.text = "Pose detail • 1.75×" if enabled else "Pose detail • full canvas"
	_zoom_button.text = "Full pose" if enabled else "Zoom detail"

func _process(delta: float) -> void:
	if not playing or not load_errors.is_empty() or frame_count() <= 0:
		return
	_elapsed += delta
	var next_frame: int = int(floor(_elapsed * fps())) % timeline_frame_count()
	if next_frame != travel_frame_index:
		travel_frame_index = next_frame
		frame_index = next_frame % frame_count()
		_apply_frame()

func _apply_frame() -> void:
	if not load_errors.is_empty() or puppet == null or detail_puppet == null or board == null or frame_count() <= 0:
		return
	puppet.call("seek_frame", frame_index)
	detail_puppet.call("seek_frame", frame_index)
	var shown: Dictionary = board.get("presentation") as Dictionary
	shown["puppet_live"] = not reference_on_board
	shown["puppet_texture"] = puppet_viewport.get_texture()
	shown["puppet_reference"] = reference_texture(facing)
	shown["puppet_anchor"] = puppet.call("get_anchor")
	shown["puppet_travel_source_px"] = travel_source_offset()
	board.call("_rebuild_hud_health_rects_cache")
	board.call("_sync_dynamic_render_state", false, false, ["presentation", "_hud_health_rects_cache", "_hud_layout_entries_cache"])
	board.call("_queue_dynamic_redraw")
	_frame_label.text = "%s • %s • %02d / %02d • %s fps%s" % [animation.capitalize(), facing.capitalize(), frame_index + 1, frame_count(), str(fps()), "" if playing else " • Paused"]
	_board_label.text = "Board: static reference" if reference_on_board else "Board: live cutout"
	if _travel_active():
		_board_label.text += " • Traveling • cycle %d / %d" % [travel_frame_index / frame_count() + 1, TRAVEL_CYCLES]
	elif animation == "walk":
		_board_label.text += " • In place"

func _layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if y == 0 or y == 7 or x == 0 or x == 8 else "stone")
		grid.append(row)
	grid[2][5] = "pillar"
	return {"name": "Protagonist Cutout Study", "coord": Vector2i(1, 0), "type": "combat", "grid": grid, "player_start": START_TILE, "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 4), "hp": 22, "max_hp": 22, "block": 0}, {"id": 2, "type": "harrier", "pos": Vector2i(6, 2), "hp": 18, "max_hp": 18, "block": 0}], "terrain": [{"id": "crate", "kind": "wooden_crate", "pos": Vector2i(2, 2), "hp": 8, "max_hp": 8}]}

func set_cloak_visible(value: bool) -> void:
	cloak_visible = value
	_cloak_button.button_pressed = value
	for rig: Node2D in [puppet, detail_puppet]:
		rig.call("set_cloak_visible", value)
