extends "res://tests/guardian_inspection_probe.gd"
func _run() -> void:
	root.size=Vector2i(1920,1080)
	root.content_scale_size=root.size
	Settings.set_storage_path("user://guardian_map_revision_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"]=1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	Progression.set_storage_path("user://guardian_map_revision_profile.json")
	Progression.set_run_storage_path("user://guardian_map_revision_run.save")
	canvas=SubViewport.new()
	canvas.size=root.size
	canvas.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var display := TextureRect.new()
	display.texture=canvas.get_texture()
	display.size=Vector2(root.size)
	display.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	scene=load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := RunEngine.new()
	var combat := Combat.new()
	var bounds: Array[Dictionary] = []
	for info: Dictionary in Guardians.DEFINITIONS.values():
		await _load(Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":info["id"],"guardian_case":"map_choice"}))
		scene.call("_open_large_map")
		await process_frame
		var panel: Node = scene.get("_large_map_view")
		var target := Vector2i.ZERO
		for room: Dictionary in (scene.get("_run_state") as Dictionary)["rooms"].values():
			if str(room.get("guardian_id",""))==str(info["id"]): target=room["coord"];break
		panel.call("select_room",target)
		var button: Button = (panel.get("node_buttons") as Dictionary)[target]
		button.grab_focus()
		await create_timer(.15).timeout
		_check(panel.call("can_activate_room",target),str(info["id"])+" is an actual route choice")
		var rect: Rect2 = button.get_global_rect()
		bounds.append({"guardian":info["id"],"node_rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
		await _capture(str(info["id"])+"_selected_map")
		# Same production node at each preserved state, tightly framed only for
		# the diagnostic close-up; the main proof above is the untouched full UI.
		for state: String in ["reachable","visited","current"]:
			button.set("route_state",state)
			button.set("reduced_motion",true)
			button.set("actionable",state=="reachable")
			button.call("refresh_state")
			await _capture(str(info["id"])+"_map_"+state)
		await scene.call("_close_large_map")
	var file := FileAccess.open("user://probes/guardian_ui/map_revision.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"nodes":bounds,"errors":failures},"\t"))
	print("GUARDIAN MAP REVISION: ","PASS" if failures.is_empty() else "FAIL"," ",failures)
	quit(0 if failures.is_empty() else 1)
