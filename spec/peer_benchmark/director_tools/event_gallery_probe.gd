extends SceneTree

# Director stills of every event from a real RunScene, for the owner's inbox: one shot of the choices
# page, one more per choice that has a reward preview on hover, and a report of what each choice says.
# --out=<abs dir> [--only=<id,id>]
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Events = preload("res://scripts/event_rules.gd")
const Preview = preload("res://scripts/event_reward_preview.gd")
const Data = preload("res://scripts/game_data.gd")

func _initialize() -> void:
	call_deferred("_run")

func _value(name: String, fallback: String) -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--%s=" % name): return argument.trim_prefix("--%s=" % name)
	return fallback

func _fix_window() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920, 1080)

func _shot(path: String) -> Vector2i:
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	image.save_png(path)
	return image.get_size()

func _catalog() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/events.json"))["events"]

func _state(id: String, event: Dictionary) -> Dictionary:
	var state: Dictionary = Run.new().create_new_run(83, Store.default_data())
	for room: Dictionary in (state["rooms"] as Dictionary).values():
		if str(room.get("type", "")) != "event": continue
		state["current_room"] = room["coord"]
		room["event_id"] = id
		room["section_index"] = int(event["min_section"])
		state["mode"] = "event"
		break
	state["player_hp"] = 30
	state["player_max_hp"] = 40
	state["held_embers"] = 120
	state["unbanked_embers"] = 120
	var equipment: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/equipment.json"))
	for slot: String in ["weapon", "armor", "boots"]:
		if not str((state["equipped_equipment"] as Dictionary).get(slot, "")).is_empty(): continue
		for gear_id: String in equipment:
			if str(equipment[gear_id].get("slot", "")) == slot:
				state["equipped_equipment"][slot] = gear_id
				break
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	var pool: Dictionary = cards.get("cards", cards)
	for card_id: String in pool:
		if Data.card_is_item(card_id):
			(state["item_inventory"] as Array).append(card_id)
			break
	return Events.enter_event(state)

func _run() -> void:
	Settings.set_storage_path("user://event-gallery-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = Vector2i(1920, 1080)
	root.gui_disable_input = true
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	var out: String = _value("out", "")
	var only: String = _value("only", "")
	var catalog: Dictionary = _catalog()
	var report: Array = []
	for id: String in catalog:
		if not only.is_empty() and id not in only.split(","): continue
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		scene.set_process_input(false)
		scene.set_process_unhandled_input(false)
		await process_frame
		_fix_window()
		await process_frame
		scene.call("_load_run_state", _state(id, catalog[id]))
		await create_timer(1.3).timeout
		_fix_window()
		await process_frame
		await process_frame
		var view: Control = scene.get("_event_view")
		var size: Vector2i = await _shot("%s/%s.png" % [out, id])
		var entry: Dictionary = {"id": id, "title": str(catalog[id]["title"]), "pool": str(catalog[id]["pool"]), "size": "%dx%d" % [size.x, size.y], "choices": []}
		var buttons: Array = view.get("choices")
		for index: int in range(buttons.size()):
			var button: Button = buttons[index]
			var lines: Array = view.call("cached_preview_lines", str(button.get("choice_id")))
			var concrete: Dictionary = Preview.first_concrete(lines)
			var line: Dictionary = {"id": str(button.get("choice_id")), "text": button.text, "available": bool(button.get("available")), "lines": lines, "hover": not concrete.is_empty()}
			(entry["choices"] as Array).append(line)
			if concrete.is_empty(): continue
			button.mouse_entered.emit()
			await create_timer(0.45).timeout
			await _shot("%s/%s_c%d.png" % [out, id, index])
			button.mouse_exited.emit()
			await create_timer(0.2).timeout
		report.append(entry)
		print("EVENT GALLERY %s choices=%d" % [id, buttons.size()])
		scene.queue_free()
		await process_frame
	var file := FileAccess.open("%s/report.json" % out, FileAccess.WRITE)
	file.store_string(JSON.stringify(report, " "))
	file.close()
	quit()
