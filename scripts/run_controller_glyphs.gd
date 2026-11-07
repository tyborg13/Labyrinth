extends Node
## In-run bindings only. The title menu retains its own prompt bar.
const Badge = preload("res://scripts/controller_glyph_badge.gd")
const Router = preload("res://scripts/input_router.gd")
const Empower = preload("res://scripts/card_empower_controller.gd")
const LandingStrip = preload("res://scripts/turn_order_landing_strip.gd")
const BADGE_Z_INDEX: int = 10

var scene: Control
var _badges: Dictionary = {}
var _used: Dictionary = {}
var _context_signature: Array = []

func _process(_delta: float) -> void:
	if not is_instance_valid(scene): return
	var scope: Control = scene._controller_focus_scope()
	var focus: Control = scene.get_viewport().gui_get_focus_owner()
	var count: int = scene.hand_box.get_child_count()
	var first: Control = scene._hand_card_control(0) if count > 0 else null
	var last: Control = scene._hand_card_control(count - 1) if count > 0 else null
	var signature: Array = [scope, focus, scene._controller_hand_focused, scene._controller_hand_index, scene._selected_card_index, scene._drag_card_index, scene._drag_card_proxy, scene._animation_lock, count, first, last]
	if signature != _context_signature:
		_context_signature = signature
		refresh()

func refresh() -> void:
	if not is_instance_valid(scene): return
	_used.clear()
	var scope: Control = scene._controller_focus_scope()
	var combat: bool = str(scene._run_state.get("mode", "")) == "combat"
	_attach(scene.menu_button, Router.ACTION_MENU, "corner_bottom_center")
	_attach(scene._section_map_hud_button, Router.ACTION_MAP, "corner_bottom_center")
	if scope == scene.ui_root or scene._guided_tutorial_hard_gate_active():
		if combat:
			_combat()
	if scene._guided_tutorial_requires_continue():
		button(scene._contextual_combat_prompt.get("_continue_button"), Router.ACTION_ACCEPT)
	if scope != scene.ui_root and not scene._guided_tutorial_hard_gate_active():
		var back: Button = _back_button(scope)
		button(back, Router.ACTION_CANCEL)
		if scope == scene._upgrade_scrim:
			var first: Control = scope.find_child("CharacterEquipmentTab", true, false) as Control
			var last: Control = scope.find_child("CharacterSkillsTab", true, false) as Control
			var left: Control = corner(first, Router.ACTION_HAND_PREVIOUS)
			if left != null: left.mode = "corner_before"
			var right: Control = corner(last, Router.ACTION_HAND_NEXT, true)
			if right != null: right.mode = "corner_after"
		if scope == scene._graftwright_view:
			var focused: Control = scene.get_viewport().gui_get_focus_owner()
			var view: Control = scene._graftwright_view
			# Match Inspect's existing availability; inventory pickers and the
			# ritual do not accept Y. No input or selection behavior changes here.
			if scene._controller_is_active() and focused is Button and focused.has_meta("graft_card_id") and not view.busy and view._picker == null and not view._intro_open and view._inspection == null:
				_attach(focused, Router.ACTION_PASS, "corner_top_right_inset", null, focused.get("artwork") as Control)
	for key: String in _badges.keys():
		var badge: Variant = _badges[key]
		if not _used.has(key) or not is_instance_valid(badge):
			if is_instance_valid(badge):
				badge._restore_content()
				badge.get_parent().remove_child(badge)
				badge.queue_free()
			_badges.erase(key)

func _combat() -> void:
	var pass_button := scene.find_child("PassPreviewChip", true, false) as Button
	var pass_badge: Control = button(pass_button, Router.ACTION_PASS)
	var phase: String = str(scene._guided_tutorial_phase_id)
	if is_instance_valid(pass_badge) and phase == "pass_turn": pass_badge.pulse_source = scene._contextual_combat_prompt
	if scene.hand_box.get_child_count() > 0:
		var first: Control = scene._hand_card_control(0)
		var last: Control = scene._hand_card_control(scene.hand_box.get_child_count() - 1)
		# Paint outside the card hierarchy: its cost watch has a higher local Z
		# than ordinary button badges, and the fan can lift any neighbouring card.
		var toggle: Control = _attach(first, Router.ACTION_HAND_TOGGLE, "corner_anchor_before", null, scene.ui_root)
		toggle.corner_anchor = first.get_node_or_null("TimeCostBadge")
		toggle._sync()
		if scene._controller_hand_focused:
			var left: Control = _attach(first, Router.ACTION_HAND_PREVIOUS, "corner_anchor_below", null, scene.ui_root)
			left.corner_anchor = toggle
			left._sync()
			var right: Control = corner(last, Router.ACTION_HAND_NEXT, true)
			if right != null: right.mode = "corner_after"
	else:
		corner(scene.hand_scroll, Router.ACTION_HAND_TOGGLE)
	var index: int = Empower.index_for_input(scene, true)
	if Empower.available(scene, index):
		var widget: Control = scene._hand_card_control(index)
		if scene._drag_card_index >= 0 and is_instance_valid(scene._drag_card_proxy):
			widget = scene._drag_card_proxy.get_child(0) as Control
		if widget != null:
			var seal: Control = widget.get_node_or_null("EmpowerSeal")
			if seal != null: _attach(seal, Router.ACTION_EMPOWER, "seal")
	if scene._movement_undo_button != null and scene._movement_undo_button.undo_available() and not scene._guided_tutorial_hard_gate_active():
		button(scene._movement_undo_button, Router.ACTION_UNDO_MOVE)

func _back_button(scope: Control) -> Button:
	if scope == scene._pre_battle_scrim: return null # Committed encounter has no B action.
	if scope == scene._upgrade_scrim and not str(scene._controller_magic_source_kind).is_empty(): return null
	if scope == scene._menu_scrim and scene._settings_panel != null and scene._settings_panel.visible:
		return scene._settings_panel.back_button()
	if scope == scene._event_view:
		return scene._event_view.continue_button if scene._event_view.page == "result" else null
	if scope == scene._graftwright_view:
		var view: Control = scene._graftwright_view
		if view.busy: return null
		if view._inspection != null: return view._inspection.find_child("InspectionBack", true, false) as Button
		if not str(view._picker_role).is_empty(): return view._picker.find_child("PickerBack", true, false) as Button
		return view._leave
	if scope == scene._scavenger_shop_view: return scene._scavenger_shop_view._leave_button
	if scope == scene._large_map_scrim:
		var close: Button = scope.find_child("CloseButton", true, false) as Button
		if close != null and close.is_visible_in_tree(): return close
	if is_instance_valid(scene._magic_purge_overlay) and scope == scene._magic_purge_overlay.focus_scope():
		var overlay: Control = scene._magic_purge_overlay
		return overlay._confirmation.cancel_button if overlay._confirmation != null and overlay._confirmation.visible else overlay._list_cancel
	# Existing buttons only. This does not decide or invoke back navigation.
	for node: Node in scope.find_children("*", "Button", true, false):
		var control := node as Button
		if not control.is_visible_in_tree() or control.disabled: continue
		var caption: String = control.text.strip_edges().to_lower()
		if caption in ["back", "leave", "close", "cancel", "return", "skip", "continue", "x", "resume"] or control.name in ["CloseCharacterOverlay", "CloseButton"]:
			return control
	return null

func button(control: Button, action: StringName) -> Control:
	if not is_instance_valid(control): return null
	var label: Label
	for node: Node in control.find_children("*", "Label", true, false):
		if node.get_parent().get_script() == Badge: continue
		if not (node as Label).visible or (node as Label).text.is_empty(): continue
		if node.name in ["CharacterCloseGlyph", "CloseGlyph"]:
			return _attach(control, action, "symbol", node as Label)
		if node.name == "PassActionLabel" or (node as Label).text == control.text or (control.text.is_empty() and (node as Label).text == str(control.get_meta("graft_action_label", ""))):
			label = node as Label
			break
	return _attach(control, action, "symbol" if control.text in ["X", "✕"] else "button", label)

func corner(control: Control, action: StringName, right: bool = false) -> Control:
	return _attach(control, action, "corner_right" if right else "corner_left")

func _attach(control: Control, action: StringName, mode: String, label: Label = null, paint_host: Control = null) -> Control:
	if not is_instance_valid(control): return null
	var key: String = "%d:%s" % [control.get_instance_id(), action]
	_used[key] = true
	var badge: Variant = _badges.get(key)
	if not is_instance_valid(badge):
		badge = Badge.new()
		badge.configure(control, action, mode, label)
		if label != null and label.get_parent() is BoxContainer:
			var row: BoxContainer = label.get_parent()
			row.add_child(badge)
			row.move_child(badge, label.get_index())
		else:
			var parent: Control = label if label != null else paint_host if paint_host != null else control
			parent.add_child(badge)
		badge.z_index = BADGE_Z_INDEX
		if paint_host == scene.ui_root:
			# Above the whole fan, below the existing turn preview and tooltips.
			badge.z_as_relative = false
			# The strip may be switched off (ui-30); its layer still sets the order.
			badge.z_index = LandingStrip.Z_INDEX - 1
		_badges[key] = badge
	badge.pulse_source = null
	badge._sync()
	return badge

func badges_snapshot() -> Array[Dictionary]:
	var result: Array[Dictionary]
	for badge: Variant in _badges.values():
		# Headless callers have no renderer pre-draw; report the same current
		# geometry that the native frame-pre-draw attachment uses.
		if is_instance_valid(badge): badge._sync()
		if is_instance_valid(badge) and badge.is_visible_in_tree():
			result.append({"action": str(badge.action_name), "target": str(badge.target.name), "rect": badge.visual_rect(), "family": badge._glyph.family})
	return result
