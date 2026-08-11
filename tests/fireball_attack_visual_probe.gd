extends SceneTree

const AttackFxLibrary = preload("res://scripts/attack_fx_library.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/fireball_attack_v7"
const PROGRESSION_PATH: String = "user://fireball_attack_probe_progression.json"
const RUN_PATH: String = "user://fireball_attack_probe_run.save"
const SETTINGS_PATH: String = "user://fireball_attack_probe_settings.json"

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
	await _capture_fireball_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("FIREBALL ATTACK VISUAL PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FIREBALL ATTACK VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_fireball_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Fireball proof should load the production run scene")
	if packed == null:
		return
	_capture_viewport = SubViewport.new()
	_capture_viewport.name = "FireballAttack1920x1080"
	_capture_viewport.size = Vector2i(1920, 1080)
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = packed.instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(1920.0, 1080.0),
		"Fireball proof should use the authored 1920x1080 combat viewport"
	)
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(8484, ProgressionStore.default_data()))
	await _settle()
	var run_state: Dictionary = instance.get("_run_state")
	var combat_coord: Vector2i = _first_combat_coord(run_engine, run_state)
	_expect(combat_coord != Vector2i.ZERO, "Fireball proof should find an authored combat room")
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
	var combat_state: Dictionary = _fireball_combat_state(instance.get("_combat_state") as Dictionary)
	_install_combat_state(instance, combat_state)
	await _settle()
	_expect_scene_depth_fixture(instance)
	var effect: Dictionary = {
		"kind": "ranged",
		"action_type": "ranged",
		"from": Vector2i(2, 4),
		"to": Vector2i(5, 4),
		"element": "fire",
	}
	_expect(AttackFxLibrary.uses_fireball(effect), "Probe attack should select the authored fireball style")
	_expect(
		AttackFxLibrary.animation_frame_count(effect, 6, false) == AttackFxLibrary.FIREBALL_ANIMATION_FRAMES,
		"Probe should exercise the complete fireball cadence"
	)

	await _render_and_capture(instance, combat_state, {}, "fireball_00_before.png")
	var preview_effect: Dictionary = effect.duplicate(true)
	preview_effect["preview"] = true
	preview_effect["damage_preview"] = {
		"enemy_1": {
			"hp": 87,
			"hp_loss": 13,
			"lethal": false,
		}
	}
	await _render_and_capture(instance, combat_state, _fireball_presentation(preview_effect, 1.0, false, instance), "fireball_05_preview_curve.png")
	var style: String = AttackFxLibrary.style_for_effect(effect)
	var frame_count: int = AttackFxLibrary.FIREBALL_ANIMATION_FRAMES
	var anticipation_end: float = AttackFxLibrary.anticipation_end_progress(style)
	var travel_end: float = AttackFxLibrary.travel_end_progress(style)
	var release_frame: int = clampi(int(round(anticipation_end * 0.65 * float(frame_count))), 1, frame_count - 4)
	var causality_frame: int = clampi(int(round(lerpf(anticipation_end, travel_end, 0.42) * float(frame_count))), release_frame + 1, frame_count - 3)
	var contact_frame: int = clampi(int(round(travel_end * float(frame_count))), causality_frame + 1, frame_count - 2)
	var impact_span: int = frame_count - contact_frame
	var peak_frame: int = clampi(contact_frame + int(round(float(impact_span) * 0.52)), contact_frame + 1, frame_count - 1)
	var aftermath_frame: int = clampi(contact_frame + int(round(float(impact_span) * 0.84)), peak_frame + 1, frame_count)
	var key_frames: Dictionary = {
		release_frame: "10_release",
		causality_frame: "20_causality",
		contact_frame: "30_contact",
		peak_frame: "40_peak",
		aftermath_frame: "50_aftermath",
	}
	var impact_state: Dictionary = combat_state.duplicate(true)
	impact_state["terrain"] = []
	for frame: int in range(1, AttackFxLibrary.FIREBALL_ANIMATION_FRAMES + 1):
		var progress: float = float(frame) / float(AttackFxLibrary.FIREBALL_ANIMATION_FRAMES)
		var presentation: Dictionary = _fireball_presentation(effect, progress, false, instance)
		var rendered_state: Dictionary = impact_state if progress + 0.0001 >= travel_end else combat_state
		instance.call("_render_board_state", rendered_state, presentation)
		await process_frame
		await process_frame
		var sequence_path: String = "%s/fireball_sequence_%02d.png" % [OUTPUT_DIR, frame]
		await _save_screenshot(sequence_path)
		if key_frames.has(frame):
			await _save_screenshot("%s/fireball_%s.png" % [OUTPUT_DIR, str(key_frames[frame])])
		await create_timer(AttackFxLibrary.FIREBALL_FRAME_SECONDS).timeout

	await _render_and_capture(instance, combat_state, {}, "fireball_50_cleared.png")
	settings["reduced_motion"] = true
	instance.set("_settings", settings.duplicate(true))
	await _render_and_capture(
		instance,
		impact_state,
		_fireball_presentation(effect, 1.0, true, instance),
		"fireball_60_reduced_motion_impact.png"
	)
	instance.queue_free()
	await process_frame
	_capture_viewport.queue_free()
	_capture_viewport = null
	await process_frame


func _fireball_presentation(effect: Dictionary, progress: float, reduced_motion: bool = false, instance: Node = null) -> Dictionary:
	var presentation: Dictionary = {
		"focus_actor_keys": ["player"],
		"focus_actor_color": Color("ffb466"),
		"focus_tiles": [effect.get("to", Vector2i(-1, -1))],
		"focus_color": Color(0.95, 0.62, 0.37, 0.18),
		"effect": effect,
		"effect_progress": progress,
	}
	if not bool(effect.get("preview", false)):
		var style: String = AttackFxLibrary.style_for_effect(effect)
		var contact_progress: float = AttackFxLibrary.travel_end_progress(style)
		if reduced_motion or progress + 0.0001 >= contact_progress:
			var elapsed_seconds: float = 0.0 if reduced_motion else maxf(0.0, progress - contact_progress) * float(AttackFxLibrary.FIREBALL_ANIMATION_FRAMES) * AttackFxLibrary.FIREBALL_FRAME_SECONDS
			presentation["impact_actor_keys"] = ["enemy_1"]
			presentation["floating_texts"] = FloatingCombatText.animate_entries([
				FloatingCombatText.damage_entry(effect.get("to", Vector2i(-1, -1)), "-13", Color("f39779")),
			], elapsed_seconds, reduced_motion)
			if instance != null:
				var destruction_progress: float = 0.52 if reduced_motion else AttackFxLibrary.impact_progress_for_style(style, progress)
				presentation["terrain_destruction_units"] = instance.call(
					"_terrain_destruction_units_at_progress",
					[{
						"id": "fireball_depth_crate",
						"kind": "wooden_crate",
						"pos": Vector2i(6, 4),
					}],
					destruction_progress
				)
	return presentation


func _fireball_combat_state(source: Dictionary) -> Dictionary:
	var combat_state: Dictionary = source.duplicate(true)
	var grid: Array = (combat_state.get("grid", []) as Array).duplicate(true)
	if grid.size() < 9:
		grid.clear()
		for y: int in range(9):
			var row: Array = []
			for x: int in range(9):
				row.append("floor")
			grid.append(row)
	(grid[3] as Array)[4] = "pillar"
	(grid[5] as Array)[6] = "pillar"
	combat_state["grid"] = grid
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
	combat_state["terrain"] = [{
		"id": "fireball_depth_crate",
		"kind": "wooden_crate",
		"pos": Vector2i(6, 4),
		"hp": 50,
		"max_hp": 50,
	}]
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


func _expect_scene_depth_fixture(instance: Node) -> void:
	var board: Control = instance.get_node_or_null("BoardUnderlay/CombatBoard") as Control
	_expect(board != null, "Fireball depth proof should find the production combat board")
	if board == null:
		return
	var scene_layers: Dictionary = board.get("_scene_render_layers_by_tile") as Dictionary
	var background_layer: Control = scene_layers.get(Vector2i(4, 3), null) as Control
	var target_layer: Control = scene_layers.get(Vector2i(5, 4), null) as Control
	var crate_layer: Control = scene_layers.get(Vector2i(6, 4), null) as Control
	var foreground_layer: Control = scene_layers.get(Vector2i(6, 5), null) as Control
	_expect(scene_layers.size() == 81, "Fireball depth proof should retain all 81 tiles as independently sorted scene layers")
	_expect(
		background_layer != null
		and target_layer != null
		and crate_layer != null
		and foreground_layer != null
		and background_layer.get_index() < target_layer.get_index()
		and target_layer.get_index() < crate_layer.get_index()
		and crate_layer.get_index() < foreground_layer.get_index(),
		"Fireball depth proof should sort its rear pillar, target, front crate, and front pillar in world-depth order"
	)


func _first_combat_coord(run_engine: RunEngine, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			return coord
	return Vector2i.ZERO


func _render_and_capture(instance: Node, combat_state: Dictionary, presentation: Dictionary, file_name: String) -> void:
	instance.call("_render_board_state", combat_state, presentation)
	await process_frame
	await _save_screenshot("%s/%s" % [OUTPUT_DIR, file_name])


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
