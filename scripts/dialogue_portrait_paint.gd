extends RefCounted

# Director v4 portrait material and explicit sprite crops. Independent textures
# preserve scrim/band/shadow/face/halo/rim/bust/text ordering in the view.
const Assets = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Ink = preload("res://scripts/dialogue_ink_paint.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const SIZE := Vector2i(340, 236)
const SHADOW_PADDING: int = 48 # Three sigma at the prescribed 16px blur.
const HALO_PADDING: int = 36 # Three sigma at the prescribed 12px blur.
const HALO_FILTER_WIDTH: int = 11 # Pillow MaxFilter(11), per the director recipe.
const FADE_HEIGHT: int = 40
static var _sources: Dictionary = {}
static var _frame: Dictionary = {}
static var _portraits: Dictionary = {}

static func frame() -> Dictionary:
	if not _frame.is_empty(): return _frame
	var face := Image.create(SIZE.x, SIZE.y, false, Image.FORMAT_RGBA8)
	face.fill(Palette.DIALOGUE_PORTRAIT_FILL)
	# Paint the whole ellipse before clipping its blurred light to the frame.
	var wash_padding: int = 150
	var wash_size: Vector2i = SIZE + Vector2i.ONE * wash_padding * 2
	var wash: PackedByteArray = Ink._ellipse_mask(wash_size, Rect2(Vector2(wash_padding + 20, wash_padding - 80), Vector2(SIZE.x - 40, 80 + int(SIZE.y * 0.75))), 255)
	wash = Ink._gaussian(wash, wash_size, 50.0)
	var wash_image: Image = _filtered_wash(wash, wash_size)
	face.blend_rect(wash_image, Rect2i(Vector2i.ONE * wash_padding, SIZE), Vector2i.ZERO)
	# Follow the recipe's two resizes around its counter-clockwise rotation.
	var texture_size := Vector2i(SIZE.y + 40, SIZE.x + 20)
	var texture: Image = Image.create_from_data(texture_size.x, texture_size.y, false, Image.FORMAT_L8, Ink._brush_mask("brush_c.png", texture_size, 0.30))
	texture.rotate_90(COUNTERCLOCKWISE)
	texture.resize(SIZE.x, SIZE.y, Image.INTERPOLATE_CUBIC)
	face.blend_rect(Ink._tinted(texture.get_data(), SIZE, Palette.DIALOGUE_PORTRAIT_TEXTURE), Rect2i(Vector2i.ZERO, SIZE), Vector2i.ZERO)
	var rim := PackedByteArray()
	rim.resize(SIZE.x * SIZE.y)
	for y: int in range(SIZE.y):
		for x: int in range(SIZE.x):
			if x < 3 or y < 3 or x >= SIZE.x - 3 or y >= SIZE.y - 3:
				rim[y * SIZE.x + x] = 220
			elif (x == 9 or x == SIZE.x - 10) and y >= 9 and y <= SIZE.y - 10:
				rim[y * SIZE.x + x] = 60
			elif (y == 9 or y == SIZE.y - 10) and x >= 9 and x <= SIZE.x - 10:
				rim[y * SIZE.x + x] = 60
	var shadow_size: Vector2i = SIZE + Vector2i.ONE * SHADOW_PADDING * 2
	var shadow := PackedByteArray()
	shadow.resize(shadow_size.x * shadow_size.y)
	for y: int in range(SHADOW_PADDING, SHADOW_PADDING + SIZE.y):
		for x: int in range(SHADOW_PADDING, SHADOW_PADDING + SIZE.x): shadow[y * shadow_size.x + x] = 190
	_frame = {
		"face": ImageTexture.create_from_image(face),
		"rim": ImageTexture.create_from_image(Ink._tinted(rim, SIZE, Palette.DIALOGUE_PORTRAIT_RIM)),
		"shadow": ImageTexture.create_from_image(Ink._tinted(Ink._gaussian(shadow, shadow_size, 16.0), shadow_size, Palette.INK_0)),
	}
	return _frame

static func source_texture(path: String) -> Texture2D:
	if path.is_empty(): return null
	var resolved: String = path if CelLook.mode == "off" else CelLook.variant_path(path)
	if resolved.is_empty():
		push_error("Dialogue portrait requires the cel variant while cel look is on: " + path)
		return null
	if not _sources.has(resolved):
		if CelLook.mode == "off":
			var original: Texture2D = Assets.load_original_texture(path, true)
			if original != null:
				original.set_meta("portrait_source_path", path)
				_sources[resolved] = original
			return original
		var image := Image.new()
		var error: Error = image.load_png_from_buffer(FileAccess.get_file_as_bytes(resolved))
		if error != OK:
			push_error("Unable to load dialogue portrait: " + resolved)
			return null
		var texture: Texture2D = ImageTexture.create_from_image(image)
		texture.set_meta("portrait_source_path", resolved)
		_sources[resolved] = texture
	return _sources[resolved]

static func portrait(definition: Dictionary, source: Texture2D) -> Dictionary:
	var authored: Dictionary = definition.get("portrait_bust", {})
	if source == null or not authored.has_all(["top", "bottom", "center_x"]): return {}
	var scale: int = int(definition.get("portrait_scale", 0))
	if scale <= 0: return {}
	var source_image: Image = Assets.texture_source_image(source)
	var rect := Rect2i(0, int(authored["top"]), source_image.get_width(), int(authored["bottom"]) - int(authored["top"]))
	if not rect.has_area(): return {}
	var center_x: int = int(authored["center_x"]) * scale
	var key: Array = [source, rect, scale, center_x]
	if _portraits.has(key): return _portraits[key]
	var image: Image = source_image.get_region(rect)
	image.convert(Image.FORMAT_RGBA8)
	image.resize(rect.size.x * scale, rect.size.y * scale, Image.INTERPOLATE_NEAREST)
	var dimensions: Vector2i = image.get_size()
	var pixels: PackedByteArray = image.get_data()
	var alpha := PackedByteArray()
	alpha.resize(dimensions.x * dimensions.y)
	var window_left: int = center_x - SIZE.x / 2 + 3
	var window_right: int = center_x + SIZE.x / 2 - 3
	var pop: int = dimensions.y - SIZE.y
	var visible := Rect2i()
	var bounds_left: int = dimensions.x
	var bounds_right: int = -1
	var bounds_top: int = dimensions.y
	var bounds_bottom: int = -1
	for y: int in range(dimensions.y):
		var fade: float = 1.0
		if y >= dimensions.y - FADE_HEIGHT: fade = pow(1.0 - float(y - (dimensions.y - FADE_HEIGHT)) / FADE_HEIGHT, 1.3)
		for x: int in range(dimensions.x):
			var index: int = y * dimensions.x + x
			pixels[index * 4 + 3] = int(pixels[index * 4 + 3] * fade)
			# The halo uses the same final clipped silhouette as the mockup.
			alpha[index] = pixels[index * 4 + 3] if y < pop or (x >= window_left and x < window_right) else 0
			if alpha[index] > 0:
				bounds_left = mini(bounds_left, x)
				bounds_right = maxi(bounds_right, x)
				bounds_top = mini(bounds_top, y)
				bounds_bottom = maxi(bounds_bottom, y)
	if bounds_right >= bounds_left: visible = Rect2i(bounds_left, bounds_top, bounds_right - bounds_left + 1, bounds_bottom - bounds_top + 1)
	var bust: Texture2D = ImageTexture.create_from_image(Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, pixels))
	bust.set_meta("portrait_bust", authored.duplicate())
	bust.set_meta("portrait_source_region", rect)
	bust.set_meta("portrait_scale", scale)
	bust.set_meta("portrait_source_path", source.get_meta("portrait_source_path"))
	bust.set_meta("portrait_visible_bounds", visible)
	alpha = _max_filter(alpha, dimensions, false)
	alpha = _max_filter(alpha, dimensions, true)
	var halo_size: Vector2i = dimensions + Vector2i.ONE * HALO_PADDING * 2
	var padded := Image.create(halo_size.x, halo_size.y, false, Image.FORMAT_L8)
	padded.blit_rect(Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_L8, alpha), Rect2i(Vector2i.ZERO, dimensions), Vector2i.ONE * HALO_PADDING)
	var halo: PackedByteArray = Ink._gaussian(padded.get_data(), halo_size, 12.0)
	for index: int in range(halo.size()): halo[index] = int(halo[index] * 0.6)
	var result := {"bust": bust, "halo": ImageTexture.create_from_image(Ink._tinted(halo, halo_size, Palette.INK_0))}
	_portraits[key] = result
	return result

static func _filtered_wash(mask: PackedByteArray, dimensions: Vector2i) -> Image:
	# Pillow's RGBA blur softens RGB and alpha, then clips just the alpha.
	var bytes := PackedByteArray()
	bytes.resize(mask.size() * 4)
	var color: Color = Palette.DIALOGUE_PORTRAIT_WASH
	for index: int in range(mask.size()):
		bytes[index * 4] = roundi(color.r * mask[index])
		bytes[index * 4 + 1] = roundi(color.g * mask[index])
		bytes[index * 4 + 2] = roundi(color.b * mask[index])
		bytes[index * 4 + 3] = int(180.0 * mask[index] / 255.0)
	return Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, bytes)

static func _max_filter(source: PackedByteArray, dimensions: Vector2i, vertical: bool) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(source.size())
	var length: int = dimensions.y if vertical else dimensions.x
	var lines: int = dimensions.x if vertical else dimensions.y
	var stride: int = dimensions.x if vertical else 1
	var radius: int = HALO_FILTER_WIDTH / 2
	for line: int in range(lines):
		var origin: int = line if vertical else line * length
		for position: int in range(length):
			var value: int = 0
			for tap: int in range(maxi(0, position - radius), mini(length - 1, position + radius) + 1): value = maxi(value, source[origin + tap * stride])
			output[origin + position * stride] = value
	return output
