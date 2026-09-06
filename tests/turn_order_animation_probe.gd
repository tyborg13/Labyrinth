extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const TURN_ORDER_BACKING_PATH: String = "res://assets/art/ui/turn_order_brush_backing_v2.png"

func _initialize() -> void:
	print("turn order probe: start")
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute("user://probes")
	ProgressionStore.set_storage_path("user://labyrinth_progression_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_probe.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	print("turn order probe: scene ready")
	var probe_run_engine := RunEngine.new()
	instance.call("_load_run_state", probe_run_engine.create_new_run(123, ProgressionStore.default_data()))
	await process_frame
	await process_frame
	print("turn order probe: run loaded")
	var run_state: Dictionary = instance.get("_run_state")
	var run_engine = instance.get("_run_engine")
	var combat_coord: Vector2i = Vector2i.ZERO
	for coord: Vector2i in run_engine.available_moves(run_state):
		var room: Dictionary = run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			combat_coord = coord
			break
	if combat_coord == Vector2i.ZERO:
		push_error("No combat room available for turn order animation probe.")
		quit(1)
		return
	print("turn order probe: entering combat")
	run_state = probe_run_engine.move_to_pre_battle(run_state, combat_coord)
	run_state = probe_run_engine.begin_pre_battle_combat(run_state)
	instance.call("_load_run_state", run_state)
	await process_frame
	await process_frame
	print("turn order probe: combat ready")
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	_assert_complete_initial_turn_order(instance, combat_state)
	_assert_turn_order_label(instance)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_backing_texture_has_transparent_bleed()
	_assert_turn_order_badges_match_relative_clocks(instance, combat_state)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_00_stable.png")
	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	print("turn order probe: animating turn consumption")
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await create_timer(0.10).timeout
	await process_frame
	_assert_single_turn_order_exit(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_01_turn_exit.png")
	await create_timer(0.20).timeout
	await process_frame
	_assert_turn_order_width_locked(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_02_turn_collapse.png")
	await create_timer(0.20).timeout
	await process_frame
	await _save_root_screenshot("user://probes/turn_order_motion_v5_03_turn_insert.png")
	await create_timer(0.55).timeout
	await process_frame
	_assert_turn_order_slot_count(instance, 10)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, scheduled_state)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_04_turn_settled.png")

	print("turn order probe: animating committed Time shift")
	_set_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame
	var time_shifted_state: Dictionary = combat_state.duplicate(true)
	time_shifted_state["player_turn_time_spent"] = int(combat_state.get("player_turn_time_spent", 0)) + 9
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), time_shifted_state.duplicate(true))
	await create_timer(0.12).timeout
	await process_frame
	_assert_active_player_persists(instance)
	_assert_reflow_in_progress(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_05_time_reflow.png")
	await create_timer(0.48).timeout
	await process_frame
	_assert_turn_order_badges_match_relative_clocks(instance, time_shifted_state)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_06_time_settled.png")

	print("turn order probe: animating enemy defeat")
	_set_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame
	var defeated_actor_key: String = _first_enemy_turn_actor_key(instance, combat_state)
	var defeated_state: Dictionary = _state_with_first_enemy_defeated(combat_state)
	instance.call("_animate_turn_order_alongside_defeats", combat_state.duplicate(true), defeated_state.duplicate(true))
	await create_timer(0.12).timeout
	await process_frame
	_assert_actor_waiting_for_shadow_echo(instance, defeated_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_07_enemy_board_death_active.png")
	await _wait_for_actor_shadow_progress(instance, defeated_actor_key, 0.42)
	_assert_actor_shadow_dissolving(instance, defeated_actor_key, 0.38, 0.78)
	_assert_enemy_board_dissolve_active(instance, defeated_actor_key)
	_assert_active_player_persists(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v6_08_enemy_overlapping_dissolve.png")
	await _wait_for_enemy_board_dissolve_to_finish(instance, defeated_actor_key)
	_assert_enemy_absent_from_board(instance, defeated_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v6_09_enemy_board_settled.png")
	await _wait_for_turn_order_to_settle(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v6_10_enemy_cleanup_settled.png")
	await process_frame
	_assert_actor_absent(instance, defeated_actor_key)
	_assert_vertical_turn_order_geometry(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_11_enemy_death_settled.png")

	print("turn order probe: verifying reduced motion")
	_set_probe_combat_state(instance, combat_state)
	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_animate_turn_order_alongside_defeats", combat_state.duplicate(true), defeated_state.duplicate(true))
	await process_frame
	_assert_reduced_motion_settled(instance, defeated_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_12_reduced_motion_settled.png")
	reduced_settings["reduced_motion"] = false
	instance.set("_settings", reduced_settings)

	print("turn order probe: animating production Burn defeat")
	var burn_boundary: Dictionary = _burn_death_production_boundary(instance, combat_state)
	var burn_before_state: Dictionary = burn_boundary.get("before_state", {}) as Dictionary
	var burn_after_state: Dictionary = burn_boundary.get("after_state", {}) as Dictionary
	var burn_steps: Array = burn_boundary.get("steps", []) as Array
	var burn_actor_key: String = str(burn_boundary.get("actor_key", ""))
	_set_probe_combat_state(instance, burn_before_state)
	await process_frame
	await process_frame
	var animated_burn_state: Dictionary = burn_before_state.duplicate(true)
	instance.call("_animate_enemy_phase_steps", animated_burn_state, burn_steps)
	await create_timer(0.60).timeout
	await process_frame
	_assert_actor_waiting_for_shadow_echo(instance, burn_actor_key)
	_assert_enemy_defeated_in_state(burn_after_state, burn_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_13_burn_board_death_active.png")
	await _wait_for_actor_shadow_progress(instance, burn_actor_key, 0.42)
	_assert_actor_shadow_dissolving(instance, burn_actor_key, 0.38, 0.78)
	_assert_enemy_board_dissolve_active(instance, burn_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v6_14_burn_overlapping_dissolve.png")
	await _wait_for_enemy_board_dissolve_to_finish(instance, burn_actor_key)
	_assert_enemy_absent_from_board(instance, burn_actor_key)
	await _save_root_screenshot("user://probes/turn_order_motion_v6_15_burn_board_settled.png")
	await _wait_for_turn_order_to_settle(instance)
	await process_frame
	_assert_actor_absent(instance, burn_actor_key)
	_assert_vertical_turn_order_geometry(instance)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_16_burn_death_settled.png")

	var tied_state: Dictionary = _equal_time_player_tie_state(instance, combat_state.duplicate(true))
	_set_probe_combat_state(instance, tied_state)
	await process_frame
	_assert_player_wins_equal_time_forecast(instance, tied_state)
	_assert_turn_order_badges_match_relative_clocks(instance, tied_state)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_17_player_tie_forecast.png")
	var tied_scheduled_state: Dictionary = combat_engine.finish_player_activation(tied_state.duplicate(true))
	_assert_player_wins_equal_time_schedule(combat_engine, tied_scheduled_state)
	_set_probe_combat_state(instance, tied_scheduled_state)
	await process_frame
	_assert_turn_order_badges_match_relative_clocks(instance, tied_scheduled_state)
	await _save_root_screenshot("user://probes/turn_order_motion_v5_18_player_tie_scheduled.png")
	print("turn order probe: done")
	print(ProjectSettings.globalize_path("user://probes"))
	instance.queue_free()
	await process_frame
	quit()

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var image: Image = root.get_viewport().get_texture().get_image()
	# macOS may expose a Retina-sized backing texture even when the authored
	# logical canvas is 1920x1080. Normalize proof to the rubric's exact canvas.
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png(output_path)

func _equal_time_player_tie_state(instance: Node, state: Dictionary) -> Dictionary:
	var combat_engine = instance.get("_combat_engine")
	var queue: Array = (state.get("turn_queue", []) as Array).duplicate(true)
	if combat_engine == null or queue.is_empty():
		push_error("Turn-order tie probe requires a combat engine and one queued enemy.")
		quit(1)
		return state
	var tied_time: int = int(state.get("initiative_clock", 0)) + int(combat_engine.player_base_initiative(state))
	var enemy_entry: Dictionary = (queue[0] as Dictionary).duplicate(true)
	enemy_entry["time"] = tied_time
	enemy_entry["seq"] = 1
	state["turn_queue"] = [enemy_entry]
	state["activation_seq"] = 1
	state["player_turn_time_spent"] = 0
	return state

func _set_probe_combat_state(instance: Node, state: Dictionary) -> void:
	instance.set("_combat_state", state.duplicate(true))
	instance.set("_turn_order_animating", false)
	instance.set("_turn_order_source_signature", "<tie-probe-reset>")
	instance.set("_turn_order_render_signature", "<tie-probe-reset>")
	instance.call("_refresh_turn_order_bar")

func _first_enemy_turn_actor_key(instance: Node, state: Dictionary) -> String:
	var combat_engine = instance.get("_combat_engine")
	for entry_var: Variant in combat_engine.current_turn_order(state, 10):
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		if str(entry.get("kind", "")) == "enemy":
			return "enemy:%s" % str(entry.get("actor_key", ""))
	push_error("Turn-order defeat probe requires a visible enemy entry.")
	quit(1)
	return ""

func _state_with_first_enemy_defeated(state: Dictionary) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var enemies: Array = (result.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		if int(enemy.get("hp", 0)) <= 0:
			continue
		enemy["hp"] = 0
		enemies[index] = enemy
		result["enemies"] = enemies
		return result
	push_error("Turn-order defeat probe requires a living enemy.")
	quit(1)
	return result

func _burn_death_production_boundary(instance: Node, state: Dictionary) -> Dictionary:
	var before_state: Dictionary = state.duplicate(true)
	var enemies: Array = (before_state.get("enemies", []) as Array).duplicate(true)
	var enemy_index: int = -1
	for index: int in range(enemies.size()):
		if typeof(enemies[index]) != TYPE_DICTIONARY:
			continue
		var candidate: Dictionary = enemies[index] as Dictionary
		if int(candidate.get("hp", 0)) > 0:
			enemy_index = index
			break
	if enemy_index < 0:
		push_error("Burn production-path probe requires a living enemy.")
		quit(1)
		return {}
	var enemy: Dictionary = (enemies[enemy_index] as Dictionary).duplicate(true)
	enemy["hp"] = 1
	enemy["burn"] = 5
	enemies[enemy_index] = enemy
	before_state["enemies"] = enemies
	var combat_engine = instance.get("_combat_engine")
	before_state["current_actor"] = combat_engine.call(
		"_enemy_actor_entry",
		before_state,
		enemy,
		int(before_state.get("initiative_clock", 0)),
		int(before_state.get("activation_seq", 0))
	) as Dictionary
	var actor_key: String = _first_enemy_turn_actor_key(instance, before_state)
	var resolution_input: Dictionary = before_state.duplicate(true)
	var burn_result: Dictionary = combat_engine.call("_resolve_enemy_start_of_turn", resolution_input, enemy_index) as Dictionary
	var burn_steps: Array = burn_result.get("steps", []) as Array
	var after_state: Dictionary = burn_result.get("state", resolution_input) as Dictionary
	var has_lethal_burn_step: bool = false
	for step_var: Variant in burn_steps:
		if typeof(step_var) != TYPE_DICTIONARY:
			continue
		var step: Dictionary = step_var as Dictionary
		if str(step.get("kind", "")) == "status_damage" and str(step.get("label", "")) == "Burn":
			has_lethal_burn_step = true
			break
	if not has_lethal_burn_step:
		push_error("Burn production-path probe did not generate an enemy status-damage step.")
		quit(1)
	return {
		"before_state": before_state,
		"after_state": after_state,
		"steps": burn_steps,
		"actor_key": actor_key
	}

func _assert_enemy_defeated_in_state(state: Dictionary, actor_key: String) -> void:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if "enemy:enemy_%d" % int(enemy.get("id", -1)) != actor_key:
			continue
		if int(enemy.get("hp", 0)) <= 0:
			return
	push_error("Production Burn boundary did not defeat %s." % actor_key)
	quit(1)

func _assert_active_player_persists(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during Time reflow probe.")
		quit(1)
		return
	for slot: Control in _turn_order_slot_controls(bar):
		if str(slot.get_meta("turn_order_actor_key", "")) != "player:player":
			continue
		if str(slot.get_meta("turn_order_animation_role", "")) != "active":
			continue
		if slot.modulate.a < 0.99 or slot.position.x > 8.0:
			push_error("Committing Time should preserve the active player portrait while future turns reflow.")
			quit(1)
		return
	push_error("Time reflow lost the active player portrait.")
	quit(1)

func _assert_reflow_in_progress(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null or not bool(instance.get("_turn_order_animating")):
		push_error("Time change should keep the turn rail in an authored reflow transition.")
		quit(1)
		return
	for slot: Control in _turn_order_slot_controls(bar):
		var rail_index: int = int(slot.get_meta("turn_order_rail_index", -1))
		if rail_index < 0:
			continue
		var settled_position: Vector2 = instance.call("_turn_order_slot_position", rail_index) as Vector2
		if slot.position.distance_to(settled_position) > 1.0:
			return
	push_error("Time change did not visibly move any turn-order portrait between slots.")
	quit(1)

func _assert_actor_waiting_for_shadow_echo(instance: Node, actor_key: String) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var matching: int = 0
	if bar != null:
		for slot: Control in _turn_order_slot_controls(bar):
			if str(slot.get_meta("turn_order_actor_key", "")) != actor_key:
				continue
			matching += 1
			var prepared_effect: Control = slot.get_node_or_null("TurnOrderShadowDissolve") as Control
			if prepared_effect != null and float(prepared_effect.call("dissolve_progress")) > 0.04:
				push_error("%s visibly began its Turn Clock dissolution before the delayed death echo." % actor_key)
				quit(1)
				return
			var rail_index: int = int(slot.get_meta("turn_order_rail_index", -1))
			var settled_position: Vector2 = instance.call("_turn_order_slot_position", rail_index) as Vector2
			if slot.position.distance_to(settled_position) > 0.5 or slot.modulate.a < 0.99:
				push_error("%s should remain settled and readable while the board death owns the first beat." % actor_key)
				quit(1)
				return
	if matching <= 0:
		push_error("Delayed death echo lost every scheduled portrait for %s before its dissolution began." % actor_key)
		quit(1)

func _assert_actor_shadow_dissolving(
	instance: Node,
	actor_key: String,
	minimum_progress: float = 0.04,
	maximum_progress: float = 0.96
) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var matching: int = 0
	var dissolving: int = 0
	if bar != null:
		for slot: Control in _turn_order_slot_controls(bar):
			if str(slot.get_meta("turn_order_actor_key", "")) != actor_key:
				continue
			matching += 1
			var effect: Control = slot.get_node_or_null("TurnOrderShadowDissolve") as Control
			if effect == null:
				continue
			var progress: float = float(effect.call("dissolve_progress"))
			if (
				str(slot.get_meta("turn_order_removal_style", "")) == "shadow_dissolve"
				and effect.visible
				and progress > minimum_progress
				and progress < maximum_progress
			):
				dissolving += 1
	if matching <= 0 or dissolving != matching:
		push_error("Every scheduled portrait for %s should share the delayed shadow dissolution (%d/%d dissolving)." % [actor_key, dissolving, matching])
		quit(1)

func _assert_enemy_board_dissolve_active(instance: Node, actor_key: String) -> void:
	var board: Control = instance.get("board_view") as Control
	var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
	var board_actor_key: String = actor_key.substr(6) if actor_key.begins_with("enemy:") else actor_key
	if not effects.has(board_actor_key):
		push_error("Turn Clock dissolution must overlap the battlefield death for %s." % actor_key)
		quit(1)

func _wait_for_turn_order_to_settle(instance: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + 1600
	while bool(instance.get("_turn_order_animating")) and Time.get_ticks_msec() < deadline:
		await process_frame
	if bool(instance.get("_turn_order_animating")):
		push_error("Overlapping defeat cleanup failed to settle within its bounded duration.")
		quit(1)

func _assert_enemy_absent_from_board(instance: Node, actor_key: String) -> void:
	var board: Control = instance.get("board_view") as Control
	if board == null:
		push_error("Combat board missing while checking settled defeat cleanup.")
		quit(1)
		return
	var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
	var board_actor_key: String = actor_key.substr(6) if actor_key.begins_with("enemy:") else actor_key
	if effects.has(board_actor_key):
		push_error("%s was still dissolving on the battlefield after its completion." % actor_key)
		quit(1)

func _wait_for_enemy_board_dissolve_to_finish(instance: Node, actor_key: String) -> void:
	var board: Control = instance.get("board_view") as Control
	if board == null:
		push_error("Combat board missing while waiting for the battlefield death to finish.")
		quit(1)
		return
	var board_actor_key: String = actor_key.substr(6) if actor_key.begins_with("enemy:") else actor_key
	var saw_effect: bool = false
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1000000.0 < 2.0:
		var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
		if effects.has(board_actor_key):
			saw_effect = true
		elif saw_effect:
			return
		await process_frame
	push_error("Battlefield dissolve for %s did not finish within the probe window." % actor_key)
	quit(1)

func _wait_for_actor_shadow_progress(instance: Node, actor_key: String, target_progress: float) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var started_usec: int = Time.get_ticks_usec()
	while float(Time.get_ticks_usec() - started_usec) / 1000000.0 < 2.0:
		var matching: int = 0
		var ready: int = 0
		if bar != null:
			for slot: Control in _turn_order_slot_controls(bar):
				if str(slot.get_meta("turn_order_actor_key", "")) != actor_key:
					continue
				matching += 1
				var effect: Control = slot.get_node_or_null("TurnOrderShadowDissolve") as Control
				if effect != null and float(effect.call("dissolve_progress")) >= target_progress:
					ready += 1
		if matching > 0 and ready == matching:
			return
		await process_frame
	push_error("Turn Clock dissolve for %s did not reach %.2f progress within the probe window." % [actor_key, target_progress])
	quit(1)

func _assert_actor_absent(instance: Node, actor_key: String) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing after enemy defeat.")
		quit(1)
		return
	for slot: Control in _turn_order_slot_controls(bar):
		if str(slot.get_meta("turn_order_actor_key", "")) == actor_key:
			push_error("Defeated actor %s remained in the settled turn order." % actor_key)
			quit(1)
			return

func _assert_reduced_motion_settled(instance: Node, removed_actor_key: String) -> void:
	if bool(instance.get("_turn_order_animating")):
		push_error("Reduced Motion should bypass turn-order transition movement.")
		quit(1)
	_assert_actor_absent(instance, removed_actor_key)
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		return
	for slot: Control in _turn_order_slot_controls(bar):
		var rail_index: int = int(slot.get_meta("turn_order_rail_index", -1))
		var settled_position: Vector2 = instance.call("_turn_order_slot_position", rail_index) as Vector2
		if slot.position.distance_to(settled_position) > 0.5 or not slot.scale.is_equal_approx(Vector2.ONE) or slot.modulate.a < 0.99:
			push_error("Reduced Motion should render only settled turn-order slots.")
			quit(1)
			return

func _assert_player_wins_equal_time_forecast(instance: Node, state: Dictionary) -> void:
	var combat_engine = instance.get("_combat_engine")
	var order: Array = combat_engine.current_turn_order(state, 3)
	if order.size() < 3:
		push_error("Turn-order tie forecast should show the active player and both tied future actors.")
		quit(1)
		return
	var player_entry: Dictionary = order[1] as Dictionary
	var enemy_entry: Dictionary = order[2] as Dictionary
	if str(player_entry.get("kind", "")) != "player" or str(enemy_entry.get("kind", "")) != "enemy" or int(player_entry.get("time", -1)) != int(enemy_entry.get("time", -2)):
		push_error("Turn-order tie forecast should place the player's tied future slot before the enemy.")
		quit(1)

func _assert_player_wins_equal_time_schedule(combat_engine: RefCounted, state: Dictionary) -> void:
	var order: Array = combat_engine.current_turn_order(state, 2)
	if order.size() < 2:
		push_error("Turn-order tied schedule should contain the player and enemy.")
		quit(1)
		return
	var player_entry: Dictionary = order[0] as Dictionary
	var enemy_entry: Dictionary = order[1] as Dictionary
	if str(player_entry.get("kind", "")) != "player" or str(enemy_entry.get("kind", "")) != "enemy" or int(player_entry.get("time", -1)) != int(enemy_entry.get("time", -2)):
		push_error("Committed turn order should keep the tied player ahead of the enemy.")
		quit(1)

func _assert_single_turn_order_exit(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during animation probe.")
		quit(1)
		return
	var exiting: int = 0
	for child_index: int in range(bar.get_child_count()):
		var child: Control = bar.get_child(child_index) as Control
		if child == null:
			continue
		if child.position.y < -2.0 or child.modulate.a < 0.98:
			exiting += 1
	if exiting != 1:
		push_error("Expected exactly one turn order entry exiting; found %d." % exiting)
		quit(1)

func _assert_turn_order_width_locked(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during animation probe.")
		quit(1)
		return
	var locked_width: float = float(instance.get("_turn_order_panel_locked_width"))
	if locked_width <= 0.0:
		push_error("Turn order panel width was not locked during animation.")
		quit(1)
		return
	if absf(panel.custom_minimum_size.x - locked_width) > 0.5:
		push_error("Turn order panel width changed during animation.")
		quit(1)

func _assert_turn_order_slot_count(instance: Node, max_count: int) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		push_error("Turn order bar missing during slot-count probe.")
		quit(1)
		return
	if _turn_order_slot_controls(bar).size() > max_count:
		push_error("Turn order bar showed %d slots; expected at most %d." % [_turn_order_slot_controls(bar).size(), max_count])
		quit(1)

func _assert_complete_initial_turn_order(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var combat_engine = instance.get("_combat_engine")
	if bar == null or panel == null or combat_engine == null:
		push_error("Turn order initialization probe is missing the bar, panel, or engine.")
		quit(1)
		return
	var expected: Array = combat_engine.current_turn_order(state, 10)
	if expected.is_empty():
		push_error("Turn order initialization fixture produced no expected entries.")
		quit(1)
		return
	if _turn_order_slot_controls(bar).size() != expected.size():
		push_error("Turn order showed %d of %d entries on room entry before any action." % [_turn_order_slot_controls(bar).size(), expected.size()])
		quit(1)
		return
	if panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null:
		push_error("Turn order should present floating portrait frames, not a full-height ornamental enclosure.")
		quit(1)
	if bar.get_node_or_null("TurnOrderOverflowBadge") != null:
		push_error("The expanded rail should show scheduled portraits directly, not a +N overflow label.")
		quit(1)

func _assert_turn_order_label(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during label probe.")
		quit(1)
		return
	var labels: Array[Label] = _labels_under(panel)
	for label: Label in labels:
		if label.text == "NEXT" or label.text.begins_with("+"):
			push_error("Expanded turn rail should not render detached NEXT or +N labels.")
			quit(1)

func _assert_turn_order_panel_right_rail(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		push_error("Turn order panel missing during right-rail probe.")
		quit(1)
		return
	var panel_rect: Rect2 = panel.get_global_rect()
	var viewport_rect: Rect2 = panel.get_viewport_rect()
	if panel_rect.end.x > viewport_rect.end.x - 8.0 or panel_rect.position.x < viewport_rect.size.x * 0.70:
		push_error("Turn order panel should stay inside the narrow right edge rail.")
		quit(1)

func _assert_vertical_turn_order_geometry(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if bar == null or panel == null:
		push_error("Turn order rail geometry needs the bar and panel.")
		quit(1)
		return
	var slots: Array[Control] = _turn_order_slot_controls(bar)
	var previous_rect := Rect2()
	var first_width: float = 0.0
	for index: int in range(slots.size()):
		var slot: Control = slots[index]
		var rect: Rect2 = slot.get_global_rect()
		if index == 0:
			first_width = rect.size.x
		else:
			if rect.position.y < previous_rect.end.y - 0.5:
				push_error("Turn entries must descend without vertical overlap.")
				quit(1)
				return
			if rect.size.x > previous_rect.size.x + 0.5:
				push_error("Queued turn portraits must progressively shrink.")
				quit(1)
				return
			if index > 1 and previous_rect.size.x - rect.size.x < 2.0:
				push_error("Queued turn portraits should have a clearly descending rhythm.")
				quit(1)
				return
		if not panel.get_global_rect().encloses(rect):
			push_error("Turn entry escaped the rail panel bounds.")
			quit(1)
			return
		var aspect: float = rect.size.x / maxf(1.0, rect.size.y)
		if aspect < 1.18 or aspect > 1.52:
			push_error("Turn entries must remain portrait-shaped near 4:3 instead of collapsing into slivers.")
			quit(1)
			return
		var portrait_crop: Control = slot.find_child("TurnOrderPortraitCrop", true, false) as Control
		var backing: TextureRect = slot.find_child("TurnOrderBrushBacking", true, false) as TextureRect
		var slot_panel: PanelContainer = slot.get_child(0) as PanelContainer if slot.get_child_count() > 0 else null
		var slot_style: StyleBoxFlat = slot_panel.get_theme_stylebox("panel") as StyleBoxFlat if slot_panel != null else null
		if portrait_crop == null or backing == null or str(slot.get_meta("turn_order_art_hook", "")) != "brush_backing_v2" or str(slot.get_meta("turn_order_backing_asset", "")) != TURN_ORDER_BACKING_PATH or slot.find_child("TurnOrderActiveFrameArtHost", true, false) != null or slot.find_child("TurnOrderQueuedFrameArtHost", true, false) != null:
			push_error("Turn entry should pair its portrait with the user-provided brush backing and no rectangular frame-art host.")
			quit(1)
			return
		if slot.clip_contents or slot_panel == null or slot_panel.clip_contents or backing.clip_contents:
			push_error("Turn-entry brush backing must sit beneath a fully non-clipping control chain.")
			quit(1)
			return
		var team: String = str(slot.get_meta("turn_order_team", "enemy"))
		if (team == "player" and backing.modulate.b <= backing.modulate.r) or (team != "player" and backing.modulate.r <= backing.modulate.b):
			push_error("Turn-entry brush backing should use the subdued blue player or red enemy treatment.")
			quit(1)
			return
		if backing.modulate.a > 0.67:
			push_error("Turn-entry brush backing should remain a subdued secondary cue.")
			quit(1)
			return
		if slot_style == null or slot_style.bg_color.a > 0.001 or slot_style.border_color.a > 0.001 or slot_style.shadow_size > 0:
			push_error("Turn entry surface should remain fully transparent and borderless.")
			quit(1)
			return
		previous_rect = rect
	if slots.size() >= 8 and (first_width < 128.0 or previous_rect.size.x < 74.0):
		push_error("Dense rail should keep its leading and final portraits readable.")
		quit(1)

func _assert_backing_texture_has_transparent_bleed() -> void:
	var image := Image.new()
	var load_error: Error = image.load(TURN_ORDER_BACKING_PATH)
	if load_error != OK:
		push_error("Turn-order brush backing failed to load for alpha-bound validation: %s" % error_string(load_error))
		quit(1)
		return
	var size: Vector2i = image.get_size()
	var min_x: int = size.x
	var min_y: int = size.y
	var max_x: int = -1
	var max_y: int = -1
	for y: int in range(size.y):
		for x: int in range(size.x):
			if image.get_pixel(x, y).a <= 0.01:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < min_x or max_y < min_y:
		push_error("Turn-order brush backing contains no visible pixels.")
		quit(1)
		return
	var minimum_horizontal_bleed: int = 20
	var minimum_vertical_bleed: int = 40
	if min_x < minimum_horizontal_bleed or size.x - 1 - max_x < minimum_horizontal_bleed or min_y < minimum_vertical_bleed or size.y - 1 - max_y < minimum_vertical_bleed:
		push_error("Turn-order brush backing needs transparent bleed on every side; alpha bounds were %s inside %s." % [Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1), size])
		quit(1)

func _turn_order_slot_controls(bar: Control) -> Array[Control]:
	var result: Array[Control] = []
	for child: Node in bar.get_children():
		var slot: Control = child as Control
		if slot != null and slot.has_meta("turn_order_rail_index"):
			result.append(slot)
	return result

func _labels_under(node: Node) -> Array[Label]:
	var labels: Array[Label] = []
	if node is Label:
		labels.append(node as Label)
	for child: Node in node.get_children():
		labels.append_array(_labels_under(child))
	return labels

func _assert_turn_order_badges_match_relative_clocks(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var combat_engine = instance.get("_combat_engine")
	if bar == null or combat_engine == null:
		push_error("Turn order bar or combat engine missing during badge probe.")
		quit(1)
		return
	var order: Array = combat_engine.current_turn_order(state, 10)
	var slots: Array[Control] = _turn_order_slot_controls(bar)
	if order.is_empty() or slots.is_empty():
		push_error("Turn order badge probe found no entries.")
		quit(1)
		return
	var count: int = mini(order.size(), slots.size())
	for index: int in range(count):
		var child: Control = slots[index]
		var entry: Dictionary = order[index] as Dictionary
		var expected: String = str(int(entry.get("eta", 0)))
		var actual: String = str(child.get_meta("turn_order_badge_text", ""))
		if actual != expected:
			push_error("Turn order badge %d showed %s, expected relative clock %s." % [index, actual, expected])
			quit(1)
			return
