extends "res://tests/aoe_targeting_preview_probe.gd"

# Real-renderer proof for straight-line Push previews (spec/forced_movement.md):
# default line, Rotate to the alternate line, collision icon and commit result.
const FORCE_OUTPUT := "user://probes/forced_movement_preview"
const FORCE_TARGET := Vector2i(4, 5)

var _metrics: Dictionary = {}

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_size(VIEWPORT_SIZE)
	root.size = VIEWPORT_SIZE
	ProgressionStore.set_storage_path("user://forced_movement_preview_progression.json")
	ProgressionStore.set_run_storage_path("user://forced_movement_preview_run.save")
	SettingsStore.set_storage_path("user://forced_movement_preview_settings.json")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FORCE_OUTPUT))
	await _capture_force_states()
	var file := FileAccess.open(ProjectSettings.globalize_path(FORCE_OUTPUT.path_join("forced-movement-proof.json")), FileAccess.WRITE)
	file.store_string(JSON.stringify(_metrics, "\t"))
	file.close()
	print(ProjectSettings.globalize_path(FORCE_OUTPUT))
	if _failures.is_empty():
		print("FORCED MOVEMENT PREVIEW PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FORCED MOVEMENT PREVIEW PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)

func _capture_force_states() -> void:
	_capture_viewport = SubViewport.new()
	_capture_viewport.size = VIEWPORT_SIZE
	_capture_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_capture_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_capture_viewport.add_child(instance)
	await _settle()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	instance.set("_settings", settings)
	await _install_combat_fixture(instance, "updraft", 30091)
	var state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	state["enemies"] = [{"id": 1, "type": "crawler", "pos": FORCE_TARGET, "hp": 100, "max_hp": 100, "block": 0, "intent": {}}]
	state["terrain"] = [{"id": "probe_crate", "kind": "wooden_crate", "pos": Vector2i(6, 5), "hp": 3, "max_hp": 3}]
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", state)
	instance.call("_mark_combat_preview_state_changed")
	instance.call("_refresh_ui")
	await _settle()
	await _arm_printed_card(instance)
	var board: Control = instance.get("board_view") as Control
	var point: Vector2 = board.get_global_transform() * (board.call("world_position_for_tile", FORCE_TARGET) as Vector2)
	instance.call("_sync_click_targeting_arrow", point)
	instance.call("_on_board_tile_hovered", FORCE_TARGET)
	await _settle()
	await _capture_case(instance, board, "01_default_line_crate_collision", Vector2i(5, 5), Vector2i(6, 5))
	instance.call("_on_rotate_action_context_pressed")
	instance.call("_on_board_tile_hovered", FORCE_TARGET)
	await _settle()
	await _capture_case(instance, board, "02_rotated_line_wall_collision", Vector2i(4, 6), Vector2i(4, 7))
	# Start the commit without awaiting it so the resolution frames, including
	# the collision flash on the contact edge, can be sampled.
	instance.call("_on_board_tile_clicked", FORCE_TARGET)
	var flash_seen: bool = false
	for sample: int in range(24):
		await create_timer(0.05).timeout
		var shown: Dictionary = board.get("presentation") as Dictionary
		for event: Dictionary in shown.get("surface_feedback_events", []):
			if str(event.get("kind", "")) == "force_collision" and float(shown.get("surface_feedback_progress", 0.0)) > 0.2 and not flash_seen:
				flash_seen = true
				await _save_screenshot(FORCE_OUTPUT.path_join("03_commit_feedback.png"))
	_expect(flash_seen, "Commit feedback must carry the force_collision event")
	if not flash_seen:
		await _save_screenshot(FORCE_OUTPUT.path_join("03_commit_feedback.png"))
	await create_timer(1.5).timeout
	await _settle()
	await _save_screenshot(FORCE_OUTPUT.path_join("04_committed.png"))
	var final_state: Dictionary = instance.get("_combat_state")
	var enemy: Dictionary = (final_state.get("enemies", []) as Array)[0]
	_expect(enemy.get("pos") == Vector2i(4, 6), "Commit follows the rotated line")
	_metrics["committed"] = {"pos": enemy.get("pos"), "hp": enemy.get("hp")}
	instance.queue_free()
	await _settle()
	_capture_viewport.queue_free()

func _capture_case(instance: Node, board: Control, label: String, landing: Vector2i, blocked: Vector2i) -> void:
	var presentation: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	var markers: Array = presentation.get("collision_markers", [])
	var ghosts: Array = []
	for unit: Dictionary in presentation.get("preview_units", []):
		ghosts.append(unit.get("pos"))
	_expect(markers.size() == 1 and (markers[0] as Dictionary).get("tile") == landing and (markers[0] as Dictionary).get("blocked_tile") == blocked, label + " must mark the collision contact")
	_expect(ghosts.has(landing), label + " must ghost the landing tile")
	_expect(not (presentation.get("displacement_paths", []) as Array).is_empty(), label + " must draw the displacement path")
	_expect((presentation.get("damage_preview", {}) as Dictionary).has("enemy_1"), label + " must forecast collision damage on the target")
	_expect(instance.find_child("ActionContextRotate", true, false) != null, label + " must offer Rotate")
	await _save_screenshot(FORCE_OUTPUT.path_join(label + ".png"))
	_metrics[label] = {"collision_markers": markers, "ghosts": ghosts, "damage_preview": presentation.get("damage_preview", {}), "displacement_paths": presentation.get("displacement_paths", [])}
