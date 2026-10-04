extends "res://tests/combat_hud_badges_test.gd"

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
	var relic := instance.call("_relic_frame_for_id", "iron_lung") as Control
	_expect(relic is PanelContainer and not relic is BaseButton, "Fixture must use a live tooltip relic frame")
	if relic == null:
		_finish()
		return
	await _assert_dialogue_input(instance, relic, router)
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame
	_finish()

func _finish() -> void:
	print("COMBAT HUD DIALOGUE INPUT TEST: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)
