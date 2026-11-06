extends SceneTree
## Controller-only inventory and routed activation. The same script supplies native proof.
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Router = preload("res://scripts/input_router.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const EventFixture = preload("res://tests/suites/event_view_suite.gd")
const GraftFixture = preload("res://tests/suites/graftwright_suite.gd")
const HearthFixture = preload("res://tests/suites/ember_hearth_suite.gd")
const DepthFixture = preload("res://tests/suites/depth_rules_suite.gd")
const Recap = preload("res://scripts/run_end_recap_overlay.gd")
# Debug-only fixtures and bounds, never production tuning.
const PROOF_SIZE := Vector2i(1920, 1080)
const FIXTURE_SEED: int = 73491
const FIXTURE_BUDGET: int = 720
const UNAFFORDABLE_SHOP_EMBERS: int = 0
const UNAFFORDABLE_SHOP_GEAR: String = "witchglass_aegis"
const SKILL_LEARN_FOCUS_ID: String = "ghost_stride"
const SETTLE_FRAMES: int = 3
const NAVIGATION_LIMIT: int = 160
const CURSOR_TICK_SECONDS: float = 1.0 / 60.0
const HUD_REBUILD_ENEMY_POSITION := Vector2i(5, 4)
const STALE_CONTROL_TEST_SIZE := Vector2(40, 40)
const SHORTCUT_TOOLTIP_CASES: int = 16
const SETUP_UNLOCKED_DEPTH: int = 3
const SETUP_INITIAL_DEPTH: int = 1
const SETUP_NEXT_DEPTH: int = 2
const ANALOG_TEST_TICK_SECONDS: float = 0.01
const ANALOG_TEST_HOLD_TICKS: int = 95
const ANALOG_TEST_BEFORE_REPEAT_TICKS: int = 39
const ANALOG_TEST_START_VOLUME: float = 0.50
const ANALOG_TEST_NEUTRAL: float = 0.29
const HOLD_JITTER_SAMPLES: Array = [0.70, 0.71, 0.72, 0.71, 0.70]
const READY_TIMEOUT_MSEC: int = 15000
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/kb-03"
const EDGES: Array = [
	[SIDE_LEFT, JOY_BUTTON_DPAD_LEFT], [SIDE_TOP, JOY_BUTTON_DPAD_UP],
	[SIDE_RIGHT, JOY_BUTTON_DPAD_RIGHT], [SIDE_BOTTOM, JOY_BUTTON_DPAD_DOWN],
]
# Director rule: use the existing Back/Leave/Cancel action, or do nothing silently.
const BACK_RULE: String = "B follows the screen's existing back, leave or cancel control; with none, B does nothing and requests no sound."
const SEARCH_TEXT_ENTRY_SCOPE: String = "Search text entry is keyboard only and outside the controller sweep; queries are fixture data."

class MenuFixture extends "res://scripts/main_menu.gd":
	var requested_scene: String = ""
	func _change_scene_to_file(path: String, _prepare: Callable = Callable()) -> void: requested_scene = path
	func _on_quit_button_pressed() -> void: requested_scene = "quit"

class RunFixture extends "res://scripts/run_scene.gd":
	var requested_scene: String = ""
	func _on_restart_pressed() -> void: requested_scene = "restart"
	func _change_scene_to_file(path: String) -> void: requested_scene = path

var _viewport: SubViewport
var _scene: Control
var _router: Node
var _failures: Array[String]
var _rows: Array[Dictionary]
var _capture_screen: String = ""
var _before: bool = false
var _activation_menu: Control
var _surface_states: Dictionary = {}
var _surface_views: Dictionary = {}
var _pressed_rows: Array[Dictionary]
var _back_checks: Array[Dictionary]
var _menu: Control
var _regression_checks: Array[Dictionary]
var _output_dir: String = OUTPUT_DIR
var _setup_only: bool = false

func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_before = args.has("--before")
	_setup_only = args.has("--new-run-setup-only")
	if args.has("--output-dir"):
		_output_dir = args[args.find("--output-dir") + 1]
	if args.has("--capture-screen"):
		_capture_screen = args[args.find("--capture-screen") + 1]
	if args.has("--write-proof-contract"):
		var contract: Dictionary = {"min_images": 1, "expected_sizes": ["1920x1080"], "required_images": [{"pattern": "*" + _capture_screen + "_focus.png", "width": 1920, "height": 1080, "regions": [{"rect": [0, 0, 1920, 1080], "min_luma_range": 20, "min_luma_stdev": 3}]}]}
		var file := FileAccess.open(args[args.find("--write-proof-contract") + 1], FileAccess.WRITE)
		file.store_string(JSON.stringify(contract, "\t") + "\n")
		quit(0)
		return
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(_output_dir)
	Store.set_storage_path("user://kb03_profile.json")
	Store.set_run_storage_path("user://kb03_run.save")
	Settings.set_storage_path("user://kb03_settings.json")
	Analytics.set_storage_dir("user://kb03_analytics")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Store.save_data(Store.default_data())
	Store.clear_saved_run()
	Router.ensure_input_map()
	_router = root.get_node("InputRouter")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	# Headless semantics may await post-draw in production; no image proof is claimed.
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	var links_only: bool = OS.get_cmdline_user_args().has("--scavenger-links-only")
	var combat_only: bool = OS.get_cmdline_user_args().has("--combat-only")
	var menu_only: bool = OS.get_cmdline_user_args().has("--menu-only") or _setup_only
	var regressions_only: bool = OS.get_cmdline_user_args().has("--regressions-only")
	var tutorial_only: bool = OS.get_cmdline_user_args().has("--tutorial-navigation-only")
	var reward_only: bool = OS.get_cmdline_user_args().has("--reward-focus-only")
	var shortcuts_only: bool = OS.get_cmdline_user_args().has("--shortcut-tooltips-only")
	var skill_learn_only: bool = OS.get_cmdline_user_args().has("--skill-learn-focus-only")
	if not links_only and not combat_only and not regressions_only and not tutorial_only and not reward_only and not shortcuts_only and not skill_learn_only: await _menu_screens()
	_scene = load("res://scenes/run_scene.tscn").instantiate()
	_scene.set_script(RunFixture)
	_scene.set("_defer_initial_run_presentation", true)
	_viewport.add_child(_scene)
	_scene.set("_defer_initial_run_presentation", false)
	await _settle()
	if skill_learn_only:
		await _skill_learn_focus_regression()
	elif tutorial_only:
		await _tutorial_navigation_regression()
	elif reward_only:
		await _reward_focus_regression()
	elif shortcuts_only:
		await _shortcut_tooltips()
	elif regressions_only:
		await _hud_rebuild_regression()
		await _analog_volume_regression()
	elif menu_only:
		if _capture_screen.is_empty() and not _setup_only: await _activate_inventory()
	elif links_only:
		await _shop()
		if OS.get_cmdline_user_args().has("--activate-screen"): await _activate_inventory()
	elif combat_only:
		await _room_entry()
		await _combat_screens()
	else:
		await _room_and_character()
		await _room_entry()
		await _menu_back_paths()
		await _skill_reset_scope()
		await _skill_learn_focus_regression()
		await _combat_screens()
		await _hud_rebuild_regression()
		await _analog_volume_regression()
		await _encounter_screens()
		await _recap_screen()
		if _capture_screen.is_empty() and not OS.get_cmdline_user_args().has("--navigation-only"): await _activate_inventory()
	await _settle()
	_scene.queue_free()
	await _settle()
	var report: Dictionary = {"regressions": _regression_checks, "screens": _rows, "activation": _pressed_rows, "failures": _failures, "back_rule": BACK_RULE, "back_checks": _back_checks, "search_text_entry_scope": SEARCH_TEXT_ENTRY_SCOPE, "native_capture": _capture_screen}
	var filename: String = "sweep_before.json" if _before else "sweep_after.json"
	if regressions_only: filename = "regressions_%s.json" % ("before" if _before else "after")
	if tutorial_only: filename = "sweep_tutorial_navigation.json"
	if reward_only: filename = "sweep_reward_focus.json"
	if skill_learn_only: filename = "sweep_skill_learn_focus.json"
	if menu_only: filename = "sweep_menu.json"
	if _setup_only: filename = "sweep_new_run_setup.json"
	if combat_only: filename = "sweep_combat.json"
	if links_only: filename = "sweep_%s_scavenger.json" % ("before" if _before else "after")
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--activate-screen"): filename = "sweep_%s_%s.json" % ["before" if _before else "after", args[args.find("--activate-screen") + 1]]
	if not _capture_screen.is_empty(): filename = "sweep_native_%s.json" % _capture_screen
	var output: String = _output_dir.path_join(filename)
	var file := FileAccess.open(output, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t") + "\n")
	for row: Dictionary in _rows:
		print("SWEEP %s: %d/%d reached" % [row["screen"], row["reached"], row["total"]])
	for check: Dictionary in _back_checks:
		print("BACK RULE %s: %s (no action, no sound)" % [check["screen"], "PASS" if check["passed"] else "FAIL"])
	for failure: String in _failures: print("SWEEP FINDING: " + failure)
	print("CONTROLLER SCREEN SWEEP: %s (%d findings)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
	print("Sweep report: " + output)
	quit(0 if _failures.is_empty() else 1)

func _menu_screens() -> void:
	var menu: Control = load("res://scenes/main_menu.tscn").instantiate()
	_menu = menu
	menu.set_script(MenuFixture)
	_viewport.add_child(menu)
	await _settle()
	if _setup_only:
		await _new_run_setup(menu)
		menu.queue_free()
		_menu = null
		await _settle()
		return
	await _joy(JOY_BUTTON_DPAD_DOWN)
	await _scan("title", menu.get_node("MenuColumn"))
	await _assert_b_noop(menu, menu.get_node("MenuColumn"), "title")
	menu.call("_on_settings_button_pressed")
	await _settle()
	var panel: Control = menu.get("settings_panel")
	await _scan("settings", panel)
	var restore: Button = _button_text(panel, "Restore defaults")
	await _navigate(panel, restore, "settings restore")
	await _joy(JOY_BUTTON_A)
	var confirmation: Control = panel.get("_confirmation_panel")
	_expect(confirmation.visible, "Settings A opens restore confirmation")
	_expect(_inside(confirmation, _focus()), "Settings confirmation takes focus off the obscured controls")
	await _scan("settings_confirmation", confirmation)
	await _capture("settings")
	await _joy(JOY_BUTTON_B)
	_expect(panel.visible and not confirmation.visible, "Settings B cancels confirmation before leaving settings")
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	var pointer_focus: Control = _focus()
	panel.call("_show_restore_confirmation")
	await _motion(JOY_AXIS_LEFT_X, 0.0)
	_expect(_focus() == pointer_focus, "Neutral joypad noise preserves pointer confirmation focus")
	panel.call("_cancel_restore_confirmation")
	_router.call("set_forced_state_for_test", "controller", "xbox")
	await _joy(JOY_BUTTON_B)
	_expect(not panel.visible, "Settings B returns to title")
	await _new_run_setup(menu)
	Store.save_run_state(_base_state())
	menu.call("_reload_progression")
	menu.call("_focus_default_keyboard_target")
	await _scan("title_resume", menu.get_node("MenuColumn"))
	await _assert_b_noop(menu, menu.get_node("MenuColumn"), "title_resume")
	menu.call("_on_start_button_pressed")
	await _settle()
	await _scan("title_replacement", menu.get("replacement_panel"))
	await _joy(JOY_BUTTON_B)
	_expect(not bool(menu.get("_replacement_confirmation_open")), "Title replacement B returns to menu")
	menu.queue_free()
	_menu = null
	await _settle()

func _new_run_setup(menu: Control) -> void:
	Store.save_data(DepthFixture._profile(SETUP_UNLOCKED_DEPTH, SETUP_INITIAL_DEPTH))
	menu.call("_reload_progression")
	for button: int in [JOY_BUTTON_A, KEY_ENTER]:
		menu.set("requested_scene", "")
		menu.call("_on_start_button_pressed")
		await _settle()
		var initial: Control = menu.get("_new_descent_panel")
		_expect(initial != null, "New-run setup opens")
		if initial == null: return
		_expect(_focus() == initial.find_child("DepthBegin", true, false), "New-run setup initially focuses Begin Descent")
		if button == JOY_BUTTON_A:
			await _capture("new_run_setup", "initial_focus")
			await _joy(button)
		else:
			await _key(button)
		_expect(menu.get("_new_descent_panel") == null and str(menu.get("requested_scene")) == "res://scenes/run_scene.tscn", "New-run immediate A/Enter begins the chosen depth")
		_expect(Store.selected_umbra_depth(Store.load_data()) == SETUP_INITIAL_DEPTH, "New-run immediate A/Enter preserves chosen depth")
		if menu.get("_new_descent_panel") != null: initial.call("cancel")
	menu.set("requested_scene", "")
	menu.call("_on_start_button_pressed")
	await _settle()
	var picker: Control = menu.get("_new_descent_panel")
	if picker == null: return
	await _scan("new_run_setup", picker)
	await _navigate(picker, picker.find_child("DepthNext", true, false), "new-run next arrow")
	await _joy(JOY_BUTTON_A)
	_expect(int(picker.get("selected_depth")) == SETUP_NEXT_DEPTH and str(menu.get("requested_scene")).is_empty(), "New-run A activates the focused arrow once")
	await _navigate(picker, picker.find_child("DepthBack", true, false), "new-run Back")
	await _capture("new_run_setup")
	await _joy(JOY_BUTTON_A)
	_expect(menu.get("_new_descent_panel") == null and str(menu.get("requested_scene")).is_empty(), "New-run A activates focused Back instead of beginning a run")
	if menu.get("_new_descent_panel") != null: picker.call("cancel")
	menu.call("_on_start_button_pressed")
	await _settle()
	picker = menu.get("_new_descent_panel")
	if picker == null: return
	await _navigate(picker, picker.find_child("DepthBack", true, false), "new-run Enter from Back")
	await _key(KEY_ENTER)
	_expect(menu.get("_new_descent_panel") == null and str(menu.get("requested_scene")) == "res://scenes/run_scene.tscn", "New-run Enter from Back begins the chosen depth")
	_expect(Store.selected_umbra_depth(Store.load_data()) == SETUP_NEXT_DEPTH, "New-run Enter begins the changed depth")
	if menu.get("_new_descent_panel") != null: picker.call("cancel")
	menu.set("requested_scene", "")
	Store.clear_saved_run()
	Store.save_data(Store.default_data())

func _base_state() -> Dictionary:
	return Run.new().create_new_run(FIXTURE_SEED, Store.default_data())

func _load(state: Dictionary) -> void:
	_scene.call("_close_dialogue")
	_scene.call("_close_magic_purge", false)
	_scene.call("_close_menu_overlay")
	_scene.call("_close_large_map")
	_scene.call("_close_card_upgrade_overlay")
	_scene.call("_close_grimoire_overlay")
	_scene.call("_close_pile_view")
	_scene.call("_close_pre_battle_preview")
	_scene.call("_load_run_state", state)
	_scene.call("_close_dialogue")
	_scene.set("_animation_lock", false)
	await _settle()
	_scene.call("_close_dialogue")
	_scene.call("_close_large_map")
	_scene.call("_recover_controller_focus")
	await _settle()

func _character_state() -> Dictionary:
	var profile: Dictionary = Store.default_data()
	profile["level"] = 3
	profile["skill_ids"] = ["measured_breath"]
	profile["moltshards"] = 1
	var state: Dictionary = Run.new().create_new_run(FIXTURE_SEED, profile)
	state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	state["magic_inventory"] = ["spark_dart", "frostbolt"]
	state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "grave_mortar"]
	state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	return state

func _room_and_character() -> void:
	await _load(_base_state())
	_scene.call("_open_large_map")
	await _settle()
	_scene.call("_focus_large_map_for_controller")
	await _scan("map", _scene.get("_large_map_scrim"))
	await _navigate(_scene.get("_large_map_scrim"), _scene.get("_large_map_view").get("_close"), "map Close")
	await _capture("map")
	await _joy(JOY_BUTTON_B)
	_expect(not _scene.get("_large_map_scrim").visible, "Map B closes")
	await _load(_character_state())
	for tab: String in ["equipment", "magic", "skills"]:
		_scene.call("_open_character_overlay", tab)
		await _settle()
		_scene.call("_recover_controller_focus")
		await _scan("character_" + tab, _scene.get("_upgrade_scrim"))
		await _joy(JOY_BUTTON_B)
		_expect(not _scene.get("_upgrade_scrim").visible, "Character %s B closes" % tab)
	_scene.call("_open_grimoire_overlay")
	await _settle()
	_scene.call("_recover_controller_focus")
	_remember_grimoire_surface("grimoire")
	await _scan("grimoire", _scene.get("_grimoire_scrim"))
	await _capture("grimoire")
	await _joy(JOY_BUTTON_B)
	_expect(not _scene.get("_grimoire_scrim").visible, "Grimoire B closes")
	_scene.call("_open_grimoire_overlay")
	_scene.get("_grimoire_search_input").text = "a"
	_scene.call("_on_grimoire_search_text_changed", "a")
	await _settle()
	_scene.call("_recover_controller_focus")
	_remember_grimoire_surface("grimoire_search")
	await _scan("grimoire_search", _scene.get("_grimoire_scrim"))
	await _joy(JOY_BUTTON_B)

func _remember_grimoire_surface(label: String) -> void:
	_surface_states[label] = (_scene.get("_run_state") as Dictionary).duplicate(true)
	var selection: Dictionary = {}
	for field: String in ["_grimoire_selected_section", "_grimoire_selected_group", "_grimoire_selected_entry"]:
		selection[field] = _scene.get(field)
	_surface_views[label] = selection

func _menu_back_paths() -> void:
	for label: String in ["camp", "pause"]:
		await _load(_base_state() if label == "camp" else _combat_state())
		await _joy(JOY_BUTTON_B)
		_expect(_scene.get("_menu_scrim").visible, label + " controller opens the existing menu")
		await _capture("room_entry" if label == "camp" else "combat_back")
		await _joy(JOY_BUTTON_B)
		_expect(not _scene.get("_menu_scrim").visible, label + " B leaves menu")
		_rows.append({"screen": label, "reached": 1, "total": 1, "note": "entry/back only; internal focus owned by kb-01"})

func _skill_learn_focus_regression() -> void:
	var failures_before: int = _failures.size()
	var profile: Dictionary = Store.default_data()
	profile["level"] = 3
	profile["skill_ids"] = ["measured_breath"]
	profile["moltshards"] = 1
	Store.save_data(profile)
	_scene.set("_progression", profile)
	await _load(Run.new().create_new_run(FIXTURE_SEED, profile))
	_scene.call("_open_character_overlay", "skills")
	await _settle()
	var scope: Control = _scene.get("_upgrade_scrim")
	var tree: Control = _scene.get("_skill_tree_view")
	var node: Control = tree.call("node_for_skill", SKILL_LEARN_FOCUS_ID)
	var action: Button = tree.get("_detail_action")
	if await _navigate(scope, node, "Learn focus skill node"):
		await _joy(JOY_BUTTON_A)
		if await _navigate(scope, action, "Learn focus action"):
			# Traversing the graph can inspect another node before reaching Learn.
			var learned_id: String = str(tree.call("focused_skill_id"))
			node = tree.call("node_for_skill", learned_id)
			await _joy(JOY_BUTTON_A)
			_expect((Store.load_data().get("skill_ids", []) as Array).has(learned_id), "Controller Learn persists the selected skill")
			_expect(action.disabled, "Learn becomes disabled after its point is spent")
			_expect(_focus() == node, "Learning returns focus from the disabled action to its selected skill")
			await _capture("skill_learn_focus")
			await _joy(JOY_BUTTON_DPAD_RIGHT)
			var current: Control = _focus()
			_expect(_inside(scope, current) and current.is_visible_in_tree() and not (current is BaseButton and current.disabled), "Navigation after learning stays on an enabled Character control")
			_expect((Store.load_data().get("skill_ids", []) as Array).size() == 2, "Navigation after learning spends no second skill point")
	_scene.call("_close_card_upgrade_overlay")
	Store.save_data(Store.default_data())
	_scene.set("_progression", Store.default_data())
	var passed: bool = _failures.size() == failures_before
	_regression_checks.append({"name": "skill_learn_focus", "passed": passed})
	print("REGRESSION SKILL_LEARN_FOCUS: " + ("PASS" if passed else "FAIL"))

func _skill_reset_scope() -> void:
	var profile: Dictionary = Store.default_data()
	profile["level"] = 3
	profile["skill_ids"] = ["measured_breath"]
	profile["moltshards"] = 1
	Store.save_data(profile)
	_scene.set("_progression", profile)
	await _load(Run.new().create_new_run(FIXTURE_SEED, profile))
	_scene.call("_open_character_overlay", "skills")
	await _settle()
	_scene.call("_open_skill_reset_confirmation")
	await _settle()
	var confirmation: Control = _scene.get("_skill_reset_confirmation_scrim")
	_expect(confirmation != null, "Skills reset fixture can open confirmation")
	if confirmation != null:
		_expect(_scene.call("_controller_focus_scope") == confirmation, "Skills reset owns focus above the tree")
		await _scan("skills_reset_confirmation", confirmation)
		await _capture("skills_reset_confirmation")
		await _joy(JOY_BUTTON_B)
		_expect(not is_instance_valid(_scene.get("_skill_reset_confirmation_scrim")), "Skills reset B cancels without closing Character")
		_expect(_scene.get("_upgrade_scrim").visible, "Skills reset B restores Character")
	_scene.call("_close_card_upgrade_overlay")
	Store.save_data(Store.default_data())
	_scene.set("_progression", Store.default_data())

func _combat_state() -> Dictionary:
	var state: Dictionary = _base_state()
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8): row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	var hand: Array = ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"]
	var layout: Dictionary = {"name": "Controller sweep fixture", "coord": Vector2i(4, 3), "type": "combat", "grid": grid, "player_start": Vector2i(2, 4), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 140, "max_hp": 140, "block": 0}], "terrain": [], "traps": [], "loot": []}
	var combat: Dictionary = Combat.new().create_combat(FIXTURE_SEED, layout, {"hp": 24, "max_hp": 24, "deck_cards": hand.duplicate(), "relics": [], "hand_size": hand.size(), "heal_bonus": 0})
	combat["deck"]["hand"] = hand.duplicate()
	combat["deck"]["draw"] = ["quick_stab"]
	combat["deck"]["discard"] = ["patch_up"]
	combat["deck"]["burned"] = ["thunderline"]
	combat["current_actor"] = {"kind": "player", "key": "player"}
	state["mode"] = "combat"
	state["current_room"] = layout["coord"]
	state["current_room_layout"] = layout
	state["combat_state"] = combat
	return state

func _combat_screens() -> void:
	await _shortcut_tooltips()
	var engine := Run.new()
	var state: Dictionary = _base_state()
	for room: Dictionary in state["rooms"].values():
		if str(room.get("type")) != "combat": continue
		state["current_room"] = room["coord"]
		state["mode"] = Run.MODE_PRE_BATTLE
		state["pre_battle_pending"] = true
		state["pre_battle_travel_dir"] = Vector2i(1, 0)
		break
	await _load(state)
	_surface_states["pre_battle"] = state.duplicate(true)
	await _scan("pre_battle", _scene.get("_pre_battle_scrim"))
	var pre_battle: Control = _scene.get("_pre_battle_scrim")
	_expect(str(_scene.get("_run_state")["mode"]) == Run.MODE_PRE_BATTLE, "Pre-battle B fixture is committed to the fight")
	_expect(_existing_back_button(pre_battle) == null, "Committed pre-battle fixture has no existing Back/Leave/Cancel control")
	await _assert_b_noop(_scene, pre_battle, "pre_battle_committed")
	await _load(_combat_state())
	await _joy(JOY_BUTTON_X)
	if str(_scene.get("_controller_region")) != "hand": await _joy(JOY_BUTTON_X)
	var seen: Dictionary = {}
	for index: int in range(5):
		seen[_scene.get("_controller_hand_index")] = true
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	_rows.append({"screen": "combat_hand", "reached": seen.size(), "total": 5})
	_expect(seen.size() == 5, "Every hand card is reachable by D-pad")
	var activated: int = 0
	for index: int in range(5):
		await _load(_combat_state())
		if str(_scene.get("_controller_region")) != "hand": await _joy(JOY_BUTTON_X)
		for step: int in range(5):
			if int(_scene.get("_controller_hand_index")) == index: break
			await _joy(JOY_BUTTON_DPAD_RIGHT)
		await _joy(JOY_BUTTON_A)
		var selected: bool = int(_scene.get("_selected_card_index")) == index or bool(_scene.get("_animation_lock")) or _scene.get("_combat_state")["deck"]["hand"].size() < 5
		_expect(selected, "A activates hand card %d" % index)
		if selected: activated += 1
		await _wait_unlocked()
	_pressed_rows.append({"screen": "combat_hand", "activated": activated, "total": 5})
	await _load(_combat_state())
	if str(_scene.get("_controller_region")) != "hand": await _joy(JOY_BUTTON_X)
	# Return through the real shoulder path before selecting the printed action.
	for index: int in range(5):
		if int(_scene.get("_controller_hand_index")) == 0: break
		await _joy(JOY_BUTTON_RIGHT_SHOULDER)
	await _joy(JOY_BUTTON_A)
	_expect(int(_scene.get("_selected_card_index")) == 0, "Combat A selects the focused card")
	await _motion(JOY_AXIS_LEFT_X, 0.8)
	await _motion(JOY_AXIS_LEFT_X, 0.0)
	await _joy(JOY_BUTTON_B)
	_expect(int(_scene.get("_selected_card_index")) < 0, "Combat B cancels card targeting")
	# Commit a real printed attack at the board target, then verify the card and
	# enemy state rather than relying only on delivery of an input signal.
	await _load(_combat_state())
	if str(_scene.get("_controller_region")) != "hand": await _joy(JOY_BUTTON_X)
	for step: int in range(5):
		if int(_scene.get("_controller_hand_index")) == 0: break
		await _joy(JOY_BUTTON_DPAD_RIGHT)
	await _joy(JOY_BUTTON_A)
	await _joy(JOY_BUTTON_A)
	await _wait_unlocked()
	_expect(_scene.get("_combat_state")["deck"]["hand"].size() == 4, "Board A plays the selected printed card")
	_expect(int(_scene.get("_combat_state")["enemies"][0]["hp"]) < 140, "Board targeting damages the selected enemy")
	await _combat_hud()
	for kind: String in ["draw", "discard", "burn"]:
		_scene.call("_open_pile_view", kind)
		await _settle()
		_scene.call("_recover_controller_focus")
		await _scan("pile_" + kind, _scene.get("_pile_scrim"))
		await _joy(JOY_BUTTON_B)
		_expect(not _scene.get("_pile_scrim").visible, "Pile %s B closes" % kind)

func _shortcut_tooltips() -> void:
	await _load(_combat_state())
	var details: BaseButton = _scene.get("_enemy_intent_toggle_button")
	for modality: String in ["controller", "pointer", "controller", "pointer"]:
		for family: String in [Router.FAMILY_XBOX, Router.FAMILY_STEAM_DECK]:
			_router.call("set_forced_state_for_test", modality, family)
			await _settle()
			var controller: bool = modality == "controller"
			var details_shortcut: String = "" if controller else " [I]"
			var map_tooltip: String = "Map" if controller else "Map [M]"
			for enabled: bool in [true, false]:
				_scene.call("_set_show_all_enemy_intents", enabled)
				var body: String = "Hide full plans" if enabled else "Show every enemy's full plan"
				_expect(details.tooltip_text == body + details_shortcut, "Details tooltip follows %s/%s in both states" % [modality, family])
				_expect(bool(details.get("_key").visible) == not controller, "Details preserves its existing key visibility")
				if controller:
					_scene.call("_controller_set_focus_candidate", _scene.call("_controller_candidate_for_control", details), true)
					await _settle()
					_expect(str(_scene.get("_controller_focus_candidate").get("detail", "")) == details.tooltip_text, "Controller focus receives the device-aware Details tooltip")
					if not enabled: await _capture("details_tooltip")
			for control: Control in [_scene.get("mini_map_overlay"), _scene.get("_section_map_hud_button")]:
				_expect(control.tooltip_text == map_tooltip, "Map tooltip follows %s/%s" % [modality, family])
	_router.call("set_forced_state_for_test", "controller", Router.FAMILY_XBOX)
	_rows.append({"screen": "shortcut_tooltips", "reached": SHORTCUT_TOOLTIP_CASES, "total": SHORTCUT_TOOLTIP_CASES})

func _legacy_room_state() -> Dictionary:
	var engine := Run.new()
	var state: Dictionary = engine.create_new_run(FIXTURE_SEED, Store.default_data(), false)
	var room: Dictionary = engine.room_metadata(state, state["current_room"])
	state["current_room_layout"] = engine.call("_display_layout_for_room", FIXTURE_SEED, room, Vector2i(1, 0))
	return state

func _room_entry() -> void:
	await _load(_legacy_room_state())
	var candidates: Array = _scene.call("_controller_navigation_candidates")
	var exits: Dictionary = _scene.get("_exit_destinations_by_tile")
	var doors: Array = candidates.filter(func(candidate: Dictionary) -> bool: return exits.has(candidate.get("tile", Vector2i(-1, -1))))
	var reached: int = 0
	_expect(not doors.is_empty(), "Legacy room fixture exposes its actual doors")
	for candidate: Dictionary in doors:
		if await _cursor_to_key(str(candidate["key"]), "room entry"): reached += 1
	_rows.append({"screen": "room_entry", "reached": reached, "total": doors.size()})
	if not doors.is_empty():
		await _joy(JOY_BUTTON_B)
		_expect(_scene.get("_menu_scrim").visible, "Room idle B opens existing menu")
		await _capture("room_entry")
		await _joy(JOY_BUTTON_B)
	var activated: int = 0
	for door: Dictionary in doors:
		await _load(_legacy_room_state())
		await _cursor_to_key(str(door["key"]), "room door activation")
		var before: Vector2i = _scene.get("_run_state")["current_room"]
		await _joy(JOY_BUTTON_A)
		await _wait_unlocked()
		var entered: bool = _scene.get("_run_state")["current_room"] != before or _scene.get("_pre_battle_scrim").visible
		_expect(entered, "Room A enters the cursor's door or its pre-battle decision")
		if entered: activated += 1
	_pressed_rows.append({"screen": "room_entry", "activated": activated, "total": doors.size()})

func _tutorial_navigation_regression() -> void:
	var tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
	var scenario = preload("res://scripts/guided_combat_scenario.gd")
	var profile: Dictionary = Store.default_data()
	profile[tutorial.PROGRESSION_KEY] = tutorial.default_state()
	Store.save_data(profile)
	var state: Dictionary = scenario.mark_run_eligible(_combat_state())
	state["progression"] = profile
	state["combat_state"] = scenario.prepare_for_run(state, state["combat_state"])
	_scene.set("_progression", profile)
	await _load(state)
	var prompt: Control = _scene.get("_contextual_combat_prompt")
	var skip: Button = _button_text(prompt, "Skip Tutorial")
	_expect(skip != null, "Guided combat exposes its existing Skip Tutorial action")
	if skip == null: return
	var controls: Array[Control]
	controls.assign(_scene.call("_controller_header_focus_controls"))
	_expect(controls.has(skip), "Controller navigation includes Skip Tutorial during the forced action")
	if not controls.has(skip): return
	await _cursor_to_key("control:%d" % skip.get_instance_id(), "Skip Tutorial")
	await _capture("tutorial_skip")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect(not bool(_scene.call("_guided_tutorial_is_active")), "Controller A skips the tutorial through its existing action")
	_expect(not prompt.is_visible_in_tree(), "Skipping removes the tutorial callout")

func _combat_hud() -> void:
	await _load(_combat_state())
	if str(_scene.get("_controller_region")) == "hand": await _joy(JOY_BUTTON_X)
	var reached: int = 0
	var targets: Array[Control]
	targets.assign(_scene.call("_controller_header_focus_controls"))
	var pass_control: Control = _scene.get("_pass_preview_overlay").find_child("PassPreviewChip", true, false)
	for target: Control in targets:
		var key: String = "control:%d" % target.get_instance_id()
		var candidates: Array = _scene.call("_controller_navigation_candidates")
		_expect(candidates.any(func(candidate: Dictionary) -> bool: return candidate.get("key") == key), "Combat cursor includes mouse control " + str(target.name))
		if await _cursor_to_key(key, "combat HUD " + str(target.name)):
			reached += 1
			var detail: String = str(_scene.get("_controller_focus_candidate").get("detail", ""))
			if not target.tooltip_text.is_empty(): _expect(not detail.is_empty(), "Combat HUD exposes the existing detail text")
	_rows.append({"screen": "combat_hud", "reached": reached, "total": targets.size()})
	var opened: int = 0
	for property: String in ["_section_map_hud_button", "loadout_button", "grimoire_button", "menu_button"]:
		var control: BaseButton = _scene.get(property)
		if not await _cursor_to_key("control:%d" % control.get_instance_id(), "Combat " + property): continue
		var pressed: Array = []
		control.pressed.connect(func() -> void: pressed.append(true), CONNECT_ONE_SHOT)
		await _joy(JOY_BUTTON_A)
		_expect(not pressed.is_empty(), "A opens combat header " + property)
		if not pressed.is_empty(): opened += 1
		for back: int in range(3):
			if not bool(_scene.call("_controller_modal_visible")): break
			await _joy(JOY_BUTTON_B)
		_expect(not bool(_scene.call("_controller_modal_visible")), "B leaves combat header " + property)
	_pressed_rows.append({"screen": "combat_header", "activated": opened, "total": 4})
	pass_control = _scene.get("_pass_preview_overlay").find_child("PassPreviewChip", true, false)
	# Routed A must open the pile, not leave the event on a passive Control.
	for property: String in ["draw_pile", "discard_pile"]:
		var control: Control = _scene.get(property)
		for visit: int in range(2):
			if not await _cursor_to_key("control:%d" % control.get_instance_id(), property): continue
			await _capture("combat_hud")
			await _joy(JOY_BUTTON_A)
			await _settle()
			var pile: Control = _scene.get("_pile_scrim")
			_expect(pile.visible, property + " A opens pile viewer")
			_expect(_inside(pile, _focus()), property + " owns focus on first and cached open")
			await _capture("pile_focus")
			await _joy(JOY_BUTTON_B)
			_expect(not pile.visible, property + " B closes pile viewer")
	var details: Button = _scene.get("_enemy_intent_toggle_button")
	var original_details: bool = bool(_scene.get("_show_all_enemy_intents"))
	if await _cursor_to_key("control:%d" % details.get_instance_id(), "Details activation"):
		await _joy(JOY_BUTTON_A)
		_expect(bool(_scene.get("_show_all_enemy_intents")) != original_details, "Controller A toggles Details through its toggled signal")
		await _capture("combat_details")
		await _joy(JOY_BUTTON_A)
		_expect(bool(_scene.get("_show_all_enemy_intents")) == original_details, "Controller A toggles Details back")
	if is_instance_valid(pass_control):
		if await _cursor_to_key("control:%d" % pass_control.get_instance_id(), "Pass"):
			var pressed: Array = []
			pass_control.pressed.connect(func() -> void: pressed.append(true), CONNECT_ONE_SHOT)
			await _joy(JOY_BUTTON_A)
			_expect(not pressed.is_empty(), "Cursor A presses Pass")
			var deadline: int = Time.get_ticks_msec() + READY_TIMEOUT_MSEC
			while bool(_scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline: await process_frame
			_expect(not bool(_scene.get("_animation_lock")), "Pass returns input after the enemy phase")

func _hud_rebuild_regression() -> void:
	var failures_before: int = _failures.size()
	await _load(_combat_state())
	var pass_control: Control = _scene.get("_pass_preview_overlay").find_child("PassPreviewChip", true, false)
	await _cursor_to_key("control:%d" % pass_control.get_instance_id(), "Pass rebuild regression")
	await _joy(JOY_BUTTON_A)
	await _wait_unlocked()
	await _settle()
	var replacement: Control = _scene.get("_pass_preview_overlay").find_child("PassPreviewChip", true, false)
	var candidate: Dictionary = _scene.get("_controller_focus_candidate")
	_expect(is_instance_valid(candidate.get("control")) and candidate.get("control") == replacement, "Pass focus follows its replacement after the next turn")
	var passes: Array = []
	replacement.pressed.connect(func() -> void: passes.append(true), CONNECT_ONE_SHOT)
	await _joy(JOY_BUTTON_A)
	await _wait_unlocked()
	_expect(passes.size() == 1, "A again activates the rebuilt Pass without moving")
	var portrait_state: Dictionary = _combat_state()
	portrait_state["combat_state"]["enemies"][0]["pos"] = HUD_REBUILD_ENEMY_POSITION
	portrait_state["current_room_layout"]["enemies"][0]["pos"] = HUD_REBUILD_ENEMY_POSITION
	await _load(portrait_state)
	var portraits: Array[Control]
	portraits.assign(preload("res://scripts/turn_order_slots.gd").controller_controls(_scene))
	_expect(not portraits.is_empty(), "Portrait rebuild fixture has a turn-order portrait")
	if not portraits.is_empty():
		var portrait: Control = portraits.filter(func(control: Control) -> bool: return control.has_meta("turn_order_actor_key")).back()
		var actor: String = str(portrait.get_meta("turn_order_actor_key"))
		await _cursor_to_key("control:%d" % portrait.get_instance_id(), "Portrait rebuild regression")
		await _joy(JOY_BUTTON_Y)
		await _wait_unlocked()
		await _settle()
		candidate = _scene.get("_controller_focus_candidate")
		var focused: Variant = candidate.get("control")
		_expect(is_instance_valid(focused) and str(focused.get_meta("turn_order_actor_key", "")) == actor, "Y preserves the focused unit's replacement portrait")
		await _joy(JOY_BUTTON_DPAD_RIGHT)
		candidate = _scene.get("_controller_focus_candidate")
		_expect(not candidate.has("control") or is_instance_valid(candidate["control"]), "Moving after portrait rebuild keeps a live candidate")
	# A removed portrait uses its prior rail position to choose the nearest survivor.
	var removed_candidate: Dictionary = (_scene.get("_controller_focus_candidate") as Dictionary).duplicate()
	portraits.assign(preload("res://scripts/turn_order_slots.gd").controller_controls(_scene))
	if portraits.size() > 1:
		var removed: Control = portraits.back()
		removed_candidate = _scene.call("_controller_candidate_for_control", removed)
		_scene.call("_controller_set_focus_candidate", removed_candidate, true)
		var removed_actor: String = str(removed.get_meta("turn_order_actor_key"))
		for portrait: Control in portraits:
			if str(portrait.get_meta("turn_order_actor_key")) == removed_actor: portrait.free()
		portraits.assign(preload("res://scripts/turn_order_slots.gd").controller_controls(_scene))
		_expect(not portraits.is_empty(), "The removed-unit fixture retains a surviving portrait")
		_scene.call("_refresh_controller_interface")
		candidate = _scene.get("_controller_focus_candidate")
		_expect(not portraits.is_empty() and candidate.get("control") == portraits.back(), "A removed unit's portrait falls back to the nearest surviving portrait")
	await _load(_combat_state())
	var obsolete := Button.new()
	obsolete.size = STALE_CONTROL_TEST_SIZE
	_scene.add_child(obsolete)
	candidate = _scene.call("_controller_candidate_for_control", obsolete)
	_scene.call("_controller_set_focus_candidate", candidate, true)
	obsolete.free()
	# Keep the stale reference until A; a physics tick must not repair it first.
	_scene.set_physics_process(false)
	var before_state: Dictionary = (_scene.get("_combat_state") as Dictionary).duplicate(true)
	var cues: Array[String]
	var bank: Node = _scene.get("_sfx_bank")
	var on_cue: Callable = func(id: String, _result: String) -> void: cues.append(id)
	bank.connect("cue_requested", on_cue)
	var feedback: Node = root.get_node("CursorFeedback")
	var before_feedback: Dictionary = feedback.call("feedback_counts")
	await _joy(JOY_BUTTON_A)
	bank.disconnect("cue_requested", on_cue)
	candidate = _scene.get("_controller_focus_candidate")
	_expect(candidate.get("tile") == _scene.get("_combat_state")["player"]["pos"], "An unrecognized freed candidate recovers the combat default focus")
	_expect(_scene.get("_combat_state") == before_state, "Recovering an invalid candidate does not activate its replacement")
	_expect(cues.is_empty() and feedback.call("feedback_counts") == before_feedback, "Recovering an invalid candidate requests no sound")
	_scene.set_physics_process(true)
	_regression_result("HUD_REBUILD", failures_before)

func _analog_volume_regression() -> void:
	var failures_before: int = _failures.size()
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var panel: Control = preload("res://scripts/settings_panel.gd").new()
	_viewport.add_child(panel)
	await _settle()
	var analog: Node = panel.get_node_or_null("ControllerGuiNavigation")
	if analog != null: analog.set_process(false)
	for key: String in ["master_volume", "music_volume", "sfx_volume"]:
		var slider: HSlider = panel.get("_controls")[key]["slider"]
		slider.grab_focus()
		slider.value = ANALOG_TEST_START_VOLUME
		for value: float in HOLD_JITTER_SAMPLES: _send_motion(JOY_AXIS_LEFT_X, value)
		_expect(is_equal_approx(slider.value, 0.55), key + " jitter hold applies exactly one step")
		_send_motion(JOY_AXIS_LEFT_X, 0.0)
		slider.value = ANALOG_TEST_START_VOLUME
		_send_motion(JOY_AXIS_LEFT_X, 0.70)
		# Deterministic elapsed time, with real joypad samples.
		if analog != null:
			for tick: int in range(ANALOG_TEST_BEFORE_REPEAT_TICKS): analog.call("_process", ANALOG_TEST_TICK_SECONDS)
		_expect(is_equal_approx(slider.value, 0.55), key + " does not repeat before 0.40s")
		if analog != null:
			analog.call("_process", ANALOG_TEST_TICK_SECONDS)
		_expect(is_equal_approx(slider.value, 0.60), key + " first repeat occurs at 0.40s")
		if analog != null:
			for tick: int in range(ANALOG_TEST_HOLD_TICKS - ANALOG_TEST_BEFORE_REPEAT_TICKS - 1): analog.call("_process", ANALOG_TEST_TICK_SECONDS)
		_expect(is_equal_approx(slider.value, 0.80), key + " 0.95s hold applies 1 + 5 steps")
		_expect(is_equal_approx(float(Settings.load_settings()[key]), 0.80), key + " persists exactly the stepped volume")
		_send_motion(JOY_AXIS_LEFT_X, 0.30)
		_send_motion(JOY_AXIS_LEFT_X, 0.70)
		_expect(is_equal_approx(slider.value, 0.80), key + " stays latched at the release boundary")
		_send_motion(JOY_AXIS_LEFT_X, ANALOG_TEST_NEUTRAL)
		_send_motion(JOY_AXIS_LEFT_X, -0.70)
		_expect(is_equal_approx(slider.value, 0.75), key + " neutral rearms the opposite direction")
		_send_motion(JOY_AXIS_LEFT_X, 0.0)
	var master: HSlider = panel.get("_controls")["master_volume"]["slider"]
	master.grab_focus()
	master.value = ANALOG_TEST_START_VOLUME
	_router.call("clear_forced_state_for_test")
	_router.call("set_modality", "pointer")
	_send_motion(JOY_AXIS_LEFT_X, 0.70)
	_expect(bool(_router.call("using_controller")), "Analog slider input records controller modality")
	_router.call("set_modality", "pointer")
	if analog != null: analog.call("_process", 0.95)
	_expect(is_equal_approx(master.value, 0.55), "Pointer handoff pauses a held analog volume repeat")
	_send_motion(JOY_AXIS_LEFT_X, 0.0)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	# Native GUI focus uses the same timed rule on each axis, preserving its D-pad route.
	var focus_steps: Array = []
	var on_focus: Callable = func(control: Control) -> void: focus_steps.append(control.get_instance_id())
	_viewport.gui_focus_changed.connect(on_focus)
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var start: Control = panel.get("_controls")["display_mode"]
		var button: int = JOY_BUTTON_DPAD_RIGHT if axis == JOY_AXIS_LEFT_X else JOY_BUTTON_DPAD_DOWN
		start.grab_focus()
		focus_steps.clear()
		await _joy(button)
		var first_trace: Array = focus_steps.duplicate()
		for step: int in range(5): await _joy(button)
		var full_trace: Array = focus_steps.duplicate()
		start.grab_focus()
		focus_steps.clear()
		for value: float in HOLD_JITTER_SAMPLES: _send_motion(axis, value)
		_expect(focus_steps == first_trace, "Native GUI axis %d jitter follows one existing D-pad edge" % axis)
		if analog != null:
			for tick: int in range(ANALOG_TEST_HOLD_TICKS): analog.call("_process", ANALOG_TEST_TICK_SECONDS)
		_expect(focus_steps == full_trace, "Native GUI axis %d 0.95s hold follows six existing D-pad edges" % axis)
		_send_motion(axis, 0.0)
	_viewport.gui_focus_changed.disconnect(on_focus)
	var embedded_before: bool = _viewport.gui_embed_subwindows
	_viewport.gui_embed_subwindows = true
	var option: OptionButton = panel.get("_controls")["display_mode"]
	var popup: PopupMenu = option.get_popup()
	var popup_steps: Array = []
	popup.id_focused.connect(func(id: int) -> void: popup_steps.append(id))
	option.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(popup.visible, "Native option popup opens for analog selection proof")
	var popup_analog: Node = popup.get_node_or_null("ControllerOptionNavigation")
	if popup_analog != null: popup_analog.set_process(false)
	var initial_item: int = popup.get_focused_item()
	popup_steps.clear()
	for value: float in HOLD_JITTER_SAMPLES:
		var motion := InputEventJoypadMotion.new()
		motion.axis = JOY_AXIS_LEFT_Y
		motion.axis_value = value
		Input.parse_input_event(motion)
		popup.push_input(motion, true)
	_expect(popup_steps.size() == 1 and popup.get_focused_item() == posmod(initial_item + 1, popup.item_count), "Option popup analog jitter advances one real option")
	if popup_analog != null:
		for tick: int in range(ANALOG_TEST_HOLD_TICKS): popup_analog.call("_process", ANALOG_TEST_TICK_SECONDS)
	_expect(popup_steps.size() == 6 and popup.get_focused_item() == posmod(initial_item + 6, popup.item_count), "Option popup 0.95s hold advances exactly six options")
	popup.hide()
	_expect(InputMap.action_get_events(&"ui_down").any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y), "Closing a popup restores its analog action bindings")
	popup.popup()
	_expect(not InputMap.action_get_events(&"ui_down").any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y), "An open option popup reserves only its analog bindings")
	_expect(InputMap.action_get_events(&"ui_down").any(func(event: InputEvent) -> bool: return event is InputEventJoypadButton and event.button_index == JOY_BUTTON_DPAD_DOWN), "An open option popup preserves its native D-pad mapping")
	panel.free()
	_expect(InputMap.action_get_events(&"ui_down").any(func(event: InputEvent) -> bool: return event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y), "Freeing an open option popup restores its analog bindings")
	_viewport.gui_embed_subwindows = embedded_before
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
	_regression_result("ANALOG_VOLUME", failures_before)
	await _analog_selection_regression()

func _analog_selection_regression() -> void:
	var failures_before: int = _failures.size()
	# Exercise the existing vector repeat contract at the director's new times.
	var navigation = preload("res://scripts/controller_navigation.gd")
	for stick: Vector2 in [Vector2(0.70, 0.0), Vector2(0.0, 0.70)]:
		var held: Dictionary = navigation.repeat_step(stick, Vector2.ZERO, 0, 0)
		var steps: int = 1
		for now: int in range(10, 951, 10):
			held = navigation.repeat_step(stick, held["direction"], held["next_repeat_msec"], now)
			if held["step"] != Vector2.ZERO: steps += 1
			if now == 390: _expect(steps == 1, "Combat selection does not repeat before 0.40s")
		_expect(steps == 6, "Combat selection holds repeat 1 + 5 times on either axis")
	preload("res://tests/suites/controller_input_suite.gd").run(_expect)
	await _load(EventFixture.fixture("hanged_knight", true))
	var event_view: Control = _scene.get("_event_view")
	await _settle()
	event_view.set_process(false)
	await _assert_selection_repeat(event_view, JOY_AXIS_LEFT_Y, "Event choices")
	event_view.set_process(true)
	_scene.process_mode = Node.PROCESS_MODE_DISABLED
	var chronicle: Control = preload("res://scripts/chronicle_panel.gd").new()
	_viewport.add_child(chronicle)
	chronicle.call("open", preload("res://tests/chronicle_probe.gd").seeded_profile(), false)
	await _settle()
	chronicle.set_process(false)
	await _assert_selection_repeat(chronicle, JOY_AXIS_LEFT_Y, "Chronicle records")
	for axis: int in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
		var detail: Control = chronicle.get("_detail")
		var targets: Array[Control] = _controls(detail)
		_expect(targets.size() >= 2, "Chronicle fixture exposes navigable detail controls")
		if not targets.is_empty():
			targets[0].grab_focus()
			await _assert_selection_repeat(chronicle, axis, "Chronicle detail")
	chronicle.free()
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
	_regression_result("ANALOG_SELECTION", failures_before)

func _assert_selection_repeat(surface: Control, axis: int, label: String) -> void:
	var selections: Array = []
	var on_focus: Callable = func(_control: Control) -> void: selections.append(true)
	_viewport.gui_focus_changed.connect(on_focus)
	for value: float in HOLD_JITTER_SAMPLES: _send_motion(axis, value)
	_expect(selections.size() == 1, "%s axis %d jitter selects once" % [label, axis])
	for tick: int in range(ANALOG_TEST_HOLD_TICKS): surface.call("_process", ANALOG_TEST_TICK_SECONDS)
	_expect(selections.size() == 6, "%s axis %d 0.95s hold selects 1 + 5 times" % [label, axis])
	_router.call("set_forced_state_for_test", "pointer", "xbox")
	surface.call("_process", 0.95)
	_expect(selections.size() == 6, label + " pointer handoff pauses analog selection repeats")
	_send_motion(axis, 0.0)
	_router.call("set_forced_state_for_test", "controller", "xbox")
	_viewport.gui_focus_changed.disconnect(on_focus)

func _regression_result(label: String, failures_before: int) -> void:
	var passed: bool = _failures.size() == failures_before
	_regression_checks.append({"name": label, "passed": passed})
	print("REGRESSION %s: %s" % [label, "PASS" if passed else "FAIL"])

func _cursor_to_key(key: String, context: String) -> bool:
	if str(_scene.get("_controller_region")) == "hand": await _joy(JOY_BUTTON_X)
	for step: int in range(NAVIGATION_LIMIT):
		var candidates: Array = _scene.call("_controller_navigation_candidates")
		var matching: Array = candidates.filter(func(candidate: Dictionary) -> bool: return str(candidate.get("key")) == key)
		if matching.is_empty():
			_expect(false, context + " is in the cursor's reachable controls")
			return false
		if str(_scene.get("_controller_focus_candidate").get("key", "")) == key:
			_send_motion(JOY_AXIS_LEFT_X, 0.0)
			_send_motion(JOY_AXIS_LEFT_Y, 0.0)
			await _settle()
			return true
		var origin: Vector2 = _scene.get("_controller_virtual_board_position")
		var point: Vector2 = matching[0]["point"]
		if not is_finite(origin.x):
			await _joy(JOY_BUTTON_DPAD_UP)
			continue
		var delta: Vector2 = point - origin
		var direction: Vector2 = delta.normalized() * minf(0.9, maxf(0.5, delta.length() / 100.0))
		_send_motion(JOY_AXIS_LEFT_X, direction.x)
		_send_motion(JOY_AXIS_LEFT_Y, direction.y)
		_scene.call("_controller_process_board_cursor", CURSOR_TICK_SECONDS)
		await process_frame
	_send_motion(JOY_AXIS_LEFT_X, 0.0)
	_send_motion(JOY_AXIS_LEFT_Y, 0.0)
	_expect(false, context + " is reachable by real stick motion")
	return false

func _send_motion(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)
	_viewport.push_input(event, true)

func _reward_focus_regression() -> void:
	var state: Dictionary = _base_state()
	state["mode"] = "reward"
	state["pending_reward"] = {"cards": ["quick_stab"], "heal_amount": Run.REWARD_HEAL, "ember_amount": 0}
	await _load(state)
	if _focus() != null: _focus().release_focus()
	var live: Dictionary = _scene.get("_run_state")
	live["pending_reward"]["intro_pending"] = true
	_scene.set("_reward_reveal_pending", true)
	_scene.set("_animation_lock", true)
	_scene.call("_finish_reward_intro")
	await _settle()
	await _settle()
	_expect(_inside(_scene.get("_relic_choice_overlay"), _focus()), "Finishing the reward reveal establishes controller focus without another input")
	await _capture("reward_focus")

func _encounter_screens() -> void:
	var state: Dictionary = _base_state()
	state["mode"] = "reward"
	state["pending_reward"] = {"cards": ["quick_stab", "bone_dart", "sidestep_slash"], "heal_amount": Run.REWARD_HEAL, "ember_amount": 0}
	await _load(state)
	_surface_states["reward"] = state.duplicate(true)
	await _scan("reward", _scene.get("_relic_choice_overlay"))
	await _load(EventFixture.fixture("hanged_knight", true))
	await create_timer(0.3).timeout
	var view: Control = _scene.get("_event_view")
	await _scan("event", view)
	_expect(str(view.get("page")) == "choices", "Event B fixture still requires a choice")
	var choices: Array[String]
	var on_choice: Callable = func(choice_id: String) -> void: choices.append(choice_id)
	view.connect("choice_requested", on_choice)
	await _assert_b_noop(_scene, view, "event_before_choice")
	view.disconnect("choice_requested", on_choice)
	_expect(choices.is_empty(), "Event B cannot request a choice or continue before choosing")
	await _joy(JOY_BUTTON_A)
	await create_timer(0.3).timeout
	await _scan("event_result", view)
	await _joy(JOY_BUTTON_B)
	_expect(str(_scene.get("_run_state")["mode"]) != "event", "Event result B continues")
	state = GraftFixture.fixture()
	await _load(state)
	view = _scene.get("_graftwright_view")
	await _scan("graftwright_intro", view)
	await _navigate(view, view.find_child("GraftBrowse", true, false), "Graftwright Browse")
	await _joy(JOY_BUTTON_A)
	await _scan("graftwright", view)
	await _navigate(view, view.find_child("ChooseSacrifice", true, false), "Graftwright sacrifice")
	await _joy(JOY_BUTTON_A)
	await _scan("graftwright_picker", view)
	await _joy(JOY_BUTTON_B)
	_expect(str(view.get("_picker_role")).is_empty(), "Graftwright B closes picker first")
	await _joy(JOY_BUTTON_B)
	_expect(str(_scene.get("_run_state")["mode"]) != "graftwright", "Graftwright B leaves")
	await _shop()
	HearthFixture.setup(_scene, 8, 180, true, false)
	await create_timer(0.7).timeout
	_scene.call("_recover_controller_focus")
	_surface_states["campfire"] = (_scene.get("_run_state") as Dictionary).duplicate(true)
	await _scan("campfire", _scene.get("_relic_choice_overlay"))
	HearthFixture.setup(_scene, 8, 180, true, true)
	await create_timer(0.7).timeout
	_scene.call("_recover_controller_focus")
	_surface_states["ember_hearth"] = (_scene.get("_run_state") as Dictionary).duplicate(true)
	await _scan("ember_hearth", _scene.get("_relic_choice_overlay"))

func _shop() -> void:
	var engine := Run.new()
	var state: Dictionary = _base_state()
	for room: Dictionary in state["rooms"].values():
		if str(room.get("merchant_kind", "")) != "scavenger" and str(room.get("type", "")) != "scavenger": continue
		room["revealed"] = true
		room["visited"] = true
		room["cleared"] = true
		room[Run.MERCHANT_STOCK_KEY] = ["grave_mortar", "boiled_leather", "crimson_draught"]
		state["current_room"] = room["coord"]
		state["current_room_layout"] = engine.call("_display_layout_for_room", FIXTURE_SEED, room, Vector2i(1, 0))
		break
	state["mode"] = "room"
	state["held_embers"] = FIXTURE_BUDGET
	state["unbanked_embers"] = FIXTURE_BUDGET
	state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	state["magic_inventory"] = ["spark_dart", "frostbolt"]
	state["attuned_magic_cards"] = ["spark_dart", "frostbolt", "grave_mortar"]
	state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	_surface_states["scavenger"] = state.duplicate(true)
	await _load(state)
	var shop: Control = _scene.get("_scavenger_shop_view")
	shop.call("_configure_focus_neighbors")
	var service: Control = shop.find_child("ScavengerPurge", true, false)
	_expect(shop.get("_mode_sell").find_valid_focus_neighbor(SIDE_RIGHT) == service, "Scavenger detail refresh keeps Sell connected to Purge")
	_expect(shop.get("_leave_button").find_valid_focus_neighbor(SIDE_LEFT) == service, "Scavenger detail refresh keeps Leave connected to Purge")
	await _scan("scavenger", shop)
	await _navigate(shop, shop.find_child("ScavengerPurge", true, false), "Scavenger Purge")
	await _capture("scavenger")
	_scene.call("_open_magic_purge", "scavenger")
	await _settle()
	var purge: Control = _scene.get("_magic_purge_overlay")
	if not is_instance_valid(purge):
		_expect(false, "Scavenger Purge opens")
		return
	await _scan("purge", purge)
	await _joy(JOY_BUTTON_A)
	await _settle()
	await _scan("purge_confirmation", purge.call("focus_scope"))
	await _joy(JOY_BUTTON_B)
	await _joy(JOY_BUTTON_B)
	_expect(not is_instance_valid(_scene.get("_magic_purge_overlay")), "Purge B cancels confirmation then list")
	await _navigate(shop, shop.get("_mode_sell"), "Scavenger Sell")
	await _joy(JOY_BUTTON_A)
	await _scan("scavenger_sell", shop)
	await _joy(JOY_BUTTON_B)
	_expect(not shop.visible, "Scavenger B returns to room")
	await _shop_unaffordable_card_navigation(state)

func _shop_unaffordable_card_navigation(source: Dictionary) -> void:
	var state: Dictionary = source.duplicate(true)
	state["held_embers"] = UNAFFORDABLE_SHOP_EMBERS
	state["unbanked_embers"] = UNAFFORDABLE_SHOP_EMBERS
	var room: Dictionary = state["rooms"][preload("res://scripts/section_map_graph.gd").key(state["current_room"])]
	room[Run.MERCHANT_STOCK_KEY] = [UNAFFORDABLE_SHOP_GEAR, "boiled_leather", "crimson_draught"]
	await _load(state)
	var shop: Control = _scene.get("_scavenger_shop_view")
	var offer: Control = shop.find_child("GearOffer_" + UNAFFORDABLE_SHOP_GEAR, true, false)
	if not await _navigate(shop, shop.get("_mode_buy"), "Unaffordable gear Browse"): return
	await _joy(JOY_BUTTON_A)
	if not await _navigate(shop, offer, "Unaffordable multi-card gear"): return
	await _joy(JOY_BUTTON_A)
	_expect(shop.get("_detail_action").disabled, "Unaffordable gear keeps Buy disabled")
	_expect(_focus() == shop.get("_detail_card_previous"), "A enters the existing card navigator when Buy is disabled")
	var previous: int = int(shop.get("_detail_card_index"))
	await _joy(JOY_BUTTON_A)
	_expect(int(shop.get("_detail_card_index")) != previous, "Controller A can inspect another granted card without changing wares")
	await _capture("shop_unaffordable")

func _recap_screen() -> void:
	var state: Dictionary = _base_state()
	state["mode"] = "defeat"
	await _load(state)
	var recap: Control = _scene.get("_run_end_recap")
	recap.skip_presentation()
	await _settle()
	_expect(_scene.call("_controller_focus_scope") == recap, "Recap owns focus above the hidden HUD")
	await _scan("run_end_recap", recap)
	await _capture("run_end_recap")
	var requested: Array = []
	recap.main_menu_pressed.connect(func() -> void: requested.append(true), CONNECT_ONE_SHOT)
	await _joy(JOY_BUTTON_B)
	_expect(not requested.is_empty(), "Recap B activates existing Main Menu action")
	if not _capture_screen.is_empty(): return
	var activated: int = 0
	for index: int in range(3):
		await _load(state)
		recap = _scene.get("_run_end_recap")
		recap.skip_presentation()
		await _settle()
		var controls: Array[Control] = _controls(recap)
		if index >= controls.size():
			_expect(false, "Recap action inventory is stable")
			continue
		var target: BaseButton = controls[index] as BaseButton
		var pressed: Array = []
		if not await _navigate(recap, target, "Recap action"): continue
		target.pressed.connect(func() -> void: pressed.append(true), CONNECT_ONE_SHOT)
		await _joy(JOY_BUTTON_A)
		_expect(not pressed.is_empty(), "Recap A presses its focused action")
		if not pressed.is_empty(): activated += 1
	_pressed_rows.append({"screen": "run_end_recap", "activated": activated, "total": 3})
	# New Run starts deferred scene preparation. Let it settle before replaying
	# another independent fixture or tearing down the run host.
	await _settle()

func _wait_unlocked() -> void:
	var deadline: int = Time.get_ticks_msec() + READY_TIMEOUT_MSEC
	while (bool(_scene.get("_animation_lock")) or bool(_scene.get("_reward_reveal_pending")) or bool(_scene.get("_loadout_acquisition_in_progress")) or bool(_scene.get("_campfire_choice_action_pending"))) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(Time.get_ticks_msec() < deadline, "Fixture releases its authored opening input lock")

func _activate_inventory() -> void:
	# Recreate the starting decision for every press. No activation is simulated
	# with pressed.emit(), direct callback calls, keyboard actions, or mouse input.
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
	for row: Dictionary in _rows.duplicate():
		var label: String = row["screen"]
		var args: PackedStringArray = OS.get_cmdline_user_args()
		if args.has("--activate-screen") and label != args[args.find("--activate-screen") + 1]: continue
		if label in ["combat_hand", "combat_hud", "room_entry", "run_end_recap", "camp", "pause", "skills_reset_confirmation"]: continue
		var scope: Control = await _restore_surface(label)
		if scope == null: continue
		var count: int = _controls(scope).size()
		if label.begins_with("grimoire"):
			_expect(count == int(row["total"]), label + " replay preserves the complete discovered catalog")
		var activated: int = 0
		var total: int = 0
		for index: int in range(count):
			print("Pressing %s %d/%d" % [label, index + 1, count])
			scope = await _restore_surface(label)
			var controls: Array[Control] = _controls(scope)
			if index >= controls.size():
				_expect(false, label + " replay inventory is stable")
				continue
			var target: Control = controls[index]
			if target is LineEdit: continue
			total += 1
			if not await _navigate(scope, target, label + " activation"): continue
			if target is BaseButton and target.disabled:
				total -= 1
				continue
			var target_name: String = str(target.name)
			var delivered: Array = []
			var before_state: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
			if target is Range:
				target.value_changed.connect(func(_value: float) -> void: delivered.append(true), CONNECT_ONE_SHOT)
			elif label.begins_with("event"):
				scope.choice_requested.connect(func(_choice: String) -> void: delivered.append(true), CONNECT_ONE_SHOT)
			elif target is BaseButton:
				target.pressed.connect(func() -> void: delivered.append(true), CONNECT_ONE_SHOT)
			elif target.has_signal("activated"):
				target.connect("activated", func() -> void: delivered.append(true), CONNECT_ONE_SHOT)
			else:
				target.gui_input.connect(func(event: InputEvent) -> void:
					if event.is_action_pressed("ui_accept"): delivered.append(true)
				)
			if target is Range:
				var value: float = target.value
				await _joy(JOY_BUTTON_DPAD_LEFT)
				_expect(is_equal_approx(target.value, maxf(target.min_value, value - target.step)), "Controller volume uses the existing single step")
				await _joy(JOY_BUTTON_DPAD_RIGHT)
			else:
				await _joy(JOY_BUTTON_A)
			if _scene.process_mode != Node.PROCESS_MODE_DISABLED: await _wait_unlocked()
			var changed: bool = before_state != (_scene.get("_run_state") as Dictionary)
			if not delivered.is_empty() or changed: activated += 1
			else: _expect(false, label + " A reaches the control handler: " + target_name)
			# Dismiss native OptionButton popups before rebuilding their owner.
			if is_instance_valid(target) and target is OptionButton and target.get_popup().visible:
				await _joy(JOY_BUTTON_B)
		_pressed_rows.append({"screen": label, "activated": activated, "total": total})
		print("ACTIVATION %s: %d/%d" % [label, activated, total])
	if is_instance_valid(_activation_menu):
		_activation_menu.queue_free()
		_activation_menu = null
	await _settle()

func _restore_surface(label: String) -> Control:
	if label in ["title", "title_resume", "title_replacement", "settings", "settings_confirmation", "new_run_setup"]:
		_scene.process_mode = Node.PROCESS_MODE_DISABLED
		if is_instance_valid(_activation_menu):
			_activation_menu.free()
		Store.clear_saved_run()
		Store.save_data(DepthFixture._profile(3, 1))
		Store._session_umbra_depth = 1
		if label in ["title_resume", "title_replacement"]: Store.save_run_state(_base_state())
		_activation_menu = load("res://scenes/main_menu.tscn").instantiate()
		_activation_menu.set_script(MenuFixture)
		_viewport.add_child(_activation_menu)
		await _settle()
		await _joy(JOY_BUTTON_DPAD_DOWN)
		if label in ["title", "title_resume"]: return _activation_menu.get_node("MenuColumn")
		if label == "title_replacement":
			_activation_menu.call("_on_start_button_pressed")
			await _settle()
			return _activation_menu.get("replacement_panel")
		if label == "new_run_setup":
			_activation_menu.call("_on_start_button_pressed")
			return _activation_menu.get("_new_descent_panel")
		_activation_menu.call("_on_settings_button_pressed")
		var panel: Control = _activation_menu.get("settings_panel")
		if label == "settings_confirmation": panel.call("_show_restore_confirmation")
		await _settle()
		return panel.get("_confirmation_panel") if label == "settings_confirmation" else panel
	if is_instance_valid(_activation_menu):
		_activation_menu.free()
		_activation_menu = null
	_scene.process_mode = Node.PROCESS_MODE_INHERIT
	Store.save_data(Store.default_data())
	_scene.set("_progression", Store.default_data())
	if label == "map" or label.begins_with("character_") or label.begins_with("grimoire"):
		var state: Dictionary = _character_state() if label.begins_with("character_") else _base_state()
		if label.begins_with("grimoire"):
			state = _surface_states[label].duplicate(true)
			var profile: Dictionary = state.get("progression", Store.default_data()).duplicate(true)
			Store.save_data(profile)
			_scene.set("_progression", profile)
		await _load(state)
		if label == "map":
			_scene.call("_open_large_map")
			await _settle()
			_scene.call("_focus_large_map_for_controller")
			return _scene.get("_large_map_scrim")
		if label.begins_with("grimoire"):
			for field: String in _surface_views[label]: _scene.set(field, _surface_views[label][field])
			_scene.call("_open_grimoire_overlay")
			if label == "grimoire_search":
				_scene.get("_grimoire_search_input").text = "a"
				_scene.call("_on_grimoire_search_text_changed", "a")
			await _settle()
			_scene.call("_recover_controller_focus")
			return _scene.get("_grimoire_scrim")
		_scene.call("_open_character_overlay", label.trim_prefix("character_"))
		await _settle()
		_scene.call("_recover_controller_focus")
		return _scene.get("_upgrade_scrim")
	if label == "pre_battle" or label == "reward":
		Store.clear_saved_run()
		await _load(_surface_states[label].duplicate(true))
		await _wait_unlocked()
		return _scene.get("_pre_battle_scrim" if label == "pre_battle" else "_relic_choice_overlay")
	if label.begins_with("pile_"):
		await _load(_combat_state())
		_scene.call("_open_pile_view", label.trim_prefix("pile_"))
		await _settle()
		_scene.call("_recover_controller_focus")
		return _scene.get("_pile_scrim")
	if label.begins_with("event"):
		var state: Dictionary = EventFixture.fixture("hanged_knight", true)
		if label == "event_result": state = Run.new().resolve_map_event(state, "cut")
		await _load(state)
		await create_timer(0.3).timeout
		return _scene.get("_event_view")
	if label.begins_with("graftwright"):
		await _load(GraftFixture.fixture())
		var view: Control = _scene.get("_graftwright_view")
		if label != "graftwright_intro": view.call("begin_work")
		if label == "graftwright_picker": view.call("open_picker", "donor")
		await _settle()
		return view
	if label in ["scavenger", "scavenger_sell", "purge", "purge_confirmation"]:
		_scene.get("_scavenger_shop_view").set("_room_coord", Vector2i(999, 999))
		await _load(_surface_states["scavenger"].duplicate(true))
		if label == "scavenger": return _scene.get("_scavenger_shop_view")
		if label == "scavenger_sell":
			var shop: Control = _scene.get("_scavenger_shop_view")
			await _navigate(shop, shop.get("_mode_sell"), "Sell fixture")
			await _joy(JOY_BUTTON_A)
			return shop
		_scene.call("_open_magic_purge", "scavenger")
		await _settle()
		var purge: Control = _scene.get("_magic_purge_overlay")
		if label == "purge_confirmation":
			await _joy(JOY_BUTTON_A)
			await _settle()
		return purge.call("focus_scope")
	if label in ["campfire", "ember_hearth"]:
		await _load(_surface_states[label].duplicate(true))
		await create_timer(0.7).timeout
		return _scene.get("_relic_choice_overlay")
	return null

func _focus() -> Control:
	return _viewport.gui_get_focus_owner()

func _inside(scope: Control, control: Control) -> bool:
	return scope != null and control != null and (scope == control or scope.is_ancestor_of(control))

func _controls(scope: Control) -> Array[Control]:
	var result: Array[Control]
	_collect(scope, result)
	return result

func _collect(node: Node, result: Array[Control]) -> void:
	if node == null: return
	if node is Control:
		var control := node as Control
		if not control.is_visible_in_tree(): return
		if control is BaseButton:
			if not control.disabled and (control.focus_mode != Control.FOCUS_NONE or control.mouse_filter != Control.MOUSE_FILTER_IGNORE): result.append(control)
		elif control.focus_mode == Control.FOCUS_ALL and not control is ScrollBar: result.append(control)
	for child: Node in node.get_children(): _collect(child, result)

func _scan(label: String, scope: Control) -> void:
	print("Scanning " + label)
	if scope == null or not scope.is_visible_in_tree():
		_expect(false, label + " surface is visible")
		return
	await _settle()
	var targets: Array[Control] = _controls(scope)
	var reached: int = 0
	for target: Control in targets:
		if not is_instance_valid(target) or (target is BaseButton and target.disabled): continue
		if await _navigate(scope, target, label): reached += 1
	_rows.append({"screen": label, "reached": reached, "total": targets.size(), "controls": targets.map(func(c: Control) -> String: return str(c.name))})

func _navigate(scope: Control, target: Control, context: String) -> bool:
	if target == null:
		_expect(false, context + " target exists")
		return false
	for step: int in range(NAVIGATION_LIMIT):
		var current: Control = _focus()
		if current == target:
			_expect(current.is_visible_in_tree() and current.modulate.a > 0.0, context + " focus is visible: " + str(current.name))
			return true
		if not _inside(scope, current):
			_expect(false, context + " initial focus belongs to screen; target=" + str(target.name))
			return false
		var route: Array = _route(scope, current, target)
		if route.is_empty():
			_expect(false, context + " unreachable " + str(scope.get_path_to(target)) + " rect=" + str(target.get_global_rect()) + " disabled=" + str(target.get("disabled")))
			return false
		await _joy(int(route[0]))
		if _focus() == current:
			_expect(false, context + " directional input trapped at " + str(current.name) + " toward " + str(target.name))
			return false
	_expect(false, context + " navigation exceeded bound: " + str(target.name))
	return false

func _route(scope: Control, start: Control, target: Control) -> Array:
	var pending: Array[Control]
	pending.append(start)
	var paths: Dictionary = {start.get_instance_id(): []}
	while not pending.is_empty():
		var current: Control = pending.pop_front()
		for edge: Array in EDGES:
			var next: Control = current.find_valid_focus_neighbor(edge[0])
			if not _inside(scope, next) or paths.has(next.get_instance_id()): continue
			var path: Array = paths[current.get_instance_id()].duplicate()
			path.append(edge[1])
			if next == target: return path
			paths[next.get_instance_id()] = path
			pending.append(next)
	return []

func _existing_back_button(scope: Control) -> Button:
	for control: Control in _controls(scope):
		if not control is Button: continue
		var caption: String = control.text.strip_edges().to_lower()
		for action: String in ["back", "leave", "cancel", "close", "return"]:
			if caption == action or caption.begins_with(action + " "): return control
	return null

func _back_state(host: Control) -> Dictionary:
	var snapshot: Dictionary = {"progression": (host.get("_progression") as Dictionary).duplicate(true), "requested_scene": host.get("requested_scene")}
	if host == _scene:
		snapshot["run_state"] = (host.get("_run_state") as Dictionary).duplicate(true)
	else:
		snapshot["loading_run"] = host.get("_loading_run")
		snapshot["replacement_confirmation_open"] = host.get("_replacement_confirmation_open")
	return snapshot

func _assert_b_noop(host: Control, scope: Control, label: String) -> void:
	await _settle()
	var state_before: Dictionary = _back_state(host)
	var focus_before: Control = _focus()
	var controls_before: Array = _controls(host).map(func(control: Control) -> int: return control.get_instance_id())
	var feedback: Node = root.get_node("CursorFeedback")
	var feedback_before: Dictionary = feedback.call("feedback_counts")
	var cues: Array[String]
	var on_cue: Callable = func(cue_id: String, _result: String) -> void: cues.append(cue_id)
	var bank: Node = host.get("_sfx_bank") as Node if host == _scene else null
	if bank != null: bank.connect("cue_requested", on_cue)
	await _joy(JOY_BUTTON_B)
	if bank != null: bank.disconnect("cue_requested", on_cue)
	var controls_after: Array = _controls(host).map(func(control: Control) -> int: return control.get_instance_id())
	var unchanged: bool = _back_state(host) == state_before
	var same_focus: bool = _focus() == focus_before and _inside(scope, _focus())
	var same_screen: bool = scope.is_visible_in_tree() and controls_after == controls_before
	if host == _scene: same_screen = same_screen and host.call("_controller_focus_scope") == scope
	var silent: bool = cues.is_empty() and feedback.call("feedback_counts") == feedback_before
	_expect(unchanged, label + " B leaves run/progression and destination unchanged")
	_expect(same_focus, label + " B preserves focus")
	_expect(same_screen, label + " B leaves the existing screen and controls open")
	_expect(silent, label + " B requests no sound or feedback cue: " + str(cues))
	_back_checks.append({"screen": label, "state_unchanged": unchanged, "focus_preserved": same_focus, "screen_preserved": same_screen, "silent": silent, "passed": unchanged and same_focus and same_screen and silent})

func _button_text(scope: Control, text: String) -> Button:
	for control: Control in _controls(scope):
		if control is Button and control.text == text: return control
	return null

func _joy(button: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	_viewport.push_input(event, true)
	await _settle()
	event = event.duplicate()
	event.pressed = false
	Input.parse_input_event(event)
	_viewport.push_input(event, true)
	await process_frame

func _motion(axis: int, value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.axis = axis
	event.axis_value = value
	event.device = 0
	Input.parse_input_event(event)
	_viewport.push_input(event, true)
	await _settle()

func _key(keycode: Key) -> void:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	_viewport.push_input(event, true)
	await _settle()
	event = event.duplicate()
	event.pressed = false
	_viewport.push_input(event, true)
	await process_frame

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(screen: String, state: String = "focus") -> void:
	if _capture_screen != screen or DisplayServer.get_name() == "headless": return
	await _settle()
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROOF_SIZE, screen + " native proof size")
	if image != null:
		var directory: String = _output_dir.path_join("native_" + screen)
		DirAccess.make_dir_recursive_absolute(directory)
		image.save_png(directory.path_join(screen + "_" + state + ".png"))
		print(directory)

func _expect(ok: bool, message: String) -> void:
	if not ok and not _failures.has(message): _failures.append(message)
