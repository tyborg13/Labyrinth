extends SceneTree

const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const OUTPUT_DIR: String = "user://relic_rework_visual_probe"
const PROGRESSION_PATH: String = "user://relic_rework_visual_progression.json"
const RUN_PATH: String = "user://relic_rework_visual_run.save"
const SETTINGS_PATH: String = "user://relic_rework_visual_settings.json"
const REDESIGNED_RELIC_IDS = [
	"pilgrim_boots", "reinforced_shield", "static_soles", "cinderbrand_tongs",
	"mirror_shard", "thawing_charm", "widow_thread", "phoenix_ember",
	"ember_lens", "hollow_die", "voltaic_tuning_fork", "tectonic_abacus",
	"dawnbrand_filament", "glowstone_matrix", "briar_winch", "hourglass_awl",
	"beaconrunner_spurs", "true_north", "dawnstitch_cord", "starless_astrolabe",
	"witchglass_carapace", "witchglass_lantern", "sunlit_edge", "glassway_compass",
	"unclouded_sun"
]

var _failures: Array[String]


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)

	for batch_index: int in range(ceili(float(REDESIGNED_RELIC_IDS.size()) / 3.0)):
		var batch_ids: Array[String]
		var start_index: int = batch_index * 3
		var end_index: int = mini(start_index + 3, REDESIGNED_RELIC_IDS.size())
		for relic_index: int in range(start_index, end_index):
			batch_ids.append(str(REDESIGNED_RELIC_IDS[relic_index]))
		await _capture(Vector2i(1920, 1080), 1.0, batch_ids, 88001 + batch_index, batch_index + 1)

	if _failures.is_empty():
		print("RELIC REWORK VISUAL PROBE: PASS")
		print("RELIC_REWORK_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("RELIC REWORK VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture(
	screenshot_size: Vector2i,
	ui_scale: float,
	relic_ids: Array[String],
	seed: int,
	batch_number: int
) -> void:
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "%s @ %d%% should load the run scene" % [screenshot_size, roundi(ui_scale * 100.0)])
	if packed == null:
		return
	var viewport := SubViewport.new()
	viewport.name = "RelicReworkProof_%dx%d_ui%d" % [
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0)
	]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = logical_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.set("_settings", settings.duplicate(true))
	instance.call("_close_dialogue")
	var run_engine := RunEngine.new()
	var base_state: Dictionary = run_engine.create_new_run(seed, ProgressionStore.default_data())
	var treasure_coord: Vector2i = _first_room_coord_of_type(run_engine, base_state, "treasure")
	var treasure_state: Dictionary = _run_state_for_room(run_engine, base_state, treasure_coord)
	treasure_state["pending_relics"] = relic_ids.duplicate()
	instance.call("_load_run_state", treasure_state)
	instance.call("_close_dialogue")
	await _settle()

	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(logical_size),
		"%s @ %d%% should expose logical viewport %s" % [
			screenshot_size,
			roundi(ui_scale * 100.0),
			logical_size
		]
	)
	_validate_relic_choices(instance, relic_ids, logical_size, screenshot_size, ui_scale)

	var label: String = "%dx%d_ui%d_batch%02d" % [
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
		batch_number
	]
	await _save_screenshot(viewport, "%s/%s_choices.png" % [OUTPUT_DIR, label], screenshot_size)
	instance.queue_free()
	viewport.queue_free()
	await _settle()


func _validate_relic_choices(
	instance: Node,
	relic_ids: Array[String],
	logical_size: Vector2i,
	screenshot_size: Vector2i,
	ui_scale: float
) -> void:
	var label: String = "%s @ %d%%" % [screenshot_size, roundi(ui_scale * 100.0)]
	var choice_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	_expect(choice_bar != null and choice_bar.visible, "%s should show the relic choice bar" % label)
	if choice_bar == null:
		return
	_expect(choice_bar.get_child_count() == relic_ids.size(), "%s should show all three requested relic choices" % label)
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(logical_size))
	_expect(viewport_rect.encloses(choice_bar.get_global_rect()), "%s relic choices should remain inside the viewport" % label)
	for index: int in range(mini(choice_bar.get_child_count(), relic_ids.size())):
		var relic_id: String = relic_ids[index]
		var panel: Control = choice_bar.get_child(index) as Control
		_expect(panel != null, "%s should create a card for %s" % [label, relic_id])
		if panel == null:
			continue
		_expect(viewport_rect.encloses(panel.get_global_rect()), "%s %s card should remain inside the viewport" % [label, relic_id])
		var description: RichTextLabel = panel.find_child("RelicChoiceDescription_%s" % relic_id, true, false) as RichTextLabel
		_expect(description != null, "%s %s should display its exact rules text" % [label, relic_id])
		if description == null:
			continue
		var font_size: int = description.get_theme_font_size("normal_font_size")
		_expect(font_size >= UiTypography.SIZE_BODY_LARGE, "%s %s rules text should use the enlarged readable type tier" % [label, relic_id])
		_expect(float(description.get_meta("inline_icon_size", 0.0)) > float(font_size), "%s %s mechanic icons should be larger than the surrounding rules text" % [label, relic_id])
		_expect(
			description.get_content_height() <= description.size.y + 1.0,
			"%s %s rules text should not clip vertically" % [label, relic_id]
		)
		_expect(
			panel.get_global_rect().encloses(description.get_global_rect()),
			"%s %s rules text should remain inside its card" % [label, relic_id]
		)

func _run_state_for_room(run_engine: RunEngine, source_state: Dictionary, coord: Vector2i) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = false
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = run_engine.call(
		"_display_layout_for_room",
		int(state.get("seed", 0)),
		room,
		Vector2i(1, 0)
	)
	state["mode"] = "treasure"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state


func _first_room_coord_of_type(run_engine: RunEngine, state: Dictionary, room_type: String) -> Vector2i:
	for radius: int in range(1, 9):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				var coord := Vector2i(x, y)
				if maxi(absi(x), absi(y)) != radius:
					continue
				if str(run_engine.room_metadata(state, coord).get("type", "")) == room_type:
					return coord
	return Vector2i.ZERO


func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]


func _save_screenshot(viewport: SubViewport, output_path: String, expected_size: Vector2i) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = viewport.get_texture().get_image()
	_expect(image.get_size() == expected_size, "%s should render exactly %s" % [output_path, expected_size])
	var error: Error = image.save_png(output_path)
	_expect(error == OK, "Should save %s" % output_path)


func _settle() -> void:
	for _frame: int in range(4):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)


func _string_array(values: Array) -> Array[String]:
	var result: Array[String]
	for value: Variant in values:
		result.append(str(value))
	return result


func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))


func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
