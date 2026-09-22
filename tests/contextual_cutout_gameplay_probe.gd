extends "res://tests/zekarion_cutout_gameplay_probe.gd"

## Actual card/End Turn paths, with fresh complete 1080p sequences and resolver
## equality checks. Fixture construction is shared with the dragon action probe.
const CONTEXT_OUTPUT: String = "user://probes/contextual_cutout_gameplay_v1"
var _context_records: Array[Dictionary] = []

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CONTEXT_OUTPUT))
	ProgressionStore.set_storage_path("user://contextual_cutout_progression.json")
	ProgressionStore.set_run_storage_path("user://contextual_cutout_run.save")
	ProgressionStore.clear_saved_run()
	_render_viewport = SubViewport.new()
	_render_viewport.size = SIZE
	_render_viewport.disable_3d = true
	_render_viewport.world_2d = World2D.new()
	_render_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_render_viewport)
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_render_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	for lethal: bool in [false, true]:
		await _fixture(Vector2i(4,6), Vector2i(4,4), false, "storm_claw", 9 if lethal else 60)
		await _instance.call("_on_card_pressed",0)
		_instance.call("_on_board_tile_hovered",Vector2i(4,5))
		await _settle()
		_instance.call("_on_board_tile_clicked",Vector2i(4,5))
		await _observe_context("enemy_death" if lethal else "enemy_hit", "enemy_1", "death" if lethal else "hit")
		var after: Dictionary = _instance.get("_combat_state")
		_assert(int(after["enemies"][0]["hp"]) == (0 if lethal else 51), "Quick Stab changes the target HP exactly once")
	for guarded: bool in [false, true]:
		await _fixture(Vector2i(4,6), Vector2i(4,4), false, "storm_claw")
		if guarded: _set_player_context(100, 999)
		var before: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var engine := CombatEngine.new()
		var expected: Dictionary = engine.advance_to_next_player_turn_with_steps(engine.finish_player_activation(before))["state"]
		_instance.call("_on_pass_turn_pressed")
		await _observe_context("player_guard" if guarded else "player_hit", "player", "block" if guarded else "hit")
		var after: Dictionary = _instance.get("_combat_state")
		for key: String in ["player","enemies","surfaces","initiative_clock","turn_queue"]:
			_assert(after.get(key)==expected.get(key), "Reaction preserves End Turn resolver " + key)
	await _fixture(Vector2i(4,6), Vector2i(4,4), false, "storm_claw")
	_set_player_context(1, 0)
	_instance.call("_on_pass_turn_pressed")
	await _observe_context("player_death", "player", "death")
	await _fixture(Vector2i(4,6), Vector2i(4,4), true, "storm_claw",9)
	await _instance.call("_on_card_pressed",0)
	_instance.call("_on_board_tile_clicked",Vector2i(4,5))
	await _observe_context("reduced_enemy_death", "enemy_1", "death", true)
	await _fixture(Vector2i(4,6), Vector2i(4,4), true, "storm_claw")
	_instance.call("_on_pass_turn_pressed")
	await _observe_context("reduced_player_hit", "player", "rest", true)
	# Existing navigation contracts still apply at the changed scene.
	await _fixture(Vector2i(4,6), Vector2i(4,4))
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		router.call("set_forced_state_for_test",InputRouter.MODALITY_CONTROLLER,InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _instance.call("_on_card_pressed",0)
		await _settle()
		await _context_still("controller_target")
		var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
		var cancel := InputEventAction.new()
		cancel.action = InputRouter.ACTION_CANCEL
		cancel.pressed = true
		_assert(await _instance.call("_handle_controller_input",cancel), "Controller cancellation remains reachable")
		_assert(state == _instance.get("_combat_state"), "Controller cancellation retains combat state")
		router.call("set_forced_state_for_test",InputRouter.MODALITY_POINTER,InputRouter.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		await _context_still("pointer_handoff")
		router.call("clear_forced_state_for_test")
	var file := FileAccess.open(CONTEXT_OUTPUT.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080], "ui_scale":1.0, "sequences":_context_records, "errors":_errors, "ok":_errors.is_empty()}, "\t"))
	file.close()
	_instance.queue_free()
	_render_viewport.queue_free()
	await process_frame
	for error: String in _errors: push_error(error)
	print("Saved " + ProjectSettings.globalize_path(CONTEXT_OUTPUT))
	print("CONTEXTUAL CUTOUT GAMEPLAY: " + ("PASS" if _errors.is_empty() else "FAIL"))
	quit(0 if _errors.is_empty() else 1)

func _set_player_context(hp: int, block: int) -> void:
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["player"]["hp"] = hp
	state["player"]["block"] = block
	state["defiance_remaining"] = 0
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"] = state
	_instance.set("_run_state",run)
	_instance.call("_sync_combat_state_from_run")
	_instance.call("_refresh_ui")

func _observe_context(label: String, actor_key: String, expected: String, reduced: bool = false) -> void:
	var started: int = Time.get_ticks_usec()
	var finished: int = 0
	var next_capture: int = started
	var clips: Dictionary = {}
	var samples: Array[Dictionary] = []
	var images: Array[Image] = []
	var targets: Dictionary = {}
	while Time.get_ticks_usec()-started < 18000000:
		await process_frame
		var now: int = Time.get_ticks_usec()
		if not bool(_instance.get("_animation_lock")) and finished == 0: finished = now
		var snapshot: Dictionary = _board.call("protagonist_animation_snapshot") if actor_key == "player" else _snapshot()
		clips[str(snapshot.get("clip", "gone"))] = true
		var shown: bool = str(snapshot.get("clip", "")) == expected
		if shown and reduced and expected == "death":
			_assert(is_equal_approx(float(snapshot.get("phase",0)),1.0), "Reduced death stays on its authored final pose")
		var presentation: Dictionary = _board.get("presentation")
		if shown and expected == "death" and actor_key != "player":
			_assert(not (_board.get("_enemy_shadow_dissolve_effects_by_key") as Dictionary).is_empty(), "Articulated death retains the original shadow dissolve")
		if now >= next_capture:
			next_capture = now + 33333
			var sample: Dictionary = {"seconds":float(now-started)/1000000.0,"animation":snapshot.duplicate(true), "death_units":presentation.get("death_animation_units",[]).duplicate(true)}
			samples.append(sample)
			await RenderingServer.frame_post_draw
			images.append(_render_viewport.get_texture().get_image())
			if shown:
				for phase: float in [.15,.5,.9]:
					var key: String = str(phase)
					var distance: float = absf(float(snapshot.get("phase",0))-phase)
					if not targets.has(key) or distance < float(targets[key]["distance"]):
						targets[key] = {"index":images.size()-1,"distance":distance}
		if finished > 0 and now-finished > 200000: break
	_assert(clips.has(expected), label + " reaches actual " + expected + " playback")
	_assert(not bool(_instance.get("_animation_lock")), label + " returns input control")
	var folder: String = CONTEXT_OUTPUT.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
	for index: int in range(images.size()): images[index].save_jpg(folder.path_join("frame_%04d.jpg" % index),.92)
	for key: String in targets: images[int(targets[key]["index"])].save_png(CONTEXT_OUTPUT.path_join(label+"_"+key+".png"))
	_context_records.append({"label":label,"clips":clips.keys(),"frames":samples})

func _context_still(label: String) -> void:
	await RenderingServer.frame_post_draw
	_render_viewport.get_texture().get_image().save_png(CONTEXT_OUTPUT.path_join(label+".png"))
