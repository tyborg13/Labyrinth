extends SceneTree

# Real-renderer inspection fixture for VP4 shared components, at 100% UI scale.
# Six captures cover native socket/strip focus and hover, normal, and each socket size.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const Socket = preload("res://scripts/ui_socket.gd")
const Strip = preload("res://scripts/ui_card_strip.gd")
const Header = preload("res://scripts/ui_section_header.gd")
const Chip = preload("res://scripts/ui_stat_chip.gd")
const Stage = preload("res://scripts/ui_ink_pool_stage.gd")

const OUTPUT_DIR: String = "user://probes/ui_components_gallery"
const VIEWPORT := Vector2i(1920, 1080)
const STATES: PackedStringArray = ["NORMAL", "HOVER", "FOCUS", "SELECTED", "EMPTY", "DISABLED"]
var _host: Control
var _viewport: SubViewport
var _sockets: Array[Button]
var _strips: Array[Button]
var _socket_grid: Dictionary = {}
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_run.call_deferred()

func _run() -> void:
	if DisplayServer.get_name() == "headless":
		_fail("Component gallery requires a real renderer")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_build_gallery()
	await process_frame
	await process_frame
	_assert_gallery()
	_sockets[2].grab_focus()
	await _hover(_sockets[1])
	_check(_sockets[1].is_hovered() and _sockets[2].has_focus(), "Socket gallery must use actual native hover and focus")
	await _capture("gallery_socket_focus.png")
	_strips[2].grab_focus()
	await _hover(_strips[1])
	_check(_strips[1].is_hovered() and _strips[2].has_focus(), "Strip gallery must use actual native hover and focus")
	await _capture("gallery_strip_focus.png")
	_strips[2].release_focus()
	await _hover(_host, Vector2(1860.0, 1020.0))
	await _capture("gallery_normal.png")
	for row: int in range(3):
		var focused: Button = _socket_grid[Vector2i(2, row)] as Button
		var hovered: Button = _socket_grid[Vector2i(1, row)] as Button
		focused.grab_focus()
		await _hover(hovered)
		_check(focused.has_focus() and hovered.is_hovered(), "Every socket size must show native hover and focus")
		await _capture("gallery_sockets_%dpx.png" % roundi(focused.socket_size))
	print("TEST RESULT: FAIL ui_components_gallery" if _failed else "TEST RESULT: PASS ui_components_gallery")
	quit(1 if _failed else 0)

func _build_gallery() -> void:
	root.size = VIEWPORT
	root.content_scale_size = VIEWPORT
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_host = Control.new()
	_host.size = Vector2(VIEWPORT)
	_viewport.add_child(_host)
	var background := ColorRect.new()
	background.color = Palette.INK_0
	background.size = Vector2(VIEWPORT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(background)
	_label("SHARED COMPONENTS", Vector2(64.0, 42.0), 30, Palette.GOLD_BRIGHT)
	_label("VISUAL PASS 4 · 1920 × 1080 · 100% UI SCALE", Vector2(64.0, 88.0), 15, Palette.TEXT_2)
	_build_sockets()
	_build_strips()
	_build_chips()
	_build_stages()

func _build_sockets() -> void:
	_header("SOCKETS", "30 / 50 / 62 px", Vector2(64.0, 144.0), 806.0)
	var icon: Texture2D = _equipment_icon("training_sword")
	for column: int in range(STATES.size()):
		var x: float = 64.0 + float(column) * 134.0
		_label(STATES[column], Vector2(x, 184.0), 14, Palette.TEXT_2)
		for row: int in range(3):
			var diameter: float = [30.0, 50.0, 62.0][row]
			var socket := Socket.new()
			socket.socket_size = diameter
			socket.position = Vector2(x + (80.0 - diameter) * 0.5, 228.0 + float(row) * 88.0)
			socket.setup(null if column == 4 else icon, "Training Sword", "3" if column == 0 and row == 1 else "")
			socket.selected = column == 3
			socket.disabled = column == 5
			_host.add_child(socket)
			_socket_grid[Vector2i(column, row)] = socket
			if row == 1:
				_sockets.append(socket)

func _build_strips() -> void:
	_header("CARD STRIPS", "native inspection signals", Vector2(64.0, 514.0), 806.0)
	for index: int in range(STATES.size()):
		var position := Vector2(64.0 + float(index % 2) * 412.0, 566.0 + float(index / 2) * 82.0)
		_label(STATES[index] if index != 4 else "LONG NAME · NO COUNT", position, 14, Palette.TEXT_2)
		var strip := Strip.new()
		strip.position = position + Vector2(0.0, 25.0)
		strip.size = Vector2(380.0, 30.0)
		var id: String = ["quick_stab", "pale_spark", "waning_pulse", "whirlwind_slash", "quick_stab", "brace"][index]
		strip.setup(id, "The longest card name in the gallery extends beyond this strip" if index == 4 else str(GameData.card_def(id).get("name", id)), 2 if index in [1, 2] else 1)
		strip.selected = index == 3
		strip.locked = index == 5
		_host.add_child(strip)
		_strips.append(strip)
	_label("SINGLE-COPY STRIPS OMIT ×1 · LOCKED STRIPS KEEP THEIR ART AND NAME", Vector2(64.0, 837.0), 14, Palette.TEXT_3)

func _build_chips() -> void:
	_header("STAT CHIPS", "content-fit width", Vector2(1010.0, 144.0), 820.0)
	var definitions: Array = [
		["health", "24/24", "Health", Palette.ALLY],
		["ember", "12", "Embers", Palette.GOLD_BRIGHT],
		["defiance", "0/0", "Defiance · next 4", Palette.GOLD_BRIGHT],
	]
	for index: int in range(definitions.size()):
		var sample: Array = definitions[index]
		var chip := Chip.new()
		chip.position = Vector2(1010.0, 198.0 + float(index) * 70.0)
		chip.setup(AssetLoader.load_texture("res://assets/art/icons/%s.png" % str(sample[0])), str(sample[1]), str(sample[2]), sample[3])
		_host.add_child(chip)

func _build_stages() -> void:
	_header("INK POOL STAGES", "variants a / b", Vector2(1010.0, 464.0), 820.0)
	var texture: Texture2D = AssetLoader.trim_texture_to_used_rect(AssetLoader.load_texture("res://assets/art/enemies/grave_surgeon.png"))
	for index: int in range(2):
		var origin := Vector2(1010.0 + float(index) * 414.0, 524.0)
		var stage := Stage.new()
		stage.position = origin
		stage.size = Vector2(340.0, 410.0)
		stage.variant = "a" if index == 0 else "b"
		stage.figure_width = 300.0
		stage.feet_anchor = Vector2(0.5, 0.88)
		_host.add_child(stage)
		var figure := TextureRect.new()
		figure.name = "GraveSurgeon%s" % stage.variant.to_upper()
		figure.texture = texture
		figure.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		figure.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		figure.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
		figure.position = origin + Vector2(20.0, 15.0)
		figure.size = Vector2(300.0, stage.size.y * stage.feet_anchor.y - 15.0)
		_host.add_child(figure)
		_label("VARIANT %s" % stage.variant.to_upper(), origin + Vector2(105.0, 426.0), 15, Palette.GOLD)

func _equipment_icon(id: String) -> Texture2D:
	var equipment: Dictionary = GameData.equipment().get(id, {})
	return AssetLoader.load_texture(str(equipment.get("icon_path", "")))

func _header(title: String, count: String, position: Vector2, width: float) -> void:
	var header := Header.new()
	header.position = position
	header.size = Vector2(width, 22.0)
	header.setup(title, count)
	_host.add_child(header)

func _label(text: String, position: Vector2, font_size: int, color: Color) -> void:
	var label := Label.new()
	label.text = text
	label.position = position
	label.add_theme_font_override("font", Typography.ui_font())
	Typography.set_label_size(label, font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_host.add_child(label)

func _assert_gallery() -> void:
	_check(_viewport.size == VIEWPORT and _host.get_viewport() == _viewport, "Gallery must render within a fixed 1920x1080 SubViewport")
	_check(is_equal_approx(Typography.ui_scale(_host), 1.0), "Gallery must use 100% UI scale")
	_check(_sockets.size() == 6 and _strips.size() == 6, "Gallery must include all socket and strip states")
	_check(_socket_grid.size() == 18, "Gallery must show all six socket states at 30, 50 and 62px")
	for socket: Button in _socket_grid.values():
		_check(socket.size.is_equal_approx(Vector2.ONE * socket.socket_size), "Every gallery socket must use its specified square size")
	for socket: Button in _sockets:
		_check(socket.get_node("Ring").texture != null, "Socket must load the approved medallion ring")
		_check(socket.get_global_rect().size.is_equal_approx(Vector2(50.0, 50.0)), "Socket middle row must be 50px square")
		if socket != _sockets[4]:
			_check(socket.get_node("Icon").texture != null, "Populated gallery socket must load its icon")
	_check(_sockets[0].get_node("Badge").visible, "Gallery must show socket badge")
	_check(_sockets[3].selected and _sockets[5].disabled, "Gallery must include selected and disabled sockets")
	for strip: Button in _strips:
		_check(strip.get_node("Art").texture != null, "Every gallery strip must show actual card art")
		_check(is_equal_approx(strip.size.y, 30.0), "Gallery strips must remain 30px tall")
		_check(_host.get_global_rect().encloses(strip.get_global_rect()), "Gallery strips must remain within the viewport")
	_check(_strips[1].get_node("Count").visible and not _strips[0].get_node("Count").visible, "Gallery must include strips with and without counts")
	_check(_strips[3].selected and _strips[5].disabled, "Gallery must include selected and locked strips")
	for figure_name: String in ["GraveSurgeonA", "GraveSurgeonB"]:
		var figure: TextureRect = _host.get_node(figure_name) as TextureRect
		_check(figure.texture != null, "Stages must show the real Grave Surgeon sprite")
	for child: Node in _host.get_children():
		if child.get_script() == Chip:
			_check(child.get_node("Socket/Icon").texture != null, "Stat chips must load purpose-built resource icons")
			var value: Label = child.get_node("Value") as Label
			var caption: Label = child.get_node("Caption") as Label
			var value_baseline: float = value.global_position.y + value.get_theme_font("font").get_ascent(value.get_theme_font_size("font_size"))
			var caption_baseline: float = caption.global_position.y + caption.get_theme_font("font").get_ascent(caption.get_theme_font_size("font_size"))
			_check(is_equal_approx(value_baseline, caption_baseline), "Every stat chip must align its caption to its value baseline")
			_check((child as Control).get_global_rect().encloses(caption.get_global_rect()), "Stat chip captions must remain inside their pills")

func _assert_socket_tints() -> void:
	for socket: Button in _socket_grid.values():
		_assert_socket_tint(socket)
	for child: Node in _host.get_children():
		if child.get_script() == Chip:
			_assert_socket_tint(child.get_node("Socket") as Button)

func _assert_socket_tint(socket: Button) -> void:
	var active: bool = socket.interactive and not socket.disabled and (socket.is_hovered() or socket.has_focus())
	var expected: Color = Color(0.72, 0.68, 0.62, 1.0) if socket.disabled else (Color(1.5, 1.36, 1.12, 1.0) if active else socket.ring_tint)
	if socket.get_node("Icon").texture == null:
		expected.a *= 0.45
	_check((socket.get_node("Ring") as TextureRect).modulate.is_equal_approx(expected), "Rendered sockets must use the normal, hover/focus, empty and disabled ring tints")

func _hover(control: Control, point: Vector2 = Vector2.ZERO) -> void:
	var target: Vector2 = control.get_global_rect().get_center() if point == Vector2.ZERO else point
	var event := InputEventMouseMotion.new()
	event.position = target
	event.global_position = target
	_viewport.push_input(event, true)
	await process_frame
	await process_frame

func _capture(filename: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_assert_socket_tints()
	var image: Image = _viewport.get_texture().get_image()
	if image == null or image.is_empty():
		_fail("Gallery must capture a renderer image")
		return
	if image.get_size() != VIEWPORT:
		_fail("Gallery renderer must produce exactly 1920x1080, got %s" % image.get_size())
		return
	var path: String = OUTPUT_DIR.path_join(filename)
	_check(image.save_png(path) == OK, "Gallery screenshot must save successfully")
	print(ProjectSettings.globalize_path(path))

func _check(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
	print("TEST RESULT: FAIL %s" % message)
