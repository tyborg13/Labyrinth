extends RefCounted
## The combat HUD's compact right column and bottom Pass/pile dock.
const Layout = preload("res://scripts/turn_order_layout.gd")
const Slots = preload("res://scripts/turn_order_slots.gd")
var plan: Dictionary = {}
var _entries: Array[Dictionary]
var _placing: bool = false
var _signature: String = ""
const BOTTOM_DOCK_GAP: float = 10.0
const TOP_BAR_GAP: float = 12.0

func clear() -> void:
	_entries.clear()
	_signature = ""
	plan.clear()

func present(scene: Control, entries: Array[Dictionary]) -> void:
	_entries = scene._turn_order_array(entries)
	if entries.is_empty():
		scene._clear_children(scene._turn_order_bar)
		scene._set_turn_order_visible(false)
		_signature = ""
	else:
		scene._layout_turn_order_anchor()

func layout(scene: Control) -> void:
	if _placing or _entries.is_empty() or scene._turn_order_panel == null or str(scene._run_state.get("mode", "")) != "combat":
		return
	var pass_overlay: Control = scene._pass_preview_overlay
	_placing = true
	var piles: Rect2 = scene.draw_pile.get_global_rect().merge(scene.discard_pile.get_global_rect())
	# Pass may still be hidden while the opening hand is being fitted. Its
	# visibility is not a prerequisite for the initiative rail. Measure the same
	# Layout C dock from the piles and Pass's available geometry instead.
	var pass_size: Vector2 = pass_overlay.size.max(pass_overlay.get_combined_minimum_size()) if pass_overlay != null else Vector2.ZERO
	var pass_top: float = piles.position.y - pass_size.y - BOTTOM_DOCK_GAP
	if pass_overlay != null:
		pass_overlay.global_position = Vector2(piles.end.x - pass_size.x, pass_top)
	var root_origin: Vector2 = scene.ui_root.global_position
	# Always measure the live header; never feed the anchor's old position
	# back into layout after a container sort or a held-hand layout callback.
	var header_bottom: float = top(scene)
	var bottom: float = pass_top - root_origin.y - Layout.DETAILS_PASS_GAP
	var total_height: float = maxf(0.0, bottom - header_bottom)
	var available_height: float = maxf(0.0, total_height - scene.ENEMY_INTENT_TOGGLE_HEIGHT - scene.ENEMY_INTENT_TOGGLE_TOP_GAP)
	plan = Layout.solve(scene, _entries.size(), available_height)
	var rail_height: float = float(plan.height)
	total_height = rail_height + scene.ENEMY_INTENT_TOGGLE_TOP_GAP + scene.ENEMY_INTENT_TOGGLE_HEIGHT
	bottom = header_bottom + total_height
	var width: float = float(plan.width)
	var anchor: Control = scene._turn_order_anchor
	anchor.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	anchor.offset_left = -width - scene.TURN_ORDER_RAIL_EDGE_GAP
	anchor.offset_right = -scene.TURN_ORDER_RAIL_EDGE_GAP
	anchor.offset_top = header_bottom
	anchor.offset_bottom = bottom
	anchor.size = Vector2(width, total_height)
	anchor.visible = true
	var panel: Control = scene._turn_order_panel
	panel.custom_minimum_size = Vector2(width, total_height)
	panel.size = panel.custom_minimum_size
	panel.visible = true
	scene._turn_order_header_host.custom_minimum_size = Vector2(width, 0.0)
	var bar: Control = scene._turn_order_bar
	bar.custom_minimum_size = Vector2(width, rail_height)
	bar.size = bar.custom_minimum_size
	# Includes transient insertion/reflow/defeat paint: the rail cannot draw
	# above the header or underneath Details/Pass during production tweens.
	bar.clip_contents = true
	var details: Button = scene._enemy_intent_toggle_button
	var margin: MarginContainer = details.get_parent() as MarginContainer
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size.x = width
	details.set_rail_docked(true)
	var visible: Array[Dictionary]
	for index: int in range(int(plan.visible)): visible.append(_entries[index])
	var overflow_entries: Array[Dictionary]
	for index: int in range(visible.size(), _entries.size()): overflow_entries.append(_entries[index])
	var signature: String = scene._turn_order_signature(_entries) + str(plan) + str(rail_height)
	if signature != _signature:
		_signature = signature
		# Geometry participates in retention, so resize/scale refreshes redraw the
		# portrait mask, health bar and brush without changing the control's input.
		Slots.reconcile(scene, visible)
		if not overflow_entries.is_empty():
			var overflow: Control = Slots.overflow(scene, overflow_entries, visible.size())
			bar.add_child(overflow)
		for slot: Control in bar.get_children():
			var badge: Control = slot.find_child("ProjectionPreviewBadge", true, false) as Control
			if badge != null: badge.position.x = width - Layout.PROJECTION_WIDTH - slot.position.x
		scene._turn_order_rendered_entries = scene._turn_order_array(_entries)
		scene._turn_order_render_signature = "%s|overflow:%s" % [scene._turn_order_signature(_entries), scene._turn_order_signature(overflow_entries)]
	_placing = false

func slot_size(scene: Node, index: int) -> Vector2:
	var sizes: Array = plan.get("sizes", [])
	return sizes[index] if index < sizes.size() else Layout.baseline_size(scene, index)

func slot_position(index: int) -> Vector2:
	var positions: Array = plan.get("positions", [])
	return positions[index] if index < positions.size() else Vector2.ZERO

static func top(scene: Control) -> float:
	var header_bottom: float = scene.ui_root.global_position.y
	if scene.top_bar != null: header_bottom = maxf(header_bottom, scene.top_bar.get_global_rect().end.y)
	header_bottom = maxf(header_bottom, scene._utility_stack_visible_bottom())
	return header_bottom - scene.ui_root.global_position.y + TOP_BAR_GAP
