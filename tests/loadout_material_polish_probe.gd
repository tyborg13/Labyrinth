extends "res://tests/controller_compat_1080_probe.gd"

const OUTPUT: String = "user://probes/loadout_material_v1"
var _instance: Node

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output_dir = OUTPUT
	_physical_size = Vector2i(1920, 1080)
	_logical_size = _physical_size
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_router = root.get_node("InputRouter")
	_build_handheld_viewport()
	_instance = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_instance)
	await create_timer(0.4).timeout
	var engine := RunEngineScript.new()
	var progression: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	var base: Dictionary = engine.create_new_run(127800, progression)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _exercise_loadout_material(_instance, base)
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_open_character_overlay", "equipment")
	await _settle()
	_viewport.gui_release_focus()
	await _save_screenshot("01_gear_idle.png")
	var panel_style: StyleBoxFlat = _instance.call("_equipment_panel_style", Color("bb9a65"), false)
	var icon_style: StyleBoxFlat = _instance.call("_equipment_icon_style", Color("bb9a65"))
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_require(is_equal_approx(panel_style.get_margin(side), 2.0), "Equipment panel keeps native two-pixel content margins")
		_require(is_equal_approx(icon_style.get_margin(side), 4.0), "Equipment icon keeps four-pixel content margins")
	_instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	_viewport.gui_release_focus()
	await _save_screenshot("02_magic_idle.png")
	_instance.call("_close_card_upgrade_overlay")
	_instance.call("_load_run_state", base)
	_instance.call("_close_dialogue")
	await create_timer(0.4).timeout
	var combat_coord: Vector2i = _first_available_combat_coord(engine, base)
	await _instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.4).timeout
	_require((_instance.get("_pre_battle_scrim") as Control).visible, "Natural room travel opens pre-battle")
	await _save_screenshot("03_pre_battle.png")
	await _merchant_states(engine, base)
	_instance.queue_free()
	await process_frame
	_cleanup_storage()
	print(ProjectSettings.globalize_path(OUTPUT))
	print("LOADOUT MATERIAL POLISH: PASS")
	quit(0)

func _merchant_states(engine, base: Dictionary) -> void:
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_load_run_state", _scavenger_controller_state(engine))
	_instance.call("_close_dialogue")
	await create_timer(0.7).timeout
	var shop: Control = _instance.get("_scavenger_shop_view") as Control
	var ware: Button = shop.find_child("GearOffer_*", true, false) as Button
	_require(ware != null and ware.is_visible_in_tree(), "Merchant fixture exposes a native gear ware")
	_viewport.gui_release_focus()
	await _point(Vector2(30, 30))
	await create_timer(0.2).timeout
	var before_rect: Rect2 = ware.get_global_rect()
	var layout_rect := Rect2(ware.position, ware.size)
	await _save_screenshot("04_merchant_idle.png")
	if ware.has_method("material_snapshot"):
		_require(not ware.is_processing(), "Visible idle ware has no perpetual redraw process")
	await _point(before_rect.get_center())
	if ware.has_method("material_snapshot"):
		var entering: Dictionary = ware.call("material_snapshot")
		_require(float(entering["active"]) < 1.0 and ware.is_processing(), "Hover starts a bounded eased material response")
	await _capture_frame("05a_merchant_hover_arrival.png")
	await create_timer(0.16).timeout
	await _save_screenshot("05_merchant_hover.png")
	_require(ware.is_hovered() and Rect2(ware.position, ware.size) == layout_rect and ware.scale.is_equal_approx(Vector2(1.045, 1.045)), "Native hover preserves the authored layout and existing 1.045 scale contract")
	if ware.has_method("material_snapshot"):
		_require(not ware.is_processing(), "Settled hover stops processing")
	await _mouse(before_rect.get_center(), true)
	await create_timer(0.14).timeout
	await _save_screenshot("06_merchant_pressed.png")
	_require(ware.is_pressed(), "Pressed proof samples native button before release")
	ware.disabled = true
	await _settle()
	if ware.has_method("material_snapshot"):
		var disabled_paint: Dictionary = ware.call("material_snapshot")
		_require(float(disabled_paint["press"]) == 0.0 and float(disabled_paint["active"]) == 0.0 and not ware.is_processing(), "Disabling a settled pressed ware clears its material response")
		var content: Control = ware.get_node("CenteredOfferContent") as Control
		_require(content.position.y == 0.0 and content.modulate == Color.WHITE, "Disabling clears depressed/dimmed content immediately")
	await _save_screenshot("06b_merchant_disabled.png")
	ware.disabled = false
	await _mouse(before_rect.get_center(), false)
	await create_timer(0.2).timeout
	_require(not str(shop.get("_selected_item_id")).is_empty(), "Native pointer release selects the same ware")
	await _save_screenshot("07_merchant_selected.png")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	ware.grab_focus()
	await _press_controller_button(JOY_BUTTON_DPAD_DOWN)
	var next_focus: Control = _viewport.gui_get_focus_owner()
	_require(next_focus != null and next_focus != ware and shop.is_ancestor_of(next_focus), "Native D-pad traversal leaves the ware for another shop control")
	ware.grab_focus()
	await create_timer(0.17).timeout
	await _save_screenshot("08_merchant_controller.png")
	await _press_controller_button(JOY_BUTTON_A)
	await _settle()
	_require(_viewport.gui_get_focus_owner() == shop.get("_detail_action"), "Native Accept enters the ware's existing trade action")
	var embers_before: int = int((_instance.get("_run_state") as Dictionary)["held_embers"])
	await _press_controller_button(JOY_BUTTON_A)
	await create_timer(0.55).timeout
	_require(int((_instance.get("_run_state") as Dictionary)["held_embers"]) < embers_before, "Existing controller Buy remains functional")
	await _save_screenshot("09_merchant_purchase.png")
	await _press_controller_button(JOY_BUTTON_B)
	_require(not shop.visible, "Controller Cancel still leaves the shop")
	_instance.call("_load_run_state", _scavenger_controller_state(engine))
	await _settle()
	_require(shop.visible, "Rebuilt merchant restores its wares")
	var reduced_settings: Dictionary = (_instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	_instance.set("_settings", reduced_settings)
	shop.call("configure", _instance.get("_run_state"), engine, true)
	await create_timer(0.2).timeout
	ware = shop.find_child("GearOffer_*", true, false) as Button
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_viewport.gui_release_focus()
	await _point(Vector2(30, 30))
	_require(bool(ware.get("reduced_motion")), "Shop settings propagate Reduced Motion to rebuilt wares")
	await _point(ware.get_global_rect().get_center())
	if ware.has_method("material_snapshot"):
		_require(float((ware.call("material_snapshot") as Dictionary)["active"]) == 1.0 and not ware.is_processing(), "Reduced Motion hover is immediate and static")
	await _mouse(ware.get_global_rect().get_center(), true)
	if ware.has_method("material_snapshot"):
		_require(float((ware.call("material_snapshot") as Dictionary)["press"]) == 1.0 and not ware.is_processing(), "Reduced Motion press applies immediately without animation")
	await _save_screenshot("10_merchant_reduced_pressed.png")
	await _mouse(ware.get_global_rect().get_center(), false)
	reduced_settings["reduced_motion"] = false
	_instance.set("_settings", reduced_settings)
	ware.set("reduced_motion", false)
	_viewport.gui_release_focus()
	await _point(Vector2(30, 30))
	if ware.has_method("material_snapshot"):
		_require(ware.is_processing(), "Pointer departure starts a live response for the preference handoff check")
		ware.set("reduced_motion", true)
		_require(float((ware.call("material_snapshot") as Dictionary)["active"]) == 0.0 and not ware.is_processing(), "Switching Reduced Motion on during a response settles immediately")
		_require((ware.get_node("CenteredOfferContent") as Control).position.y == 0.0, "Live Reduced Motion switch preserves static content placement")
		ware.set("reduced_motion", false)
	await _point(ware.get_global_rect().get_center())
	ware.hide()
	if ware.has_method("material_snapshot"):
		_require(not ware.is_processing(), "Hiding during a transition stops its processing immediately")
	ware.show()
	var poor: Dictionary = _scavenger_controller_state(engine)
	poor["held_embers"] = 0
	poor["unbanked_embers"] = 0
	_instance.call("_load_run_state", poor)
	await _settle()
	ware = shop.find_child("GearOffer_*", true, false) as Button
	await _point(ware.get_global_rect().get_center())
	await _mouse(ware.get_global_rect().get_center(), true)
	await _mouse(ware.get_global_rect().get_center(), false)
	await create_timer(0.2).timeout
	_require((shop.get("_detail_action") as Button).disabled, "Unaffordable selection retains disabled Buy and its existing reason")
	await _save_screenshot("11_merchant_unaffordable.png")
	var sell_mode: Control = shop.get("_mode_sell") as Control
	await _point(sell_mode.get_global_rect().get_center())
	await _mouse(sell_mode.get_global_rect().get_center(), true)
	await _mouse(sell_mode.get_global_rect().get_center(), false)
	await create_timer(0.2).timeout
	_require(bool(shop.get("_pack_mode")), "Native Sell mode exposes unchanged pack trays")
	await _save_screenshot("12_merchant_pack.png")

func _point(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_viewport.push_input(event, true)
	await process_frame

func _mouse(point: Vector2, down: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	_viewport.push_input(event, true)
	await process_frame

func _save_screenshot(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await _settle()
	await _capture_frame(filename)

func _capture_frame(filename: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_require(frame.get_size() == Vector2i(1920, 1080), "Every delivered image uses the native 1920×1080 envelope")
	_require(frame.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(filename))) == OK, "Native screenshot saved: " + filename)

func _exercise_loadout_material(instance: Node, base_state: Dictionary) -> void:
	var state: Dictionary = base_state.duplicate(true)
	var equipment_inventory: Array = (state.get("equipment_inventory", []) as Array).duplicate()
	if not equipment_inventory.has("iron_cleaver"):
		equipment_inventory.append("iron_cleaver")
	state["equipment_inventory"] = equipment_inventory
	var collected_equipment: Array = (state.get("collected_equipment", []) as Array).duplicate()
	if not collected_equipment.has("iron_cleaver"):
		collected_equipment.append("iron_cleaver")
	state["collected_equipment"] = collected_equipment
	var item_inventory: Array = (state.get("item_inventory", []) as Array).duplicate()
	if not item_inventory.has("mossglass_elixir"):
		item_inventory.append("mossglass_elixir")
	state["item_inventory"] = item_inventory
	var magic_inventory: Array = (state.get("magic_inventory", []) as Array).duplicate()
	if not magic_inventory.has("bone_dart"):
		magic_inventory.append("bone_dart")
	state["magic_inventory"] = magic_inventory
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()

	instance.call("_close_large_map")
	instance.call("_open_character_overlay", "equipment")
	await _settle()
	var gear_tiles: Dictionary = instance.get("_equipment_inventory_tiles") as Dictionary
	var gear_slots: Dictionary = instance.get("_equipment_slot_panels") as Dictionary
	var initial_gear_focus: Control = _viewport.gui_get_focus_owner()
	_require(
		gear_slots.values().has(initial_gear_focus) or gear_tiles.values().has(initial_gear_focus),
		"Opening Character with a controller should immediately focus a meaningful gear tile instead of the Close button"
	)
	var gear_tile: Control = gear_tiles.get("iron_cleaver") as Control
	_require(gear_tile != null and gear_tile.focus_mode == Control.FOCUS_ALL, "Spare gear should be controller-focusable outside combat")
	gear_tile.grab_focus()
	await _settle()
	var gear_tooltip: Control = instance.get("_controller_loadout_tooltip") as Control
	_require(gear_tooltip != null and gear_tooltip.visible, "Focused gear should reveal its full controller mechanics tooltip")
	await _save_screenshot("character_room_loadout_focus.png")
	gear_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.35).timeout
	var equipped: Dictionary = (instance.get("_run_state") as Dictionary).get("equipped_equipment", {}) as Dictionary
	_require(str(equipped.get("weapon", "")) == "iron_cleaver", "A on spare gear should equip it with no pointer drag")

	var current_items: Array = (instance.get("_run_state") as Dictionary).get("item_inventory", []) as Array
	var item_index: int = current_items.find("mossglass_elixir")
	_require(item_index >= 0, "Controller loadout fixture should retain its consumable")
	var item_tiles: Dictionary = instance.get("_item_inventory_tiles") as Dictionary
	var item_tile: Control = item_tiles.get(item_index) as Control
	_require(item_tile != null and item_tile.focus_mode == Control.FOCUS_ALL, "Consumables should be controller-focusable")
	item_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.25).timeout
	var equipped_items: Array = (instance.get("_run_state") as Dictionary).get("equipped_items", []) as Array
	_require(equipped_items.has("mossglass_elixir"), "A on a consumable should equip it with no pointer drag")

	instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	var reserve: Array = (instance.get("_run_state") as Dictionary).get("magic_inventory", []) as Array
	var reserve_index: int = reserve.find("bone_dart")
	_require(reserve_index >= 0, "Controller magic fixture should retain its reserve spell")
	var reserve_tiles: Dictionary = instance.get("_magic_inventory_tiles") as Dictionary
	var reserve_tile: Control = reserve_tiles.get(reserve_index) as Control
	var attuned_tiles: Dictionary = instance.get("_magic_attuned_tiles") as Dictionary
	var attuned_tile: Control = attuned_tiles.get(0) as Control
	var initial_magic_focus: Control = _viewport.gui_get_focus_owner()
	_require(
		attuned_tiles.values().has(initial_magic_focus) or reserve_tiles.values().has(initial_magic_focus),
		"Switching to Magic with a controller should immediately focus a spell tile instead of an unrelated control"
	)
	_require(reserve_tile != null and attuned_tile != null, "Magic swap should expose both controller endpoints")
	reserve_tile.grab_focus()
	# Establish the pre-handoff inspection deterministically even if a deferred
	# modal focus recovery from rebuilding this tab lands in the same frame.
	instance.call("_restore_controller_loadout_tooltip_for_focus_owner")
	await _settle()
	_require(reserve_tile.has_focus(), "Magic tooltip handoff proof requires the reserve spell to own focus")
	var magic_tooltip: Control = instance.get("_controller_loadout_tooltip") as Control
	_require(magic_tooltip != null and magic_tooltip.visible, "Focused magic should reveal its full card mechanics tooltip")
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_STEAM_DECK)
	await _settle()
	_require(instance.get("_controller_loadout_tooltip") == null, "Switching to pointer modality should clear controller-only loadout tooltips")
	_router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	await _settle()
	magic_tooltip = instance.get("_controller_loadout_tooltip") as Control
	_require(reserve_tile.has_focus(), "Pointer/controller handoff should preserve the already-focused magic tile")
	_require(magic_tooltip != null and magic_tooltip.visible, "Returning to controller modality should restore the focused magic mechanics tooltip without extra navigation")
	reserve_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	_require(str(instance.get("_controller_magic_source_kind")) == "inventory", "First A should hold the reserve spell for a two-step swap")
	var swap_prompt_labels: Array[String]
	for prompt: Dictionary in (instance.get("_controller_prompt_bar") as Control).call("prompts_snapshot") as Array[Dictionary]:
		swap_prompt_labels.append(str(prompt.get("label", "")))
	_require(
		swap_prompt_labels == ["Swap", "Cancel Swap", "Choose Slot"],
		"Selected magic should advertise Swap / Cancel Swap / Choose Slot; got %s" % [swap_prompt_labels]
	)
	await _save_screenshot("character_magic_swap_selected.png")
	attuned_tile.call("_gui_input", _controller_accept_event())
	await _settle()
	await create_timer(0.25).timeout
	var attuned: Array = (instance.get("_run_state") as Dictionary).get("attuned_magic_cards", []) as Array
	_require(not attuned.is_empty() and str(attuned[0]) == "bone_dart", "Second A on an attuned slot should complete the controller magic swap")
	instance.call("_close_card_upgrade_overlay")
	await _settle()
	var clean_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	clean_state["notice"] = ""
	instance.set("_run_state", clean_state)
	instance.call("_refresh_ui")
	await _settle()
