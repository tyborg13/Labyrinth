extends RefCounted
const Renderer = preload("renderer.gd")
const Assets = preload("res://scripts/asset_loader.gd")
const META: StringName = &"emaciated_man_cutout_renderer"
const PREPARED_META: StringName = &"prepared_emaciated_man_cutout_renderer"

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
		renderer = board.get_meta(PREPARED_META, null) as Node if board.has_meta(PREPARED_META) else null
		board.remove_meta(PREPARED_META)
		if not is_instance_valid(renderer): renderer = _create_renderer(board, false)
		board.set_meta(META, renderer)
	renderer.present(float(board.get("_idle_elapsed")), bool((board.get("presentation") as Dictionary).get("reduced_motion", false)))

static func prepare_opening_for(board: Control, present: Callable, alive: Callable, trace_step: Callable) -> void:
	if board.has_meta(META) or board.has_meta(PREPARED_META): return
	await Assets.wait_for_preparation_slice(present, alive, &"opening_npc_renderer")
	if not bool(alive.call()): return
	var started: int = Time.get_ticks_usec()
	var span: RefCounted = trace_step.call("renderer_setup") if trace_step.is_valid() else null
	var renderer: Node = _create_renderer(board, true)
	# Board gear can build nameplates before sync(). Until adoption that
	# lookup must use its ordinary rest texture, not an undrawn viewport.
	board.set_meta(PREPARED_META, renderer)
	span = null
	Assets.count_preparation_work(started, &"opening_npc_renderer")
	var rig: Node = renderer.rig
	var loaded: bool = await rig.get_script().prepare_rig_for(rig, present, alive, trace_step)
	if not bool(alive.call()): return
	if not loaded: push_error("Emaciated Man cutout: " + str(rig.load_errors))
	await Assets.wait_for_preparation_slice(present, alive, &"opening_npc_initial_pose")
	if not bool(alive.call()): return
	started = Time.get_ticks_usec()
	span = trace_step.call("initial_pose") if trace_step.is_valid() else null
	renderer.present(0.0, false)
	span = null
	Assets.count_preparation_work(started, &"opening_npc_initial_pose")
	# sync() owns the actual board pose once the real board state is submitted.

static func _create_renderer(board: Control, staged: bool) -> Node:
	var renderer := Renderer.new()
	renderer.defer_rig_build = staged
	renderer.name = "EmaciatedManCutout"
	board.add_child(renderer)
	return renderer

static func advance(board: Control, elapsed: float) -> void:
	var renderer: Node = board.get_meta(META) as Node if board.has_meta(META) else null
	if is_instance_valid(renderer): renderer.present(elapsed, bool((board.get("presentation") as Dictionary).get("reduced_motion", false)))
