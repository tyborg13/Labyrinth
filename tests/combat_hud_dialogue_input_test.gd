extends "res://tests/combat_hud_sockets_test.gd"

func _run() -> void:
	Settings.set_storage_path("user://combat_hud_dialogue_input_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["dialogue_speed"] = Settings.DIALOGUE_STANDARD
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	Store.set_storage_path("user://combat_hud_dialogue_input_profile.json")
	Store.set_run_storage_path("user://combat_hud_dialogue_input_run.save")
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
	var state: Dictionary = engine.create_new_run(123, profile)
	state["relics"] = ["iron_lung"]
	await _load(instance, state)
	instance.call("_close_large_map")
	await _settle()
	var relic := instance.call("_relic_frame_for_id", "iron_lung") as Button
	_expect(relic != null and bool(relic.get("inspect_only")), "Fixture must use a live inspect-only relic socket")
	if relic == null:
		_finish()
		return
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
	_expect(presses[0] == 0, "Dialogue input must never activate the inspect-only relic")
	instance.call("_close_dialogue")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	_finish()

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

func _finish() -> void:
	print("COMBAT HUD DIALOGUE INPUT TEST: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
