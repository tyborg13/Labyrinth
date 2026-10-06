extends "res://scripts/scavenger_shop_view.gd"

# Original inventory construction used as an independent preparation oracle.
func configure(run_state: Dictionary, run_engine: RefCounted, reduced_motion: bool, _observer: Callable = Callable()) -> void:
	_run_state = run_state.duplicate(true)
	_run_engine = run_engine
	if reduced_motion and not _reduced_motion:
		for tween: Tween in _slot_tweens.values():
			if tween != null and tween.is_valid(): tween.kill()
		_slot_tweens.clear()
		for source: Control in _offer_sources.values():
			if is_instance_valid(source): source.scale = Vector2.ONE
	_reduced_motion = reduced_motion
	var next_room: Vector2i = _run_state.get("current_room", Vector2i.ZERO)
	if next_room != _room_coord:
		_clear_children(_purchase_effects)
		_room_coord = next_room
		_entry_played_for_room = false
		_selected_item_id = ""
		_selected_is_sell = false
		_selected_source = null
		_sell_page = 0
		_pack_mode = false
		_pack_filter = "all"
		_intro_open = true
		_clear_receipt()
		_sync_dialogue()
	_rebuild_inventory()
	_restore_selection_after_rebuild()
	_sync_currency()
	_sync_detail()
	_sync_mode()
	for button: Node in _canvas.find_children("*", "Button", true, false):
		if button is ShopAction or button is Ware: button.set("reduced_motion", _reduced_motion)
	if _portrait != null and _reduced_motion: _portrait.call("apply_pose", "rest", 0.0)
	if visible and not _entry_played_for_room:
		call_deferred("_play_entry")


func _rebuild_inventory(_observer: Callable = Callable()) -> void:
	if _run_engine == null or _magic_group == null:
		return
	var offers: Array = _run_engine.call("merchant_offer_ids", _run_state, MERCHANT_KIND)
	var offers_by_kind: Dictionary = {MAGIC: [], GEAR: [], ITEM: []}
	for offer_var: Variant in offers:
		var item_id: String = str(offer_var)
		var kind: String = str(_run_engine.call("merchant_item_kind", item_id))
		(offers_by_kind[kind] as Array).append(item_id)
	for kind: String in offers_by_kind:
		var ids: Array = offers_by_kind[kind] as Array
		var signatures: Array = []
		for item_id: String in ids:
			var affordable: bool = _offer_is_affordable(item_id, false)
			signatures.append([item_id, affordable])
		var signature: int = hash(signatures)
		if _shelf_signatures.get(kind, -1) != signature:
			var target_group: Control = _magic_group if kind == MAGIC else (_gear_group if kind == GEAR else _item_group)
			var row := target_group.get_node("OfferRow") as HBoxContainer
			for child: Node in row.get_children():
				var item_id: String = str(child.get_meta("shop_item_id", ""))
				var key: String = "buy:" + item_id
				_forget_offer(key)
			_clear_children(row)
			for item_id: String in ids:
				var shelf_slot := CenterContainer.new()
				shelf_slot.name = "ShelfCubby_%s" % item_id
				shelf_slot.set_meta("shop_item_id", item_id)
				shelf_slot.custom_minimum_size = Vector2(SHELF_SLOT_WIDTH, row.size.y)
				shelf_slot.size_flags_vertical = Control.SIZE_EXPAND_FILL
				shelf_slot.add_child(_build_offer(item_id, kind))
				row.add_child(shelf_slot)
			_shelf_signatures[kind] = signature
		# Unaffordable tooltips include the changing amount still needed even
		# while their price, disabled tint and card artwork remain unchanged.
		for item_id: String in ids:
			var offer: Control = _offer_sources.get("buy:" + item_id) as Control
			if offer != null: offer.tooltip_text = _offer_tooltip(item_id, false, _offer_is_affordable(item_id, false))
	_all_sellable_ids = _run_engine.call("merchant_sellable_ids", _run_state, MERCHANT_KIND)
	_sellable_ids = _all_sellable_ids.filter(func(id: Variant) -> bool: return _pack_filter == "all" or str(_run_engine.call("merchant_item_kind", str(id))) == _pack_filter)
	_populate_sell_page()
	_update_selection_effects()
	_shade_ui_labels(_magic_group)
	_shade_ui_labels(_gear_group)
	_shade_ui_labels(_item_group)
	_shade_ui_labels(_sell_panel)



func _populate_sell_page() -> void:
	var page_count: int = maxi(1, ceili(float(_sellable_ids.size()) / float(SELL_PAGE_SIZE)))
	_sell_page = clampi(_sell_page, 0, page_count - 1)
	var signature: String = "%d|%d|%d" % [hash([_sellable_ids, _pack_filter]), _sell_page, page_count]
	if signature == _sell_page_signature: return
	_sell_page_signature = signature
	for key_var: Variant in _offer_sources.keys():
		var key: String = str(key_var)
		if key.begins_with("sell:"): _forget_offer(key)
	_clear_children(_sell_row)
	_sell_heading.text = "YOUR PACK" if page_count == 1 else "YOUR PACK  ·  %d / %d" % [_sell_page + 1, page_count]
	_sell_previous.disabled = _sell_page <= 0
	_sell_next.disabled = _sell_page >= page_count - 1
	var count: int = mini(SELL_PAGE_SIZE, maxi(0, _sellable_ids.size() - _sell_page * SELL_PAGE_SIZE))
	var rows: int = ceili(float(count) / 3.0)
	var grid_height: float = 180.0 if count == 0 else rows * SELL_TILE_SIZE.y + maxi(0, rows - 1) * 10.0
	_sell_row.custom_minimum_size.y = grid_height
	_sell_row.size.y = grid_height
	_sell_panel.custom_minimum_size.y = grid_height + 168.0
	_sell_panel.size.y = grid_height + 168.0
	if _sellable_ids.is_empty():
		var empty := Label.new()
		empty.text = "No spare wares to sell." if _pack_filter == "all" else "No %s to sell." % ("items" if _pack_filter == ITEM else _pack_filter)
		empty.custom_minimum_size = Vector2(748, 180)
		_sell_row.columns = 1
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UiTypography.set_label_size(empty, 17)
		empty.add_theme_color_override("font_color", Color("a99b86"))
		_sell_row.add_child(empty)
	else:
		_sell_row.columns = 3
		var first_index: int = _sell_page * SELL_PAGE_SIZE
		for index: int in range(first_index, mini(first_index + SELL_PAGE_SIZE, _sellable_ids.size())):
			_sell_row.add_child(_build_sell_offer(str(_sellable_ids[index])))

