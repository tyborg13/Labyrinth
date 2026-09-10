extends Control

const Typography = preload("res://scripts/ui_typography.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
var state: Dictionary = {}
var positions: Dictionary = {}
var section_index: int = 0
var selected: Vector2i = Graph.INVALID

func _draw() -> void:
	if state.is_empty():
		return
	var reachable: Dictionary = Graph.descendants(state, selected) if selected != Graph.INVALID else {}
	for source: Vector2i in positions:
		var node: Dictionary = Graph.room(state, source)
		for link: Dictionary in node.get("connections", []):
			var target: Vector2i = link.get("coord", Graph.INVALID)
			if not positions.has(target):
				continue
			var a: Vector2 = positions[source]
			var b: Vector2 = positions[target]
			var direction: Vector2 = (b - a).normalized()
			a += direction * 45
			b -= direction * 45
			var curve := Curve2D.new()
			var reach: float = maxf(20, (b.x - a.x) * 0.45)
			curve.add_point(a, Vector2.ZERO, Vector2(reach, 0))
			curve.add_point(b, Vector2(-reach, 0), Vector2.ZERO)
			var points: PackedVector2Array = curve.get_baked_points()
			var traversed: bool = bool(node.get("visited", false)) and bool(Graph.room(state, target).get("visited", false))
			var planned: bool = (source == state.get("current_room", Graph.INVALID) and target == selected) or (reachable.has(source) and reachable.has(target))
			var color := Color("d5ad60") if traversed or planned else Color("80756c")
			draw_polyline(points, Color(0.018, 0.013, 0.022, 0.94), 8, true)
			draw_polyline(points, color, 3 if traversed or planned else 2, true)
			var arrow: Vector2 = b - direction * 8
			draw_polyline(PackedVector2Array([arrow + direction.orthogonal() * 5, b, arrow - direction.orthogonal() * 5]), color, 2, true)
