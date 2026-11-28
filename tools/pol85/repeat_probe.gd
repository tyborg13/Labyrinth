extends "res://tests/controller_screen_sweep.gd"
## Production screens with deterministic game-time holds and viewport-only input.

const AxisRepeat = preload("res://scripts/controller_axis_repeat.gd")
const Grimoire = preload("res://scripts/grimoire_library.gd")
const Nav = preload("res://scripts/controller_navigation.gd")
const TICK_SECONDS: float = 0.01
const HOLD_TICKS: int = 100
const REPEAT_TICKS := [0, 40, 52, 64, 76, 88, 100]
const PROBE_STICK: float = 0.80
const SLIDER_INTERIOR: float = 0.50
const HEIRLOOM_CARDS: int = 4
const POPUP_PROOF_ITEMS: int = 10

var _targets: int

func _initialize() -> void:
	Runtime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--movie") or args.has("--movie-check"):
		quit(0 if await preload("res://tools/pol85/movie_probe.gd").capture(self) else 1)
		return
	Store.set_storage_path("user://pol85_profile.json")
	Store.set_run_storage_path("user://pol85_run.save")
	Settings.set_storage_path("user://pol85_settings.json")
	Analytics.set_storage_dir("user://pol85_analytics")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Store.save_data(Store.default_data())
	Router.ensure_input_map()
	_router = root.get_node("InputRouter")
	_router.call("set_forced_state_for_test", "controller", Router.FAMILY_STEAM_DECK)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.gui_embed_subwindows = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	await _menu_holds()
	await _make_run()
	await _combat_holds()
	await _run_gui_holds()
	await _encounter_holds()
	await _chronicle_holds()
	await _large_map_cursor_holds()
	if is_instance_valid(_scene):
		_scene.queue_free()
		await _settle()
	for failure: String in _failures: print("POL85 FINDING " + failure)
	print("POL85 DPAD REPEAT %s targets=%d" % ["PASS" if _failures.is_empty() else "FAIL", _targets])
	quit(0 if _failures.is_empty() else 1)

func _make_run() -> void:
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set("_defer_initial_run_presentation", true)
	_viewport.add_child(_scene)
	_scene.set("_defer_initial_run_presentation", false)
	await _settle()

func _press(button: int, pressed: bool = true, viewport: Viewport = null) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button as JoyButton
	event.pressed = pressed
	(viewport if viewport != null else _viewport).push_input(event, true)

func _axis(axis: JoyAxis, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	_viewport.push_input(event, true)

func _label(button: int) -> String:
	var labels := {JOY_BUTTON_DPAD_LEFT: "left", JOY_BUTTON_DPAD_RIGHT: "right", JOY_BUTTON_DPAD_UP: "up", JOY_BUTTON_DPAD_DOWN: "down", JOY_BUTTON_A: "accept", JOY_BUTTON_RIGHT_SHOULDER: "right_shoulder", JOY_BUTTON_B: "back"}
	return labels.get(button, str(button))

func _report(target: String, button: int, actual: int, expected: int, exact: bool) -> void:
	_targets += 1
	var success: bool = actual == expected and exact
	var line: String = "POL85 TARGET %s dir=%s steps=%d expected=%d %s" % [target, _label(button), actual, expected, "PASS" if success else "FAIL"]
	print(line)
	if not success: _failures.append(line)

func _hold(target: String, button: int, path: Array, read: Callable, clock: Callable, viewport: Viewport = null) -> void:
	var initial: Variant = read.call()
	var previous: Variant = initial
	var steps: int = 0
	var exact: bool = true
	for tick: int in range(HOLD_TICKS + 1):
		if tick == 0: _press(button, true, viewport)
		else: clock.call(TICK_SECONDS)
		var current: Variant = read.call()
		if current != previous:
			steps += 1
			previous = current
		var index: int = -1
		for edge: int in REPEAT_TICKS:
			if edge <= tick: index += 1
		var expected: Variant = initial if path.is_empty() else path[mini(index, path.size() - 1)]
		exact = exact and current == expected
	_press(button, false, viewport)
	clock.call(1.0)
	if not exact:
		print("POL85 TRACE ", target, " ", _label(button), " start=", initial, " actual=", previous, " expected=", path)
	_report(target, button, steps, path.size(), exact and read.call() == previous)

func _focus_clock(host: Node) -> Callable:
	return host.get_node("ControllerGuiNavigation").get("_process")

func _focus_path(start: Control, side: Side, region: Array, order_axis: int = -1) -> Array:
	var path: Array = []
	var source: Control = start
	var direction: Vector2 = [Vector2.LEFT, Vector2.UP, Vector2.RIGHT, Vector2.DOWN][side]
	var axis: int = Vector2.AXIS_X if direction.x != 0.0 else Vector2.AXIS_Y
	for step: int in REPEAT_TICKS.size():
		var next: Control = source.find_valid_focus_neighbor(side)
		if next == source or not region.has(next): break
		var distance: float = (next.get_global_rect().get_center() - source.get_global_rect().get_center()).dot(direction)
		if order_axis == axis: distance = float(region.find(next) - region.find(source)) * direction[axis]
		if distance <= 0.0: break
		path.append(next)
		source = next
	return path

func _focus_holds(label: String, controls: Array, clock: Callable, order_axis: int = -1, check_exits: bool = true) -> void:
	var region: Array = []
	region.append_array(controls)
	var observed: int = 0
	for edge: Array in EDGES:
		var side: Side = edge[0]
		var button: int = edge[1]
		var first: Control
		var exit_from: Control
		var exit_to: Control
		var path: Array = []
		for control: Control in region:
			if control.focus_mode == Control.FOCUS_NONE or not control.is_visible_in_tree(): continue
			var next: Control = control.find_valid_focus_neighbor(side)
			if next != null and next != control and not region.has(next):
				exit_from = control
				exit_to = next
			var candidate: Array = _focus_path(control, side, region, order_axis)
			if candidate.size() > path.size():
				first = control
				path = candidate
		if first != null:
			first.grab_focus()
			_hold(label, button, path, _focus, clock)
			observed += 1
		if check_exits and exit_from != null:
			exit_from.grab_focus()
			exit_to = exit_from.find_valid_focus_neighbor(side)
			if exit_to != null and not region.has(exit_to):
				_hold(label + "_exit", button, [exit_to], _focus, clock)
	if observed == 0 and not region.is_empty() and region.size() > 1:
		_failures.append(label + " has no same-region directions in the fixture")

func _menu_holds() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	menu.set_script(MenuFixture)
	_viewport.add_child(menu)
	await _settle()
	_focus_holds("title/menu", menu.get_node("MenuColumn").find_children("*", "Button", true, false), _focus_clock(menu), -1, false)
	menu.call("_on_settings_button_pressed")
	await _settle()
	var panel: Control = menu.get("settings_panel")
	var clock: Callable = _focus_clock(panel)
	var controls: Dictionary = panel.get("_controls")
	var rows: Array = []
	var sliders: Array[HSlider]
	for control: Variant in controls.values():
		if control is Control and control.is_visible_in_tree(): rows.append(control)
		if control is Dictionary and control.get("slider") is HSlider: sliders.append(control["slider"])
	rows.append_array(sliders)
	_focus_holds("settings/rows", rows, clock, -1, false)
	for slider: HSlider in sliders:
		for button: int in [JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT]:
			slider.grab_focus()
			slider.value = SLIDER_INTERIOR
			var path: Array = []
			var direction: float = AxisRepeat.dpad_direction(button).x
			for step: int in range(1, REPEAT_TICKS.size() + 1):
				path.append(roundi((SLIDER_INTERIOR + step * direction * slider.step) / slider.step))
			_hold("settings/" + str(slider.name), button, path, func() -> int: return roundi(slider.value / slider.step), clock)
	var option: OptionButton = controls["display_mode"]
	var popup: PopupMenu = option.get_popup()
	option.grab_focus()
	popup.popup()
	await _settle()
	_expect(popup.visible, "Settings option popup is open")
	for button: int in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var direction: int = int(AxisRepeat.dpad_direction(button).y)
		var from: int = 0 if direction > 0 else popup.item_count - 1
		var path: Array = []
		for index: int in range(from + direction, popup.item_count if direction > 0 else -1, direction):
			if not popup.is_item_disabled(index): path.append(index)
		popup.set_focused_item(from)
		_hold("settings/option_popup", button, path, popup.get_focused_item, popup.get_node("ControllerOptionNavigation").get("_process"), popup)
		popup.set_focused_item(popup.item_count - 1 if direction > 0 else 0)
		_hold("settings/option_popup_wrap", button, [from], popup.get_focused_item, popup.get_node("ControllerOptionNavigation").get("_process"), popup)
	# Extend the same option fixture to exercise the full cadence inside PopupMenu.
	while popup.item_count < POPUP_PROOF_ITEMS: popup.add_item("Proof " + str(popup.item_count))
	popup.set_focused_item(0)
	_hold("settings/long_option_popup", JOY_BUTTON_DPAD_DOWN, [1, 2, 3, 4, 5, 6, 7], popup.get_focused_item, popup.get_node("ControllerOptionNavigation").get("_process"), popup)
	popup.hide()
	_input_handoffs(panel, sliders[0], clock)
	panel.call("_show_restore_confirmation")
	await _settle()
	_focus_holds("settings/confirmation", _controls(panel.get("_confirmation_panel")), clock)
	panel.call("_cancel_restore_confirmation")
	menu.call("_on_settings_back_button_pressed")
	Store.clear_saved_run()
	Store.save_data(DepthFixture._profile(SETUP_UNLOCKED_DEPTH, SETUP_INITIAL_DEPTH))
	menu.call("_reload_progression")
	menu.call("_on_start_button_pressed")
	await _settle()
	var setup: Control = menu.get("_new_descent_panel")
	if is_instance_valid(setup):
		_focus_holds("new_descent/depth", _by_region(setup, &"descent_depth"), _focus_clock(menu))
		_focus_holds("new_descent/footer", _by_region(setup, &"descent_footer"), _focus_clock(menu))
	else:
		_failures.append("New Descent fixture did not open")
	menu.free()
	Store.save_data(Store.default_data())
	await _settle()

func _input_handoffs(panel: Control, slider: HSlider, clock: Callable) -> void:
	slider.grab_focus()
	slider.value = SLIDER_INTERIOR
	var unit: float = slider.step
	_press(JOY_BUTTON_DPAD_RIGHT)
	clock.call(0.4)
	var dpad_step: bool = is_equal_approx(slider.value, SLIDER_INTERIOR + 2.0 * unit)
	_axis(JOY_AXIS_LEFT_X, -PROBE_STICK)
	var first_stick: bool = is_equal_approx(slider.value, SLIDER_INTERIOR + unit)
	clock.call(0.4)
	_report("settings/dpad_to_stick", JOY_BUTTON_DPAD_RIGHT, 2 if is_equal_approx(slider.value, SLIDER_INTERIOR) else 1, 2, dpad_step and first_stick)
	_axis(JOY_AXIS_LEFT_X, 0.0)
	_press(JOY_BUTTON_DPAD_RIGHT, false)

	_press(JOY_BUTTON_DPAD_RIGHT)
	panel.get_node("ControllerGuiNavigation").notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	clock.call(1.0)
	_report("settings/focus_loss", JOY_BUTTON_DPAD_RIGHT, roundi((slider.value - SLIDER_INTERIOR) / unit), 1, true)
	_press(JOY_BUTTON_DPAD_RIGHT, false)

	slider.value = SLIDER_INTERIOR
	_press(JOY_BUTTON_DPAD_RIGHT)
	panel.call("_show_restore_confirmation")
	clock.call(1.0)
	panel.call("_cancel_restore_confirmation")
	slider.grab_focus()
	clock.call(1.0)
	_report("settings/modal_reset", JOY_BUTTON_DPAD_RIGHT, roundi((slider.value - SLIDER_INTERIOR) / unit), 1, true)
	_press(JOY_BUTTON_DPAD_RIGHT, false)

func _prepare_hand() -> void:
	await _load(_combat_state())
	if _scene.get("_controller_region") != "hand":
		_press(JOY_BUTTON_X)
		_press(JOY_BUTTON_X, false)
	_scene.call("_controller_set_hand_index", 0)
	await _settle()

func _combat_holds() -> void:
	await _prepare_hand()
	var clock: Callable = _scene.get("_advance_controller_dpad")
	var read_hand: Callable = _scene.get.bind("_controller_hand_index")
	_hold("combat/hand", JOY_BUTTON_DPAD_RIGHT, [1, 2, 3, 4], read_hand, clock)
	_hold("combat/hand", JOY_BUTTON_DPAD_LEFT, [3, 2, 1, 0], read_hand, clock)
	_hold("combat/hand_wrap", JOY_BUTTON_DPAD_LEFT, [4], read_hand, clock)
	_hold("combat/hand_wrap", JOY_BUTTON_DPAD_RIGHT, [0], read_hand, clock)
	_hold("combat/hand_to_board", JOY_BUTTON_DPAD_UP, ["board"], _scene.get.bind("_controller_region"), clock)
	for edge: Array in EDGES:
		_board_hold("combat/board", edge[1])
	_board_to_hand(clock)
	_scene.set("_controller_region", "hand")
	_scene.call("_controller_set_hand_index", 0)
	_press(JOY_BUTTON_DPAD_RIGHT)
	clock.call(0.4)
	_press(JOY_BUTTON_DPAD_LEFT)
	clock.call(1.0)
	_report("combat/second_dpad", JOY_BUTTON_DPAD_LEFT, 2 - int(read_hand.call()), 2, read_hand.call() == 0)
	_press(JOY_BUTTON_DPAD_LEFT, false)
	_press(JOY_BUTTON_DPAD_RIGHT, false)

func _board_to_hand(clock: Callable) -> void:
	# Remove the intervening HUD stops in this fixture to expose the board edge.
	var hidden: Array[Control]
	var candidates: Array[Dictionary] = _scene.call("_controller_navigation_candidates")
	for candidate: Dictionary in candidates:
		var control: Control = candidate.get("control")
		if control == null or not control.visible: continue
		control.hide()
		hidden.append(control)
	candidates = _scene.call("_controller_navigation_candidates")
	var found: bool = false
	for candidate: Dictionary in candidates:
		if not candidate.has("tile"): continue
		if Nav.best_candidate_in_direction(candidate["point"], Vector2.DOWN, candidates, candidate["key"]).is_empty():
			_scene.call("_controller_set_focus_candidate", candidate, true)
			_hold("combat/board_to_hand", JOY_BUTTON_DPAD_DOWN, ["hand"], _scene.get.bind("_controller_region"), clock)
			found = true
			break
	for control: Control in hidden: control.show()
	_expect(found, "The fixture exposes Down from the board to the hand")

func _board_hold(label: String, button: int) -> void:
	var candidates: Array[Dictionary] = _scene.call("_controller_navigation_candidates")
	var direction: Vector2 = AxisRepeat.dpad_direction(button)
	var path: Array = []
	var first: Dictionary = {}
	for candidate: Dictionary in candidates:
		if not candidate.has("tile"): continue
		var from: Dictionary = candidate
		var possible: Array = []
		for step: int in REPEAT_TICKS.size():
			var next: Dictionary = Nav.best_candidate_in_direction(from["point"], direction, candidates, from["key"])
			if not next.has("tile"): break
			possible.append(next["key"])
			from = next
		if possible.size() > path.size():
			path = possible
			first = candidate
	if not first.is_empty():
		_scene.call("_controller_set_focus_candidate", first, true)
		var read: Callable = func() -> String: return str(_scene.get("_controller_focus_candidate").get("key", ""))
		_hold(label, button, path, read, _scene.get("_advance_controller_dpad"))

func _prepare_grimoire() -> Control:
	var state: Dictionary = _base_state()
	var unlocked: Array[String]
	for entry: Dictionary in Grimoire.entries(): unlocked.append(str(entry["id"]))
	state[Grimoire.UNLOCKED_KEY] = unlocked
	await _load(state)
	_scene.call("_open_grimoire_overlay")
	await _settle()
	return _scene.get("_grimoire_scrim")

func _by_region(scope: Control, key: Variant) -> Array:
	return _controls(scope).filter(func(control: Control) -> bool: return is_same(AxisRepeat.focus_region(control, scope), key))

func _run_gui_holds() -> void:
	await _load(_legacy_room_state())
	_scene.call("_controller_enter_board", false)
	for edge: Array in EDGES: _board_hold("room/door_cursor", edge[1])
	var clock: Callable = _focus_clock(_scene)
	await _load(_base_state())
	_scene.call("_open_large_map")
	await _settle()
	var map: Control = _scene.get("_large_map_view")
	_focus_holds("section_map/doors", map.get("node_buttons").values(), clock)
	_focus_holds("section_map/tabs", map.get("_tabs").get_children(), clock)
	_focus_holds("section_map/legend", map.get("_legend").get_children(), clock)
	_scene.call("_close_large_map")
	_scene.call("_open_menu_overlay")
	await _settle()
	_focus_holds("pause/buttons", _controls(_scene.get("_menu_scrim")), clock, -1, false)
	_scene.call("_close_menu_overlay")

	await _load(_character_state())
	for tab: String in ["equipment", "magic", "skills"]:
		_scene.call("_open_character_overlay", tab)
		await _settle()
		var scope: Control = _scene.get("_upgrade_scrim")
		_focus_holds("character/tabs_" + tab, _by_region(scope, &"character_tabs"), clock)
		for panel_name: String in ["CurrentDeckPanel", "MagicAttunedPanel", "EquipmentInventoryPanel", "EquipmentEquippedPanel"]:
			var panel: Control = scope.find_child(panel_name, true, false)
			if panel != null and panel.is_visible_in_tree():
				_focus_holds("character/" + panel_name + "_" + tab, _controls(panel), clock, -1, false)
		if tab == "skills":
			_focus_holds("character/skill_tree", _by_region(scope, &"skill_tree_nodes"), clock)
		_scene.call("_close_card_upgrade_overlay")
		await _settle()

	var grimoire: Control = await _prepare_grimoire()
	var rows: Array = grimoire.get("_grimoire_nav_buttons")
	_focus_holds("grimoire/browse", rows, clock, -1, false)
	var search: LineEdit = grimoire.get("_grimoire_search_input")
	search.grab_focus()
	_hold("grimoire/search_to_list", JOY_BUTTON_DPAD_DOWN, [rows.front()], _focus, clock)
	search.text = "a"
	grimoire.call("_on_grimoire_search_text_changed", "a")
	await _settle()
	_focus_holds("grimoire/results", grimoire.get("_grimoire_search_result_buttons"), clock, -1, false)
	_scene.call("_close_grimoire_overlay")

	await _prepare_hand()
	_scene.get("_combat_state")["deck"]["draw"] = ["quick_stab", "patch_up", "thunderline", "guarded_step", "sidestep_slash"]
	_scene.call("_open_pile_view", "draw")
	await _settle()
	var pile: Control = _scene.get("_pile_dialog_cards")
	_focus_holds("deck/pile", _controls(pile), clock)
	_scene.call("_close_pile_view")

func _encounter_holds() -> void:
	var clock: Callable = _focus_clock(_scene)
	var state: Dictionary = _base_state()
	for room: Dictionary in state["rooms"].values():
		if room.get("type") != "combat": continue
		state["current_room"] = room["coord"]
		state["mode"] = Run.MODE_PRE_BATTLE
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = Vector2i.RIGHT
		break
	await _load(state)
	var preview: Control = _scene.get("_pre_battle_scrim")
	for panel: Node in preview.find_children("*", "Control", true, false):
		if panel.has_meta(AxisRepeat.REGION_META):
			_focus_holds("pre_battle/" + str(panel.name), _controls(panel), clock)

	state = _base_state()
	state["mode"] = "reward"
	state["pending_reward"] = {"cards": ["quick_stab", "bone_dart", "sidestep_slash"], "heal_amount": Run.REWARD_HEAL, "ember_amount": 0}
	await _load(state)
	var reward: Control = _scene.get("_relic_choice_overlay")
	_focus_holds("reward/cards", _by_region(reward, &"reward_cards"), clock, Vector2.AXIS_X)
	_focus_holds("reward/actions", _by_region(reward, &"reward_actions"), clock, Vector2.AXIS_X)

	await _load(EventFixture.fixture("hanged_knight", true))
	await create_timer(EVENT_SWEEP_SETTLE_SECONDS).timeout
	var view: Control = _scene.get("_event_view")
	var choices: Array = view.get("choices")
	for button: int in [JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN]:
		var direction: int = int(AxisRepeat.dpad_direction(button).y)
		var start: int = 0 if direction > 0 else choices.size() - 1
		var finish: int = choices.size() - 1 - start
		choices[start].grab_focus()
		var path: Array = []
		for index: int in range(start + direction, finish + direction, direction): path.append(index)
		_hold("event/choices", button, path, view.focused_choice_index, view.get("_process"))
		_hold("event/choice_wrap", button, [start], view.focused_choice_index, view.get("_process"))
	var requests: Array[String]
	view.choice_requested.connect(func(id: String) -> void: requests.append(id))
	view.focus_initial()
	_hold("event/confirm", JOY_BUTTON_A, [1], func() -> int: return requests.size(), view.get("_process"))

	await _load_graftwright_fixture()
	var graft: Control = _scene.get("_graftwright_view")
	_focus_holds("graftwright/intro", _controls(graft), clock, -1, false)
	var browse: Control = graft.find_child("GraftBrowse", true, false)
	browse.grab_focus()
	await _joy(JOY_BUTTON_A)
	_focus_holds("graftwright/workbench", _controls(graft), clock, -1, false)

	state = _shop_fixture()
	await _load(state)
	var shop: Control = _scene.get("_scavenger_shop_view")
	shop.call("_configure_focus_neighbors")
	_focus_holds("shop/shelves", _by_region(shop, &"shop_offers"), clock)
	shop.call("_set_pack_mode", true)
	await _settle()
	_focus_holds("shop/pack", _by_region(shop, &"shop_offers"), clock)
	_focus_holds("shop/filters", _by_region(shop, &"shop_filters"), clock)
	shop.call("_set_pack_mode", false)
	_scene.call("_open_magic_purge", "scavenger")
	await _settle()
	var purge: Control = _scene.get("_magic_purge_overlay")
	if is_instance_valid(purge):
		_focus_holds("purge/cards", _by_region(purge, &"purge_cards"), clock)
		_scene.call("_close_magic_purge", false)

	HearthFixture.setup(_scene, 8, 180, true, false)
	await _settle()
	var hearth: Control = _scene.get("_relic_choice_overlay")
	_focus_holds("hearth/choices", _controls(hearth), clock, -1, false)

	state = _base_state()
	state["mode"] = "defeat"
	await _load(state)
	var recap: Control = _scene.get("_run_end_recap")
	recap.skip_presentation()
	await _settle()
	_focus_holds("recap/actions", _by_region(recap, &"recap_actions"), clock)
	await _opening_boon_holds()
	await _heirloom_holds()

func _opening_boon_holds() -> void:
	var state: Dictionary = preload("res://tests/helpers/opening_boon_fixture.gd").state(true)
	Store.save_data(state["progression"])
	await _load(state)
	_scene.call("_speak_to_emaciated_man")
	_scene.call("_complete_current_dialogue_line")
	await _settle()
	var view: Control = _scene.get("_opening_boon_flow").overlay
	if not is_instance_valid(view):
		_failures.append("Opening boon fixture did not open")
		return
	_focus_holds("opening_boon/cards", _by_region(view, &"opening_boon_cards"), _focus_clock(_scene), Vector2.AXIS_X)

func _heirloom_holds() -> void:
	var view: Control = await preload("res://tests/helpers/heirloom_checks.gd").open(self, _scene, HEIRLOOM_CARDS)
	var read: Callable = view.get.bind("selected_index")
	var clock: Callable = view.get("_process")
	_hold("heirloom/cards", JOY_BUTTON_DPAD_RIGHT, [1, 2, 3], read, clock)
	_hold("heirloom/card_wrap", JOY_BUTTON_DPAD_RIGHT, [0], read, clock)
	_hold("heirloom/card_wrap", JOY_BUTTON_DPAD_LEFT, [3], read, clock)
	_hold("heirloom/cards", JOY_BUTTON_DPAD_LEFT, [2, 1, 0], read, clock)
	_hold("heirloom/card_to_leave", JOY_BUTTON_DPAD_DOWN, [HEIRLOOM_CARDS], read, clock)
	_hold("heirloom/leave_to_card", JOY_BUTTON_DPAD_UP, [0], read, clock)

func _shop_fixture() -> Dictionary:
	var state: Dictionary = _base_state()
	var engine := Run.new()
	for room: Dictionary in state["rooms"].values():
		if str(room.get("merchant_kind", "")) != "scavenger" and str(room.get("type", "")) != "scavenger": continue
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = true
		room[Run.MERCHANT_STOCK_KEY] = ["grave_mortar", "boiled_leather", "crimson_draught"]
		state["current_room"] = room["coord"]
		state["current_room_layout"] = engine.call("_display_layout_for_room", FIXTURE_SEED, room, Vector2i.RIGHT)
		break
	state["held_embers"] = FIXTURE_BUDGET
	state["unbanked_embers"] = FIXTURE_BUDGET
	state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "grave_mortar"]
	state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	return state

func _chronicle_holds() -> void:
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var chronicle: Control = preload("res://scripts/chronicle_panel.gd").new()
	_viewport.add_child(chronicle)
	chronicle.call("open", preload("res://tests/chronicle_probe.gd").seeded_profile(), false)
	await _settle()
	var clock: Callable = chronicle.get("_process")
	var read: Callable = chronicle.get.bind("selected_index")
	for direction: int in [1, -1]:
		var start: int = 0 if direction > 0 else 6
		var path: Array = []
		for index: int in range(start + direction, 7 if direction > 0 else -1, direction): path.append(index)
		chronicle.select_record(start, true)
		_hold("chronicle/records", JOY_BUTTON_DPAD_DOWN if direction > 0 else JOY_BUTTON_DPAD_UP, path, read, clock)
	chronicle.select_record(0, true)
	var row: Control = chronicle.get("_rows").get_child(0)
	var tile: Control = row.find_valid_focus_neighbor(SIDE_RIGHT)
	_hold("chronicle/record_to_detail", JOY_BUTTON_DPAD_RIGHT, [tile], _focus, clock)
	var detail: Control = chronicle.get("_detail")
	var chain: Array = []
	var cursor: Control = tile
	while cursor != null and detail.is_ancestor_of(cursor) and not chain.has(cursor):
		chain.append(cursor)
		cursor = cursor.find_valid_focus_neighbor(SIDE_RIGHT)
	for edge: Array in EDGES:
		var step: int = 1 if edge[0] in [SIDE_RIGHT, SIDE_BOTTOM] else -1
		var start: int = 0 if step > 0 else chain.size() - 1
		var path: Array = []
		for index: int in range(start + step, chain.size() if step > 0 else -1, step): path.append(chain[index])
		chain[start].grab_focus()
		_hold("chronicle/detail", edge[1], path.slice(0, REPEAT_TICKS.size()), _focus, clock)
	chronicle.select_record(0, true)
	_hold("chronicle/page_switch", JOY_BUTTON_RIGHT_SHOULDER, [clampi(floori((chronicle.get("_list") as Control).size.y / chronicle.ROW_HEIGHT), 1, 6)], read, clock)
	chronicle.select_record(0, true)
	var echo := InputEventKey.new()
	echo.keycode = KEY_DOWN
	echo.pressed = true
	echo.echo = true
	_viewport.push_input(echo, true)
	_report("chronicle/keyboard_echo", JOY_BUTTON_DPAD_DOWN, chronicle.selected_index, 1, true)
	chronicle.free()
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
	await _settle()

func _large_map_cursor_holds() -> void:
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var map: Control = preload("res://scripts/labyrinth_map_view.gd").new()
	map.size = Vector2(PROOF_SIZE)
	_viewport.add_child(map)
	map.set_run_state(_base_state())
	await _settle()
	map.grab_focus()
	for edge: Array in EDGES:
		var direction: Vector2 = AxisRepeat.dpad_direction(edge[1])
		var bounds: Rect2 = map.get("_map_rect_cache")
		var origin: Vector2 = bounds.get_center() - bounds.size * direction * 0.5
		var path: Array = []
		var stride: float = maxf(86.0, float(map.get("_base_node_size_cache")) * 1.18)
		for index: int in range(1, REPEAT_TICKS.size() + 1):
			var point: Vector2 = (origin + direction * stride * index).clamp(bounds.position, bounds.end)
			if path.is_empty() or not point.is_equal_approx(path.back()): path.append(point)
		map.set("_controller_cursor_position", origin)
		var read: Callable = func() -> Vector2i: return Vector2i((map.get("_controller_cursor_position") as Vector2).round())
		_hold("large_map/cursor", edge[1], path.map(func(point: Vector2) -> Vector2i: return Vector2i(point.round())), read, map.get("_process"))
	map.free()
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
