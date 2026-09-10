extends Button

const Assets = preload("res://scripts/asset_loader.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
var room_data: Dictionary = {}
var route_state: String = "ahead"
var reduced_motion: bool = false
var pulse_phase: float = 0.0
var actionable: bool = false
var activation_progress: float = 0.0

func configure(data: Dictionary, _caption: String, state: String, reduce_motion: bool = false) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room_data = data
	route_state = state
	reduced_motion = reduce_motion
	for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(style, StyleBoxEmpty.new())
	focus_mode = Control.FOCUS_ALL
	mouse_entered.connect(queue_redraw)
	mouse_exited.connect(queue_redraw)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)
	refresh_state()

func refresh_state() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actionable else Control.CURSOR_HELP
	set_process(route_state == "reachable" and actionable and not reduced_motion and activation_progress <= 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	pulse_phase = fmod(pulse_phase + delta * TAU / 1.8, TAU)
	queue_redraw()

func visual_radius() -> float:
	if str(room_data.get("type", "")) == "boss": return 88.0
	if route_state == "reachable" and actionable: return 46.0
	if route_state == "current": return 43.0
	if route_state == "visited": return 33.0
	return 29.0

func pulse_scale() -> float:
	return 1.0 if reduced_motion or activation_progress > 0.0 or route_state != "reachable" or not actionable else 1.0 + 0.055 * (0.5 + 0.5 * sin(pulse_phase))

func set_activation_progress(progress: float) -> void:
	activation_progress = progress
	refresh_state()

func activation_scale() -> float:
	return 1.0 if reduced_motion else 1.0 + 0.09 * sin(PI * activation_progress)

func _draw_outline(center: Vector2, radius: float, gap: float, color: Color, width: float) -> void:
	draw_polyline(MapSkin.medallion_contour(center, radius, gap), color, width, true)

func has_recovery() -> bool:
	return bool(room_data.get("recovery_marker", false)) and int(room_data.get("recovery_amount", 0)) > 0

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var known: bool = bool(room_data.get("revealed", false))
	var current: bool = route_state == "current"
	var available: bool = route_state == "reachable" and actionable
	var visited: bool = route_state == "visited"
	var bypassed: bool = route_state == "bypassed"
	var boss: bool = str(room_data.get("type", "")) == "boss"
	var radius: float = visual_radius() * pulse_scale() * activation_scale()
	if available:
		# The solid outer seal carries availability even with motion disabled.
		for ring: int in range(4):
			_draw_outline(center, radius, 5 + ring * 2, Color(1.0, 0.73, 0.33, 0.19 - ring * 0.04), 3.0)
		draw_colored_polygon(MapSkin.medallion_contour(center, radius, 4, false), Color("21190f"))
		_draw_outline(center, radius, 4, Color("ffda8d"), 3.5)
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.from_angle(angle)
			var perpendicular := direction.orthogonal()
			var point: Vector2 = center + MapSkin.medallion_edge(roundi(angle / TAU * MapSkin.MEDALLION_SEGMENTS)) * radius + direction * 9
			draw_colored_polygon(PackedVector2Array([point - direction * 4, point + perpendicular * 4, point + direction * 4, point - perpendicular * 4]), Color("ffdfa0"))
	if known:
		draw_circle(center, radius - 2, Color("0c0b0e"))
		var tint := Color(1.2, 1.08, 0.86) if available else (Color("d5b877") if current else Color("9b8c70"))
		if bypassed: tint = Color("5b5961")
		elif not current and not visited and not boss and not available: tint = Color("7a7880")
		draw_texture_rect(MapSkin._texture("medallion"), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, tint)
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
			var icon_tint := Color.WHITE if available or current else Color("89868c")
			if boss: icon_tint = Color("bbb1a8") if not available else Color.WHITE
			if visited: icon_tint = Color("99948c")
			if bypassed: icon_tint = Color("504e56")
			draw_polygon(points, PackedColorArray([icon_tint]), uvs, icon)
		if activation_progress > 0.0:
			draw_circle(center, radius * 0.74, Color(1.0, 0.88, 0.63, 0.25 * sin(PI * activation_progress)))
		# The opaque center of the full texture sits below the room art. Its rim
		# is a separate mesh above it, so sword tips and packs cannot cover gold.
		draw_mesh(MapSkin.medallion_rim_mesh(), MapSkin._texture("medallion"), Transform2D(Vector2(radius, 0), Vector2(0, radius), center), tint)
	else:
		draw_circle(center, radius - 3, Color(0.035, 0.032, 0.05, 0.75))
		for index: int in range(10):
			var angle: float = TAU * float(index) / 10.0
			draw_arc(center, radius, angle, angle + 0.38, 8, Color("686471") if not bypassed else Color("45424d"), 1.5, true)
		draw_string(get_theme_font("font"), center + Vector2(-6, 7), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("9c94a4") if not bypassed else Color("625c6a"))
	if visited:
		# A broad stamped seal reads at map scale; the emblem stays recognizable.
		_draw_outline(center, radius, 4, Color("090c0c"), 8.0)
		_draw_outline(center, radius, 4, Color("b7c1ad"), 4.0)
		var stamp: Vector2 = center + Vector2(radius * 0.52, radius * 0.58)
		draw_circle(stamp, 16, Color("18211d"))
		draw_arc(stamp, 16, 0, TAU, 48, Color("b7c1ad"), 2, true)
		draw_polyline(PackedVector2Array([stamp + Vector2(-9, 0), stamp + Vector2(-2, 7), stamp + Vector2(11, -8)]), Color("e0e6cf"), 4, true)
	if current:
		# A filled pointer marks the player's position, distinct from completed seals.
		var tip: Vector2 = center + MapSkin.medallion_edge(72) * radius - Vector2(0, 10)
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -27), tip + Vector2(20, -27)]), Color("100f15"))
		draw_colored_polygon(PackedVector2Array([tip - Vector2(0, 4), tip + Vector2(-15, -24), tip + Vector2(15, -24)]), Color("fff0c0"))
		_draw_outline(center, radius, 4, Color("100f15"), 9.0)
		_draw_outline(center, radius, 4, Color("fff0c0"), 5.5)
	if activation_progress > 0.0:
		var spread: float = 4.0 if reduced_motion else 4.0 + activation_progress * 13.0
		_draw_outline(center, radius, spread, Color(1.0, 0.94, 0.76, 1.0 - activation_progress * 0.7), 4.0)
	if has_focus():
		for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner: Vector2 = center + direction * (radius + 10)
			draw_polyline(PackedVector2Array([corner - Vector2(direction.x * 12, 0), corner, corner - Vector2(0, direction.y * 12)]), Color("fff2cd"), 2, true)
	elif is_hovered():
		if known: _draw_outline(center, radius, 9, Color("f8dfaa"), 2.0)
		else: draw_arc(center, radius + 9, 0, TAU, 96, Color("f8dfaa"), 2.0, true)
	if has_recovery():
		var badge_center: Vector2 = center + Vector2(radius * 0.85, -radius * 0.65)
		draw_circle(badge_center, 18, Color("160b05"))
		draw_arc(badge_center, 18, 0, TAU, 48, Color("e1a457"), 2, true)
		var recovery: Texture2D = Assets.load_texture("res://assets/art/tiles/dropped_embers.png")
		if recovery != null:
			draw_texture_rect(recovery, Rect2(badge_center - Vector2(14, 14), Vector2(28, 28)), false)
