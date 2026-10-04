extends "res://tests/loadout_material_polish_probe.gd"

const CHARACTER_OUTPUT: String = "user://probes/character_menu_vp4"
const Menu = preload("res://scripts/character_menu_view.gd")
const Palette = preload("res://scripts/ui_palette.gd")

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_output_dir = CHARACTER_OUTPUT
	_physical_size = Vector2i(1920, 1080)
	_logical_size = _physical_size
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHARACTER_OUTPUT))
	_router = root.get_node("InputRouter")
	_build_handheld_viewport()
	_require(_viewport.size == Vector2i(1920, 1080) and _viewport.size_2d_override == Vector2i(1920, 1080), "Proof uses a fixed 1920×1080 SubViewport at native UI scale")
	_instance = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(_instance)
	await create_timer(0.4).timeout
	var engine := RunEngineScript.new()
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	var base: Dictionary = engine.create_new_run(127800, profile)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _exercise_loadout_material(_instance, base)
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	_instance.call("_open_character_overlay", "equipment")
	await _settle()
	_viewport.gui_release_focus()
	var dialog: Control = _instance.get("_upgrade_dialog") as Control
	var bounds: Rect2 = dialog.get_global_rect()
	_require(bounds.size == Vector2(1500.0, 900.0) and bounds.position == Vector2(210.0, 90.0), "Character retains the production panel size and placement")
	_require(dialog.find_child("CharacterGlass", true, false) != null, "Character uses a gilded major-dialog glass surface")
	_require((dialog.find_child("ProgressionLevelLabel", true, false) as Label).text == "THE REAVER · LEVEL 1", "Level lives in the Reaver eyebrow")
	_require((dialog.find_child("ProgressionSkillPointsLabel", true, false) as Label).get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Skill points use the gold stat-chip value")
	await _assert_review_header(dialog)
	_assert_body_fit(dialog)
	_assert_gear_components(dialog)
	_assert_wrapper_states(dialog)
	await _save_screenshot("01_gear_idle.png")
	var slots: Dictionary = _instance.get("_equipment_slot_panels") as Dictionary
	var slot: Control = slots["weapon"] as Control
	slot.grab_focus()
	await _settle()
	_require(bool(slot.find_child("EquipmentIconChip", true, false).get("selected")), "Focused equipped slot selects its socket")
	await _assert_socket_render(slot)
	await _save_screenshot("02_equipped_slot_selected.png")
	await _key_event(KEY_TAB)
	await _settle()
	var keyboard_socket: Control = _viewport.gui_get_focus_owner()
	_require(keyboard_socket != slot and slots.values().has(keyboard_socket), "Keyboard Tab traverses native paper-doll socket endpoints")
	await _assert_socket_render(keyboard_socket)
	await _save_screenshot("02b_socket_keyboard_focus.png")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	slot.grab_focus()
	await _settle()
	_require(_viewport.gui_get_focus_owner() == slot, "Controller focus stays on the native slot endpoint")
	await _assert_socket_render(slot)
	await _save_screenshot("03_socket_controller_focus.png")
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	var pack: Dictionary = _instance.get("_equipment_inventory_tiles") as Dictionary
	var pack_tile: Control = pack.values()[0] as Control
	pack_tile.grab_focus()
	await _settle()
	_require((pack_tile.find_child("CharacterPackActions", true, false) as Control).visible, "Selected pack row reveals compact native actions")
	await _save_screenshot("04_pack_selected.png")
	var inspect: Button = pack_tile.find_child("CharacterPackActions", true, false).get_child(1) as Button
	inspect.grab_focus()
	inspect.pressed.emit()
	await _settle()
	_require(_viewport.gui_get_focus_owner() == pack_tile and _instance.get("_controller_loadout_tooltip") != null, "Inspect retains the native row focus and full equipment inspection")
	slot.grab_focus()
	await _settle()
	_require(_instance.get("_controller_loadout_tooltip") == null, "Leaving the inspected row clears its inspection")
	var state: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	state["equipped_items"] = ["mossglass_elixir", "crimson_draught"]
	_instance.set("_run_state", state)
	_instance.call("_rebuild_progression_overlay")
	await _settle()
	_require((_instance.get("_item_equipped_tiles") as Dictionary).size() == 2, "Full item loadout retains both native endpoints")
	_assert_wrapper_states(dialog)
	await _save_screenshot("05_items_full.png")
	state["equipped_items"] = []
	_instance.set("_run_state", state)
	_instance.call("_rebuild_progression_overlay")
	await _settle()
	var item_slots: Dictionary = _instance.get("_item_equipped_tiles") as Dictionary
	for tile: Control in item_slots.values():
		_require(tile.find_child("ItemCardArtChip", true, false) != null, "Empty item row contains an empty socket")
	_assert_wrapper_states(dialog)
	await _save_screenshot("06_items_empty.png")
	_click_now(dialog.find_child("CharacterMagicTab", true, false) as Control)
	_require(str(_instance.get("_progression_overlay_mode")) == "magic", "Pointer tab activation is immediate")
	await _settle()
	_assert_body_fit(dialog)
	_assert_wrapper_states(dialog)
	_require(dialog.get_global_rect() == bounds, "Tab switching preserves outer bounds")
	var attuned: Dictionary = _instance.get("_magic_attuned_tiles") as Dictionary
	for tile: Control in attuned.values():
		_require(is_equal_approx(tile.size.y, 34.0), "Attuned slots use 34px strips")
	_viewport.gui_release_focus()
	await _save_screenshot("07_magic_idle.png")
	_instance.call("_controller_activate_magic_tile", "attuned", 0, str((attuned[0] as Control).get("card_id")))
	_require(bool((attuned[0] as Control).get_node("CharacterCardStrip").get("selected")), "Two-step swap uses the shared strip selected state")
	await _save_screenshot("08_magic_swap_selected.png")
	_instance.call("_clear_controller_magic_selection")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	await _settle()
	_require(str(_instance.get("_progression_overlay_mode")) == "skills", "Controller RB traverses native tabs")
	var tree: Control = _instance.get("_skill_tree_view") as Control
	_require(tree.is_ancestor_of(_viewport.gui_get_focus_owner()), "Skills retains graph focus")
	_require((tree.find_child("SkillDetailAction", true, false) as Button).text == "No Skill Points", "No-points learning stays quiet and unavailable")
	_require(is_equal_approx(float(tree.call("minimum_connection_width")), 2.0), "Skill rails use the specified 2px stroke")
	_require(tree.find_children("SkillLegendChip_*", "", true, false).size() == 4, "Skills has four eyebrow legend chips")
	await _save_screenshot("09_skills_no_points.png")
	var retained_id: int = tree.get_instance_id()
	await _press_controller_button(JOY_BUTTON_B)
	_require(not (_instance.get("_upgrade_scrim") as Control).visible, "Controller Back closes Character")
	_instance.call("_open_character_overlay", "skills")
	_require((_instance.get("_skill_tree_view") as Control).get_instance_id() == retained_id, "Cached reopening retains the native skill tree")
	var progressed: Dictionary = profile.duplicate(true)
	progressed["level"] = 4
	ProgressionStore.save_data(progressed)
	state = (_instance.get("_run_state") as Dictionary).duplicate(true)
	state["progression"] = progressed
	_instance.set("_run_state", state)
	_instance.call("_rebuild_progression_overlay")
	await _settle()
	_require((dialog.find_child("ProgressionDefianceChip", true, false).get_node("Caption") as Label).text == "DEFIANCE · NEXT 8", "Defiance caption refreshes the next level threshold")
	var learn: Button = tree.find_child("SkillDetailAction", true, false) as Button
	_require(not learn.disabled and learn.text == "Learn  ·  1 Point", "Points enable the native primary Learn action")
	await _save_screenshot("10_skills_points_available.png")
	var tab: Control = dialog.find_child("CharacterSkillsTab", true, false) as Control
	tab.grab_focus()
	await _key_event(KEY_TAB)
	_require(_viewport.gui_get_focus_owner() != tab and dialog.is_ancestor_of(_viewport.gui_get_focus_owner()), "Keyboard traversal remains inside Character")
	await _key_event(KEY_ESCAPE)
	_require(not (_instance.get("_upgrade_scrim") as Control).visible, "Keyboard Escape closes Character")
	var reduced: Dictionary = settings.duplicate(true)
	reduced["reduced_motion"] = true
	_instance.call("_on_settings_changed", reduced)
	_instance.call("_open_character_overlay", "equipment")
	_require(_instance.get("_character_menu_arrival_tween") == null, "Reduced motion opening is static")
	await _settle()
	await _save_screenshot("11_reduced_motion.png")
	_instance.call("_close_card_upgrade_overlay")
	await _load_combat_fixture(_instance)
	_instance.call("_open_character_overlay", "magic")
	await _settle()
	_require(not bool(_instance.call("_magic_overlay_can_change")), "Combat menu retains its lock")
	attuned = _instance.get("_magic_attuned_tiles") as Dictionary
	for tile: Control in attuned.values():
		_require(bool(tile.get_node("CharacterCardStrip").get("locked")), "Combat spells use the shared locked strip state")
	await _save_screenshot("12_combat_locked.png")
	_instance.queue_free()
	await process_frame
	_cleanup_storage()
	print(ProjectSettings.globalize_path(CHARACTER_OUTPUT))
	if DisplayServer.get_name() == "headless":
		print("CHARACTER PROOF: HEADLESS ASSERTIONS ONLY; NO SCREENSHOTS")
	print("CHARACTER MENU POLISH: PASS")
	quit(0)

func _assert_body_fit(dialog: Control) -> void:
	var body: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	for panel_name: String in ["EquipmentLoadoutPanel", "EquipmentInventoryPanel", "MagicAttunedPanel", "MagicInventoryPanel", "CurrentDeckPanel"]:
		var panel: Control = body.find_child(panel_name, true, false) as Control
		if panel != null:
			_require(body.get_global_rect().encloses(panel.get_global_rect()), "Column fits the native body: " + panel_name)

func _assert_gear_components(dialog: Control) -> void:
	var slots: Dictionary = _instance.get("_equipment_slot_panels") as Dictionary
	_require(slots.size() == 5, "Paper doll exposes all five native gear slots")
	for slot: Control in slots.values():
		_require(slot.size == Vector2(62.0, 62.0), "Gear socket endpoint is 62px")
	var art: Control = dialog.find_child("EquipmentCharacterArt", true, false) as Control
	_require(art.size == Vector2(260.0, 260.0), "Hero preview is enlarged to 260px")
	_require(dialog.find_child("CharacterInkPool", true, false) != null, "Paper doll uses the unit-0 ink pool")
	var deck: Control = dialog.find_child("CurrentDeckPanel", true, false) as Control
	for grid: Node in deck.find_children("CharacterDeckGrid", "", true, false):
		_require((grid as GridContainer).columns == 2, "Each deck source uses a two-column strip grid")
	var pale_spark_strips: int = 0
	for strip: Node in deck.find_children("CharacterCardStrip", "", true, false):
		if str(strip.get_node("CardBadgeName").text) == "Pale Spark":
			pale_spark_strips += 1
			_require(str(strip.get_node("Count").text) == "×2", "Equivalent Pale Spark copies share their ×2 count")
	_require(pale_spark_strips == 1, "Retired Bone Dart and Pale Spark resolve to one deck strip")
	var attuned: Array = (_instance.get("_run_state") as Dictionary).get("attuned_magic_cards", []) as Array
	_require(attuned.count("bone_dart") == 1 and attuned.count("pale_spark") == 1, "Deck grouping preserves the original loadout IDs")
	_require(Menu.deck_card_id("dull_bolt") == "dull_bolt" and Menu.deck_card_id("waning_pulse") == "waning_pulse", "Distinct printed spells preserve their deck identities")

func _assert_review_header(dialog: Control) -> void:
	var close: Button = dialog.find_child("CloseCharacterOverlay", true, false) as Button
	var glyph: Label = close.get_node("CharacterCloseGlyph") as Label
	_require(close.get("socket_size") == 40.0, "Close uses a 40px native socket")
	_require(glyph.text == "✕" and glyph.get_theme_font_size("font_size") == 18, "Close draws a UI 18 glyph above the socket")
	_require(glyph.mouse_filter == Control.MOUSE_FILTER_IGNORE and glyph.get_global_rect() == close.get_global_rect(), "Close glyph preserves native input and fills its socket")
	_require(glyph.get_theme_color("font_color") == Palette.TEXT_2, "Idle close glyph uses TEXT_2")
	await _point(close.get_global_rect().get_center())
	_require(close.is_hovered() and glyph.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Hovered close glyph uses GOLD_BRIGHT")
	await _point(Vector2.ZERO)
	close.grab_focus()
	_require(glyph.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Focused close glyph uses GOLD_BRIGHT")
	_viewport.gui_release_focus()
	_require(glyph.get_theme_color("font_color") == Palette.TEXT_2, "Close glyph returns to TEXT_2 after focus leaves")
	_click_now(close)
	_require(not (_instance.get("_upgrade_scrim") as Control).visible, "Close glyph allows native pointer activation")
	_instance.call("_open_character_overlay", "equipment")
	await _settle()
	_viewport.gui_release_focus()
	for entry: Dictionary in [
		{"chip": "ProgressionSkillPointsChip", "path": Menu.SKILL_POINT_ICON_PATH},
		{"chip": "ProgressionMoltshardsChip", "path": Menu.MOLTSHARD_ICON_PATH}
	]:
		var chip: Control = dialog.find_child(str(entry["chip"]), true, false) as Control
		var socket: Button = chip.get_node("Socket") as Button
		var icon: Texture2D = socket.get("_source_icon") as Texture2D
		var path: String = str(entry["path"])
		if FileAccess.file_exists(path) or ResourceLoader.exists(path):
			_require(icon != null and str(icon.get_meta("asset_source_path", "")) == path, "Resource chip uses its purpose-built icon: " + path)
			_require(icon.get_size() == Vector2(64.0, 64.0), "Resource icon source is 64×64 pixel art")
		else:
			_require(icon == null, "Missing resource art leaves an empty socket without a borrowed icon")
		_require(socket.get("icon_filter") == CanvasItem.TEXTURE_FILTER_NEAREST, "Resource sockets retain nearest filtering")
	var missing_path: String = "res://assets/art/icons/character_menu_missing_test_icon.png"
	_require(Menu.resource_icon(missing_path) == null and not Menu.AssetLoader._texture_cache.has(missing_path), "Missing optional icons do not poison the texture cache")
	var defiance: Label = dialog.find_child("ProgressionDefianceLabel", true, false) as Label
	var caption: Label = defiance.get_parent().get_node("Caption") as Label
	_require(defiance.text == "0/0" and defiance.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Defiance value is only the gold remaining/capacity pair")
	_require(caption.text == "DEFIANCE · NEXT 4", "Defiance threshold lives in its eyebrow caption")
	_require(str(defiance.get_meta("resource_summary_text", "")) == "0/0 · next 4", "Defiance keeps the underlying combined resource string available")

func _assert_wrapper_states(dialog: Control) -> void:
	for property: String in ["_equipment_slot_panels", "_equipment_inventory_tiles", "_item_equipped_tiles", "_item_inventory_tiles", "_magic_attuned_tiles", "_magic_inventory_tiles"]:
		for wrapper: Control in (_instance.get(property) as Dictionary).values():
			for state: String in ["focus", "hover", "hover_pressed", "pressed"]:
				_require(wrapper.has_theme_stylebox_override(state) and wrapper.get_theme_stylebox(state) is StyleBoxEmpty, "Native %s paint is suppressed on %s wrappers" % [state, property])
	for strip: Node in dialog.find_children("CharacterCardStrip", "", true, false):
		for state: String in ["focus", "hover", "hover_pressed", "pressed"]:
			_require((strip as Control).get_theme_stylebox(state) is StyleBoxEmpty and (strip.get_parent() as Control).get_theme_stylebox(state) is StyleBoxEmpty, "Card strips and their wrappers share no opaque native state paint")

func _assert_socket_render(slot: Control) -> void:
	_require(slot.get_theme_stylebox("focus") is StyleBoxEmpty, "Pointer, keyboard and controller focus use only the socket treatment")
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	var corner: Vector2i = Vector2i(slot.get_global_rect().position - Vector2(3.0, 3.0))
	var pixel: Color = frame.get_pixelv(corner)
	_require(maxf(pixel.r, maxf(pixel.g, pixel.b)) < 0.65, "Focused socket glow leaves its outer corner dark without a white square")

func _click_now(control: Control) -> void:
	_require(control != null, "Pointer target exists")
	var point: Vector2 = control.get_global_rect().get_center()
	for down: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		_viewport.push_input(event, true)

func _key_event(code: Key) -> void:
	for down: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = down
		_viewport.push_input(event, true)
		await process_frame

func _capture_frame(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var frame: Image = _viewport.get_texture().get_image()
	_require(frame.get_size() == Vector2i(1920, 1080), "Capture uses the fixed SubViewport texture")
	_require(frame.save_png(ProjectSettings.globalize_path(CHARACTER_OUTPUT.path_join(filename))) == OK, "Saved native Character image: " + filename)
