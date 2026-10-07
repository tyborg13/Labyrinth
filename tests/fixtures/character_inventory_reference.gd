extends "res://scripts/run_scene.gd"

# Independent constructors and whole-dialog rebuild copied from baseline
# 1eeead41087e11e64609f266e33508d0357efe25. Optional arguments only
# adapt signatures; this reference bypasses all Character retention.

func _rebuild_progression_overlay() -> void:
	# Inventory refreshes rebuild synchronously; only explicit open/tab actions
	# start an arrival, so committed changes never replay menu motion.
	_stop_character_menu_arrival()
	if _upgrade_dialog == null:
		return
	_clear_controller_loadout_tooltip()
	var performance_phase_started: int = Time.get_ticks_usec() if _runtime_performance_instrumentation_enabled else 0
	_sync_progression_from_run()
	performance_phase_started = _record_runtime_performance_phase("character_sync", performance_phase_started)
	# Preserve the graph while rebuilding the much smaller surrounding chrome.
	# Keep it owned by this scene under a hidden host across other Character tabs.
	if is_instance_valid(_skill_tree_view):
		_skill_tree_view.clear_external_focus_targets()
		if _retained_skill_tree_host == null:
			_retained_skill_tree_host = Control.new()
			_retained_skill_tree_host.name = "RetainedSkillTreeHost"
			_retained_skill_tree_host.visible = false
			_retained_skill_tree_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(_retained_skill_tree_host)
		if _skill_tree_view.get_parent() != _retained_skill_tree_host:
			_skill_tree_view.reparent(_retained_skill_tree_host, false)
	_clear_children_now(_upgrade_dialog)
	_layout_progression_dialog()
	performance_phase_started = _record_runtime_performance_phase("character_clear_layout", performance_phase_started)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_top", int(UiTypography.PANEL_PADDING))
	margin.add_theme_constant_override("margin_right", int(UiTypography.PANEL_PADDING_LARGE))
	margin.add_theme_constant_override("margin_bottom", int(UiTypography.PANEL_PADDING))
	_upgrade_dialog.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", UiTypography.SPACE_LARGE)
	margin.add_child(vbox)

	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", UiTypography.SPACE_MEDIUM)
	vbox.add_child(top_row)

	const Menu = preload("res://scripts/character_menu_view.gd")
	var title_block := Menu.title_block()
	top_row.add_child(title_block)
	_progression_level_label = title_block.get_node("ProgressionLevelLabel") as Label
	top_row.add_child(_build_progression_resource_summary())
	var close_button := Menu.close_socket()
	close_button.pressed.connect(_on_progression_overlay_close_pressed)
	top_row.add_child(close_button)

	if not _progression_overlay_notice.is_empty():
		var notice_label := Label.new()
		notice_label.name = "ProgressionOverlayNotice"
		notice_label.text = _progression_overlay_notice
		notice_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UiTypography.apply_label_role(notice_label, UiTypography.ROLE_CAPTION)
		notice_label.add_theme_color_override(
			"font_color",
			Color("ef9a8f") if _progression_overlay_notice_is_error else Color("f0c978")
		)
		vbox.add_child(notice_label)

	vbox.add_child(_build_character_overlay_tabs())
	performance_phase_started = _record_runtime_performance_phase("character_chrome", performance_phase_started)

	if _progression_overlay_mode == "equipment":
		vbox.add_child(_build_equipment_overlay_body())
	elif _progression_overlay_mode == "magic":
		vbox.add_child(_build_magic_overlay_body())
	else:
		vbox.add_child(_build_skill_tree_overlay_body())
	performance_phase_started = _record_runtime_performance_phase("character_body", performance_phase_started)
	Menu.finish_dialog(_upgrade_dialog)
	# A freshly built auto-wrapping detail panel can briefly report its minimum
	# height before receiving its final width. CenterContainer preserves that
	# transient growth in its offsets, so refit once layout has settled.
	_fit_progression_modal_to_viewport()
	call_deferred("_fit_progression_modal_to_viewport")
	_progression_overlay_cached_mode = _progression_overlay_mode
	_progression_overlay_content_signature = _progression_overlay_signature()
	_record_runtime_performance_phase("character_finish", performance_phase_started)

func _build_equipment_inventory_column(_keep_parent: bool = false) -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var inventory_ids: Array = _equipment_inventory_ids()
	var item_ids: Array = _item_inventory_ids()
	var panel := Menu.column("EquipmentInventoryPanel", 400.0, "PACK", "%d gear · %d items" % [inventory_ids.size(), item_ids.size()])
	var list := Menu.scroll_list(panel)
	var gear_rows := VBoxContainer.new()
	gear_rows.name = "EquipmentInventoryRows"
	gear_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gear_rows.add_theme_constant_override("separation", 8)
	list.add_child(gear_rows)
	if inventory_ids.is_empty():
		gear_rows.add_child(Menu.empty_copy("No spare gear"))
	else:
		for equipment_id: Variant in inventory_ids:
			gear_rows.add_child(_build_equipment_inventory_tile(str(equipment_id)))
	var item_rows := VBoxContainer.new()
	item_rows.name = "ItemInventoryRows"
	item_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item_rows.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_rows.add_theme_constant_override("separation", 8)
	list.add_child(item_rows)
	_item_inventory_drop_panel = item_rows
	if item_ids.is_empty():
		item_rows.add_child(Menu.empty_copy("No consumables"))
	else:
		for index: int in range(item_ids.size()):
			item_rows.add_child(_build_item_card_tile(str(item_ids[index]), "inventory", index))
	return panel

func _build_magic_attuned_column(_keep_parent: bool = false) -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var attuned: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	var panel := Menu.column("MagicAttunedPanel", 420.0, "ATTUNED MAGIC", "%d / %d" % [mini(attuned.size(), GameData.magic_loadout_limit()), GameData.magic_loadout_limit()])
	_magic_attuned_drop_panel = panel
	var slots := Menu.scroll_list(panel)
	for index: int in range(GameData.magic_loadout_limit()):
		var card_id: String = str(attuned[index]) if index < attuned.size() else ""
		slots.add_child(_build_magic_card_tile(card_id, "attuned", index))
	if not _magic_overlay_can_change():
		slots.add_child(Menu.label("Locked in combat", 14, UiPalette.TEXT_2))
	return panel

func _build_magic_inventory_column(_keep_parent: bool = false) -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var reserve: Array = (_run_state.get("magic_inventory", []) as Array).duplicate()
	var panel := Menu.column("MagicInventoryPanel", 400.0, "LEARNED MAGIC", str(reserve.size()))
	_magic_inventory_drop_panel = panel
	var slots := Menu.scroll_list(panel)
	if reserve.is_empty():
		slots.add_child(Menu.empty_copy("No learned magic"))
	else:
		for index: int in range(reserve.size()):
			slots.add_child(_build_magic_card_tile(str(reserve[index]), "inventory", index))
	return panel

func _build_equipment_inventory_tile(equipment_id: String, _retention_key: String = "") -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var item: Dictionary = GameData.equipment_def(equipment_id)
	var tile := EquipmentInventoryTile.new()
	tile.equipment_id = equipment_id
	tile.host = self
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = "equipment:%s" % equipment_id
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _equipment_overlay_can_change() else Control.CURSOR_ARROW
	tile.add_theme_stylebox_override("panel", Menu.row_style())
	_configure_controller_loadout_focus(tile, UiPalette.GOLD)
	tile.add_child(Menu.row_body(AssetLoader.load_texture(str(item.get("icon_path", ""))), "%s · %s" % [_equipment_slot_label(GameData.equipment_slot(equipment_id)), _equipment_rarity_label(GameData.equipment_rarity(equipment_id))], str(item.get("name", equipment_id)), _equipment_card_summary(equipment_id)))
	Menu.pack_actions(tile, self, _equip_equipment_from_overlay.bind(equipment_id), _equipment_overlay_can_change())
	_equipment_inventory_tiles[equipment_id] = tile
	_add_loadout_new_tag(tile, "equipment", equipment_id)
	if not _equipment_overlay_can_change():
		tile.modulate = Color(0.72, 0.72, 0.72, 1.0)
	return tile

func _build_magic_card_tile(card_id: String, source_kind: String, index: int, _retention_key: String = "") -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var tile := MagicCardTile.new()
	tile.card_id = card_id
	tile.host = self
	tile.source_kind = source_kind
	tile.magic_index = index
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.custom_minimum_size.y = UiTypography.scaled_value(self, 34.0)
	tile.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if card_id.is_empty():
		Menu.empty_strip(tile)
		return tile
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = "card:%s" % card_id
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _magic_overlay_can_change() else Control.CURSOR_ARROW
	var strip := Menu.strip_content(card_id, 1, 34.0)
	strip.locked = not _magic_overlay_can_change()
	tile.add_child(strip)
	_configure_controller_loadout_focus(tile, UiPalette.GOLD)
	if source_kind == "attuned":
		_magic_attuned_tiles[index] = tile
	else:
		_magic_inventory_tiles[index] = tile
	_add_loadout_new_tag(tile, "magic", card_id)
	return tile

func _build_item_card_tile(card_id: String, source_kind: String, index: int, _retention_key: String = "") -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	if card_id.is_empty():
		var empty := PanelContainer.new()
		empty.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		Menu.empty_row(empty, "Empty item slot")
		if source_kind == "equipped":
			_item_equipped_tiles[index] = empty
		return empty
	var tile := ItemCardTile.new()
	tile.card_id = card_id
	tile.host = self
	tile.source_kind = source_kind
	tile.item_index = index
	tile.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tile.mouse_filter = Control.MOUSE_FILTER_STOP
	tile.focus_mode = Control.FOCUS_ALL
	tile.tooltip_text = "card:%s" % card_id
	tile.mouse_default_cursor_shape = Control.CURSOR_DRAG if _item_overlay_can_change() else Control.CURSOR_ARROW
	tile.add_theme_stylebox_override("panel", Menu.row_style())
	tile.add_child(_build_item_card_tile_body(card_id))
	_configure_controller_loadout_focus(tile, UiPalette.GOLD)
	if source_kind == "equipped":
		_item_equipped_tiles[index] = tile
	else:
		_item_inventory_tiles[index] = tile
		Menu.pack_actions(tile, self, _equip_item_from_overlay.bind(index), _item_overlay_can_change())
	_add_loadout_new_tag(tile, "equipment", card_id)
	return tile


# Frozen original deck constructor. The optional parameter only adapts the
# live builder signature; every original construction step stays unchanged.
func _build_current_deck_column(_keep_parent: bool = false) -> Control:
	const Menu = preload("res://scripts/character_menu_view.gd")
	var attuned: Array = (_run_state.get("attuned_magic_cards", []) as Array).duplicate()
	var items: Array = (_run_state.get("equipped_items", []) as Array).duplicate()
	var equipped: Dictionary = _run_state.get("equipped_equipment", {}) as Dictionary
	var card_count: int = attuned.size() + items.size()
	for slot: String in GameData.equipment_slots():
		card_count += GameData.equipment_cards(str(equipped.get(slot, "")), _run_state).size()
	var panel := Menu.column("CurrentDeckPanel", 0.0, "DECK", "%d cards" % card_count)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var list := Menu.scroll_list(panel)
	list.add_child(_build_attuned_magic_deck_group(attuned))
	list.add_child(_build_equipped_items_deck_group(items))
	for slot: String in GameData.equipment_slots():
		var equipment_id: String = str(equipped.get(slot, ""))
		if not equipment_id.is_empty():
			list.add_child(_build_equipment_deck_group(equipment_id, _equipment_slot_label(slot)))
	return panel

