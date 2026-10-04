extends RefCounted

const Socket = preload("res://scripts/ui_socket.gd")
const Strip = preload("res://scripts/ui_card_strip.gd")
const Header = preload("res://scripts/ui_section_header.gd")
const Chip = preload("res://scripts/ui_stat_chip.gd")
const Stage = preload("res://scripts/ui_ink_pool_stage.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const GameData = preload("res://scripts/game_data.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Surface = preload("res://scripts/ui_component_surface.gd")

static func run(tree: SceneTree, expect: Callable) -> void:
	var host := Control.new()
	host.size = Vector2(1000.0, 600.0)
	tree.root.add_child(host)
	var socket := Socket.new()
	socket.position = Vector2(60.0, 60.0)
	socket.setup(AssetLoader.load_texture("res://assets/art/icons/melee.png"), "Inspect equipment", "3")
	host.add_child(socket)
	var strip := Strip.new()
	strip.position = Vector2(180.0, 60.0)
	strip.size = Vector2(320.0, 30.0)
	strip.setup("quick_stab", "Quick Stab", 2)
	host.add_child(strip)
	var header := Header.new()
	header.setup("Deck", "17 cards")
	header.position = Vector2(60.0, 160.0)
	header.size = Vector2(480.0, 22.0)
	host.add_child(header)
	var chip := Chip.new()
	chip.setup(socket.get_node("Icon").texture, "24/24", "Health", Palette.ALLY)
	chip.position = Vector2(60.0, 220.0)
	host.add_child(chip)
	var stage := Stage.new()
	stage.position = Vector2(600.0, 60.0)
	stage.size = Vector2(280.0, 400.0)
	stage.variant = "b"
	stage.feet_anchor = Vector2(0.5, 0.9)
	stage.pool_size = Vector2(230.0, 58.0)
	host.add_child(stage)
	await tree.process_frame
	await tree.process_frame
	await _check_socket_geometry(tree, host, expect)
	await _check_socket_resources(tree, host, socket, stage, expect)
	expect.call(socket.focus_mode == Control.FOCUS_ALL, "Interactive sockets must support native focus")
	expect.call(socket.tooltip_text == "Inspect equipment", "Socket setup must preserve tooltip copy")
	expect.call(socket.get_node("Badge").visible and socket.get_node("Badge").text == "3", "Socket badge must show its setup count")
	var presses: Array = [0]
	socket.pressed.connect(func() -> void: presses[0] += 1)
	await _mouse_click(tree, socket)
	expect.call(presses[0] == 1, "Socket pointer release must emit pressed once")
	await _move_mouse(tree, Vector2(950.0, 550.0))
	expect.call(socket.has_focus() and not socket.has_focus(true) and not socket.call("_socket_active"), "A socket's hidden pointer focus must not keep its glow active after hover leaves")
	socket.grab_focus()
	expect.call(socket.has_focus(true) and socket.call("_socket_active"), "Keyboard focus must still activate the socket's glow without pointer hover")
	await _key_activate(tree)
	expect.call(presses[0] == 2, "Socket keyboard activation must emit pressed once")
	await _controller_activate(tree)
	expect.call(presses[0] == 3, "Socket controller activation must emit pressed once")
	socket.disabled = true
	await _key_activate(tree)
	expect.call(presses[0] == 3, "Disabled socket must reject activation")
	socket.disabled = false
	socket.setup(null)
	expect.call(not socket.get_node("Badge").visible and socket.get_node("Icon").texture == null, "Empty socket setup must clear icon and badge")
	socket.interactive = false
	expect.call(socket.focus_mode == Control.FOCUS_NONE and socket.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Display-only socket must not capture focus or mouse input")
	await _mouse_click(tree, socket)
	expect.call(presses[0] == 3, "Display-only socket must reject pointer activation")
	var strip_presses: Array = [0]
	var inspections: Array = []
	strip.pressed.connect(func() -> void: strip_presses[0] += 1)
	strip.hovered.connect(func(id: String) -> void: inspections.append("hover:" + id))
	strip.unhovered.connect(func(id: String) -> void: inspections.append("exit:" + id))
	await _move_mouse(tree, strip.get_global_rect().get_center())
	expect.call(inspections == ["hover:quick_stab"], "Strip mouse hover must emit the card identity")
	strip.grab_focus()
	await tree.process_frame
	expect.call(inspections.size() == 1, "Overlapping hover and focus must not duplicate inspection")
	await _mouse_click(tree, strip)
	await _move_mouse(tree, Vector2(950.0, 550.0))
	expect.call(strip.has_focus() and not strip.has_focus(true) and inspections == ["hover:quick_stab", "exit:quick_stab"], "Hidden pointer focus must end strip inspection when hover leaves")
	strip.release_focus()
	strip.grab_focus()
	await tree.process_frame
	expect.call(inspections == ["hover:quick_stab", "exit:quick_stab", "hover:quick_stab"], "Keyboard focus must restore strip inspection without pointer hover")
	await _key_activate(tree)
	await _controller_activate(tree)
	expect.call(strip_presses[0] == 3, "Strip pointer, keyboard and controller activation must each emit pressed")
	await _move_mouse(tree, Vector2(950.0, 550.0))
	expect.call(inspections.size() == 3, "Strip keyboard focus must retain inspection after the pointer leaves")
	strip.release_focus()
	await tree.process_frame
	expect.call(inspections == ["hover:quick_stab", "exit:quick_stab", "hover:quick_stab", "exit:quick_stab"], "Strip inspection must close after both hover and keyboard focus leave")
	expect.call(strip.get_node("Count").visible and strip.get_node("Count").text == "×2", "Strip must show counts above one")
	expect.call(strip.get_node("Art").texture.get_meta("asset_source_path") == str(GameData.card_def("quick_stab").get("art_path")), "Strip must resolve CardWidget's art path")
	var override: Dictionary = GameData.card_def("pale_spark").duplicate(true)
	strip.setup("quick_stab", "An exceptionally long card name that must be clipped only when necessary", 1, override)
	expect.call(not strip.get_node("Count").visible, "Single-copy strip must hide its count")
	expect.call(strip.get_node("Art").texture.get_meta("asset_source_path") == str(override.get("art_path")), "Strip must respect supplied card art overrides")
	expect.call(strip.get_node("Name").text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS, "Long strip names must use ellipsis")
	strip.locked = true
	strip.grab_focus()
	await _mouse_click(tree, strip)
	await _key_activate(tree)
	expect.call(strip_presses[0] == 3 and strip.disabled, "Locked strip must reject pointer and keyboard activation")
	header.setup("Deck")
	expect.call(not header.get_node("Count").visible, "Section setup must hide an omitted count")
	expect.call(chip.get_node("Socket").focus_mode == Control.FOCUS_NONE, "Stat chip socket must be display-only")
	expect.call(chip.get_node("Value").text == "24/24" and chip.get_node("Value").get_theme_color("font_color") == Palette.ALLY, "Stat chip must preserve value and semantic color")
	expect.call(chip.get_combined_minimum_size().x > 100.0, "Stat chip width must fit its content")
	var chip_value: Label = chip.get_node("Value") as Label
	var chip_caption: Label = chip.get_node("Caption") as Label
	expect.call(is_equal_approx(_label_baseline(chip_value), _label_baseline(chip_caption)), "Stat chip caption and value must share a baseline")
	expect.call(chip.get_global_rect().encloses(chip_value.get_global_rect()) and chip.get_global_rect().encloses(chip_caption.get_global_rect()), "Baseline-aligned stat text must remain within its pill")
	expect.call(chip.get_node("Socket").ring_tint == socket.ring_tint, "Stat chips must reuse the shared muted socket tint")
	expect.call(stage.mouse_filter == Control.MOUSE_FILTER_IGNORE and stage.variant == "b", "Ink pool stage must ignore input and retain variant")
	host.queue_free()
	await tree.process_frame

static func _check_socket_resources(tree: SceneTree, host: Control, socket: Button, stage: Control, expect: Callable) -> void:
	var sample := Socket.new()
	sample.position = Vector2(60.0, 330.0)
	sample.setup(socket.get_node("Icon").texture, "Equipment sample")
	host.add_child(sample)
	var second_stage := Stage.new()
	host.add_child(second_stage)
	expect.call(sample.get("_glow") == socket.get("_glow"), "Sockets must share their radial glow texture")
	expect.call(stage.get("_spotlight") == second_stage.get("_spotlight"), "Ink pool stages must share their radial spotlight texture")
	var color := Color(0.21, 0.34, 0.55, 0.6)
	expect.call(Surface.radial_texture(color) == Surface.radial_texture(color), "Matching radial colors must reuse one texture")
	expect.call(Surface.radial_texture(color) != Surface.radial_texture(Color(color, 0.3)), "Distinct radial colors must retain distinct textures")
	expect.call(Surface.radial_texture(color) != Surface.radial_texture(color, 0.7), "Distinct radial falloffs must retain distinct textures")
	var normal_material: ShaderMaterial = socket.get_node("Icon").material as ShaderMaterial
	expect.call(sample.get_node("Icon").material == normal_material, "Normal socket icons must share one immutable material")
	sample.disabled = true
	sample.call("_update_icon_material")
	var disabled_material: ShaderMaterial = sample.get_node("Icon").material as ShaderMaterial
	expect.call(disabled_material != normal_material and is_equal_approx(float(disabled_material.get_shader_parameter("saturation")), 0.35), "Disabled socket icons must select the cached desaturated material")
	expect.call(is_equal_approx(float(normal_material.get_shader_parameter("saturation")), 1.0), "Disabling one socket must preserve other icons' saturation")
	expect.call(disabled_material == Surface.socket_material(0.35), "Disabled sockets must reuse the shared desaturated material")
	sample.queue_free()
	second_stage.queue_free()
	await tree.process_frame

static func _check_socket_geometry(tree: SceneTree, host: Control, expect: Callable) -> void:
	var image := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var used := Rect2i(19, 7, 14, 38)
	image.fill_rect(used, Color.WHITE)
	var padded := ImageTexture.create_from_image(image)
	var geometry: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Socket.GEOMETRY_PATH)) as Dictionary
	var previous_crop: Texture2D
	for diameter: float in [30.0, 50.0, 62.0]:
		var sample := Socket.new()
		expect.call(sample.ring_tint == Color(1.14, 1.06, 0.96, 1.0), "Socket ring_tint must default to warm-lifted bronze")
		sample.socket_size = diameter
		sample.position = Vector2(900.0, 440.0)
		sample.setup(padded)
		host.add_child(sample)
		await tree.process_frame
		var icon: TextureRect = sample.get_node("Icon") as TextureRect
		var opening: float = 2.0 * float(geometry["inner_radius"]) * sample.size.x / float(geometry["size"][0])
		expect.call(icon.size.is_equal_approx(Vector2.ONE * opening * 0.92), "Every socket size must fill 92% of the measured ring opening")
		var crop: AtlasTexture = icon.texture as AtlasTexture
		expect.call(crop != null and crop.atlas == padded and crop.region == Rect2(used), "Pixel-art socket icons must crop transparent padding to opaque bounds")
		if previous_crop != null:
			expect.call(icon.texture == previous_crop, "Sockets sharing an icon must reuse the cached cropped texture")
		previous_crop = icon.texture
		sample.icon_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		expect.call(icon.texture == padded, "Non-pixel-art icons must retain their authored bounds")
		sample.icon_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		expect.call(icon.texture == previous_crop, "Returning to pixel filtering must reuse the cached crop")
		# A thinner replacement and different source dimensions must change the opening without code edits.
		sample.set("_geometry", {"size": [512, 512], "center": [256.0, 256.0], "outer_radius": 240.0, "inner_radius": 210.0})
		sample.call("_layout")
		expect.call(is_equal_approx(icon.size.x, 420.0 * sample.size.x / 512.0 * 0.92), "Socket layout must use runtime metadata for replacement ring geometry")
		sample.queue_free()
		await tree.process_frame

static func _label_baseline(label: Label) -> float:
	return label.global_position.y + label.get_theme_font("font").get_ascent(label.get_theme_font_size("font_size"))

static func _move_mouse(tree: SceneTree, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	tree.root.push_input(motion, true)
	await tree.process_frame

static func _mouse_click(tree: SceneTree, button: Button) -> void:
	var point: Vector2 = button.get_global_rect().get_center()
	await _move_mouse(tree, point)
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

static func _key_activate(tree: SceneTree) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame

static func _controller_activate(tree: SceneTree) -> void:
	for down: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = down
		tree.root.push_input(event, true)
		await tree.process_frame
