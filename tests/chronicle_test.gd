extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Suite = preload("res://tests/suites/chronicle_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Probe = preload("res://tests/chronicle_probe.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Icons = preload("res://scripts/room_icon_library.gd")
const SCROLL_RECORD_COUNT: int = 15
var failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	Analytics.set_storage_dir("user://chronicle_test_analytics")
	call_deferred("_run")

func _run() -> void:
	Suite.run(_check)
	var canvas: SubViewport = Probe.create_capture_viewport(root)
	_check(canvas.size == Vector2i(1920, 1080) and canvas.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Chronicle proof uses a fixed 1920x1080 render target updated every frame")
	var menu: Control = preload("res://scenes/main_menu.tscn").instantiate()
	canvas.add_child(menu)
	await process_frame
	var button: Button = menu.get_node("MenuColumn/ChronicleButton")
	_check(button.get_index() == menu.get_node("MenuColumn/StartButton").get_index() + 1 and button.get_index() + 1 == menu.get_node("MenuColumn/SettingsButton").get_index(), "Chronicle menu ordering")
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	await process_frame
	await Probe.click_button(button, canvas)
	await process_frame
	var panel: Control = menu.get_node("ChroniclePanel")
	_check(panel.visible and panel.get_node("ChronicleFrame").position == Vector2(60, 110) and panel.get_node("ChronicleFrame").size == Vector2(1800, 860), "Chronicle panel opens at approved geometry")
	_check(panel.get_node("ChronicleFrame/DescentList").size.x == 520, "Chronicle list has approved width")
	_check(button.position.y - menu.get_node("MenuColumn/StartButton").position.y == 92 and menu.get_node("MenuColumn/SettingsButton").position.y - button.position.y == 92, "Chronicle keeps 92 px menu spacing")
	_check(panel.find_child("DescentDetail", true, false).get_child(0).text == "Your first descent will be written here.", "Chronicle empty detail copy")
	panel.close()
	_check(button.has_focus() and not panel.visible, "Chronicle close restores menu focus")
	var opened: Array[Dictionary] = Analytics.load_all_events()
	_check(opened.size() == 1 and opened[0]["event_type"] == "chronicle_opened" and opened[0]["payload"]["records"] == 0, "Chronicle emits one additive local open event")
	# Validate both navigation steps through the added Chronicle slot.
	var start: Button = menu.get_node("MenuColumn/StartButton")
	start.grab_focus()
	var navigate := InputEventKey.new()
	navigate.keycode = KEY_DOWN
	navigate.pressed = true
	menu.get_viewport().push_input(navigate, true)
	await process_frame
	_check(button.has_focus(), "Keyboard navigation reaches Chronicle between New Game and Settings")
	menu.get_viewport().push_input(navigate, true)
	await process_frame
	_check(menu.get_node("MenuColumn/SettingsButton").has_focus(), "Keyboard navigation still reaches Settings after Chronicle")
	panel.open(Probe.seeded_profile(), false)
	await process_frame
	await process_frame
	_check(panel.records.size() == 7 and panel.find_child("ChronicleScore", true, false).text == "567", "Approved seven-record proof fixture selects the newest score")
	_check(panel.find_child("ChronicleScore", true, false).horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "Detail score aligns at the right end of the title row")
	var gear: Control = panel.find_child("Gear_training_sword", true, false)
	_check(gear != null, "Chronicle reuses approved production gear icons")
	if gear != null:
		gear.grab_focus()
		await process_frame
		await process_frame
		_check(panel.get("_focus_tooltip") != null and (panel.get("_focus_tooltip") as Node).find_children("*", "Button", true, false).size() > 0, "Focused gear uses production card previews in the existing tooltip")
	panel.select_record(1, true)
	await process_frame
	await process_frame
	var relic: Control = panel.find_child("Relic_iron_lung", true, false)
	if relic != null:
		relic.grab_focus()
		await process_frame
		await process_frame
		var detail_scroller: ScrollContainer = panel.get("_detail_scroll")
		_check(relic.get_global_rect().end.y <= detail_scroller.get_global_rect().end.y, "Icon focus keeps long victory builds visible in the detail scroller")
	var guardian_profile: Dictionary = Probe.seeded_profile()
	guardian_profile[Store.CHRONICLE_RECORDS_KEY][0]["path"][0][0] = "guardian"
	panel.open(guardian_profile, false)
	await process_frame
	var guardian: Dictionary = Guardians.for_boss("tharokh")
	var room_icon: Control = panel.find_child("PathSection0Room0", true, false)
	_check(room_icon.get("texture") == Icons.icon_texture("guardian_" + str(guardian["id"])) and str(room_icon.get("tooltip_title")).begins_with(str(guardian["name"])), "Chronicle reuses the section map's specific guardian emblem and tooltip name")
	var overflow_profile: Dictionary = Probe.seeded_profile()
	overflow_profile[Store.CHRONICLE_RECORDS_KEY][0]["deck"] = Probe.overflow_deck()
	panel.open(overflow_profile, false)
	await process_frame
	await process_frame
	var spells: Label = panel.find_child("ChronicleSpells", true, false)
	_check(spells.text.contains("more") and spells.get_line_count() <= 8, "The actual 30-spell windowed fixture overflows within eight physical lines")
	var profile: Dictionary = Store.default_data()
	for index: int in range(SCROLL_RECORD_COUNT):
		profile = Store.record_chronicle(profile, {"run_id": "ui-%d" % index, "outcome": "defeat", "section_name": "Rime Hall", "section_index": 2, "score_total": 567, "path": [["combat"]], "section_names": ["Worldspine Roots"]})
	panel.open(profile, false)
	await process_frame
	await process_frame
	_check(panel.get_node("ChronicleFrame/DescentList").size.x == 520, "Chronicle scrolling never grows the 520 px list")
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	panel._input(down)
	_check(panel.selected_index == 1, "Chronicle keyboard Down selects")
	var bumper := InputEventJoypadButton.new()
	bumper.button_index = JOY_BUTTON_RIGHT_SHOULDER
	bumper.pressed = true
	panel._input(bumper)
	_check(panel.selected_index == 11, "Chronicle RB pages by visible rows")
	var stick := InputEventJoypadMotion.new()
	stick.axis = JOY_AXIS_LEFT_Y
	stick.axis_value = -0.5
	panel._input(stick)
	_check(panel.selected_index == 10, "Chronicle left stick selects")
	panel._input(stick)
	_check(panel.selected_index == 10, "Chronicle held stick does not skip every motion sample")
	var dpad := InputEventJoypadButton.new()
	dpad.button_index = JOY_BUTTON_DPAD_UP
	dpad.pressed = true
	panel._input(dpad)
	_check(panel.selected_index == 9, "Chronicle controller D-pad selects")
	var back := InputEventJoypadButton.new()
	back.button_index = JOY_BUTTON_B
	back.pressed = true
	panel._input(back)
	_check(not panel.visible and button.has_focus(), "Chronicle controller B returns to menu")
	menu.queue_free()
	canvas.queue_free()
	await process_frame
	for failure: String in failures:
		push_error(failure)
	print("CHRONICLE TEST RESULT: %s" % ("PASS" if failures.is_empty() else "FAIL (%d failure(s))" % failures.size()))
	quit(0 if failures.is_empty() else 1)

func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
