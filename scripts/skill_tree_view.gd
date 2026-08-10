extends HBoxContainer
class_name SkillTreeView

const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const InlineIconText = preload("res://scripts/inline_icon_text.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

signal skill_focused(skill_id: String)
signal learn_requested(skill_id: String)

const MODE_VIEW: String = "view"

const STATE_OWNED: String = "owned"
const STATE_AVAILABLE: String = "available"
const STATE_LOCKED: String = "locked"
const STATE_EXCLUDED: String = "excluded"
const STATE_SELECTED: String = "selected"

const GRAPH_SIZE: Vector2 = Vector2(SkillTreeLibrary.LAYOUT_CANVAS_SIZE)
const DETAIL_WIDTH: float = 280.0
const COMPACT_DETAIL_WIDTH: float = 350.0
const COMPACT_LAYOUT_WIDTH: float = 1300.0
const LINK_NODE_CLEARANCE: float = 8.0
const LINK_ENDPOINT_EXPOSURE: float = 10.0
const LINK_CHANNEL_SPACING: float = 10.0
const LINK_BRIDGE_HALF_GAP: float = 10.0
const LINK_TARGET_STUB_OFFSETS: Dictionary = {
	"quick_wits>curators_patience": -12.0,
}
const LINK_SOURCE_STUB_OFFSETS: Dictionary = {
	# Leave the root row before the enlarged Salvager face begins.
	"discerning_eye>true_bearing": -12.0,
}
const LINK_CHANNEL_NUDGES: Dictionary = {
	# The larger medallions move both routes onto x=440 unless this long link
	# claims the adjacent clear channel. Keeping separate rails preserves topology.
	"quick_wits>curators_patience": 4.0,
}

const BRANCH_COLORS: Dictionary = {
	"tactics": Color("d7a85d"),
	"resolve": Color("d17a72"),
	"traverse": Color("79b9a5"),
	"foresight": Color("b994d0"),
	"radiance": Color("e7c85f"),
	"keystone": Color("e5cf9b"),
}

class SkillLinkLayer:
	extends Control

	var links: Array[Dictionary]

	func set_links(value: Array[Dictionary]) -> void:
		links.clear()
		for link: Dictionary in value:
			links.append(link.duplicate(false))
		links.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority: int = int(left.get("draw_priority", 0))
			var right_priority: int = int(right.get("draw_priority", 0))
			if left_priority != right_priority:
				return left_priority < right_priority
			return str(left.get("sort_key", "")) < str(right.get("sort_key", ""))
		)
		queue_redraw()

	func _draw() -> void:
		for link: Dictionary in links:
			var points: PackedVector2Array = link.get("points", PackedVector2Array())
			if points.size() < 2:
				continue
			var color: Color = link.get("color", Color("4a434d"))
			var width: float = float(link.get("width", 3.0))
			var under_color := Color(0.025, 0.02, 0.027, 0.95)
			var bridge_gaps: Array = link.get("bridge_gaps", []) as Array
			if bool(link.get("highlighted", false)):
				var glow := color
				glow.a = 0.20
				_draw_routed_line(points, bridge_gaps, glow, width + 8.0)
			_draw_routed_line(points, bridge_gaps, under_color, width + 3.0)
			_draw_routed_line(points, bridge_gaps, color, width)

	func _draw_routed_line(
		points: PackedVector2Array,
		bridge_gaps: Array,
		color: Color,
		width: float
	) -> void:
		for segment_index: int in range(points.size() - 1):
			var start: Vector2 = points[segment_index]
			var finish: Vector2 = points[segment_index + 1]
			var segment: Vector2 = finish - start
			var segment_length: float = segment.length()
			if segment_length <= 0.01:
				continue
			var direction: Vector2 = segment / segment_length
			var segment_gaps: Array[Dictionary]
			for gap_value: Variant in bridge_gaps:
				if typeof(gap_value) != TYPE_DICTIONARY:
					continue
				var gap: Dictionary = gap_value as Dictionary
				if int(gap.get("segment_index", -1)) == segment_index:
					segment_gaps.append(gap)
			segment_gaps.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
				return float(left.get("distance", 0.0)) < float(right.get("distance", 0.0))
			)
			var cursor_distance: float = 0.0
			for gap: Dictionary in segment_gaps:
				var gap_distance: float = clampf(float(gap.get("distance", 0.0)), 0.0, segment_length)
				var half_gap: float = maxf(0.0, float(gap.get("half_gap", 0.0)))
				var gap_start: float = maxf(cursor_distance, gap_distance - half_gap)
				if gap_start > cursor_distance + 0.01:
					draw_line(
						start + direction * cursor_distance,
						start + direction * gap_start,
						color,
						width,
						true
					)
				cursor_distance = maxf(cursor_distance, minf(segment_length, gap_distance + half_gap))
			if cursor_distance < segment_length - 0.01:
				draw_line(start + direction * cursor_distance, finish, color, width, true)

class SkillLinkOverlayLayer:
	extends Control

	const ARROW_LENGTH: float = 10.0
	const ARROW_HALF_WIDTH: float = 5.0

	var links: Array[Dictionary]

	func set_links(value: Array[Dictionary]) -> void:
		links.clear()
		for link: Dictionary in value:
			links.append(link.duplicate(false))
		links.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
			var left_priority: int = int(left.get("draw_priority", 0))
			var right_priority: int = int(right.get("draw_priority", 0))
			if left_priority != right_priority:
				return left_priority < right_priority
			return str(left.get("sort_key", "")) < str(right.get("sort_key", ""))
		)
		queue_redraw()

	func _draw() -> void:
		for link: Dictionary in links:
			var points: PackedVector2Array = link.get("points", PackedVector2Array())
			if points.size() < 2:
				continue
			var color: Color = link.get("color", Color("4a434d"))
			var width: float = float(link.get("width", 3.0))
			var under_color := Color(0.025, 0.02, 0.027, 0.98)
			var target_start: int = maxi(0, points.size() - 2)
			var source_direction: Vector2 = points[1] - points[0]
			var source_overlay_end: Vector2 = points[0]
			if source_direction.length_squared() > 0.01:
				source_overlay_end += source_direction.normalized() * minf(6.0, source_direction.length())
			var target: Vector2 = points[points.size() - 1]
			var incoming: Vector2 = target - points[target_start]
			if incoming.length_squared() <= 0.01:
				continue
			var direction: Vector2 = incoming.normalized()
			var target_overlay_start: Vector2 = target - direction * minf(ARROW_LENGTH + 2.0, incoming.length())
			if bool(link.get("highlighted", false)):
				var glow := color
				glow.a = 0.22
				draw_line(points[0], source_overlay_end, glow, width + 8.0, true)
				draw_line(target_overlay_start, target, glow, width + 8.0, true)
			draw_line(points[0], source_overlay_end, under_color, width + 3.0, true)
			draw_line(points[0], source_overlay_end, color, width, true)
			draw_line(target_overlay_start, target, under_color, width + 3.0, true)
			draw_line(target_overlay_start, target, color, width, true)
			draw_circle(points[0], width * 0.9 + 1.0, under_color, true, -1.0, true)
			draw_circle(points[0], width * 0.65, color, true, -1.0, true)
			var normal := Vector2(-direction.y, direction.x)
			var under_arrow := PackedVector2Array([
				target + direction * 1.0,
				target - direction * (ARROW_LENGTH + 2.0) + normal * (ARROW_HALF_WIDTH + 2.0),
				target - direction * (ARROW_LENGTH + 2.0) - normal * (ARROW_HALF_WIDTH + 2.0),
			])
			var arrow := PackedVector2Array([
				target,
				target - direction * ARROW_LENGTH + normal * ARROW_HALF_WIDTH,
				target - direction * ARROW_LENGTH - normal * ARROW_HALF_WIDTH,
			])
			draw_colored_polygon(under_arrow, under_color)
			draw_colored_polygon(arrow, color)

class SkillLegendMarker:
	extends Control

	var state: String = "locked"
	var marker_color: Color = Color("68636d")

	func configure(next_state: String, next_color: Color) -> void:
		state = next_state
		marker_color = next_color
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(center, radius, Color(0.025, 0.02, 0.03, 0.98), true, -1.0, true)
		draw_arc(center, radius - 0.5, 0.0, TAU, 24, marker_color, 2.0, true)
		match state:
			"owned":
				draw_polyline(PackedVector2Array([
					center + Vector2(-4.0, 0.0),
					center + Vector2(-1.0, 3.0),
					center + Vector2(4.5, -3.5),
				]), marker_color, 2.2, true)
			"available":
				draw_line(center + Vector2(-4.0, 0.0), center + Vector2(4.0, 0.0), marker_color, 2.0, true)
				draw_line(center + Vector2(0.0, -4.0), center + Vector2(0.0, 4.0), marker_color, 2.0, true)
			"pending":
				draw_circle(center, 3.5, marker_color, true, -1.0, true)
			"excluded":
				draw_line(center + Vector2(-4.0, 4.0), center + Vector2(4.0, -4.0), marker_color, 2.2, true)
			_:
				draw_rect(Rect2(center + Vector2(-3.5, -0.5), Vector2(7.0, 5.0)), marker_color, false, 1.7, true)
				draw_arc(center + Vector2(0.0, -0.5), 3.5, PI, TAU, 14, marker_color, 1.7, true)

class SkillNodeFace:
	extends Control

	var tier: String = "branch"
	var state: String = "locked"
	var relationship: String = "none"
	var selected: bool = false
	var branch_color: Color = Color("b99a6b")
	var icon_texture: Texture2D

	func configure(
		next_tier: String,
		next_state: String,
		next_relationship: String,
		next_selected: bool,
		next_branch_color: Color,
		next_icon: Texture2D
	) -> void:
		if (
			tier == next_tier
			and state == next_state
			and relationship == next_relationship
			and selected == next_selected
			and branch_color == next_branch_color
			and icon_texture == next_icon
		):
			return
		tier = next_tier
		state = next_state
		relationship = next_relationship
		selected = next_selected
		branch_color = next_branch_color
		icon_texture = next_icon
		queue_redraw()

	func _draw() -> void:
		var center := size * 0.5
		var radius: float = minf(size.x, size.y) * 0.5 - 4.0
		var state_color: Color = _face_state_color(state)
		var fill: Color = _face_fill_color(state)
		var outline_width: float = 3.0 if state != "locked" else 2.0
		if selected or relationship != "none":
			var halo_color := Color("fff4d8")
			if relationship == "prerequisite":
				halo_color = Color("ffd47a")
			elif relationship == "dependent":
				halo_color = Color("8ce1d5")
			draw_arc(center, radius + 4.5, 0.0, TAU, 40, Color(0.02, 0.015, 0.02, 0.94), 6.0, true)
			draw_arc(center, radius + 4.5, 0.0, TAU, 40, halo_color, 2.5, true)
		_draw_node_shadow(center, radius)
		match tier:
			"root":
				draw_circle(center, radius, fill, true, -1.0, true)
				draw_arc(center, radius, 0.0, TAU, 40, state_color, outline_width, true)
			"junction":
				var diamond := _diamond_points(center, radius)
				draw_colored_polygon(diamond, fill)
				draw_polyline(_closed_points(diamond), state_color, outline_width, true)
			"keystone":
				var hexagon := _hexagon_points(center, radius)
				draw_colored_polygon(hexagon, fill)
				draw_polyline(_closed_points(hexagon), state_color, outline_width + 1.0, true)
				draw_polyline(_closed_points(_hexagon_points(center, radius - 5.5)), branch_color.darkened(0.08), 1.5, true)
			_:
				var style := StyleBoxFlat.new()
				style.bg_color = fill
				style.border_color = state_color
				style.set_border_width_all(int(outline_width))
				style.set_corner_radius_all(10)
				draw_style_box(style, Rect2(center - Vector2(radius, radius), Vector2(radius * 2.0, radius * 2.0)))
		# The icon is the medallion's identity, not a small badge inside it. Keep a
		# narrow state-marker gutter, then let the purpose-built silhouette occupy
		# most of the remaining face so it survives fit-to-view scaling.
		var icon_size: float = radius * (1.70 if tier != "keystone" else 1.74)
		if icon_texture != null:
			var icon_tint := Color.WHITE if state != "locked" else Color("77737b")
			draw_texture_rect(icon_texture, Rect2(center - Vector2.ONE * icon_size * 0.5, Vector2.ONE * icon_size), false, icon_tint)
		draw_circle(center + Vector2(-radius * 0.62, radius * 0.70), 3.5, Color(0.02, 0.015, 0.02, 0.98), true, -1.0, true)
		draw_circle(center + Vector2(-radius * 0.62, radius * 0.70), 2.4, branch_color, true, -1.0, true)
		_draw_state_marker(center + Vector2(radius * 0.68, radius * 0.70), state_color)

	func _draw_node_shadow(center: Vector2, radius: float) -> void:
		draw_circle(center + Vector2(0.0, 3.0), radius + 1.5, Color(0.0, 0.0, 0.0, 0.55), true, -1.0, true)

	func _draw_state_marker(center: Vector2, marker_color: Color) -> void:
		draw_circle(center, 7.2, Color(0.025, 0.02, 0.03, 0.98), true, -1.0, true)
		draw_arc(center, 7.0, 0.0, TAU, 20, marker_color, 1.8, true)
		match state:
			"owned":
				draw_polyline(PackedVector2Array([center + Vector2(-3.4, 0.0), center + Vector2(-0.7, 2.8), center + Vector2(4.0, -3.0)]), marker_color, 2.0, true)
			"available":
				draw_line(center + Vector2(-3.5, 0.0), center + Vector2(3.5, 0.0), marker_color, 1.8, true)
				draw_line(center + Vector2(0.0, -3.5), center + Vector2(0.0, 3.5), marker_color, 1.8, true)
			"pending":
				draw_circle(center, 3.2, marker_color, true, -1.0, true)
			"excluded":
				draw_line(center + Vector2(-3.7, 3.7), center + Vector2(3.7, -3.7), marker_color, 2.0, true)
			_:
				draw_rect(Rect2(center + Vector2(-3.0, -0.5), Vector2(6.0, 4.5)), marker_color, false, 1.5, true)
				draw_arc(center + Vector2(0.0, -0.5), 3.0, PI, TAU, 12, marker_color, 1.5, true)

	func _diamond_points(center: Vector2, radius: float) -> PackedVector2Array:
		return PackedVector2Array([
			center + Vector2(0.0, -radius),
			center + Vector2(radius, 0.0),
			center + Vector2(0.0, radius),
			center + Vector2(-radius, 0.0),
		])

	func _hexagon_points(center: Vector2, radius: float) -> PackedVector2Array:
		var points := PackedVector2Array()
		for point_index: int in range(6):
			var angle: float = -PI * 0.5 + float(point_index) * TAU / 6.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		return points

	func _closed_points(points: PackedVector2Array) -> PackedVector2Array:
		var closed := PackedVector2Array(points)
		if not points.is_empty():
			closed.append(points[0])
		return closed

	func _face_state_color(value: String) -> Color:
		match value:
			"owned":
				return Color("e6b85f")
			"available":
				return Color("7dd7ca")
			"pending":
				return Color("70b9f2")
			"excluded":
				return Color("dc7186")
			_:
				return Color("68636d")

	func _face_fill_color(value: String) -> Color:
		match value:
			"owned":
				return Color("65461f")
			"available":
				return Color("173a35")
			"pending":
				return Color("174665")
			"excluded":
				return Color("3c1b25")
			_:
				return Color("17151a")

var _ui_skin := UiSkin.new()
var _owned_ids: Array[String]
var _required_count: int = 0
var _unspent_points: int = 0
var _editing_enabled: bool = true
var _focused_id: String = ""

var _graph_canvas: Control
var _graph_viewport: Control
var _graph_fit_scale: float = 1.0
var _link_layer: SkillLinkLayer
var _link_overlay_layer: SkillLinkOverlayLayer
var _summary_label: Label
var _node_buttons: Dictionary = {}
var _node_faces: Dictionary = {}
var _node_icons: Dictionary = {}
var _node_centers: Dictionary = {}
var _node_sizes: Dictionary = {}
var _node_visual_rects: Dictionary = {}
var _static_links: Array[Dictionary]
var _bridge_records: Array[Dictionary]
var _link_geometry_rebuild_count: int = 0
var _navigation_rebuild_count: int = 0
var _last_build_view_usec: int = 0
var _last_refresh_view_usec: int = 0
var _last_link_geometry_usec: int = 0
var _last_navigation_usec: int = 0
var _legend: HBoxContainer
var _graph_header: HBoxContainer
var _detail_panel: PanelContainer
var _detail_content: VBoxContainer
var _detail_divider: HSeparator
var _detail_status: Label
var _detail_title: Label
var _detail_description: RichTextLabel
var _detail_activation: Label
var _detail_requirements: Label
var _detail_unlocks: Label
var _detail_reason: Label
var _detail_action: Button
var _external_command_target: Control
var _external_tab_target: Control
var _compact_layout: bool = false

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", UiTypography.PANEL_GAP)
	var build_started_usec: int = Time.get_ticks_usec()
	_build_view()
	_last_build_view_usec = Time.get_ticks_usec() - build_started_usec
	var refresh_started_usec: int = Time.get_ticks_usec()
	_refresh_view()
	_last_refresh_view_usec = Time.get_ticks_usec() - refresh_started_usec
	resized.connect(_refresh_responsive_layout)
	call_deferred("_refresh_responsive_layout")
	# External tab/command controls may only become visible after this subtree's
	# ready pass. Rebind once the completed modal is live so controller exits do
	# not retain empty NodePaths.
	call_deferred("_configure_focus_neighbors")

func configure(context: Dictionary) -> void:
	_owned_ids = SkillTreeLibrary.normalized_ids(context.get("owned_ids", []))
	_required_count = maxi(0, int(context.get("required_count", _owned_ids.size())))
	_unspent_points = maxi(0, int(context.get("unspent_points", _required_count - _owned_ids.size())))
	_editing_enabled = bool(context.get("editing_enabled", true))
	var requested_focus: String = str(context.get("focused_id", _focused_id))
	_focused_id = requested_focus if SkillTreeLibrary.has_definition(requested_focus) else _default_focus_id()
	if is_node_ready():
		_refresh_summary()
		_refresh_nodes()
		_refresh_links()
		_refresh_detail()
		_configure_focus_neighbors()

func mode() -> String:
	return MODE_VIEW

func owned_skill_ids() -> Array[String]:
	return _string_array(_owned_ids)

func focus_skill(skill_id: String, ensure_visible: bool = true) -> void:
	if not SkillTreeLibrary.has_definition(skill_id):
		return
	_focused_id = skill_id
	_refresh_nodes()
	_refresh_links()
	_refresh_detail()
	_configure_focus_neighbors()
	skill_focused.emit(skill_id)
	if ensure_visible:
		call_deferred("_ensure_focused_visible")

func grab_tree_focus() -> void:
	var button: Button = node_for_skill(_focused_id)
	if button != null and button.is_inside_tree() and button.is_visible_in_tree():
		button.grab_focus()
		call_deferred("_ensure_focused_visible")

func set_external_command_focus_target(target: Control) -> void:
	_external_command_target = target
	if is_node_ready():
		_configure_focus_neighbors()

func set_external_tab_focus_target(target: Control) -> void:
	_external_tab_target = target
	if is_node_ready():
		_configure_focus_neighbors()

func focused_skill_id() -> String:
	return _focused_id

func activate_focused_skill() -> void:
	_on_detail_action_pressed()

func status_for_skill(skill_id: String) -> String:
	if not SkillTreeLibrary.has_definition(skill_id):
		return STATE_LOCKED
	if _owned_ids.has(skill_id):
		return STATE_OWNED
	if _is_excluded(skill_id, _owned_ids):
		return STATE_EXCLUDED
	return STATE_AVAILABLE if SkillTreeLibrary.is_available(skill_id, _owned_ids) else STATE_LOCKED

func visual_state_for_skill(skill_id: String) -> String:
	return STATE_SELECTED if skill_id == _focused_id else status_for_skill(skill_id)

func node_for_skill(skill_id: String) -> Button:
	return _node_buttons.get(skill_id, null) as Button

func node_count() -> int:
	return _node_buttons.size()

func connection_count() -> int:
	return _link_layer.links.size() if _link_layer != null else 0

func connection_arrowhead_count() -> int:
	return _link_overlay_layer.links.size() if _link_overlay_layer != null else 0

func highlighted_connection_count() -> int:
	if _link_layer == null:
		return 0
	var result: int = 0
	for link: Dictionary in _link_layer.links:
		if bool(link.get("highlighted", false)):
			result += 1
	return result

func highlighted_connection_pairs() -> Array[String]:
	var result: Array[String]
	if _link_layer == null:
		return result
	for link: Dictionary in _link_layer.links:
		if bool(link.get("highlighted", false)):
			result.append("%s>%s" % [str(link.get("from_id", "")), str(link.get("to_id", ""))])
	result.sort()
	return result

func legend_state_count() -> int:
	if _legend == null:
		return 0
	var count: int = 0
	for state: String in [STATE_OWNED, STATE_AVAILABLE, STATE_LOCKED, STATE_EXCLUDED]:
		var label: Label = _legend.get_node_or_null("SkillLegendLabel_%s" % state) as Label
		if label != null and label.visible:
			count += 1
	return count

func points_remaining() -> int:
	return _unspent_points

func link_geometry_rebuild_count() -> int:
	return _link_geometry_rebuild_count

func navigation_rebuild_count() -> int:
	return _navigation_rebuild_count

func performance_metrics() -> Dictionary:
	return {
		"build_view_usec": _last_build_view_usec,
		"refresh_view_usec": _last_refresh_view_usec,
		"link_geometry_usec": _last_link_geometry_usec,
		"navigation_usec": _last_navigation_usec,
	}

func graph_scroll_offset() -> Vector2i:
	return Vector2i.ZERO

func graph_fit_scale() -> float:
	return _graph_fit_scale

func detail_action_is_enabled() -> bool:
	return _detail_action != null and _detail_action.visible and not _detail_action.disabled

func detail_title_text() -> String:
	return _detail_title.text if _detail_title != null else ""

func graph_canvas_size() -> Vector2:
	return _graph_canvas.custom_minimum_size if _graph_canvas != null else Vector2.ZERO

func node_center_for_skill(skill_id: String) -> Vector2:
	return _node_center(skill_id)

func node_visual_rect(skill_id: String) -> Rect2:
	return _node_visual_rect(skill_id)

func node_role_for_skill(skill_id: String) -> String:
	return SkillTreeLibrary.tier(skill_id)

func navigation_neighbor(skill_id: String, direction: String) -> String:
	var button: Button = node_for_skill(skill_id)
	if button == null or direction not in ["left", "right", "up", "down"]:
		return ""
	return str(button.get_meta("nav_%s" % direction, ""))

func connection_points(source_id: String, target_id: String) -> PackedVector2Array:
	if _link_layer == null:
		return PackedVector2Array()
	for link: Dictionary in _link_layer.links:
		if str(link.get("from_id", "")) == source_id and str(link.get("to_id", "")) == target_id:
			return link.get("points", PackedVector2Array()) as PackedVector2Array
	return PackedVector2Array()

func connection_intersection_count(clearance: float = 2.0) -> int:
	return connection_intersection_pairs(clearance).size()

func connection_intersection_pairs(clearance: float = 2.0) -> Array[String]:
	var result: Array[String]
	if _link_layer == null:
		return result
	for link: Dictionary in _link_layer.links:
		var source_id: String = str(link.get("from_id", ""))
		var target_id: String = str(link.get("to_id", ""))
		var points: PackedVector2Array = link.get("points", PackedVector2Array()) as PackedVector2Array
		for skill_id: String in SkillTreeLibrary.ordered_ids():
			if skill_id in [source_id, target_id]:
				continue
			var obstacle: Rect2 = _node_visual_rect(skill_id).grow(clearance)
			for point_index: int in range(points.size() - 1):
				if _axis_segment_intersects_rect(points[point_index], points[point_index + 1], obstacle):
					result.append("%s>%s@%s" % [source_id, target_id, skill_id])
					break
	return result

func collinear_connection_overlap_pairs() -> Array[String]:
	var result: Array[String]
	for record: Dictionary in _bridge_records:
		if str(record.get("kind", "")) != "overlap":
			continue
		var pair_key: String = str(record.get("pair_key", ""))
		if not pair_key.is_empty() and not result.has(pair_key):
			result.append(pair_key)
	result.sort()
	return result

func bridged_connection_pairs() -> Array[String]:
	var result: Array[String]
	for record: Dictionary in _bridge_records:
		if str(record.get("kind", "")) != "crossing" or not bool(record.get("bridged", false)):
			continue
		var pair_key: String = str(record.get("pair_key", ""))
		if not pair_key.is_empty() and not result.has(pair_key):
			result.append(pair_key)
	result.sort()
	return result

func bridge_assignment_signature() -> Array[String]:
	var result: Array[String]
	for record: Dictionary in _bridge_records:
		if str(record.get("kind", "")) != "crossing" or not bool(record.get("bridged", false)):
			continue
		result.append("%s under %s" % [str(record.get("lower_link", "")), str(record.get("pair_key", ""))])
	result.sort()
	return result

func unbridged_connection_pairs() -> Array[String]:
	var result: Array[String]
	for record: Dictionary in _bridge_records:
		if str(record.get("kind", "")) != "crossing" or bool(record.get("bridged", false)):
			continue
		var pair_key: String = str(record.get("pair_key", ""))
		if not pair_key.is_empty() and not result.has(pair_key):
			result.append(pair_key)
	result.sort()
	return result

func minimum_bridge_half_gap() -> float:
	var result: float = INF
	for record: Dictionary in _bridge_records:
		if str(record.get("kind", "")) == "crossing" and bool(record.get("bridged", false)):
			result = minf(result, float(record.get("half_gap", 0.0)))
	return 0.0 if result == INF else result

func minimum_connection_width() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = INF
	for link: Dictionary in _link_layer.links:
		result = minf(result, float(link.get("width", 0.0)))
	return result

func minimum_connection_alpha() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = 1.0
	for link: Dictionary in _link_layer.links:
		var color: Color = link.get("color", Color.TRANSPARENT)
		result = minf(result, color.a)
	return result

func minimum_understroke_margin() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = INF
	for link: Dictionary in _link_layer.links:
		result = minf(result, float(link.get("under_width", 0.0)) - float(link.get("width", 0.0)))
	return result

func minimum_target_segment_length() -> float:
	if _link_layer == null or _link_layer.links.is_empty():
		return 0.0
	var result: float = INF
	for link: Dictionary in _link_layer.links:
		var points: PackedVector2Array = link.get("points", PackedVector2Array()) as PackedVector2Array
		if points.size() < 2:
			return 0.0
		result = minf(result, points[points.size() - 1].distance_to(points[points.size() - 2]))
	return result

func _build_view() -> void:
	if not _node_buttons.is_empty():
		return
	add_child(_build_graph_panel())
	add_child(_build_detail_panel())

func _build_graph_panel() -> Control:
	var panel := PanelContainer.new()
	panel.name = "SkillTreeGraphPanel"
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", _panel_style(Color("756245")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 6)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 6)
	panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiTypography.SPACE_TIGHT)
	margin.add_child(column)

	_graph_header = HBoxContainer.new()
	_graph_header.name = "SkillTreeGraphHeader"
	_graph_header.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	column.add_child(_graph_header)
	var title := Label.new()
	title.text = "SKILL TREE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiTypography.apply_label_role(title, UiTypography.ROLE_SECTION)
	title.add_theme_color_override("font_color", Color("f2e6d1"))
	_graph_header.add_child(title)
	_summary_label = Label.new()
	_summary_label.name = "SkillTreeSummary"
	UiTypography.apply_label_role(_summary_label, UiTypography.ROLE_CAPTION)
	_summary_label.add_theme_color_override("font_color", Color("d6bc87"))
	_graph_header.add_child(_summary_label)

	_legend = HBoxContainer.new()
	_legend.name = "SkillStateLegend"
	_legend.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	column.add_child(_legend)
	_build_state_legend()

	_graph_viewport = Control.new()
	_graph_viewport.name = "SkillTreeGraphViewport"
	_graph_viewport.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_graph_viewport.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_graph_viewport.clip_contents = true
	_graph_viewport.mouse_filter = Control.MOUSE_FILTER_PASS
	_graph_viewport.resized.connect(_layout_graph_canvas)
	column.add_child(_graph_viewport)

	_graph_canvas = Control.new()
	_graph_canvas.name = "SkillTreeCanvas"
	_graph_canvas.custom_minimum_size = GRAPH_SIZE
	_graph_canvas.size = GRAPH_SIZE
	_graph_canvas.mouse_filter = Control.MOUSE_FILTER_PASS
	_graph_viewport.add_child(_graph_canvas)

	_link_layer = SkillLinkLayer.new()
	_link_layer.name = "SkillTreeLinkLayer"
	_link_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_canvas.add_child(_link_layer)

	_build_branch_headers()
	_build_skill_nodes()
	_link_overlay_layer = SkillLinkOverlayLayer.new()
	_link_overlay_layer.name = "SkillTreeLinkOverlayLayer"
	_link_overlay_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_link_overlay_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_graph_canvas.add_child(_link_overlay_layer)
	call_deferred("_layout_graph_canvas")
	return panel

func _layout_graph_canvas() -> void:
	if _graph_viewport == null or _graph_canvas == null:
		return
	var available_size: Vector2 = _graph_viewport.size
	if available_size.x <= 1.0 or available_size.y <= 1.0:
		return
	_graph_fit_scale = minf(1.0, minf(available_size.x / GRAPH_SIZE.x, available_size.y / GRAPH_SIZE.y))
	var scaled_size: Vector2 = GRAPH_SIZE * _graph_fit_scale
	_graph_canvas.scale = Vector2(_graph_fit_scale, _graph_fit_scale)
	_graph_canvas.position = (available_size - scaled_size) * 0.5

func _refresh_responsive_layout() -> void:
	var compact: bool = size.x < COMPACT_LAYOUT_WIDTH
	_compact_layout = compact
	if _graph_header != null:
		_graph_header.visible = not compact
	if _legend != null:
		_legend.visible = not compact
	if _detail_panel != null:
		_detail_panel.custom_minimum_size.x = COMPACT_DETAIL_WIDTH if compact else DETAIL_WIDTH
	if _detail_content != null:
		_detail_content.add_theme_constant_override("separation", UiTypography.SPACE_TIGHT if compact else UiTypography.SPACE_SMALL)
	if _detail_title != null:
		UiTypography.apply_label_role(_detail_title, UiTypography.ROLE_BODY_LARGE if compact else UiTypography.ROLE_SECTION)
	if _detail_description != null:
		UiTypography.apply_rich_text_role(_detail_description, UiTypography.ROLE_CAPTION if compact else UiTypography.ROLE_BODY)
	_refresh_detail_visibility()
	call_deferred("_layout_graph_canvas")

func _build_branch_headers() -> void:
	for root_id: String in ["measured_breath", "quick_wits", "discerning_eye", "ghost_stride", "long_dawn"]:
		var definition: Dictionary = SkillTreeLibrary.definition(root_id)
		var branch_id: String = str(definition.get("branch", ""))
		var label := Label.new()
		label.name = "SkillBranchHeader_%s" % branch_id.capitalize()
		label.text = branch_id.to_upper()
		label.position = Vector2(_node_center(root_id).x - 48.0, 1.0)
		label.size = Vector2(96.0, 20.0)
		label.custom_minimum_size = label.size
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.apply_label_role(label, UiTypography.ROLE_CAPTION)
		label.add_theme_color_override("font_color", _branch_color(branch_id).lightened(0.12))
		_graph_canvas.add_child(label)

func _build_state_legend() -> void:
	if _legend == null:
		return
	for state: String in [STATE_OWNED, STATE_AVAILABLE, STATE_LOCKED, STATE_EXCLUDED]:
		var marker := SkillLegendMarker.new()
		marker.name = "SkillLegendMarker_%s" % state
		marker.custom_minimum_size = Vector2(18.0, 18.0)
		marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
		marker.set_meta("skill_state", state)
		marker.set_meta("symbol_kind", _legend_symbol_kind(state))
		marker.configure(state, _state_color(state))
		_legend.add_child(marker)
		var label := Label.new()
		label.name = "SkillLegendLabel_%s" % state
		label.text = _legend_state_text(state)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UiTypography.apply_label_role(label, UiTypography.ROLE_CAPTION)
		label.add_theme_color_override("font_color", Color("cfc4b2") if state != STATE_LOCKED else Color("8f8991"))
		_legend.add_child(label)

func _legend_symbol_kind(state: String) -> String:
	match state:
		STATE_OWNED:
			return "check"
		STATE_AVAILABLE:
			return "plus"
		STATE_EXCLUDED:
			return "strike"
		_:
			return "lock"

func _build_skill_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node_size: Vector2 = _node_size(skill_id)
		var node_center: Vector2 = _node_center(skill_id)
		_node_centers[skill_id] = node_center
		_node_sizes[skill_id] = node_size
		_node_visual_rects[skill_id] = Rect2(node_center - (node_size - Vector2(8.0, 8.0)) * 0.5, node_size - Vector2(8.0, 8.0))
		var button := Button.new()
		button.name = "SkillNode_%s" % skill_id
		button.position = node_center - node_size * 0.5
		button.size = node_size
		button.custom_minimum_size = node_size
		button.focus_mode = Control.FOCUS_ALL
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.clip_contents = false
		button.pressed.connect(_on_node_pressed.bind(skill_id))
		button.focus_entered.connect(_on_node_focus_entered.bind(skill_id))
		for style_name: String in ["normal", "hover", "pressed", "focus", "disabled"]:
			button.add_theme_stylebox_override(style_name, StyleBoxEmpty.new())
		_graph_canvas.add_child(button)
		_node_buttons[skill_id] = button
		_node_icons[skill_id] = ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id))
		var face := SkillNodeFace.new()
		face.name = "SkillNodeFace"
		face.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		button.add_child(face)
		_node_faces[skill_id] = face

func _build_detail_panel() -> Control:
	_detail_panel = PanelContainer.new()
	_detail_panel.name = "SkillDetailPanel"
	_detail_panel.custom_minimum_size = Vector2(DETAIL_WIDTH, 0.0)
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_panel.clip_contents = true
	_detail_panel.add_theme_stylebox_override("panel", _panel_style(Color("8c6f49")))

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_COMPACT))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING_COMPACT))
	_detail_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	margin.add_child(column)

	_detail_content = VBoxContainer.new()
	_detail_content.name = "SkillDetailContent"
	_detail_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_detail_content.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	column.add_child(_detail_content)

	_detail_status = Label.new()
	_detail_status.name = "SkillDetailStatus"
	UiTypography.apply_label_role(_detail_status, UiTypography.ROLE_CAPTION)
	_detail_content.add_child(_detail_status)

	_detail_title = Label.new()
	_detail_title.name = "SkillDetailTitle"
	_detail_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_title, UiTypography.ROLE_SECTION)
	_detail_title.add_theme_color_override("font_color", Color("f5ead4"))
	_detail_content.add_child(_detail_title)

	_detail_description = RichTextLabel.new()
	_detail_description.name = "SkillDetailDescription"
	_detail_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_description.bbcode_enabled = false
	_detail_description.fit_content = true
	_detail_description.scroll_active = false
	_detail_description.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UiTypography.apply_rich_text_role(_detail_description, UiTypography.ROLE_BODY)
	_detail_description.add_theme_color_override("default_color", Color("ddcfb7"))
	_detail_content.add_child(_detail_description)

	_detail_divider = HSeparator.new()
	_detail_divider.add_theme_constant_override("separation", UiTypography.SPACE_SMALL)
	_detail_content.add_child(_detail_divider)

	_detail_activation = Label.new()
	_detail_activation.name = "SkillDetailActivation"
	UiTypography.apply_label_role(_detail_activation, UiTypography.ROLE_CAPTION)
	_detail_activation.add_theme_color_override("font_color", Color("c9b998"))
	_detail_activation.visible = false
	_detail_content.add_child(_detail_activation)

	_detail_requirements = Label.new()
	_detail_requirements.name = "SkillDetailRequirements"
	_detail_requirements.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_requirements, UiTypography.ROLE_CAPTION)
	_detail_requirements.add_theme_color_override("font_color", Color("c9b998"))
	_detail_content.add_child(_detail_requirements)

	_detail_unlocks = Label.new()
	_detail_unlocks.name = "SkillDetailUnlocks"
	_detail_unlocks.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_unlocks, UiTypography.ROLE_CAPTION)
	_detail_unlocks.add_theme_color_override("font_color", Color("a8c9c1"))
	_detail_content.add_child(_detail_unlocks)

	_detail_reason = Label.new()
	_detail_reason.name = "SkillDetailReason"
	_detail_reason.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UiTypography.apply_label_role(_detail_reason, UiTypography.ROLE_BODY)
	_detail_content.add_child(_detail_reason)

	_detail_action = Button.new()
	_detail_action.name = "SkillDetailAction"
	_detail_action.custom_minimum_size = Vector2(0.0, 44.0)
	_detail_action.pressed.connect(_on_detail_action_pressed)
	column.add_child(_detail_action)

	return _detail_panel

func _refresh_view() -> void:
	if _graph_canvas == null:
		return
	if _static_links.is_empty():
		_rebuild_link_geometry()
	_refresh_legend()
	_refresh_summary()
	_refresh_nodes()
	_refresh_links()
	_refresh_detail()
	_configure_focus_neighbors()

func _refresh_legend() -> void:
	if _legend == null:
		return
	for state: String in [STATE_OWNED, STATE_AVAILABLE, STATE_LOCKED, STATE_EXCLUDED]:
		var marker: Control = _legend.get_node_or_null("SkillLegendMarker_%s" % state) as Control
		var label: Label = _legend.get_node_or_null("SkillLegendLabel_%s" % state) as Label
		if marker != null:
			marker.visible = true
		if label != null:
			label.text = _legend_state_text(state)
			label.visible = true

func _refresh_summary() -> void:
	if _summary_label == null:
		return
	_summary_label.text = "LEARNED %d  ·  POINTS %d" % [_owned_ids.size(), _unspent_points]

func _refresh_nodes() -> void:
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button: Button = node_for_skill(skill_id)
		if button == null:
			continue
		var base_state: String = status_for_skill(skill_id)
		var selected: bool = skill_id == _focused_id
		var relationship: String = _relationship_to_focus(skill_id)
		button.set_meta("skill_id", skill_id)
		button.set_meta("skill_state", base_state)
		button.set_meta("skill_visual_state", STATE_SELECTED if selected else base_state)
		button.set_meta("selected", selected)
		button.set_meta("focus_relationship", relationship)
		button.set_meta("node_role", SkillTreeLibrary.tier(skill_id))
		button.set_meta("icon_key", SkillTreeLibrary.icon_key(skill_id))
		button.tooltip_text = ""
		var face: SkillNodeFace = _node_faces.get(skill_id, null) as SkillNodeFace
		if face != null:
			face.configure(
				SkillTreeLibrary.tier(skill_id),
				base_state,
				relationship,
				selected,
				_branch_color(str(SkillTreeLibrary.definition(skill_id).get("branch", ""))),
				_node_icons.get(skill_id, null) as Texture2D
			)

func _rebuild_link_geometry() -> void:
	var started_usec: int = Time.get_ticks_usec()
	var links: Array[Dictionary]
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			var sort_key: String = "%s>%s" % [prerequisite_id, skill_id]
			links.append({
				"from_id": prerequisite_id,
				"to_id": skill_id,
				"sort_key": sort_key,
				"points": _link_points(prerequisite_id, skill_id),
				"bridge_gaps": [],
			})
	_bridge_records = _annotate_connection_bridges(links)
	_static_links = links
	_link_geometry_rebuild_count += 1
	_last_link_geometry_usec = Time.get_ticks_usec() - started_usec

func _refresh_links() -> void:
	if _link_layer == null:
		return
	if _static_links.is_empty():
		_rebuild_link_geometry()
	var links: Array[Dictionary]
	var ancestor_ids: Array[String] = _ancestor_ids(_focused_id)
	for geometry: Dictionary in _static_links:
		var prerequisite_id: String = str(geometry.get("from_id", ""))
		var skill_id: String = str(geometry.get("to_id", ""))
		var relationship: String = "unrelated"
		if skill_id == _focused_id:
			relationship = "prerequisite"
		elif prerequisite_id == _focused_id:
			relationship = "dependent"
		elif ancestor_ids.has(prerequisite_id) and ancestor_ids.has(skill_id):
			relationship = "ancestor"
		var link_state: String = _link_state(prerequisite_id, skill_id)
		var visual: Dictionary = _link_visual(link_state, relationship)
		var link: Dictionary = geometry.duplicate(false)
		link["relationship"] = relationship
		link["highlighted"] = relationship in ["prerequisite", "dependent", "ancestor"]
		link["draw_priority"] = _link_draw_priority(link_state, relationship)
		link["color"] = visual.get("color", Color("413b43"))
		link["width"] = float(visual.get("width", 3.0))
		link["under_width"] = float(link.get("width", 3.0)) + 3.0
		links.append(link)
	_link_layer.set_links(links)
	if _link_overlay_layer != null:
		_link_overlay_layer.set_links(links)

func _refresh_detail() -> void:
	if _detail_title == null:
		return
	if not SkillTreeLibrary.has_definition(_focused_id):
		_detail_status.text = "SELECT A SKILL"
		_detail_title.text = "Skill Tree"
		_detail_description.text = "Choose a node to inspect its effect and requirements."
		_detail_activation.text = ""
		_detail_requirements.text = ""
		_detail_unlocks.text = ""
		_detail_reason.text = ""
		_detail_action.visible = false
		return
	var state: String = status_for_skill(_focused_id)
	_detail_status.text = _detail_status_text(_focused_id, state)
	_detail_status.add_theme_color_override("font_color", _state_color(state).lightened(0.12))
	_detail_title.text = SkillTreeLibrary.display_name(_focused_id)
	InlineIconText.apply_to(_detail_description, SkillTreeLibrary.description(_focused_id))
	_detail_activation.text = "TIMING  ·  %s" % SkillTreeLibrary.activation_kind(_focused_id).to_upper()
	_detail_requirements.text = _requirements_text(_focused_id)
	_detail_unlocks.text = _unlocks_text(_focused_id)
	_detail_reason.text = _detail_reason_text(_focused_id, state)
	_refresh_detail_visibility()
	_detail_reason.add_theme_color_override("font_color", _state_color(state).lightened(0.16))
	_refresh_detail_action(state)

func _refresh_detail_visibility() -> void:
	if _detail_divider != null:
		_detail_divider.visible = not _compact_layout
	if _detail_requirements != null:
		_detail_requirements.visible = not _compact_layout
	if _detail_unlocks != null:
		_detail_unlocks.visible = not _compact_layout
	if _detail_reason != null:
		_detail_reason.visible = not _detail_reason.text.is_empty()

func _refresh_detail_action(state: String) -> void:
	_detail_action.visible = true
	_detail_action.disabled = true
	if state == STATE_OWNED:
		_detail_action.text = "Learned"
	elif state == STATE_AVAILABLE and _unspent_points > 0:
		_detail_action.text = "Learn  ·  1 Point"
		_detail_action.disabled = not _editing_enabled
	elif state == STATE_AVAILABLE:
		_detail_action.text = "No Skill Points"
	else:
		_detail_action.text = "Unavailable"
	var action_variant: String = UiSkin.VARIANT_SELECTED if not _detail_action.disabled else UiSkin.VARIANT_STANDARD
	_ui_skin.apply_button_stylebox_overrides(_detail_action, action_variant)
	_ui_skin.apply_button_text_overrides(_detail_action)
	UiTypography.apply_button_role(_detail_action, UiTypography.ROLE_BODY)

func _on_node_pressed(skill_id: String) -> void:
	focus_skill(skill_id)

func _on_node_focus_entered(skill_id: String) -> void:
	if skill_id != _focused_id:
		focus_skill(skill_id)

func _ensure_focused_visible() -> void:
	# The complete topology is always zoomed to fit. Focus never pans or scrolls
	# the authored graph away from the surrounding prerequisites and dependents.
	_layout_graph_canvas()

func _configure_focus_neighbors() -> void:
	var started_usec: int = Time.get_ticks_usec()
	_navigation_rebuild_count += 1
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var button: Button = node_for_skill(skill_id)
		if button == null:
			continue
		for direction: String in ["left", "right", "up", "down"]:
			var neighbor_id: String = _navigation_neighbor_for_direction(skill_id, direction)
			button.set_meta("nav_%s" % direction, neighbor_id)
			var neighbor: Control = node_for_skill(neighbor_id)
			if neighbor == null:
				neighbor = _tree_exit_target(direction)
			_set_focus_neighbor(button, direction, neighbor if neighbor != null else button)
	_configure_command_focus_neighbors()
	_last_navigation_usec = Time.get_ticks_usec() - started_usec

func _tree_exit_target(direction: String) -> Control:
	if direction in ["left", "up"] and _control_accepts_focus(_external_tab_target):
		return _external_tab_target
	if direction == "right" and _control_accepts_focus(_detail_action):
		return _detail_action
	if direction in ["right", "down"]:
		if _control_accepts_focus(_external_command_target):
			return _external_command_target
	return null

func _configure_command_focus_neighbors() -> void:
	var focused_node: Button = node_for_skill(_focused_id)
	if focused_node == null:
		return
	if _control_accepts_focus(_external_tab_target):
		_set_focus_neighbor(_external_tab_target, "down", focused_node)
	if _control_accepts_focus(_detail_action):
		_set_focus_neighbor(_detail_action, "left", focused_node)
		_set_focus_neighbor(_detail_action, "up", focused_node)
		_set_focus_neighbor(_detail_action, "down", _external_command_target if _control_accepts_focus(_external_command_target) else focused_node)
	if _control_accepts_focus(_external_command_target):
		_set_focus_neighbor(_external_command_target, "left", focused_node)
		_set_focus_neighbor(
			_external_command_target,
			"up",
			_external_tab_target if _control_accepts_focus(_external_tab_target) else focused_node
		)

func _control_accepts_focus(control: Control) -> bool:
	if control == null or not control.is_inside_tree() or not control.is_visible_in_tree() or control.focus_mode == Control.FOCUS_NONE:
		return false
	if control is BaseButton and (control as BaseButton).disabled:
		return false
	return true

func _set_focus_neighbor(source: Control, direction: String, target: Control) -> void:
	if source == null or target == null or not source.is_inside_tree() or not target.is_inside_tree():
		return
	var target_path: NodePath = source.get_path_to(target)
	match direction:
		"left":
			source.focus_neighbor_left = target_path
		"right":
			source.focus_neighbor_right = target_path
		"up":
			source.focus_neighbor_top = target_path
		"down":
			source.focus_neighbor_bottom = target_path

func _navigation_neighbor_for_direction(skill_id: String, direction: String) -> String:
	var origin: Vector2 = _node_center(skill_id)
	if direction in ["left", "right"]:
		var best_id: String = ""
		var best_distance: float = INF
		for candidate_id: String in SkillTreeLibrary.ordered_ids():
			if candidate_id == skill_id:
				continue
			var delta: Vector2 = _node_center(candidate_id) - origin
			if absf(delta.y) > 0.5:
				continue
			if direction == "left" and delta.x >= -0.5:
				continue
			if direction == "right" and delta.x <= 0.5:
				continue
			var distance: float = absf(delta.x)
			if distance < best_distance:
				best_distance = distance
				best_id = candidate_id
		return best_id
	var candidates: Array[String]
	if direction == "up":
		candidates = SkillTreeLibrary.prerequisites(skill_id)
	else:
		candidates = _direct_dependent_ids(skill_id)
	var best_id: String = ""
	var best_horizontal_distance: float = INF
	for candidate_id: String in candidates:
		var horizontal_distance: float = absf(_node_center(candidate_id).x - origin.x)
		if horizontal_distance < best_horizontal_distance:
			best_horizontal_distance = horizontal_distance
			best_id = candidate_id
		elif is_equal_approx(horizontal_distance, best_horizontal_distance) and not best_id.is_empty():
			if _node_center(candidate_id).x < _node_center(best_id).x:
				best_id = candidate_id
	return best_id

func _on_detail_action_pressed() -> void:
	if not _editing_enabled or not SkillTreeLibrary.has_definition(_focused_id):
		return
	if _unspent_points <= 0 or not SkillTreeLibrary.is_available(_focused_id, _owned_ids):
		return
	learn_requested.emit(_focused_id)

func _default_focus_id() -> String:
	if not _owned_ids.is_empty():
		return _owned_ids[0]
	var available: Array[String] = SkillTreeLibrary.available_ids([])
	return available[0] if not available.is_empty() else ""

func _is_excluded(skill_id: String, selection: Array[String]) -> bool:
	var group_id: String = SkillTreeLibrary.exclusive_group(skill_id)
	if group_id.is_empty():
		return false
	for selected_id: String in selection:
		if selected_id != skill_id and SkillTreeLibrary.exclusive_group(selected_id) == group_id:
			return true
	return false

func _node_center(skill_id: String) -> Vector2:
	if _node_centers.has(skill_id):
		return _node_centers.get(skill_id, Vector2.ZERO) as Vector2
	return Vector2(SkillTreeLibrary.layout_position(skill_id))

func _node_size(skill_id: String) -> Vector2:
	if _node_sizes.has(skill_id):
		return _node_sizes.get(skill_id, Vector2.ZERO) as Vector2
	return Vector2(SkillTreeLibrary.layout_node_size(skill_id))

func _node_visual_rect(skill_id: String) -> Rect2:
	if _node_visual_rects.has(skill_id):
		return _node_visual_rects.get(skill_id, Rect2()) as Rect2
	var visual_size: Vector2 = _node_size(skill_id) - Vector2(8.0, 8.0)
	return Rect2(_node_center(skill_id) - visual_size * 0.5, visual_size)

func _node_state_text(skill_id: String, state: String) -> String:
	match state:
		STATE_OWNED:
			return "[ LEARNED ]"
		STATE_AVAILABLE:
			return "+  AVAILABLE"
		STATE_EXCLUDED:
			return "X  EXCLUSIVE"
		_:
			return "-  LOCKED"

func _legend_state_text(state: String) -> String:
	match state:
		STATE_OWNED:
			return "LEARNED"
		STATE_AVAILABLE:
			return "AVAILABLE"
		STATE_EXCLUDED:
			return "EXCLUSIVE"
		_:
			return "LOCKED"

func _detail_status_text(skill_id: String, state: String) -> String:
	var tier: String = str(SkillTreeLibrary.definition(skill_id).get("tier", "skill")).to_upper()
	var activation: String = SkillTreeLibrary.activation_kind(skill_id).to_upper()
	return "%s  ·  %s  ·  %s" % [tier, _node_state_text(skill_id, state), activation]

func _detail_reason_text(skill_id: String, state: String) -> String:
	if state == STATE_OWNED:
		return ""
	if state == STATE_AVAILABLE:
		if _unspent_points <= 0:
			return "Requirements met. Earn another skill point to learn this."
		return ""
	return SkillTreeLibrary.locked_reason(skill_id, _selection_for_availability())

func _requirements_text(skill_id: String) -> String:
	var parts: Array[String]
	parts.append("REQUIRES")
	var selection: Array[String] = _selection_for_availability()
	for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
		parts.append("%s  %s" % [
			"READY" if selection.has(prerequisite_id) else "NEED",
			SkillTreeLibrary.display_name(prerequisite_id),
		])
	if SkillTreeLibrary.prerequisites(skill_id).is_empty():
		parts.append("NONE  Root skill")
	var minimum_owned: int = SkillTreeLibrary.minimum_owned(skill_id)
	if minimum_owned > 0:
		var other_skill_count: int = selection.size() - (1 if selection.has(skill_id) else 0)
		parts.append("%s  %d other skills learned" % ["READY" if other_skill_count >= minimum_owned else "NEED", minimum_owned])
	if not SkillTreeLibrary.exclusive_group(skill_id).is_empty():
		parts.append("LIMIT  One keystone per build")
	return "\n".join(parts)

func _unlocks_text(skill_id: String) -> String:
	var dependents: Array[String] = _direct_dependent_ids(skill_id)
	if dependents.is_empty():
		return "LEADS TO\nNo direct skills"
	var names: Array[String]
	for dependent_id: String in dependents:
		names.append(SkillTreeLibrary.display_name(dependent_id))
	return "LEADS TO\n%s" % "  ·  ".join(names)

func _selection_for_availability() -> Array[String]:
	return _string_array(_owned_ids)

func _branch_color(branch_id: String) -> Color:
	return BRANCH_COLORS.get(branch_id, Color("b99a6b"))

func _state_color(state: String) -> Color:
	match state:
		STATE_OWNED:
			return Color("e6b85f")
		STATE_AVAILABLE:
			return Color("7dd7ca")
		STATE_EXCLUDED:
			return Color("dc7186")
		_:
			return Color("57535b")

func _relationship_to_focus(skill_id: String) -> String:
	if _focused_id.is_empty() or skill_id == _focused_id:
		return "none"
	if SkillTreeLibrary.prerequisites(_focused_id).has(skill_id):
		return "prerequisite"
	if _direct_dependent_ids(_focused_id).has(skill_id):
		return "dependent"
	return "none"

func _direct_dependent_ids(skill_id: String) -> Array[String]:
	var result: Array[String]
	if skill_id.is_empty():
		return result
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if SkillTreeLibrary.prerequisites(candidate_id).has(skill_id):
			result.append(candidate_id)
	return result

func _ancestor_ids(skill_id: String) -> Array[String]:
	var result: Array[String]
	if skill_id.is_empty():
		return result
	var pending: Array[String] = SkillTreeLibrary.prerequisites(skill_id)
	while not pending.is_empty():
		var candidate_id: String = pending.pop_front()
		if result.has(candidate_id):
			continue
		result.append(candidate_id)
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(candidate_id):
			if not result.has(prerequisite_id):
				pending.append(prerequisite_id)
	return result

func _link_state(source_id: String, target_id: String) -> String:
	var source_state: String = status_for_skill(source_id)
	var target_state: String = status_for_skill(target_id)
	if source_state == STATE_OWNED and target_state == STATE_OWNED:
		return STATE_OWNED
	if target_state == STATE_AVAILABLE:
		return STATE_AVAILABLE
	if STATE_EXCLUDED in [source_state, target_state]:
		return STATE_EXCLUDED
	return STATE_LOCKED

func _link_visual(link_state: String, relationship: String) -> Dictionary:
	match relationship:
		"prerequisite":
			return {"color": Color("ffd47a"), "width": 5.0}
		"dependent":
			return {"color": Color("8ce1d5"), "width": 5.0}
		"ancestor":
			var ancestor_color := Color("bfa36d")
			ancestor_color.a = 0.90
			return {"color": ancestor_color, "width": 3.8}
	match link_state:
		STATE_OWNED:
			return {"color": Color("d6a84f"), "width": 4.0}
		STATE_AVAILABLE:
			return {"color": Color("69c5b8"), "width": 3.6}
		STATE_EXCLUDED:
			return {"color": Color("b96073"), "width": 3.2}
		_:
			return {"color": Color("746d79"), "width": 3.0}

func _link_draw_priority(link_state: String, relationship: String) -> int:
	var state_priority: int = 0
	match link_state:
		STATE_EXCLUDED:
			state_priority = 1
		STATE_AVAILABLE:
			state_priority = 2
		STATE_OWNED:
			state_priority = 3
	if relationship == "ancestor":
		return 20 + state_priority
	if relationship in ["prerequisite", "dependent"]:
		return 30 + state_priority
	return state_priority

func _annotate_connection_bridges(links: Array[Dictionary]) -> Array[Dictionary]:
	var records: Array[Dictionary]
	for left_index: int in range(links.size()):
		var left: Dictionary = links[left_index]
		for right_index: int in range(left_index + 1, links.size()):
			var right: Dictionary = links[right_index]
			if _links_are_incident(left, right):
				continue
			var left_points: PackedVector2Array = left.get("points", PackedVector2Array()) as PackedVector2Array
			var right_points: PackedVector2Array = right.get("points", PackedVector2Array()) as PackedVector2Array
			for left_segment_index: int in range(left_points.size() - 1):
				for right_segment_index: int in range(right_points.size() - 1):
					var intersection: Dictionary = _connection_segment_intersection(
						left_points[left_segment_index],
						left_points[left_segment_index + 1],
						right_points[right_segment_index],
						right_points[right_segment_index + 1]
					)
					if intersection.is_empty():
						continue
					var pair_key: String = _connection_pair_key(left, right)
					var kind: String = str(intersection.get("kind", ""))
					var record: Dictionary = {
						"kind": kind,
						"pair_key": pair_key,
						"point": intersection.get("point", Vector2.ZERO),
						"bridged": false,
					}
					if kind == "crossing":
						var left_is_lower: bool = _link_is_below(left, right)
						var lower_index: int = left_index if left_is_lower else right_index
						var lower_segment_index: int = left_segment_index if left_is_lower else right_segment_index
						var lower_points: PackedVector2Array = left_points if left_is_lower else right_points
						var point: Vector2 = intersection.get("point", Vector2.ZERO) as Vector2
						var lower_start: Vector2 = lower_points[lower_segment_index]
						var gap: Dictionary = {
							"segment_index": lower_segment_index,
							"distance": lower_start.distance_to(point),
							"half_gap": LINK_BRIDGE_HALF_GAP,
						}
						var lower_link: Dictionary = links[lower_index]
						var lower_gaps: Array = lower_link.get("bridge_gaps", []) as Array
						lower_gaps.append(gap)
						lower_link["bridge_gaps"] = lower_gaps
						links[lower_index] = lower_link
						record["bridged"] = true
						record["half_gap"] = LINK_BRIDGE_HALF_GAP
						record["lower_link"] = str(lower_link.get("sort_key", ""))
					records.append(record)
	return records

func _links_are_incident(left: Dictionary, right: Dictionary) -> bool:
	var left_ids: Array[String]
	left_ids.append(str(left.get("from_id", "")))
	left_ids.append(str(left.get("to_id", "")))
	var right_ids: Array[String]
	right_ids.append(str(right.get("from_id", "")))
	right_ids.append(str(right.get("to_id", "")))
	return left_ids[0] in right_ids or left_ids[1] in right_ids

func _link_is_below(left: Dictionary, right: Dictionary) -> bool:
	var left_length: float = _connection_route_length(left)
	var right_length: float = _connection_route_length(right)
	if not is_equal_approx(left_length, right_length):
		# Long cross-branch routes pass beneath shorter local routes. This remains
		# stable as focus and learned state change, so the topology never flips.
		return left_length > right_length
	return str(left.get("sort_key", "")) < str(right.get("sort_key", ""))

func _connection_route_length(link: Dictionary) -> float:
	var points: PackedVector2Array = link.get("points", PackedVector2Array()) as PackedVector2Array
	var result: float = 0.0
	for point_index: int in range(points.size() - 1):
		result += points[point_index].distance_to(points[point_index + 1])
	return result

func _connection_pair_key(left: Dictionary, right: Dictionary) -> String:
	var keys: Array[String]
	keys.append(str(left.get("sort_key", "")))
	keys.append(str(right.get("sort_key", "")))
	keys.sort()
	return "%s × %s" % [keys[0], keys[1]]

func _connection_segment_intersection(
	left_start: Vector2,
	left_finish: Vector2,
	right_start: Vector2,
	right_finish: Vector2
) -> Dictionary:
	var left_vertical: bool = is_equal_approx(left_start.x, left_finish.x)
	var left_horizontal: bool = is_equal_approx(left_start.y, left_finish.y)
	var right_vertical: bool = is_equal_approx(right_start.x, right_finish.x)
	var right_horizontal: bool = is_equal_approx(right_start.y, right_finish.y)
	if left_vertical and right_horizontal:
		var point := Vector2(left_start.x, right_start.y)
		if _point_is_on_axis_segment(point, left_start, left_finish) and _point_is_on_axis_segment(point, right_start, right_finish):
			return {"kind": "crossing", "point": point}
	if left_horizontal and right_vertical:
		var point := Vector2(right_start.x, left_start.y)
		if _point_is_on_axis_segment(point, left_start, left_finish) and _point_is_on_axis_segment(point, right_start, right_finish):
			return {"kind": "crossing", "point": point}
	if left_vertical and right_vertical and is_equal_approx(left_start.x, right_start.x):
		var overlap_start: float = maxf(minf(left_start.y, left_finish.y), minf(right_start.y, right_finish.y))
		var overlap_end: float = minf(maxf(left_start.y, left_finish.y), maxf(right_start.y, right_finish.y))
		if overlap_end - overlap_start > 0.5:
			return {"kind": "overlap", "point": Vector2(left_start.x, (overlap_start + overlap_end) * 0.5)}
	if left_horizontal and right_horizontal and is_equal_approx(left_start.y, right_start.y):
		var overlap_start: float = maxf(minf(left_start.x, left_finish.x), minf(right_start.x, right_finish.x))
		var overlap_end: float = minf(maxf(left_start.x, left_finish.x), maxf(right_start.x, right_finish.x))
		if overlap_end - overlap_start > 0.5:
			return {"kind": "overlap", "point": Vector2((overlap_start + overlap_end) * 0.5, left_start.y)}
	return {}

func _point_is_on_axis_segment(point: Vector2, start: Vector2, finish: Vector2) -> bool:
	const EPSILON: float = 0.01
	return (
		point.x >= minf(start.x, finish.x) - EPSILON
		and point.x <= maxf(start.x, finish.x) + EPSILON
		and point.y >= minf(start.y, finish.y) - EPSILON
		and point.y <= maxf(start.y, finish.y) + EPSILON
	)

func _link_points(source_id: String, target_id: String) -> PackedVector2Array:
	var source_port: Vector2 = _output_port(source_id, target_id)
	var target_port: Vector2 = _input_port(target_id, source_id)
	var output_lane: int = _output_lane_index(source_id, target_id)
	var input_lane: int = _input_lane_index(target_id, source_id)
	var source_stub := Vector2(
		source_port.x,
		_row_visual_edge(source_id, true) + LINK_ENDPOINT_EXPOSURE + float(maxi(0, output_lane)) * LINK_CHANNEL_SPACING
	)
	var target_stub := Vector2(
		target_port.x,
		_row_visual_edge(target_id, false) - LINK_ENDPOINT_EXPOSURE - float(maxi(0, input_lane)) * LINK_CHANNEL_SPACING
	)
	var link_key: String = "%s>%s" % [source_id, target_id]
	source_stub.y += float(LINK_SOURCE_STUB_OFFSETS.get(link_key, 0.0))
	target_stub.y += float(LINK_TARGET_STUB_OFFSETS.get(link_key, 0.0))
	if source_stub.y > target_stub.y:
		var midpoint_y: float = (source_port.y + target_port.y) * 0.5
		source_stub.y = midpoint_y
		target_stub.y = midpoint_y
	var channel_x: float = _best_route_channel_x(source_id, target_id, source_stub, target_stub)
	channel_x += float(LINK_CHANNEL_NUDGES.get(link_key, 0.0))
	return _simplified_points(PackedVector2Array([
		source_port,
		source_stub,
		Vector2(channel_x, source_stub.y),
		Vector2(channel_x, target_stub.y),
		target_stub,
		target_port,
	]))

func _row_visual_edge(skill_id: String, bottom: bool) -> float:
	var row_y: float = _node_center(skill_id).y
	var edge: float = _node_visual_rect(skill_id).end.y if bottom else _node_visual_rect(skill_id).position.y
	for candidate_id: String in SkillTreeLibrary.ordered_ids():
		if not is_equal_approx(_node_center(candidate_id).y, row_y):
			continue
		var candidate_rect: Rect2 = _node_visual_rect(candidate_id)
		edge = maxf(edge, candidate_rect.end.y) if bottom else minf(edge, candidate_rect.position.y)
	return edge

func _input_port(target_id: String, source_id: String) -> Vector2:
	var prerequisites: Array[String] = SkillTreeLibrary.prerequisites(target_id)
	_sort_ids_by_visual_x(prerequisites)
	var index: int = prerequisites.find(source_id)
	var offset_x: float = _distributed_port_offset(index, prerequisites.size(), 8.0)
	return _node_boundary_port(target_id, offset_x, false)

func _output_port(source_id: String, target_id: String) -> Vector2:
	var dependents: Array[String] = _direct_dependent_ids(source_id)
	_sort_ids_by_visual_x(dependents)
	var index: int = dependents.find(target_id)
	var offset_x: float = _distributed_port_offset(index, dependents.size(), 14.0)
	return _node_boundary_port(source_id, offset_x, true)

func _input_lane_index(target_id: String, source_id: String) -> int:
	var prerequisites: Array[String] = SkillTreeLibrary.prerequisites(target_id)
	_sort_ids_by_visual_x(prerequisites)
	return prerequisites.find(source_id)

func _output_lane_index(source_id: String, target_id: String) -> int:
	var dependents: Array[String] = _direct_dependent_ids(source_id)
	_sort_ids_by_visual_x(dependents)
	return dependents.find(target_id)

func _sort_ids_by_visual_x(skill_ids: Array[String]) -> void:
	skill_ids.sort_custom(func(left: String, right: String) -> bool:
		var left_center: Vector2 = _node_center(left)
		var right_center: Vector2 = _node_center(right)
		return left_center.x < right_center.x if not is_equal_approx(left_center.x, right_center.x) else left_center.y < right_center.y
	)

func _distributed_port_offset(index: int, count: int, maximum_offset: float) -> float:
	if count <= 1 or index < 0:
		return 0.0
	return lerpf(-maximum_offset, maximum_offset, float(index) / float(count - 1))

func _node_boundary_port(skill_id: String, offset_x: float, bottom: bool) -> Vector2:
	var center: Vector2 = _node_center(skill_id)
	var radius: float = minf(_node_size(skill_id).x, _node_size(skill_id).y) * 0.5 - 4.0
	var vertical_extent: float = radius
	match SkillTreeLibrary.tier(skill_id):
		"root":
			vertical_extent = sqrt(maxf(0.0, radius * radius - offset_x * offset_x))
		"junction":
			vertical_extent = maxf(0.0, radius - absf(offset_x))
		_:
			vertical_extent = radius
	return center + Vector2(offset_x, vertical_extent if bottom else -vertical_extent)

func _best_route_channel_x(
	source_id: String,
	target_id: String,
	source_stub: Vector2,
	target_stub: Vector2
) -> float:
	var preferred_x: float = (source_stub.x + target_stub.x) * 0.5
	var best_x: float = preferred_x
	var best_score: float = INF
	var obstacle_ranges: Array[Vector2] = _vertical_route_obstacle_ranges(
		source_stub.y,
		target_stub.y,
		source_id,
		target_id
	)
	var candidate_x: float = 12.0
	while candidate_x <= GRAPH_SIZE.x - 12.0:
		if _route_channel_is_clear(candidate_x, obstacle_ranges):
			var score: float = absf(candidate_x - preferred_x) + 0.18 * (
				absf(candidate_x - source_stub.x) + absf(candidate_x - target_stub.x)
			)
			if score < best_score:
				best_score = score
				best_x = candidate_x
		candidate_x += 4.0
	return best_x

func _vertical_route_obstacle_ranges(
	start_y: float,
	end_y: float,
	source_id: String,
	target_id: String
) -> Array[Vector2]:
	var result: Array[Vector2]
	var segment_start: float = minf(start_y, end_y)
	var segment_end: float = maxf(start_y, end_y)
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		if skill_id in [source_id, target_id]:
			continue
		var obstacle: Rect2 = _node_visual_rect(skill_id).grow(LINK_NODE_CLEARANCE)
		if segment_start > obstacle.end.y or segment_end < obstacle.position.y:
			continue
		result.append(Vector2(obstacle.position.x, obstacle.end.x))
	return result

func _route_channel_is_clear(x: float, obstacle_ranges: Array[Vector2]) -> bool:
	for obstacle_range: Vector2 in obstacle_ranges:
		if x >= obstacle_range.x and x <= obstacle_range.y:
			return false
	return true

func _simplified_points(points: PackedVector2Array) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point: Vector2 in points:
		if not result.is_empty() and result[result.size() - 1].is_equal_approx(point):
			continue
		if result.size() >= 2:
			var previous_direction: Vector2 = result[result.size() - 1] - result[result.size() - 2]
			var next_direction: Vector2 = point - result[result.size() - 1]
			if is_zero_approx(previous_direction.cross(next_direction)):
				result[result.size() - 1] = point
				continue
		result.append(point)
	return result

func _axis_segment_intersects_rect(start: Vector2, finish: Vector2, rect: Rect2) -> bool:
	if is_equal_approx(start.x, finish.x):
		return (
			start.x >= rect.position.x
			and start.x <= rect.end.x
			and maxf(minf(start.y, finish.y), rect.position.y) <= minf(maxf(start.y, finish.y), rect.end.y)
		)
	if is_equal_approx(start.y, finish.y):
		return (
			start.y >= rect.position.y
			and start.y <= rect.end.y
			and maxf(minf(start.x, finish.x), rect.position.x) <= minf(maxf(start.x, finish.x), rect.end.x)
		)
	return rect.intersects(Rect2(start, finish - start).abs())

func _panel_style(border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.042, 0.052, 0.97)
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

func _string_array(value: Variant) -> Array[String]:
	var result: Array[String]
	if typeof(value) != TYPE_ARRAY:
		return result
	for item: Variant in value as Array:
		result.append(str(item))
	return result
