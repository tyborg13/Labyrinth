extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const InputRouterScript = preload("res://scripts/input_router.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const ITERATIONS: int = 240
const IDLE_FRAMES: int = 120

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://controller_cursor_perf_progression.json")
	ProgressionStore.set_run_storage_path("user://controller_cursor_perf_run.save")
	ProgressionStore.clear_saved_run()
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	await _install_combat(instance)
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null and router.has_method("set_forced_state_for_test"):
		router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_controller_enter_board", true)
	instance.set("_controller_stick", Vector2.ZERO)
	await _settle()
	# Selected-card targeting is the important case: board hover presentation is
	# legitimately expensive when the target changes, but a stationary analog
	# pointer must not resubmit that same work on every physics tick.
	instance.set("_selected_card_index", 0)
	instance.call("set_runtime_performance_instrumentation_enabled", true)
	instance.call("consume_runtime_performance_instrumentation_snapshot")
	var board: Control = instance.get("board_view") as Control
	var render_before: Dictionary = board.call("render_instrumentation_snapshot")
	var started_usec: int = Time.get_ticks_usec()
	for _iteration: int in range(ITERATIONS):
		instance.call("_controller_process_board_cursor", 1.0 / 60.0)
	var elapsed_usec: int = Time.get_ticks_usec() - started_usec
	var sections: Dictionary = instance.call("consume_runtime_performance_instrumentation_snapshot")
	var render_after: Dictionary = board.call("render_instrumentation_snapshot")
	var cursor: Control = instance.get("_controller_analog_cursor") as Control
	var cursor_draw_count: Array[int] = [0]
	if cursor != null:
		cursor.draw.connect(func() -> void: cursor_draw_count[0] += 1)
	for _frame: int in range(IDLE_FRAMES):
		await process_frame
	instance.set("_selected_card_index", -1)
	instance.call("consume_runtime_performance_instrumentation_snapshot")
	instance.call("_controller_set_hand_focused", true)
	instance.call("_controller_set_hand_focused", false)
	for _frame: int in range(4):
		await process_frame
	var layout_sections: Dictionary = instance.call("consume_runtime_performance_instrumentation_snapshot")
	var selected_tile: Vector2i = instance.get("_controller_board_tile")
	var result: Dictionary = {
		"schema_version": 1,
		"iterations": ITERATIONS,
		"elapsed_usec": elapsed_usec,
		"usec_per_stationary_tick": float(elapsed_usec) / float(ITERATIONS),
		"stage_total_calls": int((sections.get("stage_total", {}) as Dictionary).get("count", 0)),
		"controller_cursor_total_calls": int((sections.get("hover_controller_cursor_total", {}) as Dictionary).get("count", 0)),
		"idle_frames": IDLE_FRAMES,
		"idle_cursor_draw_count": cursor_draw_count[0],
		"rapid_hand_toggle_stage_refresh_calls": int((layout_sections.get("stage_total", {}) as Dictionary).get("count", 0)),
		"dynamic_draw_count_delta": int(render_after.get("dynamic_draw_count", 0)) - int(render_before.get("dynamic_draw_count", 0)),
		"selected_tile": [selected_tile.x, selected_tile.y],
		"board_focus_matches": board.get("_controller_focus_tile") == selected_tile,
	}
	print("CONTROLLER CURSOR PERF RESULT: %s" % JSON.stringify(result))
	instance.queue_free()
	await process_frame
	var candidate_instrumentation_present: bool = int(result["controller_cursor_total_calls"]) > 0
	var candidate_regression_free: bool = (
		not candidate_instrumentation_present
		or (
			int(result["idle_cursor_draw_count"]) == 0
			and int(result["rapid_hand_toggle_stage_refresh_calls"]) == 0
		)
	)
	quit(0 if bool(result["board_focus_matches"]) and candidate_regression_free else 1)

func _install_combat(instance: Node) -> void:
	var hand: Array = ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"]
	var layout: Dictionary = {
		"name": "Controller Cursor Performance",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [
			{"id": 1, "type": "crawler", "pos": Vector2i(3, 4), "hp": 140, "max_hp": 140, "block": 0},
			{"id": 2, "type": "crawler", "pos": Vector2i(5, 2), "hp": 140, "max_hp": 140, "block": 0},
		],
		"traps": [],
		"terrain": [],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(127801, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": hand.duplicate(),
		"relics": [],
		"hand_size": hand.size(),
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["traps"] = []
	combat_state["terrain"] = []
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout["coord"]
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")
	await _settle()

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _settle() -> void:
	for _frame: int in range(6):
		await process_frame
