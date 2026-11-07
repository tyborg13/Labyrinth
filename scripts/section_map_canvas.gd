extends Control

const Graph = preload("res://scripts/section_map_graph.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const MapSkin = preload("res://scripts/section_map_skin.gd")
const InkCache = preload("res://scripts/section_map_ink_cache.gd")
var state: Dictionary = {}
var positions: Dictionary = {}
var radii: Dictionary = {}
var section_index: int = 0
var selected: Vector2i = Graph.INVALID
# Consecutive dots share one native triangle upload. The helper preserves
# Godot's circle fan, float colours and original paint order; AA rails remain
# native flush boundaries. Static fans are retained per link and layer, and
# ordered submissions reuse those exact arrays on unchanged draws.
var _dot_batch := preload("res://scripts/section_map_ink_batch.gd").new()
var _ink_cache := InkCache.new()
# Revision 7 (map-03): inked dot trails, ground shadows and the lantern's walk.
var ink: bool = false
var travel_from: Vector2i = Graph.INVALID
var travel_to: Vector2i = Graph.INVALID
var travel_progress: float = 0.0
# Trail styles, back to front: [dot spacing, dot radius, colour, halo alpha].
const INK_BYPASSED: Array = [15.0, 2.0, Palette.TEXT_3, 0.28, 0.5]
const INK_AHEAD: Array = [13.0, 2.7, Palette.TEXT_2, 0.58, 0.92]
const INK_PLANNED: Array = [12.0, 3.0, Palette.GOLD, 0.6, 0.96]
const INK_CHOICE: Array = [11.0, 3.6, Palette.GOLD_BRIGHT, 0.63, 1.0]
const INK_CHOSEN: Array = [10.0, 4.2, Palette.GOLD_BRIGHT, 0.7, 1.0]
const INK_HALO: float = 1.6
const INK_WALKED_WIDTH: float = 4.0
const INK_TOKEN_RADIUS: float = 34.0
const INK_TOKEN_STEPS: float = 4.0
const INK_TOKEN_HOP: float = 3.0

func _draw() -> void:
	if state.is_empty():
		return
	if ink:
		_draw_ink()
		return
	var current: Vector2i = state.get("current_room", Graph.INVALID)
	var future: Dictionary = Graph.descendants(state, current)
	var planned: Dictionary = Graph.descendants(state, selected) if future.has(selected) else {}
	# Paint faint paths first so the immediate decision stays legible at crossings.
	for foreground: bool in [false, true]:
		for source: Vector2i in positions:
			var node: Dictionary = Graph.room(state, source)
			for link: Dictionary in node.get("connections", []):
				var target: Vector2i = link.get("coord", Graph.INVALID)
				if not positions.has(target):
					continue
				var immediate: bool = source == current
				if immediate != foreground:
					continue
				var destination: Dictionary = Graph.room(state, target)
				var traversed: bool = bool(node.get("visited", false)) and bool(destination.get("visited", false))
				var bypassed: bool = not traversed and (not future.has(source) or not future.has(target))
				var chosen: bool = immediate and target == selected
				var ahead: bool = planned.has(source) and planned.has(target)
				var a: Vector2 = positions[source] + Vector2(float(radii.get(source, _radius(node, source == current or immediate))), 0)
				var b: Vector2 = positions[target] - Vector2(float(radii.get(target, _radius(destination, immediate))), 0)
				var curve := Curve2D.new()
				var reach: float = maxf(20, (b.x - a.x) * 0.52)
				curve.add_point(a, Vector2.ZERO, Vector2(reach, 0))
				curve.add_point(b, Vector2(-reach, 0), Vector2.ZERO)
				var points: PackedVector2Array = curve.get_baked_points()
				var color := Color("b29666") if traversed else Color("595661")
				if bypassed: color = Color(0.36, 0.34, 0.41, 0.34)
				if ahead: color = Color("a18e6a")
				if immediate: color = Color("e9ce97") if chosen else Color("b9a783")
				if bypassed:
					_draw_dashed(curve, color)
				else:
					draw_polyline(points, Color(0.025, 0.021, 0.03, 0.50), 5 if immediate else 3.5, true)
					draw_polyline(points, color, 2.5 if chosen else (2.0 if immediate else 1.5), true)
				# Only exits need a direction cue. Sample the curve's actual tangent.
				if immediate:
					var middle: float = curve.get_baked_length() * 0.56
					var point: Vector2 = curve.sample_baked(middle)
					var tangent: Vector2 = (curve.sample_baked(middle + 2) - curve.sample_baked(middle - 2)).normalized()
					draw_colored_polygon(PackedVector2Array([point + tangent * 5, point - tangent * 4 + tangent.orthogonal() * 3.5, point - tangent * 4 - tangent.orthogonal() * 3.5]), color)

func _radius(node: Dictionary, prominent: bool) -> float:
	if str(node.get("type", "")) == "boss": return 91.0
	if str(node.get("type", "")) == "guardian": return 71.0 if prominent else 46.0
	if prominent: return 52.0
	return 42.0 if bool(node.get("visited", false)) else 31.0

func _draw_dashed(curve: Curve2D, color: Color) -> void:
	var distance: float = 0
	while distance < curve.get_baked_length():
		var points := PackedVector2Array()
		for offset: int in range(0, 8, 2):
			points.append(curve.sample_baked(minf(distance + offset, curve.get_baked_length())))
		draw_polyline(points, color, 1.0, true)
		distance += 13

func _trail(a: Vector2, b: Vector2) -> Curve2D:
	return InkCache.make_trail(a, b)

func _draw_ink() -> void:
	var layers: Dictionary = _ink_cache.layers_for(state, positions, section_index, selected)
	_dot_batch.begin_draw(layers, section_index)
	for coord: Vector2i in positions:
		_draw_ground_shadow(positions[coord], float(radii.get(coord, 37.0)) - 6.0)
	for kind: String in ["bypassed", "ahead", "planned", "walked", "choice", "chosen"]:
		for pair: Array in layers[kind]:
			var source: Vector2i = pair[0]
			var target: Vector2i = pair[1]
			var trail: Dictionary = _ink_cache.trail_for(source, target, positions, radii)
			var points: PackedVector2Array = trail["points"]
			if kind == "walked":
				_dot_batch.flush(self)
				draw_polyline(points, Color(Palette.INK_0, 0.66), INK_WALKED_WIDTH * 2.0, true)
				draw_polyline(points, Palette.GOLD, INK_WALKED_WIDTH, true)
				continue
			if kind in ["choice", "chosen"]:
				_dot_batch.flush(self)
				# A soft ember glow under your next choices.
				draw_polyline(points, Color(Palette.EMBER, 0.08 if kind == "choice" else 0.14), 20.0, true)
				draw_polyline(points, Color(Palette.EMBER, 0.14 if kind == "choice" else 0.22), 10.0, true)
			var style: Array = {"bypassed": INK_BYPASSED, "ahead": INK_AHEAD, "planned": INK_PLANNED, "choice": INK_CHOICE, "chosen": INK_CHOSEN}[kind]
			_draw_dots(pair, kind, trail, style)
	_dot_batch.flush(self)
	_dot_batch.end_draw()

func _draw_dots(pair: Array, kind: String, trail: Dictionary, style: Array) -> void:
	_dot_batch.append_trail(pair, kind, trail["points"], trail["curve"], style, INK_HALO, Palette.INK_0)

func _draw_ground_shadow(center: Vector2, radius: float) -> void:
	# Seats each room on the painting: a soft, flattened pool under it.
	draw_set_transform(center + Vector2(0, radius * 0.66), 0.0, Vector2(1.0, 0.34))
	draw_circle(Vector2.ZERO, radius * 1.22, Color(Palette.INK_0, 0.16))
	draw_circle(Vector2.ZERO, radius * 1.02, Color(Palette.INK_0, 0.22))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

# The lantern walks above the rooms, so it visibly leaves one and reaches the next.
func draw_lantern_token(layer: CanvasItem) -> void:
	if travel_progress <= 0.0 or not positions.has(travel_from) or not positions.has(travel_to): return
	var curve: Curve2D = _trail(positions[travel_from], positions[travel_to])
	var eased: float = ease(clampf(travel_progress, 0.0, 1.0), -1.8)
	var point: Vector2 = curve.sample_baked(curve.get_baked_length() * eased)
	# A small hop on each step of the walk.
	point.y -= absf(sin(eased * PI * INK_TOKEN_STEPS)) * INK_TOKEN_HOP
	layer.draw_circle(point, INK_TOKEN_RADIUS + 12.0, Color(Palette.EMBER, 0.14))
	layer.draw_circle(point, INK_TOKEN_RADIUS * 0.74, Palette.INK_0)
	MapSkin.draw_medallion(layer, point, INK_TOKEN_RADIUS, MapSkin.icon_texture("start"))
