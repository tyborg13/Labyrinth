extends "res://tests/enemy_cutout_roster_gameplay_probe.gd"

## Native proof of the shared presentation pass, using the live RunScene path
## player/enemy movement scheduler and unchanged roster fixture builder.
const ActorPresentation = preload("res://scripts/actor_presentation.gd")
const PROOF: String = "user://probes/actor_presentation_v1"
var _walk_complete: bool = false
var _proof: Dictionary = {"size": [1920, 1080], "ui_scale": 1.0, "walks": [], "bounds": [], "transitions": [], "errors": []}

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
	_active_type = "grave_surgeon"
	_observer_type = "warden"
	await _fixture(GameData.enemy_def(_active_type)["intents"][0])
	await create_timer(0.45).timeout
	if OS.get_environment("LABYRINTH_PRESENTATION_FRAMING_ONLY").is_empty():
		await _record_walk("player", Vector2i(1, 0))
	var actor_types: Array = ActorPresentation.PROFILES.keys()
	var selected: String = OS.get_environment("LABYRINTH_PRESENTATION_ACTORS")
	if not selected.is_empty():
		actor_types.clear()
		for actor: String in selected.split(",", false):
			_check(ActorPresentation.has_profile(actor), "Requested proof actor exists: " + actor)
			if ActorPresentation.has_profile(actor):
				actor_types.append(actor)
	for actor: String in actor_types:
		_active_type = actor
		_observer_type = actor if OS.get_environment("LABYRINTH_PRESENTATION_OBSERVER") == "same" else "warden" if actor != "warden" else "grave_surgeon"
		await _fixture(GameData.enemy_def(actor)["intents"][0])
		await create_timer(0.45).timeout
		await _verify_views_and_top_row(actor)
		if OS.get_environment("LABYRINTH_PRESENTATION_FRAMING_ONLY").is_empty():
			await _record_walk(actor, Vector2i(1, 0))
			await _record_walk(actor, Vector2i(0, -1))
			await _audit_action_envelope(actor)
		print("PRESENTATION PROOF: " + actor)
		_write_proof()
	await _verify_transitions(false)
	await _verify_transitions(true)
	_write_proof()
	for error: String in _errors:
		push_error(error)
	print("ACTOR PRESENTATION PROOF DIR=" + ProjectSettings.globalize_path(PROOF))
	print("ACTOR PRESENTATION PROBE: " + ("PASS" if _errors.is_empty() else "FAIL"))
	_instance.queue_free()
	await process_frame
	quit(0 if _errors.is_empty() else 1)

func _fixture(intent: Dictionary, reduced: bool = false) -> void:
	# Each synthetic fixture represents a fresh combat at the reused test coord.
	await super._fixture(intent, reduced)
	_instance.set("_board_encounter_key", "")
	_instance.call("_refresh_ui")
	await _settle()

func _install(state: Dictionary) -> void:
	_instance.set("_combat_state", state.duplicate(true))
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["combat_state"] = state.duplicate(true)
	_instance.set("_run_state", run)
	_instance.call("_render_board_state", state.duplicate(true), {}, false)

func _unit(actor: String) -> Dictionary:
	for unit: Dictionary in _board.call("_visible_units"):
		if str(unit.get("key", "")) == ("player" if actor == "player" else "enemy_1"):
			return unit
	return {}

func _renderer(actor: String) -> Node:
	return _board.call("unit_cutout_renderer", _unit(actor))

func _verify_views_and_top_row(actor: String) -> void:
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["enemies"][0]["pos"] = Vector2i(4, 4)
	state["enemies"][1]["pos"] = Vector2i(7, 7)
	var points: Array[Vector2i]
	points.assign([Vector2i(4, 8), Vector2i(8, 4), Vector2i(4, 2), Vector2i(2, 4)])
	var initial_origin: Vector2 = _board.call("_board_origin")
	var initial_width: float = _board.call("_tile_width")
	for index: int in range(points.size()):
		var registrations_before: Dictionary = _board.call("_cutout_floor_registrations")
		var draws_before: Dictionary = _board.call("render_instrumentation_snapshot")["scene_tile_draw_counts"]
		state["player"]["pos"] = points[index]
		_install(state)
		await _settle()
		var draws_after: Dictionary = _board.call("render_instrumentation_snapshot")["scene_tile_draw_counts"]
		var registrations_after: Dictionary = _board.call("_cutout_floor_registrations")
		if registrations_before.get("enemy_1") != registrations_after.get("enemy_1"):
			var tile: Vector2i = _board.call("_effective_unit_tile", _unit(actor))
			var tile_key: String = "%d,%d" % [tile.x, tile.y]
			_check(int(draws_after.get(tile_key, 0)) > int(draws_before.get(tile_key, 0)), actor + " changed floor registration redraws its retained body in view " + str(index))
		var snapshot: Dictionary = _snapshot(actor, 1)
		var unit: Dictionary = _unit(actor)
		var center: Vector2 = _board.call("_unit_center", unit)
		var rect: Rect2 = _board.call("_unit_draw_rect_for_center", unit, center)
		var anchor: Vector2 = ActorPresentation.floor_anchor(actor, snapshot["facing"], snapshot["mirrored"])
		_check((rect.position + anchor * rect.size / 255.0).distance_to(center) < 0.01, actor + " authored support centroid sits over its tile/ring in view " + str(index))
		_check(initial_origin.is_equal_approx(_board.call("_board_origin")) and is_equal_approx(initial_width, _board.call("_tile_width")), actor + " facing/player movement preserves the camera")
		_measure_hp(actor, index)
		await _still(actor + "_view_" + str(index))
	state["enemies"][0]["pos"] = Vector2i(1, 1)
	state["player"]["pos"] = Vector2i(6, 6)
	_install(state)
	await _settle()
	_check(initial_origin.is_equal_approx(_board.call("_board_origin")) and is_equal_approx(initial_width, _board.call("_tile_width")), actor + " top-row move never corrects the camera after arrival")
	_assert_actor_inside(actor, "top_row")
	await _still(actor + "_top_row")
	if actor in ["warden", "zekarion"]:
		var router: Node = root.get_node_or_null("InputRouter")
		var input: Script = load("res://scripts/input_router.gd")
		router.call("set_forced_state_for_test", input.MODALITY_CONTROLLER, input.FAMILY_STEAM_DECK)
		_instance.call("_refresh_controller_interface")
		await _settle()
		_assert_actor_inside(actor, "top_row_controller")
		_check(initial_origin.is_equal_approx(_board.call("_board_origin")) and is_equal_approx(initial_width, _board.call("_tile_width")), actor + " header input modality cannot change the up-front fit")
		await _still(actor + "_top_row_controller")
		router.call("clear_forced_state_for_test")
		_instance.call("_refresh_controller_interface")
		await _settle()

func _record_walk(actor: String, direction: Vector2i) -> void:
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["player"]["pos"] = Vector2i(7, 1)
	state["enemies"][0]["pos"] = Vector2i(3, 4)
	state["enemies"][1]["pos"] = Vector2i(7, 7)
	var key: String = "player" if actor == "player" else "enemy_1"
	var start := Vector2i(3, 4)
	if actor == "player":
		state["player"]["pos"] = start
		state["enemies"][0]["pos"] = Vector2i(1, 1)
	_install(state)
	await _settle()
	var path: Array[Vector2i]
	path.assign([start, start + direction, start + direction * 2])
	var label: String = actor + ("_front_walk" if direction.x > 0 else "_rear_walk")
	var directory: String = PROOF.path_join(label)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	var frames: Array[Dictionary]
	var initial_origin: Vector2 = _board.call("_board_origin")
	var initial_width: float = _board.call("_tile_width")
	var initial_unit: Dictionary = _unit(actor)
	var from_point: Vector2 = _board.call("world_position_for_unit_origin", initial_unit, path[0])
	var to_point: Vector2 = _board.call("world_position_for_unit_origin", initial_unit, path[-1])
	_walk_complete = false
	_instance.set("_animation_lock", true)
	var started: int = Time.get_ticks_usec()
	_play_walk(state, key, path)
	var image_index: int = 0
	while not _walk_complete and Time.get_ticks_usec() - started < 8000000:
		await RenderingServer.frame_post_draw
		var seconds: float = float(Time.get_ticks_usec() - started) / 1000000.0
		var center: Vector2 = _board.call("_unit_center", _unit(actor))
		var file: String = "%04d.jpg" % image_index
		_viewport.get_texture().get_image().save_jpg(directory.path_join(file), 0.94)
		frames.append({"file": file, "seconds": seconds, "center": [center.x, center.y]})
		image_index += 1
		_check(initial_origin.is_equal_approx(_board.call("_board_origin")) and is_equal_approx(initial_width, _board.call("_tile_width")), label + " camera remains fixed for every travel frame")
	var elapsed: float = float(Time.get_ticks_usec() - started) / 1000000.0
	_check(_walk_complete, label + " finishes the actual RunScene animation")
	_check((_board.call("_unit_center", _unit(actor)) as Vector2).distance_to(to_point) < 0.01, label + " reaches the resolved destination")
	_proof["walks"].append({"actor": actor, "label": label, "seconds": elapsed, "distance": from_point.distance_to(to_point), "tile_width": initial_width, "frames": frames})
	await _still(label + "_arrival")
	_instance.set("_animation_lock", false)

func _play_walk(state: Dictionary, key: String, path: Array[Vector2i]) -> void:
	await _instance.call("_animate_actor_along_path", state, key, path, {})
	_walk_complete = true

func _audit_action_envelope(actor: String) -> void:
	# Sample the live production rigs, not a synthetic rectangle or legacy PNG.
	var state: Dictionary = (_instance.get("_combat_state") as Dictionary).duplicate(true)
	state["enemies"][0]["pos"] = Vector2i(1, 1)
	state["player"]["pos"] = Vector2i(6, 6)
	_install(state)
	await _settle()
	var renderer: Node = _renderer(actor)
	renderer.set_process(false)
	var case_actor: String = "stone_warden" if actor == "warden" else actor
	var version: String = "v04" if actor == "warden" else "v02" if actor == "harrier" else "v01"
	var config: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://experiments/cutouts/%s/%s/cutout.json" % [case_actor, version]))
	var rigs: Dictionary = renderer.get("rigs")
	var union := Rect2()
	for facing: String in ["front", "rear"]:
		for view: String in rigs:
			(rigs[view] as Node2D).visible = view == facing
		var rig: Node2D = rigs[facing]
		rig.position = Vector2(128, 128)
		rig.scale = Vector2.ONE
		var anchor: Vector2 = ActorPresentation.floor_anchor(actor, facing)
		for clip: String in config["clips"]:
			for index: int in range(17):
				var phase: float = float(index) / 16.0
				rig.call("apply_pose", clip, phase)
				(renderer.get("viewport") as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var bounds: Rect2 = Rect2((renderer.call("texture") as Texture2D).get_image().get_used_rect())
				bounds.position -= Vector2(128, 128) + anchor
				union = bounds if not union.has_area() else union.merge(bounds)
				var reflected := Rect2(Vector2(-bounds.end.x, bounds.position.y), bounds.size)
				union = union.merge(reflected)
				_check(ActorPresentation.body_envelope(actor).grow(0.1).encloses(bounds), "%s %s %s fits the fixed source envelope" % [actor, facing, clip])
	_proof["bounds"].append({"actor": actor, "rect": [union.position.x, union.position.y, union.size.x, union.size.y]})
	renderer.set("_pose_signature", [])
	renderer.set_process(true)
	_install(state)
	await _settle()

func _assert_actor_inside(actor: String, label: String) -> void:
	var unit: Dictionary = _unit(actor)
	var center: Vector2 = _board.call("_unit_center", unit)
	var texture: Texture2D = _board.call("_texture_for_unit", unit)
	var draw_rect: Rect2 = _board.call("_unit_texture_draw_rect", unit, center)
	var used := Rect2(texture.get_image().get_used_rect())
	var scale: Vector2 = draw_rect.size / texture.get_size()
	var visible_rect := Rect2(draw_rect.position + used.position * scale + _board.position, used.size * scale)
	var hp: Rect2 = _board.call("_unit_health_bar_rect", unit, center)
	hp.position += _board.position
	var viewport_rect := Rect2(Vector2(4, 4), Vector2(1912, 1072))
	_check(viewport_rect.encloses(visible_rect), actor + " full native silhouette stays on screen in " + label)
	var local_hp: bool = not bool(unit.get("boss_bar", false))
	_check(not local_hp or viewport_rect.encloses(hp), actor + " visible health bar stays on screen in " + label)
	var available: Rect2 = _instance.call("_board_fit_rect")
	_check(available.grow(0.1).encloses(visible_rect) and (not local_hp or available.grow(0.1).encloses(hp)), actor + " native silhouette and HP avoid the fixed header/hand reserve in " + label)
	for property: String in ["_boss_health_overlay", "_controller_prompt_bar"]:
		var header: Control = _instance.get(property) as Control
		if header != null and header.is_visible_in_tree():
			var header_rect: Rect2 = header.get_global_rect()
			_check(not visible_rect.intersects(header_rect) and (not local_hp or not hp.intersects(header_rect)), actor + " native silhouette and HP avoid actual " + property + " in " + label)

func _verify_transitions(reduced: bool) -> void:
	_active_type = "grave_surgeon"
	_observer_type = "warden"
	await _fixture(GameData.enemy_def(_active_type)["intents"][0], reduced)
	await create_timer(0.5).timeout
	var mode_label: String = "reduced" if reduced else "normal"
	var initial_width: float = _board.call("_tile_width")
	var initial_position: Vector2 = _board.position
	await _still(mode_label + "_combat_before_reward")
	var run: Dictionary = (_instance.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "reward"
	run["pending_reward"] = {"cards": ["quick_stab", "brace", "patch_up"], "heal_amount": 3, "board_state": (_instance.get("_combat_state") as Dictionary).duplicate(true)}
	_instance.set("_run_state", run)
	_instance.call("_refresh_ui")
	var started: int = Time.get_ticks_usec()
	var samples: Array[Dictionary]
	var middle_captured: bool = false
	var last_y: float = initial_position.y
	for frame: int in range(36):
		await create_timer(1.0 / 60.0).timeout
		var width: float = _board.call("_tile_width")
		var position: Vector2 = _board.position
		_check(is_equal_approx(width, initial_width), mode_label + " reward transition retains the exact combat scale")
		_check(position.y >= last_y - 0.01, mode_label + " reward board moves monotonically toward center")
		if not reduced:
			_check(absf(position.y - last_y) < 24.0, "Reward board eases without a positional jump")
		last_y = position.y
		samples.append({"seconds": float(Time.get_ticks_usec() - started) / 1000000.0, "y": position.y, "tile_width": width})
		if not middle_captured and frame >= 6:
			await _still(mode_label + "_reward_mid_transition")
			middle_captured = true
	await _still(mode_label + "_reward_centered")
	var framing: RefCounted = _board.get("_room_framing")
	var center: Vector2 = _board.position + (_board.call("_board_origin") as Vector2) + (framing.get("floor_bounds") as Rect2).get_center() * initial_width / 100.0
	_check(absf(center.y - 540.0) < 0.5, mode_label + " reward background floor is centered in the screen")
	_proof["transitions"].append({"mode": mode_label, "samples": samples, "floor_center": [center.x, center.y]})
	run["mode"] = "combat"
	_instance.set("_run_state", run)
	_instance.call("_refresh_ui")
	await create_timer(0.5).timeout
	_check(_board.position.distance_to(initial_position) < 0.01 and is_equal_approx(_board.call("_tile_width"), initial_width), mode_label + " returning to combat restores the exact framing")

func _still(label: String) -> void:
	await RenderingServer.frame_post_draw
	_viewport.get_texture().get_image().save_png(PROOF.path_join(label + ".png"))

func _write_proof() -> void:
	_proof["errors"] = _errors
	var file := FileAccess.open(PROOF.path_join("manifest.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(_proof, "\t"))

func _measure_hp(actor: String, index: int) -> void:
	var unit: Dictionary = _unit(actor)
	if bool(unit.get("boss_bar", false)): return
	var center: Vector2 = _board.call("_unit_center", unit)
	var texture: Texture2D = _board.call("_texture_for_unit", unit)
	var rect: Rect2 = _board.call("_unit_texture_draw_rect", unit, center)
	var used: Rect2i = texture.get_image().get_used_rect()
	var visible_top: float = rect.position.y + float(used.position.y) * rect.size.y / texture.get_height()
	var hp: Rect2 = _board.call("_unit_health_bar_rect", unit, center)
	var cached: Rect2 = (_board.get("_hud_health_rects_cache") as Dictionary).get("enemy_1", Rect2())
	_check(cached.is_equal_approx(hp), actor + " cached rendered HP matches its current painted facing " + str(index))
	_check(is_equal_approx(float(_board.call("_unit_art_top_y", unit, center)) - hp.end.y, 4.0), actor + " uses four pixels of body clearance")
	if not _proof.has("health_bars"): _proof["health_bars"] = []
	_proof["health_bars"].append({"actor": actor, "view": index, "visible_top": visible_top, "art_anchor_top": _board.call("_unit_art_top_y", unit, center), "hp_bottom": hp.end.y, "gap": visible_top - hp.end.y, "width": _board.call("_tile_width"), "source_top": used.position.y})
