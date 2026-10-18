extends TextureRect

# A static presentation mask derived from the selected card's existing painted
# frame. No art is authored: distance from that frame's alpha silhouette controls
# the outward-only feather, and the body remains transparent.
const Palette = preload("res://scripts/ui_palette.gd")
const FEATHER_RADIUS: int = 56
const PEAK_ALPHA: float = 0.30
const ALPHA_COVERAGE_THRESHOLD: float = 0.5
static var _textures: Dictionary = {}

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_SCALE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	self_modulate = Color(Palette.DANGER, PEAK_ALPHA)

func configure(frame: StyleBoxTexture, card_size: Vector2i) -> void:
	var key: String = "%s/%s/%s/%s/%s/%s" % [frame.texture.get_instance_id(), card_size, frame.texture_margin_left, frame.texture_margin_top, frame.texture_margin_right, frame.texture_margin_bottom]
	if not _textures.has(key):
		_textures[key] = ImageTexture.create_from_image(feather_image(_frame_mask(frame, card_size), FEATHER_RADIUS))
	texture = _textures[key]

static func _frame_mask(frame: StyleBoxTexture, card_size: Vector2i) -> Image:
	var source: Image = frame.texture.get_image()
	if source.is_compressed(): source.decompress()
	# Match CardWidget's nine-patch stretch, including its unscaled 34px rails.
	var x_source := PackedInt32Array([0, int(frame.texture_margin_left), source.get_width() - int(frame.texture_margin_right), source.get_width()])
	var y_source := PackedInt32Array([0, int(frame.texture_margin_top), source.get_height() - int(frame.texture_margin_bottom), source.get_height()])
	var x_target := PackedInt32Array([0, x_source[1], card_size.x - int(frame.texture_margin_right), card_size.x])
	var y_target := PackedInt32Array([0, y_source[1], card_size.y - int(frame.texture_margin_bottom), card_size.y])
	var result := Image.create(card_size.x, card_size.y, false, Image.FORMAT_RGBA8)
	for row: int in range(3):
		for column: int in range(3):
			var patch: Image = source.get_region(Rect2i(x_source[column], y_source[row], x_source[column + 1] - x_source[column], y_source[row + 1] - y_source[row]))
			patch.resize(x_target[column + 1] - x_target[column], y_target[row + 1] - y_target[row], Image.INTERPOLATE_BILINEAR)
			patch.convert(Image.FORMAT_RGBA8)
			result.blit_rect(patch, Rect2i(Vector2i.ZERO, patch.get_size()), Vector2i(x_target[column], y_target[row]))
	return result

static func feather_image(mask: Image, radius: int) -> Image:
	var width: int = mask.get_width() + radius * 2
	var height: int = mask.get_height() + radius * 2
	var distances := PackedFloat64Array()
	distances.resize(width * height)
	distances.fill(INF)
	for y: int in range(mask.get_height()):
		for x: int in range(mask.get_width()):
			if mask.get_pixel(x, y).a >= ALPHA_COVERAGE_THRESHOLD:
				distances[(y + radius) * width + x + radius] = 0.0
	# Exact separable squared Euclidean distance transform; work stays linear
	# in image area rather than searching a 56px neighbourhood for every pixel.
	for y: int in range(height):
		var line: PackedFloat64Array = distances.slice(y * width, (y + 1) * width)
		var transformed: PackedFloat64Array = _squared_distance(line)
		for x: int in range(width): distances[y * width + x] = transformed[x]
	var result := Image.create(width, height, false, Image.FORMAT_RGBA8)
	for x: int in range(width):
		var line := PackedFloat64Array()
		line.resize(height)
		for y: int in range(height): line[y] = distances[y * width + x]
		var transformed: PackedFloat64Array = _squared_distance(line)
		for y: int in range(height):
			var squared: float = transformed[y]
			var alpha: float = 0.0
			if squared > 0.0 and not is_inf(squared):
				# Pixel coverage puts the silhouette edge half a texel from its
				# opaque centres. Smoothstep has no hard rim at either endpoint.
				var outward: float = maxf(0.0, sqrt(squared) - 0.5)
				alpha = 1.0 - smoothstep(0.0, float(radius), outward)
			result.set_pixel(x, y, Color(1, 1, 1, alpha))
	return result

static func _squared_distance(line: PackedFloat64Array) -> PackedFloat64Array:
	var sites := PackedInt32Array()
	var starts := PackedFloat64Array()
	var result := PackedFloat64Array()
	sites.resize(line.size())
	starts.resize(line.size())
	result.resize(line.size())
	result.fill(INF)
	var last: int = -1
	for position: int in range(line.size()):
		if is_inf(line[position]): continue
		var start: float = -INF
		while last >= 0:
			var previous: int = sites[last]
			start = (line[position] + float(position * position) - line[previous] - float(previous * previous)) / float(2 * (position - previous))
			if start > starts[last]: break
			last -= 1
		last += 1
		sites[last] = position
		starts[last] = -INF if last == 0 else start
	if last < 0: return result
	var active: int = 0
	for position: int in range(line.size()):
		while active < last and starts[active + 1] < float(position): active += 1
		var delta: int = position - sites[active]
		result[position] = float(delta * delta) + line[sites[active]]
	return result
