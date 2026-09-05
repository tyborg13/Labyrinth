extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const AnalyticsStore = preload("res://scripts/analytics_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const OUTPUT_DIR: String = "user://probes/equipment_inventory_readability"
const GEAR_IDS: Array[String] = ["duelist_rapier", "mirror_guard", "cinderweave_mail", "cloudstep_sandals", "worldroot_greaves", "ember_hourglass"]
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://equipment_inventory_readability/progression.json")
	ProgressionStore.set_run_storage_path("user://equipment_inventory_readability/current_run.save")
	SettingsStore.set_storage_path("user://equipment_inventory_readability/settings.json")
	AnalyticsStore.set_storage_dir("user://equipment_inventory_readability/analytics")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	if _capture_requested():
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(instance)
	await _settle()
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(9142, ProgressionStore.default_data())
	state["mode"] = "room"
	state["equipment_inventory"] = GEAR_IDS.duplicate()
	var collected: Array = (state.get("collected_equipment", []) as Array).duplicate()
	collected.append_array(GEAR_IDS)
	state["collected_equipment"] = collected
	state["item_inventory"] = ["grave_dust_satchel", "mossglass_elixir", "bone_ward_charm"]
	state["equipped_items"] = ["crimson_draught"]
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	instance.call("_open_character_overlay", "equipment")
	await _settle()
	var gear: Dictionary = instance.get("_equipment_inventory_tiles") as Dictionary
	_expect(gear.size() == GEAR_IDS.size(), "Every spare equipment item must remain in the inventory")
	for gear_id: String in GEAR_IDS:
		var tile: Control = gear.get(gear_id) as Control
		_expect(tile != null, "Inventory must contain %s" % gear_id)
		if tile == null:
			continue
		_expect(tile.size.x >= 320.0 and absf(tile.size.x - (tile.get_parent() as Control).size.x) < 1.0, "Gear row must use the available inventory width: %s" % gear_id)
		var expected_names: Array[String] = []
		for card_id: Variant in GameData.equipment_cards(gear_id):
			expected_names.append(str(GameData.card_def(str(card_id)).get("name", card_id)))
		_expect(_has_text(tile, ", ".join(expected_names)), "Gear row must show every granted card name: %s" % gear_id)
		_expect(_has_text(tile, str(GameData.equipment_def(gear_id).get("name", ""))), "Gear row must retain its complete canonical title")
		_check_labels(tile, tile.get_global_rect())
		var inventory_scroll: ScrollContainer = tile.get_parent().get_parent().get_parent() as ScrollContainer
		_expect(inventory_scroll.get_global_rect().grow(1.0).encloses(tile.get_global_rect()), "Six spare gear choices must fit without initial scrolling: %s" % gear_id)
		_expect(tile.focus_mode == Control.FOCUS_ALL and tile.mouse_filter == Control.MOUSE_FILTER_STOP, "Expanded gear row must keep focus and pointer input")
	await _capture(viewport, "inventory_full_names.png")
	var first_tile: Control = gear.get("duelist_rapier") as Control
	first_tile.grab_focus()
	await _settle()
	_expect(first_tile.has_focus(), "Expanded equipment row must accept keyboard/controller focus")
	await _capture(viewport, "inventory_focused.png")
	var source_rect: Rect2 = instance.call("_equipment_inventory_icon_rect", "duelist_rapier") as Rect2
	_expect(source_rect.size.x > 0.0 and first_tile.get_global_rect().encloses(source_rect), "Gear drag must retain its visible icon anchor")
	instance.call("_begin_equipment_overlay_drag", "duelist_rapier", source_rect, first_tile, source_rect.get_center())
	_expect(str(instance.get("_equipment_drag_id")) == "duelist_rapier", "Expanded equipment row must retain drag initiation")
	instance.call("_cancel_equipment_overlay_drag", false)
	var old_weapon: String = str((state.get("equipped_equipment", {}) as Dictionary).get("weapon", ""))
	var accept := InputEventAction.new()
	accept.action = "ui_accept"
	accept.pressed = true
	first_tile.call("_gui_input", accept)
	var deadline: int = Time.get_ticks_msec() + 4000
	while bool(instance.get("_equipment_swap_animation_active")) and Time.get_ticks_msec() < deadline:
		await process_frame
	await _settle()
	var after: Dictionary = instance.get("_run_state") as Dictionary
	_expect(str((after.get("equipped_equipment", {}) as Dictionary).get("weapon", "")) == "duelist_rapier", "Accept must equip the selected spare weapon")
	_expect((after.get("equipment_inventory", []) as Array).has(old_weapon), "Equipping must return the prior weapon to spare gear")
	await _capture(viewport, "inventory_after_equip.png")
	var items: Dictionary = instance.get("_item_inventory_tiles") as Dictionary
	_expect(items.size() == 3, "Every spare consumable must remain available")
	for item_tile: Control in items.values():
		_expect(absf(item_tile.size.x - (item_tile.get_parent() as Control).size.x) < 1.0, "Item row must use the available inventory width")
		_check_labels(item_tile, item_tile.get_global_rect())
	var item_rows: Control = instance.find_child("ItemInventoryRows", true, false) as Control
	var scroll: ScrollContainer = item_rows.get_parent().get_parent() as ScrollContainer
	scroll.ensure_control_visible(item_rows)
	await _settle()
	await _capture(viewport, "inventory_consumables.png")
	instance.queue_free()
	viewport.queue_free()
	await process_frame
	for failure: String in _failures:
		push_error(failure)
	if _capture_requested():
		print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("EQUIPMENT INVENTORY READABILITY TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _check_labels(node: Node, tile_rect: Rect2) -> void:
	if node is Label:
		var label := node as Label
		if not label.text.is_empty() and label.text != "NEW":
			_expect(not label.clip_text, "Inventory copy must never clip mid-word: %s" % label.text)
			_expect(label.get_line_count() == label.get_visible_line_count(), "All wrapped inventory lines must fit vertically: %s" % label.text)
			_expect(tile_rect.grow(1.0).encloses(label.get_global_rect()), "Inventory text must remain inside its card: %s" % label.text)
			_expect(label.get_theme_font_size("font_size") >= 14, "Inventory copy must retain readable type sizes")
	for child: Node in node.get_children():
		_check_labels(child, tile_rect)

func _has_text(node: Node, expected: String) -> bool:
	if node is Label and (node as Label).text == expected:
		return true
	for child: Node in node.get_children():
		if _has_text(child, expected):
			return true
	return false

func _settle() -> void:
	for _frame: int in range(8):
		await process_frame

func _capture(viewport: SubViewport, filename: String) -> void:
	if not _capture_requested():
		return
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "Equipment proof image must render")
	if image != null and not image.is_empty():
		image.save_png("%s/%s" % [OUTPUT_DIR, filename])

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

func _capture_requested() -> bool:
	return false
