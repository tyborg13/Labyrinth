extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

var _failures: Array[String]
var _learned_request: String = ""

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1280, 720)
	root.size = Vector2i(1280, 720)
	await process_frame
	await _test_skill_tree_view()
	if _failures.is_empty():
		print("TEST RESULT: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)

func _test_skill_tree_view() -> void:
	var view := SkillTreeView.new()
	view.position = Vector2(40.0, 40.0)
	view.size = Vector2(1120.0, 620.0)
	view.learn_requested.connect(func(skill_id: String) -> void: _learned_request = skill_id)
	var initial_build_started_usec: int = Time.get_ticks_usec()
	root.add_child(view)
	var initial_build_elapsed_usec: int = Time.get_ticks_usec() - initial_build_started_usec
	var initial_configure_started_usec: int = Time.get_ticks_usec()
	view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": ["quick_wits"],
		"required_count": 5,
		"unspent_points": 4,
		"editing_enabled": true,
		"focused_id": "quick_wits",
	})
	var initial_configure_elapsed_usec: int = Time.get_ticks_usec() - initial_configure_started_usec
	print("SKILL TREE PERF build=%dus configure=%dus metrics=%s" % [initial_build_elapsed_usec, initial_configure_elapsed_usec, view.performance_metrics()])
	await process_frame
	await process_frame
	var warm_view := SkillTreeView.new()
	var warm_build_started_usec: int = Time.get_ticks_usec()
	root.add_child(warm_view)
	var warm_build_elapsed_usec: int = Time.get_ticks_usec() - warm_build_started_usec
	print("SKILL TREE PERF warm_build=%dus" % warm_build_elapsed_usec)
	_expect(initial_build_elapsed_usec < 250000, "Cold skill-tree construction should stay below a quarter-second: %dus" % initial_build_elapsed_usec)
	_expect(initial_configure_elapsed_usec < 50000, "A ready skill-tree state update should stay below 50ms: %dus" % initial_configure_elapsed_usec)
	_expect(warm_build_elapsed_usec < 250000, "Repeated skill-tree construction should stay below a quarter-second: %dus" % warm_build_elapsed_usec)
	_expect(int(view.performance_metrics().get("link_geometry_usec", 0)) < 100000, "Connector routing should stay below 100ms")
	warm_view.queue_free()
	await process_frame

	_expect(view.node_count() == 24, "The tree should render all 24 skills")
	var expected_links: int = 0
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		expected_links += SkillTreeLibrary.prerequisites(skill_id).size()
	_expect(view.connection_count() == expected_links, "The tree should render every prerequisite connector")
	_expect(view.connection_arrowhead_count() == expected_links, "Every connector should retain its target arrowhead")
	_expect(view.link_geometry_rebuild_count() == 1, "Static connector geometry should be built exactly once")
	_expect(view.navigation_rebuild_count() >= 1, "Initial configuration should build directional navigation")
	_expect(view.graph_canvas_size() == Vector2(1000.0, 540.0), "The graph should retain its topology-first canvas")
	_expect(view.find_child("SkillTreeScroll", true, false) == null, "The primary graph must never expose a scrollbar")
	_expect(view.find_child("SkillTreeGraphViewport", true, false) is Control, "The graph should use a clipped zoom-to-fit viewport")
	_expect(view.graph_fit_scale() > 0.0 and view.graph_fit_scale() <= 1.0, "The complete authored graph should fit its viewport without panning")
	_expect(view.find_child("SkillDetailScroll", true, false) == null, "The skill tree detail pane should not expose a scrollbar")
	_expect(view.find_child("SkillDetailContent", true, false) is VBoxContainer, "The complete focused-skill rules should remain visible beside the tree")
	_expect(view.legend_state_count() == 4, "The persistent tree should show learned, available, locked, and exclusive states without a draft state")
	_expect(_label_with_text(view, "Prismatic Instinct") == null, "Skill names should remain in the unobstructed detail pane")
	_expect(
		view.connection_intersection_count() == 0,
		"No connector should cross an unrelated medallion: %s; discerning→bearing=%s" % [
			", ".join(view.connection_intersection_pairs()),
			view.connection_points("discerning_eye", "true_bearing"),
		]
	)
	_expect(
		view.collinear_connection_overlap_pairs().is_empty(),
		"Unrelated routes should never merge into an ambiguous rail: %s; deferred→layaway=%s; quick→curator=%s" % [
			", ".join(view.collinear_connection_overlap_pairs()),
			view.connection_points("deferred_choice", "layaway"),
			view.connection_points("quick_wits", "curators_patience"),
		]
	)
	_expect(view.bridged_connection_pairs().size() == 11, "Every unavoidable route crossing should retain an explicit bridge")
	_expect(view.unbridged_connection_pairs().is_empty(), "No route crossing should resemble an unexplained junction")
	_expect(view.minimum_bridge_half_gap() >= 10.0, "Bridge gaps should visibly clear the upper route")
	_expect(view.minimum_connection_width() >= 3.0, "Unfocused connectors should remain legible")
	_expect(view.minimum_connection_alpha() >= 0.9, "Focusing should not fade the remaining topology")
	_expect(view.minimum_understroke_margin() >= 3.0, "Connectors should retain a separating understroke")
	_expect(view.minimum_target_segment_length() >= 10.0, "Arrowheads should remain exposed outside node shadows")

	var legend_symbols: Array[String]
	for state: String in ["owned", "available", "locked", "excluded"]:
		var marker := view.find_child("SkillLegendMarker_%s" % state, true, false) as Control
		var label := view.find_child("SkillLegendLabel_%s" % state, true, false) as Label
		_expect(marker != null and marker.custom_minimum_size.x >= 18.0, "%s should have a readable vector marker" % state)
		_expect(label != null and label.get_theme_font_size("font_size") >= UiTypography.SIZE_CAPTION, "%s copy should meet the caption floor" % state)
		if marker != null:
			legend_symbols.append(str(marker.get_meta("symbol_kind", "")))
	legend_symbols.sort()
	_expect(legend_symbols == ["check", "lock", "plus", "strike"], "Persistent states should use independent non-color symbols")

	for branch_id: String in ["Resolve", "Tactics", "Foresight", "Traverse"]:
		_expect(view.find_child("SkillBranchHeader_%s" % branch_id, true, false) is Label, "%s should keep a stable root heading" % branch_id)
	var graph_bounds := Rect2(Vector2.ZERO, view.graph_canvas_size())
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node: Button = view.node_for_skill(skill_id)
		_expect(node != null and node.size.x >= 76.0 and node.size.x <= 80.0, "%s should use a large scan-readable medallion" % skill_id)
		_expect(node != null and node.tooltip_text.is_empty(), "%s should rely on the fixed detail pane instead of a tooltip" % skill_id)
		_expect(graph_bounds.encloses(Rect2(node.position, node.size)), "%s should remain inside the graph canvas" % skill_id)
		_expect(ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id)) != null, "%s should render a semantic icon" % skill_id)
		var up_neighbor: String = view.navigation_neighbor(skill_id, "up")
		if not up_neighbor.is_empty():
			_expect(SkillTreeLibrary.prerequisites(skill_id).has(up_neighbor), "%s Up should follow a visible prerequisite" % skill_id)
		var down_neighbor: String = view.navigation_neighbor(skill_id, "down")
		if not down_neighbor.is_empty():
			_expect(SkillTreeLibrary.prerequisites(down_neighbor).has(skill_id), "%s Down should follow a visible dependent" % skill_id)
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			_expect(view.node_center_for_skill(prerequisite_id).y < view.node_center_for_skill(skill_id).y, "%s should render below %s" % [skill_id, prerequisite_id])
		var prerequisites: Array[String] = SkillTreeLibrary.prerequisites(skill_id)
		if prerequisites.size() > 1:
			var first_route: PackedVector2Array = view.connection_points(prerequisites[0], skill_id)
			var second_route: PackedVector2Array = view.connection_points(prerequisites[1], skill_id)
			_expect(first_route[first_route.size() - 1] != second_route[second_route.size() - 1], "%s should expose separate prerequisite ports" % skill_id)

	_expect(view.status_for_skill("quick_wits") == SkillTreeView.STATE_OWNED, "Committed skills should render as learned")
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_AVAILABLE, "Legal unlearned roots should render as available")
	_expect(view.status_for_skill("borrowed_time") == SkillTreeView.STATE_LOCKED, "Missing prerequisites should render as locked")
	_expect(view.points_remaining() == 4, "The tree should display all banked skill points")
	var detail_action := view.find_child("SkillDetailAction", true, false) as Button
	view.focus_skill("measured_breath")
	_expect(view.detail_title_text() == "Measured Breath", "Focus should update the persistent detail pane")
	_expect(detail_action != null and detail_action.text == "Learn  ·  1 Point" and view.detail_action_is_enabled(), "An available skill with a banked point should expose immediate Learn")
	detail_action.pressed.emit()
	await process_frame
	_expect(_learned_request == "measured_breath", "Learn should emit the single skill to persist immediately")
	_expect(view.owned_skill_ids() == ["quick_wits"], "The reusable view should not invent a local allocation before its owner saves")

	var navigation_before_learn_update: int = view.navigation_rebuild_count()
	view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": ["quick_wits", "measured_breath"],
		"required_count": 5,
		"unspent_points": 3,
		"editing_enabled": true,
		"focused_id": "measured_breath",
	})
	await process_frame
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_OWNED, "A saved learned skill should update immediately")
	_expect(view.points_remaining() == 3, "A saved learn should consume exactly one point")
	_expect(view.link_geometry_rebuild_count() == 1, "State reconfiguration should reuse static connector geometry")
	_expect(view.navigation_rebuild_count() > navigation_before_learn_update, "A saved learn should rebuild controller exits after Learn becomes unavailable")
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node: Button = view.node_for_skill(skill_id)
		for neighbor_property: StringName in [&"focus_neighbor_left", &"focus_neighbor_right", &"focus_neighbor_top", &"focus_neighbor_bottom"]:
			var neighbor_path: NodePath = node.get(neighbor_property)
			var neighbor: Node = node.get_node_or_null(neighbor_path) if not neighbor_path.is_empty() else null
			_expect(neighbor != detail_action, "%s should not retain a controller exit to the disabled Learn action" % skill_id)

	# Pointer hover is decoration only. Selection belongs to click/controller
	# focus, and hover must not do any graph or navigation work.
	var scroll_before: Vector2i = view.graph_scroll_offset()
	var geometry_before: int = view.link_geometry_rebuild_count()
	var navigation_before: int = view.navigation_rebuild_count()
	var focus_before: Control = root.gui_get_focus_owner()
	var hover_started: int = Time.get_ticks_usec()
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		view.node_for_skill(skill_id).mouse_entered.emit()
	var hover_elapsed_usec: int = Time.get_ticks_usec() - hover_started
	await process_frame
	_expect(view.focused_skill_id() == "measured_breath", "Hover should not change the clicked or controller-focused skill")
	_expect(root.gui_get_focus_owner() == focus_before, "Hover should not transfer keyboard focus")
	_expect(view.graph_scroll_offset() == Vector2i.ZERO and scroll_before == Vector2i.ZERO, "The zoom-to-fit graph should have no scroll offset")
	_expect(view.link_geometry_rebuild_count() == geometry_before, "Hover should never reroute connectors or recompute bridges")
	_expect(view.navigation_rebuild_count() == navigation_before, "Hover should never rebuild directional navigation")
	_expect(hover_elapsed_usec < 1000000, "A full 24-node hover sweep should complete comfortably under one second")

	view.focus_skill("prismatic_instinct", false)
	var prismatic_links: Array[String] = view.highlighted_connection_pairs()
	_expect(prismatic_links.size() == 3, "Focused junctions should highlight exactly two prerequisites and one direct dependent")
	_expect(prismatic_links.has("quick_wits>prismatic_instinct"), "Quick Wits should visibly feed Prismatic Instinct")
	_expect(prismatic_links.has("discerning_eye>prismatic_instinct"), "Discerning Eye should visibly feed Prismatic Instinct")
	_expect(prismatic_links.has("prismatic_instinct>confluence"), "Prismatic Instinct should visibly feed Confluence")
	_expect(view.link_geometry_rebuild_count() == geometry_before, "Focus emphasis should restyle cached routes without rebuilding them")

	view.grab_tree_focus()
	await process_frame
	var focused_node: Button = view.node_for_skill("prismatic_instinct")
	_expect(root.gui_get_focus_owner() == focused_node, "Explicit controller focus should still enter the visually focused node")
	_expect(view.navigation_neighbor("quick_wits", "left") == "measured_breath", "Horizontal navigation should stay on the root row")
	_expect(view.navigation_neighbor("quick_wits", "right") == "discerning_eye", "Root navigation should use the adjacent medallion")

	view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": ["quick_wits", "measured_breath"],
		"required_count": 2,
		"unspent_points": 0,
		"editing_enabled": true,
		"focused_id": "ghost_stride",
	})
	await process_frame
	_expect(detail_action.text == "No Skill Points" and not view.detail_action_is_enabled(), "Available skills should remain inspectable but unspendable at zero points")

	var keystone_build: Array[String] = SkillTreeLibrary.repaired_selection([], 9, [
		"quick_wits", "measured_breath", "rehearsed_escape", "makeshift_tool",
		"carry_the_guard", "pain_remembers", "borrowed_time", "ghost_stride", "encore",
	])
	view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": keystone_build,
		"required_count": 12,
		"unspent_points": 3,
		"editing_enabled": true,
		"focused_id": "open_arsenal",
	})
	await process_frame
	_expect(view.status_for_skill("open_arsenal") == SkillTreeView.STATE_EXCLUDED, "Other keystones should remain visibly exclusive")
	var keystone_reason := view.find_child("SkillDetailReason", true, false) as Label
	_expect(keystone_reason != null and keystone_reason.text == "Another keystone is selected", "Excluded details should explain the competing keystone")
	view.focus_skill("last_door", false)
	var leaf_links := view.find_child("SkillDetailUnlocks", true, false) as Label
	_expect(leaf_links != null and leaf_links.text == "LEADS TO\nNo direct skills", "Leaf details should not imply hidden unlocks")

	view.queue_free()
	await process_frame

func _label_with_text(node: Node, expected: String) -> Label:
	if node is Label and (node as Label).text == expected:
		return node as Label
	for child: Node in node.get_children():
		var found: Label = _label_with_text(child, expected)
		if found != null:
			return found
	return null

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
