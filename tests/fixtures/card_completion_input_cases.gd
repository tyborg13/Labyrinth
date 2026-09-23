extends RefCounted

# Native correctness helper for card_completion_stall_probe.gd. Assertions use
# real routed input and transformed card bounds; no pointer repair follows the
# mutation being tested. run_core() is useful while extending the broader cases.
const ActionIcons = preload("res://scripts/action_icon_library.gd")

var _tree: SceneTree
var _scene: Node
var _checks: int = 0
var _errors: Array[String]
var _cases: Array[Dictionary]

func run(tree: SceneTree, scene: Node) -> Dictionary:
	await run_core(tree, scene)
	await _case_pooled_round_trip()
	await _case_wrapper_cancel()
	await _case_resize_restore()
	await _case_offhand_clear()
	return {"checks": _checks, "errors": _errors.duplicate(), "cases": _cases.duplicate(true)}

func run_core(tree: SceneTree, scene: Node) -> Dictionary:
	_tree = tree
	_scene = scene
	_checks = 0
	_errors.clear()
	_cases.clear()
	_tree.set("_native_pointer_instance", null)
	_check(not bool(_scene.call("_reduced_motion_enabled")), "normal authored motion is enabled")
	await _case_unlocked_full_rebuild()
	await _case_retained_identity("remove_earlier", false)
	await _case_retained_identity("reorder_earlier", true)
	return {"checks": _checks, "errors": _errors.duplicate(), "cases": _cases.duplicate(true)}

func _check(condition: bool, message: String) -> void:
	_checks += 1
	if not condition:
		_errors.append(message)
	_tree.call("_expect", condition, "completion input: " + message)

func _settle() -> void:
	await _tree.call("_settle_native_hand_pointer", _scene)

func _prepare() -> void:
	_tree.set("_native_pointer_instance", null)
	_tree.call("_install_stress_combat", _scene, "specialists")
	_tree.call("_move_native_hand_pointer", Vector2(8.0, 8.0))
	await _settle()
	_check(not bool(_scene.get("_animation_lock")), "fixture starts unlocked")
	_check(_hand_cards().size() == 7, "fixture starts with seven cards")

func _hand() -> Control:
	return _scene.get("hand_box") as Control

func _hand_cards() -> Array:
	var state: Dictionary = _scene.get("_combat_state") as Dictionary
	return ((state.get("deck", {}) as Dictionary).get("hand", []) as Array).duplicate()

func _widget(index: int) -> Control:
	return _scene.call("_hand_card_control", index) as Control

func _geometric_hits(point: Vector2) -> Array[int]:
	var hits: Array[int]
	for index: int in range(_hand().get_child_count()):
		var widget: Control = _widget(index)
		if widget == null or not widget.is_visible_in_tree():
			continue
		var local_point: Vector2 = widget.get_global_transform_with_canvas().affine_inverse() * point
		if Rect2(Vector2.ZERO, widget.size).has_point(local_point):
			hits.append(index)
	return hits

func _route_owner_index() -> int:
	var routed: Control = _tree.root.gui_get_hovered_control()
	if routed == null:
		return -1
	for index: int in range(_hand().get_child_count()):
		var widget: Control = _widget(index)
		var slot: Node = _hand().get_child(index)
		if (widget != null and (routed == widget or widget.is_ancestor_of(routed))) or routed == slot or slot.is_ancestor_of(routed):
			return index
	return -1

func _unique_point(index: int, lifted: bool) -> Vector2:
	var widget: Control = _widget(index)
	var fractions: Array = [Vector2(0.25, 0.06), Vector2(0.35, 0.08), Vector2(0.5, 0.08), Vector2(0.5, 0.18)] if lifted else [Vector2(0.5, 0.3), Vector2(0.5, 0.5), Vector2(0.6, 0.35), Vector2(0.4, 0.35)]
	for fraction: Vector2 in fractions:
		var point: Vector2 = widget.get_global_transform_with_canvas() * (widget.size * fraction)
		var hits: Array[int] = _geometric_hits(point)
		if _tree.root.get_visible_rect().has_point(point) and hits.size() == 1 and hits[0] == index:
			return point
	return Vector2.INF

func _park_middle(label: String) -> Control:
	var index: int = int(_hand().get_child_count() / 2)
	var first_point: Vector2 = _unique_point(index, false)
	_check(first_point.is_finite(), label + ": middle card has a unique visible setup point")
	if not first_point.is_finite():
		_record(label + "/invalid_anchor")
		return null
	_tree.call("_move_native_hand_pointer", first_point)
	await _settle()
	_assert_pointer_truth(label + "/initial_hover", true)
	# A second setup motion enters the lifted upper portion. It leaves more
	# exposed area when an earlier card is removed; no motion follows mutation.
	var lifted_point: Vector2 = _unique_point(index, true)
	_check(lifted_point.is_finite(), label + ": emphasized card has a unique visible setup point")
	if not lifted_point.is_finite():
		_record(label + "/invalid_lifted_anchor")
		return null
	_tree.call("_move_native_hand_pointer", lifted_point)
	await _settle()
	_assert_pointer_truth(label + "/before", true)
	return _widget(index)

func _pointer_stamp() -> Dictionary:
	return {"viewport": _tree.root.get_mouse_position(), "display": DisplayServer.mouse_get_position()}

func _assert_stationary(stamp: Dictionary, label: String) -> void:
	var prior_viewport: Vector2 = stamp["viewport"]
	var prior_display: Vector2i = stamp["display"]
	_check(_tree.root.get_mouse_position().distance_to(prior_viewport) <= 2.0, label + ": routed pointer stayed stationary")
	_check(Vector2(DisplayServer.mouse_get_position()).distance_to(Vector2(prior_display)) <= 2.0, label + ": physical pointer stayed stationary")

func _record(label: String) -> void:
	var snapshot: Dictionary = _tree.call("_native_hand_pointer_diagnostic_snapshot", _scene)
	_cases.append({"label": label, "geometric_hits": _geometric_hits(_tree.root.get_mouse_position()), "route_owner_index": _route_owner_index(), "snapshot": snapshot})

func _expected_tooltip_icons(index: int) -> Array[String]:
	var state: Dictionary = _scene.get("_combat_state") as Dictionary
	var cards: Array = _hand_cards()
	var card: Dictionary = _scene.call("_card_def", str(cards[index]), state)
	var display: Dictionary = _scene.call("_card_widget_display_for_index", index)
	var leading: Array
	if int(card.get("time", 0)) > 0:
		leading.append("time")
	var icons: Array[String]
	for entry: Dictionary in ActionIcons.tooltip_entries_for_rows(display.get("summary_rows", []) as Array, leading):
		if entry.get("texture", null) != null:
			icons.append(str(entry.get("icon", "")))
	return icons

func _assert_pointer_truth(label: String, require_unique: bool) -> void:
	_record(label)
	var hits: Array[int] = _geometric_hits(_tree.root.get_mouse_position())
	_check(hits.size() == 1 if require_unique else hits.size() <= 1, label + ": pointer geometry has an unambiguous expected card")
	if hits.size() > 1 or (require_unique and hits.is_empty()):
		return
	var expected: int = hits[0] if not hits.is_empty() else -1
	_check(_route_owner_index() == expected, label + ": router ancestor-owning card agrees with geometry")
	_check(int(_scene.get("_hovered_card_index")) == expected, label + ": global hover agrees with geometry")
	_check(int(_hand().call("emphasized_index")) == expected, label + ": emphasized index agrees with geometry")
	var expected_strength: float = 1.0 if expected >= 0 else 0.0
	_check(is_equal_approx(float(_hand().call("emphasis_strength")), expected_strength), label + ": authored emphasis tween has settled")
	for index: int in range(_hand().get_child_count()):
		var widget: Control = _widget(index)
		_check(bool(widget.get("_local_hovered")) == (index == expected), label + ": local hover for card %d agrees with geometry" % index)
		_check(widget.mouse_filter == Control.MOUSE_FILTER_STOP, label + ": ordinary card %d accepts native input" % index)
		_check(widget.size.is_equal_approx(Vector2(250.0, 352.0)), label + ": card %d retains native inner geometry" % index)
	var tooltip: Control = _scene.get("_card_focus_tooltip_stack") as Control
	if tooltip != null:
		var expected_icons: Array[String]
		if expected >= 0:
			expected_icons = _expected_tooltip_icons(expected)
		_check((tooltip.call("entry_icon_keys") as Array) == expected_icons, label + ": tooltip icons identify the geometrically hovered card")
		if not expected_icons.is_empty():
			_check(tooltip.get("_follow_target") == _widget(expected), label + ": tooltip follows the geometrically hovered widget")
		else:
			_check(not tooltip.visible, label + ": empty tooltip is hidden")

func _replace_hand(cards: Array) -> void:
	# Fixture-only state mutation isolates the production hand rebuilding
	# boundary. It is not a substitute for an actual gameplay draw/play proof.
	var state: Dictionary = (_scene.get("_combat_state") as Dictionary).duplicate(true)
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = cards.duplicate()
	state["deck"] = deck
	_scene.set("_combat_state", state)
	var run_state: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = state
	_scene.set("_run_state", run_state)
	_scene.call("_mark_combat_preview_state_changed")
	_scene.set("_hand_panel_signature", "completion input fixture invalidation")
	_scene.call("_refresh_hand_panel")

func _case_unlocked_full_rebuild() -> void:
	await _prepare()
	var target: Control = await _park_middle("unlocked_full_rebuild")
	if target == null:
		return
	var stamp: Dictionary = _pointer_stamp()
	_scene.set("_hand_panel_content_signature", "completion input content invalidation")
	_scene.set("_hand_panel_signature", "completion input signature invalidation")
	_scene.call("_refresh_hand_panel")
	await _settle()
	_assert_stationary(stamp, "unlocked_full_rebuild")
	_check(_widget(3) == target, "unlocked_full_rebuild: live middle widget is retained")
	_assert_pointer_truth("unlocked_full_rebuild/after", true)

func _case_retained_identity(label: String, reorder_only: bool) -> void:
	await _prepare()
	var target: Control = await _park_middle(label)
	if target == null:
		return
	var stamp: Dictionary = _pointer_stamp()
	var cards: Array = _hand_cards()
	var first: Variant = cards.pop_front()
	if reorder_only:
		cards.append(first)
	_replace_hand(cards)
	await _settle()
	_assert_stationary(stamp, label)
	_check(_widget(2) == target, label + ": same middle widget survives at its new index")
	_assert_pointer_truth(label + "/after", false)

func _case_pooled_round_trip() -> void:
	await _prepare()
	var target: Control = await _park_middle("pool_round_trip")
	if target == null:
		return
	var stamp: Dictionary = _pointer_stamp()
	var original: Array = _hand_cards()
	var pooled_widget: Control = _widget(6)
	var reduced: Array = original.duplicate()
	reduced.pop_back()
	_replace_hand(reduced)
	await _settle()
	_check(_hand().get_child_count() == 6, "pool_round_trip: removal leaves six cards")
	_check(_widget(3) == target, "pool_round_trip: unrelated middle widget survives removal")
	_assert_stationary(stamp, "pool_round_trip/remove")
	_assert_pointer_truth("pool_round_trip/six_cards", false)
	_replace_hand(original)
	await _settle()
	_check(_hand().get_child_count() == 7, "pool_round_trip: return restores seven cards")
	_check(_widget(6) == pooled_widget, "pool_round_trip: returned card reuses released pooled widget")
	_check(_widget(3) == target, "pool_round_trip: unrelated middle widget survives return")
	_assert_stationary(stamp, "pool_round_trip/return")
	_assert_pointer_truth("pool_round_trip/seven_cards", false)

func _case_wrapper_cancel() -> void:
	await _prepare()
	var target: Control = await _park_middle("wrapper_cancel")
	if target == null:
		return
	var stamp: Dictionary = _pointer_stamp()
	_scene.call("_begin_quick_wits_card_selection", "quick_wits")
	await _settle()
	_check(str(_scene.get("_combat_skill_card_selection_zone")) == "hand", "wrapper_cancel: Quick Wits opens hand selection")
	for index: int in range(_hand().get_child_count()):
		var button: Button = _hand().get_child(index) as Button
		_check(button != null and not button.disabled, "wrapper_cancel: card %d has an enabled selection wrapper" % index)
	_record("wrapper_cancel/wrapped")
	_scene.call("_cancel_combat_skill_card_selection")
	await _settle()
	_check(str(_scene.get("_combat_skill_card_selection_zone")).is_empty(), "wrapper_cancel: cancellation leaves selection mode")
	_assert_stationary(stamp, "wrapper_cancel")
	_assert_pointer_truth("wrapper_cancel/after", false)

func _case_resize_restore() -> void:
	await _prepare()
	var target: Control = await _park_middle("resize_restore")
	if target == null:
		return
	var authored_size: Vector2i = _tree.root.size
	_tree.root.size = Vector2i(1728, 972)
	await _settle()
	# Window managers may reposition the physical window. Record both coordinate
	# spaces and assess the actual pointer rather than injecting repair motion.
	_assert_pointer_truth("resize_restore/smaller", false)
	_tree.root.size = authored_size
	await _settle()
	_check(_tree.root.size == authored_size, "resize_restore: authored resolution restored")
	_assert_pointer_truth("resize_restore/restored", true)

func _case_offhand_clear() -> void:
	await _prepare()
	var target: Control = await _park_middle("offhand_clear")
	if target == null:
		return
	_tree.call("_move_native_hand_pointer", Vector2(8.0, 8.0))
	await _settle()
	_check(_geometric_hits(_tree.root.get_mouse_position()).is_empty(), "offhand_clear: pointer moved outside all cards")
	_assert_pointer_truth("offhand_clear/after", false)
