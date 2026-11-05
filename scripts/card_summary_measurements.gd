extends RefCounted

# Shared shaping results, keyed by the actual font resource and rendered size.
# A bounded working set covers hands without retaining arbitrary override text.
const MAX_WIDTHS_PER_FONT: int = 2048
static var _fonts: Dictionary = {}

static func _measurements(font: Font) -> Dictionary:
	var id: int = font.get_instance_id()
	if not _fonts.has(id):
		# Do not bind/retain the font in its own changed signal. That would keep
		# it and this script alive after the owning theme has been released.
		for old_id: int in _fonts.keys():
			if (_fonts[old_id]["font"] as WeakRef).get_ref() == null:
				_fonts.erase(old_id)
		_fonts[id] = {"widths": {}, "heights": {}, "multiline": {}, "revision": 0, "font": weakref(font)}
		font.changed.connect(_font_changed.bind(id))
	return _fonts[id]

static func _font_changed(id: int) -> void:
	var entry: Dictionary = _fonts[id]
	entry["widths"].clear()
	entry["heights"].clear()
	entry["multiline"].clear()
	entry["revision"] += 1

static func font_revision(font: Font) -> int:
	return int(_measurements(font)["revision"]) if font != null else 0

static func text_width(font: Font, font_size: int, text: String, alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> float:
	var widths: Dictionary = _measurements(font)["widths"]
	var key: Array = [font_size, text, alignment]
	if not widths.has(key):
		if widths.size() >= MAX_WIDTHS_PER_FONT:
			widths.clear()
		widths[key] = font.get_string_size(text, alignment, -1.0, font_size).x
	return float(widths[key])

static func text_height(font: Font, font_size: int) -> float:
	var heights: Dictionary = _measurements(font)["heights"]
	if not heights.has(font_size):
		heights[font_size] = font.get_height(font_size)
	return float(heights[font_size])

static func multiline_height(font: Font, font_size: int, text: String, width: float) -> float:
	var multiline: Dictionary = _measurements(font)["multiline"]
	var key: Array = [font_size, text, width]
	if not multiline.has(key):
		if multiline.size() >= MAX_WIDTHS_PER_FONT:
			multiline.clear()
		multiline[key] = font.get_multiline_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, width, font_size).y
	return float(multiline[key])
