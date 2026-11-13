extends SceneTree

const CursorFeedbackScript = preload("res://scripts/cursor_feedback.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const DemoPanel = preload("res://scripts/demo_end_panel.gd")
const QuietLink = preload("res://scripts/ui_quiet_link.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")
const DemoSteamService = preload("res://scripts/steam_service.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Skills = preload("res://scripts/skill_tree_view.gd")
const SkillLibrary = preload("res://scripts/skill_tree_library.gd")
const MENU = preload("res://scenes/main_menu.tscn")
const SettingsPanelScript = preload("res://scripts/settings_panel.gd")
const PROFILE_PATH: String = "user://dmo03_test_profile.json"
const RUN_PATH: String = "user://dmo03_test_run.save"
const SETTINGS_PATH: String = "user://dmo03_test_settings.json"
const TEST_FEEDBACK_URL: String = "https://example.invalid/dmo-03-feedback"
const TEST_SEED: int = 90212
const ABSENT_EDITOR_FEATURE: String = "dmo03_test_no_editor_feature"

class FakeSteam:
	extends RefCounted
	var overlay_enabled: bool = true
	var calls: Array
	func isOverlayEnabled() -> bool:
		return overlay_enabled
	func activateGameOverlayToStore(app_id: int, flag: int) -> void:
		calls.append([app_id, flag])

class StoreServiceSpy:
	extends Node
	var calls: int = 0
	func open_store_page() -> void:
		calls += 1

var _failures: Array[String]
var _assertions: int = 0
var _opened: Array[String]
var _store_calls: int = 0
var _original_config: Dictionary

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	Progression.set_storage_path(PROFILE_PATH)
	Progression.set_run_storage_path(RUN_PATH)
	Settings.set_storage_path(SETTINGS_PATH)
	Settings.save_settings(Settings.default_settings())
	Progression.save_data(Progression.default_data())
	_original_config = DemoRules.config()
	DemoPanel.shell_open = func(url: String) -> void: _opened.append(url)
	DemoPanel.store_page_override_for_test = func() -> void: _store_calls += 1
	call_deferred("_run")

func _run() -> void:
	OS.set_environment("LABYRINTH_DEMO", "1")
	_check(DemoBuild.is_demo(), "The dmo-01 editor hook enables demo mode")
	_test_store_service()
	_test_link_override_guards()
	await _test_quiet_link()
	await _test_recap("full", 5, true)
	await _test_recap("full", 8, false)
	await _test_recap("links", 5, true)
	await _test_recap("links", 5, false)
	await _test_surfaces(true)
	await _test_model_rules()
	OS.set_environment("LABYRINTH_DEMO", "0")
	await _test_surfaces(false)
	await _test_full_recap()
	DemoRules._config = _original_config
	DemoPanel.shell_open = OS.shell_open
	DemoPanel.store_page_override_for_test = Callable()
	for failure: String in _failures:
		printerr("FAIL: " + failure)
	print("DEMO END PANEL TEST RESULT: %s (%d assertions)" % ["PASS" if _failures.is_empty() else "FAIL", _assertions])
	quit(0 if _failures.is_empty() else 1)

func _test_store_service() -> void:
	var service := DemoSteamService.new()
	var fake := FakeSteam.new()
	service._steam = fake
	service._initialized = true
	service._logged_on = true
	service._steam_id = "test-user"
	service.set_meta("store_shell_open_for_test", func(url: String) -> void: _opened.append(url))
	service.open_store_page()
	_check(fake.calls == [[int(_original_config["store_app_id"]), 0]], "Active Steam overlay uses the data app id and flag zero")
	_check(_opened.is_empty(), "Steam overlay does not open a browser")
	fake.overlay_enabled = false
	service.open_store_page()
	_check(_opened.pop_back() == _original_config["store_url"], "Disabled overlay uses the data store URL")
	service._initialized = false
	service.open_store_page()
	_check(_opened.pop_back() == _original_config["store_url"], "Inactive Steam uses the data store URL")
	service._steam = null
	service.open_store_page()
	_check(_opened.pop_back() == _original_config["store_url"], "Absent Steam uses the data store URL")
	service.free()

func _test_link_override_guards() -> void:
	_check(not OS.has_feature(ABSENT_EDITOR_FEATURE), "The substituted feature exercises a build without editor overrides")
	_check(DemoBuild.is_demo(), "The exported-path regression runs while demo mode is active")
	DemoRules._config = _original_config.duplicate(true)
	DemoRules._config["feedback_url"] = TEST_FEEDBACK_URL
	var original_service: Node = root.get_node("SteamService")
	original_service.name = "Dmo03OriginalSteamService"
	var store_spy := StoreServiceSpy.new()
	store_spy.name = "SteamService"
	root.add_child(store_spy)
	for editor: bool in [true, false]:
		var panel_script: GDScript = _script_with_editor_feature("res://scripts/demo_end_panel.gd", editor, true)
		var override_calls: Array[String]
		panel_script.set("shell_open", func(url: String) -> void: override_calls.append(url))
		panel_script.set("store_page_override_for_test", func() -> void: override_calls.append("store"))
		var before_store: int = store_spy.calls
		for action: String in ["wishlist", "discord", "feedback"]:
			panel_script.call("activate", action)
		var real_urls: Array[String] = panel_script.get("recorded_real_shell_urls")
		_check(override_calls.size() == (3 if editor else 0), "Link overrides are honoured only with the editor feature: %s" % editor)
		_check(store_spy.calls == before_store + (0 if editor else 1), "Without the editor feature Wishlist reaches the real SteamService path")
		_check(real_urls == ([] if editor else [_original_config["discord_url"], TEST_FEEDBACK_URL]), "Without the editor feature Discord and Feedback reach the real shell path")
		var invalid_overrides: Array[Callable]
		invalid_overrides.append(Callable())
		invalid_overrides.append(Callable(self, "nonexistent_demo_link_override"))
		for invalid: Callable in invalid_overrides:
			panel_script.set("shell_open", invalid)
			panel_script.set("store_page_override_for_test", invalid)
			real_urls.clear()
			before_store = store_spy.calls
			for action: String in ["wishlist", "discord", "feedback"]:
				panel_script.call("activate", action)
			_check(store_spy.calls == before_store + 1, "An empty or invalid Wishlist override falls back to SteamService")
			_check(real_urls == [_original_config["discord_url"], TEST_FEEDBACK_URL], "Empty or invalid shell overrides still open both data URLs")
		# Release callbacks owned by the anonymous test script.
		panel_script.set("shell_open", Callable())
		panel_script.set("store_page_override_for_test", Callable())
		var service_script: GDScript = _script_with_editor_feature("res://scripts/steam_service.gd", editor, false)
		var service: Node = service_script.new()
		override_calls.clear()
		service.set_meta("store_shell_open_for_test", func(url: String) -> void: override_calls.append(url))
		service.call("open_store_page")
		real_urls = service.get("recorded_real_shell_urls")
		_check(override_calls == ([_original_config["store_url"]] if editor else []), "SteamService's shell override requires the editor feature: %s" % editor)
		_check(real_urls == ([] if editor else [_original_config["store_url"]]), "Without the editor feature SteamService uses the real store URL shell path")
		for invalid: Callable in invalid_overrides:
			service.set_meta("store_shell_open_for_test", invalid)
			real_urls.clear()
			service.call("open_store_page")
			_check(real_urls == [_original_config["store_url"]], "Empty or invalid SteamService overrides fall back to the real shell")
		service.remove_meta("store_shell_open_for_test")
		real_urls.clear()
		service.call("open_store_page")
		_check(real_urls == [_original_config["store_url"]], "SteamService without an override uses the real shell")
		var fake := FakeSteam.new()
		service.set("_steam", fake)
		service.set("_initialized", true)
		service.set("_logged_on", true)
		service.set("_steam_id", "test-user")
		service.call("open_store_page")
		_check(fake.calls == [[int(_original_config["store_app_id"]), 0]], "Both feature paths retain the active Steam store overlay")
		service.free()
	root.remove_child(store_spy)
	store_spy.free()
	original_service.name = "SteamService"
	DemoRules._config = _original_config.duplicate(true)

func _script_with_editor_feature(path: String, editor: bool, static_shell: bool) -> GDScript:
	var source: String = FileAccess.get_file_as_string(path)
	var declaration: String = 'const TEST_OVERRIDE_FEATURE: String = "editor"'
	_check(source.count(declaration) == 1, "Each link dispatcher has one injectable editor feature constant")
	source = source.replace(declaration, 'const TEST_OVERRIDE_FEATURE: String = "%s"' % ("editor" if editor else ABSENT_EDITOR_FEATURE))
	# Intercept only the real OS boundary, outside the production overrides.
	# No browser or external program is opened while testing the shipped path.
	source = source.replace("OS.shell_open", "_record_real_shell_open")
	var qualifier: String = "static " if static_shell else ""
	source += "\n%svar recorded_real_shell_urls: Array[String]\n%sfunc _record_real_shell_open(url: String) -> Error:\n\trecorded_real_shell_urls.append(url)\n\treturn OK\n" % [qualifier, qualifier]
	var script := GDScript.new()
	script.source_code = source
	_check(script.reload() == OK, "The production dispatcher compiles with editor feature %s" % editor)
	return script

func _test_quiet_link() -> void:
	var link := QuietLink.new()
	link.text = "VIEW IN THE CHRONICLE ›"
	_add_logic_surface(link)
	link.size = link.get_combined_minimum_size()
	await process_frame
	link.mouse_entered.emit()
	_check(link.engaged(), "Standalone hover selects quiet links")
	link.mouse_exited.emit()
	_check(not link.engaged(), "Standalone pointer exit clears selection")
	link.grab_focus()
	_check(link.engaged(), "Standalone focus selects quiet links")
	link.mouse_entered.emit()
	link.release_focus()
	_check(link.engaged(), "Hover remains engaged when focus leaves")
	link.mouse_exited.emit()
	_check(not link.engaged(), "Focus and pointer exit clear selection")
	link.owner_manages_selection = true
	link.mouse_entered.emit()
	_check(not link.engaged(), "Owner-managed links do not change selection themselves")
	_check((link.get_theme_font("font") as FontVariation).spacing_glyph == 4 and link.get_theme_font_size("font_size") == 18, "Quiet links retain Chronicle typography")
	_check(link.get_theme_stylebox("normal").content_margin_top == 10 and link.get_theme_stylebox("normal").content_margin_bottom == 10, "Quiet links retain the hit padding")
	await _free(link)

func _test_recap(kind: String, row_count: int, feedback: bool) -> void:
	DemoRules._config = _original_config.duplicate(true)
	DemoRules._config["feedback_url"] = TEST_FEEDBACK_URL if feedback else ""
	var recap := Recap.new()
	recap.size = Vector2(1920, 1080)
	_add_logic_surface(recap)
	recap.present(_model(kind, row_count))
	recap.skip_presentation()
	await process_frame
	await process_frame
	var panel: DemoPanel = recap._demo_panel
	_check(panel != null and panel.kind == kind, "Recap builds the requested demo panel: " + kind)
	_check(panel.links.size() == (2 if kind == "full" else 3) - (0 if feedback else 1), "Empty feedback URL removes its link: " + kind)
	_check((recap._feat_rows.visible) == (kind == "full" and row_count > 5), "Clear ledgers split above five rows")
	_check(root.gui_get_focus_owner() == panel.primary_plate(), "The correct primary plate receives initial focus")
	_check(panel.wishlist_plate == null or panel.primary_plate() != panel.wishlist_plate, "Initial focus never lands on Wishlist (qa-87 F10)")
	_check(bool(panel.primary_plate().get_meta("umbra_selected")), "The primary plate is selected")
	await _test_link_pointer_selection(recap, panel)
	for index: int in range(panel.plates.size()):
		var plate: Button = panel.plates[index]
		_route(plate, "left", panel.plates[posmod(index - 1, panel.plates.size())])
		_route(plate, "right", panel.plates[(index + 1) % panel.plates.size()])
		_route(plate, "top", panel.links[0])
		plate.grab_focus()
		for link: Button in panel.links:
			_route(link, "bottom", plate)
	for index: int in range(panel.links.size()):
		var link: Button = panel.links[index]
		_route(link, "left", panel.links[posmod(index - 1, panel.links.size())])
		_route(link, "right", panel.links[(index + 1) % panel.links.size()])
		_route(link, "top", recap._chronicle_button)
		link.grab_focus()
		_check(bool(link.get_meta("umbra_selected")) and not bool(panel.primary_plate().get_meta("umbra_selected")), "Demo links share the recap selection")
		_activate_link(link)
	_route(recap._chronicle_button, "bottom", panel.links[0])
	if kind == "full":
		var plate: Button = panel.wishlist_plate
		_check(plate.global_position == Vector2(1010, 952), "Wishlist occupies the first approved exit slot")
		_check(is_equal_approx(plate.size.x, (780.0 - 32.0) / 3.0), "Wishlist keeps the authored plate width")
		var before: int = _store_calls
		plate.pressed.emit()
		_check(_store_calls == before + 1, "Wishlist plate calls open_store_page")
		var rule: Control = panel.get_node("DemoRule")
		var heading: Label = panel.get_node("DemoHeading")
		var body: Label = panel.get_node("DemoBody")
		_check(is_equal_approx(rule.position.y, recap._chronicle_button.position.y + recap._chronicle_button.size.y + 26), "Demo rule follows Chronicle by 26px")
		_check(heading.position.y == rule.position.y + 24 and body.position.y == rule.position.y + 66, "Demo copy matches approved vertical positions")
		_check(panel.links[0].position.y == body.position.y + body.size.y + 14, "Demo links follow the body by 14px")
		# Regression (director review): the body once kept its one-line width and ran off the screen.
		_check(is_equal_approx(body.size.x, 760.0) and body.autowrap_mode == TextServer.AUTOWRAP_WORD_SMART, "Demo body wraps inside its 760px measure")
		_check(body.get_line_count() == 2, "Demo body takes two lines at 1920x1080")
	else:
		_check(panel.primary_plate() == recap._new_run_button and panel.wishlist_plate == null, "Links-only recap preserves Rise Again")
		var line: Label = panel.get_node("DemoLinksLine")
		_check(is_equal_approx(line.position.y, recap._chronicle_button.position.y + recap._chronicle_button.size.y + 30), "Links-only copy follows Chronicle by 30px")
		_check(panel.links[0].position.y == line.position.y + 40, "Links-only row follows the copy by 40px")
	var new_runs: Array = []
	var main_menus: Array = []
	recap.new_run_pressed.connect(func() -> void: new_runs.append(true))
	recap.main_menu_pressed.connect(func() -> void: main_menus.append(true))
	recap._new_run_button.pressed.emit()
	recap._main_menu_button.pressed.emit()
	_check(new_runs.size() == 1 and main_menus.size() == 1, "Existing exit signals are preserved")
	recap._set_recap_shown(false)
	_check(not panel.is_visible_in_tree() and (panel.wishlist_plate == null or not panel.wishlist_plate.visible), "Chronicle hides demo copy and the external Wishlist plate")
	recap._set_recap_shown(true)
	await _free(recap)

func _test_link_pointer_selection(recap: Recap, panel: DemoPanel) -> void:
	var chronicle: QuietLink = recap._chronicle_button
	var discord: QuietLink = panel.get_node("DemoDiscordLink") as QuietLink
	for pair: Array in [[chronicle, discord], [discord, chronicle]]:
		var focused: QuietLink = pair[0]
		var hovered: QuietLink = pair[1]
		focused.grab_focus()
		await _move_pointer(hovered.get_global_rect().get_center())
		_check(hovered.is_hovered(), "Native pointer motion enters the link")
		_check(hovered.engaged() and not focused.engaged(), "%s: hovering %s takes selection from focused %s" % [panel.kind, hovered.name, focused.name])
		_check(focused.has_focus(), "Pointer hover preserves keyboard focus")
		await _move_pointer(Vector2.ZERO)
		_check(focused.engaged() and not hovered.engaged(), "%s: leaving %s restores selection to focused %s" % [panel.kind, hovered.name, focused.name])
		_check(focused.has_focus() and focused.get_theme_color("font_color") == QuietLink.Palette.GOLD_BRIGHT, "The focused link draws engaged after pointer exit")
		await _move_pointer(hovered.get_global_rect().get_center())
		focused.release_focus()
		focused.grab_focus()
		_check(hovered.engaged() and not focused.engaged(), "The hovered link keeps selection when keyboard focus is reacquired")
		await _move_pointer(Vector2.ZERO)

func _add_logic_surface(control: Control) -> void:
	# These focus/dispatch fixtures own feedback without playing audio. Native
	# pointer motion must not leave a focus tick playing when the test exits.
	control.set_meta(CursorFeedbackScript.CUE_FOCUS_META, true)
	root.add_child(control)

func _move_pointer(at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	motion.global_position = at
	root.push_input(motion, true)
	await process_frame

func _test_surfaces(demo: bool) -> void:
	var menu: Control = MENU.instantiate()
	_add_logic_surface(menu)
	await _settle()
	var links: Array[Button] = menu.get("_demo_links")
	_check(links.size() == (2 if demo else 0), "Main-menu links are demo-only")
	if demo:
		var quit_button: Button = menu.get("quit_button")
		_route(quit_button, "bottom", links[0])
		_route(links[0], "top", quit_button)
		_route(links[0], "bottom", links[1])
		_route(links[1], "top", links[0])
		_check(links[0].global_position == Vector2(menu.get_node("MenuColumn").global_position.x + 26, quit_button.get_global_rect().end.y + 12), "Menu links align with slab labels and Quit bottom")
		_check(links[1].position.y == links[0].position.y + 36, "Menu links use the approved 36px step")
		for link: Button in links: _activate_link(link)
		menu.get_node("ProfileBlock").hide()
		_check(not links[0].visible, "Hiding the profile hides menu links")
		menu.get_node("ProfileBlock").show()
		menu.call("_on_chronicle_button_pressed")
		_check(not links[0].visible, "Chronicle hides menu links")
		menu.get("_chronicle").call("close")
		menu.call("_open_new_descent")
		_check(not links[0].visible, "New descent hides menu links")
		menu.call("_close_new_descent")
	menu.call("_on_settings_button_pressed")
	await _settle()
	if demo: _check(not links[0].visible, "Settings hides menu links")
	await _test_settings(menu.get_node("SettingsPanel"), demo)
	menu.call("_on_settings_back_button_pressed")
	if demo: _check(links[0].visible, "Closing Settings restores menu links")
	await _free(menu)
	# The same panel class is installed by RunScene, independent of menu links.
	var panel := SettingsPanelScript.new()
	_add_logic_surface(panel)
	await _settle()
	await _test_settings(panel, demo)
	await _free(panel)
	var tree := Skills.new()
	tree.size = Vector2(1440, 650)
	_add_logic_surface(tree)
	tree.configure({"skill_ids": [], "unspent_points": 0})
	await _settle()
	var captions: int = 0
	for skill_id: String in SkillLibrary.visible_ids():
		var node: Button = tree.node_for_skill(skill_id)
		var tag: Label = node.get_node_or_null("DemoKeystoneCaption") as Label
		if demo and SkillLibrary.is_demo_locked(skill_id):
			captions += 1
			_check(tag != null and tag.text == str(_original_config["text"]["keystone_tag"]).to_upper(), "Locked keystones have their data caption")
			_check(tag.position == Vector2(-40, node.size.y + 6) and tag.focus_mode == Control.FOCUS_NONE, "Keystone captions are centred and nonfocusable")
			tree.focus_skill(skill_id)
			_check(tree._detail_reason.text == SkillLibrary.locked_reason(skill_id, []), "Keystones show dmo-02's locked reason")
			_check(tree._detail_action.text == "Unavailable", "Demo keystones keep Unavailable")
		else:
			_check(tag == null, "Other nodes and full builds have no teaser caption")
	_check(captions == (5 if demo else 0), "Only the five demo keystones have captions")
	await _free(tree)

func _test_settings(panel: Control, demo: bool) -> void:
	var links: Array[Button] = panel.get("_demo_links")
	_check(links.size() == (2 if demo else 0), "Settings links are demo-only")
	if not demo: return
	var audio: Control = panel.get("_controls")["master_volume"]["slider"]
	_route(audio, "top", links[0])
	for index: int in range(links.size()):
		_route(links[index], "left", links[1 - index])
		_route(links[index], "right", links[1 - index])
		_route(links[index], "bottom", audio)
		_activate_link(links[index])
	_check(is_equal_approx(links[1].get_global_rect().end.x, panel.get_global_rect().end.x - 30), "Settings links end 30px inside the panel")
	_check(is_equal_approx(links[0].get_global_rect().end.x + 32, links[1].global_position.x), "Settings links keep the 32px gap")
	_check(is_equal_approx(links[0].global_position.y, panel.global_position.y + 30), "Settings links use approved header height")

func _test_model_rules() -> void:
	var profile: Dictionary = Progression.default_data()
	var state: Dictionary = Run.new().create_new_run(TEST_SEED, profile)
	var at: Vector2i = state["current_room"]
	state["rooms"]["%d,%d" % [at.x, at.y]]["boss_id"] = "vyraketh"
	var model: Dictionary = Recap.build_model(state, profile, "victory", 236)
	_check(model["demo_end_panel_kind"] == "full" and model["title"] == "VICTORIOUS" and model["cause"] == "Vyraketh falls.", "Model uses demo_clear title and short dragon cause")
	_check(Recap.build_model(state, profile, "defeat", 0)["demo_end_panel_kind"] == "none", "Before the Hearth there is no prompt")
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		if str(room.get("type", "")) == "campfire" and int(room.get("section_index", 0)) == 0:
			room["visited"] = true
			break
	for outcome: String in ["defeat", "embrace"]:
		_check(Recap.build_model(state, profile, outcome, 0)["demo_end_panel_kind"] == "links", "First post-Hearth end shows links: " + outcome)
	profile[DemoRules.LINKS_PROMPT_RUN_KEY] = "different-run"
	_check(Recap.build_model(state, profile, "defeat", 0)["demo_end_panel_kind"] == "none", "A later run does not repeat the one-time prompt")

func _test_full_recap() -> void:
	var recap := Recap.new()
	_add_logic_surface(recap)
	recap.present(_model("full", 5))
	await process_frame
	_check(recap._demo_panel == null and recap.find_child("WishlistButton", true, false) == null, "Full builds create no demo recap nodes even with a stale demo model")
	_route(recap._new_run_button, "top", recap._chronicle_button)
	_route(recap._new_run_button, "right", recap._main_menu_button)
	_route(recap._chronicle_button, "bottom", recap._new_run_button)
	await _free(recap)

static func _model(kind: String, rows: int) -> Dictionary:
	var lines: Array = []
	var feats: Array = []
	for index: int in range(mini(rows, 4)):
		lines.append({"id": "test_line_%d" % index, "label": "Rooms explored", "detail": "9 × 5", "points": 45})
	for index: int in range(rows - lines.size()):
		feats.append({"id": "test_feat_%d" % index, "label": "Chain Reaction", "detail": "3 foes slain by one card", "points": 25})
	return {"outcome": "victory" if kind == "full" else "defeat", "title": "VICTORIOUS" if kind == "full" else "FALLEN", "cause": "Vyraketh falls.", "demo_end_panel_kind": kind, "score": {"lines": lines, "feats": feats, "total": 187}, "ember_amount": 236, "embers_text": "Embers carried 236."}

func _activate_link(link: Button) -> void:
	var before: int = _store_calls
	var action: String = "wishlist" if "Wishlist" in link.name else ("discord" if "Discord" in link.name else "feedback")
	link.pressed.emit()
	if action == "wishlist":
		_check(_store_calls == before + 1, "Wishlist link calls open_store_page")
	else:
		_check(_opened.pop_back() == DemoRules.config()[action + "_url"], "Link opens its data URL: " + action)

func _route(from: Control, direction: String, target: Control) -> void:
	var side: Side = {"left": SIDE_LEFT, "right": SIDE_RIGHT, "top": SIDE_TOP, "bottom": SIDE_BOTTOM}[direction]
	_check(from.find_valid_focus_neighbor(side) == target, "Native focus: %s %s reaches %s" % [from.name, direction, target.name])
	var path: NodePath = from.get("focus_neighbor_" + direction)
	_check(not path.is_empty() and from.get_node_or_null(path) == target, "%s %s reaches %s" % [from.name, direction, target.name])

func _check(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)

func _settle() -> void:
	for index: int in range(6): await process_frame

func _free(node: Node) -> void:
	node.queue_free()
	await process_frame
	await process_frame
