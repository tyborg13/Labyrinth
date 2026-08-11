extends SceneTree

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/elemental_ranged_attack_v4"
const PROGRESSION_PATH: String = "user://elemental_ranged_attack_probe_progression.json"
const RUN_PATH: String = "user://elemental_ranged_attack_probe_run.save"
const SETTINGS_PATH: String = "user://elemental_ranged_attack_probe_settings.json"
const ELEMENTS: PackedStringArray = ["earth", "air", "lightning", "ice"]

var _failures: Array[String] = []
var _capture_viewport: SubViewport = null


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()
	await _capture_elemental_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("ELEMENTAL RANGED ATTACK VISUAL PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ELEMENTAL RANGED ATTACK VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_elemental_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Elemental attack proof should load the production run scene")
	if packed == null:
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "ElementalRangedAttack1920x1080"
	_capture_viewport.size = Vector2i(1920, 1080)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(1920.0, 1080.0),
		"Elemental attack proof should use the authored 1920x1080 combat viewport"
	)
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(8585, ProgressionStore.default_data()))
	await _settle()
	var run_state: Dictionary = instance.get("_run_state")
	var combat_coord: Vector2i = _first_combat_coord(run_engine, run_state)
	_expect(combat_coord != Vector2i.ZERO, "Elemental attack proof should find an authored combat room")
	if combat_coord == Vector2i.ZERO:
		instance.queue_free()
		return
	instance.call("_on_map_view_room_selected", combat_coord)
	await create_timer(0.95).timeout
	await _settle()
	instance.call("_close_dialogue")

	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	instance.set("_settings", settings.duplicate(true))
	var combat_state: Dictionary = _elemental_combat_state(instance.get("_combat_state") as Dictionary)
	_install_combat_state(instance, combat_state)
	await _settle()
	await _render_and_capture(instance, combat_state, {}, "elemental_00_before.png")
	for element_id: String in _requested_elements():
		settings["reduced_motion"] = false
		instance.set("_settings", settings.duplicate(true))
		await _capture_element_sequence(instance, combat_state, element_id)
		await _render_and_capture(instance, combat_state, {}, "%s_70_cleared.png" % element_id)
		settings["reduced_motion"] = true
		instance.set("_settings", settings.duplicate(true))
		var effect: Dictionary = _effect_for_element(element_id)
		await _render_and_capture(
			instance,
			combat_state,
			_elemental_presentation(effect, 1.0, element_id),
			"%s_80_reduced_motion.png" % element_id
		)

	instance.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	_capture_viewport = null
	await process_frame


func _capture_element_sequence(instance: Node, combat_state: Dictionary, element_id: String) -> void:
	var effect: Dictionary = _effect_for_element(element_id)
	var style: String = AttackFxLibrary.style_for_effect(effect)
	_expect(style != AttackFxLibrary.STYLE_DEFAULT, "%s probe attack should select an authored style" % element_id.capitalize())
	var frame_count: int = AttackFxLibrary.animation_frame_count(effect, 6, false)
	var frame_seconds: float = AttackFxLibrary.animation_frame_seconds(effect, 0.04, false)
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	var release_frame: int = clampi(int(round(anticipation_end * 0.65 * float(frame_count))), 1, frame_count - 4)
	var causality_frame: int = clampi(int(round(lerpf(anticipation_end, travel_end, 0.42) * float(frame_count))), release_frame + 1, frame_count - 3)
	var contact_frame: int = clampi(int(round(travel_end * float(frame_count))), causality_frame + 1, frame_count - 2)
	var impact_span: int = frame_count - contact_frame
	var peak_ratio: float = 0.72 if style == AttackFxLibrary.STYLE_EARTH_SPIKES else 0.52
	var aftermath_ratio: float = 0.86 if style == AttackFxLibrary.STYLE_EARTH_SPIKES else 0.78
	var peak_frame: int = clampi(contact_frame + int(round(float(impact_span) * peak_ratio)), contact_frame + 1, frame_count - 1)
	var aftermath_frame: int = clampi(contact_frame + int(round(float(impact_span) * aftermath_ratio)), peak_frame + 1, frame_count)
	var key_frames: Dictionary = {
		release_frame: "10_release",
		causality_frame: "20_causality",
		contact_frame: "30_contact",
		peak_frame: "40_peak",
		aftermath_frame: "50_aftermath",
	}
	for frame: int in range(1, frame_count + 1):
		var progress: float = float(frame) / float(frame_count)
		instance.call("_render_board_state", combat_state, _elemental_presentation(effect, progress, element_id))
		await process_frame
		await process_frame
		await _save_screenshot("%s/%s_sequence_%02d.png" % [OUTPUT_DIR, element_id, frame])
		if key_frames.has(frame):
			await _save_screenshot("%s/%s_%s.png" % [OUTPUT_DIR, element_id, str(key_frames[frame])])
		await create_timer(frame_seconds).timeout


func _effect_for_element(element_id: String) -> Dictionary:
	return {
		"kind": "ranged",
		"action_type": "ranged",
		"from": Vector2i(2, 4),
		"to": Vector2i(5, 4),
		"element": element_id,
	}


func _elemental_presentation(effect: Dictionary, progress: float, element_id: String) -> Dictionary:
	var focus_colors: Dictionary = {
		"earth": Color("b99b69"),
		"air": Color("bde9f6"),
		"lightning": Color("fff28a"),
		"ice": Color("93dcff"),
	}
	var focus_color: Color = focus_colors.get(element_id, Color.WHITE)
	return {
		"focus_actor_keys": ["player"],
		"focus_actor_color": focus_color,
		"focus_tiles": [effect.get("to", Vector2i(-1, -1))],
		"focus_color": Color(focus_color.r, focus_color.g, focus_color.b, 0.16),
		"effect": effect,
		"effect_progress": progress,
	}


func _elemental_combat_state(source: Dictionary) -> Dictionary:
	var combat_state: Dictionary = source.duplicate(true)
	combat_state["player"] = {
		"pos": Vector2i(2, 4),
		"hp": 24,
		"max_hp": 24,
		"block": 0,
		"stoneskin": 0,
	}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["cards_played_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state.erase("player_turn_restrictions")
	combat_state["enemies"] = [{
		"id": 1,
		"type": "crawler",
		"pos": Vector2i(5, 4),
		"hp": 100,
		"max_hp": 100,
		"block": 0,
		"stoneskin": 0,
	}]
	combat_state["terrain"] = []
	combat_state["traps"] = []
	combat_state["illusions"] = []
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["firebrand_volley"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	return combat_state


func _install_combat_state(instance: Node, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_reset_card_resolution")
	instance.set("_animation_lock", false)
	instance.set("_card_play_count_override", -1)
	instance.call("_refresh_ui")


func _first_combat_coord(run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			return coord
	return Vector2i.ZERO


func _render_and_capture(instance: Node, combat_state: Dictionary, presentation: Dictionary, file_name: String) -> void:
	instance.call("_render_board_state", combat_state, presentation)
	await process_frame
	await process_frame
	await _save_screenshot("%s/%s" % [OUTPUT_DIR, file_name])


func _requested_elements() -> PackedStringArray:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--elements="):
			continue
		var requested := PackedStringArray()
		for element_id: String in argument.trim_prefix("--elements=").split(",", false):
			if element_id in ELEMENTS:
				requested.append(element_id)
		if not requested.is_empty():
			return requested
	return ELEMENTS


func _save_screenshot(output_path: String) -> void:
	if _capture_viewport == null:
		_failures.append("Screenshot viewport should exist for %s" % output_path.get_file())
		return
	var image: Image = _capture_viewport.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1920, 1080), "%s should render at 1920x1080" % output_path.get_file())
	var error: Error = image.save_png(output_path)
	_expect(error == OK, "Should save %s" % output_path.get_file())


func _settle() -> void:
	await process_frame
	await process_frame


func _clear_probe_output() -> void:
	var dir := DirAccess.open(OUTPUT_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			dir.remove(file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
