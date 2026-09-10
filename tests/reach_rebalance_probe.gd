extends "res://tests/protagonist_cutout_gameplay_probe.gd"

const Data = preload("res://scripts/game_data.gd")
const Tactical = preload("res://tests/suites/enemy_tactical_ai_suite.gd")
const PROOF: String = "user://probes/reach_rebalance_v1"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_capture = DisplayServer.get_name() != "headless"
	_assert(_capture, "Reach proof requires the real renderer")
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF))
	ProgressionStore.set_storage_path("user://reach_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://reach_probe_run.save")
	ProgressionStore.clear_saved_run()
	var surface := SubViewport.new()
	surface.size = SIZE
	surface.disable_3d = true
	surface.world_2d = World2D.new()
	surface.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(surface)
	_render_viewport = surface
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	surface.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	await _reach_fixture(Vector2i(3, 4), "clear")
	await _instance.call("_on_card_pressed", 0)
	_instance.call("_on_board_tile_hovered", Vector2i(6, 4))
	_instance.call("_sync_click_targeting_arrow", _board.get_global_transform_with_canvas() * (_board.call("world_position_for_tile", Vector2i(6, 4)) as Vector2))
	await _settle()
	_assert(not (_board.get("attack_tiles") as Array).has(Vector2i(6, 4)), "Range-two poke rejects the enemy three away")
	await _capture_reach("01_poke_range_two")
	_instance.call("_cancel_card_selection")
	await _instance.call("_on_card_pressed", 1)
	_instance.call("_on_board_tile_hovered", Vector2i(6, 4))
	_instance.call("_sync_click_targeting_arrow", _board.get_global_transform_with_canvas() * (_board.call("world_position_for_tile", Vector2i(6, 4)) as Vector2))
	await _settle()
	_assert((_board.get("attack_tiles") as Array).has(Vector2i(6, 4)), "Dedicated range-three shot highlights the legal enemy")
	await _capture_reach("02_shot_range_three")
	await _instance.call("_on_board_tile_clicked", Vector2i(6, 4))
	await create_timer(1.6).timeout
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == 36, "Click targeting resolves Dull Bolt once")
	await _capture_reach("03_clicked_shot_resolved")

	await _reach_fixture(Vector2i(1, 4), "clear")
	_instance.set("_show_all_enemy_intents", true)
	_instance.call("_refresh_ui")
	_instance.call("_on_board_tile_hovered", Vector2i(6, 4))
	_instance.call("_sync_click_targeting_arrow", _board.get_global_transform_with_canvas() * (_board.call("world_position_for_tile", Vector2i(6, 4)) as Vector2))
	await _settle()
	var combat := CombatEngine.new()
	var plan: Dictionary = combat.enemy_intent_plan(_instance.get("_combat_state"), 0)
	_assert((plan["path"] as Array).size() == 4 and not bool(plan["attack_available"]), "Distant Acolyte preview shows three movement without a connecting hit")
	await _capture_reach("04_distant_weak_approach")

	await _reach_fixture(Vector2i(3, 4), "heart")
	_instance.set("_show_all_enemy_intents", true)
	_instance.call("_refresh_ui")
	await _settle()
	var presentation: Dictionary = _board.get("presentation") as Dictionary
	for entry: Dictionary in combat.current_turn_order(_instance.get("_combat_state")):
		if str(entry.get("kind", "")) == "enemy":
			_assert(str(entry.get("type", "")) == "umbra_presence", "Hidden turn order entries remain Unknown Presence")
	_assert(not (presentation.get("visible_enemy_ids", []) as Array).has(1), "Heart fog preserves the hidden enemy identity")
	_assert((presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Show all intents cannot expose a hidden attacker")
	await _capture_reach("05_heart_fog_preserved")

	# Exercise the existing drag selection/cancel path on changed ranged content.
	await _reach_fixture(Vector2i(3, 4), "clear")
	_instance.call("_on_card_drag_started", 1, Vector2(820, 920))
	_instance.call("_on_board_tile_hovered", Vector2i(6, 4))
	_instance.call("_sync_click_targeting_arrow", _board.get_global_transform_with_canvas() * (_board.call("world_position_for_tile", Vector2i(6, 4)) as Vector2))
	await _settle()
	await _capture_reach("06_drag_target")
	_instance.call("_cancel_drag_play")
	_assert(int((_instance.get("_combat_state") as Dictionary)["enemies"][0]["hp"]) == 40, "Cancelling drag targeting preserves the target")
	var file: FileAccess = FileAccess.open(PROOF + "/manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "balance_revision": Data.BALANCE_REVISION, "checks": _manifest["checks"], "errors": _errors}, "\t"))
	_instance.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("REACH REBALANCE PROBE: %s" % ("PASS" if _errors.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(PROOF))
	quit(0 if _errors.is_empty() else 1)

func _reach_fixture(player_tile: Vector2i, fog: String) -> void:
	await _fixture(player_tile, Vector2i(6, 4), false, ["pale_spark", "dull_bolt", "stormstring_shot", "sidestep_slash", "threaded_path", "trapdoor", "frostbolt"])
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	var grid: Array = []
	for y: int in range(9):
		var row: Array[String]
		for x: int in range(9): row.append("wall" if x == 0 or x == 8 or y == 0 or y == 8 else "stone")
		grid.append(row)
	state["grid"] = grid
	state["room_name"] = "Short Reach Trial"
	state["enemies"][0]["type"] = "acolyte"
	state["enemies"][0]["intent"] = Tactical._intent("acolyte", "dust_advance" if player_tile.x == 1 else "dust_bolt")
	state["umbra"]["stage"] = fog
	_instance.set("_combat_state", state)
	var run: Dictionary = _instance.get("_run_state")
	run["combat_state"] = state.duplicate(true)
	run["current_room_layout"]["grid"] = grid
	run["current_room_layout"]["name"] = "Short Reach Trial"
	_instance.set("_run_state", run)
	_instance.call("_sync_combat_state_from_run")
	_instance.set("_show_all_enemy_intents", false)
	_instance.call("_refresh_ui")
	await _settle()

func _capture_reach(label: String) -> void:
	await RenderingServer.frame_post_draw
	var shot: Image = _render_viewport.get_texture().get_image()
	_assert(shot.get_size() == SIZE, "Native render target is exactly 1920x1080")
	shot.save_png(PROOF.path_join(label + ".png"))
