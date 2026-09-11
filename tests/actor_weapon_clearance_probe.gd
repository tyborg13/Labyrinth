extends "res://tests/actor_presentation_probe.gd"

func _run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = SIZE
	root.size = SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF))
	ProgressionStore.set_storage_path("user://presentation_progression.json")
	ProgressionStore.set_run_storage_path("user://presentation_run.save")
	ProgressionStore.clear_saved_run()
	_viewport = SubViewport.new()
	_viewport.size = SIZE
	_viewport.disable_3d = true
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_instance = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_instance)
	await _settle()
	_board = _instance.get("board_view") as Control
	for actor: String in ["warden", "harrier"]:
		_active_type = actor
		_observer_type = "grave_surgeon"
		await _fixture(GameData.enemy_def(actor)["intents"][0])
		await _raised_weapon_proof(actor)
	_write_proof()
	for error: String in _errors: push_error(error)
	print("FIXED HEAD HP ANCHOR: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _raised_weapon_proof(actor: String) -> void:
	var renderer: Node = _renderer(actor)
	renderer.set_process(false)
	var case_path: String = "stone_warden/v04" if actor == "warden" else "harrier/v02"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/" + case_path + "/cutout.json"))
	var rigs: Dictionary = renderer.get("rigs")
	for facing: String in ["front", "rear"]:
		renderer.set("facing", facing)
		renderer.set("mirrored", false)
		for view: String in rigs: (rigs[view] as Node2D).visible = view == facing
		var rig: Node2D = rigs[facing]
		rig.position = Vector2(128, 128)
		rig.scale = Vector2.ONE
		var minimum: int = 512
		var chosen: String = "rest"
		var chosen_phase: float = 0.0
		for clip: String in config["clips"]:
			for index: int in range(17):
				var phase: float = float(index) / 16.0
				rig.call("apply_pose", clip, phase)
				(renderer.get("viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var bounds: Rect2i = (renderer.call("texture") as Texture2D).get_image().get_used_rect()
				if bounds.position.y < minimum:
					minimum = bounds.position.y
					chosen = clip
					chosen_phase = phase
		rig.call("apply_pose", chosen, chosen_phase)
		(renderer.get("viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
		_board.call("_rebuild_hud_health_rects_cache")
		_board.call("_sync_dynamic_render_state", false, false, ["_hud_health_rects_cache", "_hud_layout_entries_cache"])
		_board.call("_queue_dynamic_redraw")
		await _settle()
		var unit: Dictionary = _unit(actor)
		var center: Vector2 = _board.call("_unit_center", unit)
		var rect: Rect2 = _board.call("_unit_texture_draw_rect", unit, center)
		var hp: Rect2 = _board.call("_unit_health_bar_rect", unit, center)
		var pixels: Image = (renderer.call("texture") as Texture2D).get_image()
		var scale: Vector2 = rect.size / Vector2(pixels.get_size())
		var region := Rect2i((hp.position - rect.position) / scale, hp.size / scale)
		region = region.intersection(Rect2i(Vector2i.ZERO, pixels.get_size()))
		var overlap: int = 0
		for y: int in range(region.position.y, region.end.y):
			for x: int in range(region.position.x, region.end.x):
				if pixels.get_pixel(x, y).a > 0.1: overlap += 1
		_check(is_equal_approx(float(_board.call("_unit_art_top_y", unit, center)) - hp.end.y, 4.0), actor + " " + facing + " raised weapon does not lift the HP bar away from the head")
		_proof["bounds"].append({"actor": actor, "facing": facing, "clip": chosen, "phase": chosen_phase, "opaque_pixels_under_hp": overlap})
		await _still(actor + "_" + facing + "_raised_weapon")
		renderer.set("_pose_signature", [])
	renderer.set_process(true)
