extends "res://scripts/ui_socket.gd"

var _glyph := Label.new()

func _init() -> void:
	super._init()
	socket_size = 40.0
	_glyph.name = "CloseGlyph"
	_glyph.text = "✕"
	_glyph.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_glyph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	Typography.set_label_size(_glyph, 18)
	_glyph.add_theme_font_override("font", Typography.ui_font())
	add_child(_glyph)
	_glyph.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for event: Signal in [mouse_entered, mouse_exited, focus_entered, focus_exited]:
		event.connect(_refresh_glyph)
	_refresh_glyph()

func set_glyph_name(node_name: String) -> void:
	_glyph.name = node_name

func _refresh_glyph() -> void:
	_glyph.add_theme_color_override("font_color", Palette.GOLD_BRIGHT if is_hovered() or has_focus(true) else Palette.TEXT_2)
