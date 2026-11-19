extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")
const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

const OUTPUT_DIR: String = "user://probes"
const PROOF_UI_SCALE: float = 1.0
const MOTION_WATCHDOG_MS: int = 4000
const RUN_SEED: int = 123
const PASS_WATCHDOG_MS: int = 12000
const FIRE_FIXTURE_HP: int = 1

var _owns_probe_lifecycle: bool = false
var _probe_failed: bool = false
var _pass_finished: bool = false

func _initialize() -> void:
	_owns_probe_lifecycle = true
	if DisplayServer.get_name() == "headless":
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	print("turn order probe: start")
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://labyrinth_settings_turn_order_probe.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = PROOF_UI_SCALE
	SettingsStore.save_settings(settings)
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_factor = PROOF_UI_SCALE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
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
	var progression: Dictionary = ProgressionStore.default_data()
	for prompt: String in Tutorials.prompt_ids():
		progression = Tutorials.resolve_progression(progression, prompt)
	instance.call("_load_run_state", probe_run_engine.create_new_run(RUN_SEED, progression))
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
		_fail_probe("No combat room available for turn order animation probe.")
		await _finish_probe(instance)
		return
	print("turn order probe: entering combat")
	run_state = probe_run_engine.move_to_pre_battle(run_state, combat_coord)
	run_state = probe_run_engine.begin_pre_battle_combat(run_state)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	print("turn order probe: combat ready")
	var combat_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	_assert_complete_initial_turn_order(instance, combat_state)
	_assert_turn_order_label(instance)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, combat_state)
	await _save_motion_screenshot("v5_00_stable")
	var combat_engine = instance.get("_combat_engine")
	var scheduled_state: Dictionary = combat_engine.finish_player_activation(combat_state.duplicate(true))
	print("turn order probe: animating turn consumption")
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), scheduled_state.duplicate(true))
	await _observe_consumed_turn(instance)
	_assert_turn_order_slot_count(instance, 10)
	_assert_turn_order_panel_right_rail(instance)
	_assert_vertical_turn_order_geometry(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, scheduled_state)
	await _save_motion_screenshot("v5_04_turn_settled")

	print("turn order probe: animating committed Time shift")
	_set_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame
	var time_shifted_state: Dictionary = combat_state.duplicate(true)
	time_shifted_state["player_turn_time_spent"] = int(combat_state.get("player_turn_time_spent", 0)) + 9
	instance.call("_animate_turn_order_transition_between_states", combat_state.duplicate(true), time_shifted_state.duplicate(true))
	await _observe_time_reflow(instance)
	await _wait_for_turn_order_to_settle(instance)
	_assert_turn_order_badges_match_relative_clocks(instance, time_shifted_state)
	await _save_motion_screenshot("v5_06_time_settled")

	print("turn order probe: animating enemy defeat")
	_set_probe_combat_state(instance, combat_state)
	await process_frame
	await process_frame
	var defeated_actor_key: String = _first_enemy_turn_actor_key(instance, combat_state)
	var defeated_state: Dictionary = _state_with_enemy_defeated(combat_state, defeated_actor_key)
	instance.call("_animate_turn_order_alongside_defeats", combat_state.duplicate(true), defeated_state.duplicate(true))
	await _observe_defeat(
		instance, defeated_actor_key, "defeat",
		"v5_07_enemy_board_death_active", "v6_08_enemy_overlapping_dissolve", "v6_09_enemy_board_settled"
	)
	_assert_enemy_absent_from_board(instance, defeated_actor_key)
	await _wait_for_turn_order_to_settle(instance)
	await _save_motion_screenshot("v6_10_enemy_cleanup_settled")
	await process_frame
	_assert_actor_absent(instance, defeated_actor_key)
	_assert_vertical_turn_order_geometry(instance)
	await _save_motion_screenshot("v5_11_enemy_death_settled")

	print("turn order probe: verifying reduced motion")
	_set_probe_combat_state(instance, combat_state)
	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_animate_turn_order_alongside_defeats", combat_state.duplicate(true), defeated_state.duplicate(true))
	await process_frame
	_assert_reduced_motion_settled(instance, defeated_actor_key)
	await _save_motion_screenshot("v5_12_reduced_motion_settled")
	reduced_settings["reduced_motion"] = false
	instance.set("_settings", reduced_settings)

	print("turn order probe: passing into production Fire defeat")
	var fire_state: Dictionary = _fire_fixture(combat_state, defeated_actor_key)
	var fire_run: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	fire_run["combat_state"] = fire_state
	instance.call("_load_run_state", fire_run)
	instance.call("_close_dialogue")
	await process_frame
	await process_frame
	_pass_turn(instance)
	await _observe_defeat(
		instance, defeated_actor_key, "pass_fire",
		"v5_13_fire_board_death_active", "v6_14_fire_overlapping_dissolve", "v6_15_fire_board_settled"
	)
	var pass_deadline: int = Time.get_ticks_msec() + PASS_WATCHDOG_MS
	while not _pass_finished and Time.get_ticks_msec() < pass_deadline:
		await process_frame
	if not _pass_finished or bool(instance.get("_animation_lock")) or bool(instance.get("_turn_order_animating")):
		_fail_probe("Pass did not finish and release input after the Fire defeat.")
		await _finish_probe(instance)
		return
	_assert_enemy_defeated_in_state(instance.get("_combat_state") as Dictionary, defeated_actor_key)
	_assert_enemy_absent_from_board(instance, defeated_actor_key)
	_assert_actor_absent(instance, defeated_actor_key)
	_assert_vertical_turn_order_geometry(instance)
	await _save_motion_screenshot("v5_16_fire_death_settled")

	var tied_state: Dictionary = _equal_time_player_tie_state(instance, combat_state.duplicate(true))
	_set_probe_combat_state(instance, tied_state)
	await process_frame
	_assert_player_wins_equal_time_forecast(instance, tied_state)
	_assert_turn_order_badges_match_relative_clocks(instance, tied_state)
	await _save_motion_screenshot("v5_17_player_tie_forecast")
	var tied_scheduled_state: Dictionary = combat_engine.finish_player_activation(tied_state.duplicate(true))
	_assert_player_wins_equal_time_schedule(combat_engine, tied_scheduled_state)
	_set_probe_combat_state(instance, tied_scheduled_state)
	await process_frame
	_assert_turn_order_badges_match_relative_clocks(instance, tied_scheduled_state)
	await _save_motion_screenshot("v5_18_player_tie_scheduled")
	await _finish_probe(instance)

func _finish_probe(instance: Node) -> void:
	instance.queue_free()
	await process_frame
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TURN ORDER ANIMATION PROBE RESULT: %s" % ("FAIL" if _probe_failed else "PASS"))
	quit(1 if _probe_failed else 0)

func _fail_probe(message: String) -> void:
	push_error(message)
	_probe_failed = true
	if not _owns_probe_lifecycle:
		# The overlap probe inherits the assertions and owns its own lifecycle.
		quit(1)

func _save_motion_screenshot(stage: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw(true)
	var image: Image = root.get_texture().get_image()
	# macOS can expose a Retina backing texture for the 1920x1080 canvas.
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	var output_path: String = "%s/turn_order_motion_%s.png" % [OUTPUT_DIR, stage]
	if image.save_png(output_path) != OK:
		_fail_probe("Could not save %s." % output_path)

func _equal_time_player_tie_state(instance: Node, state: Dictionary) -> Dictionary:
	var combat_engine = instance.get("_combat_engine")
	var queue: Array = (state.get("turn_queue", []) as Array).duplicate(true)
	if combat_engine == null or queue.is_empty():
		_fail_probe("Turn-order tie probe requires a combat engine and one queued enemy.")
		return state
	state["player_turn_time_spent"] = 0
	var tied_time: int = int(state.get("initiative_clock", 0)) + int(combat_engine.player_base_initiative(state)) + int(combat_engine.pending_wait_time(state))
	var enemy_entry: Dictionary = (queue[0] as Dictionary).duplicate(true)
	enemy_entry["time"] = tied_time
	enemy_entry["seq"] = 1
	state["turn_queue"] = [enemy_entry]
	state["activation_seq"] = 1
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
	_fail_probe("Turn-order defeat probe requires a visible enemy entry.")
	return ""

func _state_with_enemy_defeated(state: Dictionary, actor_key: String) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var enemy: Dictionary = _fixture_enemy(result, actor_key)
	if not enemy.is_empty():
		enemy["hp"] = 0
	return result

func _fire_fixture(state: Dictionary, actor_key: String) -> Dictionary:
	var result: Dictionary = state.duplicate(true)
	var enemy: Dictionary = _fixture_enemy(result, actor_key)
	if not enemy.is_empty():
		enemy["hp"] = FIRE_FIXTURE_HP
		BoardSurfaceRules.place(result, enemy["pos"], "fire")
	return result

func _fixture_enemy(state: Dictionary, actor_key: String) -> Dictionary:
	for enemy: Dictionary in state.get("enemies", []):
		if "enemy:enemy_%d" % int(enemy.get("id", -1)) == actor_key:
			return enemy
	_fail_probe("Turn-order fixture could not find %s." % actor_key)
	return {}

func _pass_turn(instance: Node) -> void:
	await instance.call("_on_pass_turn_pressed")
	_pass_finished = true

func _assert_enemy_defeated_in_state(state: Dictionary, actor_key: String) -> void:
	for enemy_var: Variant in state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if "enemy:enemy_%d" % int(enemy.get("id", -1)) != actor_key:
			continue
		if int(enemy.get("hp", 0)) <= 0:
			return
	_fail_probe("Production Fire defeat did not defeat %s." % actor_key)

func _assert_active_player_persists(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		_fail_probe("Turn order bar missing during Time reflow probe.")
		return
	for slot: Control in _turn_order_slot_controls(bar):
		if str(slot.get_meta("turn_order_actor_key", "")) != "player:player":
			continue
		if str(slot.get_meta("turn_order_animation_role", "")) != "active":
			continue
		var active_position: Vector2 = instance.call("_turn_order_slot_position", 0) as Vector2
		if slot.modulate.a < 0.99 or slot.position.distance_to(active_position) > 1.0:
			_fail_probe("Committing Time should preserve the active player portrait while future turns reflow.")
		return
	_fail_probe("Time reflow lost the active player portrait.")

func _slot_is_reflowing(instance: Node, slot: Control) -> bool:
	var index: int = int(slot.get_meta("turn_order_rail_index"))
	var baseline: Vector2 = instance.call("_turn_order_slot_position", index) as Vector2
	return slot.position.distance_to(baseline) > 1.0

func _observe_time_reflow(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var deadline: int = Time.get_ticks_msec() + MOTION_WATCHDOG_MS
	while bool(instance.get("_turn_order_animating")) and Time.get_ticks_msec() < deadline:
		for slot: Control in _turn_order_slot_controls(bar):
			if slot.modulate.a > 0.0 and _slot_is_reflowing(instance, slot):
				_assert_active_player_persists(instance)
				await _save_motion_screenshot("v5_05_time_reflow")
				return
		await process_frame
	_fail_probe("Time change did not visibly move any turn-order portrait between slots.")

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
				_fail_probe("%s visibly began its Turn Clock dissolution before the delayed death echo." % actor_key)
				return
			var rail_index: int = int(slot.get_meta("turn_order_rail_index", -1))
			var settled_position: Vector2 = instance.call("_turn_order_slot_position", rail_index) as Vector2
			if slot.position.distance_to(settled_position) > 0.5 or slot.modulate.a < 0.99:
				_fail_probe("%s should remain settled and readable while the board death owns the first beat." % actor_key)
				return
	if matching <= 0:
		_fail_probe("Delayed death echo lost every scheduled portrait for %s before its dissolution began." % actor_key)

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
		_fail_probe("Every scheduled portrait for %s should share the delayed shadow dissolution (%d/%d dissolving)." % [actor_key, dissolving, matching])

func _assert_enemy_board_dissolve_active(instance: Node, actor_key: String) -> void:
	var board: Control = instance.get("board_view") as Control
	var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
	var board_actor_key: String = actor_key.substr(6) if actor_key.begins_with("enemy:") else actor_key
	if not effects.has(board_actor_key):
		_fail_probe("Turn Clock dissolution must overlap the battlefield death for %s." % actor_key)

func _wait_for_turn_order_to_settle(instance: Node) -> void:
	var deadline: int = Time.get_ticks_msec() + MOTION_WATCHDOG_MS
	while bool(instance.get("_turn_order_animating")) and Time.get_ticks_msec() < deadline:
		await process_frame
	if bool(instance.get("_turn_order_animating")):
		_fail_probe("Overlapping defeat cleanup failed to settle within its bounded duration.")

func _assert_enemy_absent_from_board(instance: Node, actor_key: String) -> void:
	var board: Control = instance.get("board_view") as Control
	if board == null:
		_fail_probe("Combat board missing while checking settled defeat cleanup.")
		return
	var effects: Dictionary = board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary
	var board_actor_key: String = actor_key.substr(6) if actor_key.begins_with("enemy:") else actor_key
	if effects.has(board_actor_key):
		_fail_probe("%s was still dissolving on the battlefield after its completion." % actor_key)

func _observe_defeat(
	instance: Node, actor_key: String, case_id: String,
	board_image: String, overlap_image: String, settled_image: String
) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var board: Control = instance.get("board_view") as Control
	var board_key: String = actor_key.trim_prefix("enemy:")
	var trace := FileAccess.open("%s/turn_order_%s.jsonl" % [OUTPUT_DIR, case_id], FileAccess.WRITE)
	var start: int = Time.get_ticks_msec()
	var deadline: int = start + (PASS_WATCHDOG_MS if case_id == "pass_fire" else MOTION_WATCHDOG_MS)
	var peak_progress: float = 0.0
	var saw_board_first: bool = false
	var saw_overlap: bool = false
	var saw_board_finish: bool = false
	var progressing_frames: int = 0
	while Time.get_ticks_msec() < deadline:
		var board_active: bool = (board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).has(board_key)
		var progress: Array[float]
		for slot: Control in _turn_order_slot_controls(bar):
			if str(slot.get_meta("turn_order_actor_key", "")) != actor_key:
				continue
			var effect: Control = slot.get_node_or_null("TurnOrderShadowDissolve") as Control
			progress.append(float(effect.call("dissolve_progress")) if effect != null else -1.0)
		if trace != null:
			trace.store_line(JSON.stringify({
				"frame": Engine.get_process_frames(),
				"ms": Time.get_ticks_msec() - start,
				"actor": actor_key,
				"board_dissolving": board_active,
				"portrait_progress": progress,
			}))
		if board_active and not progress.is_empty():
			var earliest: float = float(progress.min())
			var latest: float = float(progress.max())
			if latest <= 0.04 and not saw_board_first:
				saw_board_first = true
				_assert_actor_waiting_for_shadow_echo(instance, actor_key)
				await _save_motion_screenshot(board_image)
			if earliest > peak_progress and latest < 1.0:
				peak_progress = earliest
				progressing_frames += 1
			if earliest >= 0.38 and latest <= 0.80 and not saw_overlap:
				saw_overlap = true
				_assert_actor_shadow_dissolving(instance, actor_key)
				_assert_enemy_board_dissolve_active(instance, actor_key)
				if case_id == "defeat":
					_assert_active_player_persists(instance)
				await _save_motion_screenshot(overlap_image)
		if saw_board_first and not board_active and not saw_board_finish:
			saw_board_finish = true
			await _save_motion_screenshot(settled_image)
		if (saw_board_finish and progress.is_empty()) or (case_id == "pass_fire" and _pass_finished):
			break
		await process_frame
	if trace != null:
		trace.close()
	else:
		_fail_probe("Could not write the %s frame trace." % case_id)
	print("TURN ORDER DEFEAT %s actor=%s board_first=%s overlap=%s progressing_frames=%d board_finished=%s" % [
		case_id, actor_key, saw_board_first, saw_overlap, progressing_frames, saw_board_finish,
	])
	if not saw_board_first or not saw_overlap or progressing_frames < 2 or not saw_board_finish:
		_fail_probe("%s did not show a delayed, advancing portrait dissolve overlapping the board death." % case_id)

func _assert_actor_absent(instance: Node, actor_key: String) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		_fail_probe("Turn order bar missing after enemy defeat.")
		return
	for slot: Control in _turn_order_slot_controls(bar):
		if str(slot.get_meta("turn_order_actor_key", "")) == actor_key:
			_fail_probe("Defeated actor %s remained in the settled turn order." % actor_key)
			return

func _assert_reduced_motion_settled(instance: Node, removed_actor_key: String) -> void:
	if bool(instance.get("_turn_order_animating")):
		_fail_probe("Reduced Motion should bypass turn-order transition movement.")
	_assert_actor_absent(instance, removed_actor_key)
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		return
	for slot: Control in _turn_order_slot_controls(bar):
		var rail_index: int = int(slot.get_meta("turn_order_rail_index", -1))
		var settled_position: Vector2 = instance.call("_turn_order_slot_position", rail_index) as Vector2
		if slot.position.distance_to(settled_position) > 0.5 or not slot.scale.is_equal_approx(Vector2.ONE) or slot.modulate.a < 0.99:
			_fail_probe("Reduced Motion should render only settled turn-order slots.")
			return

func _assert_player_wins_equal_time_forecast(instance: Node, state: Dictionary) -> void:
	var combat_engine = instance.get("_combat_engine")
	var order: Array = combat_engine.current_turn_order(state, 3)
	if order.size() < 3:
		_fail_probe("Turn-order tie forecast should show the active player and both tied future actors.")
		return
	var player_entry: Dictionary = order[1] as Dictionary
	var enemy_entry: Dictionary = order[2] as Dictionary
	if str(player_entry.get("kind", "")) != "player" or str(enemy_entry.get("kind", "")) != "enemy" or int(player_entry.get("time", -1)) != int(enemy_entry.get("time", -2)):
		_fail_probe("Turn-order tie forecast should place the player's tied future slot before the enemy.")

func _assert_player_wins_equal_time_schedule(combat_engine: RefCounted, state: Dictionary) -> void:
	var order: Array = combat_engine.current_turn_order(state, 2)
	if order.size() < 2:
		_fail_probe("Turn-order tied schedule should contain the player and enemy.")
		return
	var player_entry: Dictionary = order[0] as Dictionary
	var enemy_entry: Dictionary = order[1] as Dictionary
	if str(player_entry.get("kind", "")) != "player" or str(enemy_entry.get("kind", "")) != "enemy" or int(player_entry.get("time", -1)) != int(enemy_entry.get("time", -2)):
		_fail_probe("Committed turn order should keep the tied player ahead of the enemy.")

func _observe_consumed_turn(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var saw_exit: bool = false
	var saw_collapse: bool = false
	var saw_insert: bool = false
	var deadline: int = Time.get_ticks_msec() + MOTION_WATCHDOG_MS
	while bool(instance.get("_turn_order_animating")) and Time.get_ticks_msec() < deadline:
		var exiting: Array[Control]
		var reflowing: bool = false
		var inserting: bool = false
		for slot: Control in _turn_order_slot_controls(bar):
			if slot.get_meta("turn_order_removal_style", "") == "slide":
				exiting.append(slot)
			elif _slot_is_reflowing(instance, slot):
				reflowing = reflowing or slot.modulate.a >= 0.99
				inserting = inserting or (slot.modulate.a > 0.0 and slot.modulate.a < 0.99)
		if exiting.size() > 1:
			_fail_probe("Expected exactly one sliding turn-order entry; found %d." % exiting.size())
		if exiting.size() == 1 and not saw_exit:
			var slot: Control = exiting[0]
			if slot.modulate.a < 0.98 and _slot_is_reflowing(instance, slot):
				if slot.get_meta("turn_order_actor_key", "") != "player:player" or slot.get_meta("turn_order_animation_role", "") != "active":
					_fail_probe("The exit slide must consume the active player entry.")
				saw_exit = true
				_assert_turn_order_width_locked(instance)
				print("TURN ORDER CONSUMED PLAYER: slide alpha=%.3f y=%.2f" % [slot.modulate.a, slot.position.y])
				await _save_motion_screenshot("v5_01_turn_exit")
		if saw_exit and exiting.is_empty() and reflowing and not saw_collapse:
			saw_collapse = true
			_assert_turn_order_width_locked(instance)
			await _save_motion_screenshot("v5_02_turn_collapse")
		if saw_collapse and inserting and not saw_insert:
			saw_insert = true
			await _save_motion_screenshot("v5_03_turn_insert")
		await process_frame
	if not saw_exit or not saw_collapse or not saw_insert:
		_fail_probe("Turn consumption missed a motion phase (exit=%s collapse=%s insert=%s)." % [saw_exit, saw_collapse, saw_insert])
	await _wait_for_turn_order_to_settle(instance)

func _assert_turn_order_width_locked(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		_fail_probe("Turn order panel missing during animation probe.")
		return
	var locked_width: float = float(instance.get("_turn_order_panel_locked_width"))
	if locked_width <= 0.0:
		_fail_probe("Turn order panel width was not locked during animation.")
		return
	if absf(panel.custom_minimum_size.x - locked_width) > 0.5:
		_fail_probe("Turn order panel width changed during animation.")

func _assert_turn_order_slot_count(instance: Node, max_count: int) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	if bar == null:
		_fail_probe("Turn order bar missing during slot-count probe.")
		return
	if _turn_order_slot_controls(bar).size() > max_count:
		_fail_probe("Turn order bar showed %d slots; expected at most %d." % [_turn_order_slot_controls(bar).size(), max_count])

func _assert_complete_initial_turn_order(instance: Node, state: Dictionary) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var combat_engine = instance.get("_combat_engine")
	if bar == null or panel == null or combat_engine == null:
		_fail_probe("Turn order initialization probe is missing the bar, panel, or engine.")
		return
	var expected: Array = combat_engine.current_turn_order(state, 10)
	if expected.is_empty():
		_fail_probe("Turn order initialization fixture produced no expected entries.")
		return
	if _turn_order_slot_controls(bar).size() != expected.size():
		_fail_probe("Turn order showed %d of %d entries on room entry before any action." % [_turn_order_slot_controls(bar).size(), expected.size()])
		return
	if panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null:
		_fail_probe("Turn order should present floating portrait frames, not a full-height ornamental enclosure.")
	if bar.get_node_or_null("TurnOrderOverflowBadge") != null:
		_fail_probe("The expanded rail should show scheduled portraits directly, not a +N overflow label.")

func _assert_turn_order_label(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		_fail_probe("Turn order panel missing during label probe.")
		return
	var labels: Array[Label] = _labels_under(panel)
	for label: Label in labels:
		if label.text == "NEXT" or label.text.begins_with("+"):
			_fail_probe("Expanded turn rail should not render detached NEXT or +N labels.")

func _assert_turn_order_panel_right_rail(instance: Node) -> void:
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if panel == null:
		_fail_probe("Turn order panel missing during right-rail probe.")
		return
	var panel_rect: Rect2 = panel.get_global_rect()
	var viewport_rect: Rect2 = panel.get_viewport_rect()
	if panel_rect.end.x > viewport_rect.end.x - 8.0 or panel_rect.position.x < viewport_rect.size.x * 0.70:
		_fail_probe("Turn order panel should stay inside the narrow right edge rail.")

func _assert_vertical_turn_order_geometry(instance: Node) -> void:
	var bar: Control = instance.get("_turn_order_bar") as Control
	var panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	if bar == null or panel == null:
		_fail_probe("Turn order rail geometry needs the bar and panel.")
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
				_fail_probe("Turn entries must descend without vertical overlap.")
				return
			if rect.size.x > previous_rect.size.x + 0.5:
				_fail_probe("Queued turn portraits must progressively shrink.")
				return
			if index > 1 and previous_rect.size.x - rect.size.x < 2.0:
				_fail_probe("Queued turn portraits should have a clearly descending rhythm.")
				return
		if not panel.get_global_rect().encloses(rect):
			_fail_probe("Turn entry escaped the rail panel bounds.")
			return
		var aspect: float = rect.size.x / maxf(1.0, rect.size.y)
		if aspect < 1.18 or aspect > 1.52:
			_fail_probe("Turn entries must remain portrait-shaped near 4:3 instead of collapsing into slivers.")
			return
		var portrait_crop: Control = slot.find_child("TurnOrderPortraitCrop", true, false) as Control
		var backing: TextureRect = slot.find_child("TurnOrderBrushBacking", true, false) as TextureRect
		var edge: Control = slot.find_child("TurnOrderSlashEdge", true, false) as Control
		var slot_panel: PanelContainer = slot.get_child(0) as PanelContainer if slot.get_child_count() > 0 else null
		var slot_style: StyleBoxFlat = slot_panel.get_theme_stylebox("panel") as StyleBoxFlat if slot_panel != null else null
		if portrait_crop == null or backing == null or backing.texture == null or edge == null or str(slot.get_meta("turn_order_art_hook", "")) != "ink_brush_v3" or slot.find_child("TurnOrderActiveFrameArtHost", true, false) != null or slot.find_child("TurnOrderQueuedFrameArtHost", true, false) != null:
			_fail_probe("Turn entry should pair its portrait with a painted ink stroke and no raster frame-art host.")
			return
		if slot.clip_contents or slot_panel == null or slot_panel.clip_contents or backing.clip_contents:
			_fail_probe("Turn-entry ink stroke must sit beneath a fully non-clipping control chain.")
			return
		var team: String = str(slot.get_meta("turn_order_team", "enemy"))
		var active_slot: bool = slots.find(slot) == 0
		if not active_slot and ((team == "player" and backing.modulate.g <= backing.modulate.r) or (team != "player" and backing.modulate.r <= backing.modulate.b)):
			_fail_probe("Queued ink strokes should read as teal allies and crimson enemies.")
			return
		if edge.z_index <= portrait_crop.z_index:
			_fail_probe("Turn-entry painted edge should draw above the portrait sprite.")
			return
		if slot_style == null or slot_style.bg_color.a > 0.001 or slot_style.border_color.a > 0.001 or slot_style.shadow_size > 0:
			_fail_probe("Turn entry surface should remain fully transparent and borderless.")
			return
		previous_rect = rect
	if slots.size() >= 8 and (first_width < 128.0 or previous_rect.size.x < 74.0):
		_fail_probe("Dense rail should keep its leading and final portraits readable.")

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
		_fail_probe("Turn order bar or combat engine missing during badge probe.")
		return
	var order: Array = combat_engine.current_turn_order(state, 10)
	var slots: Array[Control] = _turn_order_slot_controls(bar)
	if order.is_empty() or slots.is_empty():
		_fail_probe("Turn order badge probe found no entries.")
		return
	var count: int = mini(order.size(), slots.size())
	for index: int in range(count):
		var child: Control = slots[index]
		var entry: Dictionary = order[index] as Dictionary
		var expected: String = str(int(entry.get("eta", 0)))
		var actual: String = str(child.get_meta("turn_order_badge_text", ""))
		if actual != expected:
			_fail_probe("Turn order badge %d showed %s, expected relative clock %s." % [index, actual, expected])
			return
