extends RefCounted

## Inspection and isolation share one target and one return tween per slot.
const UiPalette = preload("res://scripts/ui_palette.gd")

static func apply(frame: Control, visibility: RefCounted) -> void:
	var edge: Control = frame.get_node_or_null("TurnOrderSlashEdge")
	if edge == null: return
	var inspected: bool = visibility.inspected(str(frame.get_meta("rd05_actor_key", ""))) or bool(frame.get_meta("threat_isolation_hovered", false))
	var target: Color = UiPalette.GOLD_BRIGHT if inspected else frame.get_meta("rd07_resting_edge", edge.get("color"))
	if frame.get_meta("rd07_edge_target", Color.TRANSPARENT) == target: return
	frame.set_meta("rd07_edge_target", target)
	var previous: Tween = frame.get_meta("rd07_edge_tween") as Tween if frame.has_meta("rd07_edge_tween") else null
	if previous != null and previous.is_valid(): previous.kill()
	if inspected or not frame.is_inside_tree():
		_set_edge_color(edge, target)
	else:
		var motion: Tween = frame.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		motion.tween_method(func(color: Color) -> void: _set_edge_color(edge, color), edge.get("color"), target, 0.12)
		frame.set_meta("rd07_edge_tween", motion)
		edge.set_meta("rd04_rail_tween", motion)

static func _set_edge_color(edge: Control, color: Color) -> void:
	edge.set("color", color)
	edge.queue_redraw()
