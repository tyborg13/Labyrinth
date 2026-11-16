extends RefCounted

# Runtime composition of the director's approved brush masks. CPU images are
# retained by size; neither masks nor blurs are rebuilt during reveal/motion.
const Assets = preload("res://scripts/asset_loader.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const BRUSH_ROOT: String = "res://assets/art/ui/turn_order_ink/"
const BLUR_PASSES: int = 3
# Gaussian masks are smooth; native resampling keeps their working grid small.
# Brush silhouettes and the final cached texture stay at full layout resolution.
const BLUR_DOWNSAMPLE: int = 4
static var _bands: Dictionary = {}
static var band_bakes: int = 0

static func band(dimensions: Vector2i) -> Texture2D:
	if _bands.has(dimensions): return _bands[dimensions]
	var width: int = dimensions.x
	var height: int = dimensions.y
	var main: PackedByteArray = _brush_mask("brush_c.png", dimensions, 0.97)
	var core := PackedByteArray()
	core.resize(width * height)
	var left: int = int(width * 0.07)
	var right: int = int(width * 0.93)
	var top: int = int(height * 0.16)
	var bottom: int = int(height * 0.84)
	for y: int in range(top, bottom + 1):
		var dy: int = y - clampi(y, top + 40, bottom - 40)
		var span: float = sqrt(40 * 40 - dy * dy)
		var row_left: int = ceili(left + 40 - span)
		var row_right: int = floori(right - 40 + span)
		for x: int in range(row_left, row_right + 1): core[y * width + x] = 242
	core = _gaussian(core, dimensions, 18.0)
	for index: int in range(main.size()): main[index] = maxi(main[index], core[index])
	var light: PackedByteArray = _ellipse_mask(dimensions, Rect2(Vector2(int(width * 0.22), -int(height * 0.9)), Vector2(int(width * 0.86) - int(width * 0.22), int(height * 0.5) + int(height * 0.9))), 22)
	light = _gaussian(light, dimensions, 46.0)
	for index: int in range(light.size()): light[index] = light[index] * main[index] / 255
	var under_size := Vector2i(width + 40, height + 26)
	var result := Image.create(width + 40, height + 30, false, Image.FORMAT_RGBA8)
	result.blend_rect(_tinted(_brush_mask("brush_b.png", under_size, 0.70), under_size, Palette.DIALOGUE_UNDER), Rect2i(Vector2i.ZERO, under_size), Vector2i(0, 4))
	result.blend_rect(_tinted(main, dimensions, Palette.DIALOGUE_BAND), Rect2i(Vector2i.ZERO, dimensions), Vector2i(4, 0))
	result.blend_rect(_tinted(light, dimensions, Palette.EMBER), Rect2i(Vector2i.ZERO, dimensions), Vector2i(4, 0))
	var texture: Texture2D = ImageTexture.create_from_image(result)
	_bands[dimensions] = texture
	band_bakes += 1
	return texture

static func _brush_mask(file: String, dimensions: Vector2i, alpha: float) -> PackedByteArray:
	var image: Image = Assets.texture_source_image(Assets.load_texture(BRUSH_ROOT + file)).duplicate()
	image.convert(Image.FORMAT_RGBA8)
	image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_LANCZOS)
	var rgba: PackedByteArray = image.get_data()
	var result := PackedByteArray()
	result.resize(dimensions.x * dimensions.y)
	for index: int in range(result.size()): result[index] = int(rgba[index * 4 + 3] * alpha)
	return result

static func _ellipse_mask(dimensions: Vector2i, ellipse: Rect2, alpha: int) -> PackedByteArray:
	var result := PackedByteArray()
	result.resize(dimensions.x * dimensions.y)
	var center: Vector2 = ellipse.get_center()
	var radius: Vector2 = ellipse.size * 0.5
	for y: int in range(dimensions.y):
		var dy: float = (y - center.y) / radius.y
		if absf(dy) > 1.0: continue
		var span: float = radius.x * sqrt(1.0 - dy * dy)
		var left: int = maxi(0, ceili(center.x - span))
		var right: int = mini(dimensions.x - 1, floori(center.x + span))
		for x: int in range(left, right + 1): result[y * dimensions.x + x] = alpha
	return result

static func _tinted(mask: PackedByteArray, dimensions: Vector2i, color: Color) -> Image:
	var bytes := PackedByteArray()
	bytes.resize(mask.size() * 4)
	var red: int = roundi(color.r * 255.0)
	var green: int = roundi(color.g * 255.0)
	var blue: int = roundi(color.b * 255.0)
	for index: int in range(mask.size()):
		bytes[index * 4] = red
		bytes[index * 4 + 1] = green
		bytes[index * 4 + 2] = blue
		bytes[index * 4 + 3] = mask[index]
	return Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_RGBA8, bytes)

# Three extended box passes are the Gaussian approximation used by Pillow's
# GaussianBlur. Fractional end taps retain the requested sigma at each size.
static func _gaussian(mask: PackedByteArray, dimensions: Vector2i, sigma: float) -> PackedByteArray:
	var original: Vector2i = dimensions
	var image: Image = Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_L8, mask)
	dimensions = Vector2i(maxi(1, roundi(float(dimensions.x) / BLUR_DOWNSAMPLE)), maxi(1, roundi(float(dimensions.y) / BLUR_DOWNSAMPLE)))
	image.resize(dimensions.x, dimensions.y, Image.INTERPOLATE_BILINEAR)
	mask = image.get_data()
	sigma /= BLUR_DOWNSAMPLE
	var variance: float = sigma * sigma / BLUR_PASSES
	var radius: int = floori((sqrt(12.0 * variance + 1.0) - 1.0) * 0.5)
	var fraction: float = (2.0 * radius + 1.0) * (radius * (radius + 1.0) - 3.0 * variance) / (6.0 * (variance - (radius + 1.0) * (radius + 1.0)))
	for pass_index: int in range(BLUR_PASSES):
		mask = _box_pass(mask, dimensions.x, dimensions.y, radius, fraction, false)
	for pass_index: int in range(BLUR_PASSES):
		mask = _box_pass(mask, dimensions.y, dimensions.x, radius, fraction, true)
	image = Image.create_from_data(dimensions.x, dimensions.y, false, Image.FORMAT_L8, mask)
	image.resize(original.x, original.y, Image.INTERPOLATE_LANCZOS)
	return image.get_data()

static func _box_pass(source: PackedByteArray, length: int, lines: int, radius: int, fraction: float, vertical: bool) -> PackedByteArray:
	var output := PackedByteArray()
	output.resize(source.size())
	var stride: int = lines if vertical else 1
	var normalization: float = 2.0 * radius + 1.0 + 2.0 * fraction
	for line: int in range(lines):
		var origin: int = line if vertical else line * length
		var total: int = 0
		for tap: int in range(-radius, radius + 1): total += source[origin + clampi(tap, 0, length - 1) * stride]
		for position: int in range(length):
			var edge: float = source[origin + clampi(position - radius - 1, 0, length - 1) * stride] + source[origin + clampi(position + radius + 1, 0, length - 1) * stride]
			output[origin + position * stride] = roundi((total + edge * fraction) / normalization)
			total += source[origin + clampi(position + radius + 1, 0, length - 1) * stride] - source[origin + clampi(position - radius, 0, length - 1) * stride]
	return output
