extends "res://tests/runtime_frame_performance_benchmark.gd"

# Ordinary combat alongside the deliberately equipment-heavy depth-13 matrix.
# Use the same live pointer routing, rendering boundaries and semantic oracles.
var _profile: String = "early"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_profile = OS.get_environment("LABYRINTH_COMBAT_PROFILE")
	if _profile not in ["early", "middle"]:
		_profile = "early"
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 1000
	root.mode = Window.MODE_WINDOWED
	root.size = _viewport_size
	_render_pulse = RenderPulse.new()
	_render_pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_render_pulse.size = Vector2.ONE
	_render_pulse.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	root.add_child(_render_pulse)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://representative_profile.json")
	ProgressionStore.set_run_storage_path("user://representative_run.save")
	var settings_store = load("res://scripts/settings_store.gd")
	settings_store.set_storage_path("user://representative_settings.json")
	var settings: Dictionary = settings_store.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = OS.get_environment("LABYRINTH_RUNTIME_PERF_REDUCED_MOTION") == "1"
	settings_store.save_settings(settings)
	await process_frame
	var instance: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	root.add_child(instance)
	var sampler := FrameSampler.new()
	sampler.request_render = _render_pulse.pulse
	sampler.observe_frame = _observe_probe_focus
	sampler.measured_viewport_rid = root.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(sampler.measured_viewport_rid, true)
	root.add_child(sampler)
	_expect(await _acquire_probe_window_focus(), "representative combat needs a foreground window")
	await _settle_probe_window()
	var initial: Dictionary = _install_stress_combat(instance, "specialists")
	await _settle_render_frames(WARMUP_FRAMES)
	var fixture: Dictionary = {
		"depth": initial.get("room_depth", 0), "hand": _workload_hand(),
		"relics": initial.get("relics", []), "skills": initial.get("skill_ids", []),
		"enemies": initial.get("enemies", []), "player": initial.get("player", {}),
		"illusions": initial.get("illusions", []), "surfaces": initial.get("surfaces", {}),
	}
	await _save_root_screenshot(_profile + "_idle.png")
	var idle: Dictionary = await _measure_idle(sampler)
	var previews: Dictionary = await _measure_preview_matrix(instance)
	var actions: Dictionary = await _measure_action_matrix(instance, sampler)
	var abilities: Dictionary = await _measure_ability_action_matrix(instance, sampler)
	var movement: Dictionary = await _measure_movement_pool_action(instance, sampler)
	var rounds: Dictionary = await _measure_enemy_round_matrix(instance, sampler)
	var visuals: Dictionary = await _capture_wildfire_action_visuals(instance)
	_expect(_unfocused_observation_count == 0, "representative timings must remain focused throughout")
	_expect(root.size == _viewport_size and root.get_texture().get_size() == Vector2(_viewport_size), "representative proof retains 1920x1080 pixels")
	var result: Dictionary = {
		"workload_id": "representative_combat_v1", "profile": _profile,
		"sample_boundary": "RenderingServer.frame_post_draw_v1", "fixture": fixture,
		"viewport": "1920x1080", "ui_scale": 1.0,
		"reduced_motion": settings["reduced_motion"],
		"section_instrumentation_enabled": _section_instrumentation_enabled(),
		"renderer": RenderingServer.get_video_adapter_name(),
		"rendering_method": ProjectSettings.get_setting("rendering/renderer/rendering_method"),
		"probe_unfocused_observations": _unfocused_observation_count,
		"probe_focus_pauses": _focus_pause_count,
		"idle": idle, "preview_matrix": previews, "action_matrix": actions,
		"ability_action_matrix": abilities, "movement_pool_action": movement,
		"enemy_round_matrix": rounds, "action_visual_proof": visuals,
		"semantic_errors": _errors,
	}
	print("REPRESENTATIVE COMBAT RESULT: " + JSON.stringify(result))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	instance.queue_free()
	sampler.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _workload_hand() -> Array[String]:
	var hand: Array[String]
	hand.append_array(["pale_spark", "sidestep_slash", "glowstone_ward", "gust_step", "wildfire_halo"])
	if _profile == "middle":
		hand.append("shadow_step")
	return hand

func _benchmark_composition_ids() -> Array[String]:
	var result: Array[String]
	result.append("specialists")
	return result

func _benchmark_manual_skill_ids() -> Array[String]:
	var result: Array[String]
	if _profile == "middle": result.append_array(["quick_wits", "encore"])
	return result

func _composition_enemies(_composition: String) -> Array:
	var enemies: Array = [
		_enemy(1, "crawler", Vector2i(3, 2)),
		_enemy(2, "harrier", Vector2i(6, 4)),
		_enemy(3, "cinder_ooze", Vector2i(4, 6)),
	]
	if _profile == "middle":
		enemies.append(_enemy(4, "frostglass_lancer", Vector2i(2, 5)))
		enemies.append(_enemy(5, "chainbound_gaoler", Vector2i(6, 6)))
	return enemies

func _enrich_enemy_states(_state: Dictionary) -> void:
	pass # Keep authored HP/status instead of the 999-HP stress targets.

func _stress_illusions() -> Array:
	return [] if _profile == "early" else [{"id": 1, "pos": Vector2i(2, 3), "hp": 8, "max_hp": 8}]

func _stress_traps() -> Array:
	return [] if _profile == "early" else super._stress_traps().slice(0, 1)

func _stress_loot() -> Array:
	return [] if _profile == "early" else super._stress_loot().slice(0, 1)

func _stress_terrain() -> Array:
	return super._stress_terrain().slice(0, 1 if _profile == "early" else 3)

func _enemy(enemy_id: int, enemy_type: String, pos: Vector2i) -> Dictionary:
	var generator = preload("res://scripts/room_generator.gd").new()
	var hp: int = generator._scaled_enemy_max_hp(enemy_type, 2 if _profile == "early" else 7)
	return {"id": enemy_id, "type": enemy_type, "pos": pos, "hp": hp, "max_hp": hp}

func _install_stress_combat(instance: Node, _composition: String) -> Dictionary:
	instance.call("_cancel_drag_play")
	instance.call("_cancel_card_selection")
	instance.call("_cancel_combat_skill_card_selection")
	instance.call("_close_skill_status_popover", false)
	instance.call("_cancel_surface_skill_selection")
	instance.call("_reset_card_resolution")
	var skills: Array[String]
	var relics: Array[String]
	if _profile == "middle":
		skills.append_array(["quick_wits", "encore", "measured_breath", "sure_footed"])
		relics.append_array(["ember_lens", "pilgrim_boots", "mirror_shard"])
	var depth: int = 2 if _profile == "early" else 7
	var layout: Dictionary = {
		"name": "Early Combat" if _profile == "early" else "Middle Combat",
		"coord": Vector2i(depth, 0), "depth": depth, "section_index": 0 if depth == 2 else 1,
		"type": "combat", "element": "none" if _profile == "early" else "ice",
		"grid": _stress_grid(), "player_start": Vector2i(4, 4),
		"enemies": _composition_enemies("specialists"), "traps": _stress_traps(),
		"loot": _stress_loot(), "terrain": _stress_terrain(),
		"surfaces": {} if _profile == "early" else {"3,4": {"elemental": "ice", "rubble": false}, "5,5": {"elemental": "fire", "rubble": false}},
	}
	var hand: Array[String] = _workload_hand()
	var state: Dictionary = _combat.create_combat(90210 + depth, layout, {
		"hp": 80, "max_hp": 80, "deck_cards": hand, "relics": relics, "skill_ids": skills,
		"hand_size": hand.size(), "cards_per_turn": 3, "draw_per_turn": hand.size(), "heal_bonus": 0,
	})
	state["illusions"] = _stress_illusions()
	state["deck"]["hand"] = hand
	state["deck"]["draw"] = hand + hand
	state["deck"]["discard"] = hand.duplicate()
	state["deck"]["burned"] = []
	var progression: Dictionary = ContextualCombatTutorial.complete_tutorial(ProgressionStore.default_data())
	progression["level"] = 1 if _profile == "early" else 5
	progression["skill_ids"] = skills.duplicate()
	progression["run_counter"] = 2
	instance.set("_progression", progression)
	var run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["depth"] = depth
	run["current_room"] = layout["coord"]
	run["current_room_layout"] = layout.duplicate(true)
	run["skill_ids"] = skills.duplicate()
	run["relics"] = relics.duplicate()
	run["progression"] = progression.duplicate(true)
	run["combat_state"] = state
	instance.set("_run_state", run)
	instance.set("_combat_state", state)
	instance.set("_animation_lock", false)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	_expect(_combat.combat_outcome(state).is_empty(), "representative fixture starts in active combat")
	return (instance.get("_combat_state") as Dictionary).duplicate(true)
