extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

var _failures: Array[String]
var _observed_level_choice: String = ""
var _pending_event_count: int = 0
var _respec_event_count: int = 0
var _confirmed_ids: Array[String]

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
	view.skill_focused.connect(_on_skill_focused)
	view.level_up_choice_changed.connect(_on_level_choice_changed)
	view.pending_changed.connect(_on_pending_changed)
	view.respec_draft_changed.connect(_on_respec_draft_changed)
	view.confirm_requested.connect(_on_confirm_requested)
	root.add_child(view)
	view.configure({
		"mode": SkillTreeView.MODE_LEVEL_UP,
		"owned_ids": ["quick_wits"],
		"required_count": 2,
		"resource_count": 0,
		"editing_enabled": true,
	})
	await process_frame
	await process_frame

	_expect(view.node_count() == 24, "The reusable tree should render all 24 skill nodes")
	var expected_links: int = 0
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		expected_links += SkillTreeLibrary.prerequisites(skill_id).size()
	_expect(view.connection_count() == expected_links, "The reusable tree should render one connector for every prerequisite")
	_expect(view.connection_arrowhead_count() == expected_links, "Every prerequisite should retain one visible target arrowhead above the node layer")
	_expect(view.graph_canvas_size() == Vector2(1000.0, 540.0), "The graph should reserve enough topology-first space for exposed routing lanes")
	_expect(view.find_child("SkillTreeScroll", true, false) is ScrollContainer, "The graph should remain scrollable in a smaller host")
	_expect(view.find_child("SkillDetailPanel", true, false) is PanelContainer, "The tree should provide its own detail panel")
	_expect(view.find_child("SkillDetailScroll", true, false) is ScrollContainer, "Long skill rules should scroll inside the detail pane instead of resizing the whole tree")
	_expect(view.legend_state_count() == 5, "Level-up mode should explain every node state that can appear while choosing a skill")
	var legend_symbols: Array[String]
	for state: String in ["owned", "available", "locked", "pending", "excluded"]:
		var marker := view.find_child("SkillLegendMarker_%s" % state, true, false) as Control
		var legend_label := view.find_child("SkillLegendLabel_%s" % state, true, false) as Label
		_expect(marker != null and marker.custom_minimum_size.x >= 18.0, "%s should use a readable vector legend marker" % state)
		_expect(legend_label != null and legend_label.get_theme_font_size("font_size") >= UiTypography.SIZE_CAPTION, "%s legend copy should respect the caption readability floor" % state)
		if marker != null:
			legend_symbols.append(str(marker.get_meta("symbol_kind", "")))
	legend_symbols.sort()
	_expect(legend_symbols == ["check", "dot", "lock", "plus", "strike"], "Every legend state should have a distinct non-color symbol")
	_expect(_label_with_text(view, "Prismatic Instinct") == null, "Skill names should live in the detail pane instead of covering graph connections")
	_expect(view.connection_intersection_count() == 0, "No connector should pass through an unrelated medallion: %s" % ", ".join(view.connection_intersection_pairs()))
	_expect(
		view.collinear_connection_overlap_pairs().is_empty(),
		"Unrelated routes should never merge into an ambiguous shared rail: %s" % ", ".join(view.collinear_connection_overlap_pairs())
	)
	_expect(
		view.bridged_connection_pairs().size() == 11,
		"Every unavoidable non-incident crossover should have one explicit visual bridge: %s" % ", ".join(view.bridged_connection_pairs())
	)
	_expect(
		view.unbridged_connection_pairs().is_empty(),
		"No non-incident crossover should be rendered as an unexplained junction: %s" % ", ".join(view.unbridged_connection_pairs())
	)
	_expect(view.minimum_bridge_half_gap() >= 10.0, "Crossover gaps should visibly clear the route drawn above them")
	var stable_bridge_signature: Array[String] = view.bridge_assignment_signature()
	_expect(view.minimum_connection_width() >= 3.0, "Every connection should remain visibly legible even when unfocused")
	_expect(view.minimum_connection_alpha() >= 0.9, "Focusing a node should never fade the remaining topology into invisibility")
	_expect(view.minimum_understroke_margin() >= 3.0, "Every connection should have a dark separating under-stroke")
	_expect(view.minimum_target_segment_length() >= 10.0, "Every prerequisite should expose enough incoming line for its arrowhead to remain outside the medallion shadow")
	for branch_id: String in ["Resolve", "Tactics", "Foresight", "Traverse"]:
		_expect(view.find_child("SkillBranchHeader_%s" % branch_id, true, false) is Label, "%s should have a stable branch heading above its root" % branch_id)
	_expect(view.status_for_skill("quick_wits") == SkillTreeView.STATE_OWNED, "Committed skills should render as learned")
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_AVAILABLE, "Legal roots should render as available")
	_expect(view.status_for_skill("borrowed_time") == SkillTreeView.STATE_LOCKED, "Missing prerequisites should render as locked")
	var requirements_label := view.find_child("SkillDetailRequirements", true, false) as Label
	var unlocks_label := view.find_child("SkillDetailUnlocks", true, false) as Label
	_expect(requirements_label != null and requirements_label.text == "REQUIRES\nNONE  Root skill", "Root details should state that there is no prerequisite")
	_expect(unlocks_label != null and unlocks_label.text.begins_with("LEADS TO\n") and not unlocks_label.text.contains("UNLOCKS"), "Dependency details should describe visible outgoing links as leads-to relationships")
	var quick_node: Button = view.node_for_skill("quick_wits")
	var measured_node: Button = view.node_for_skill("measured_breath")
	_expect(quick_node != null and measured_node != null and measured_node.position.x < quick_node.position.x, "Topology layout should place Measured Breath beside Quick Wits to shorten their shared link")
	view.grab_tree_focus()
	await process_frame
	_expect(root.gui_get_focus_owner() == quick_node, "Opening the tree should transfer real GUI focus to its visually focused node")
	measured_node.mouse_entered.emit()
	await process_frame
	_expect(view.focused_skill_id() == "measured_breath" and root.gui_get_focus_owner() == measured_node, "Mouse hover should synchronize the tree highlight with real GUI focus")
	await _press_ui_action(&"ui_accept")
	_expect(view.pending_skill_ids() == ["measured_breath"], "Keyboard Accept after hover should activate the hovered skill, not the previously focused control")
	view.configure({
		"mode": SkillTreeView.MODE_LEVEL_UP,
		"owned_ids": ["quick_wits"],
		"pending_ids": [],
		"required_count": 2,
		"resource_count": 0,
		"editing_enabled": true,
		"focused_id": "quick_wits",
	})
	view.grab_tree_focus()
	await process_frame
	var encore_node: Button = view.node_for_skill("encore")
	_expect(encore_node != null and quick_node != null and encore_node.position.y > quick_node.position.y, "Keystones should render below their earlier tiers")
	_expect(view.node_for_skill("rehearsed_escape").position.y == view.node_for_skill("makeshift_tool").position.y, "Sibling skills should share a dependency depth instead of implying a false chain")
	var graph_bounds := Rect2(Vector2.ZERO, view.graph_canvas_size())
	for skill_id: String in SkillTreeLibrary.ordered_ids():
		var node: Button = view.node_for_skill(skill_id)
		_expect(node.size.x >= 48.0 and node.size.x <= 66.0, "%s should use a compact but accessible medallion hit target" % skill_id)
		_expect(graph_bounds.encloses(Rect2(node.position, node.size)), "%s should remain wholly inside the fixed graph canvas" % skill_id)
		_expect(ActionIcons.icon_texture(SkillTreeLibrary.icon_key(skill_id)) != null, "%s should render a valid semantic icon" % skill_id)
		var up_neighbor: String = view.navigation_neighbor(skill_id, "up")
		if not up_neighbor.is_empty():
			_expect(SkillTreeLibrary.prerequisites(skill_id).has(up_neighbor), "%s Up navigation should follow one of its visible prerequisite links" % skill_id)
		var down_neighbor: String = view.navigation_neighbor(skill_id, "down")
		if not down_neighbor.is_empty():
			_expect(SkillTreeLibrary.prerequisites(down_neighbor).has(skill_id), "%s Down navigation should follow one of its visible dependent links" % skill_id)
		for prerequisite_id: String in SkillTreeLibrary.prerequisites(skill_id):
			_expect(view.node_center_for_skill(prerequisite_id).y < view.node_center_for_skill(skill_id).y, "%s should render below prerequisite %s" % [skill_id, prerequisite_id])
		var prerequisites: Array[String] = SkillTreeLibrary.prerequisites(skill_id)
		if prerequisites.size() > 1:
			var minimum_x: float = minf(view.node_center_for_skill(prerequisites[0]).x, view.node_center_for_skill(prerequisites[1]).x)
			var maximum_x: float = maxf(view.node_center_for_skill(prerequisites[0]).x, view.node_center_for_skill(prerequisites[1]).x)
			_expect(view.node_center_for_skill(skill_id).x >= minimum_x and view.node_center_for_skill(skill_id).x <= maximum_x, "%s should sit between its two prerequisites" % skill_id)
			var first_route: PackedVector2Array = view.connection_points(prerequisites[0], skill_id)
			var second_route: PackedVector2Array = view.connection_points(prerequisites[1], skill_id)
			_expect(first_route[first_route.size() - 1] != second_route[second_route.size() - 1], "%s should expose a separate input port for each prerequisite" % skill_id)
	var discerning_node: Button = view.node_for_skill("discerning_eye")
	var ghost_node: Button = view.node_for_skill("ghost_stride")
	_expect(view.navigation_neighbor("measured_breath", "left").is_empty(), "The left root edge should not jump diagonally into another rank")
	_expect(view.navigation_neighbor("measured_breath", "right") == "quick_wits", "Root-row Right should move to the adjacent root")
	_expect(view.navigation_neighbor("quick_wits", "left") == "measured_breath", "Quick Wits Left should remain on the root row")
	_expect(view.navigation_neighbor("quick_wits", "right") == "discerning_eye", "Quick Wits Right should remain on the root row")
	_expect(view.navigation_neighbor("discerning_eye", "left") == "quick_wits" and view.navigation_neighbor("discerning_eye", "right") == "ghost_stride", "Discerning Eye horizontal navigation should use adjacent roots")
	_expect(view.navigation_neighbor("ghost_stride", "right").is_empty(), "The right root edge should not jump diagonally into another rank")
	_expect(view.navigation_neighbor("borrowed_time", "down") == "encore", "Vertical navigation should follow Borrowed Time's visible dependent link")
	_expect(quick_node.find_valid_focus_neighbor(SIDE_LEFT) == measured_node, "Godot's live focus graph should resolve Quick Wits Left to Measured Breath")
	_expect(quick_node.find_valid_focus_neighbor(SIDE_RIGHT) == discerning_node, "Godot's live focus graph should resolve Quick Wits Right to Discerning Eye")
	var detail_action := view.find_child("SkillDetailAction", true, false) as Button
	view.focus_skill("ghost_stride")
	ghost_node.grab_focus()
	await process_frame
	_expect(ghost_node.find_valid_focus_neighbor(SIDE_RIGHT) == detail_action, "A graph edge should lead to the focused skill's visible action instead of trapping controller focus")
	var cancel_button := view.find_child("SkillTreeCancel", true, false) as Button
	var reserve_node: Button = view.node_for_skill("last_reserve")
	view.focus_skill("last_reserve")
	reserve_node.grab_focus()
	await process_frame
	_expect(reserve_node.find_valid_focus_neighbor(SIDE_BOTTOM) == cancel_button, "A leaf should expose a controller path from the graph to its footer")
	await _press_ui_action(&"ui_down")
	_expect(root.gui_get_focus_owner() == cancel_button, "Live controller navigation should leave a graph leaf for the footer")

	view.focus_skill("measured_breath")
	measured_node.grab_focus()
	await process_frame
	_expect(view.visual_state_for_skill("measured_breath") == SkillTreeView.STATE_SELECTED, "Focused nodes should expose the selected visual state")
	_expect(view.detail_title_text() == "Measured Breath", "Node focus should update the detail title")
	_expect(view.detail_action_is_enabled(), "A legal level-up choice should expose an enabled detail action")
	await _press_ui_action(&"ui_accept")
	_expect(view.pending_skill_ids() == ["measured_breath"], "Level-up mode should retain one pending skill")
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_PENDING, "The chosen level-up node should render as pending")
	_expect(_observed_level_choice == "measured_breath", "Level-up mode should emit the chosen skill id")
	_expect(view.confirm_is_enabled(), "A legal pending level-up choice should enable confirmation")
	var confirm_button := view.find_child("SkillTreeConfirm", true, false) as Button
	_expect(root.gui_get_focus_owner() == confirm_button, "Completing a controller-built selection should move live focus to Confirm")
	await _press_ui_action(&"ui_accept")
	_expect(_confirmed_ids == ["quick_wits", "measured_breath"], "Level-up confirmation should emit the complete proposed selection")
	view.focus_skill("prismatic_instinct")
	var prismatic_links: Array[String] = view.highlighted_connection_pairs()
	_expect(prismatic_links.size() == 3, "Focusing Prismatic Instinct should highlight exactly its two prerequisites and direct unlock")
	_expect(prismatic_links.has("quick_wits>prismatic_instinct"), "Focusing Prismatic Instinct should highlight its Quick Wits prerequisite edge")
	_expect(prismatic_links.has("discerning_eye>prismatic_instinct"), "Focusing Prismatic Instinct should highlight its Discerning Eye prerequisite edge")
	_expect(prismatic_links.has("prismatic_instinct>confluence"), "Focusing Prismatic Instinct should highlight its Confluence unlock edge")
	_expect(not prismatic_links.has("measured_breath>carry_the_guard"), "Changing focus should clear connector emphasis from the previously focused skill")
	var quick_relation_node: Button = view.node_for_skill("quick_wits")
	var discerning_relation_node: Button = view.node_for_skill("discerning_eye")
	_expect(str(quick_relation_node.get_meta("focus_relationship", "")) == "prerequisite", "A focused junction should mark Quick Wits as a prerequisite")
	_expect(str(discerning_relation_node.get_meta("focus_relationship", "")) == "prerequisite", "A focused junction should mark Discerning Eye as a prerequisite")
	view.focus_skill("living_shadow")
	await process_frame
	await process_frame
	_expect(
		view.bridge_assignment_signature() == stable_bridge_signature,
		"Crossover ownership should remain stable as focus and learned state change"
	)
	var graph_scroll := view.find_child("SkillTreeScroll", true, false) as ScrollContainer
	var visible_graph: Rect2 = graph_scroll.get_global_rect() if graph_scroll != null else Rect2()
	_expect(
		graph_scroll != null
		and visible_graph.encloses(view.node_for_skill("pain_remembers").get_global_rect())
		and visible_graph.encloses(view.node_for_skill("afterimage").get_global_rect()),
		"Focusing a long cross-branch skill should pan far enough to show both direct prerequisite medallions"
	)

	view.visible = false
	var compact_view := SkillTreeView.new()
	compact_view.position = Vector2(24.0, 24.0)
	compact_view.size = Vector2(900.0, 420.0)
	compact_view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": [],
		"focused_id": "last_door",
	})
	root.add_child(compact_view)
	await process_frame
	await process_frame
	compact_view.grab_tree_focus()
	await process_frame
	await process_frame
	var compact_scroll := compact_view.find_child("SkillTreeScroll", true, false) as ScrollContainer
	var last_door_node: Button = compact_view.node_for_skill("last_door")
	_expect(
		compact_scroll != null
		and compact_scroll.scroll_horizontal > 0
		and compact_scroll.scroll_vertical > 0
		and compact_scroll.get_global_rect().encloses(last_door_node.get_global_rect()),
		"Opening a compact tree on a remembered extreme node should pan both axes to reveal it"
	)
	root.remove_child(compact_view)
	compact_view.queue_free()
	view.visible = true
	await process_frame

	var original: Array[String]
	original.append_array([
		"quick_wits",
		"measured_breath",
		"rehearsed_escape",
		"makeshift_tool",
		"carry_the_guard",
	])
	_expect(SkillTreeLibrary.selection_is_valid(original, 5), "The respec fixture should begin with a legal selection")
	view.configure({
		"mode": SkillTreeView.MODE_RESPEC,
		"owned_ids": original,
		"required_count": 5,
		"resource_count": 1,
		"editing_enabled": true,
		"focused_id": "",
	})
	await process_frame
	_expect(view.pending_skill_ids().is_empty(), "A respec should open as an empty replacement build")
	_expect(view.points_remaining() == 5, "Every earned skill point should be refunded into the replacement draft")
	_expect(view.legend_state_count() == 4, "The replacement tree should omit the impossible learned state from its legend")
	_expect(view.focused_skill_id() == "quick_wits", "An empty replacement draft should automatically focus the first available root")
	_expect(view.detail_title_text() == "Quick Wits" and view.detail_action_is_enabled(), "The default empty-draft focus should expose an actionable root detail")
	detail_action = view.find_child("SkillDetailAction", true, false) as Button
	confirm_button = view.find_child("SkillTreeConfirm", true, false) as Button
	_expect(detail_action != null and detail_action.text == "Allocate", "A legal respec choice should use allocation language rather than another spend command")
	_expect(confirm_button != null and confirm_button.text == "Confirm · 1 Moltshard", "Respec confirmation should name its distinct resource cost")
	_expect(view.get_combined_minimum_size().y <= view.size.y + 1.0, "An empty replacement draft's detail copy should not increase the tree beyond its assigned height")
	_expect(view.status_for_skill("quick_wits") == SkillTreeView.STATE_AVAILABLE, "Formerly learned roots should begin available rather than appearing selected or removed")
	_expect(not view.confirm_is_enabled(), "An empty replacement build should not be confirmable")
	for skill_id: String in ["quick_wits", "rehearsed_escape", "makeshift_tool", "measured_breath", "carry_the_guard"]:
		view.focus_skill(skill_id)
		_expect(view.detail_action_is_enabled(), "%s should be addable in prerequisite order" % skill_id)
		view.activate_focused_skill()
	_expect(view.pending_skill_ids().size() == 5, "A complete rebuild should allocate every refunded point")
	_expect(view.points_remaining() == 0, "A complete rebuild should leave no unallocated points")
	_expect(view.status_for_skill("quick_wits") == SkillTreeView.STATE_PENDING, "Draft selections should use a distinct drafted state")
	_expect(not view.confirm_is_enabled(), "Rebuilding the exact original set should not waste a Moltshard")
	var matching_summary := view.find_child("SkillTreeSummary", true, false) as Label
	_expect(matching_summary != null and matching_summary.text.contains("MATCHES CURRENT BUILD"), "An unchanged complete replacement should visibly explain why confirmation is unavailable")
	_expect(confirm_button != null and confirm_button.tooltip_text.contains("matches your current build"), "The disabled unchanged-build confirmation should explain the required edit")
	view.focus_skill("ghost_stride")
	_expect(view.status_for_skill("ghost_stride") == SkillTreeView.STATE_AVAILABLE, "An otherwise legal root should remain visibly available at the point cap")
	_expect(not view.detail_action_is_enabled(), "The view should hard-cap additions when no skill points remain")
	view.focus_skill("quick_wits")
	_expect(not view.detail_action_is_enabled(), "A prerequisite with drafted dependents should require removing its dependents first")
	view.focus_skill("carry_the_guard")
	_expect(view.detail_action_is_enabled(), "A drafted leaf should refund its point")
	_expect(detail_action != null and detail_action.text == "Refund", "A removable draft leaf should use refund language")
	view.activate_focused_skill()
	_expect(view.pending_skill_ids().size() == 4 and view.points_remaining() == 1, "Removing a drafted leaf should refund exactly one point")
	view.focus_skill("ghost_stride")
	_expect(view.detail_action_is_enabled(), "A refunded point should make an available replacement root addable")
	view.activate_focused_skill()
	_expect(view.pending_skill_ids().size() == 5, "Spending the refunded point should restore the required draft size")
	_expect(view.status_for_skill("ghost_stride") == SkillTreeView.STATE_PENDING, "A newly allocated skill should render as drafted")
	_expect(SkillTreeLibrary.selection_is_valid(view.pending_skill_ids(), 5), "The edited respec draft should remain topologically legal")
	_expect(view.confirm_is_enabled(), "A changed legal respec draft with a resource should be confirmable")
	_expect(confirm_button != null and confirm_button.tooltip_text.contains("replace the active build"), "A changed build should explain the whole-build replacement transaction")
	_expect(_respec_event_count == 7, "Each from-scratch allocation and refund should emit the complete draft")
	view.request_confirm()
	_expect(_confirmed_ids == view.pending_skill_ids(), "Respec confirmation should emit the complete replacement build")

	var keystone_build: Array[String] = SkillTreeLibrary.repaired_selection([], 9, [
		"quick_wits",
		"measured_breath",
		"rehearsed_escape",
		"makeshift_tool",
		"carry_the_guard",
		"pain_remembers",
		"borrowed_time",
		"ghost_stride",
		"encore",
	])
	_expect(keystone_build.has("encore"), "The exclusivity fixture should contain its requested keystone")
	view.configure({
		"mode": SkillTreeView.MODE_VIEW,
		"owned_ids": keystone_build,
		"focused_id": "open_arsenal",
	})
	await process_frame
	_expect(view.legend_state_count() == 4, "The read-only tree should omit the impossible drafted state from its legend")
	_expect(view.status_for_skill("open_arsenal") == SkillTreeView.STATE_EXCLUDED, "Other keystones should expose an excluded state after one is learned")
	var keystone_requirements := view.find_child("SkillDetailRequirements", true, false) as Label
	var keystone_reason := view.find_child("SkillDetailReason", true, false) as Label
	_expect(keystone_requirements != null and keystone_requirements.text.contains("READY  8 other skills learned"), "Keystone details should count the eight other skills required before the keystone")
	_expect(keystone_reason != null and keystone_reason.text == "Another keystone is selected", "Excluded keystone details should describe the competing selection accurately")
	view.focus_skill("last_door")
	var leaf_links := view.find_child("SkillDetailUnlocks", true, false) as Label
	_expect(leaf_links != null and leaf_links.text == "LEADS TO\nNo direct skills", "Leaf details should use the same leads-to language without implying a hidden unlock")
	_expect(_pending_event_count >= 8, "Both level-up and from-scratch respec edits should emit the shared pending signal")

	view.queue_free()
	await process_frame

func _on_skill_focused(_skill_id: String) -> void:
	pass

func _on_level_choice_changed(skill_id: String) -> void:
	_observed_level_choice = skill_id

func _on_pending_changed(_skill_ids: Array) -> void:
	_pending_event_count += 1

func _on_respec_draft_changed(_skill_ids: Array) -> void:
	_respec_event_count += 1

func _on_confirm_requested(skill_ids: Array) -> void:
	_confirmed_ids.clear()
	for skill_id_var: Variant in skill_ids:
		_confirmed_ids.append(str(skill_id_var))

func _press_ui_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		event.strength = 1.0 if pressed else 0.0
		root.push_input(event)
		await process_frame
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
