extends RefCounted

# Presentation consumes the ev-01 strings verbatim; only tone and inline-icon
# markup are added here. The rules remain the source of every outcome value.
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Inline = preload("res://scripts/inline_icon_text.gd")

static func tone(text: String) -> Color:
	if text.begins_with("Bane:"): return Palette.EVENT_BANE
	if text.begins_with("Blessing:"): return Palette.EVENT_BLESSING
	if text.begins_with("Lose") or text.begins_with("Lost") or text.begins_with("Pay") or text.begins_with("Paid") or text.begins_with("−"): return Palette.EVENT_COST
	if text.begins_with("Gain") or text.begins_with("Heal") or text.begins_with("Choose") or text.begins_with("Next:") or text.begins_with("+"): return Palette.EVENT_GAIN
	return Palette.TEXT_2

static func markup(text: String, toned: bool = false) -> String:
	var output: String = text.replace("[", "[lb]")
	if not toned: return output
	# Random lines keep the percentage prefix neutral and colour each concrete
	# nested effect independently, without changing EventRules' words or order.
	var markers := RegEx.new()
	markers.compile("(?:(?:^|(?<=: )|(?<=\\. ))(?:Bane:|Blessing:|Lose |Lost |Pay |Paid |Gain |Gained |Heal |Healed |Choose |Next:|Nothing|Transform |Reforge |Reveal |Revealed |[+−][0-9]))")
	var matches: Array[RegExMatch] = markers.search_all(output)
	if matches.is_empty(): return "[color=#%s]%s[/color]" % [tone(text).to_html(false), output]
	var result: String = ""
	var cursor: int = 0
	for index: int in range(matches.size()):
		var start: int = matches[index].get_start()
		var end: int = matches[index + 1].get_start() if index + 1 < matches.size() else output.length()
		if start > cursor: result += "[color=#%s]%s[/color]" % [Palette.TEXT_2.to_html(false), output.substr(cursor, start - cursor)]
		var part: String = output.substr(start, end - start)
		result += "[color=#%s]%s[/color]" % [tone(part).to_html(false), part]
		cursor = end
	return result

static func label(text: String, width: float, font_size: int, color: Color = Palette.TEXT, italic: bool = false, toned: bool = false, line_height: float = 1.35) -> RichTextLabel:
	var label := RichTextLabel.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.bbcode_enabled = true
	label.scroll_active = false
	label.fit_content = true
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_override("normal_font", Typography.text_font())
	var italics := FontVariation.new()
	italics.base_font = Typography.text_font()
	italics.variation_transform = Transform2D(Vector2(1, 0), Vector2(0.2, 1), Vector2.ZERO)
	label.add_theme_font_override("italics_font", italics)
	label.add_theme_font_size_override("normal_font_size", font_size)
	label.add_theme_font_size_override("italics_font_size", font_size)
	label.add_theme_color_override("default_color", color)
	var native_height: float = Typography.text_font().get_height(font_size)
	label.add_theme_constant_override("line_separation", maxi(0, int(round(font_size * line_height - native_height))))
	label.custom_minimum_size.x = width
	label.size.x = width
	if italic: label.push_font(italics, font_size)
	if toned:
		var colors := RegEx.new()
		colors.compile("\\[color=(#[0-9a-f]+)\\](.*?)\\[/color\\]")
		for part: RegExMatch in colors.search_all(markup(text, true)):
			label.push_color(Color(part.get_string(1)))
			_append_icons(label, part.get_string(2))
			label.pop()
	else:
		_append_icons(label, text)
	if italic: label.pop()
	label.set_meta("event_source_text", text)
	return label

static func height(label: RichTextLabel) -> float:
	var result: float = maxf(label.get_content_height(), label.get_theme_font("normal_font").get_height(label.get_theme_font_size("normal_font_size")))
	label.size.y = ceilf(result)
	return label.size.y

static func _append_icons(label: RichTextLabel, text: String) -> void:
	var cursor: int = 0
	while cursor < text.length():
		var start: int = text.find("@icon(", cursor)
		if start < 0:
			label.add_text(text.substr(cursor))
			break
		label.add_text(text.substr(cursor, start - cursor))
		var end: int = text.find(")", start)
		if end < 0:
			label.add_text(text.substr(start))
			break
		var key: String = text.substr(start + 6, end - start - 6)
		var texture: Texture2D = Icons.icon_texture(key)
		if texture != null: label.add_image(texture, 20, 20, Color.WHITE, 5)
		else: label.add_text(text.substr(start, end - start + 1))
		cursor = end + 1
