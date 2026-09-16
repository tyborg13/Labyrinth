extends "res://tests/guardian_ui_probe.gd"

## Expanded existing enemy inspection: every Guardian and distinct helper,
## longest four-move panel, contextual reinforcement rules and real close input.
func _run() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	Settings.set_storage_path("user://guardian_inspection_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	Progression.set_storage_path("user://guardian_inspection_profile.json")
	Progression.set_run_storage_path("user://guardian_inspection_run.save")
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var display := TextureRect.new()
	display.texture = canvas.get_texture()
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(display)
	var engine := RunEngine.new()
	var combat := Combat.new()
	var seen: Dictionary = {}
	var panels: Array[Dictionary] = []
	for info: Dictionary in Guardians.DEFINITIONS.values():
		if is_instance_valid(scene):
			scene.queue_free()
			await process_frame
		scene = load("res://scenes/run_scene.tscn").instantiate()
		canvas.add_child(scene)
		await process_frame
		var state: Dictionary = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":info["id"],"guardian_case":"pre_battle"})
		await _load(state)
		var preview: Dictionary = (scene.get("_pre_battle_preview_run_state") as Dictionary)["combat_state"]
		for enemy: Dictionary in preview.get("enemies",[]):
			var id: String = enemy["type"]
			if seen.has(id): continue
			seen[id] = true
			scene.call("_open_pinned_pre_battle_inspection","enemy",str(enemy["id"]),null,enemy)
			await create_timer(.2).timeout
			await process_frame
			var panel: Control = scene.get("_pinned_tooltip_panel")
			_check(is_instance_valid(panel),id+" opens existing enemy inspection")
			if not is_instance_valid(panel): continue
			var rect: Rect2 = panel.get_global_rect()
			_check(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(rect),id+" expanded panel fits 1080p")
			for label: Node in panel.find_children("Guardian*Rules","Label",true,false):
				_check(rect.encloses((label as Label).get_global_rect()),id+" counterplay text stays inside panel")
			panels.append({"actor":id,"rect":[rect.position.x,rect.position.y,rect.size.x,rect.size.y]})
			await _capture(id+"_expanded_inspection")
			var close: Button = panel.find_child("PreBattleInspectionCloseButton",true,false)
			await _click(close.get_global_rect().get_center())
			_check(not (scene.get("_pinned_tooltip_scrim") as Control).visible,id+" closes via pointer")
	_check(seen.size()==14,"all six Guardians and eight distinct helper types inspected")
	var file := FileAccess.open("user://probes/guardian_ui/inspection.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"panels":panels,"errors":failures},"\t"))
	print("GUARDIAN INSPECTION: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	quit(0 if failures.is_empty() else 1)
