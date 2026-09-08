extends Control

const Rig = preload("res://tools/cutout_pipeline/rig.gd")
const Board = preload("res://tools/cutout_pipeline/board.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
var case_file: String
var rig: Rig
var puppet: SubViewport
var board: Board
var status: Label
var animation: String
var frame_index: int = 0
var elapsed: float = 0.0
var playing: bool = true
var mirrored: bool = false
var cloak_visible: bool = true
var pause_button: Button
var facing_select: OptionButton
var clip_select: OptionButton
var rest_cache: Dictionary = {}
var skin := UiSkin.new()

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var background := ColorRect.new()
	background.color = Color("100e12")
	background.size = Vector2(1920, 1080)
	add_child(background)
	puppet = SubViewport.new()
	puppet.size = Vector2i(512, 512)
	puppet.transparent_bg = true
	puppet.disable_3d = true
	puppet.world_2d = World2D.new()
	puppet.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(puppet)
	rig = Rig.new()
	rig.position = Vector2(128, 128)
	puppet.add_child(rig)
	if not rig.configure(case_file):
		push_error(str(rig.load_errors))
		get_tree().quit(1)
		return
	animation = str(rig.config["clips"].keys()[0])
	_label(str(rig.config["character_id"]).capitalize() + " • Cutout study", Vector2(32, 18), Vector2(1800, 52), Typography.ROLE_HERO)
	_label("Native board scale and complete pose • Space: pause • Arrows: step", Vector2(32, 78), Vector2(1800, 32), Typography.ROLE_BODY)
	board = Board.new()
	board.position = Vector2(20, 188)
	board.size = Vector2(1280, 780)
	add_child(board)
	Typography.apply_board_font(self, board)
	var state: Dictionary = Combat.new().create_combat(71471, _layout(), {"hp": 30, "max_hp": 30, "deck_cards": ["quick_stab", "guarded_step"], "relics": []})
	var presentation: Dictionary = {"reduced_motion": true, "ambient_time_seconds": 12.0, "puppet_live": true, "puppet_texture": puppet.get_texture(), "board_framing_mode": "combat", "board_safe_global_rect": Rect2(32, 204, 1250, 740)}
	board.set_combat_state(state, [], [], Vector2i(4, 4), "", "", {}, {}, presentation)
	board.set_navigation_zoom(1.04)
	board.set_navigation_pan(Vector2.ZERO)
	var detail := TextureRect.new()
	detail.position = Vector2(1350, 270)
	detail.size = Vector2(512, 512)
	detail.texture = puppet.get_texture()
	detail.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	add_child(detail)
	_label("Full action canvas • 1× source pixels", Vector2(1335, 214), Vector2(560, 44), Typography.ROLE_SECTION)
	_label("Character study; gameplay routing is verified separately", Vector2(32, 1030), Vector2(1840, 30), Typography.ROLE_CAPTION)
	var controls := HBoxContainer.new()
	controls.position = Vector2(32, 130)
	controls.add_theme_constant_override("separation", 12)
	add_child(controls)
	facing_select = OptionButton.new()
	for name: String in rig.config["layouts"]:
		facing_select.add_item(name.capitalize())
	facing_select.item_selected.connect(func(index: int) -> void: select(str(rig.config["layouts"].keys()[index]), animation))
	controls.add_child(facing_select)
	clip_select = OptionButton.new()
	for name: String in rig.config["clips"]:
		clip_select.add_item(name.capitalize())
	clip_select.item_selected.connect(func(index: int) -> void: select(rig.facing, str(rig.config["clips"].keys()[index])))
	controls.add_child(clip_select)
	pause_button = _button("Pause", controls, func() -> void: set_playing(not playing))
	_button("Step back", controls, func() -> void: step(-1))
	_button("Step forward", controls, func() -> void: step(1))
	_button("Mirror", controls, func() -> void: mirrored = not mirrored; _apply_frame())
	_button("Cloak on/off", controls, func() -> void: cloak_visible = not cloak_visible; rig.set_slot_visible("cloak", cloak_visible))
	for control: Control in [facing_select, clip_select]:
		control.custom_minimum_size = Vector2(190, 44)
		Typography.apply_button_role(control, Typography.ROLE_BODY)
	status = _label("", Vector2(32, 982), Vector2(1840, 40), Typography.ROLE_SECTION)
	_apply_frame()

func _button(text: String, parent: Node, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(158, 44)
	skin.apply_button_stylebox_overrides(button, UiSkin.VARIANT_STANDARD)
	skin.apply_button_text_overrides(button)
	Typography.apply_button_role(button, Typography.ROLE_BODY)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _label(text: String, at: Vector2, extent: Vector2, role: String) -> Label:
	var label := Label.new()
	label.text = text
	label.position = at
	label.size = extent
	Typography.apply_label_role(label, role)
	add_child(label)
	return label

func set_playing(value: bool) -> void:
	var spec: Dictionary = rig.config["clips"][animation]
	if value and not bool(spec["loop"]) and frame_index >= int(spec["frames"]) - 1:
		frame_index = 0
		elapsed = 0.0
	playing = value
	pause_button.text = "Pause" if value else "Play"
	_apply_frame()

func select(facing: String, clip_name: String) -> void:
	if not rig.set_facing(facing):
		push_error(str(rig.load_errors))
		return
	animation = clip_name
	frame_index = 0
	elapsed = 0.0
	facing_select.select(rig.config["layouts"].keys().find(facing))
	clip_select.select(rig.config["clips"].keys().find(clip_name))
	rig.set_slot_visible("cloak", cloak_visible)
	_apply_frame()

func show_frame(index: int) -> void:
	frame_index = index
	_apply_frame()

func timeline_frames() -> int:
	var spec: Dictionary = rig.config["clips"][animation]
	return int(spec["frames"]) * int(spec.get("preview_cycles", 1))

func step(amount: int) -> void:
	set_playing(false)
	frame_index = posmod(frame_index + amount, timeline_frames())
	var spec: Dictionary = rig.config["clips"][animation]
	elapsed = float(frame_index) * float(spec["duration"]) / float(spec["frames"])
	_apply_frame()

func _process(delta: float) -> void:
	if rig == null or status == null or not playing:
		return
	elapsed += delta
	var spec: Dictionary = rig.config["clips"][animation]
	var next_frame: int = int(elapsed / float(spec["duration"]) * float(spec["frames"]))
	if bool(spec["loop"]):
		next_frame %= timeline_frames()
	else:
		next_frame = mini(next_frame, int(spec["frames"]) - 1)
	if next_frame != frame_index:
		show_frame(next_frame)
	if not bool(spec["loop"]) and elapsed >= float(spec["duration"]):
		set_playing(false)

func _input(event: InputEvent) -> void:
	# Timeline shortcuts must run before button focus-navigation consumes arrows.
	# Open selectors retain their ordinary keyboard navigation.
	if facing_select == null or facing_select.get_popup().visible or clip_select.get_popup().visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE: set_playing(not playing)
			KEY_LEFT: step(-1)
			KEY_RIGHT: step(1)
			_: return
		get_viewport().set_input_as_handled()

func _apply_frame() -> void:
	if status == null:
		return
	rig.show_frame(animation, frame_index)
	rig.scale.x = -1.0 if mirrored else 1.0
	rig.position.x = 128.0 + (255.0 if mirrored else 0.0)
	var shown: Dictionary = board.presentation
	shown["puppet_texture"] = puppet.get_texture()
	var rest: Texture2D = rest_cache.get(rig.facing)
	if rest != null:
		shown["puppet_reference"] = rest
	elif rig.layout.has("rest_source"):
		shown["puppet_reference"] = rig._texture(rig.layout["rest_source"])
	var travel: Vector2 = rig.travel_for_frame(animation, frame_index)
	travel.x *= -1.0 if mirrored else 1.0
	shown["puppet_travel_source_px"] = travel
	board._rebuild_hud_health_rects_cache()
	board._sync_dynamic_render_state(false, false, ["presentation", "_hud_health_rects_cache", "_hud_layout_entries_cache"])
	board._queue_dynamic_redraw()
	status.text = "%s • %s • frame %d/%d • %.2fs per cycle%s" % [rig.facing.capitalize(), animation.capitalize(), frame_index + 1, timeline_frames(), float(rig.config["clips"][animation]["duration"]), " • Paused" if not playing else ""]

func _layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if y == 0 or y == 7 or x == 0 or x == 8 else "stone")
		grid.append(row)
	return {"name": "Cutout Study", "coord": Vector2i(1, 0), "type": "combat", "grid": grid, "player_start": Vector2i(4, 4), "enemies": [], "terrain": []}

func bake_references() -> void:
	set_playing(false)
	for facing: String in rig.config["layouts"]:
		rig.set_facing(facing)
		rig.apply_pose("rest", 0.0)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = puppet.get_texture().get_image().get_region(Rect2i(128, 128, 255, 255))
		rest_cache[facing] = ImageTexture.create_from_image(image)
	select(str(rig.config["default_facing"]), animation)
