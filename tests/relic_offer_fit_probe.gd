extends SceneTree

# Every relic offer must show its exact rules text in full: render all relics
# (longest descriptions first) through the live treasure choice and fail on any
# description whose content is taller than its box or escapes its panel.

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

var _vp: SubViewport
var _overflows: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920, 1080))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = Vector2i(1920, 1080)
	root.size = Vector2i(1920, 1080)
	SettingsStore.set_storage_path("user://relic_offer_fit_settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://probes"))
	ProgressionStore.set_storage_path("user://relic_offer_fit_progression.json")
	ProgressionStore.set_run_storage_path("user://relic_offer_fit_run.save")
	ProgressionStore.clear_saved_run()
	_vp = SubViewport.new()
	_vp.size = Vector2i(1920, 1080)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_vp)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	_vp.add_child(instance)
	await process_frame
	await process_frame
	var eng := RunEngine.new()
	var base_state: Dictionary = eng.create_new_run(321, ProgressionStore.default_data())
	instance.call("_load_run_state", base_state.duplicate(true))
	await process_frame
	await process_frame
	if instance.has_method("_close_dialogue"):
		instance.call("_close_dialogue")
	var coord: Vector2i = _first_room_coord_of_type(eng, base_state, "treasure")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/relics.json"))
	var relics: Variant = (data as Dictionary).get("relics", data) if data is Dictionary else data
	var entries: Array = []
	if relics is Dictionary:
		for key: Variant in (relics as Dictionary).keys():
			var rel: Dictionary = (relics as Dictionary)[key]
			entries.append([str(key), str(rel.get("description", "")).length()])
	else:
		for rel: Variant in relics:
			entries.append([str((rel as Dictionary).get("id", "")), str((rel as Dictionary).get("description", "")).length()])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return int(a[1]) > int(b[1]))
	var ids: Array[String] = []
	for e: Array in entries:
		ids.append(str(e[0]))
	var batch: int = 0
	var start: int = 0
	while start < ids.size():
		var batch_ids: Array = ids.slice(start, mini(start + 3, ids.size()))
		start += 3
		batch += 1
		var state: Dictionary = _run_state_for_room(eng, base_state, coord, "treasure", Vector2i(1, 0))
		state["pending_relics"] = batch_ids
		instance.call("_load_run_state", state)
		for _step: int in range(160):
			if not bool(instance.get("_treasure_reveal_active")):
				break
			await create_timer(0.025).timeout
		await process_frame
		await process_frame
		await process_frame
		var bar: Control = instance.get("_relic_choice_bar") as Control
		if bar == null or bar.get_child_count() == 0:
			print("RELIC FIT batch %d: no choices shown" % batch)
			_overflows += 1
			continue
		var batch_overflow: bool = false
		for child: Node in bar.get_children():
			var panel: Control = child as Control
			var relic_id: String = str(panel.get_meta("relic_id", ""))
			var desc: RichTextLabel = panel.find_child("RelicChoiceDescription_%s" % relic_id, true, false) as RichTextLabel
			var name_label: Label = null
			for node: Node in panel.find_children("*", "Label", true, false):
				if node is Label:
					name_label = node as Label
					break
			var content_h: float = desc.get_content_height() if desc != null else -1.0
			var box_h: float = desc.size.y if desc != null else -1.0
			var inside: bool = desc != null and panel.get_global_rect().grow(0.5).encloses(desc.get_global_rect())
			var over: bool = content_h > box_h + 1.0 or not inside
			if over:
				_overflows += 1
				batch_overflow = true
			print("RELIC FIT %s content=%.1f box=%.1f panel=%s name_lines=%d inside=%s %s" % [relic_id, content_h, box_h, panel.size, name_label.get_line_count() if name_label != null else -1, inside, "OVERFLOW" if over else "ok"])
		if batch <= 3 or batch_overflow:
			var image: Image = _vp.get_texture().get_image()
			image.save_png(ProjectSettings.globalize_path("user://probes/relic_offer_fit_%02d.png" % batch))
	print(ProjectSettings.globalize_path("user://probes"))
	if _overflows == 0:
		print("RELIC OFFER FIT: PASS")
		quit(0)
	else:
		push_error("%d relic offers clip their rules text" % _overflows)
		print("RELIC OFFER FIT: FAIL (%d)" % _overflows)
		quit(1)

func _run_state_for_room(probe_run_engine: RunEngine, source_state: Dictionary, coord: Vector2i, mode: String, travel_dir: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = probe_run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode == "room"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = probe_run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, travel_dir)
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _first_room_coord_of_type(probe_run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(probe_run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO
