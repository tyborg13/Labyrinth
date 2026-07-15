extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/pause_overlay_20260715_v1"
const INVALID_COORD := Vector2i(999, 999)

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
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
	var hand_box: Control = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/BottomStack/HandRow/HandScroll/HandCenter/HandBox") as Control
	_require(menu_scrim != null, "Pause scrim should exist")
	_require(menu_dialog != null, "Pause dialog should exist")
	_require(settings_panel != null, "In-run settings panel should exist")
	_require(turn_order != null and turn_order.visible, "Combat proof should show turn order")
	_require(choice_overlay != null and choice_overlay.visible, "Combat proof should show the Pass action")
	_require(pass_preview != null and pass_preview.visible, "Combat proof should show the On Turn End preview")
	_require(hand_box != null and hand_box.get_child_count() > 1, "Combat proof should show a multi-card hand")
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
