extends SceneTree
## Focused QA-117 replays, using its census route driver, input gate and fixtures.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixtures = preload("res://tools/hitch_census/fixtures.gd")
const Route = preload("res://tools/hitch_census/demo/route.gd")
const Gate = preload("res://tools/hitch_census/demo/gate.gd")
const InputGate = preload("res://tools/hitch_census/demo/input_gate.gd")
const Geometry = preload("res://tools/qa107/layout_geometry.gd")
const Router = preload("res://scripts/input_router.gd")
const MenuScene = preload("res://scenes/main_menu.tscn")
const TitleSweep = preload("res://tools/ui38/card_title_sweep.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const RewardCaption = preload("res://scripts/reward_action_caption.gd")
const Combat = preload("res://scripts/combat_engine.gd")

const DESKTOP_SIZE := Vector2i(1920, 1080)
const DECK_SIZE := Vector2i(1280, 800)
const FIXTURE_SEED: int = 83
const UNLOCKED_DEPTH: int = 3
const INJURED_HEALTH: int = 23
const MAX_HEALTH: int = 24
const CENTER_ROUNDING_PIXELS: float = 1.0
const WIDTH_CAP_EXERCISE_PIXELS: float = 1.0
const TITLE_HAND: String = "whirlwind_slash,hamstring_shot,whirlwind_slash,hamstring_shot"
const TITLE_PROOF_HAND: String = "whirlwind_slash,rite_of_the_mountain,hamstring_shot,hamstring_shot"
const TITLE_PROOF_NAMES := ["Whirlwind Slash", "Low Sweep", "Rite of the Mountain"]
const TITLE_SIX_CARD_HAND: String = "whirlwind_slash,hamstring_shot,backhand_nick,ball_lightning,blessed_salve,hamstring_shot"
const SETTLE_SECONDS: float = 0.65
const TIMEOUT_MSEC: int = 16000
const CASES := ["d01-save", "d01-recap", "d02", "d03", "d04", "d05", "d06"]

var _driver
var _gate: Node
var _case: String
var _out: String
var _proof_size: Vector2i
var _title_sweep: bool
var _report: FileAccess
var _failures: Array[String]
var _case_failures: Array[String]

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	_case = OS.get_environment("UI38_CASE")
	_title_sweep = OS.get_environment("UI38_TITLE_SWEEP") == "1"
	if _title_sweep: _case = "d03"
	_out = OS.get_environment("UI38_OUTPUT")
	if _out.is_empty(): _out = ProjectSettings.globalize_path("user://ui38")
	if Runtime.current_namespace().is_empty() or DirAccess.make_dir_recursive_absolute(_out) != OK:
		quit(2)
		return
	_report = FileAccess.open(_out.path_join("witness.jsonl"), FileAccess.WRITE)
	if _report == null or (not _case.is_empty() and _case not in CASES):
		quit(2)
		return
	var deck: bool = OS.get_environment("SteamDeck") == "1"
	_proof_size = DECK_SIZE if deck else DESKTOP_SIZE
	var scale: float = 1.15 if deck else 1.0
	if OS.has_environment("UI38_SCALE"): scale = float(OS.get_environment("UI38_SCALE")) / 100.0
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = scale
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.set_storage_path("user://ui38-settings.json")
	Store.set_storage_path("user://ui38-profile.json")
	Store.set_run_storage_path("user://ui38-run.save")
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.gui_embed_subwindows = true
	root.size = _proof_size
	root.content_scale_factor = scale
	Engine.max_fps = 60
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_driver = Route.new(self)
	_gate = InputGate.new()
	_gate.session = self
	root.add_child(_gate)
	log_event("configuration", {"size": str(root.size), "logical_size": str(root.get_visible_rect().size), "scale": scale})
	for label: String in CASES:
		if not _case.is_empty() and _case != label: continue
		_case_failures.clear()
		await _run_case(label)
		if _case_failures.is_empty() and DisplayServer.get_name() != "headless":
			await _capture(label)
		if label == "d05" and is_instance_valid(current_scene.get("_grimoire_scrim")) and current_scene.get("_grimoire_scrim").visible:
			await _press(JOY_BUTTON_B)
		var result: String = "PASS" if _case_failures.is_empty() else "FAIL " + "; ".join(_case_failures)
		print("UI38 %s: %s" % [label, result])
		log_event("case", {"id": label, "result": result})
		_failures.append_array(_case_failures)
	var expected: int = _driver.inputs["joypad_button"] + _driver.inputs["joypad_motion"]
	if expected == 0 or expected != _gate.accepted: _failures.append("Input gate count mismatch")
	print("UI38 RESULT: joypad=%d/%d failures=%d" % [_gate.accepted, expected, _failures.size()])
	_report.close()
	quit(0 if _failures.is_empty() else 1)

func _run_case(label: String) -> void:
	Store.clear_saved_run()
	var profile: Dictionary = Store.default_data()
	if label == "d02": profile[Store.UMBRA_DEPTH_UNLOCKED_KEY] = UNLOCKED_DEPTH
	Store.save_data(profile)
	await _enter(MenuScene.resource_path)
	if not _controller_active(): await _driver.pad.pulse(Vector2.DOWN)
	match label:
		"d01-save": await _return_to_title(false)
		"d01-recap": await _return_to_title(true)
		"d02": await _depth_prompts()
		"d03": await _card_titles()
		"d04": await _reward_caption()
		"d05": await _grimoire_search()
		"d06": await _map_legend()

func _enter(path: String) -> void:
	change_scene_to_file(path)
	await scene_changed
	_driver.scene = current_scene
	await _settle()

func _install(kind: String, options: Dictionary = {}) -> bool:
	var fixtures := Fixtures.new()
	var state: Dictionary = fixtures.make(kind, FIXTURE_SEED, options)
	var message: String = fixtures.census_error
	fixtures.free()
	if state.is_empty():
		fail("Fixture %s failed: %s" % [kind, message])
		return false
	await _enter("res://scenes/run_scene.tscn")
	current_scene.set("_progression", state["progression"])
	current_scene.call("_load_run_state", state)
	current_scene.call("_close_dialogue")
	await _settle()
	return true

func _return_to_title(recap: bool) -> void:
	if not await _install("defeat" if recap else "start"): return
	var button: int = JOY_BUTTON_B
	if recap:
		var overlay: Control = current_scene.get("_run_end_recap")
		await hold(float(overlay.call("presentation_duration")))
	else:
		if not await _close_start_map() or not await _press(JOY_BUTTON_START): return
		var menu: Control = current_scene.get("_menu_scrim")
		var save: Control = _driver.match_text(_driver.controls(menu), ["save and quit"])
		if not await _driver.control(save): return
		button = JOY_BUTTON_A
	var witness: Dictionary
	var record_first_frame := func() -> void:
		var focus: Control = root.gui_get_focus_owner()
		witness["focus"] = String(focus.name) if focus != null else ""
		witness["highlight"] = focus != null and bool(focus.get_meta("umbra_selected", false))
	scene_changed.connect(record_first_frame, CONNECT_ONE_SHOT)
	if not await _driver.pad.button(button):
		scene_changed.disconnect(record_first_frame)
		fail("Title departure input was dropped")
		return
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while witness.is_empty() and Time.get_ticks_msec() < deadline: await process_frame
	if scene_changed.is_connected(record_first_frame): scene_changed.disconnect(record_first_frame)
	var expected: String = "StartButton" if recap else "ContinueButton"
	log_event("first_title_frame", witness)
	_check(witness.get("focus", "") == expected and witness.get("highlight", false),
		"first title frame expected highlighted %s, observed %s" % [expected, witness])
	await _settle()
	_check(current_scene.scene_file_path == MenuScene.resource_path, "Title did not return")
	var settled_focus: Control = root.gui_get_focus_owner()
	_check(settled_focus != null and String(settled_focus.name) == expected, "Title did not retain initial focus")

func _depth_prompts() -> void:
	if not await _activate(current_scene.get("start_button")): return
	var bar: Control = current_scene.find_child("ControllerPromptBar", true, false)
	_check_prompts(bar, [Router.ACTION_ACCEPT, Router.ACTION_HAND_NEXT, Router.ACTION_CANCEL])
	if not await _press(JOY_BUTTON_RIGHT_SHOULDER): return
	var descent: Control = current_scene.get("_new_descent_panel")
	_check(descent.get("selected_depth") == 1, "R1 did not advance depth")
	_check_prompts(bar, [Router.ACTION_ACCEPT, Router.ACTION_HAND_BUMPERS, Router.ACTION_CANCEL])
	if not await _press(JOY_BUTTON_LEFT_SHOULDER): return
	_check(descent.get("selected_depth") == 0, "L1 did not restore depth")
	for depth: int in range(UNLOCKED_DEPTH):
		if not await _press(JOY_BUTTON_RIGHT_SHOULDER): return
	_check_prompts(bar, [Router.ACTION_ACCEPT, Router.ACTION_HAND_PREVIOUS, Router.ACTION_CANCEL])
	if not await _press(JOY_BUTTON_B): return
	_check(not is_instance_valid(current_scene.get("_new_descent_panel")), "B did not close depth picker")
	# Capture the interior depth with both shoulders available.
	if await _activate(current_scene.get("start_button")):
		await _press(JOY_BUTTON_LEFT_SHOULDER)

func _check_prompts(bar: Control, actions: Array) -> void:
	var prompts: Array = bar.call("prompts_snapshot")
	log_event("depth_prompts", {"prompts": prompts})
	var labels := ["Select", "Umbra Depth", "Back"]
	var expected: Array[Dictionary]
	for index: int in range(actions.size()):
		expected.append({"action": str(actions[index]), "label": labels[index]})
	_check(bar.is_visible_in_tree() and prompts == expected, "expected %s, observed %s" % [expected, prompts])

func _card_titles() -> void:
	if _title_sweep:
		await _sweep_titles()
		return
	if not await _install("combat", {"hand": TITLE_PROOF_HAND}): return
	if not bool(current_scene.get("_controller_hand_focused")) and not await _press(JOY_BUTTON_X): return
	if not await _press(JOY_BUTTON_LEFT_SHOULDER): return
	_check(bool(current_scene.get("_controller_hand_focused")), "Controller did not enter hand")
	var titles: Array[String]
	var fitted: int = 0
	var ellipsized: int = 0
	for label: Label in current_scene.find_children("Title", "Label", true, false):
		if not label.is_visible_in_tree() or label.text not in TITLE_PROOF_NAMES: continue
		titles.append(label.text)
		var metrics: Dictionary = Geometry.text_data(label)
		var card: Control = label.get_parent().get_parent().get_parent().get_parent()
		var available: float = minf(metrics["available"][0], card.call("_title_nameplate_width"))
		var size: int = label.get_theme_font_size("font_size")
		var floor_size: int = Typography.scaled_size(label, card.call("_title_min_size"))
		metrics["fit_width"] = available
		metrics["font_size"] = size
		metrics["floor_size"] = floor_size
		log_event("card_title", metrics)
		if float(metrics["width"]) > available:
			ellipsized += 1
			_check(size == floor_size and label.text_overrun_behavior == TextServer.OVERRUN_TRIM_ELLIPSIS,
				"%s must ellipsize at the type floor" % label.text)
		else:
			fitted += 1
			_check(label.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING,
				"%s fits without ellipsis" % label.text)
	for title: String in TITLE_PROOF_NAMES:
		_check(title in titles, "Missing %s in the live hand" % title)
	_check(fitted > 0 and ellipsized > 0, "Fixture must exercise both full titles and floor ellipsis")

func _sweep_titles() -> void:
	var sweep := TitleSweep.new()
	var cards: PackedStringArray = TITLE_HAND.split(",")
	for count: int in range(1, Combat.MAX_HAND_SIZE + 2):
		var hand: PackedStringArray
		for slot: int in range(count):
			hand.append(cards[slot % cards.size()])
		var fixture: String = TITLE_SIX_CARD_HAND if count == 6 else ",".join(hand)
		if not await _install("combat", {"hand": fixture}): return
		if not await _sample_hand(sweep, count): return
	_case_failures.append_array(sweep.finish(_out))

func _sample_hand(sweep: RefCounted, count: int) -> bool:
	if current_scene.get("_controller_hand_focused") and not await _press(JOY_BUTTON_X): return false
	sweep.sample(current_scene, "board_focus", true)
	if not await _sample_transition(sweep, JOY_BUTTON_X, "enter_hand"): return false
	var first: int = current_scene.get("_controller_hand_index")
	for step: int in range(1, count):
		if not await _sample_transition(sweep, JOY_BUTTON_RIGHT_SHOULDER, "next_card"): return false
		_check(int(current_scene.get("_controller_hand_index")) == (first + step) % count,
			"R1 did not reach the expected slot in the %d-card hand" % count)
	return await _sample_transition(sweep, JOY_BUTTON_X, "leave_hand")

func _sample_transition(sweep: RefCounted, button: int, transition: String) -> bool:
	var observe := func() -> void: sweep.sample(current_scene, transition, false)
	process_frame.connect(observe)
	var sent: bool = await _press(button)
	process_frame.disconnect(observe)
	if not sent: return false
	var focused: bool = current_scene.get("_controller_hand_focused")
	_check(focused == (transition != "leave_hand"), "Unexpected controller focus after " + transition)
	sweep.sample(current_scene, "hand_focus" if focused else "board_focus", true)
	return true

func _reward_caption() -> void:
	if not await _install("reward", {"player_hp": INJURED_HEALTH, "player_max_hp": MAX_HEALTH}): return
	var button: Button = current_scene.find_child("RewardRecoverButton", true, false) as Button
	if not await _driver.control(button): return
	var metrics: Dictionary = Geometry.text_data(button)
	var panel: Control = current_scene.get("_relic_choice_host")
	var center_error: float = absf(button.get_global_rect().get_center().x - panel.get_global_rect().get_center().x)
	metrics["button_width"] = button.size.x
	metrics["panel_width"] = panel.size.x
	metrics["center_error"] = center_error
	log_event("reward_caption", metrics)
	_check(button.text.contains("23 → 24"), "Missing the QA Health transition")
	_check(float(metrics["width"]) <= float(metrics["available"][0]), "Health caption overflows: %s" % metrics)
	_check(center_error <= CENTER_ROUNDING_PIXELS, "Recover button is %s pixels off-center" % center_error)
	_check(button.get_theme_font_size("font_size") == Typography.scaled_size(button, Typography.SIZE_BODY_LARGE),
		"Recover caption shrank while the panel had space")
	if DisplayServer.get_name() == "headless" and _case_failures.is_empty():
		var row: HBoxContainer = button.get_parent()
		var normal_width: float = button.size.x
		var forced_cap: float = normal_width - WIDTH_CAP_EXERCISE_PIXELS
		RewardCaption.fit_row(row, forced_cap, current_scene.REWARD_ACTION_BUTTON_MIN_WIDTH)
		await process_frame
		_check(button.custom_minimum_size.x <= forced_cap, "Recover button exceeded the width limit")
		_check(button.get_theme_font_size("font_size") == Typography.scaled_size(button, Typography.SIZE_BODY),
			"Recover caption did not step down once at the width limit")

func _grimoire_search() -> void:
	if not await _install("start") or not await _close_start_map(): return
	if not await _activate(current_scene.get("grimoire_button")): return
	var field: LineEdit = current_scene.get("_grimoire_search_input")
	_check(field.has_focus(), "Search field did not receive initial focus")
	_check_tooltip(field)
	if not await _press(JOY_BUTTON_A): return
	_check_tooltip(field)
	if not await _press(JOY_BUTTON_DPAD_DOWN): return
	_check(not field.has_focus() and field.find_child("ControllerFocusTooltip", true, false) == null,
		"Search help remained after leaving search")
	await _press(JOY_BUTTON_DPAD_UP)
	_check(field.has_focus(), "D-pad Up did not return to search")

func _map_legend() -> void:
	if not await _install("start") or not await _close_start_map() or not await _press(JOY_BUTTON_BACK): return
	var map: Control = current_scene.get("_large_map_view")
	var legend: Control = map.find_child("MapLegend", true, false)
	var route: Control = root.gui_get_focus_owner()
	_check(route != null and str(route.name).begins_with("Room_"), "Map did not start on the route")
	_check(legend != null and legend.get_child_count() > 0, "Map legend is empty")
	if legend == null or legend.get_child_count() == 0: return
	for item: Control in legend.get_children():
		_check(item.focus_mode == Control.FOCUS_ALL and not _driver.gui_path(route, item).is_empty(),
			"Legend row unavailable from route: %s" % item.tooltip_text)
	var first: Control = legend.get_child(0)
	if first.focus_mode != Control.FOCUS_ALL or _driver.gui_path(route, first).is_empty(): return
	if not await _driver.control(first): return
	var hover: Control = first.call("_make_custom_tooltip", first.tooltip_text)
	_check_tooltip(first, _tooltip_text(hover))
	hover.free()
	if not await _press(JOY_BUTTON_DPAD_UP): return
	var returned: Control = root.gui_get_focus_owner()
	_check(returned != null and str(returned.name).begins_with("Room_"), "D-pad Up did not return to the route")
	await _driver.control(first)

func _check_tooltip(owner: Control, expected: String = "") -> void:
	var panel: Control = owner.find_child("ControllerFocusTooltip", true, false) as Control
	var text: String = _tooltip_text(panel) if panel != null else ""
	log_event("focus_tooltip", {"owner": str(owner.name), "text": text})
	_check(panel != null and panel.is_visible_in_tree() and not text.is_empty()
		and text == (owner.tooltip_text if expected.is_empty() else expected),
		"Focused %s did not show pointer help" % owner.name)

func _tooltip_text(panel: Control) -> String:
	var help: PackedStringArray
	for node: Node in panel.find_children("*", "", true, false):
		if node is Label: help.append(node.text)
		elif node is RichTextLabel: help.append(node.get_parsed_text())
	return "\n".join(help)

func _close_start_map() -> bool:
	var map: Control = current_scene.get("_large_map_scrim")
	return not map.visible or await _press(JOY_BUTTON_B)

func _activate(target: Control) -> bool:
	return await _driver.control(target) and await _press(JOY_BUTTON_A)

func _press(button: int) -> bool:
	var sent: bool = await _driver.pad.button(button)
	if not sent: fail("QA joypad driver dropped button %d" % button)
	await _settle()
	return sent

func _settle() -> void:
	await hold(SETTLE_SECONDS)
	var deadline: int = Time.get_ticks_msec() + TIMEOUT_MSEC
	while not Gate.ready(current_scene) and Time.get_ticks_msec() < deadline: await process_frame
	_driver.scene = current_scene

func _controller_active() -> bool:
	return root.get_node("InputRouter").call("using_controller")

func _capture(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join("ui38-" + label + ".png")
	if image == null or image.get_size() != _proof_size or image.save_png(path) != OK:
		fail("Capture did not save at %s" % str(_proof_size))
	else:
		print(path)

func hold(seconds: float) -> void:
	await create_timer(seconds).timeout

func _check(condition: bool, message: String) -> void:
	if not condition: fail(message)

func fail(reason: String) -> void:
	_case_failures.append(reason)

func log_event(kind: String, data: Dictionary = {}) -> void:
	_report.store_line(JSON.stringify({"kind": kind, "data": data}))
