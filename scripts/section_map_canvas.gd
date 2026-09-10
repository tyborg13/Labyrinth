extends Control

const Graph = preload("res://scripts/section_map_graph.gd")
var state: Dictionary = {}
var positions: Dictionary = {}
var section_index: int = 0
var selected: Vector2i = Graph.INVALID

func _draw() -> void:
	if state.is_empty():
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
				var a: Vector2 = positions[source] + Vector2(_radius(node, source == current or immediate), 0)
				var b: Vector2 = positions[target] - Vector2(_radius(destination, immediate), 0)
				var curve := Curve2D.new()
				var reach: float = maxf(20, (b.x - a.x) * 0.52)
				curve.add_point(a, Vector2.ZERO, Vector2(reach, 0))
				curve.add_point(b, Vector2(-reach, 0), Vector2.ZERO)
				var points: PackedVector2Array = curve.get_baked_points()
				var color := Color("b29666") if traversed else Color("817d7e")
				if bypassed: color = Color(0.48, 0.46, 0.51, 0.46)
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
	if not bool(node.get("revealed", false)): return 33.0
	if str(node.get("type", "")) == "boss": return 58.0
	return 49.0 if prominent else 40.0

func _draw_dashed(curve: Curve2D, color: Color) -> void:
	var distance: float = 0
	while distance < curve.get_baked_length():
		var points := PackedVector2Array()
		for offset: int in range(0, 8, 2):
			points.append(curve.sample_baked(minf(distance + offset, curve.get_baked_length())))
		draw_polyline(points, color, 1.0, true)
		distance += 13
