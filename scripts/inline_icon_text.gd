extends RefCounted
class_name InlineIconText

const ActionIcons = preload("res://scripts/action_icon_library.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")
const Glossary = preload("res://scripts/glossary.gd")
const UiPalette = preload("res://scripts/ui_palette.gd")
const TokenSyntax = preload("res://scripts/inline_token_syntax.gd")
const DEFAULT_ICON_SCALE: float = 1.15
# All explicit concept words share this colour and inherit host typography.
const KEYWORD_COLOR: Color = UiPalette.GOLD_BRIGHT

# RichTextLabel hit-tests both inline images and hint spans. Opt-in preserves
# existing noninteractive labels and labels with their own custom scripts.
class GlossaryRichLabel extends RichTextLabel:
	func _make_custom_tooltip(for_text: String) -> Object:
		return load("res://scripts/ui_tooltip_panel.gd").make_text(for_text)

static func _tokens(markup: String) -> Array[RegExMatch]:
	return TokenSyntax.tokens(markup)

# Historical name: callers use this to choose RichTextLabel over Label, so
# word-only @kw markup must also take the rich-text path.
static func has_icons(markup: String) -> bool:
	return not _tokens(markup).is_empty()

static func concept_keys(markup: String) -> Array[String]:
	var result: Array[String]
	for token: RegExMatch in _tokens(markup):
		result.append(token.get_string(2))
	return result

static func icon_keys(markup: String) -> Array[String]:
	var result: Array[String]
	for token: RegExMatch in _tokens(markup):
		if token.get_string(1) == "kw": continue
		var key: String = token.get_string(2)
		if token.get_string(1) == "icon" or Glossary.lookup(key).get("icon") != null:
			result.append(key)
	return result

static func invalid_icon_keys(markup: String) -> Array[String]:
	var result: Array[String]
	for token: RegExMatch in _tokens(markup):
		var key: String = token.get_string(2)
		if Glossary.lookup(key).is_empty() or (token.get_string(1) == "icon" and ActionIcons.icon_path(key).is_empty()):
			if not result.has(key): result.append(key)
	return result

static func _word(token: RegExMatch) -> String:
	return token.get_string(3) if not token.get_string(3).is_empty() else Glossary.name_for(token.get_string(2))

static func apply_to(label: RichTextLabel, markup: String, icon_scale: float = DEFAULT_ICON_SCALE, install_glossary_tooltip: bool = false) -> void:
	if label == null: return
	if install_glossary_tooltip and label.get_script() == null:
		label.set_script(GlossaryRichLabel)
	label.clear()
	var font_size: int = label.get_theme_font_size("normal_font_size")
	var icon_size: float = maxf(12.0, float(font_size) * icon_scale)
	label.set_meta("inline_icon_keys", icon_keys(markup))
	label.set_meta("inline_concept_keys", concept_keys(markup))
	label.set_meta("inline_icon_font_size", font_size)
	label.set_meta("inline_icon_size", icon_size)
	append_to(label, markup, icon_size)

# Append without clearing the host's font/colour stack (event outcomes use it).
static func append_to(label: RichTextLabel, markup: String, icon_size: float, parse_bbcode: bool = true) -> void:
	label.hint_underlined = false
	var cursor: int = 0
	for token: RegExMatch in _tokens(markup):
		_append_text(label, markup.substr(cursor, token.get_start() - cursor), parse_bbcode)
		var key: String = token.get_string(2)
		var kind: String = token.get_string(1)
		var entry: Dictionary = Glossary.lookup(key)
		if entry.is_empty():
			_append_text(label, token.get_string(), parse_bbcode)
		else:
			var texture: Texture2D = null
			var icon: String = str(entry["icon"]) if entry.get("icon") != null else ""
			if kind != "kw" and not icon.is_empty():
				texture = AssetLoader.load_texture(icon) if icon.begins_with("res://") else ActionIcons.icon_texture(icon)
			if texture != null:
				label.add_image(texture, icon_size, icon_size, Color.WHITE, 5, Rect2(), null, false, ActionIcons.tooltip(key), 0, 0, ActionIcons.label(key))
			if kind != "icon":
				if texture != null: label.add_text(" ")
				label.push_color(KEYWORD_COLOR)
				label.push_hint(ActionIcons.tooltip(key))
				label.add_text(_word(token))
				label.pop()
				label.pop()
			elif texture == null:
				_append_text(label, token.get_string(), parse_bbcode)
		cursor = token.get_end()
	_append_text(label, markup.substr(cursor), parse_bbcode)

static func plain_text(markup: String) -> String:
	var result: String = ""
	var cursor: int = 0
	for token: RegExMatch in _tokens(markup):
		result += markup.substr(cursor, token.get_start() - cursor)
		result += token.get_string() if Glossary.lookup(token.get_string(2)).is_empty() else _word(token)
		cursor = token.get_end()
	return result + markup.substr(cursor)

static func _append_text(label: RichTextLabel, text: String, parse_bbcode: bool = true) -> void:
	if label.bbcode_enabled and parse_bbcode:
		label.append_text(text)
	else:
		label.add_text(text)
