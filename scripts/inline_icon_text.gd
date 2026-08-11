extends RefCounted
class_name InlineIconText

const ActionIcons = preload("res://scripts/action_icon_library.gd")

const TOKEN_PREFIX: String = "@icon("
const TOKEN_SUFFIX: String = ")"
const DEFAULT_ICON_SCALE: float = 1.15


static func has_icons(markup: String) -> bool:
	return markup.find(TOKEN_PREFIX) >= 0


static func icon_keys(markup: String) -> Array[String]:
	var result: Array[String]
	var cursor: int = 0
	while cursor < markup.length():
		var token_start: int = markup.find(TOKEN_PREFIX, cursor)
		if token_start < 0:
			break
		var key_start: int = token_start + TOKEN_PREFIX.length()
		var token_end: int = markup.find(TOKEN_SUFFIX, key_start)
		if token_end < 0:
			break
		var icon_key: String = markup.substr(key_start, token_end - key_start)
		if not icon_key.is_empty():
			result.append(icon_key)
		cursor = token_end + TOKEN_SUFFIX.length()
	return result


static func invalid_icon_keys(markup: String) -> Array[String]:
	var result: Array[String]
	for icon_key: String in icon_keys(markup):
		if ActionIcons.icon_path(icon_key).is_empty() and not result.has(icon_key):
			result.append(icon_key)
	return result


static func apply_to(label: RichTextLabel, markup: String, icon_scale: float = DEFAULT_ICON_SCALE) -> void:
	if label == null:
		return
	label.clear()
	var font_size: int = label.get_theme_font_size("normal_font_size")
	var icon_size: float = maxf(12.0, float(font_size) * icon_scale)
	label.set_meta("inline_icon_keys", icon_keys(markup))
	label.set_meta("inline_icon_font_size", font_size)
	label.set_meta("inline_icon_size", icon_size)
	var cursor: int = 0
	while cursor < markup.length():
		var token_start: int = markup.find(TOKEN_PREFIX, cursor)
		if token_start < 0:
			label.add_text(markup.substr(cursor))
			break
		label.add_text(markup.substr(cursor, token_start - cursor))
		var key_start: int = token_start + TOKEN_PREFIX.length()
		var token_end: int = markup.find(TOKEN_SUFFIX, key_start)
		if token_end < 0:
			label.add_text(markup.substr(token_start))
			break
		var icon_key: String = markup.substr(key_start, token_end - key_start)
		var texture: Texture2D = ActionIcons.icon_texture(icon_key)
		if texture == null:
			label.add_text(markup.substr(token_start, token_end + 1 - token_start))
		else:
			var icon_label: String = ActionIcons.label(icon_key)
			label.add_image(
				texture,
				icon_size,
				icon_size,
				Color.WHITE,
				5,
				Rect2(),
				null,
				false,
				icon_label,
				0,
				0,
				icon_label
			)
		cursor = token_end + TOKEN_SUFFIX.length()


static func plain_text(markup: String) -> String:
	var result: String = ""
	var cursor: int = 0
	while cursor < markup.length():
		var token_start: int = markup.find(TOKEN_PREFIX, cursor)
		if token_start < 0:
			result += markup.substr(cursor)
			break
		result += markup.substr(cursor, token_start - cursor)
		var key_start: int = token_start + TOKEN_PREFIX.length()
		var token_end: int = markup.find(TOKEN_SUFFIX, key_start)
		if token_end < 0:
			result += markup.substr(token_start)
			break
		var icon_key: String = markup.substr(key_start, token_end - key_start)
		result += ActionIcons.label(icon_key) if not ActionIcons.icon_path(icon_key).is_empty() else markup.substr(token_start, token_end + 1 - token_start)
		cursor = token_end + TOKEN_SUFFIX.length()
	return result
