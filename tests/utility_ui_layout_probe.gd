extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const DEFAULT_SIZE := Vector2i(1280, 720)
const MODAL_TRAVERSAL_STEPS: int = 9
const SETTINGS_TRAVERSAL_STEPS: int = 12

var _viewport_size: Vector2i = DEFAULT_SIZE
var _phase: String = "after"
var _validate_layout: bool = true
var _character_only: bool = false
var _modal_focus_only: bool = false
var _focus_capture: String = ""
var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_parse_args()
	if DisplayServer.get_name() == "headless":
		print("HEADLESS SEMANTICS ONLY: no renderer captures")
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	SettingsStore.set_storage_path("user://utility_ui_probe_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	ProgressionStore.set_storage_path("user://labyrinth_progression_utility_ui_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_utility_ui_probe.save")
	ProgressionStore.clear_saved_run()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = _viewport_size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = _viewport_size
	await process_frame
	await process_frame
	root.size = _viewport_size
	await process_frame
	print("Utility UI probe viewport=%s window=%s content_scale=%s" % [root.get_viewport().get_visible_rect().size, root.size, root.content_scale_size])
	var output_dir: String = "user://utility_ui_layout/%s_%dx%d" % [_phase, _viewport_size.x, _viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	_clear_probe_output(output_dir)
	await _capture_targeted_surfaces(output_dir)
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d layout failures)" % _failures.size())
		quit(1)
		return
	print(ProjectSettings.globalize_path(output_dir))
	print("TEST RESULT: PASS")
	quit()

func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--width="):
			_viewport_size.x = maxi(640, int(arg.trim_prefix("--width=")))
		elif arg.begins_with("--height="):
			_viewport_size.y = maxi(480, int(arg.trim_prefix("--height=")))
		elif arg.begins_with("--phase="):
			_phase = arg.trim_prefix("--phase=").strip_edges()
		elif arg == "--no-validate":
			_validate_layout = false
		elif arg == "--character-only":
			_character_only = true
		elif arg == "--modal-focus-only":
			_modal_focus_only = true
		elif arg.begins_with("--focus-capture="):
			_focus_capture = arg.trim_prefix("--focus-capture=")

func _capture_targeted_surfaces(output_dir: String) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_failures.append("Run scene should load for utility UI layout coverage")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	var run_engine = RunEngineScript.new()
	var base_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	instance.call("_load_run_state", base_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await _settle()
	await _check_modal_focus(instance, output_dir, "camp")
	if _modal_focus_only:
		var combat_coord: Vector2i = _first_available_combat_coord(run_engine, base_state)
		_require_focus(combat_coord != Vector2i(999, 999), "Pause focus proof needs an available combat room")
		if combat_coord != Vector2i(999, 999):
			var combat_state: Dictionary = run_engine.move_to_pre_battle(base_state.duplicate(true), combat_coord)
			combat_state = run_engine.begin_pre_battle_combat(combat_state)
			instance.call("_load_run_state", combat_state)
			instance.call("_close_dialogue")
			await _settle()
			await _check_modal_focus(instance, output_dir, "combat pause")
		instance.queue_free()
		await _settle()
		return

	instance.call("_open_large_map")
	await _settle()
	await _capture(output_dir, "large_map")
	_check_inside_viewport(instance.get("_large_map_dialog") as Control, "Large map dialog", UiTypography.SAFE_MARGIN)
	instance.call("_close_large_map")

	instance.call("_open_character_overlay", "skills")
	await _settle()
	await _capture(output_dir, "character_stats")
	var character_dialog: Control = instance.get("_upgrade_dialog") as Control
	var stats_dialog_rect: Rect2 = character_dialog.get_global_rect() if character_dialog != null else Rect2()
	_check_inside_viewport(character_dialog, "Character dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(character_dialog, "Character dialog")
	_print_dialog_metrics(instance, "stats")
	instance.call("_switch_character_overlay_mode", "equipment")
	await _settle()
	character_dialog = instance.get("_upgrade_dialog") as Control
	await _capture(output_dir, "character_gear")
	_check_inside_viewport(character_dialog, "Character gear dialog", UiTypography.SAFE_MARGIN)
	_check_same_rect(character_dialog, stats_dialog_rect, "Character gear dialog")
	_check_character_subpanels(character_dialog, ["EquipmentLoadoutPanel", "EquipmentInventoryPanel", "CurrentDeckPanel"], "Gear")
	_print_dialog_metrics(instance, "gear")
	instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	character_dialog = instance.get("_upgrade_dialog") as Control
	await _capture(output_dir, "character_magic")
	_check_inside_viewport(character_dialog, "Character magic dialog", UiTypography.SAFE_MARGIN)
	_check_same_rect(character_dialog, stats_dialog_rect, "Character magic dialog")
	_check_character_subpanels(character_dialog, ["MagicAttunedPanel", "CurrentDeckPanel"], "Magic")
	_print_dialog_metrics(instance, "magic")
	instance.call("_close_card_upgrade_overlay")
	if _character_only:
		instance.queue_free()
		await process_frame
		return

	instance.set("_progression_overlay_mode", "level_up")
	instance.call("_rebuild_progression_overlay")
	var progression_scrim: Control = instance.get("_upgrade_scrim") as Control
	if progression_scrim != null:
		progression_scrim.visible = true
	await _settle()
	await _capture(output_dir, "progression_level_up")
	_check_inside_viewport(instance.get("_upgrade_dialog") as Control, "Progression dialog", UiTypography.SAFE_MARGIN)
	instance.call("_close_card_upgrade_overlay")

	instance.call("_open_grimoire_overlay")
	await _settle()
	instance.call("_on_grimoire_entry_pressed", "magick:pale_spark")
	await _settle()
	await _capture(output_dir, "grimoire")
	_check_inside_viewport(instance.get("_grimoire_dialog") as Control, "Grimoire dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(instance.get("_grimoire_dialog") as Control, "Grimoire dialog")
	instance.call("_close_grimoire_overlay")

	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, base_state)
	if combat_coord == Vector2i(999, 999):
		_failures.append("Utility UI probe needs an available combat room")
	else:
		await instance.call("_on_map_view_room_selected", combat_coord)
		await _settle()
		await _capture(output_dir, "pre_battle")
		_check_inside_viewport(instance.get("_pre_battle_panel") as Control, "Pre-battle dialog", UiTypography.SPACE_LARGE)
		var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
		if pre_battle_scrim != null:
			pre_battle_scrim.visible = false
		await _check_modal_focus(instance, output_dir, "pause")

	instance.call("_open_menu_overlay")
	await _settle()
	await _capture(output_dir, "pause")
	_check_inside_viewport(instance.get("_menu_dialog") as Control, "Pause dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(instance.get("_menu_dialog") as Control, "Pause dialog")
	instance.call("_close_menu_overlay")

	var reward_state: Dictionary = base_state.duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash"],
		"heal_amount": RunEngineScript.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.call("_load_run_state", reward_state)
	await _settle()
	await _capture(output_dir, "reward")
	_check_reward_choices(instance)

	var victory_state: Dictionary = _state_for_room(run_engine, base_state, Vector2i(8, 0), "victory")
	victory_state["victory"] = true
	victory_state["held_embers"] = 42
	instance.call("_load_run_state", victory_state)
	await _settle()
	var run_end_recap: Control = instance.get("_run_end_recap") as Control
	if run_end_recap != null:
		run_end_recap.call("seek_presentation", 0.62)
	await _settle()
	await _capture(output_dir, "victory")
	var victory_panel: Control = run_end_recap.find_child("OutcomeRecap", true, false) as Control if run_end_recap != null else null
	_check_inside_viewport(victory_panel, "Victory recap", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(victory_panel, "Victory recap")

	var defeat_state: Dictionary = _state_for_room(run_engine, base_state, Vector2i(1, 0), "defeat")
	defeat_state["player_hp"] = 0
	defeat_state["held_embers"] = 23
	instance.call("_load_run_state", defeat_state)
	await _settle()
	run_end_recap = instance.get("_run_end_recap") as Control
	if run_end_recap != null:
		run_end_recap.call("seek_presentation", float(run_end_recap.call("presentation_duration")))
	await _settle()
	await _capture(output_dir, "defeat")
	var defeat_panel: Control = run_end_recap.find_child("LastLightRecap", true, false) as Control if run_end_recap != null else null
	_check_inside_viewport(defeat_panel, "Defeat recap")
	_check_descendant_minimum_font(defeat_panel, "Defeat recap")
	_check_inside_viewport(run_end_recap.find_child("NewRunButton", true, false) as Control if run_end_recap != null else null, "Defeat new-run action")
	_check_inside_viewport(run_end_recap.find_child("MainMenuButton", true, false) as Control if run_end_recap != null else null, "Defeat main-menu action")

	instance.queue_free()
	await _settle()

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

func _capture(output_dir: String, surface: String) -> void:
	var image: Image = await _renderer_image()
	if image != null: image.save_png("%s/%s.png" % [output_dir, surface])

func _renderer_image() -> Image:
	if DisplayServer.get_name() == "headless": return null
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_require_focus(false, "Utility proof should capture a renderer image")
		return null
	var actual: Vector2i = image.get_size()
	_require_focus(is_equal_approx(float(actual.x) / actual.y, float(_viewport_size.x) / _viewport_size.y), "Utility capture should preserve viewport proportions")
	if actual != _viewport_size: image.resize(_viewport_size.x, _viewport_size.y, Image.INTERPOLATE_LANCZOS)
	return image

func _check_modal_focus(instance: Node, output_dir: String, context: String) -> void:
	var hud: Button = instance.get("grimoire_button") as Button
	var menu: Control = instance.get("_menu_dialog") as Control
	var scrim: Control = instance.get("_menu_scrim") as Control
	var settings: Control = instance.get("_settings_panel") as Control
	var first: Button = _find_control_with_text(menu, "Character") as Button
	var danger: Button = _find_control_with_text(menu, "Succumb to the Darkness") as Button
	var close: Button = _find_control_with_text(menu, "Close") as Button
	var activations: Dictionary = {"count": 0}
	var count_activation := func() -> void: activations["count"] += 1
	hud.pressed.connect(count_activation)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	var original_focus_mode: int = hud.focus_mode
	# A real HUD control owns focus at the instant the modal opens.
	var run_before: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	hud.grab_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	_require_focus(root.gui_get_focus_owner() == first, context + ": opening immediately focuses the first menu button")
	await _key(KEY_DOWN)
	_require_focus(root.gui_get_focus_owner() == _find_control_with_text(menu, "Grimoire"), context + ": the first arrow navigates immediately")
	if context == "camp" and _focus_capture in ["", "keyboard"]:
		await _capture(output_dir, "modal_camp_keyboard")
	# Traverse both native directions repeatedly, including the wrap boundaries.
	for key: Key in [KEY_TAB, KEY_DOWN, KEY_UP, KEY_LEFT, KEY_RIGHT]:
		for step: int in range(MODAL_TRAVERSAL_STEPS):
			await _key(key)
			_require_focus(_focus_inside(menu), context + ": navigation must stay in the menu")
	await _key(KEY_ESCAPE)
	await _settle()
	_require_focus(not scrim.visible and root.gui_get_focus_owner() == hud, context + ": closing should restore the previous HUD focus")
	_require_focus(hud.focus_mode == original_focus_mode, context + ": closing should restore the HUD focus mode")
	# Opening excludes stale background focus before the first Enter dispatch.
	hud.grab_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	_require_focus(root.gui_get_focus_owner() == first, context + ": focus is ready before Enter")
	close.grab_focus()
	await _key(KEY_ENTER)
	_require_focus(int(activations["count"]) == 0, context + ": Enter must never activate the HUD behind the menu")
	_require_focus(not scrim.visible, context + ": first Enter activates the focused menu button")
	instance.call("_close_menu_overlay")
	instance.call("_close_grimoire_overlay")
	# No initial focus, Tab, Shift+Tab, and a disabled first option.
	for backwards: bool in [false, true]:
		if root.gui_get_focus_owner() != null: root.gui_get_focus_owner().release_focus()
		instance.call("_open_menu_overlay")
		await _settle()
		_require_focus(root.gui_get_focus_owner() == first, context + ": opening without prior focus starts on Character")
		await _key(KEY_TAB, backwards)
		_require_focus(_focus_inside(menu) and root.gui_get_focus_owner() != first, context + ": first Tab navigates immediately inside the menu")
		instance.call("_close_menu_overlay")
	first.disabled = true
	instance.call("_open_menu_overlay")
	await _settle()
	_require_focus(root.gui_get_focus_owner() == _find_control_with_text(menu, "Grimoire"), context + ": opening skips disabled buttons")
	instance.call("_close_menu_overlay")
	first.disabled = false
	# Settings shares the scope; Back returns to its opener inside Camp/Pause.
	hud.grab_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	await _key(KEY_DOWN)
	await _key(KEY_DOWN)
	var settings_button: Button = _find_control_with_text(menu, "Settings") as Button
	_require_focus(root.gui_get_focus_owner() == settings_button, context + ": down should reach Settings")
	if root.gui_get_focus_owner() == settings_button:
		await _key(KEY_ENTER)
	else:
		instance.call("_open_settings_overlay")
	_require_focus(settings.visible, context + ": native Enter should open Settings")
	await _key(KEY_TAB)
	_require_focus(_focus_inside(settings), context + ": Settings must seed its own focus")
	for step: int in range(SETTINGS_TRAVERSAL_STEPS * 2):
		await _key(KEY_TAB, step >= SETTINGS_TRAVERSAL_STEPS)
		_require_focus(_focus_inside(settings), context + ": Settings traversal must exclude the HUD")
	await _key(KEY_ESCAPE)
	_require_focus(menu.visible and not settings.visible and root.gui_get_focus_owner() == settings_button, context + ": Settings Back should restore its menu opener")
	await _key(KEY_ESCAPE)
	_require_focus(root.gui_get_focus_owner() == hud, context + ": nested close should restore HUD focus")
	# Native controller events navigate and activate on their first dispatch.
	router.call("clear_forced_state_for_test")
	hud.grab_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	_require_focus(root.gui_get_focus_owner() == first, context + ": controller menu focuses immediately")
	settings_button.grab_focus()
	await _joy(JOY_BUTTON_A)
	_require_focus(scrim.visible and settings.visible, context + ": first controller A activates focused Settings")
	await _joy(JOY_BUTTON_B)
	instance.call("_close_menu_overlay")
	if root.gui_get_focus_owner() != null: root.gui_get_focus_owner().release_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	_require_focus(root.gui_get_focus_owner() == first, context + ": controller starts on Character")
	if context == "camp" and _focus_capture in ["", "controller"]:
		await _capture(output_dir, "modal_camp_controller")
	# Reach Succumb solely through controller navigation; leave it unactivated.
	for step: int in range(5): await _joy(JOY_BUTTON_DPAD_DOWN)
	_require_focus(root.gui_get_focus_owner() == danger, context + ": controller should reach Succumb")
	var ornament: Control = danger.get_node(UiSkin.BUTTON_ORNAMENT_NAME) as Control
	_require_focus(ornament.call("_accent_color", UiSkin.STATE_FOCUS) == ornament.call("_accent_color", UiSkin.STATE_NORMAL), context + ": danger focus must keep the normal danger material")
	var focus_style: StyleBoxFlat = danger.get_theme_stylebox("focus") as StyleBoxFlat
	_require_focus(not focus_style.draw_center, context + ": danger focus should add only the standard ring")
	var standard_focus: StyleBoxFlat = UiSkin.new().make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
	_require_focus(focus_style.border_color == standard_focus.border_color and focus_style.shadow_color == standard_focus.shadow_color, context + ": danger focus uses the standard ring and halo")
	_require_focus(danger.get_theme_stylebox("normal").bg_color == UiSkin.new().make_button_style(UiSkin.VARIANT_DESTRUCTIVE).bg_color, context + ": danger keeps its red plate underneath the focus overlay")
	if context == "camp" and _focus_capture in ["", "controller"]:
		await _capture(output_dir, "modal_succumb_controller")
	await _joy(JOY_BUTTON_B)
	# Pointer clicking and native Close activation still follow their usual path.
	router.call("set_forced_state_for_test", "pointer", "steam_deck")
	hud.grab_focus()
	instance.call("_open_menu_overlay")
	await _settle()
	await _click(close.get_global_rect().get_center())
	_require_focus(not scrim.visible and root.gui_get_focus_owner() == hud, context + ": pointer Close should restore the prior focus (visible=%s focus=%s point=%s hovered=%s)" % [scrim.visible, root.gui_get_focus_owner(), close.get_global_rect(), close.is_hovered()])
	_require_focus(int(activations["count"]) == 0, context + ": no background activation during any modal input")
	_require_focus((instance.get("_run_state") as Dictionary) == run_before, context + ": modal input should preserve run/combat state and RNG")
	hud.pressed.disconnect(count_activation)
	router.call("clear_forced_state_for_test")
	print("MODAL FOCUS REGRESSIONS: %s checked" % context)

func _focus_inside(scope: Control) -> bool:
	var focus: Control = root.gui_get_focus_owner()
	return focus != null and scope.is_ancestor_of(focus)

func _require_focus(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)

func _key(key: Key, shift: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.shift_pressed = shift
	await _press(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	await _press(event)

func _press(event: InputEvent) -> void:
	event.pressed = true
	root.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	root.push_input(event, true)
	await process_frame

func _first_available_combat_coord(run_engine, state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(state):
		var preview_state: Dictionary = run_engine.move_to_room(state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat":
			return coord
	return Vector2i(999, 999)

func _state_for_room(run_engine, source_state: Dictionary, coord: Vector2i, mode: String) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode == "room"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _check_inside_viewport(control: Control, label: String, safe_margin: float = 0.0) -> void:
	if not _validate_layout:
		return
	if control == null:
		_failures.append("%s should exist" % label)
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	var viewport_rect := Rect2(Vector2.ONE * safe_margin, viewport_size - Vector2.ONE * safe_margin * 2.0)
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_rect.end.x + 1.0 or rect.end.y > viewport_rect.end.y + 1.0:
		_failures.append("%s should fit viewport; rect=%s viewport=%s" % [label, rect, viewport_rect])

func _check_same_rect(control: Control, expected: Rect2, label: String) -> void:
	if not _validate_layout:
		return
	if control == null:
		_failures.append("%s should exist" % label)
		return
	var actual: Rect2 = control.get_global_rect()
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s should keep the Stats bounds; actual=%s expected=%s" % [label, actual, expected])

func _check_character_subpanels(dialog: Control, panel_names: Array[String], label: String) -> void:
	if not _validate_layout or dialog == null:
		return
	var body_frame: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	if body_frame == null:
		_failures.append("%s body frame should exist" % label)
		return
	var frame_rect: Rect2 = body_frame.get_global_rect()
	for panel_name: String in panel_names:
		var panel: Control = body_frame.find_child(panel_name, true, false) as Control
		if panel == null:
			_failures.append("%s subpanel %s should exist" % [label, panel_name])
			continue
		var panel_rect: Rect2 = panel.get_global_rect()
		if not frame_rect.encloses(panel_rect):
			_failures.append("%s subpanel %s should fit its body frame; panel=%s frame=%s" % [label, panel_name, panel_rect, frame_rect])

func _check_descendant_minimum_font(root_control: Control, label: String) -> void:
	if not _validate_layout or root_control == null:
		return
	for node: Node in root_control.find_children("*", "Label", true, false):
		var text_label := node as Label
		if text_label == null or text_label.text.strip_edges().is_empty():
			continue
		var font_size: int = text_label.get_theme_font_size("font_size")
		if font_size < 14:
			_failures.append("%s label '%s' should use at least the caption floor; got %d" % [label, text_label.text.left(28), font_size])

func _check_reward_choices(instance: Node) -> void:
	if not _validate_layout:
		return
	var reward_bar: Control = instance.get("_relic_choice_bar") as Control
	if reward_bar == null:
		_failures.append("Reward choices should exist")
		return
	for child: Node in reward_bar.get_children():
		if child is Control:
			_check_inside_viewport(child as Control, "Reward choice")

func _find_control_with_text(parent: Control, text: String) -> Control:
	if parent == null:
		return null
	for node: Node in parent.find_children("*", "Control", true, false):
		if node is Label and (node as Label).text == text:
			return node as Control
		if node is Button and (node as Button).text == text:
			return node as Control
	return null

func _print_dialog_metrics(instance: Node, mode: String) -> void:
	var dialog: Control = instance.get("_upgrade_dialog") as Control
	if dialog == null:
		return
	print("Character %s custom=%s actual=%s combined=%s" % [mode, dialog.custom_minimum_size, dialog.size, dialog.get_combined_minimum_size()])

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
