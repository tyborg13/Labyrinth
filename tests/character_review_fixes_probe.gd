extends "res://tests/character_menu_polish_probe.gd"

const REVIEW_OUTPUT: String = "user://probes/character_review_fixes"
const CloseSocket = preload("res://scripts/ui_close_socket.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output_dir = REVIEW_OUTPUT
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
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(REVIEW_OUTPUT))
	_router = root.get_node("InputRouter")
	_build_handheld_viewport()
	_require(_viewport.size == Vector2i(1920, 1080), "Review proof uses a fixed 1920×1080 SubViewport")
	_instance = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_instance)
	await create_timer(0.4).timeout
	var engine := RunEngineScript.new()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	var state: Dictionary = engine.create_new_run(127800, profile)
	state["equipment_inventory"] = ["iron_cleaver", "duelist_rapier"]
	state["collected_equipment"] = (state.get("collected_equipment", []) as Array) + ["iron_cleaver", "duelist_rapier"]
	state["item_inventory"] = ["mossglass_elixir", "crimson_draught"]
	_instance.call("_load_run_state", state)
	_instance.call("_close_dialogue")
	_instance.call("_close_large_map")
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_open_character_overlay", "equipment")
	await _settle()
	var dialog: Control = _instance.get("_upgrade_dialog") as Control
	await _assert_review_header(dialog)
	_require(dialog.find_child("CloseCharacterOverlay", true, false).get_script() == CloseSocket, "Character uses the shared close socket")
	await _pack_gestures("_equipment_inventory_tiles", "iron_cleaver", "_equipment_drag_id", "01_gear_press.png")
	await _pack_gestures("_item_inventory_tiles", 0, "_item_drag_card_id", "02_item_press.png")
	await _deck_dismissal(dialog)
	await _drag_equipment_to_socket()
	await _drag_item_to_slot()
	await _known_moves_close()
	_instance.queue_free()
	await process_frame
	_cleanup_storage()
	print(ProjectSettings.globalize_path(REVIEW_OUTPUT))
	if DisplayServer.get_name() == "headless":
		print("CHARACTER REVIEW PROOF: HEADLESS ASSERTIONS ONLY; NO SCREENSHOTS")
	print("CHARACTER REVIEW FIXES: PASS")
	quit(0)

func _pack_gestures(property: String, key: Variant, drag_property: String, filename: String) -> void:
	_viewport.gui_release_focus()
	await _settle()
	var tiles: Dictionary = _instance.get(property) as Dictionary
	var tile: Control = tiles[key] as Control
	var actions: Control = tile.find_child("CharacterPackActions", true, false) as Control
	_require(actions != null and not actions.visible, "Idle pack row reserves hidden actions")
	var rects: Dictionary = {}
	for id: Variant in tiles:
		rects[id] = (tiles[id] as Control).get_global_rect()
	var point: Vector2 = tile.get_global_rect().position + Vector2(70.0, 16.0)
	await _point(point)
	await _mouse(point, true)
	await _settle()
	_require(not actions.visible, "Press does not reveal actions at drag start")
	_require(not str(_instance.get(drag_property)).is_empty(), "Press retains the native drag path")
	_assert_pack_rects(tiles, rects, "press")
	await _save_screenshot(filename)
	await _mouse(point, false)
	await _settle()
	_require(actions.visible, "Completed click reveals selected row actions")
	_assert_pack_rects(tiles, rects, "completed click")
	await _save_screenshot(filename.replace("press", "selected"))
	_viewport.gui_release_focus()
	await _settle()
	await _mouse(point, true)
	await _point(point + Vector2(30.0, 0.0))
	_require(not actions.visible, "Dragging does not reveal actions")
	_assert_pack_rects(tiles, rects, "drag")
	await _mouse(point + Vector2(30.0, 0.0), false)
	await _settle()
	_require(not actions.visible, "Drag release does not count as a click")
	_assert_pack_rects(tiles, rects, "drag release")
	await _mouse(point, true)
	await _key_event(KEY_ESCAPE)
	await _mouse(point, false)
	await _settle()
	_require(not actions.visible, "Cancelled drag does not reveal click actions")
	await create_timer(0.2).timeout
	_require(str(_instance.get(drag_property)).is_empty(), "Native cancellation finishes its return animation")
	_assert_pack_rects(tiles, rects, "cancelled drag")
	_viewport.gui_release_focus()
	tile.grab_focus()
	await _settle()
	_require(actions.visible, "Keyboard/controller focus reveals actions")
	_assert_pack_rects(tiles, rects, "keyboard/controller focus")

func _assert_pack_rects(tiles: Dictionary, rects: Dictionary, phase: String) -> void:
	for id: Variant in tiles:
		_require((tiles[id] as Control).get_global_rect() == rects[id], "Pack row geometry stays fixed on " + phase)

func _deck_dismissal(dialog: Control) -> void:
	_viewport.gui_release_focus()
	var deck: Control = dialog.find_child("CurrentDeckPanel", true, false) as Control
	var strip: Control = deck.find_child("CharacterCardStrip", true, false) as Control
	var empty: Vector2 = dialog.global_position + Vector2(500.0, 35.0)
	await _mouse(strip.get_global_rect().get_center(), true)
	await _mouse(strip.get_global_rect().get_center(), false)
	await _settle()
	_require(_instance.get("_controller_loadout_tooltip") != null, "Clicking a deck strip pins its inspection")
	await _save_screenshot("03_deck_inspection.png")
	await _mouse(empty, true)
	await _mouse(empty, false)
	await _settle()
	_require(_instance.get("_controller_loadout_tooltip") == null, "Clicking empty dialog space dismisses deck inspection")
	_require((_instance.get("_upgrade_scrim") as Control).visible, "Empty-space dismissal preserves Character")
	await _save_screenshot("04_deck_dismissed.png")
	_click_now(strip)
	await _settle()
	_require(_instance.get("_controller_loadout_tooltip") != null, "Deck inspection reopens after dismissal")
	_click_now(strip)
	await _settle()
	_require(_instance.get("_controller_loadout_tooltip") == null, "The next click on the same strip dismisses without reopening inspection")
	_click_now(strip)
	await _settle()
	await _key_event(KEY_ESCAPE)
	_require(_instance.get("_controller_loadout_tooltip") == null and (_instance.get("_upgrade_scrim") as Control).visible, "Escape dismisses inspection before Character")
	_click_now(strip)
	await _settle()
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _press_controller_button(JOY_BUTTON_B)
	_require(_instance.get("_controller_loadout_tooltip") == null and (_instance.get("_upgrade_scrim") as Control).visible, "Controller Back dismisses inspection before Character")
	_router.call("set_forced_state_for_test", "pointer", "xbox")

func _drag_equipment_to_socket() -> void:
	var tiles: Dictionary = _instance.get("_equipment_inventory_tiles") as Dictionary
	var tile: Control = tiles["iron_cleaver"] as Control
	var target: Control = (_instance.get("_equipment_slot_panels") as Dictionary)["weapon"] as Control
	var point: Vector2 = tile.get_global_rect().position + Vector2(70.0, 16.0)
	await _mouse(point, true)
	await _point(target.get_global_rect().get_center())
	await _mouse(target.get_global_rect().get_center(), false)
	await _settle()
	await create_timer(0.4).timeout
	var equipped: Dictionary = (_instance.get("_run_state") as Dictionary).get("equipped_equipment", {}) as Dictionary
	_require(str(equipped.get("weapon", "")) == "iron_cleaver", "Pack drag still equips onto the native weapon socket")

func _drag_item_to_slot() -> void:
	var tiles: Dictionary = _instance.get("_item_inventory_tiles") as Dictionary
	var tile: Control = tiles[0] as Control
	var target: Control = (_instance.get("_item_equipped_tiles") as Dictionary)[0] as Control
	var card_id: String = str(tile.get("card_id"))
	var point: Vector2 = tile.get_global_rect().position + Vector2(70.0, 16.0)
	await _mouse(point, true)
	await _point(target.get_global_rect().get_center())
	await _mouse(target.get_global_rect().get_center(), false)
	await _settle()
	await create_timer(0.4).timeout
	_require(((_instance.get("_run_state") as Dictionary).get("equipped_items", []) as Array).has(card_id), "Pack drag still equips onto the native item slot")

func _known_moves_close() -> void:
	_instance.call("_close_card_upgrade_overlay")
	var panel: Control = _instance.call("_build_pre_battle_enemy_inspection_panel", {"type": "warden", "hp": 20, "max_hp": 20}, true) as Control
	var scrim: Control = _instance.get("_pinned_tooltip_scrim") as Control
	var host: Control = _instance.get("_pinned_tooltip_host") as Control
	host.add_child(panel)
	_instance.set("_pinned_tooltip_panel", panel)
	panel.position = Vector2(620.0, 180.0)
	panel.size = panel.get_combined_minimum_size()
	scrim.visible = true
	await _point(Vector2.ZERO)
	await _settle()
	var close: Button = panel.find_child("PreBattleInspectionCloseButton", true, false) as Button
	var glyph: Label = close.get_node("PreBattleCloseGlyph") as Label
	_require(close.get_script() == CloseSocket and close.text.is_empty(), "Known moves uses the shared socket without transparent native button text")
	_require(glyph.text == "✕" and glyph.get_theme_font_size("font_size") == 18 and glyph.get_theme_color("font_color") == Palette.TEXT_2, "Known-moves close glyph uses UI18 TEXT_2")
	for state: String in ["focus", "hover", "hover_pressed", "pressed"]:
		_require(close.get_theme_stylebox(state) is StyleBoxEmpty, "Shared close socket suppresses native " + state + " paint")
	await _save_screenshot("05_known_moves_close_idle.png")
	close.grab_focus()
	await _settle()
	_require(glyph.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Known-moves close glyph brightens on keyboard/controller focus")
	await _save_screenshot("06_known_moves_close_focus.png")
	await _point(close.get_global_rect().get_center())
	_require(glyph.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Known-moves close glyph brightens on hover")
	_click_now(close)
	await _settle()
	_require(not scrim.visible, "Known-moves close preserves native pointer activation")

func _capture_frame(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_require(frame.get_size() == Vector2i(1920, 1080), "Review screenshots use the fixed SubViewport texture")
	_require(frame.save_png(ProjectSettings.globalize_path(REVIEW_OUTPUT.path_join(filename))) == OK, "Saved review proof: " + filename)
