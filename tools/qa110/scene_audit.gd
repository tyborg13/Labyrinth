extends RefCounted
## Inspect owners and retained drawing inputs without refreshing the scene.

const INVALID := Vector2i(-1, -1)
const ALPHA_MIN: float = 0.02
const ALPHA_MAX: float = 0.98
const Cards = preload("res://scripts/card_widget.gd")
const TooltipButton = preload("res://scripts/ui_tooltip_button.gd")
const TooltipStack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Highlight = preload("res://scripts/targeted_tile_highlight.gd")

static func presentation(scene: Node, board: Control, selected: bool, checks: Dictionary) -> Dictionary:
	var shown: Dictionary = board.presentation
	var viewport: Viewport = scene.get_viewport()
	var pointer: Control = viewport.gui_get_hovered_control()
	var focus: Control = viewport.gui_get_focus_owner()
	var controller: bool = scene._controller_is_active()
	var expected_tile: Vector2i = scene._controller_board_tile if controller else INVALID
	if not controller and owned_by(board, pointer):
		# Viewport.push_input changes GUI hover without warping the OS cursor.
		# Sample the last real/injected pointer event, independent of board state.
		var event_point: Vector2 = scene._hand_pointer_position if scene._hand_pointer_position_valid else viewport.get_mouse_position()
		var point: Vector2 = board.get_global_transform_with_canvas().affine_inverse() * event_point
		expected_tile = board._tile_at_point(point)
	var ring: Vector2i = board._controller_focus_tile if controller else board._hover_tile
	checks["hover_ring"] = []
	if ring.x >= 0 and ring != expected_tile:
		checks["hover_ring"].append({"kind": "tile_owner", "actual": ring, "expected": expected_tile})
	var highlight: Node2D = board._targeted_tile_highlight
	var raised: Node2D = board._targeted_tile_threat
	for node: Node2D in [highlight, raised]:
		if is_instance_valid(node) and node.is_visible_in_tree() and node.tile != expected_tile:
			checks["hover_ring"].append({"kind": "raised_tile", "node": str(node.name), "actual": node.tile, "expected": expected_tile})

	checks["targeting"] = []
	if not selected:
		var retained: Dictionary = {}
		if bool(shown.get("board_targeting", false)) or board._aim_focus.active:
			retained["board_targeting"] = true
		if is_instance_valid(scene._drag_target_arrow) and scene._drag_target_arrow.is_visible_in_tree():
			retained["aim_arrow"] = path_of(scene._drag_target_arrow)
		if is_instance_valid(highlight) and highlight.is_visible_in_tree():
			retained["outline"] = highlight.tile
		if is_instance_valid(scene._drag_card_proxy) and scene._drag_card_proxy.is_visible_in_tree():
			retained["drag_proxy"] = str(scene._drag_card_proxy.get_path())
		# Unfurled foe intent can intentionally present a ghost and path. Check
		# these against the tile/rail owner before treating them as stale aim.
		var foe_owned: bool = expected_tile.x >= 0 and shown.get("hover_owner_tile", INVALID) == expected_tile and not shown.get("enemy_threat_previews", []).is_empty()
		if not scene._turn_order_hovered_enemy_key.is_empty():
			foe_owned = foe_owned or (pointer != null and owned_by(scene._turn_order_bar, pointer))
		for key: String in ["path_tiles", "preview_units"]:
			if not foe_owned and not shown.get(key, []).is_empty(): retained[key] = shown[key]
		if not foe_owned and (shown.get("projected_destination", INVALID) as Vector2i).x >= 0:
			retained["destination"] = shown["projected_destination"]
		if not foe_owned and not board._projected_destination_tiles_lookup_cache.is_empty():
			retained["destination_cache"] = board._projected_destination_tiles_lookup_cache.keys()
		if not retained.is_empty(): checks["targeting"].append({"kind": "unowned_aim", "retained": retained})

	checks["tooltip"] = []
	checks["alpha"] = []
	var exclusions: Dictionary = {}
	var surfaces: Array[Node] = Array([], TYPE_OBJECT, &"Node", null)
	append_tree(board, surfaces)
	retained_hover(board, surfaces, expected_tile, checks["hover_ring"])
	append_tree(scene.get_node("UiLayer"), surfaces)
	var reveal: Node = board.get("_occlusion_reveal")
	var popup_owners: Dictionary = {}
	for node: Node in surfaces:
		if node is TooltipButton and node._active_tooltip != null:
			var panel: Object = node._active_tooltip.get_ref()
			if is_instance_valid(panel) and panel.get_parent() is Window:
				popup_owners[panel.get_parent()] = node
	for node: Node in surfaces:
		if node is CanvasItem and node.is_visible_in_tree():
			check_alpha(node, "modulate", node.modulate.a, selected, checks["alpha"], exclusions, reveal, expected_tile)
			check_alpha(node, "self_modulate", node.self_modulate.a, selected, checks["alpha"], exclusions)
			if node is TooltipStack and not stack_owned(scene, node._follow_target, pointer, focus):
				checks["tooltip"].append({"kind": "keyword_stack", "node": str(node.get_path()), "owner": path_of(node._follow_target)})
		if node is Window and node.visible and node.theme_type_variation == &"TooltipPanel":
			var owner: Control = popup_owners.get(node)
			# Godot's plain/custom non-UiTooltipButton popup is parented to its
			# originating Control. Some engine versions use the viewport instead.
			if owner == null: owner = node.get_parent() as Control
			if not owned_by(owner, pointer) and not owned_by(owner, focus):
				checks["tooltip"].append({"kind": "native_popup", "node": str(node.get_path()), "owner": path_of(owner)})
	var landing: Control = scene._turn_order_landing_strip
	if is_instance_valid(landing) and landing.is_visible_in_tree() and not stack_owned(scene, landing._target, pointer, focus) and not selected:
		checks["tooltip"].append({"kind": "card_landing_preview", "node": path_of(landing), "owner": path_of(landing._target)})
	var anchored: Control = scene._controller_loadout_tooltip
	if is_instance_valid(anchored) and anchored.is_visible_in_tree() and not owned_by(scene._controller_loadout_tooltip_anchor, focus):
		checks["tooltip"].append({"kind": "loadout_popup", "node": path_of(anchored), "owner": path_of(scene._controller_loadout_tooltip_anchor)})
	var pass_panel: Control = scene.find_child("PassForecastFocusTooltip", true, false)
	if is_instance_valid(pass_panel) and pass_panel.is_visible_in_tree() and pass_panel.modulate.a > ALPHA_MIN:
		var chip: Control = pass_panel.get_parent()
		if not owned_by(chip, pointer) and not owned_by(chip, focus) and not (selected and bool(chip.get_meta("pass_action_preview", false))):
			checks["tooltip"].append({"kind": "pass_panel", "node": str(pass_panel.get_path()), "owner": path_of(chip)})
	for callout: Dictionary in shown.get("intent_callouts", []):
		checks["tooltip"].append({"kind": "settled_callout", "callout": callout})
	return {"pointer": path_of(pointer), "focus": path_of(focus), "expected_tile": expected_tile, "board_hover": ring,
		"selected": selected, "hand_index": scene._hovered_card_index, "drag_index": scene._drag_card_index,
		"turn": scene._combat_state.get("turn", -1), "alpha_exclusions": exclusions}

static func retained_hover(board: Control, board_nodes: Array[Node], expected: Vector2i, issues: Array) -> void:
	var tiles: Dictionary = {}
	for node: Node in board_nodes:
		if node.get_script() != board.get_script() or not node._is_layer_slice_canvas or not node.is_visible_in_tree(): continue
		for op: Array in node._render_slice_ops:
			var args: Array = op[1]
			if op[0] == "draw_colored_polygon" and args[1] == board.HOVER_HIGHLIGHT:
				var points: PackedVector2Array = args[0]
				if points.size() != 4: continue
				var tile: Vector2i = board._tile_at_point((points[0] + points[2]) * 0.5)
				if tile.x >= 0 and tile != expected: tiles[tile] = true
			elif op[0] == "_draw_controller_door_chevron" and args[0] != expected:
				tiles[args[0]] = true
	if not tiles.is_empty():
		issues.append({"kind": "retained_hover", "actual": tiles.keys(), "expected": expected})

static func stack_owned(scene: Node, owner: Control, pointer: Control, focus: Control) -> bool:
	if owned_by(owner, pointer) or owned_by(owner, focus): return true
	if not is_instance_valid(owner): return false
	if scene._controller_is_active():
		return scene._controller_hand_focused and scene._controller_region == "hand" and scene._hand_card_control(scene._controller_hand_index) == owner
	# A hand relayout deliberately resolves from event geometry before Godot's
	# cached hovered control changes. Compare the current hit-tested card.
	return scene._hand_pointer_position_valid and scene._hand_pointer_hover_allowed() and scene._hand_card_control(scene._hand_index_under_pointer()) == owner

static func owned_by(owner: Node, candidate: Node) -> bool:
	return is_instance_valid(owner) and is_instance_valid(candidate) and (owner == candidate or owner.is_ancestor_of(candidate))

static func path_of(node: Node) -> String:
	return str(node.get_path()) if is_instance_valid(node) and node.is_inside_tree() else ""

static func check_alpha(node: CanvasItem, field: String, alpha: float, selected: bool, issues: Array, exclusions: Dictionary,
	reveal: Node = null, expected_tile: Vector2i = INVALID) -> void:
	if alpha < ALPHA_MIN or alpha > ALPHA_MAX: return
	var source: String = authored_alpha(node, field, alpha, selected)
	if field == "modulate" and is_instance_valid(reveal) and expected_tile.x >= 0 and reveal.focus_tile == expected_tile and is_equal_approx(alpha, reveal.REVEAL_ALPHA):
		var parent_name: String = str(node.get_parent().name)
		if parent_name.begins_with("UnitBody_") and bool(reveal.targets.get("unit:" + parent_name.trim_prefix("UnitBody_"), {}).get("on", false)):
			source = "scripts/board_occlusion_reveal.gd::_apply"
	if field == "modulate" and node.has_meta("rd04_alpha") and is_equal_approx(alpha, float(node.get_meta("rd04_alpha"))):
		source = "scripts/board_threat_isolation.gd::_apply_alpha"
	if field == "self_modulate" and selected and node.has_meta("rd03_target") and is_equal_approx(alpha, (node.get_meta("rd03_target") as Color).a):
		source = "scripts/board_aim_focus.gd::_present"
	if not source.is_empty():
		exclusions["%s/%s" % [node.name, field]] = {"source": source, "alpha": alpha}
		return
	var receipt: Dictionary = {"kind": "partial_alpha", "node": str(node.get_path()), "field": field, "alpha": alpha}
	for key: String in ["rd04_alpha", "rd03_target", "threat_actor_keys"]:
		if node.has_meta(key): receipt[key] = node.get_meta(key)
	issues.append(receipt)

static func authored_alpha(node: CanvasItem, field: String, alpha: float, selected: bool) -> String:
	if node is Highlight and selected and bool(node._context.get("active", false)):
		if field == "self_modulate" and alpha >= Highlight.PULSE_MIN:
			return "scripts/targeted_tile_highlight.gd::_update_pulse"
		if field == "modulate" and is_equal_approx(alpha, node.tone_color.a):
			return "scripts/targeted_tile_highlight.gd::present"
	if field == "self_modulate":
		if node.name == &"ArtShadow" and is_equal_approx(alpha, 0.42):
			return "scripts/card_widget.gd::_ensure_art_shadow"
		return ""
	var pulse: Node = node.get_node_or_null("CombatPreviewPulse")
	if selected and is_instance_valid(pulse) and pulse._active and alpha >= pulse._base_alpha * 0.52 and alpha <= pulse._base_alpha * 0.74:
		return "scripts/combat_preview_pulse.gd::CanvasPulse"
	if node is Cards and (
		(not node._usable and is_equal_approx(alpha, 0.56))
		or (node._usable and node._dimmed and is_equal_approx(alpha, 0.72))
		or (node._usable and not node._dimmed and not node._printed_playable and is_equal_approx(alpha, 0.90))
	):
		return "scripts/card_widget.gd::_apply_interaction_configuration"
	if node.name in [&"TurnOrderBrushBacking", &"LandingStripBrush"] and matches(alpha, [0.90, 0.95, 0.648]):
		return "scripts/turn_order_slots.gd::update and scripts/turn_order_ink.gd::ink_color"
	var parent: Node = node.get_parent()
	if node.name == &"LandingStripPortrait" and matches(alpha, [0.74, 0.94, 0.98]):
		return "scripts/turn_order_landing_strip.gd"
	if (parent.name == &"TurnOrderPortraitCrop" or str(parent.name).begins_with("OverflowPortraitEdge")) and node is TextureRect:
		var inactive: Array = [0.74, 0.94, 0.98]
		for tint: float in inactive:
			if is_equal_approx(alpha, tint): return "scripts/run_scene.gd::_turn_order_portrait_modulate"
			if not str(parent.name).begins_with("OverflowPortraitEdge"): continue
			for base: float in inactive:
				for layer: int in [1, 2]:
					if is_equal_approx(alpha, tint * pow(base, layer)):
						return "scripts/turn_order_slots.gd::overflow"
	if node.name == &"PassForecastFrameArtHost" and parent is Button and parent.disabled and is_equal_approx(alpha, 0.92):
		return "scripts/run_scene.gd::_refresh_pass_preview_interaction"
	if node.name in [&"DrawPileIcon", &"DiscardPileIcon", &"ExhaustPileIcon"] and is_equal_approx(alpha, 0.42):
		return "scripts/pile_visual_refresh.gd::populate_icon"
	if node.name == &"PlayerMovementMeter" and is_equal_approx(alpha, 0.42):
		return "scripts/run_scene.gd::_refresh_player_movement_meter"
	if node.name == &"CardPlayMeter" and is_equal_approx(alpha, 0.42):
		return "scripts/run_scene.gd::_refresh_card_play_meter"
	if str(node.get_path()).contains("/GuidedActionCallout/") and node is Button and is_equal_approx(alpha, 0.78):
		return "scripts/contextual_combat_prompt.gd:478"
	if selected and str(node.name).begins_with("IntentTab_") and is_equal_approx(alpha, (parent.get_meta("rd03_target", parent.self_modulate) as Color).a):
		return "scripts/intent_badges.gd::draw_contextual_chip and scripts/board_aim_focus.gd::_present"
	return ""

static func matches(value: float, authored: Array) -> bool:
	for candidate: float in authored:
		if is_equal_approx(value, candidate): return true
	return false

static func append_tree(node: Node, result: Array[Node]) -> void:
	result.append(node)
	for child: Node in node.get_children(true):
		append_tree(child, result)

static func census(scene: Node) -> Dictionary:
	return {"tree": scene.get_tree().get_node_count(),
		"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)),
		"orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)),
		"scene": scene.get_instance_id()}

static func lifetime(tree: SceneTree, scene: Node, count: Dictionary) -> Array[Dictionary]:
	var issues: Array[Dictionary]
	var nodes: Array[Node]
	append_tree(scene, nodes)
	for node: Node in nodes:
		if not node is AnimationPlayer or not node.is_playing(): continue
		var target: Node = node.get_node_or_null(node.root_node)
		if not is_instance_valid(target) or (target is CanvasItem and not target.is_visible_in_tree()):
			issues.append({"kind": "hidden_animation", "node": str(node.get_path()), "animation": str(node.current_animation), "owner": path_of(target)})
	# SceneTree exposes processed tweens but no bound-owner accessor. Settling
	# requires no running tweens anywhere in the isolated tree, a stricter gate.
	for tween: Tween in tree.get_processed_tweens():
		if tween.is_running(): issues.append({"kind": "running_tween", "id": tween.get_instance_id()})
	if count["orphans"] < 0:
		issues.append({"kind": "invalid_orphan_monitor"})
	return issues
