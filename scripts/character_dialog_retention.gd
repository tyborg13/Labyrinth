extends RefCounted

# Keep the actual dialog chrome in its final parent. Exact mode/viewport/scale
# guards belong to the caller; validate every owned control before mutating it.
static func refresh_header(scene: Node, previous: Dictionary, current: Dictionary) -> bool:
	var dialog: Control = scene._upgrade_dialog
	var frame: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	var tabs: Control = dialog.find_child("CharacterTabs", true, false) as Control
	var summary: Control = dialog.find_child("ProgressionOverlaySummary", true, false) as Control
	if frame == null or tabs == null or summary == null or not frame.get_parent() is VBoxContainer: return false
	var column: VBoxContainer = frame.get_parent()
	if tabs.get_parent() != column or not is_instance_valid(scene._progression_level_label) or not dialog.is_ancestor_of(scene._progression_level_label): return false
	for label: Variant in [scene._progression_skill_points_label, scene._progression_moltshards_label, scene._progression_defiance_label]:
		if not is_instance_valid(label) or not summary.is_ancestor_of(label): return false
	if previous.get("header") == current.get("header"): return true
	scene._refresh_progression_resource_summary()
	var notice: Label = dialog.find_child("ProgressionOverlayNotice", true, false) as Label
	# Skill learning also retires notices through the scene's deferred cleanup.
	# Never revive a named label already scheduled for end-of-frame deletion.
	if notice != null and notice.is_queued_for_deletion():
		_retire(scene, notice)
		notice = null
	if scene._progression_overlay_notice.is_empty():
		if notice != null: _retire(scene, notice)
	else:
		if notice == null:
			notice = Label.new()
			notice.name = "ProgressionOverlayNotice"
			notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			preload("res://scripts/ui_typography.gd").apply_label_role(notice, preload("res://scripts/ui_typography.gd").ROLE_CAPTION)
			column.add_child(notice)
			column.move_child(notice, 1)
		notice.text = scene._progression_overlay_notice
		notice.add_theme_color_override("font_color", Color("ef9a8f") if scene._progression_overlay_notice_is_error else Color("f0c978"))
	# Only the unread identities affect tabs while mode is unchanged. Recreate
	# that small authored row if badges/callback targets need reconciliation.
	var before: Array = previous["header"]
	var after: Array = current["header"]
	if before[7] != after[7] or before[8] != after[8]:
		var index: int = tabs.get_index()
		_retire(scene, tabs)
		var replacement: Control = scene._build_character_overlay_tabs()
		column.add_child(replacement)
		column.move_child(replacement, index)
	return true

# Keep the live rig, final paper-doll parent and unchanged native sockets.
# Validate the entire eligible subtree before updating any control. Catalog,
# item/interaction or malformed-owner changes take the original column builder.
static func refresh_equipment_loadout(scene: Node, panel: Control, previous: Dictionary, current: Dictionary) -> bool:
	# Drag highlights stay active until the authored swap animation finishes.
	# The original rebuild resets them immediately, so retain no such subtree.
	if not scene._equipment_drag_id.is_empty(): return false
	if previous.get("definitions") != current.get("definitions"): return false
	var before: Dictionary = previous["state"]
	var after: Dictionary = current["state"]
	if before.get("equipped_items", []) != after.get("equipped_items", []): return false
	if scene._run_engine.can_change_equipment(before) != scene._run_engine.can_change_equipment(after): return false
	if scene._run_engine.can_change_items(before) != scene._run_engine.can_change_items(after): return false
	if scene._run_engine.loadout_unread_ids(before, "equipment") != scene._run_engine.loadout_unread_ids(after, "equipment"): return false
	if not scene._character_dialog_can_retain(panel): return false
	var list: VBoxContainer = panel.find_child("EquipmentLoadoutList", true, false) as VBoxContainer
	var doll: Control = panel.find_child("CharacterPaperDoll", true, false) as Control
	var art: TextureRect = panel.find_child("EquipmentCharacterArt", true, false) as TextureRect
	var items: Control = panel.find_child("CharacterEquippedItems", true, false) as Control
	if list == null or doll == null or art == null or items == null or list.get_child_count() != 2 or list.get_child(0) != doll or list.get_child(1) != items or art.get_parent() != doll: return false
	var cutout: Node = art.get_node_or_null("EquipmentCutout")
	if not is_instance_valid(cutout) or cutout.is_queued_for_deletion() or cutout.get_script() != preload("res://scripts/protagonist_cutout/renderer.gd"): return false
	var slots: Dictionary = doll.get_meta("character_doll_slots", {})
	var before_equipment: Dictionary = before.get("equipped_equipment", {})
	var after_equipment: Dictionary = after.get("equipped_equipment", {})
	for slot: String in preload("res://scripts/game_data.gd").equipment_slots():
		var tile: Variant = slots.get(slot)
		if not is_instance_valid(tile) or tile.is_queued_for_deletion() or tile.get_parent() != doll or scene._equipment_slot_panels.get(slot) != tile or tile.get("slot_id") != slot or tile.get("equipment_id") != str(before_equipment.get(slot, "")): return false
		if doll.get_node_or_null("%sSlotCaption" % slot.capitalize()) == null: return false
	for slot: String in preload("res://scripts/game_data.gd").equipment_slots():
		if str(before_equipment.get(slot, "")) == str(after_equipment.get(slot, "")): continue
		var old: Control = slots[slot]
		var position: Vector2 = old.position
		var size: Vector2 = old.size
		var index: int = old.get_index()
		var replacement: Control = scene._build_equipment_slot_panel(slot, str(after_equipment.get(slot, "")))
		_retire(scene, old)
		slots[slot] = replacement
		doll.add_child(replacement)
		doll.move_child(replacement, index)
		replacement.position = position
		replacement.size = size
	art.modulate = scene._equipment_player_art_tint()
	# A fresh original portrait starts this same idle pose on every changed
	# column. Reset that phase while retaining the ready rig and texture RID.
	cutout._idle_seconds = 0.0
	cutout.present({}, scene._reduced_motion_enabled())
	var scroll: ScrollContainer = panel.find_child("EquipmentLoadoutScroll", true, false) as ScrollContainer
	if scroll != null:
		scroll.scroll_horizontal = 0
		scroll.scroll_vertical = 0
	return true

static func refresh_skills(scene: Node, previous: Dictionary, current: Dictionary) -> bool:
	var dialog: Control = scene._upgrade_dialog
	var frame: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	if frame == null or frame.get_child_count() != 1: return false
	var body: Node = frame.get_child(0)
	if body.name != "SkillTreeOverlayBody" or not is_instance_valid(scene._skill_tree_view) or scene._skill_tree_view.get_parent() != body: return false
	if not is_instance_valid(scene._skill_reset_button) or not body.is_ancestor_of(scene._skill_reset_button): return false
	# The original builder always retains the graph, including its authored
	# node transforms. Validate chrome motion without treating graph zoom or
	# focused-node scale as a reason to destroy the surrounding controls.
	if not scene._character_row_can_retain(dialog) or not scene._character_row_can_retain(frame) or not scene._character_row_can_retain(scene._skill_reset_button): return false
	if not refresh_header(scene, previous, current): return false
	scene._character_inventory_rows.release_focus(dialog)
	scene._skill_tree_view.configure({
		"mode": preload("res://scripts/skill_tree_view.gd").MODE_VIEW,
		"owned_ids": preload("res://scripts/progression_store.gd").selected_skill_ids(scene._progression),
		"required_count": preload("res://scripts/progression_store.gd").skill_points_for_level(int(scene._progression.get("level", 1))),
		"unspent_points": preload("res://scripts/progression_store.gd").unspent_skill_points(scene._progression),
		"editing_enabled": scene._skill_editing_can_edit(),
		"focused_id": scene._progression_focused_skill_id,
	})
	scene._skill_reset_button.text = scene._skill_reset_button_text()
	scene._skill_reset_button.disabled = not scene._skill_reset_can_apply()
	scene._skill_reset_button.tooltip_text = scene._skill_reset_unavailable_reason()
	scene._apply_progression_command_button_style(scene._skill_reset_button)
	preload("res://scripts/ui_typography.gd").apply_button_role(scene._skill_reset_button, preload("res://scripts/ui_typography.gd").ROLE_BODY)
	scene._skill_tree_view.set_external_focus_targets(dialog.find_child("CharacterSkillsTab", true, false), scene._skill_reset_button)
	scene._skill_tree_view.call_deferred("grab_tree_focus")
	return true

static func _retire(scene: Node, control: Control) -> void:
	# Retired names must leave the live hierarchy synchronously. Another
	# committed refresh can run before the end-of-frame deletion flush.
	scene._prepare_node_for_immediate_free(control)
	if control.get_parent() != null: control.get_parent().remove_child(control)
	control.queue_free()
