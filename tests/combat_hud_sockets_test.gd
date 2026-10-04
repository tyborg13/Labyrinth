extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Socket = preload("res://scripts/combat_hud_socket.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const BossFactory = preload("res://tools/dragon_boss_inspection.gd")
const EmberFeedbackSuite = preload("res://tests/suites/ember_reward_feedback_suite.gd")
const TooltipSuite = preload("res://tests/suites/tooltip_consistency_suite.gd")
const SIZE := Vector2i(1920, 1080)

var _viewport: SubViewport
var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://combat_hud_sockets_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://combat_hud_sockets_profile.json")
	Store.set_run_storage_path("user://combat_hud_sockets_run.save")
	Store.clear_saved_run()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	Store.save_data(profile)
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(instance)
	await _settle()
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var engine := Run.new()
	var room_state: Dictionary = engine.create_new_run(123, profile)
	var coord := Vector2i(-999, -999)
	for candidate: Vector2i in engine.available_moves(room_state):
		if str(engine.room_metadata(room_state, candidate).get("type", "")) == "combat":
			coord = candidate
			break
	_expect(coord != Vector2i(-999, -999), "Fixture must offer a real combat room")
	var normal: Dictionary = engine.begin_pre_battle_combat(engine.move_to_pre_battle(room_state, coord))
	_expect(str(normal.get("mode", "")) == "combat", "Fixture must enter real combat")
	await _load(instance, normal)
	_assert_toolbar(instance)
	await _capture("01_normal_combat")
	var grimoire := instance.get("grimoire_button") as Button
	await _pointer(grimoire.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == grimoire, "Socket icon and badge must not intercept hover")
	await _capture("02_socket_hover_notification")
	await _pointer(Vector2(960, 500))
	grimoire.grab_focus()
	_expect(grimoire.has_focus(), "HUD sockets retain native keyboard focus")
	await _capture("03_socket_keyboard_focus")
	await _key(KEY_ENTER)
	await _settle()
	_expect((instance.get("_grimoire_scrim") as Control).visible, "Enter activates the grimoire socket")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (instance.get("_grimoire_scrim") as Control).visible, "Escape returns from grimoire")
	var intents := instance.get("_enemy_intent_toggle_button") as Button
	_expect(intents.visible and not intents.button_pressed and intents.text == "INTENTS [I]", "Intents starts off with its semantic label intact")
	_expect((intents.get_node("IntentContents/VisionIcon") as TextureRect).texture != null, "Intents uses the vision icon")
	await _capture("04_intents_off")
	await _click(intents)
	_expect(intents.button_pressed and bool(instance.get("_show_all_enemy_intents")), "Pointer toggles all enemy intents")
	_expect(intents.text == "INTENTS ON [I]" and (intents.get_theme_stylebox("normal") as StyleBoxFlat).border_color == Palette.GOLD_BRIGHT, "ON retains semantic text and brightens the plate")
	await _pointer(Vector2(960, 500))
	await _capture("05_intents_on")
	await _key(KEY_I)
	_expect(not intents.button_pressed and not bool(instance.get("_show_all_enemy_intents")), "I still toggles intents off")
	intents.disabled = true
	await _click(intents)
	_expect(not intents.button_pressed, "Disabled intents must not activate")
	instance.call("_refresh_enemy_intent_toggle")
	router.call("set_forced_state_for_test", "controller", "xbox")
	grimoire.grab_focus()
	await _settle()
	_expect(not (instance.get("menu_button") as Button).get_node("HotkeyHint").visible, "Controller input omits keyboard caps")
	_expect(not intents.get_node("IntentContents/IntentKey").visible, "Controller intents omits keyboard hint without invented glyphs")
	await _capture("06_socket_controller_focus")
	instance.call("_controller_set_focus_candidate", instance.call("_controller_candidate_for_control", grimoire), true)
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect((instance.get("_grimoire_scrim") as Control).visible, "Controller A activates the focused HUD socket")
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (instance.get("_grimoire_scrim") as Control).visible, "Controller B returns from grimoire")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _load(instance, room_state)
	_expect((instance.get("_large_map_scrim") as Control).visible, "Room entry preserves automatic section-map presentation")
	await _capture("07a_section_map_room_view")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (instance.get("_large_map_scrim") as Control).visible, "Escape closes the automatically presented map")
	var map_button := instance.get("_section_map_hud_button") as Button
	_expect(map_button.is_visible_in_tree(), "Section map room keeps its map socket")
	await _capture("07_map_room")
	await _pointer(map_button.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == map_button, "Map socket receives pointer input after the map closes")
	await _click(map_button)
	_expect((instance.get("_large_map_scrim") as Control).visible, "Pointer still opens the section map")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (instance.get("_large_map_scrim") as Control).visible and map_button.has_focus(), "Map back returns focus to its socket")
	await _key(KEY_M)
	_expect((instance.get("_large_map_scrim") as Control).visible, "Map hotkey remains bound")
	await _key(KEY_M)
	var options := {"dragon_id": "zekarion", "dragon_depth": 20, "relics": "iron_lung,ember_lens,pilgrim_boots,mirror_shard,phoenix_ember,winters_hour,stormroad_coil"}
	var boss_profile: Dictionary = profile.duplicate(true)
	boss_profile["level"] = 5
	boss_profile["skill_ids"] = ["ghost_stride", "sure_footed", "discerning_eye", "true_bearing"]
	var boss: Dictionary = BossFactory.build(engine, Combat.new(), engine.create_new_run(BossFactory.seed_for_options(options), boss_profile), options)
	boss["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "phoenix_ember", "winters_hour", "stormroad_coil"]
	boss["combat_state"]["relics"] = boss["relics"].duplicate()
	boss["combat_state"]["relic_time_reserve"] = {"winters_hour": 2}
	await _load(instance, boss)
	_expect((instance.get("_boss_health_overlay") as Control).is_visible_in_tree(), "Boss proof must include the live boss bar")
	_assert_relics(instance)
	await _capture("08_boss_wrapped_relics_charge")
	var charged: Control = instance.call("_relic_frame_for_id", "winters_hour")
	_expect(charged.get_node("RelicTimeReserve").text == "2" and charged.get_node("RelicTimeReserve").visible, "Stored Time uses the socket badge with its exact value")
	_expect(charged.tooltip_text.contains("Stored Time: 2 / 3"), "Charge tooltip retains exact reserve rules")
	charged.grab_focus()
	await _capture("09_charged_relic_focus")
	var unchanged: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _key(KEY_ENTER)
	_expect(instance.get("_run_state") == unchanged, "Relic inspection focus cannot spend charges or alter run state")
	instance.call("_set_show_all_enemy_intents", true)
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	await _settle()
	_assert_relics(instance)
	_expect(charged.scale == Vector2.ONE, "Reduced motion keeps the socket stable")
	await _capture("10_reduced_motion")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	await EmberFeedbackSuite.run(self, _expect)
	TooltipSuite.run(_expect)
	_finish()

func _assert_toolbar(instance: Node) -> void:
	var previous: Control = instance.get("stats_label") as Control
	for button: Button in [instance.get("_section_map_hud_button"), instance.get("loadout_button"), instance.get("grimoire_button"), instance.get("menu_button")]:
		_expect(button is Socket and button.size == Vector2(58, 58), "Every toolbar action uses a 58px shared socket")
		_expect(button.focus_mode == Control.FOCUS_ALL and button.get_node("Icon").texture != null, "Toolbar preserves native focus and existing icons")
		_expect(bool(button.get_meta("ui_button_feedback_bound", false)), "Toolbar retains its shared hover/focus audio feedback")
		for state: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
			_expect(button.get_theme_stylebox(state) is StyleBoxEmpty, "Sockets must never draw default rectangular states")
		_expect(absf(button.global_position.x - previous.get_global_rect().end.x - 12.0) < 1.0, "Toolbar keeps action order with 12px spacing")
		_expect(Rect2(Vector2.ZERO, Vector2(SIZE)).encloses(button.get_global_rect()), "Toolbar remains inside screen margins")
		previous = button
	_expect((instance.get("loadout_button") as Button).get_node_or_null("HotkeyHint") == null and (instance.get("grimoire_button") as Button).get_node_or_null("HotkeyHint") == null, "Unbound actions omit invented C/G hints")
	_expect((instance.get("_section_map_hud_button") as Button).get_node("HotkeyHint").text == "M", "Map cap reflects its actual binding")
	var stats := instance.get("stats_label") as Label
	_expect(stats.get_node("StatsStack/LevelEyebrow").text == "LEVEL 1" and stats.get_node("StatsStack/EmberRow/EmberValue").text == "0", "Header paints the compact level and ember stack")
	_expect(stats.text == "LV 1  EMBERS 0", "Semantic ember text remains compatible with exact reward feedback")
	var badge := instance.get("_grimoire_badge") as Control
	_expect(badge != null and badge.visible and (instance.get("grimoire_button") as Control).get_global_rect().encloses(badge.get_global_rect()), "Unread notification occupies the socket's top-right rim")
	var scrim: Node = instance.get_node("UiLayer/UiRoot/HudSeatScrim")
	_expect(scrim.get_index() == 0 and bool(scrim.get("show_bottom_band")), "HUD scrims retain the board/card seating")

func _assert_relics(instance: Node) -> void:
	var grid := instance.get("_relic_icon_grid") as GridContainer
	_expect(grid.get_child_count() == 7 and grid.columns == 5, "Seven relics retain five-column wrapping")
	var first_bottom: float = 0.0
	var visible_bottom: float = 0.0
	for index: int in range(grid.get_child_count()):
		var socket := grid.get_child(index) as Button
		_expect(socket is Socket and socket.size == Vector2(48, 48), "Every relic uses a 48px shared socket")
		_expect(not socket.tooltip_text.is_empty() and socket.focus_mode == Control.FOCUS_ALL, "Relic inspection retains its tooltip and focus")
		if index < 5:
			first_bottom = maxf(first_bottom, socket.get_global_rect().end.y)
		else:
			_expect(socket.global_position.y > (grid.get_child(0) as Control).global_position.y, "Additional relics occupy the second row")
		visible_bottom = maxf(visible_bottom, socket.get_global_rect().end.y)
	_expect(is_equal_approx(float(instance.call("_relic_bar_first_row_bottom_y")), first_bottom), "First-row bottom continues to track the actual sockets")
	_expect(float(instance.call("_relic_bar_visible_bottom_y")) >= visible_bottom and visible_bottom > first_bottom, "Visible relic bottom includes wrapped rows")
	var sigil := instance.get("_skill_sigil") as Button
	_expect(sigil != null and (sigil.find_child("SkillSigilTitle", true, false) as Label).text == "ABILITIES", "Ability chip retains its content")
	if sigil != null:
		for preview: Node in sigil.find_children("SkillSigilPreview_*", "Button", true, false):
			_expect(preview is Socket, "Ability previews share the socket ring")

func _load(instance: Node, state: Dictionary) -> void:
	instance.set("_progression", state.get("progression", Store.default_data()))
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()

func _settle() -> void:
	await create_timer(0.35).timeout
	await process_frame
	await process_frame

func _pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	event.relative = Vector2(3, 0)
	_viewport.push_input(event, true)
	await process_frame

func _click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	await _pointer(position)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _capture(_label: String) -> void:
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error(message)

func _finish() -> void:
	print("COMBAT HUD SOCKETS TEST: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
