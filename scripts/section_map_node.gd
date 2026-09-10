extends Button

const Assets = preload("res://scripts/asset_loader.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
var room_data: Dictionary = {}
var route_state: String = "unavailable"
var selected: bool = false
var label: Label

func configure(data: Dictionary, caption: String, state: String) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room_data = data
	route_state = state
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	if label == null:
		label = Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		Typography.apply_label_role(label, Typography.ROLE_BODY_LARGE)
		label.add_theme_color_override("font_color", Color("e3d6b7"))
		label.add_theme_color_override("font_outline_color", Color("08060d"))
		label.add_theme_constant_override("outline_size", 5)
		add_child(label)
	label.text = caption
	label.position = Vector2(-22, 111 if str(data.get("type", "")) == "boss" else 92)
	label.size = Vector2(144, 72)
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	queue_redraw()

func _draw() -> void:
	var center := Vector2(50, 48)
	var known: bool = bool(room_data.get("revealed", false))
	var current: bool = route_state == "current"
	var visited: bool = bool(room_data.get("visited", false))
	var boss: bool = str(room_data.get("type", "")) == "boss"
	if selected or has_focus():
		draw_circle(center, 47, Color(0.03, 0.02, 0.04, 0.95))
		draw_arc(center, 47, 0, TAU, 64, Color("f6d897"), 3, true)
	draw_circle(center, 41, Color(0.025, 0.019, 0.026, 0.98))
	var frame: Texture2D = MapSkin._texture("medallion")
	if frame != null:
		var tint := Color(1.18, 1.03, 0.76) if current or selected or has_focus() else (Color(0.92, 0.86, 0.72) if route_state == "reachable" else Color(0.55, 0.55, 0.54))
		draw_texture_rect(frame, Rect2(center - Vector2(58, 58) if boss else center - Vector2(45, 45), Vector2(116, 116) if boss else Vector2(90, 90)), false, tint)
	if known:
		var icon_id: String = "start" if current else ("boss_" + str(room_data.get("boss_id", "tharokh")) if str(room_data.get("type", "")) == "boss" else str(room_data.get("type", "combat")))
		var icon: Texture2D = MapSkin.icon_texture(icon_id)
		if icon != null:
			# Opaque painted emblems sit on the medallion's matching charcoal inset.
			draw_circle(center, 43 if boss else 33, Color("08080c"))
			# Fit the artwork to the round inset while keeping each source asset intact.
			var radius: float = 43.0 if boss else 33.0
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for index: int in range(64):
				var direction := Vector2.from_angle(TAU * float(index) / 64.0)
				points.append(center + direction * radius)
				uvs.append(Vector2(0.5, 0.5) + direction * 0.5)
			draw_polygon(points, PackedColorArray([Color.WHITE if not visited or current else Color(0.7, 0.68, 0.65)]), uvs, icon)
	if visited and not current:
		draw_polyline(PackedVector2Array([Vector2(39, 1), Vector2(46, 8), Vector2(60, -7)]), Color("f2d594"), 3, true)
	if bool(room_data.get("map_landmark", false)) and not visited:
		draw_circle(Vector2(85, 13), 6, Color("f2d594"))
