extends Button

const Assets = preload("res://scripts/asset_loader.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const CONTOUR_OFFSET_CACHE_CAPACITY: int = 12
var room_data: Dictionary = {}
var route_state: String = "ahead"
var reduced_motion: bool = false
var modern_layout: bool = false
var pulse_phase: float = 0.0
var actionable: bool = false
var scout_target: bool = false
var activation_progress: float = 0.0
var _umbra_clock: float = 0.0
# Revision 7 scrolling maps: rooms hit-test as circles (columns sit close), and
# the room you stand in shows the lantern.
var round_hit: bool = false
var lantern_marker: bool = false
var _configured: bool = false

# Separate native display lists keep the still seal and marks while its Umbra
# pool drifts. Internal, input-transparent controls preserve the button surface
# and its public children. Each list retains the original local coordinates,
# texture filtering and paint order (pool/availability, face, then marks).
class SealLayer extends Control:
	var room: Button
	var marks: bool = false
	func _draw() -> void:
		if marks: room._draw_marks(self)
		else: room._draw_face(self)

var _face_layer: SealLayer
var _marks_layer: SealLayer
var _face_inputs: Array = []
var _marks_inputs: Array = []
var _shape_inputs: Array = []
var _contours: Dictionary = {}
var _radius: float = 0.0
var _retained_dirty: bool = true
var _draw_size := Vector2.ZERO
var _draw_origin := Vector2.ZERO
var _draw_lantern: bool = false
var _draw_known: bool = false
var _draw_hovered: bool = false
var _draw_focused: bool = false
var _icon_directions := PackedVector2Array()
var _icon_uvs := PackedVector2Array()
var _contour_basis: String = ""
var _contour_edges := PackedVector2Array()
var _contour_normals := PackedVector2Array()
var _contour_offsets: Dictionary = {}
var _scaled_contour := PackedVector2Array()

func _ensure_layers() -> void:
	if _face_layer != null: return
	_face_layer = SealLayer.new()
	_marks_layer = SealLayer.new()
	for layer: SealLayer in [_face_layer, _marks_layer]:
		layer.room = self
		layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(layer, false, Node.INTERNAL_MODE_BACK)
	_marks_layer.marks = true

func configure(data: Dictionary, _caption: String, state: String, reduce_motion: bool = false) -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	room_data = data
	route_state = state
	reduced_motion = reduce_motion
	# Reconfiguration retains the native button, with the same pulse reset that
	# a newly constructed room node used on each map refresh.
	pulse_phase = 0.0
	if not _configured:
		_configured = true
		for style: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			add_theme_stylebox_override(style, StyleBoxEmpty.new())
		focus_mode = Control.FOCUS_ALL
		mouse_entered.connect(queue_redraw)
		mouse_exited.connect(queue_redraw)
		focus_entered.connect(queue_redraw)
		focus_exited.connect(queue_redraw)
	refresh_state()

func refresh_state() -> void:
	_retained_dirty = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if actionable else Control.CURSOR_HELP
	# Reachable rooms pulse and unknown rooms' Umbra drifts; reduced motion holds both still.
	set_process(((route_state == "reachable" or scout_target) and actionable or not _known()) and not reduced_motion and activation_progress <= 0.0)
	queue_redraw()

func _process(delta: float) -> void:
	if not is_visible_in_tree(): return
	# Hit-stop does not change either drawn clock. Keep live pulses at their
	# existing frame cadence, without resubmitting the same frozen frame.
	if delta == 0.0: return
	if (route_state == "reachable" or scout_target) and actionable:
		pulse_phase = fmod(pulse_phase + delta * TAU / 1.8, TAU)
	elif not get_viewport_rect().intersects(get_global_rect()): return
	_umbra_clock += delta
	queue_redraw()

# Rooms drift out of step with each other; reduced motion keeps each one's still moment.
func _umbra_time() -> float:
	var coord: Vector2i = room_data.get("coord", Vector2i.ZERO)
	return _umbra_clock + float(posmod(coord.x * 92821 + coord.y * 68917, 997)) * 0.037

func _known() -> bool:
	var mystery: bool = str(room_data.get("type", "")) == "mystery"
	# Scouting names a mystery room: from then on it reads like any known room.
	# On a scrolling map the room you stand in always shows the lantern.
	return (bool(room_data.get("revealed", false)) and (not mystery or bool(room_data.get("scouted", false)))) or (route_state == "current" and lantern_marker)

func visual_radius() -> float:
	if str(room_data.get("type", "")) == "boss": return 88.0
	if str(room_data.get("type", "")) == "guardian": return 66.0 if actionable else 43.0
	if (route_state == "reachable" or scout_target) and actionable: return 46.0
	if route_state == "current": return 43.0
	if route_state == "visited": return 33.0
	return 29.0

# The largest radius a room can take in any state, for layout spacing.
static func max_visual_radius(data: Dictionary) -> float:
	if str(data.get("type", "")) == "boss": return 88.0
	if str(data.get("type", "")) == "guardian": return 66.0
	return 46.0

func _has_point(point: Vector2) -> bool:
	if not round_hit: return Rect2(Vector2.ZERO, size).has_point(point)
	return point.distance_to(size * 0.5) <= visual_radius() + 10.0

func pulse_scale() -> float:
	return 1.0 if reduced_motion or activation_progress > 0.0 or (route_state != "reachable" and not scout_target) or not actionable else 1.0 + 0.055 * (0.5 + 0.5 * sin(pulse_phase))

func set_activation_progress(progress: float) -> void:
	activation_progress = progress
	refresh_state()

func activation_scale() -> float:
	return 1.0 if reduced_motion else 1.0 + 0.09 * sin(PI * activation_progress)

# Keep AA strokes native. The old triangle-list candidate changed sparse rim
# pixels despite matching its own expanded-triangle oracle. Native polyline/arc
# calls retain Godot's three triangle strips, feather interpolation and upload
# boundaries; retaining the display lists avoids rebuilding still strokes.
func _draw_outline(canvas: CanvasItem, center: Vector2, radius: float, gap: float, color: Color, width: float) -> void:
	canvas.draw_polyline(_outline_points(center, radius, gap), color, width, true)

func has_recovery() -> bool:
	return bool(room_data.get("recovery_marker", false)) and int(room_data.get("recovery_amount", 0)) > 0

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var lantern: bool = route_state == "current" and lantern_marker
	var known: bool = _known()
	var available: bool = (route_state == "reachable" or scout_target) and actionable
	var bypassed: bool = route_state == "bypassed"
	var radius: float = visual_radius() * pulse_scale() * activation_scale()
	var hovered: bool = is_hovered()
	var focused: bool = has_focus()
	var origin: Vector2 = get_global_transform_with_canvas().origin if not known else Vector2.ZERO
	if _retained_dirty or radius != _radius or size != _draw_size or lantern != _draw_lantern or known != _draw_known or hovered != _draw_hovered or focused != _draw_focused or origin != _draw_origin:
		_sync_layers(center, radius, known, available, lantern)
		_retained_dirty = false
		_radius = radius
		_draw_size = size
		_draw_lantern = lantern
		_draw_known = known
		_draw_hovered = hovered
		_draw_focused = focused
		_draw_origin = origin
	# The Umbra pools beneath an unknown room's seal, under every ring and bracket.
	var umbra: float = 0.5 if bypassed else 1.0
	if not known: MapSkin.draw_unknown_pool(self, center, radius, _umbra_time(), umbra)
	if available:
		# The solid outer seal carries availability even with motion disabled.
		for ring: int in range(4):
			_draw_outline(self, center, radius, _rim_gap(5) + ring * (1.0 if _guardian_emblem() else 2.0), Color(1.0, 0.73, 0.33, 0.19 - ring * 0.04), 3.0)
		draw_colored_polygon(_outline_points(center, radius, _rim_gap(4), false), Color("21190f"))
		_draw_outline(self, center, radius, _rim_gap(4), Color("ffda8d"), 3.5)
		for angle: float in [0.0, PI * 0.5, PI, PI * 1.5]:
			var direction := Vector2.from_angle(angle)
			var perpendicular := direction.orthogonal()
			var point: Vector2 = center + _rim_edge(roundi(angle / TAU * MapSkin.MEDALLION_SEGMENTS)) * radius + direction * 9
			draw_colored_polygon(PackedVector2Array([point - direction * 4, point + perpendicular * 4, point + direction * 4, point - perpendicular * 4]), Color("ffdfa0"))

func _sync_layers(center: Vector2, radius: float, known: bool, available: bool, lantern: bool) -> void:
	_ensure_layers()
	var icon_id: String = preload("res://scripts/room_icon_library.gd").icon_id_for_room(room_data)
	var guardian: bool = _guardian_emblem()
	var basis: String = icon_id if guardian else "medallion"
	if basis != _contour_basis:
		_contour_basis = basis
		_contour_edges.clear()
		_contour_normals.clear()
		_contour_offsets.clear()
		for index: int in range(MapSkin.MEDALLION_SEGMENTS): _contour_edges.append(_rim_edge(index))
		for index: int in range(MapSkin.MEDALLION_SEGMENTS):
			var tangent: Vector2 = _contour_edges[(index + 1) % MapSkin.MEDALLION_SEGMENTS] - _contour_edges[posmod(index - 1, MapSkin.MEDALLION_SEGMENTS)]
			_contour_normals.append(Vector2(tangent.y, -tangent.x).normalized())
	var shape: Array = [center, radius, guardian, icon_id]
	if shape != _shape_inputs:
		_shape_inputs = shape
		_contours.clear()
		# Native packed-array transform performs the same float32 edge*radius
		# then centre addition as medallion_contour, without 96 script calls.
		_scaled_contour = Transform2D(Vector2(radius,0),Vector2(0,radius),center) * _contour_edges
	var face: Array = [shape, route_state, known, available, lantern, modern_layout, str(room_data.get("type", "")), medallion_icon_tint(), activation_progress]
	# The unknown glyph snaps its pen in global pixels. Scrolling must retain
	# the original rounding, even though the rest of the seal stays local.
	if not known: face.append(get_global_transform_with_canvas().origin)
	if face != _face_inputs:
		_face_inputs = face
		_face_layer.queue_redraw()
	var marks: Array = [shape, route_state, activation_progress, reduced_motion, has_focus(), is_hovered(), has_recovery()]
	if marks != _marks_inputs:
		_marks_inputs = marks
		_marks_layer.queue_redraw()

func _draw_face(canvas: CanvasItem) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = _radius
	var lantern: bool = route_state == "current" and lantern_marker
	var known: bool = _known()
	var current: bool = route_state == "current"
	var available: bool = (route_state == "reachable" or scout_target) and actionable
	var visited: bool = route_state == "visited"
	var bypassed: bool = route_state == "bypassed"
	var boss: bool = str(room_data.get("type", "")) == "boss"
	var umbra: float = 0.5 if bypassed else 1.0
	var tint := Color(1.2, 1.08, 0.86) if available else (Color("d5b877") if current else Color("9b8c70"))
	if bypassed: tint = Color("5b5961")
	elif not current and not visited and not boss and not available: tint = Color("7a7880")
	if known:
		canvas.draw_colored_polygon(_outline_points(center, radius, -1, false), Color("0c0b0e")) if _guardian_emblem() else canvas.draw_circle(center, radius - 2, Color("0c0b0e"))
		var icon_id: String = preload("res://scripts/room_icon_library.gd").icon_id_for_room(room_data)
		if lantern: icon_id = "start"
		var icon_tint: Color = medallion_icon_tint()
		if str(room_data.get("type", "")) == "guardian" and not lantern:
			canvas.draw_texture_rect(MapSkin.icon_texture(icon_id), Rect2(center-Vector2.ONE*radius,Vector2.ONE*radius*2.0), false, icon_tint)
		else:
			_draw_medallion(canvas, center, radius, MapSkin.icon_texture(icon_id), icon_tint, tint, 0.25 * sin(PI * activation_progress))
	else:
		MapSkin.draw_unknown_room(canvas, center, radius, (Palette.GOLD_BRIGHT if available else Palette.GOLD) * medallion_icon_tint(), tint, _umbra_time(), umbra, false)

func _draw_medallion(canvas: CanvasItem, center: Vector2, radius: float, icon: Texture2D, icon_tint: Color, frame_tint: Color, glint_alpha: float) -> void:
	canvas.draw_texture_rect(MapSkin._texture("medallion"), Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2), false, frame_tint)
	if icon != null:
		if _icon_directions.is_empty():
			for index: int in range(64):
				var direction := Vector2.from_angle(TAU * float(index) / 64.0)
				_icon_directions.append(direction)
				_icon_uvs.append(Vector2.ONE * 0.5 + direction * 0.5)
		var points: PackedVector2Array = Transform2D(Vector2(radius,0),Vector2(0,radius),Vector2.ZERO) * _icon_directions
		points = Transform2D(Vector2(0.735,0),Vector2(0,0.735),center) * points
		canvas.draw_polygon(points, PackedColorArray([icon_tint]), _icon_uvs, icon)
	if glint_alpha > 0.0:
		canvas.draw_circle(center, radius * 0.74, Color(1.0, 0.88, 0.63, glint_alpha))
	canvas.draw_mesh(MapSkin.medallion_rim_mesh(), MapSkin._texture("medallion"), Transform2D(Vector2(radius, 0), Vector2(0, radius), center), frame_tint)

func _draw_marks(canvas: CanvasItem) -> void:
	var center: Vector2 = size * 0.5
	var radius: float = _radius
	var visited: bool = route_state == "visited"
	var current: bool = route_state == "current"
	if visited:
		# A broad stamped seal reads at map scale; the emblem stays recognizable.
		_draw_outline(canvas, center, radius, _rim_gap(4), Color("090c0c"), 8.0)
		_draw_outline(canvas, center, radius, _rim_gap(4), Color("b7c1ad"), 4.0)
		var stamp: Vector2 = center + Vector2(radius * 0.52, radius * 0.58)
		var stamp_color := Color("18211d")
		canvas.draw_circle(stamp, 16, stamp_color)
		var stamp_rim := Color("b7c1ad")
		canvas.draw_arc(stamp, 16, 0, TAU, 48, stamp_rim, 2, true)
		canvas.draw_polyline(PackedVector2Array([stamp + Vector2(-9, 0), stamp + Vector2(-2, 7), stamp + Vector2(11, -8)]), Color("e0e6cf"), 4, true)
	if current:
		# A filled pointer marks the player's position, distinct from completed seals.
		var tip: Vector2 = center + _rim_edge(72) * radius - Vector2(0, 10)
		var pointer_ink := Color("100f15")
		canvas.draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-20, -27), tip + Vector2(20, -27)]), pointer_ink)
		canvas.draw_colored_polygon(PackedVector2Array([tip - Vector2(0, 4), tip + Vector2(-15, -24), tip + Vector2(15, -24)]), Color("fff0c0"))
		_draw_outline(canvas, center, radius, _rim_gap(4), pointer_ink, 9.0)
		_draw_outline(canvas, center, radius, _rim_gap(4), Color("fff0c0"), 5.5)
	if activation_progress > 0.0:
		var spread: float = 4.0 if reduced_motion else 4.0 + activation_progress * 13.0
		_draw_outline(canvas, center, radius, spread, Color(1.0, 0.94, 0.76, 1.0 - activation_progress * 0.7), 4.0)
	if has_focus():
		for direction: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
			var corner: Vector2 = center + direction * (radius + 10)
			canvas.draw_polyline(PackedVector2Array([corner - Vector2(direction.x * 12, 0), corner, corner - Vector2(0, direction.y * 12)]), Color("fff2cd"), 2, true)
	elif is_hovered():
		_draw_outline(canvas, center, radius, _rim_gap(9), Color("f8dfaa"), 2.0)
	if has_recovery():
		var badge_center: Vector2 = center + Vector2(radius * 0.85, -radius * 0.65)
		var badge_color := Color("160b05")
		canvas.draw_circle(badge_center, 18, badge_color)
		var badge_rim := Color("e1a457")
		canvas.draw_arc(badge_center, 18, 0, TAU, 48, badge_rim, 2, true)
		var recovery: Texture2D = Assets.load_original_texture("res://assets/art/tiles/dropped_embers.png")
		if recovery != null:
			canvas.draw_texture_rect(recovery, Rect2(badge_center - Vector2(14, 14), Vector2(28, 28)), false)

func medallion_icon_tint() -> Color:
	var available: bool = (route_state == "reachable" or scout_target) and actionable
	if modern_layout and route_state == "ahead" and not available and bool(room_data.get("revealed", false)):
		return Color(1.0, 1.0, 1.0, 0.85)
	# Rooms you can no longer reach fade alike, unknown ones included.
	if route_state == "bypassed": return Color("504e56")
	var tint := Color.WHITE if available or route_state == "current" else Color("89868c")
	if str(room_data.get("type", "")) == "mystery": return tint
	if str(room_data.get("type", "")) == "boss": tint = Color.WHITE if available else Color("bbb1a8")
	if route_state == "visited": tint = Color("99948c")
	return tint

func _guardian_emblem() -> bool:
	return str(room_data.get("type",""))=="guardian" and bool(room_data.get("revealed",false)) and not (route_state == "current" and lantern_marker)

func _rim_gap(ordinary: float) -> float:
	return 2.0 if _guardian_emblem() else ordinary

func _rim_edge(index: int) -> Vector2:
	return MapSkin.icon_edge(preload("res://scripts/room_icon_library.gd").icon_id_for_room(room_data),index) if _guardian_emblem() else MapSkin.medallion_edge(index)

func _outline_points(_center: Vector2, _radius_value: float, gap: float, closed: bool = true) -> PackedVector2Array:
	var key: Array = [gap, closed]
	if not _contours.has(key):
		if not _contour_offsets.has(gap):
			# Activation's expanding ring has an unbounded number of distinct
			# gaps; keep only a small current-shape working set.
			if _contour_offsets.size() >= CONTOUR_OFFSET_CACHE_CAPACITY: _contour_offsets.clear()
			var offsets := PackedVector2Array()
			for normal: Vector2 in _contour_normals: offsets.append(normal * gap)
			_contour_offsets[gap] = offsets
		var offsets: PackedVector2Array = _contour_offsets[gap]
		var points := PackedVector2Array()
		for index: int in range(MapSkin.MEDALLION_SEGMENTS): points.append(_scaled_contour[index] + offsets[index])
		if closed: points.append(points[0])
		_contours[key] = points
	return _contours[key]
