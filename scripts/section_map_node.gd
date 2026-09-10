extends Button

const Assets = preload("res://scripts/asset_loader.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const Typography = preload("res://scripts/ui_typography.gd")
var room_data: Dictionary = {}
var route_state: String = "ahead"
var selected: bool = false
var door_label: String = "AVAILABLE"
var label: Label
var status_label: Label
var recovery_label: Label

func configure(data: Dictionary, caption: String, state: String) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room_data = data
	route_state = state
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	focus_mode = Control.FOCUS_ALL
	label = _label(Typography.ROLE_BODY_LARGE)
	label.text = caption
	label.position = Vector2(-26, 108 if str(data.get("type", "")) == "boss" else 96)
	label.size = Vector2(152, 64)
	status_label = _label(Typography.ROLE_CAPTION)
	status_label.position = Vector2(-22, -34)
	status_label.size = Vector2(144, 26)
	status_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	recovery_label = _label(Typography.ROLE_BODY)
	recovery_label.name = "RecoveryAmount"
	recovery_label.visible = bool(data.get("recovery_marker", false)) and int(data.get("recovery_amount", 0)) > 0
	recovery_label.text = str(data.get("recovery_amount", 0))
	recovery_label.position = Vector2(69, 21)
	recovery_label.size = Vector2(38, 24)
	recovery_label.add_theme_color_override("font_color", Color("ffd28f"))
	refresh_state()

func _label(role: String) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	Typography.apply_label_role(result, role)
	result.add_theme_color_override("font_outline_color", Color("09080d"))
	result.add_theme_constant_override("outline_size", 4)
	add_child(result)
	return result

func refresh_state() -> void:
	var text: String = ""
	match route_state:
		"current": text = "YOU ARE HERE"
		"reachable": text = "SELECTED" if selected else door_label
		"visited": text = "VISITED"
		"bypassed": text = "NOT TAKEN"
		_: text = "INSPECTING" if selected else ("LANDMARK" if bool(room_data.get("map_landmark", false)) else "")
	status_label.text = text
	var muted: bool = route_state in ["visited", "bypassed"]
	label.add_theme_color_override("font_color", Color("aaa69d") if muted else Color("f1e3c4"))
	status_label.add_theme_color_override("font_color", Color("292016") if route_state == "current" or (selected and route_state == "reachable") else (Color("9e9c99") if muted else Color("dfc389")))
	status_label.add_theme_constant_override("outline_size", 0 if route_state == "current" or (selected and route_state == "reachable") else 3)
	queue_redraw()

func _draw() -> void:
	var center := Vector2(50, 48)
	var known: bool = bool(room_data.get("revealed", false))
	var current: bool = route_state == "current"
	var available: bool = route_state == "reachable"
	var muted: bool = route_state in ["visited", "bypassed"]
	var boss: bool = str(room_data.get("type", "")) == "boss"
	var radius: float = 57.0 if boss else (45.0 if current or available else 39.0)
	var frame: Texture2D = MapSkin._texture("medallion")
	if current or (selected and available):
		# A solid nameplate and pointer identify position/selection without color.
		var plaque := Rect2(Vector2(-16, -33), Vector2(132, 24))
		draw_style_box(_plaque_style(), plaque)
		draw_colored_polygon(PackedVector2Array([Vector2(45, -9), Vector2(55, -9), Vector2(50, -4)]), Color("dfc389"))
	if current or available:
		draw_circle(center, radius + 3, Color("17141a"))
		if selected or current:
			draw_arc(center, radius + 3, 0, TAU, 96, Color("e6c783"), 2.0, true)
	if known:
		draw_circle(center, radius - 3, Color("08080c"))
		var tint := Color(1.15, 1.03, 0.82) if current or available else (Color(0.46, 0.47, 0.49) if muted else Color(0.72, 0.69, 0.63))
		draw_texture_rect(frame, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, tint)
		var icon_id: String = "boss_" + str(room_data.get("boss_id", "tharokh")) if boss else str(room_data.get("type", "combat"))
		var icon: Texture2D = MapSkin.icon_texture(icon_id)
		if icon != null:
			var inset_radius: float = radius * 0.735
			var points := PackedVector2Array()
			var uvs := PackedVector2Array()
			for index: int in range(64):
				var direction := Vector2.from_angle(TAU * float(index) / 64.0)
				points.append(center + direction * inset_radius)
				uvs.append(Vector2(0.5, 0.5) + direction * 0.5)
			draw_polygon(points, PackedColorArray([Color(0.45, 0.47, 0.49) if muted else Color.WHITE]), uvs, icon)
	else:
		# An incomplete ring is knowledge, never an empty actionable medallion.
		draw_circle(center, 30, Color(0.035, 0.032, 0.05, 0.75))
		for index: int in range(12):
			var angle: float = TAU * float(index) / 12.0
			draw_arc(center, 31, angle, angle + 0.30, 8, Color("89838b") if not muted else Color("56535e"), 1.5, true)
		draw_string(get_theme_font("font"), center + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("c1b9c6") if not muted else Color("77727c"))
	if route_state == "visited":
		var stamp := Vector2(78, 76)
		draw_circle(stamp, 10, Color("252829"))
		draw_polyline(PackedVector2Array([stamp + Vector2(-5, 0), stamp + Vector2(-1, 4), stamp + Vector2(6, -4)]), Color("b8c5bd"), 2, true)
	if route_state == "bypassed":
		var stamp := Vector2(78, 76)
		draw_circle(stamp, 10, Color("25232b"))
		draw_line(stamp + Vector2(-5, 0), stamp + Vector2(5, 0), Color("9a949f"), 2, true)
	if has_focus():
		# Corner brackets distinguish navigation focus from a persistent selection.
		for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner: Vector2 = center + direction * (radius + 7)
			draw_polyline(PackedVector2Array([corner - Vector2(direction.x * 12, 0), corner, corner - Vector2(0, direction.y * 12)]), Color("ffebbd"), 2, true)
	elif is_hovered() or (selected and not available):
		draw_arc(center, radius + 5, 0, TAU, 96, Color("c5b18b"), 1.5, true)
	if recovery_label.visible:
		var badge_center := Vector2(86, 8)
		draw_circle(badge_center, 18, Color("160b05"))
		draw_arc(badge_center, 18, 0, TAU, 48, Color("e1a457"), 2, true)
		var recovery: Texture2D = Assets.load_texture("res://assets/art/tiles/dropped_embers.png")
		if recovery != null:
			draw_texture_rect(recovery, Rect2(badge_center - Vector2(14, 14), Vector2(28, 28)), false)

func _plaque_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("dfc389")
	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	return style
