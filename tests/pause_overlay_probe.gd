extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/pause_overlay_20260715_v1"
const INVALID_COORD := Vector2i(999, 999)

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if OS.get_cmdline_user_args().has("--ui15-proof"):
		call_deferred("_run_ui15_proof")
		return
	ProgressionStore.set_storage_path("user://pause_overlay_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://pause_overlay_probe_run.save")
	SettingsStore.set_storage_path("user://pause_overlay_probe_settings.json")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	await process_frame
	await process_frame
	_clear_probe_output()
	await _run_probe()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d pause-overlay failures)" % _failures.size())
		quit(1)
		return
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: PASS")
	quit()

func _run_probe() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_require(packed != null, "Run scene should load for pause overlay proof")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	var run_engine = RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(7915, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, run_state)
	_require(combat_coord != INVALID_COORD, "Pause overlay proof needs an available combat room")
	if combat_coord == INVALID_COORD:
		instance.queue_free()
		return
	run_state = run_engine.move_to_pre_battle(run_state, combat_coord)
	run_state = run_engine.begin_pre_battle_combat(run_state)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await _settle(0.85)

	var menu_scrim: ColorRect = instance.get("_menu_scrim") as ColorRect
	var menu_dialog: PanelContainer = instance.get("_menu_dialog") as PanelContainer
	var settings_panel: PanelContainer = instance.get("_settings_panel") as PanelContainer
	var turn_order: Control = instance.get("_turn_order_anchor") as Control
	var choice_overlay: Control = instance.get("_choice_button_overlay") as Control
	var pass_preview: Control = instance.get("_pass_preview_overlay") as Control
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandTuckMargin/HandBox") as Control
	_require(menu_scrim != null, "Pause scrim should exist")
	_require(menu_dialog != null, "Pause dialog should exist")
	_require(settings_panel != null, "In-run settings panel should exist")
	_require(turn_order != null and turn_order.visible, "Combat proof should show turn order")
	_require(choice_overlay != null and choice_overlay.visible, "Combat proof should show the Pass action")
	_require(pass_preview != null and pass_preview.visible, "Combat proof should show the On Turn End preview")
	_require(hand_box != null and hand_box.get_child_count() > 1, "Combat proof should show a multi-card hand")
	var turn_order_panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var pass_preview_chip: PanelContainer = instance.find_child("PassPreviewChip", true, false) as PanelContainer
	var mini_map_overlay: PanelContainer = instance.get("mini_map_overlay") as PanelContainer
	var log_overlay: PanelContainer = instance.get("log_overlay") as PanelContainer
	_require(turn_order_panel != null and turn_order_panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Turn Clock should use the authored raster border")
	_require(pass_preview_chip != null and pass_preview_chip.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null, "On Turn End should use the shared asymmetric shape")
	_require(mini_map_overlay != null and mini_map_overlay.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Minimap should use the authored raster border")
	_require(log_overlay != null and log_overlay.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Combat log should use the authored raster border")
	_require(menu_dialog != null and menu_dialog.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Pause/Camp should use the raster-only outer frame")
	_require(settings_panel != null and settings_panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "Settings should use the raster-only outer frame")
	if menu_scrim == null or menu_dialog == null or settings_panel == null or hand_box == null:
		instance.queue_free()
		return
	_require(not menu_scrim.z_as_relative, "Pause scrim should use an absolute z-order")
	_require(menu_scrim.is_ancestor_of(menu_dialog), "Pause dialog should live inside the dimming subtree")
	_require(menu_scrim.is_ancestor_of(settings_panel), "Settings should live inside the dimming subtree")
	_require_surfaces_below_menu(menu_scrim, turn_order, choice_overlay, pass_preview, hand_box)

	var baseline: Image = await _capture("combat_baseline.png")
	instance.call("_open_menu_overlay")
	await _settle()
	var paused: Image = await _capture("pause_menu.png")
	_require(menu_scrim.visible, "Pause should keep its dimming scrim visible")
	_require(menu_dialog.visible, "Pause should show its dialog")
	var dialog_rect: Rect2 = menu_dialog.get_global_rect().grow(4.0)
	_require_region_dimmed(baseline, paused, turn_order, dialog_rect, "turn order")
	_require_region_dimmed(baseline, paused, choice_overlay, dialog_rect, "Pass action")
	_require_region_dimmed(baseline, paused, pass_preview, dialog_rect, "On Turn End preview")
	for index: int in range(hand_box.get_child_count()):
		_require_region_dimmed(baseline, paused, hand_box.get_child(index) as Control, dialog_rect, "hand card %d" % (index + 1))

	instance.call("_open_settings_overlay")
	await _settle()
	await _capture("pause_settings.png")
	_require(menu_scrim.visible, "Settings opened from pause should retain the dimming scrim")
	_require(settings_panel.visible, "Settings opened from pause should be visible")
	_require(not menu_dialog.visible, "Settings should replace only the pause dialog")
	_require_surfaces_below_menu(menu_scrim, turn_order, choice_overlay, pass_preview, hand_box)
	instance.queue_free()
	await process_frame

func _first_available_combat_coord(run_engine, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat":
			return coord
	return INVALID_COORD

func _require_surfaces_below_menu(menu_scrim: ColorRect, turn_order: Control, choice_overlay: Control, pass_preview: Control, hand_box: Control) -> void:
	var menu_z: int = _effective_canvas_z(menu_scrim)
	for entry: Dictionary in [
		{"control": turn_order, "label": "turn order"},
		{"control": choice_overlay, "label": "Pass action"},
		{"control": pass_preview, "label": "On Turn End preview"},
		{"control": hand_box, "label": "player hand"}
	]:
		var surface: Control = entry.get("control") as Control
		_require(surface != null and menu_z > _maximum_effective_canvas_z(surface), "Pause should render above the %s" % str(entry.get("label", "combat UI")))

func _effective_canvas_z(item: CanvasItem) -> int:
	var effective_z: int = item.z_index
	if not item.z_as_relative:
		return effective_z
	var ancestor: Node = item.get_parent()
	while ancestor != null:
		if ancestor is CanvasItem:
			var ancestor_item := ancestor as CanvasItem
			effective_z += ancestor_item.z_index
			if not ancestor_item.z_as_relative:
				break
		ancestor = ancestor.get_parent()
	return effective_z

func _maximum_effective_canvas_z(node: Node) -> int:
	var maximum_z: int = -4096
	if node is CanvasItem:
		maximum_z = _effective_canvas_z(node as CanvasItem)
	for child: Node in node.get_children():
		maximum_z = maxi(maximum_z, _maximum_effective_canvas_z(child))
	return maximum_z

func _require_region_dimmed(before: Image, after: Image, control: Control, exclusion: Rect2, label: String) -> void:
	_require(control != null, "%s should exist for dimming proof" % label)
	if control == null:
		return
	var image_scale := Vector2(before.get_size()) / Vector2(VIEWPORT_SIZE)
	var control_rect: Rect2 = control.get_global_rect()
	var rect := Rect2(control_rect.position * image_scale, control_rect.size * image_scale)
	var exclusion_rect := Rect2(exclusion.position * image_scale, exclusion.size * image_scale)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(before.get_size()))
	rect = rect.intersection(viewport_rect).grow(-3.0 * maxf(image_scale.x, image_scale.y))
	var brightest: float = 0.0
	var dimmed_brightness: float = 0.0
	for y: int in range(maxi(0, floori(rect.position.y)), mini(before.get_height(), ceili(rect.end.y)), 3):
		for x: int in range(maxi(0, floori(rect.position.x)), mini(before.get_width(), ceili(rect.end.x)), 3):
			var point := Vector2(float(x), float(y))
			if exclusion_rect.has_point(point):
				continue
			var source_luminance: float = before.get_pixel(x, y).get_luminance()
			if source_luminance > brightest:
				brightest = source_luminance
				dimmed_brightness = after.get_pixel(x, y).get_luminance()
	_require(brightest >= 0.03, "%s should expose a readable pixel for dimming proof" % label)
	_require(dimmed_brightness <= brightest * 0.68 + 0.006, "%s should be visibly dimmed by the pause scrim (before=%.3f after=%.3f)" % [label, brightest, dimmed_brightness])

func _settle(seconds: float = 0.08) -> void:
	await process_frame
	await process_frame
	await create_timer(seconds).timeout
	await process_frame

func _capture(file_name: String) -> Image:
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	var error: Error = image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	_require(error == OK, "Pause overlay proof should save %s" % file_name)
	return image

func _clear_probe_output() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	DirAccess.make_dir_recursive_absolute(absolute_dir)
	var directory := DirAccess.open(absolute_dir)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".png"):
			DirAccess.remove_absolute(absolute_dir.path_join(file_name))

func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)

# ui-15: native exact-size SubViewport proof. The desktop window is parked by
# visual_probe_runner; no root-window capture, resize or synthetic focus state.
const UI15_OUTPUT: String = "user://ui15"
const UI15_SETTLE_FRAMES: int = 8
const UI15_NAVIGATION_STEPS: int = 12
var _ui15_viewport: SubViewport
var _ui15_output: String
var _ui15_baseline: bool = false

func _run_ui15_proof() -> void:
	_ui15_baseline = OS.get_cmdline_user_args().has("--before")
	ProgressionStore.set_storage_path("user://ui15_profile.json")
	ProgressionStore.set_run_storage_path("user://ui15_run.save")
	SettingsStore.set_storage_path("user://ui15_settings.json")
	ProgressionStore.clear_saved_run()
	var profile: Dictionary = ProgressionStore.default_data()
	profile = preload("res://scripts/contextual_combat_tutorial.gd").dismiss_tutorial(profile)
	ProgressionStore.save_data(profile)
	for configuration: Dictionary in [{"size": Vector2i(1920, 1080), "scale": 1.0}, {"size": Vector2i(1280, 800), "scale": 1.15}]:
		var physical: Vector2i = configuration["size"]
		var ui_scale: float = configuration["scale"]
		var settings: Dictionary = SettingsStore.default_settings()
		settings["ui_scale"] = ui_scale
		settings["reduced_motion"] = false
		SettingsStore.save_settings(settings)
		SettingsStore.apply_settings(settings, root, false)
		_ui15_viewport = SubViewport.new()
		_ui15_viewport.size = physical
		_ui15_viewport.size_2d_override = Vector2i(Vector2(physical) / ui_scale)
		_ui15_viewport.size_2d_override_stretch = true
		_ui15_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_ui15_viewport)
		_ui15_viewport.notify_mouse_entered()
		_ui15_output = "%s/%s/%dx%d_ui%d" % [UI15_OUTPUT, "before" if _ui15_baseline else "after", physical.x, physical.y, roundi(ui_scale * 100)]
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(_ui15_output))
		var instance: Control = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
		_ui15_viewport.add_child(instance)
		await _ui15_settle()
		instance.call("_close_dialogue")
		await _ui15_camp(instance)
		if physical == VIEWPORT_SIZE:
			await _ui15_danger(instance)
			await _ui15_recap(instance)
		instance.queue_free()
		await _ui15_settle()
		_ui15_viewport.queue_free()
		await process_frame
	root.get_node("InputRouter").call("clear_forced_state_for_test")
	for failure: String in _failures: push_error(failure)
	print(ProjectSettings.globalize_path(UI15_OUTPUT))
	print("UI15 MENU/CAPTION TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _ui15_camp(instance: Control) -> void:
	var router: Node = root.get_node("InputRouter")
	var menu: Control = instance.get("_menu_dialog")
	var hud: Control = instance.get("grimoire_button")
	var first: Button = _ui15_button(menu, "Character")
	var activations := {"count": 0}
	var observe := func() -> void: activations["count"] += 1
	hud.pressed.connect(observe)
	for device: String in ["keyboard", "controller"]:
		router.call("set_forced_state_for_test", "controller" if device == "controller" else "pointer", "xbox")
		hud.grab_focus()
		instance.call("_open_menu_overlay")
		await _ui15_settle()
		if not _ui15_baseline:
			_require(_ui15_viewport.gui_get_focus_owner() == first, device + " Camp focuses Character at open (actual=%s first=%s scope=%s)" % [_ui15_viewport.gui_get_focus_owner(), first, instance.get("_menu_focus").get("_scope")])
		await _ui15_capture("camp_" + device + ".png")
		if not _ui15_baseline:
			for action: String in ["ui_down", "ui_up", "ui_left", "ui_right", "ui_focus_next", "ui_focus_prev"]:
				for step: int in range(UI15_NAVIGATION_STEPS):
					await _ui15_action(action)
					var focus: Control = _ui15_viewport.gui_get_focus_owner()
					_require(focus != null and menu.is_ancestor_of(focus), device + " Camp traps " + action)
			# A programmatic background grab is rejected before native confirmation.
			hud.grab_focus()
			_require(menu.is_ancestor_of(_ui15_viewport.gui_get_focus_owner()), "Stale HUD focus is rejected")
			_ui15_button(menu, "Settings").grab_focus()
			await _ui15_action("ui_accept")
			_require((instance.get("_settings_panel") as Control).visible, "Confirm opens focused Settings immediately")
			await _ui15_action("ui_cancel")
			_require(menu.visible, "Cancel returns from Settings to Camp")
		instance.call("_close_menu_overlay")
		await _ui15_settle()
		_require(_ui15_viewport.gui_get_focus_owner() == hud, "Camp restores previous HUD focus")
		_require(int(activations["count"]) == 0, "Camp never activates the background HUD")
	# Closing with no previous focus returns to no focus.
	if _ui15_viewport.gui_get_focus_owner() != null: _ui15_viewport.gui_get_focus_owner().release_focus()
	instance.call("_open_menu_overlay")
	instance.call("_close_menu_overlay")
	await _ui15_settle()
	_require(_ui15_viewport.gui_get_focus_owner() == null, "Camp preserves absent return focus")
	hud.pressed.disconnect(observe)

func _ui15_danger(instance: Control) -> void:
	root.get_node("InputRouter").call("set_forced_state_for_test", "controller", "xbox")
	instance.call("_open_menu_overlay")
	var danger: Button = _ui15_button(instance.get("_menu_dialog"), "Succumb to the Darkness")
	var first: Button = _ui15_button(instance.get("_menu_dialog"), "Character")
	first.grab_focus()
	await _ui15_capture("succumb_unfocused.png")
	danger.grab_focus()
	await _ui15_capture("succumb_focused.png")
	var focus: StyleBoxFlat = danger.get_theme_stylebox("focus")
	var normal: StyleBoxFlat = danger.get_theme_stylebox("normal")
	var skin := UiSkin.new()
	var standard: StyleBoxFlat = skin.make_button_style(UiSkin.VARIANT_STANDARD, UiSkin.STATE_FOCUS)
	_require(not focus.draw_center and focus.bg_color.a == 0, "Destructive focus leaves the red normal plate exposed")
	_require(focus.border_color == standard.border_color and focus.shadow_color == standard.shadow_color and focus.border_width_left == standard.border_width_left, "Destructive focus adds the standard ring")
	_require(normal.bg_color == skin.make_button_style(UiSkin.VARIANT_DESTRUCTIVE).bg_color, "Succumb retains its destructive style")
	danger.release_focus()
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	var motion := InputEventMouseMotion.new()
	motion.position = danger.get_global_rect().get_center()
	_ui15_viewport.push_input(motion, true)
	await _ui15_capture("succumb_hovered.png")
	_require(DisplayServer.get_name() == "headless" or danger.is_hovered(), "Hover proof uses native pointer hover")
	instance.call("_close_menu_overlay")

func _ui15_recap(instance: Control) -> void:
	var recap: Control = instance.get("_run_end_recap")
	var state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	state["run_stats"] = {"rooms_explored": 29, "enemies_slain": 61, "max_single_hit": 22}
	state.erase("run_result")
	var overlay = preload("res://scripts/run_end_recap_overlay.gd")
	recap.call("present", overlay.build_model(state, ProgressionStore.default_data(), "defeat", 214))
	recap.call("skip_presentation")
	await _ui15_capture("recap_feat_new_best.png")
	var best: Label = recap.find_child("NewBestTag", true, false)
	var diamond: Label = recap.find_child("FeatDiamond", true, false)
	var caption: int = preload("res://scripts/ui_typography.gd").role_size("caption")
	_require(best != null and best.is_visible_in_tree() and best.get_theme_font_size("font_size") == caption, "NEW BEST uses the caption floor")
	_require(diamond != null and diamond.is_visible_in_tree() and diamond.get_theme_font_size("font_size") == caption, "Feat diamond uses the caption floor")

func _ui15_button(scope: Node, text: String) -> Button:
	for child: Node in scope.get_children():
		if child is Button and child.text == text: return child
		var found: Button = _ui15_button(child, text)
		if found != null: return found
	return null

func _ui15_action(action: String) -> void:
	var event: InputEvent
	var controller: bool = bool(root.get_node("InputRouter").call("using_controller"))
	var buttons: Dictionary = {"ui_up": JOY_BUTTON_DPAD_UP, "ui_down": JOY_BUTTON_DPAD_DOWN, "ui_left": JOY_BUTTON_DPAD_LEFT, "ui_right": JOY_BUTTON_DPAD_RIGHT, "ui_accept": JOY_BUTTON_A, "ui_cancel": JOY_BUTTON_B}
	var keys: Dictionary = {"ui_up": KEY_UP, "ui_down": KEY_DOWN, "ui_left": KEY_LEFT, "ui_right": KEY_RIGHT, "ui_accept": KEY_ENTER, "ui_cancel": KEY_ESCAPE, "ui_focus_next": KEY_TAB, "ui_focus_prev": KEY_TAB}
	if controller and buttons.has(action):
		var joy := InputEventJoypadButton.new()
		joy.button_index = buttons[action]
		joy.pressed = true
		event = joy
	else:
		var key := InputEventKey.new()
		key.keycode = keys[action]
		key.physical_keycode = key.keycode
		key.shift_pressed = action == "ui_focus_prev"
		key.pressed = true
		event = key
	_ui15_viewport.push_input(event, true)
	await process_frame
	event = event.duplicate()
	event.pressed = false
	_ui15_viewport.push_input(event, true)
	await process_frame

func _ui15_settle() -> void:
	for frame: int in range(UI15_SETTLE_FRAMES): await process_frame

func _ui15_capture(filename: String) -> void:
	await _ui15_settle()
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var image: Image = _ui15_viewport.get_texture().get_image()
	_require(image != null and image.get_size() == _ui15_viewport.size, "Native SubViewport size matches proof")
	if image != null:
		_require(image.save_png(_ui15_output.path_join(filename)) == OK, "Saved " + filename)
