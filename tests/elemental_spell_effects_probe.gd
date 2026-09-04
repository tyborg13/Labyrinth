extends "res://tests/elemental_ranged_attack_visual_probe.gd"

# Shares the production-board fixture and depth checks with the established probe.
# Default: open-stage stills plus separate depth proof. --capture-sequence: every authored animation frame.
# --showcase: continuously display all requested spells at their production cadence.
const SPELL_OUTPUT_DIR: String = "user://probes/elemental_spell_effects_v1"
const ALL_ELEMENTS: PackedStringArray = ["fire", "earth", "air", "lightning", "ice"]

var _peak_image: Image = null


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SPELL_OUTPUT_DIR))
	await _capture_elemental_states()
	print(ProjectSettings.globalize_path(SPELL_OUTPUT_DIR))
	if _failures.is_empty():
		print("ELEMENTAL SPELL EFFECTS VISUAL PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("ELEMENTAL SPELL EFFECTS VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_elemental_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Spell proof should load the production run scene")
	if packed == null:
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "ElementalSpells1920x1080"
	_capture_viewport.size = Vector2i(1920, 1080)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if "--showcase" in OS.get_cmdline_user_args():
		var container := SubViewportContainer.new()
		container.size = Vector2(1920, 1080)
		root.add_child(container)
		container.add_child(_capture_viewport)
		DisplayServer.window_set_size(Vector2i(1920, 1080))
		_capture_viewport.gui_disable_input = true
	else:
		root.add_child(_capture_viewport)
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	_expect(instance.get_viewport().get_visible_rect().size == Vector2(1920, 1080), "Spell proof should render a 1920x1080 logical canvas")
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(8585, ProgressionStore.default_data()))
	await _settle()
	var combat_coord: Vector2i = _first_combat_coord(run_engine, instance.get("_run_state") as Dictionary)
	_expect(combat_coord != Vector2i.ZERO, "Spell proof should find an authored combat room")
	if combat_coord == Vector2i.ZERO:
		return
	await instance.call("_on_map_view_room_selected", combat_coord)
	var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
	if pre_battle_scrim != null and pre_battle_scrim.visible:
		await instance.call("_on_pre_battle_start_pressed")
	await create_timer(0.95).timeout
	await _settle()
	instance.call("_close_dialogue")
	_expect(str((instance.get("_run_state") as Dictionary).get("mode", "")) == "combat", "Spell proof must enter live combat through the Start action")
	_expect(not bool(instance.call("_controller_modal_visible")), "Spell proof must not capture through a pre-battle or other modal overlay")
	if not _failures.is_empty():
		return
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	instance.set("_settings", settings.duplicate(true))
	var depth_combat_state: Dictionary = _elemental_combat_state(instance.get("_combat_state") as Dictionary)
	var combat_state: Dictionary = _open_spell_combat_state(depth_combat_state)
	_install_combat_state(instance, combat_state)
	await _settle()
	_expect_scene_layer_grid(instance, 0)
	_expect(not bool(instance.call("_controller_modal_visible")), "Installing the spell fixture must leave the combat board uncovered")
	if "--showcase" in OS.get_cmdline_user_args() and _failures.is_empty():
		await _showcase(instance, combat_state)
		return
	await _render_and_capture(instance, combat_state, {}, "spells_00_before.png")
	for element_id: String in _requested_elements():
		settings["reduced_motion"] = false
		instance.set("_settings", settings.duplicate(true))
		var preview: Dictionary = _effect_for_element(element_id)
		preview["preview"] = true
		await _render_and_capture(instance, combat_state, _elemental_presentation(preview, 1.0, element_id), "%s_05_preview.png" % element_id)
		_peak_image = null
		await _capture_element_sequence(instance, combat_state, element_id)
		await _render_and_capture(instance, combat_state, {}, "%s_70_cleared.png" % element_id)
		_expect_spell_pixels_changed(instance, element_id, _peak_image, _capture_viewport.get_texture().get_image())
		settings["reduced_motion"] = true
		instance.set("_settings", settings.duplicate(true))
		await _render_and_capture(instance, combat_state, _elemental_presentation(_effect_for_element(element_id), 1.0, element_id, true), "%s_80_reduced_motion.png" % element_id)
	settings["reduced_motion"] = false
	instance.set("_settings", settings.duplicate(true))
	_install_combat_state(instance, depth_combat_state)
	await _settle()
	_expect_scene_depth_fixture(instance)
	await _render_and_capture(instance, depth_combat_state, {}, "spells_90_depth_before.png")
	for element_id: String in _requested_elements():
		var depth_effect: Dictionary = _effect_for_element(element_id)
		var depth_style: String = AttackFxLibrary.style_for_effect(depth_effect)
		var contact: float = AttackFxLibrary.travel_end_progress(depth_style)
		await _render_and_capture(instance, depth_combat_state, _elemental_presentation(depth_effect, lerpf(contact, 1.0, 0.52), element_id), "%s_95_depth_peak.png" % element_id)
		await _render_and_capture(instance, depth_combat_state, _elemental_presentation(depth_effect, lerpf(contact, 1.0, 0.82), element_id), "%s_96_depth_tail.png" % element_id)
	instance.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	_capture_viewport = null
	await process_frame


func _capture_element_sequence(instance: Node, combat_state: Dictionary, element_id: String) -> void:
	var effect: Dictionary = _effect_for_element(element_id)
	var style: String = AttackFxLibrary.style_for_effect(effect)
	_expect(style != AttackFxLibrary.STYLE_DEFAULT, "%s should select its elemental style" % element_id.capitalize())
	var frame_count: int = AttackFxLibrary.animation_frame_count(effect, 6, false)
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	var release_frame: int = maxi(1, roundi(anticipation_end * 0.65 * frame_count))
	var travel_frame: int = roundi(lerpf(anticipation_end, travel_end, 0.42) * frame_count)
	var contact_frame: int = roundi(travel_end * frame_count)
	var impact_span: int = frame_count - contact_frame
	var key_frames: Dictionary = {
		release_frame: "10_release",
		travel_frame: "20_travel",
		contact_frame: "30_contact",
		contact_frame + roundi(impact_span * 0.20): "35_burst",
		contact_frame + roundi(impact_span * 0.52): "40_peak",
		contact_frame + roundi(impact_span * 0.82): "50_tail",
		frame_count: "60_end",
	}
	var capture_sequence: bool = "--capture-sequence" in OS.get_cmdline_user_args()
	for frame: int in range(1, frame_count + 1):
		if not capture_sequence and not key_frames.has(frame):
			continue
		instance.call("_render_board_state", combat_state, _elemental_presentation(effect, float(frame) / frame_count, element_id))
		await _settle()
		if capture_sequence:
			await _save_screenshot("%s_sequence_%03d.png" % [element_id, frame])
		if key_frames.has(frame):
			await _save_screenshot("%s_%s.png" % [element_id, str(key_frames[frame])])
			if str(key_frames[frame]) == "40_peak":
				_peak_image = _capture_viewport.get_texture().get_image()


func _showcase(instance: Node, combat_state: Dictionary) -> void:
	instance.set("_animation_lock", true)
	print("ELEMENTAL SPELL SHOWCASE: looping at production cadence; close the window to finish")
	while is_instance_valid(instance):
		for element_id: String in _requested_elements():
			DisplayServer.window_set_title("Escape the Umbra - %s spell showcase" % element_id.capitalize())
			var effect: Dictionary = _effect_for_element(element_id)
			var style: String = AttackFxLibrary.style_for_effect(effect)
			var frame_count: int = AttackFxLibrary.animation_frame_count(effect, 6, false)
			var duration: float = AttackFxLibrary.animation_duration_seconds_for_style(style)
			for repeat_index: int in range(2):
				instance.call("_render_board_state", combat_state, {})
				await create_timer(0.7).timeout
				var start_msec: int = Time.get_ticks_msec()
				var progress: float = 0.0
				while progress < 1.0:
					progress = minf(1.0, float(Time.get_ticks_msec() - start_msec) / (duration * 1000.0))
					# Quantize to the same authored frames used during card resolution.
					var frame: int = clampi(ceili(progress * frame_count), 1, frame_count)
					instance.call("_render_board_state", combat_state, _elemental_presentation(effect, float(frame) / frame_count, element_id))
					await process_frame
				instance.call("_render_board_state", combat_state, {})
				await create_timer(0.65).timeout


func _elemental_presentation(effect: Dictionary, progress: float, element_id: String, reduced_motion: bool = false) -> Dictionary:
	var presentation: Dictionary = super._elemental_presentation(effect, progress, element_id, reduced_motion)
	if element_id == "fire":
		presentation["focus_actor_color"] = Color("ffc07b")
		presentation["focus_color"] = Color(1.0, 0.75, 0.48, 0.16)
	return presentation


func _requested_elements() -> PackedStringArray:
	for argument: String in OS.get_cmdline_user_args():
		if not argument.begins_with("--elements="):
			continue
		var requested := PackedStringArray()
		for element_id: String in argument.trim_prefix("--elements=").split(",", false):
			if element_id in ALL_ELEMENTS and not element_id in requested:
				requested.append(element_id)
		if not requested.is_empty():
			return requested
	return ALL_ELEMENTS


func _save_screenshot(output_path: String) -> void:
	# Redirect inherited captures into this revision's output directory.
	await super._save_screenshot("%s/%s" % [SPELL_OUTPUT_DIR, output_path.get_file()])


func _expect_spell_pixels_changed(instance: Node, element_id: String, peak_image: Image, cleared_image: Image) -> void:
	_expect(peak_image != null, "%s must provide its peak frame for pixel verification" % element_id)
	if peak_image == null:
		return
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	_expect(board != null and board.is_visible_in_tree(), "Spell pixel verification requires the visible combat board")
	if board == null:
		return
	var target_local: Vector2 = board.call("_tile_center", Vector2i(5, 4)) as Vector2
	var target_screen: Vector2 = board.get_global_transform() * target_local
	var region := Rect2i(Vector2i(target_screen) - Vector2i(220, 280), Vector2i(440, 360))
	region = region.intersection(Rect2i(Vector2i.ZERO, peak_image.get_size()))
	var changed: int = 0
	var samples: int = 0
	var total_delta: float = 0.0
	for y: int in range(region.position.y, region.end.y, 4):
		for x: int in range(region.position.x, region.end.x, 4):
			var before: Color = cleared_image.get_pixel(x, y)
			var after: Color = peak_image.get_pixel(x, y)
			var delta: float = (absf(before.r - after.r) + absf(before.g - after.g) + absf(before.b - after.b)) / 3.0
			total_delta += delta
			if delta > 0.04:
				changed += 1
			samples += 1
	var mean_delta: float = total_delta / float(maxi(1, samples))
	var changed_fraction: float = float(changed) / float(maxi(1, samples))
	print("SPELL PIXEL PROOF %s: target region %s, mean delta %.5f, changed %.3f%%" % [element_id, region, mean_delta, changed_fraction * 100.0])
	_expect(mean_delta >= 0.002 and changed_fraction >= 0.01, "%s peak and cleared target-region pixels must visibly differ; blocked or blank board captures are invalid" % element_id)


func _open_spell_combat_state(depth_state: Dictionary) -> Dictionary:
	var result: Dictionary = depth_state.duplicate(true)
	var grid: Array = result.get("grid", []) as Array
	(grid[3] as Array)[4] = "stone"
	(grid[5] as Array)[6] = "stone"
	result["terrain"] = []
	return result
