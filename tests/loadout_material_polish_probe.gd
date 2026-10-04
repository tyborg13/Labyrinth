extends "res://tests/controller_compat_1080_probe.gd"

const OUTPUT: String = "user://probes/loadout_material_vp4"
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
	_instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	_viewport.gui_release_focus()
	await _save_screenshot("02_magic_idle.png")
	_instance.queue_free()
	await process_frame
	_cleanup_storage()
	print(ProjectSettings.globalize_path(OUTPUT))
	if DisplayServer.get_name() == "headless":
		print("LOADOUT PROOF: HEADLESS ASSERTIONS ONLY; NO SCREENSHOTS")
	print("LOADOUT MATERIAL POLISH: PASS")
	quit(0)

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
