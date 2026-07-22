extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SkillTreeLibrary = preload("res://scripts/skill_tree_library.gd")
const SkillTreeView = preload("res://scripts/skill_tree_view.gd")

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
	_expect(view.graph_canvas_size() == Vector2(730.0, 344.0), "The graph should expose a stable readable canvas size")
	_expect(view.find_child("SkillTreeScroll", true, false) is ScrollContainer, "The graph should remain scrollable in a smaller host")
	_expect(view.find_child("SkillDetailPanel", true, false) is PanelContainer, "The tree should provide its own detail panel")
	_expect(view.legend_state_count() == 5, "The tree should provide an explicit legend for every persistent node state")
	_expect(_label_with_text(view, "Prismatic Instinct") != null, "Long skill names should render in full instead of being ellipsized")
	_expect(view.status_for_skill("quick_wits") == SkillTreeView.STATE_OWNED, "Committed skills should render as learned")
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_AVAILABLE, "Legal roots should render as available")
	_expect(view.status_for_skill("borrowed_time") == SkillTreeView.STATE_LOCKED, "Missing prerequisites should render as locked")
	var quick_node: Button = view.node_for_skill("quick_wits")
	var measured_node: Button = view.node_for_skill("measured_breath")
	_expect(quick_node != null and measured_node != null and measured_node.position.x > quick_node.position.x, "Data positions should map roots into four distinct columns")
	var encore_node: Button = view.node_for_skill("encore")
	_expect(encore_node != null and quick_node != null and encore_node.position.y > quick_node.position.y, "Keystones should render below their earlier tiers")

	view.focus_skill("measured_breath")
	_expect(view.visual_state_for_skill("measured_breath") == SkillTreeView.STATE_SELECTED, "Focused nodes should expose the selected visual state")
	_expect(view.detail_title_text() == "Measured Breath", "Node focus should update the detail title")
	_expect(view.detail_action_is_enabled(), "A legal level-up choice should expose an enabled detail action")
	view.activate_focused_skill()
	_expect(view.pending_skill_ids() == ["measured_breath"], "Level-up mode should retain one pending skill")
	_expect(view.status_for_skill("measured_breath") == SkillTreeView.STATE_PENDING, "The chosen level-up node should render as pending")
	_expect(_observed_level_choice == "measured_breath", "Level-up mode should emit the chosen skill id")
	_expect(view.confirm_is_enabled(), "A legal pending level-up choice should enable confirmation")
	view.request_confirm()
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
	_expect(view.focused_skill_id() == "quick_wits", "An empty replacement draft should automatically focus the first available root")
	_expect(view.detail_title_text() == "Quick Wits" and view.detail_action_is_enabled(), "The default empty-draft focus should expose an actionable root detail")
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
	view.focus_skill("ghost_stride")
	_expect(view.status_for_skill("ghost_stride") == SkillTreeView.STATE_AVAILABLE, "An otherwise legal root should remain visibly available at the point cap")
	_expect(not view.detail_action_is_enabled(), "The view should hard-cap additions when no skill points remain")
	view.focus_skill("quick_wits")
	_expect(not view.detail_action_is_enabled(), "A prerequisite with drafted dependents should require removing its dependents first")
	view.focus_skill("carry_the_guard")
	_expect(view.detail_action_is_enabled(), "A drafted leaf should refund its point")
	view.activate_focused_skill()
	_expect(view.pending_skill_ids().size() == 4 and view.points_remaining() == 1, "Removing a drafted leaf should refund exactly one point")
	view.focus_skill("ghost_stride")
	_expect(view.detail_action_is_enabled(), "A refunded point should make an available replacement root addable")
	view.activate_focused_skill()
	_expect(view.pending_skill_ids().size() == 5, "Spending the refunded point should restore the required draft size")
	_expect(view.status_for_skill("ghost_stride") == SkillTreeView.STATE_PENDING, "A newly allocated skill should render as drafted")
	_expect(SkillTreeLibrary.selection_is_valid(view.pending_skill_ids(), 5), "The edited respec draft should remain topologically legal")
	_expect(view.confirm_is_enabled(), "A changed legal respec draft with a resource should be confirmable")
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
	_expect(view.status_for_skill("open_arsenal") == SkillTreeView.STATE_EXCLUDED, "Other keystones should expose an excluded state after one is learned")
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
