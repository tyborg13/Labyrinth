extends SceneTree

const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://grimoire_search_probe"

var _failures: Array[String] = []
var _capture_viewport: SubViewport

class KeyboardRouter extends "res://scripts/input_router.gd":
	# Mock singleton tests must not initialize the host's real Steam Input API.
	func _family_from_steam_input(_device_id: int) -> String:
		return FAMILY_STEAM_DECK

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	ProgressionStore.set_storage_path("user://labyrinth_progression_grimoire_search_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_grimoire_search_probe.save")
	ProgressionStore.clear_saved_run()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await process_frame
	await process_frame
	root.size = VIEWPORT_SIZE
	await _run_probe()
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("GRIMOIRE SEARCH PROBE RESULT: FAIL (%d failures)" % _failures.size())
		quit(1)
		return
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("GRIMOIRE SEARCH PROBE RESULT: PASS")
	quit(0)

func _run_probe() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Run scene should load for Grimoire search proof")
	if packed == null:
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "GrimoireSearchProofViewport"
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(84217, ProgressionStore.default_data())
	var all_entry_ids: Array[String] = []
	for entry_var: Variant in GrimoireLibrary.entries():
		if typeof(entry_var) == TYPE_DICTIONARY:
			all_entry_ids.append(str((entry_var as Dictionary).get("id", "")))
	state[GrimoireLibrary.UNLOCKED_KEY] = all_entry_ids.duplicate()
	state[GrimoireLibrary.UNREAD_KEY] = []
	var progression: Dictionary = (state.get("progression", {}) as Dictionary).duplicate(true)
	progression[GrimoireLibrary.UNLOCKED_KEY] = all_entry_ids.duplicate()
	progression[GrimoireLibrary.UNREAD_KEY] = []
	state["progression"] = progression
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()

	var opener: Button = instance.get_node("UiLayer/UiRoot/Backdrop/Margin/MainVBox/TopBar/GrimoireButton") as Button
	opener.grab_focus()
	instance.call("_open_grimoire_overlay")
	await _settle()
	var input: LineEdit = instance.get("_grimoire_search_input") as LineEdit
	var dialog: Control = instance.get("_grimoire_dialog") as Control
	_expect(input != null and input.is_visible_in_tree(), "Grimoire should expose a visible search field")
	_expect(dialog != null and _inside_viewport(dialog), "Grimoire dialog should remain inside the 1920x1080 viewport")
	_expect(_capture_viewport.gui_get_focus_owner() == input, "Opening the Grimoire should focus search for immediate typing")
	await _verify_steam_keyboard(instance, input)
	instance.call("_on_grimoire_entry_pressed", "combat:fatigue")
	await _settle()
	var browse_scroll: ScrollContainer = instance.get("_grimoire_entry_scroll") as ScrollContainer
	browse_scroll.scroll_vertical = 80
	await _settle()
	var browse_scroll_before_search: int = browse_scroll.scroll_vertical
	_expect(browse_scroll_before_search > 0, "Browse proof should begin from a meaningful saved scroll position")
	input.release_focus()
	await _capture("grimoire_search_v1_browse.png")
	input.grab_focus()
	await _settle()
	await _capture("grimoire_search_v1_focused.png")

	await _set_query(instance, input, "heath c")
	_expect(str(instance.get("_grimoire_selected_entry")) == "keyword:health_cost", "A one-character second token should keep Health Cost visible while typing through a small first-token typo")
	await _capture("grimoire_search_v2_incremental_token.png")

	await _set_query(instance, input, "reshuffle")
	_expect(str(instance.get("_grimoire_selected_entry")) == "combat:fatigue", "Rules-text search should select Fatigue for reshuffle")
	_expect(str((instance.get("_grimoire_detail_title") as Label).text) == "Fatigue", "Rules-text result should populate its detail page")
	await _capture("grimoire_search_v1_rules.png")
	var down_event := InputEventAction.new()
	down_event.action = "ui_down"
	down_event.pressed = true
	instance.call("_on_grimoire_search_gui_input", down_event)
	await _settle()
	var search_buttons: Array[Button] = instance.get("_grimoire_search_result_buttons") as Array[Button]
	_expect(not search_buttons.is_empty() and _capture_viewport.gui_get_focus_owner() == search_buttons[0], "Down from search should visibly focus the first result")
	await _capture("grimoire_search_v1_result_focus.png")
	await _activate_focused_control()
	var activated_search_result: Control = _capture_viewport.gui_get_focus_owner()
	_expect(activated_search_result != null and str(activated_search_result.get_meta("grimoire_nav_id", "")) == "combat:fatigue", "Accepting a search result should keep focus on its rebuilt row")
	input.grab_focus()
	await _settle()

	await _set_query(instance, input, "initiative")
	_expect(str(instance.get("_grimoire_selected_entry")) == "combat:turn_clock", "Familiar initiative alias should select Turn Clock")
	var alias_results: Array[Dictionary] = instance.get("_grimoire_search_results") as Array[Dictionary]
	_expect(not alias_results.is_empty() and str(alias_results[0].get("match_kind", "")) == "alias", "Alias search should visibly identify a common-term match")
	await _capture("grimoire_search_v1_alias.png")

	await _set_query(instance, input, "truesigth")
	_expect(str(instance.get("_grimoire_selected_entry")) == "keyword:truesight", "Small transposition typo should recover Truesight")
	var typo_status: Label = instance.get("_grimoire_search_status") as Label
	_expect(typo_status != null and typo_status.text.contains("close"), "Typo-only results should be labeled as close matches")
	await _capture("grimoire_search_v1_typo.png")

	await _set_query(instance, input, "purple banana")
	_expect(str(instance.get("_grimoire_selected_entry")).is_empty(), "No-result search should clear the result selection")
	_expect(str((instance.get("_grimoire_detail_title") as Label).text) == "No known match", "No-result search should explain the empty state")
	await _capture("grimoire_search_v1_no_results.png")

	await _set_query(instance, input, "")
	_expect(str(instance.get("_grimoire_selected_entry")) == "combat:fatigue", "Clearing search should restore the pre-search browse selection")
	_expect(absi(browse_scroll.scroll_vertical - browse_scroll_before_search) <= 1, "Clearing search should restore the pre-search browse scroll position")
	var browse_fatigue_button: Button = _find_nav_button(instance, "entry", "combat:fatigue")
	_expect(browse_fatigue_button != null, "Restored browsing should expose the previously selected entry row")
	if browse_fatigue_button != null:
		browse_fatigue_button.grab_focus()
		await _activate_focused_control()
		var activated_browse_result: Control = _capture_viewport.gui_get_focus_owner()
		_expect(activated_browse_result != null and str(activated_browse_result.get_meta("grimoire_nav_id", "")) == "combat:fatigue", "Accepting a browse entry should keep focus on its rebuilt row")
	await _capture("grimoire_search_v1_restored.png")

	instance.call("_close_grimoire_overlay")
	await _settle()
	_expect(_capture_viewport.gui_get_focus_owner() == opener, "Closing the Grimoire should restore focus to its opener")
	instance.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	await process_frame

func _set_query(instance: Node, input: LineEdit, query: String) -> void:
	input.set_block_signals(true)
	input.text = query
	input.caret_column = query.length()
	input.set_block_signals(false)
	instance.call("_on_grimoire_search_text_changed", query)
	await _settle()

func _verify_steam_keyboard(instance: Node, field: LineEdit) -> void:
	var service: Node = root.get_node("SteamService")
	var original_router: Node = root.get_node("InputRouter")
	var router_processing: bool = original_router.is_processing_input()
	var modality: String = str(original_router.call("modality"))
	original_router.set_process_input(false)
	original_router.name = "KeyboardProofOriginalRouter"
	var router := KeyboardRouter.new()
	router.name = "InputRouter"
	root.add_child(router)
	var properties: Array[String] = ["_steam", "_initialized", "_logged_on", "_steam_id", "_floating_keyboard_open"]
	var original: Dictionary = {}
	for property: String in properties: original[property] = service.get(property)
	var processing: bool = service.is_processing()
	var fake := preload("res://tests/suites/steam_service_suite.gd").FakeSteam.new()
	service.set_process(false)
	service.set("_steam", fake)
	service.set("_initialized", true)
	service.set("_logged_on", true)
	service.set("_steam_id", fake.steam_id)
	service.set("_floating_keyboard_open", false)
	router.call("set_forced_state_for_test", "pointer", "xbox")
	field.release_focus()
	field.grab_focus()
	_expect(fake.keyboard_calls.is_empty(), "Mouse/keyboard focus never opens Steam's floating keyboard")
	field.release_focus()
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	service.set("_initialized", false)
	field.grab_focus()
	_expect(fake.keyboard_calls.is_empty(), "Controller focus without initialized Steam is a no-op")
	field.release_focus()
	service.set("_initialized", true)
	fake.steam_running = false
	field.grab_focus()
	_expect(fake.keyboard_calls.is_empty(), "Controller focus with a stopped Steam client is a no-op")
	field.release_focus()
	fake.steam_running = true
	field.grab_focus()
	_expect(fake.keyboard_calls.size() == 1, "Controller focus opens the floating keyboard exactly once")
	if not fake.keyboard_calls.is_empty():
		var call: Dictionary = fake.keyboard_calls.back()
		var transform: Transform2D = field.get_viewport().get_final_transform() * field.get_global_transform_with_canvas()
		var rect: Rect2 = transform * Rect2(Vector2.ZERO, field.size)
		_expect(int(call["mode"]) == 0 and call["rect"] == Rect2i(rect.position.floor(), rect.end.ceil() - rect.position.floor()), "Floating keyboard uses single-line mode and the actual field in window pixels")
	var confirm := InputEventJoypadButton.new()
	confirm.button_index = JOY_BUTTON_A
	confirm.pressed = true
	_capture_viewport.push_input(confirm, true)
	_expect(fake.keyboard_calls.size() == 1, "Confirm while the floating keyboard is open does not reopen it")
	fake.floating_gamepad_text_input_dismissed.emit()
	_capture_viewport.push_input(confirm, true)
	_expect(fake.keyboard_calls.size() == 2, "Controller confirm reopens a dismissed keyboard on the focused field")
	# The floating API sends OS keys; exercise actual viewport input rather than
	# setting LineEdit.text or invoking its text_changed handler.
	for character: String in "reshuffle":
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = character.unicode_at(0)
		_capture_viewport.push_input(key, true)
	await _settle()
	_expect(field.text == "reshuffle" and str(instance.get("_grimoire_search_query")) == "reshuffle", "Floating keyboard keystrokes update the field and live search as typed text")
	for index: int in range(64):
		var key := InputEventKey.new()
		key.pressed = true
		key.unicode = "x".unicode_at(0)
		_capture_viewport.push_input(key, true)
	_expect(field.text.length() == 64 and field.max_length == 64, "Floating keyboard typing obeys the existing 64-character limit")
	field.release_focus()
	_expect(fake.keyboard_dismissals > 0, "Leaving the field dismisses its floating keyboard")
	for property: String in properties: service.set(property, original[property])
	service.set_process(processing)
	router.free()
	original_router.name = "InputRouter"
	original_router.set_process_input(router_processing)
	original_router.call("set_modality", modality)
	fake.free()
	await _set_query(instance, field, "")
	field.grab_focus()
	print("GRIMOIRE STEAM KEYBOARD: %s" % ("PASS" if _failures.is_empty() else "FAIL"))

func _activate_focused_control() -> void:
	var pressed := InputEventAction.new()
	pressed.action = "ui_accept"
	pressed.pressed = true
	_capture_viewport.push_input(pressed, true)
	await process_frame
	var released := InputEventAction.new()
	released.action = "ui_accept"
	released.pressed = false
	_capture_viewport.push_input(released, true)
	await _settle()

func _find_nav_button(instance: Node, kind: String, item_id: String) -> Button:
	var buttons: Array[Button] = instance.get("_grimoire_nav_buttons") as Array[Button]
	for button: Button in buttons:
		if str(button.get_meta("grimoire_nav_kind", "")) == kind and str(button.get_meta("grimoire_nav_id", "")) == item_id:
			return button
	return null

func _capture(file_name: String) -> void:
	await process_frame
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(true)
	var image: Image = _capture_viewport.get_texture().get_image()
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should render at 1920x1080" % file_name)
	var error: Error = image.save_png("%s/%s" % [OUTPUT_DIR, file_name])
	_expect(error == OK, "%s should save successfully" % file_name)

func _inside_viewport(control: Control) -> bool:
	if control == null:
		return false
	var rect: Rect2 = control.get_global_rect()
	return rect.position.x >= 0.0 and rect.position.y >= 0.0 and rect.end.x <= VIEWPORT_SIZE.x and rect.end.y <= VIEWPORT_SIZE.y

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.06).timeout
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
