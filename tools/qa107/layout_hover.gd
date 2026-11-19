extends RefCounted
## Query live tooltip hit regions, then move through Godot's GUI input pipeline.
## Coverage records distinguish a source that opened from a shadowed source and
## from a signal-connected affordance that produced no tooltip.

const Check = preload("res://tools/qa107/layout_geometry.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const TOOLTIP_SETTLE_SECONDS: float = 0.10
const HOVER_FRAMES: int = 3
const SAMPLE_FRACTIONS := [Vector2(0.5, 0.5), Vector2(0.2, 0.5), Vector2(0.8, 0.5),
	Vector2(0.5, 0.2), Vector2(0.5, 0.8), Vector2(0.2, 0.2), Vector2(0.8, 0.2),
	Vector2(0.2, 0.8), Vector2(0.8, 0.8)]
const CLEAR_POINTER := Vector2(-32, -32)

func visit(host: SceneTree, state: String, target: String, surface: Control = null) -> void:
	var scene: Node = host.scene
	var view: Window = host.root
	var scope: Node = surface if surface != null else scene
	var candidates: Dictionary = _candidates(scene, view, scope)
	var delay: float = float(ProjectSettings.get_setting("gui/timers/tooltip_delay_sec")) + TOOLTIP_SETTLE_SECONDS
	var outcomes := {"sources": candidates.size(), "opened": 0, "shadowed": 0, "no_popup": 0}
	for key: String in candidates:
		if not target.is_empty() and key != target: continue
		var candidate: Dictionary = candidates[key]
		_move(view, CLEAR_POINTER)
		await host.process_frame
		var source: Control = candidate.owner.get_ref()
		if not is_instance_valid(source) or not source.is_visible_in_tree():
			# Pointer previews rebuild some HUD rows. Resolve their stable key
			# against the new row before treating an original source as retired.
			var live: Dictionary = _candidates(scene, view, scope)
			if not live.has(key):
				outcomes["shadowed"] += 1
				_record(host, state, key, candidate, "retired")
				continue
			candidate = live[key]
			source = candidate.owner.get_ref()
		var before: Dictionary = _surfaces(scene)
		var reached: bool = false
		var selected: Vector2
		for point: Vector2 in candidate.points:
			_move(view, point)
			await host.process_frame
			var hit: Control = view.gui_get_hovered_control()
			if is_instance_valid(source) and (hit == source or (hit != null and source.is_ancestor_of(hit))):
				if hit != source and not hit.get_tooltip(hit.get_global_transform_with_canvas().affine_inverse() * point).is_empty():
					continue
				reached = true
				selected = point
				break
		if not reached:
			outcomes["shadowed"] += 1
			_record(host, state, key, candidate, "shadowed")
			continue
		if not str(candidate.trigger).is_empty(): await host.create_timer(delay, true, false, true).timeout
		else: await host.create_timer(TOOLTIP_SETTLE_SECONDS).timeout
		for frame: int in range(HOVER_FRAMES): await host.process_frame
		var after: Dictionary = _surfaces(scene)
		var opened: Array[Node]
		for popup: Node in after:
			if not before.has(popup) or before[popup] != after[popup]:
				opened.append(popup)
		if opened.is_empty():
			outcomes["no_popup"] += 1
			_record(host, state, key, candidate, "no_popup")
			continue
		outcomes["opened"] += 1
		var witness: Dictionary = _record(host, state, key, candidate, "opened", selected)
		await host.snapshot(state, key, witness, opened)
		if host.finished: break
	_move(view, CLEAR_POINTER)
	await host.process_frame
	outcomes["state"] = state
	host.record("hover_coverage", outcomes)

func _record(host: SceneTree, state: String, key: String, candidate: Dictionary, outcome: String, point: Vector2 = Vector2.INF) -> Dictionary:
	var row := {"state": state, "hover": key, "source_path": candidate.path, "trigger": candidate.trigger, "outcome": outcome}
	if point != Vector2.INF: row["point"] = [point.x, point.y]
	host.record("hover_attempt", row)
	return row

func _candidates(scene: Node, view: Window, scope: Node) -> Dictionary:
	var result: Dictionary = {}
	var viewport: Rect2 = view.get_visible_rect()
	for control: Control in Check.controls_below(scope):
		if not Check.painted(control) or control.mouse_filter == Control.MOUSE_FILTER_IGNORE: continue
		if control.get_window() != view: continue
		var visible: Rect2 = Check.bounds(control, view).intersection(Check.ancestor_clip(control, view, viewport))
		if not visible.has_area(): continue
		var script: Script = control.get_script()
		var dynamic: bool = false
		if script != null:
			dynamic = control.has_method("_get_tooltip")
		if not dynamic and control.tooltip_text.is_empty() and control.mouse_entered.get_connections().is_empty(): continue
		var source_path: String = Check.path(control, scene)
		var transform: Transform2D = control.get_global_transform_with_canvas()
		var inverse: Transform2D = transform.affine_inverse()
		var points: Array[Vector2]
		for fraction: Vector2 in SAMPLE_FRACTIONS: points.append(visible.position + visible.size * fraction)
		if control is CombatBoardView:
			_append_board_points(control, transform, points)
		elif control is CardWidget:
			_append_child_points(control, points)
		var found: Dictionary = {}
		for point: Vector2 in points:
			if not visible.has_point(point): continue
			var tooltip: String = control.get_tooltip(inverse * point)
			if tooltip.is_empty() and control.mouse_entered.get_connections().is_empty(): continue
			if not found.has(tooltip): found[tooltip] = []
			if not found[tooltip].has(point): found[tooltip].append(point)
		for trigger: String in found:
			# The trigger disambiguates positions along one board or card. The
			# relative path keeps a replay independent of generated Node names.
			var key: String = (source_path + "\n" + trigger).sha256_text().left(12)
			result[key] = {"owner": weakref(control), "path": source_path, "trigger": trigger, "points": found[trigger]}
	return result

func _append_child_points(card: Control, points: Array[Vector2]) -> void:
	for child: Control in Check.controls_below(card):
		if child == card: continue
		if child is TextureRect or not child.tooltip_text.is_empty():
			points.append(Check.bounds(child, card.get_window()).get_center())

func _append_board_points(board: CombatBoardView, transform: Transform2D, points: Array[Vector2]) -> void:
	var layers: Array = board.call("_retained_render_layers").duplicate(false)
	layers.append(board)
	for layer: Control in layers:
		for region: Dictionary in layer.get("_tooltip_regions"):
			points.append(transform * (region["rect"] as Rect2).get_center())
	var plates: RefCounted = board.get("plate_visibility")
	for unit: Dictionary in plates.call("actors"):
		for entry: Dictionary in plates.call("status_entries", unit):
			points.append(transform * (entry["rect"] as Rect2).get_center())
	var grid: Array = board.combat_state.get("grid", [])
	for y: int in range(grid.size()):
		for x: int in range((grid[y] as Array).size()):
			points.append(transform * Vector2(board.call("_tile_center", Vector2i(x, y))))
	for loot: Dictionary in board.combat_state.get("loot", []):
		var texture: Texture2D = board.call("_loot_texture", loot)
		if texture != null:
			var rect: Rect2 = board.call("_loot_rect_for_tile", loot.get("pos", Vector2i(-1, -1)), texture, loot)
			points.append(transform * rect.get_center())

func _move(view: Window, point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	view.push_input(motion, true)

func _surfaces(scene: Node) -> Dictionary:
	var result: Dictionary = {}
	_collect_surfaces(scene.get_window(), result)
	return result

func _collect_surfaces(node: Node, result: Dictionary) -> void:
	if node is Window and not node.visible: return
	if node is SubViewport: return
	if node is CanvasItem and not node.is_visible_in_tree(): return
	if node is Window and node.theme_type_variation == &"TooltipPanel":
		result[node] = node.get_child_count(true)
		return
	if node is Stack:
		if node.entry_count() > 0:
			var owner: Control = node.get("_follow_target")
			var owner_id: int = owner.get_instance_id() if is_instance_valid(owner) else 0
			result[node] = [owner_id, node.entry_count(), node.entry_icon_keys()]
		return
	if node is Control and node.has_meta("tooltip_surface"):
		result[node] = node.get_child_count()
		return
	for child: Node in node.get_children(true): _collect_surfaces(child, result)
