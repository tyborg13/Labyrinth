extends RefCounted

const View = preload("res://scripts/aoe_pattern_view.gd")
const Syntax: String = "@pattern\\(([a-z0-9_]+)(?::([0-9]+))?(?::(origin|hero))?\\)"
const RULE_COPY: String = "res://data/pattern_rule_text.json"
static var _rule_copy: Dictionary
static var _syntax: RegEx
static var _textures: Dictionary = {}

static func display_rules(text: String) -> String:
	if _rule_copy.is_empty():
		_rule_copy = (JSON.parse_string(FileAccess.get_file_as_string(RULE_COPY)) as Dictionary).get("copy", {})
	# Match whole rule lines so a generic concept never rewrites unrelated text.
	var lines: PackedStringArray = text.split("\n")
	for index: int in range(lines.size()):
		if _rule_copy.has(lines[index]): lines[index] = _rule_copy[lines[index]]
	return "\n".join(lines)

static func matches(text: String) -> Array[RegExMatch]:
	if _syntax == null:
		_syntax = RegEx.create_from_string(Syntax)
	return _syntax.search_all(text)

static func strip(text: String) -> String:
	for token: RegExMatch in matches(text):
		text = text.replace(token.get_string() + " ", "").replace(token.get_string(), "")
	return text

static func diagram(shape: String, extent: int = 0, origin: String = "") -> String:
	var size_suffix: String = ":%d" % extent if extent > 0 else ""
	var origin_suffix: String = ":" + origin if not origin.is_empty() else ""
	return "@pattern(%s%s%s)" % [shape, size_suffix, origin_suffix]

static func offsets(shape: String, extent: int = 0) -> Array[Vector2i]:
	var result: Array[Vector2i]
	if shape.begins_with("ring_"): return radial_offsets(int(shape.trim_prefix("ring_")), extent, Vector2i(2, 2))
	match shape:
		"cross":
			result.assign(preload("res://scripts/burst_rules.gd").OFFSETS)
		"neighbors":
			result.assign([Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT])
		"surround", "square":
			for y: int in range(-1, 2):
				for x: int in range(-1, 2):
					if shape == "square" or x != 0 or y != 0: result.append(Vector2i(x, y))
		"diamond", "hollow_diamond":
			for y: int in range(-extent, extent + 1):
				var span: int = extent - absi(y)
				for x: int in range(-span, span + 1):
					if shape == "diamond" or x != 0 or y != 0: result.append(Vector2i(x, y))
		"body_cross":
			return body_cross_offsets(extent, Vector2i(2, 2))
		"body_area":
			return radial_offsets(1, extent, Vector2i(2, 2))
		"line":
			for x: int in range(extent): result.append(Vector2i(x, 0))
		"beyond":
			for x: int in range(1, extent + 1): result.append(Vector2i(x, 0))
		"icefall":
			result.assign([Vector2i.LEFT, Vector2i.ZERO, Vector2i.RIGHT])
	return result

static func radial_offsets(minimum: int, maximum: int, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for y: int in range(-maximum, footprint.y + maximum):
		for x: int in range(-maximum, footprint.x + maximum):
			var distance: int = maxi(maxi(-x, x - footprint.x + 1), 0) + maxi(maxi(-y, y - footprint.y + 1), 0)
			if distance >= minimum and distance <= maximum: result.append(Vector2i(x, y))
	return result

static func body_cross_offsets(reach: int, footprint: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for y: int in range(-reach, footprint.y + reach):
		for x: int in range(-reach, footprint.x + reach):
			var body_column: bool = x >= 0 and x < footprint.x
			var body_row: bool = y >= 0 and y < footprint.y
			if body_column != body_row: result.append(Vector2i(x, y))
	return result

static func make_view(token: RegExMatch, row_height: float) -> Control:
	var shape: Array[Vector2i] = offsets(token.get_string(1), int(token.get_string(2)))
	var origin: String = token.get_string(3)
	var view := View.new()
	view.setup(shape, not origin.is_empty(), "", _scale(shape, origin, row_height), origin == "hero")
	view.set_meta("inline_pattern_count", 1)
	view.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return view

static func _scale(pattern: Array, origin: String, row_height: float) -> float:
	var full_size: Vector2 = View.measured_size(pattern, not origin.is_empty(), 1.0)
	return clampf(row_height / full_size.y, 0.42, 1.0)

static func texture(token: RegExMatch, row_height: float) -> Texture2D:
	return texture_for_offsets(offsets(token.get_string(1), int(token.get_string(2))), token.get_string(3), row_height)

static func texture_for_offsets(pattern: Array, origin: String, row_height: float) -> Texture2D:
	if pattern.is_empty(): return null
	# Use the same AoE painter and dimensions as the diagram controls.
	var include_origin: bool = not origin.is_empty()
	var scale_factor: float = _scale(pattern, origin, row_height)
	var dimensions := Vector2i(View.measured_size(pattern, include_origin, scale_factor).ceil())
	var key: Array = [pattern, origin, dimensions, scale_factor]
	if _textures.has(key): return _textures[key]
	if DisplayServer.get_name() == "headless":
		var placeholder := PlaceholderTexture2D.new()
		placeholder.size = dimensions
		_textures[key] = placeholder
		return placeholder
	# RichTextLabel can lay out the image immediately. Publish the rendered
	# pixels to that same texture only after the offscreen canvas has drawn.
	var image := ImageTexture.create_from_image(Image.create_empty(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8))
	_textures[key] = image
	_render_texture.call_deferred(image, pattern, origin, scale_factor, dimensions)
	return image

static func _render_texture(image: ImageTexture, pattern: Array, origin: String, scale_factor: float, dimensions: Vector2i) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var viewport := SubViewport.new()
	viewport.size = dimensions
	viewport.transparent_bg = true
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var view := View.new()
	view.setup(pattern, not origin.is_empty(), "", scale_factor, origin == "hero")
	view.size = dimensions
	viewport.add_child(view)
	tree.root.add_child(viewport)
	# Arm the one-shot after the diagram's draw commands have entered the canvas.
	await view.draw
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	var pixels: Image = viewport.get_texture().get_image()
	if pixels != null and not pixels.is_empty():
		pixels.convert(Image.FORMAT_RGBA8)
		image.update(pixels)
	viewport.queue_free()
