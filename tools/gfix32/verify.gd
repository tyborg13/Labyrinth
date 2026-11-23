extends SceneTree

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Router = preload("res://scripts/input_router.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const Events = preload("res://tests/suites/event_view_suite.gd")
const InitialGraph = preload("res://scripts/initial_run_graph.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const FIXTURE_VOLUME: float = 0.35
const LAYOUT_FRAMES: int = 4
const EVENT_SETTLE_SECONDS: float = 0.65
const MAP_SEED: int = Events.FIXTURE_SEED
const EVENT_ID: String = "hanged_knight"
const DISCOVERY_COUNT: int = 2
const EXPECTED_NOTICE: String = "Added 2 entries to the Grimoire."
const OUTSIDE_CLICK := Vector2(24, 24)
const DEFAULT_OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/gfix-32/after"

var _viewport: SubViewport
var _router: Node
var _baseline: bool
var _headless: bool
var _output: String
var _failures: int


func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_baseline = args.has("--baseline")
	_headless = DisplayServer.get_name() == "headless"
	var output_index: int = args.find("--output-dir")
	_output = args[output_index + 1] if output_index >= 0 and output_index + 1 < args.size() else DEFAULT_OUTPUT_DIR
	_run.call_deferred()


func _run() -> void:
	Settings.set_storage_path("user://gfix32_settings.json")
	Store.set_storage_path("user://gfix32_progression.json")
	Store.set_run_storage_path("user://gfix32_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["master_volume"] = FIXTURE_VOLUME
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Store.save_data(Tutorial.complete_tutorial(Store.default_data()))
	Store.clear_saved_run()
	Router.ensure_input_map()
	_router = root.get_node("InputRouter")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = UI_SCALE
	if not _headless:
		_check(CelLook.mode == "all" and not CelLook._files.is_empty(), "Approved cel-look variants are available")
		_check(DirAccess.make_dir_recursive_absolute(_output) == OK, "Capture directory is writable")
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await _settings()
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	root.set_meta(InitialGraph.SEED_OVERRIDE, MAP_SEED)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	root.remove_meta(InitialGraph.SEED_OVERRIDE)
	await _settle()
	_check(bool(scene.call("initial_presentation_is_ready")), "Run is ready")
	await _map(scene)
	await _pause_settings(scene)
	await _event(scene)
	scene.queue_free()
	await _settle()
	_router.call("clear_forced_state_for_test")
	print("GFIX-32 %s %s: %d failures" % [
		"BASELINE" if _baseline else "AFTER", "HEADLESS" if _headless else "CAPTURE", _failures])
	quit(0 if _failures == 0 else 1)


func _settings() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_viewport.add_child(menu)
	await _settle()
	menu.call("_on_settings_button_pressed")
	await _settle()
	var panel: Control = menu.get("settings_panel")
	var actions: HBoxContainer = panel.get("_footer_actions")
	var restore: Button = actions.get_child(1)
	var cancel: Button = panel.get("_confirmation_cancel")
	var confirm_panel: Control = panel.get("_confirmation_panel")
	var reset: Button = cancel.get_parent().get_child(2)
	var scroll: ScrollContainer = panel.find_children("*", "ScrollContainer", true, false)[0]
	_check(panel.visible and root.content_scale_factor == UI_SCALE, "Settings opens at 100%")
	restore.grab_focus()
	await _settle()
	var reduced: Button = (panel.get("_controls") as Dictionary)["reduced_motion"]
	var reduced_row: Control = reduced.get_parent().get_parent().get_parent()
	scroll.ensure_control_visible(reduced_row)
	await _settle()
	_check(scroll.get_global_rect().encloses(reduced_row.get_global_rect()), "Reduced motion is fully visible before opening")
	var before: Dictionary = _settings_geometry(scroll)
	var restore_rect: Rect2 = restore.get_global_rect()
	await _capture("01_settings_closed")
	await _joy(JOY_BUTTON_A)
	var opened: Dictionary = _settings_geometry(scroll)
	print("Settings closed: ", before)
	print("Settings open:   ", opened)
	print("Settings footer: restore_before=%s restore_open=%s reset=%s confirmation=%s cancel_focus=%s" % [
		restore_rect, _paint(restore), _paint(reset), confirm_panel.get_global_rect(), _viewport.gui_get_focus_owner() == cancel])
	_check(confirm_panel.visible, "Controller opens restore confirmation")
	_observe(before == opened, "settings_open_preserves_row_and_scroll_geometry")
	_observe(not _drawn(restore) and _drawn(reset), "settings_has_one_visible_destructive_action")
	_observe(_viewport.gui_get_focus_owner() == cancel, "settings_focus_enters_cancel")
	await _capture("02_settings_confirm")
	await _joy(JOY_BUTTON_A)
	_check_dismissal("cancel_button", panel, restore, restore_rect, true)
	_check(_settings_geometry(scroll) == before, "Cancel restores original scroll and row geometry")

	restore.grab_focus()
	await _joy(JOY_BUTTON_A)
	await _joy(JOY_BUTTON_B)
	_check_dismissal("controller_b", panel, restore, restore_rect, true)

	restore.grab_focus()
	await _joy(JOY_BUTTON_A)
	await _key(KEY_ESCAPE)
	_check_dismissal("escape", panel, restore, restore_rect, true)

	if not panel.visible: menu.call("_on_settings_button_pressed")
	restore.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(not panel.call("contains_pointer_position", OUTSIDE_CLICK), "Outside click target is outside Settings")
	await _click(OUTSIDE_CLICK)
	_check_dismissal("outside_click", panel, restore, restore_rect, true)
	if confirm_panel.visible:
		await _joy(JOY_BUTTON_B)
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	await _click(restore_rect.get_center())
	_check(confirm_panel.visible, "Pointer opens restore confirmation")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _joy(JOY_BUTTON_B)
	_check_dismissal("pointer_to_controller", panel, restore, restore_rect, true)
	_check(is_equal_approx(float(Settings.load_settings()["master_volume"]), FIXTURE_VOLUME), "Dismissing does not reset the fixture preference")
	menu.queue_free()
	await _settle()


func _settings_geometry(scroll: ScrollContainer) -> Dictionary:
	var bar: VScrollBar = scroll.get_v_scroll_bar()
	var visible_area: Rect2 = scroll.get_global_rect()
	var rows: Dictionary = {}
	var sections: VBoxContainer = scroll.get_child(0)
	for section: PanelContainer in sections.get_children():
		for row: Control in (section.get_meta("rows") as VBoxContainer).get_children():
			var label: String = str(row.name)
			if row is Button:
				label = (row as Button).text
			else:
				var first: Control = row.get_child(0).get_child(0).get_child(0)
				if first is VBoxContainer: first = first.get_child(0)
				if first is Label: label = (first as Label).text
			var rect: Rect2 = row.get_global_rect()
			rows[label] = [rect.position.x, rect.position.y, rect.size.x, rect.size.y, rect.intersection(visible_area).size.y]
	return {"scroll_rect": visible_area, "bar_visible": bar.is_visible_in_tree(),
		"bar_rect": bar.get_global_rect(), "scroll_y": scroll.scroll_vertical, "rows": rows}


func _check_dismissal(path: String, panel: Control, restore: Button, before: Rect2, expect_focus: bool) -> void:
	var confirmation: Control = panel.get("_confirmation_panel")
	var closed: bool = panel.visible and not confirmation.visible and _drawn(restore) and restore.get_global_rect() == before
	var focused: bool = _viewport.gui_get_focus_owner() == restore
	print("Settings %s: settings_visible=%s confirmation_visible=%s restore_rect=%s restore_focused=%s" % [
		path, panel.visible, confirmation.visible, restore.get_global_rect(), focused])
	_observe(closed and (not expect_focus or focused), "settings_dismiss_" + path)


func _map(scene: Node) -> void:
	scene.call("_close_dialogue")
	# Consume the automatic map presentation before measuring manual reopen.
	scene.call("_maybe_present_section_map", false)
	scene.call("_close_large_map")
	await _settle()
	var title: Label = scene.get("room_title")
	var subtitle: Label = scene.get("room_subtitle")
	var scrim: ColorRect = scene.get("_large_map_scrim")
	var before: Dictionary = _paint(title)
	var subtitle_rect: Rect2 = subtitle.get_global_rect()
	_check(_drawn(title) and not title.text.is_empty(), "Map fixture has a visible room title")
	await _capture("03_room_closed")
	scene.call("_open_large_map")
	await _settle()
	var open: Dictionary = _paint(title)
	var backdrop_alpha: float = scrim.color.a * _alpha(scrim)
	var covered: bool = _drawn(scrim) and backdrop_alpha == 1.0 and scrim.get_global_rect().encloses(title.get_global_rect()) and _above(scrim, title)
	print("Map closed: title=%s subtitle_rect=%s" % [before, subtitle_rect])
	print("Map open: title=%s scrim=%s backdrop_alpha=%.3f title_covered=%s" % [
		open, _paint(scrim), backdrop_alpha, covered])
	_check(scrim.visible, "Run opens the large map")
	_check(not _drawn(title) or covered, "Open map leaves no room-title paint exposed")
	_check(subtitle.get_global_rect() == subtitle_rect, "Map leaves the room subtitle geometry unchanged")
	await _capture("04_map_open")
	scene.call("_close_large_map")
	await _settle()
	_check(not scrim.visible and _paint(title) == before, "Closing the map restores the same title paint")


func _pause_settings(scene: Node) -> void:
	_router.call("set_forced_state_for_test", "controller", "xbox")
	scene.call("_open_menu_overlay")
	scene.call("_open_settings_overlay")
	await _settle()
	var panel: Control = scene.get("_settings_panel")
	var actions: HBoxContainer = panel.get("_footer_actions")
	var restore: Button = actions.get_child(1)
	var confirmation: Control = panel.get("_confirmation_panel")
	restore.grab_focus()
	await _joy(JOY_BUTTON_A)
	_check(confirmation.visible, "Controller opens restore confirmation in the pause menu")
	var restore_rect: Rect2 = restore.get_global_rect()
	await _key(KEY_ESCAPE)
	_check_dismissal("pause_escape", panel, restore, restore_rect, true)
	scene.call("_close_menu_overlay")
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	await _settle()


func _event(scene: Node) -> void:
	var state: Dictionary = Events.fixture(EVENT_ID)
	var known: Array[String] = Library.entry_ids_for_run_state(state)
	state[Library.UNLOCKED_KEY] = known
	state = Library.ensure_run_state(state)
	known = state[Library.UNLOCKED_KEY]
	var discover: Array[String]
	for entry: Dictionary in Library.entries():
		var id: String = str(entry.get("id", ""))
		if id.is_empty() or known.has(id): continue
		discover.append(id)
		if discover.size() == DISCOVERY_COUNT: break
	state = Library.unlock_entries(state, discover)["state"]
	_check(state.get(Library.NOTICE_KEY, "") == EXPECTED_NOTICE, "Event fixture generates the two-entry notice through GrimoireLibrary")
	scene.call("_load_run_state", state)
	await create_timer(EVENT_SETTLE_SECONDS).timeout
	await _settle()
	var view: Control = scene.get("_event_view")
	var panel: Control = view.get("panel")
	var log: Control = scene.get("log_overlay")
	var label: RichTextLabel = scene.get("log_label")
	var queued: Node = scene.get_node("DeferredRunNotifications")
	_check(_drawn(panel) and EXPECTED_NOTICE in label.text, "The event and exact notice request coexist")
	print("Event open: panel=%s notice=%s notice_above_panel=%s held=%d text=%s" % [
		_paint(panel), _paint(log), _above(log, panel), (queued.get("queued") as Array).size(), JSON.stringify(label.text)])
	_check(not _drawn(log) or _above(log, panel), "No notice paint under the event")
	await _capture("05_event_open")


func _paint(item: Control) -> Dictionary:
	return {"rect": item.get_global_rect(), "visible": item.is_visible_in_tree(),
		"alpha": _alpha(item), "canvas": _layer(item), "z": _z(item)}


func _drawn(item: Control) -> bool:
	return item.is_visible_in_tree() and _alpha(item) > 0.0


func _alpha(item: CanvasItem) -> float:
	var opacity: float = item.self_modulate.a
	while item != null:
		opacity *= item.modulate.a
		item = item.get_parent() as CanvasItem
	return opacity


func _layer(item: CanvasItem) -> int:
	var layer: CanvasLayer = item.get_canvas_layer_node()
	return layer.layer if layer != null else 0


func _z(item: CanvasItem) -> int:
	var z: int = 0
	while item != null:
		z += item.z_index
		if not item.z_as_relative: break
		item = item.get_parent() as CanvasItem
	return z


func _above(first: CanvasItem, second: CanvasItem) -> bool:
	return _layer(first) > _layer(second) or (_layer(first) == _layer(second) and _z(first) > _z(second))


func _capture(name: String) -> void:
	var path: String = _output.path_join(name + ".png")
	if _headless:
		print("Capture planned: ", path)
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_check(image != null and image.get_size() == PROOF_SIZE, "Exact-size capture: " + path)
	if image != null and image.get_size() == PROOF_SIZE:
		_check(image.save_png(path) == OK, "Capture saved: " + path)
		print(path)


func _settle() -> void:
	for frame: int in range(LAYOUT_FRAMES):
		await process_frame


func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)
	await _settle()


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.physical_keycode = key
		event.pressed = pressed
		_viewport.push_input(event, true)
	await _settle()


func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.position = point
		event.global_position = point
		event.pressed = pressed
		_viewport.push_input(event, true)
	await _settle()


func _observe(condition: bool, name: String) -> void:
	print("GFIX-32 [%s] %s: %s" % ["baseline" if _baseline else "after", name, "PASS" if condition else "FAIL"])
	if not _baseline:
		_check(condition, name)


func _check(condition: bool, name: String) -> void:
	if condition: return
	print("GFIX-32 CHECK FAILED: ", name)
	_failures += 1
