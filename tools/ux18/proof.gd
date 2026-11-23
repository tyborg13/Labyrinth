extends SceneTree

const CelLook = preload("res://scripts/cel_look.gd")
const Library = preload("res://scripts/grimoire_library.gd")
const Router = preload("res://scripts/input_router.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Resolution := Vector2i(1920, 1080)
const DeckResolution := Vector2i(1280, 800)
const ProfilePath := "user://ux18-profile.json"
const SettingsPath := "user://ux18-settings.json"
const SavePath := "user://ux18-run.save"
const FixtureSeed := 84217
const LoopEntry := "keyword:collision"
const LoopFrame := 12
const LoopTimeoutMs := 2500
const LayoutFrames := 4
const Query := "drawing from an empty"
const MissingQuery := "zzqqxxzz"
const SaveOnlyEntry := "keyword:discharge"
const ClearPointer := Vector2(24, 24)

var _viewport: SubViewport
var _router: Node
var _headless: bool
var _baseline: bool
var _output: String
var _backdrop: String
var _reference: String
var _failures: Array[String]
var _run_states: Dictionary = {}
var _title_open_us: Dictionary = {}
var _run_open_us: Dictionary = {}

func _initialize() -> void:
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	_baseline = OS.get_cmdline_user_args().has("--baseline")
	_output = _argument("--output-dir")
	_backdrop = _argument("--backdrop")
	_reference = _argument("--baseline-images")
	if _headless:
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		_expect(CelLook.mode == "all" and not CelLook._files.is_empty(), "approved cel look is on")
	Router.ensure_input_map()
	Store.set_storage_path(ProfilePath)
	Store.set_run_storage_path(SavePath)
	Settings.set_storage_path(SettingsPath)
	DirAccess.make_dir_recursive_absolute(_output)
	_run.call_deferred()

func _run() -> void:
	_router = root.get_node("InputRouter")
	if OS.get_cmdline_user_args().has("--demo-check"):
		_expect(preload("res://scripts/demo_build.gd").is_demo(), "demo build branch is active")
		var profile: Dictionary = _profile("fresh")
		_prepare_files(profile)
		await _title_case("fresh", profile, false)
		print("UX18 DEMO RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
		quit(0 if _failures.is_empty() else 1)
		return
	for fixture: String in ["fresh", "played"]:
		var profile: Dictionary = _profile(fixture)
		_prepare_files(profile)
		await _run_case(fixture, profile)
		if not _baseline:
			_prepare_files(profile)
			await _title_case(fixture, profile, false)
	if not _baseline:
		var deck_profile: Dictionary = _profile("played")
		_prepare_files(deck_profile)
		await _title_case("played", deck_profile, true)
	_router.call("clear_forced_state_for_test")
	var report := {
		"renderer": not _headless, "ok": _failures.is_empty(),
		"run_states": _run_states, "run_open_us": _run_open_us, "title_open_us": _title_open_us,
	}
	var file := FileAccess.open(_output.path_join("measurements.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t", true, true))
	file.close()
	print("UX18 OPEN USEC run=%s title=%s" % [JSON.stringify(_run_open_us), JSON.stringify(_title_open_us)])
	print("UX18 %s RESULT: %s" % ["HEADLESS" if _headless else "NATIVE", "PASS" if _failures.is_empty() else "FAIL"])
	quit(0 if _failures.is_empty() else 1)

func _profile(fixture: String) -> Dictionary:
	var profile: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(Store.default_data())
	if fixture == "played":
		var ids: Array[String]
		for entry: Dictionary in Library.entries():
			var id: String = str(entry["id"])
			if id != SaveOnlyEntry: ids.append(id)
		profile[Library.UNLOCKED_KEY] = ids
		var unread: Array[String] = [LoopEntry]
		profile[Library.UNREAD_KEY] = unread
		profile["run_counter"] = 42
	return profile

func _prepare_files(profile: Dictionary) -> void:
	var preferences: Dictionary = Settings.default_settings()
	preferences["ui_scale"] = 1.0
	preferences["reduced_motion"] = true
	_expect(Settings.save_settings(preferences), "settings fixture saved")
	Settings.apply_settings(preferences, root, false)
	_expect(Store.save_data(profile), "profile fixture saved")
	var checkpoint: Dictionary = RunEngine.new().create_new_run(FixtureSeed, profile)
	checkpoint = Library.unlock_entries(checkpoint, [SaveOnlyEntry])["state"]
	_expect(Store.save_run_state(checkpoint), "checkpoint fixture saved")

func _make_viewport(resolution: Vector2i) -> void:
	_viewport = SubViewport.new()
	_viewport.size = resolution
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.gui_embed_subwindows = true
	if resolution == DeckResolution:
		_viewport.size_2d_override = Vector2i(resolution * (float(Resolution.x) / resolution.x))
		_viewport.size_2d_override_stretch = true
	root.add_child(_viewport)
	_viewport.notify_mouse_entered()

func _run_case(fixture: String, profile: Dictionary) -> void:
	_router.call("set_forced_state_for_test", Router.MODALITY_POINTER, Router.FAMILY_XBOX)
	_make_viewport(Resolution)
	var run: Control = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(run)
	await _settle()
	run.call("_load_run_state", RunEngine.new().create_new_run(FixtureSeed, profile))
	run.call("_close_dialogue")
	await _settle()
	run.call("_close_large_map")
	await _point(ClearPointer)
	await _settle()
	var opener: Button = run.get("grimoire_button")
	var scrim: ColorRect = run.get("_grimoire_scrim")
	if fixture == "played" and not _headless: await _pin_run_backdrop(scrim)
	opener.grab_focus()
	var started := Time.get_ticks_usec()
	run.call("_open_grimoire_overlay")
	_run_open_us[fixture] = Time.get_ticks_usec() - started
	await _settle()
	_expect(scrim.visible, fixture + ": run Grimoire opens")
	if fixture == "played": await _book_cases(run, scrim, "run")
	run.call("_close_grimoire_overlay")
	await _settle()
	_viewport.queue_free()
	await process_frame

func _title_case(fixture: String, profile: Dictionary, deck: bool) -> void:
	var family: String = Router.FAMILY_STEAM_DECK if deck else Router.FAMILY_XBOX
	_router.call("set_forced_state_for_test", Router.MODALITY_POINTER, family)
	_make_viewport(DeckResolution if deck else Resolution)
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_viewport.add_child(menu)
	if _headless: await process_frame
	_expect(menu.get("_grimoire") == null, "title first frame has no Grimoire panel")
	await _settle()
	var warmed_panel: Control = menu.get("_grimoire")
	_expect(warmed_panel != null and not warmed_panel.visible, "title can reuse its hidden panel after presenting")
	var opener: Button = menu.get("grimoire_button")
	if opener == null:
		_expect(false, "title Grimoire button exists")
		_viewport.queue_free()
		return
	var order: Array[String]
	for child: Control in opener.get_parent().get_children():
		if child.visible: order.append(str(child.name))
	_expect(order == ["ContinueButton", "StartButton", "ChronicleButton", "GrimoireButton", "SettingsButton", "QuitButton"], "title action order")
	_expect(Rect2(Vector2.ZERO, _viewport.get_visible_rect().size).encloses(opener.get_global_rect()), "Grimoire fits the title viewport")
	var before: Dictionary = _storage_bytes()
	var music: AudioStreamPlayer = menu.get("_music_player")
	_expect(is_instance_valid(music) and music.playing, "title music is playing before open")
	var stream: AudioStream = music.stream if music != null else null
	var settings_button: Button = menu.get("settings_button")
	var quit_button: Button = menu.get("quit_button")
	_expect(Rect2(Vector2.ZERO, _viewport.get_visible_rect().size).encloses(quit_button.get_global_rect()), "Quit fits after Grimoire is added")
	await _point(opener.get_global_rect().get_center())
	_expect(opener.is_hovered(), "pointer reaches title Grimoire")
	if fixture == "played" and not deck: await _capture("title_pointer", Resolution)
	var started: int = Time.get_ticks_usec()
	menu.call("_on_grimoire_button_pressed")
	if not deck: _title_open_us[fixture] = Time.get_ticks_usec() - started
	await _settle()
	var scrim: ColorRect = menu.get("_grimoire")
	_expect(scrim != null and scrim.visible, "title Grimoire opens")
	if scrim == null:
		_viewport.queue_free()
		return
	if not deck:
		var expected: Dictionary = RunEngine.new().create_new_run(FixtureSeed, profile)
		var actual: Dictionary = scrim.get("_run_state")
		for key: String in [Library.UNLOCKED_KEY, Library.UNREAD_KEY]:
			_expect(actual.get(key) == expected.get(key), fixture + ": title has the new-run discovery and unread lists")
		_expect(not actual[Library.UNLOCKED_KEY].has(SaveOnlyEntry), fixture + ": continued-run-only entry stays hidden")
		print("UX18 CATALOG %s entries=%d unread=%d" % [fixture, actual[Library.UNLOCKED_KEY].size(), actual[Library.UNREAD_KEY].size()])
		_expect(_viewport.gui_get_focus_owner() == scrim.get("_grimoire_search_input"), "title opens with search focused")
		_expect(menu.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED and menu.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED, "title disables background focus and pointer input")
		_expect(not settings_button.has_focus(), "background Settings has no focus")
		await _key(KEY_TAB)
		_expect(scrim.is_ancestor_of(_viewport.gui_get_focus_owner()), "Tab stays inside the title Grimoire")
		if fixture == "played": await _book_cases(scrim, scrim, "title")
		await _key(KEY_ESCAPE)
		_expect(not scrim.visible and opener.has_focus(), "Escape closes title Grimoire and restores opener")
		await _click(opener.get_global_rect().get_center())
		_expect(scrim.visible, "pointer opens title Grimoire")
		await _click(ClearPointer)
		_expect(not scrim.visible and opener.has_focus(), "pointer dismissal restores title opener")
		await _click(opener.get_global_rect().get_center())
		await _click(settings_button.get_global_rect().get_center())
		_expect(not (menu.get("settings_panel") as Control).visible, "click on Settings position has no background effect")
		if scrim.visible: await _key(KEY_ESCAPE)
	else:
		await _key(KEY_ESCAPE)
	_router.call("set_forced_state_for_test", Router.MODALITY_CONTROLLER, family)
	await _point(ClearPointer)
	(menu.get("chronicle_button") as Button).grab_focus()
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_expect(opener.has_focus(), "controller goes from Chronicle to Grimoire")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	_expect(settings_button.has_focus(), "controller goes from Grimoire to Settings")
	await _joy(JOY_BUTTON_DPAD_UP)
	_expect(opener.has_focus(), "controller returns from Settings to Grimoire")
	var bar: Control = menu.get("_controller_prompt_bar")
	var prompt_z: int = bar.z_index
	_expect(bar.visible and not (bar.call("prompts_snapshot") as Array).is_empty(), "controller glyphs are visible")
	if deck:
		var deck_glyphs: int = 0
		for prompt: Node in (bar.get("_prompt_row") as HBoxContainer).get_children():
			if prompt is InputPrompt and prompt._glyph.family == Router.FAMILY_STEAM_DECK: deck_glyphs += 1
		_expect(deck_glyphs >= 2, "title renders native Deck glyphs for selection and navigation")
		await _capture("deck_title_controller", DeckResolution)
	elif fixture == "played":
		await _capture("title_controller", Resolution)
	await _joy(JOY_BUTTON_A)
	_expect(scrim.visible and _viewport.gui_get_focus_owner() == scrim.get("_grimoire_search_input"), "controller opens Grimoire with search focused")
	_expect(bar.z_index < scrim.z_index, "the title's controller prompts stay behind the Grimoire scrim")
	await _joy(JOY_BUTTON_DPAD_DOWN)
	var nav: Array[Button] = scrim.get("_grimoire_nav_buttons")
	_expect(not nav.is_empty() and nav[0].has_focus(), "controller Down goes from search to the first row")
	if deck: await _capture("deck_title_grimoire", DeckResolution)
	await _joy(JOY_BUTTON_B)
	_expect(not scrim.visible and opener.has_focus(), "B closes Grimoire and restores title opener")
	_expect(bar.z_index == prompt_z, "the title's controller prompts regain their layer")
	_expect(music != null and music.playing and music.stream == stream, "title music continues through Grimoire")
	_expect(not (menu.get("settings_panel") as Control).visible, "background Settings stayed closed")
	_expect(before == _storage_bytes(), fixture + ": profile, settings and checkpoint bytes are unchanged")
	if not deck: print("UX18 READ ONLY %s: profile, settings, checkpoint and backups byte-identical" % fixture)
	_viewport.queue_free()
	await process_frame

func _book_cases(host: Control, scrim: ColorRect, prefix: String) -> void:
	var field: LineEdit = host.get("_grimoire_search_input")
	host.call("_on_grimoire_section_pressed", "combat")
	await _point(ClearPointer)
	field.grab_focus()
	await _settle()
	await _book_case(scrim, prefix, "sections")
	host.call("_on_grimoire_entry_pressed", LoopEntry)
	await _settle()
	var entry: Button = _entry_button(host, LoopEntry)
	_expect(entry != null, prefix + ": loop entry is in the navigation list")
	if entry != null:
		var scroll: ScrollContainer = host.get("_grimoire_entry_scroll")
		scroll.ensure_control_visible(entry)
		await _settle()
		await _point(entry.get_global_rect().get_center())
		var player: Control = await _paused_loop(entry)
		if player != null:
			await _book_case(scrim, prefix, "entry_loop", player)
			if _headless: player.get_parent().get_parent().queue_free()
	await _point(ClearPointer)
	await _search(host, field, Query)
	_expect(not (host.get("_grimoire_search_results") as Array).is_empty(), prefix + ": results for the fixture query")
	await _book_case(scrim, prefix, "search_results")
	await _search(host, field, MissingQuery)
	_expect((host.get("_grimoire_search_results") as Array).is_empty(), prefix + ": empty search")
	if prefix == "run": await _book_case(scrim, prefix, "search_empty")
	await _search(host, field, Query)
	_router.call("set_forced_state_for_test", Router.MODALITY_CONTROLLER, Router.FAMILY_XBOX)
	await _joy(JOY_BUTTON_DPAD_DOWN)
	var results: Array[Button] = host.get("_grimoire_search_result_buttons")
	_expect(not results.is_empty() and results[0].has_focus(), prefix + ": controller focuses first entry from search")
	if prefix == "run": await _book_case(scrim, prefix, "controller_entry")
	_router.call("set_forced_state_for_test", Router.MODALITY_POINTER, Router.FAMILY_XBOX)

func _book_case(scrim: ColorRect, prefix: String, state: String, loop: Control = null) -> void:
	await _settle()
	if prefix == "run":
		var controls: Array[Dictionary]
		_collect_controls(scrim, controls)
		if loop != null: controls.append({"loop": loop.get("asset_path"), "frame": loop.get("displayed_frame")})
		_run_states[state] = controls
	await _capture(prefix + "_" + state, Resolution)

func _collect_controls(node: Node, controls: Array[Dictionary]) -> void:
	if node.has_meta("ux18_pinned_backdrop") or (node is Control and not node.is_visible_in_tree()): return
	if node is Control:
		var view: Control = node
		var row := {"class": view.get_class(), "rect": str(view.get_global_rect()), "focus": view.has_focus()}
		if view is Button or view is Label or view is LineEdit:
			row["text"] = view.get("text")
			row["font_size"] = view.get_theme_font_size("font_size")
		if view is Button:
			row["pressed"] = view.button_pressed
			row["id"] = str(view.get_meta("grimoire_nav_id", ""))
			row["draw_mode"] = view.get_draw_mode()
		if view is RichTextLabel: row["text"] = view.get_parsed_text()
		if view is ColorRect: row["color"] = str(view.color)
		if view is ScrollContainer: row["scroll"] = view.scroll_vertical
		controls.append(row)
	for child: Node in node.get_children(): _collect_controls(child, controls)

func _paused_loop(button: Button) -> Control:
	var player: Control
	if _headless:
		# The dummy display does not always create a native tooltip popup.
		# Exercise the same tooltip factory and decoded frame without a window.
		var tooltip: Control = button.call("_make_custom_tooltip", button.tooltip_text)
		_viewport.add_child(tooltip)
		player = tooltip.find_child("TooltipLoopWindow", true, false)
	else:
		var until: int = Time.get_ticks_msec() + LoopTimeoutMs
		while Time.get_ticks_msec() < until:
			player = _tooltip_loop(_viewport)
			if player != null: break
			await process_frame
	_expect(player != null, "registered Grimoire tooltip contains its loop")
	if player == null: return null
	player.set("reduced_motion", false)
	player.set("proof_seconds", (float(LoopFrame) + 0.5) / 30.0)
	var deadline := Time.get_ticks_msec() + LoopTimeoutMs
	while Time.get_ticks_msec() < deadline:
		if player.get("displayed_frame") == LoopFrame and float(player.get("_fade")) >= float(player.FADE_IN_SECONDS):
			player.set_process(false)
			return player
		await process_frame
	_expect(false, "approved loop decodes and pauses at frame %d" % LoopFrame)
	return null

func _tooltip_loop(node: Node) -> Control:
	if node is Control and node.name == &"TooltipLoopWindow" and node.is_visible_in_tree(): return node
	for child: Node in node.get_children(true):
		var found: Control = _tooltip_loop(child)
		if found != null: return found
	return null

func _entry_button(host: Control, id: String) -> Button:
	for button: Button in host.get("_grimoire_nav_buttons"):
		if button.get_meta("grimoire_nav_id", "") == id: return button
	return null

func _search(host: Control, field: LineEdit, query: String) -> void:
	field.grab_focus()
	field.text = query
	host.call("_on_grimoire_search_text_changed", query)
	await _settle()

func _pin_run_backdrop(scrim: ColorRect) -> void:
	var art: Image
	if _baseline:
		await RenderingServer.frame_post_draw
		art = _viewport.get_texture().get_image()
		_expect(art != null and art.save_png(_backdrop) == OK, "save the common rendered run backdrop")
	else:
		art = Image.load_from_file(_backdrop)
	_expect(art != null and art.get_size() == Resolution, "run backdrop matches the proof viewport")
	if art == null: return
	var backdrop := TextureRect.new()
	backdrop.texture = ImageTexture.create_from_image(art)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.z_index = -1
	backdrop.set_meta("ux18_pinned_backdrop", true)
	scrim.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _storage_bytes() -> Dictionary:
	var result: Dictionary = {}
	for base: String in [ProfilePath, SettingsPath, SavePath]:
		for suffix: String in ["", ".backup", ".tmp"]:
			var path: String = base + suffix
			result[path] = FileAccess.get_file_as_bytes(path) if FileAccess.file_exists(path) else null
	return result

func _point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	_viewport.push_input(motion, true)
	await process_frame

func _click(point: Vector2) -> void:
	await _point(point)
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.global_position = point
	await _press(event)

func _joy(button: JoyButton) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	await _press(event)

func _key(key: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	await _press(event)

func _press(event: InputEvent) -> void:
	event.pressed = true
	_viewport.push_input(event, true)
	await process_frame
	var release := event.duplicate() as InputEvent
	release.pressed = false
	_viewport.push_input(release, true)
	await _settle()

func _settle() -> void:
	for index: int in range(LayoutFrames): await process_frame

func _capture(label: String, resolution: Vector2i) -> void:
	var path: String = _output.path_join(label + ".png")
	if _headless:
		print("WOULD CAPTURE " + path)
		return
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == resolution and image.save_png(path) == OK, "capture " + label)
	if label.begins_with("run_") and not _reference.is_empty() and image != null:
		var before: Image = Image.load_from_file(_reference.path_join(label + ".png"))
		image.convert(Image.FORMAT_RGBA8)
		if before != null: before.convert(Image.FORMAT_RGBA8)
		var identical: bool = before != null and before.get_size() == image.get_size() and before.get_data() == image.get_data()
		_expect(identical, "%s has identical RGBA pixels before and after" % label)
		if identical: print("UX18 PIXELS IDENTICAL " + label)
	print(path)

func _argument(name: String) -> String:
	var args := OS.get_cmdline_user_args()
	var index := args.find(name)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""

func _expect(condition: bool, message: String) -> void:
	if condition: return
	_failures.append(message)
	printerr("UX18 FAIL: " + message)
