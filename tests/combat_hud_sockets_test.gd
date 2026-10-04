extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const Socket = preload("res://scripts/combat_hud_socket.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const CursorFeedback = preload("res://scripts/cursor_feedback.gd")
const InputRouter = preload("res://scripts/input_router.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const BossFactory = preload("res://tools/dragon_boss_inspection.gd")
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
	await _capture("01_normal_combat")
	var intents := instance.get("_enemy_intent_toggle_button") as Button
	_expect(intents.visible and not intents.button_pressed and intents.text == "INTENTS [I]", "Intents starts off with its semantic label intact")
	_expect((intents.get_node("IntentContents/VisionIcon") as TextureRect).texture != null, "Intents uses the vision icon")
	await _capture("02_intents_off")
	await _click(intents)
	_expect(intents.button_pressed and bool(instance.get("_show_all_enemy_intents")), "Pointer toggles all enemy intents")
	_expect(intents.text == "INTENTS ON [I]" and (intents.get_theme_stylebox("normal") as StyleBoxFlat).border_color == Palette.GOLD_BRIGHT, "ON retains semantic text and brightens the plate")
	await _pointer(Vector2(960, 500))
	await _capture("03_intents_on")
	await _key(KEY_I)
	_expect(not intents.button_pressed and not bool(instance.get("_show_all_enemy_intents")), "I still toggles intents off")
	intents.disabled = true
	await _click(intents)
	_expect(not intents.button_pressed, "Disabled intents must not activate")
	instance.call("_refresh_enemy_intent_toggle")
	router.call("set_forced_state_for_test", "controller", "xbox")
	await _settle()
	_expect(not intents.get_node("IntentContents/IntentKey").visible, "Controller intents omits the keyboard hint")
	await _capture("04_intents_controller")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var options := {"dragon_id": "zekarion", "dragon_depth": 20, "relics": "iron_lung,ember_lens,pilgrim_boots,mirror_shard,phoenix_ember,winters_hour,stormroad_coil"}
	var boss_profile: Dictionary = profile.duplicate(true)
	boss_profile["level"] = 5
	boss_profile["skill_ids"] = ["ghost_stride", "quick_wits", "discerning_eye", "true_bearing"]
	var boss: Dictionary = BossFactory.build(engine, Combat.new(), engine.create_new_run(BossFactory.seed_for_options(options), boss_profile), options)
	boss["relics"] = ["iron_lung", "ember_lens", "pilgrim_boots", "mirror_shard", "phoenix_ember", "winters_hour", "stormroad_coil"]
	boss["combat_state"]["relics"] = boss["relics"].duplicate()
	boss["combat_state"]["relic_time_reserve"] = {"winters_hour": 2}
	await _load(instance, boss)
	_expect((instance.get("_boss_health_overlay") as Control).is_visible_in_tree(), "Boss proof must include the live boss bar")
	_assert_relics(instance)
	_expect((instance.get("_defiance_badge") as Socket).accent_color == Color("d6aa5e"), "Charged Defiance retains master's gold badge accent")
	await _capture("05_boss_wrapped_relics_charge")
	var charged: Control = instance.call("_relic_frame_for_id", "winters_hour")
	_expect(charged.get_node("RelicTimeReserve").text == "2" and charged.get_node("RelicTimeReserve").visible, "Stored Time uses the socket badge with its exact value")
	_expect(charged.tooltip_text.contains("Stored Time: 2 / 3"), "Charge tooltip retains exact reserve rules")
	charged.grab_focus()
	await _capture("06_charged_relic_focus")
	await _assert_inspection(instance, charged, router)
	await _assert_dialogue_input(instance, charged, router)
	var unchanged: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	await _key(KEY_ENTER)
	_expect(instance.get("_run_state") == unchanged, "Relic inspection focus cannot spend charges or alter run state")
	instance.call("_set_show_all_enemy_intents", true)
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	await _settle()
	_assert_relics(instance)
	_expect(charged.scale == Vector2.ONE, "Reduced motion keeps the socket stable")
	await _capture("07_reduced_motion")
	boss["defiance_capacity"] = 2
	boss["defiance_remaining"] = 0
	boss["combat_state"]["defiance_capacity"] = 2
	boss["combat_state"]["defiance_remaining"] = 0
	boss["combat_state"]["skill_flags"]["used:ghost_stride"] = true
	await _load(instance, boss)
	var defiance := instance.get("_defiance_badge") as Button
	_expect((defiance as Socket).accent_color == Color("62556e"), "Spent Defiance retains master's muted badge accent")
	_expect(defiance.get_node("DefianceCount").text == "0/2" and not defiance.disabled and bool(defiance.get("dimmed")), "0/2 Defiance must be visually spent without disabling inspection")
	_expect(not (instance.call("_controller_candidate_for_control", defiance) as Dictionary).is_empty(), "0/2 Defiance must remain a controller candidate")
	await _assert_inspection(instance, defiance, router)
	await _capture("08_spent_defiance_controller_inspection")
	await _assert_skill_statuses(instance)
	var rite := instance.call("_build_active_rite_badge", {"card_id": "rite_of_noon", "icon": "rite", "tooltip": "Active rite inspection"}, 0) as Socket
	(instance.get("_relic_icon_grid") as Control).add_child(rite)
	await _settle()
	_expect(rite.accent_color == Color(str(GameData.card_def("rite_of_noon").get("accent", "#d9862f"))), "Rites retain their card's exact master badge accent")
	_expect(((rite.get_node("RiteMarkBacking") as Panel).get_theme_stylebox("panel") as StyleBoxFlat).border_color == rite.accent_color, "The rite corner mark retains the same card accent")
	await _assert_inspection(instance, rite, router)
	await _capture("10_rite_controller_inspection")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	instance.call("_controller_clear_board_focus")
	instance.call("_controller_hide_analog_cursor")
	rite.release_focus()
	await _pointer(Vector2(960, 500))
	rite.status_color = Palette.ALLY
	await _settle()
	await _capture("14_accent_with_inner_status")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	_finish()

func _assert_dialogue_input(instance: Node, relic: Button, router: Node) -> void:
	var presses: Array = [0]
	relic.pressed.connect(func() -> void: presses[0] += 1)
	await _click(relic)
	relic.grab_focus()
	_expect(relic.has_focus(), "Relic inspection must retain native focus")
	for key: Key in [KEY_SPACE, KEY_ENTER]:
		router.call("set_forced_state_for_test", "pointer", "xbox")
		_open_dialogue(instance, relic)
		await _key(key)
		_expect(bool(instance.get("_dialogue_text_complete")), "%s must complete a dialogue line while an inspect-only relic has focus" % OS.get_keycode_string(key))
		relic.grab_focus()
		await _key(key)
		_expect(int(instance.get("_dialogue_line_index")) == 1, "%s must advance dialogue while an inspect-only relic has focus" % OS.get_keycode_string(key))
		await _capture("11_dialogue_space" if key == KEY_SPACE else "12_dialogue_enter")
		instance.call("_close_dialogue")
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_A
	accept.pressed = true
	_expect(accept.is_action_pressed("ui_accept"), "Controller A must use the live ui_accept mapping")
	router.call("set_forced_state_for_test", "controller", "xbox")
	_open_dialogue(instance, relic)
	await _joy(JOY_BUTTON_A)
	_expect(bool(instance.get("_dialogue_text_complete")), "Controller A must complete a dialogue line while an inspect-only relic has focus")
	relic.grab_focus()
	await _joy(JOY_BUTTON_A)
	_expect(int(instance.get("_dialogue_line_index")) == 1, "Controller A must advance dialogue while an inspect-only relic has focus")
	await _capture("13_dialogue_controller")
	_expect(presses[0] == 0, "Dialogue input must never activate the inspect-only relic")
	instance.call("_close_dialogue")

func _open_dialogue(instance: Node, relic: Button) -> void:
	instance.call("_start_dialogue", {
		"npc_id": "emaciated_man",
		"lines": [
			{"speaker": "Emaciated Man", "text": "A long dialogue line must finish on accept even when inspection retains focus. ".repeat(8)},
			{"speaker": "Emaciated Man", "text": "The next dialogue line confirms that scene input still advances the conversation. ".repeat(8)},
		],
	})
	relic.grab_focus()
	_expect(bool(instance.get("_dialogue_active")) and not bool(instance.get("_dialogue_text_complete")), "Regression must start with a live incomplete dialogue line")
	_expect(relic.has_focus(), "Inspect-only relic must own focus before dialogue input")

func _assert_inspection(instance: Node, socket: Button, router: Node) -> void:
	_expect(socket.focus_mode == Control.FOCUS_ALL and socket.mouse_default_cursor_shape == Control.CURSOR_HELP, "Tooltip sockets must preserve focus and the help cursor")
	_expect(not bool(CursorFeedback.context_for_control(socket).get("actionable", true)), "Relic, rite and Defiance sockets must have non-actionable help feedback")
	var presses: Array = [0]
	socket.pressed.connect(func() -> void: presses[0] += 1)
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _click(socket)
	socket.grab_focus()
	await _key(KEY_ENTER)
	await _key(KEY_SPACE)
	router.call("set_forced_state_for_test", "controller", "xbox")
	instance.set("_controller_region", "board")
	instance.call("_controller_set_focus_candidate", instance.call("_controller_candidate_for_control", socket), true)
	await _settle()
	var prompts: Array = (instance.get("_controller_prompt_bar") as Node).call("prompts_snapshot")
	for prompt: Dictionary in prompts:
		_expect(str(prompt.get("action", "")) != str(InputRouter.ACTION_ACCEPT), "Focused tooltip sockets must not advertise an A prompt")
	var cursor: Dictionary = (instance.get("_controller_analog_cursor") as Node).call("cursor_snapshot")
	_expect(socket.has_focus() and str(cursor.get("detail_text", "")) == socket.tooltip_text.strip_edges(), "Controller focus must expose the complete inspection tooltip")
	instance.call("_controller_activate_current")
	await _joy(JOY_BUTTON_A)
	_expect(presses[0] == 0, "Tooltip sockets must not emit pressed for pointer, Enter, Space or controller A")

func _assert_skill_statuses(instance: Node) -> void:
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	instance.call("_controller_clear_board_focus")
	instance.call("_controller_hide_analog_cursor")
	(instance.get("_defiance_badge") as Button).release_focus()
	await _pointer(Vector2(960, 500))
	await _settle()
	var sigil := instance.get("_skill_sigil") as Button
	var spent: Socket = sigil.find_child("SkillSigilPreview_ghost_stride", true, false) as Socket
	var ready: Socket = sigil.find_child("SkillSigilPreview_quick_wits", true, false) as Socket
	_expect(spent != null and ready != null, "The live ability sigil must preview spent Ghost Stride and ready Quick Wits")
	if spent == null or ready == null:
		return
	_expect(str(instance.call("_skill_hud_status", "ghost_stride")) == "SPENT" and str(instance.call("_skill_hud_status", "quick_wits")) == "READY", "Status proof must use the real combat ability states")
	_expect(spent.status_color == Palette.TEXT_3 and spent.dimmed, "Spent ability previews must retain a grey status ring and desaturated icon")
	_expect(ready.status_color == Palette.ALLY and not ready.dimmed, "Ready ability previews must retain a teal status ring and saturated icon")
	_expect(spent.get_node("Icon").material != ready.get_node("Icon").material, "Ready and spent previews must use independent cached saturation states")
	await _capture("09_ready_spent_skill_status_rings")

func _assert_relics(instance: Node) -> void:
	var grid := instance.get("_relic_icon_grid") as GridContainer
	_expect(grid.get_child_count() == 7 and grid.columns == 5, "Seven relics retain five-column wrapping")
	var first_bottom: float = 0.0
	var visible_bottom: float = 0.0
	var rarities: Dictionary = {}
	for index: int in range(grid.get_child_count()):
		var socket := grid.get_child(index) as Button
		_expect(socket is Socket and socket.size == Vector2(48, 48), "Every relic uses a 48px shared socket")
		var relic_id: String = str(socket.get_meta("relic_id", ""))
		_expect((socket as Socket).accent_color == Color(GameData.relic_accent(relic_id)), "Relic %s retains its exact rarity/accent color" % relic_id)
		rarities[GameData.relic_rarity(relic_id)] = true
		_expect(not socket.tooltip_text.is_empty() and socket.focus_mode == Control.FOCUS_ALL, "Relic inspection retains its tooltip and focus")
		if index < 5:
			first_bottom = maxf(first_bottom, socket.get_global_rect().end.y)
		else:
			_expect(socket.global_position.y > (grid.get_child(0) as Control).global_position.y, "Additional relics occupy the second row")
		visible_bottom = maxf(visible_bottom, socket.get_global_rect().end.y)
	_expect(rarities.has("common") and rarities.has("rare") and rarities.has("legendary"), "Accent proof must cover common grey, rare blue and legendary orange relics")
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
