extends RefCounted
const Renderer = preload("renderer.gd")
const META: StringName = &"emaciated_man_cutout_renderer"

static func uses_waypoint_room_fit(state: Dictionary) -> bool:
	# The combat hand is hidden here; its measured top can be only ten pixels.
	# Reuse the established room rectangle instead of shrinking the actors to
	# the resulting two-pixel hand budget. No other room or combat fit changes.
	return str(state.get("mode", "")) == "room" and state.get("current_room", Vector2i(-1, -1)) == Vector2i.ZERO

static func handles(unit: Dictionary) -> bool:
	return str(unit.get("type", "")) == "emaciated_man"

static func renderer_for_unit(board: Control, unit: Dictionary) -> Node:
	if not handles(unit): return null
	var owner: Node = board.get("_render_instrumentation_owner") as Node
	var host: Node = owner if is_instance_valid(owner) else board
	return host.get_meta(META) as Node if host.has_meta(META) else null

static func sync(board: Control) -> void:
	if bool(board.get("_is_dynamic_render_layer")) or bool(board.get("_is_static_render_cache_layer")) or not board.is_inside_tree(): return
	var present: bool = false
	for npc: Dictionary in (board.get("combat_state") as Dictionary).get("npcs", []):
		if str(npc.get("id", "")) == "emaciated_man": present = true
	var renderer: Node = board.get_meta(META) as Node if board.has_meta(META) else null
	if not present:
		if is_instance_valid(renderer): renderer.queue_free()
		board.remove_meta(META)
		return
	if not is_instance_valid(renderer):
		renderer = Renderer.new()
		renderer.name = "EmaciatedManCutout"
		board.add_child(renderer)
		board.set_meta(META, renderer)
	renderer.present(float(board.get("_idle_elapsed")), bool((board.get("presentation") as Dictionary).get("reduced_motion", false)))

static func advance(board: Control, elapsed: float) -> void:
	var renderer: Node = board.get_meta(META) as Node if board.has_meta(META) else null
	if is_instance_valid(renderer): renderer.present(elapsed, bool((board.get("presentation") as Dictionary).get("reduced_motion", false)))
