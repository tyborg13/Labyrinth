extends "res://tools/fx18/native_capture.gd"

const Fixture = preload("res://tools/fx36/cases.gd")
const CONTACT_SAMPLES: Array[int] = [0, 2, 6, 10]
const DETAIL_CROP := Vector2i(320, 240)
const REEL_SAMPLES: int = 3 * FPS
const TAIL_SAMPLES: int = 16
const LEGACY_FLIGHT_PROGRESS: float = 0.42

var _routes: Array
var _contacts: Dictionary
var _bursts: Dictionary
var _bolts: Dictionary
var _spark_seen: bool

func _take() -> void:
	_plan = OS.get_cmdline_user_args().has("--plan")
	_record = OS.get_cmdline_user_args().has("--record")
	var id: String = _arg("--case")
	var output: String = _arg("--out")
	if id not in Fixture.NATIVE or not output.is_absolute_path():
		_fail("Provide a known FX-36 native case and an absolute output directory.")
		return
	if _plan:
		_install_plan_clock()
	elif DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx36/native.sh for a native 60 fps cel-look take.")
		return
	if not (await take_case(id, output, false)).is_empty(): quit()

func take_case(id: String, output: String, reduced: bool) -> Dictionary:
	_case = id
	_output = output
	_reduced = reduced
	_complete = false
	_routes.clear()
	_contacts.clear()
	_bursts.clear()
	_bolts.clear()
	_spark_seen = false
	DirAccess.make_dir_recursive_absolute(output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	_options = Fixture.options(id, DEFAULT_SEED)
	var run: Dictionary = _build_run_state("combat", profile)
	Fixture.configure(id, run["combat_state"])
	if not await _start_take({"run": run, "profile": profile}):
		_fail("Could not resume FX-36 fixture " + id)
		return {}
	_viewport.audio_listener_enable_2d = true
	var report: Dictionary = await _observe_take_fx36()
	_viewport.queue_free()
	await process_frame
	if report.is_empty(): return {}
	var file := FileAccess.open(output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write FX-36 take.")
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-36 TAKE " + output.path_join("take.json"))
	return report

func _drive_action() -> void:
	var state: Dictionary = _run._combat_state.duplicate(true)
	_run._animation_lock = true
	if _case == "capacitor":
		var result: Dictionary = _combat_engine.resolve_enemy_turn_with_steps(state, 0)
		for step: Dictionary in result["steps"]:
			if step.get("action_type") == "chain_discharge":
				_record_routes(step["chain_hits"])
		_run._combat_pacing.begin_enemies()
		await _run._animate_enemy_phase_steps(state, result["steps"], result["state"])
		_run._combat_pacing.end_scope()
	else:
		var card: String = Fixture.card_id(_case)
		var action: Dictionary = Fixture.Witness.Data.card_def(card)["actions"][0].duplicate(true)
		action["_card_id"] = card
		var aim: Vector2i = Fixture.Witness.PRIMARY
		var result: Dictionary = _combat_engine.resolve_player_action_for_presentation(state, action, aim)
		_record_routes(result["chain_hits"])
		_run._combat_pacing.begin_card()
		_run._begin_action_step_resolution_tracker(card, [action], [aim], false)
		await _run._animate_player_action_step(state, result["state"], card, action, aim, result["chain_hits"])
		_run._combat_pacing.end_scope()
		_run._combat_state = result["state"]
		_run._render_board_state(result["state"], {})
	_run._animation_lock = false
	_complete = true

func _record_routes(hits: Array) -> void:
	for index: int in hits.size():
		var hit: Dictionary = hits[index]
		var kind: String = hit.get("kind", "actor")
		var bolt: bool = index > 0 and kind == "actor" and hit["from"] != hit["to"]
		_routes.append({"from": hit["from"], "to": hit["to"], "kind": kind, "bolt": bolt})

func _observe_take_fx36() -> Dictionary:
	var board: Control = _run.board_view
	var raw: FileAccess
	if not _plan and _record:
		raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
		if raw == null:
			_fail("Could not open FX-36 reel stream.")
			return {}
	var done: int = -1
	var first_movie_frame: int = -1
	var reel_count: int = 0
	var columns: Dictionary
	var legacy_samples: Dictionary
	var legacy_flight: bool = OS.get_cmdline_user_args().has("--legacy-flight") and _case == "capacitor"
	_drive_action()
	var hops: Array = _routes.filter(func(route: Dictionary) -> bool: return route["bolt"])
	for frame: int in TAKE_LIMIT:
		if _plan: await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and done < 0: done = frame
		_observe_frame(board, frame)
		var samples: Array[Vector2i]
		for hop: int in hops.size():
			var tile: String = Fixture.Witness.coord(hops[hop]["to"])
			if not _contacts.has(tile): continue
			var column: int = CONTACT_SAMPLES.find(frame - int(_contacts[tile]["frame"]))
			if column < 0: continue
			samples.append(Vector2i(hop, column))
			var frames: Array = columns.get_or_add(str(hop + 1), [])
			frames.append(frame)
		var recording: bool = _record and frame < REEL_SAMPLES
		if recording:
			reel_count += 1
			if first_movie_frame < 0: first_movie_frame = Engine.get_frames_drawn() - 1
		var legacy_hop: int = _legacy_hop(board, hops, legacy_samples) if legacy_flight else -1
		if legacy_hop >= 0: legacy_samples[legacy_hop] = frame
		if not _plan and (recording or not samples.is_empty() or legacy_hop >= 0):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected the exact 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if recording: raw.store_buffer(image.get_data())
			for sample: Vector2i in samples:
				if not _capture_column(image, board, hops[sample.x], sample): return {}
			if legacy_hop >= 0 and not _save(image, "hop-%d-legacy-flight.png" % (legacy_hop + 1)): return {}
		if done >= 0 and frame >= done + TAIL_SAMPLES and (not _record or reel_count == REEL_SAMPLES): break
	if raw != null: raw.close()
	if done < 0 or columns.size() != hops.size() or columns.values().any(func(value: Array) -> bool: return value.size() != CONTACT_SAMPLES.size()):
		_fail("Incomplete FX-36 contact columns for " + _case)
		return {}
	if _record and reel_count != REEL_SAMPLES:
		_fail("Incomplete FX-36 game-speed segment for " + _case)
		return {}
	if legacy_flight and legacy_samples.size() != hops.size():
		_fail("Incomplete legacy Arc Lash flight evidence.")
		return {}
	return {"routes": _routes.duplicate(true), "damage": _contacts.duplicate(true), "bursts": _bursts.duplicate(true),
		"bolts": _bolts.values().duplicate(true), "opening_spark": _spark_seen,
		"columns": columns, "legacy_flight": legacy_samples, "done": done, "movie_first_frame": first_movie_frame, "reel_frames": reel_count}

func _legacy_hop(board: Control, hops: Array, samples: Dictionary) -> int:
	var effect: Dictionary = board.presentation.get("effect", {})
	if effect.get("kind") != "chain" or board.presentation.get("effect_progress", 0.0) < LEGACY_FLIGHT_PROGRESS:
		return -1
	for index: int in hops.size():
		var route: Dictionary = hops[index]
		if not samples.has(index) and route["from"] == effect.get("from") and route["to"] == effect.get("to") and not _contacts.has(Fixture.Witness.coord(route["to"])):
			return index
	return -1

func _observe_frame(board: Control, frame: int) -> void:
	for entry: Dictionary in board.presentation.get("floating_texts", []):
		if entry.get("kind") != "damage" or float(entry.get("alpha", 1.0)) <= 0.0: continue
		_contacts.get_or_add(Fixture.Witness.coord(entry["tile"]), {"frame": frame, "text": entry["text"]})
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		if not stamp.front or not stamp.visible: continue
		var tile: String = Fixture.Witness.coord(stamp.tile)
		var rows: Dictionary = _bursts.get_or_add(tile, {})
		rows.get_or_add(stamp.sample.y, {"frame": frame, "point": stamp.position})
	var shot: Variant = board._single_shot_fx
	if shot._shot_id == "spark" and shot._heads[0].visible and not _routes.is_empty() and shot._to_tile == _routes[0]["to"]:
		_spark_seen = true
	var slots: Array = board._scene_back_effect_render_layers_by_tile.values() + board._scene_front_effect_render_layers_by_tile.values()
	for slot: CanvasItem in slots:
		for child: Node in slot.get_children():
			if not child.name.begins_with("ChainBolt"): continue
			if child.visible:
				_observe_bolt(board, child, frame)
			elif _bolts.has(child.get_instance_id()) and child.is_queued_for_deletion():
				_bolts[child.get_instance_id()]["end_age"] = child.get("_seconds")

func _observe_bolt(board: Control, bolt: Sprite2D, frame: int) -> void:
	var id: int = bolt.get_instance_id()
	if not _bolts.has(id):
		var from: Vector2i = bolt.get("from_tile")
		var to: Vector2i = bolt.get("to_tile")
		var from_point: Vector2 = bolt.get("from_point")
		var to_point: Vector2 = bolt.get("to_point")
		var back: int = board._scene_render_layers_by_tile[from].get_index()
		var front: int = board._scene_render_layers_by_tile[to].get_index()
		var order: int = bolt.get_parent().get_index()
		var stretch: Transform2D = board.get_viewport().get_stretch_transform()
		var board_pixels: Transform2D = stretch * board.get_global_transform_with_canvas()
		var texture_pixels: Transform2D = stretch * bolt.get_global_transform_with_canvas()
		var image: Image = bolt.texture.get_image()
		var tips: Array[String]
		for point: Vector2 in [from_point, to_point]:
			var cell := Vector2i((texture_pixels.affine_inverse() * (board_pixels * point)).floor())
			tips.append(image.get_pixelv(cell).to_html() if Rect2i(Vector2i.ZERO, image.get_size()).has_point(cell) else "")
		_bolts[id] = {"from": Fixture.Witness.coord(from), "to": Fixture.Witness.coord(to),
			"from_point": from_point, "to_point": to_point, "start": frame,
			"birth_offset": Engine.get_process_frames() - int(bolt.get("start_frame")),
			"cell": bolt.get("cell_px"), "spark_cell": board._single_shot_fx._cells_px,
			"nearest": bolt.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"tips": tips, "depth": [mini(back, front), order, maxi(back, front)],
			"floor_depth": board._action_floor_render_layer.get_index(), "effects_depth": board._effects_render_layer.get_index(),
			"hud_depth": board._hud_render_layer.get_index(),
			"front_from": board._scene_front_effect_render_layers_by_tile[from].get_index(),
			"front_to": board._scene_front_effect_render_layers_by_tile[to].get_index(), "samples": []}
	var age: float = bolt.get("_seconds")
	_bolts[id]["last_age"] = age
	var samples: Array = _bolts[id]["samples"]
	var phase: int = bolt.get("phase")
	if not samples.is_empty() and samples[-1]["phase"] == phase:
		samples[-1]["last"] = frame
		return
	var image: Image = bolt.texture.get_image()
	var inks: int = 0
	var palette: Dictionary
	for y: int in image.get_height():
		for x: int in image.get_width():
			var color: Color = image.get_pixel(x, y)
			if color.a == 0.0: continue
			inks += 1
			palette[color.to_html()] = true
	samples.append({"phase": phase, "first": frame, "last": frame, "inks": inks, "age": age,
		"hash": hash(image.get_data()), "palette": palette.keys()})

func _capture_column(image: Image, board: Control, route: Dictionary, sample: Vector2i) -> bool:
	var name: String = "hop-%d" % (sample.x + 1)
	var start: Vector2 = board._tile_center(route["from"])
	var end: Vector2 = board._tile_center(route["to"])
	var center: Vector2 = board.get_global_transform_with_canvas() * start.lerp(end, 0.5)
	var crop: Image = image.get_region(_crop_at(center, CropSize))
	if not _save(crop, "%s-column-%d.png" % [name, sample.y]): return false
	if sample.y > 0: return true
	var detail: Image = image.get_region(_crop_at(center, DETAIL_CROP))
	detail.resize(DETAIL_CROP.x * 2, DETAIL_CROP.y * 2, Image.INTERPOLATE_NEAREST)
	return _save(image, name + "-contact.png") and _save(detail, name + "-contact-2x.png")

func _crop_at(center: Vector2, extent: Vector2i) -> Rect2i:
	var origin: Vector2i = Vector2i(center.round()) - extent / 2
	return Rect2i(origin.clamp(Vector2i.ZERO, CanvasSize - extent), extent)
