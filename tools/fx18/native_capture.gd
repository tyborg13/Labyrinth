extends "res://tools/fx15/native_capture.gd"
## Fixed-rate observation of production RunScene, shared by headless and native proof.

const Cases = preload("res://tools/fx18/cases.gd")
const DRAGON_CROP := Vector2i(960, 720)
const RELEASE_OFFSET_FRAMES: int = 6
const CONTACT_OFFSETS: Array[int] = [0, 6, 14, 22]
const CLIP_FRAMES: int = 150

var _base_dir: String
var _witness: String
var _dragon_fixture: Dictionary
var _take_camera_center: Vector2

func _take() -> void:
	_case = _arg("--case")
	_output = _arg("--out")
	_base_dir = _arg("--base-dir")
	_record = OS.get_cmdline_user_args().has("--record-part")
	if not Cases.STRIPS.has(_case) or _output.is_empty():
		_fail("Provide an FX-18 strip case and output directory.")
		return
	if DisplayServer.get_name() == "headless" or Engine.get_write_movie_path().is_empty() or Clock._read_movie_fps() != FPS or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Use tools/fx18/native.sh for a native 60 fps cel-look take.")
		return
	var report: Dictionary = await _dragon_take(_case, _output, false)
	if report.is_empty(): return
	print("FX-18 NATIVE %s" % JSON.stringify(report))
	quit()

func _install_plan_clock() -> void:
	process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	_plan_frame = PlanFrame.new()
	_plan_frame.process_priority = 1000
	root.add_child(_plan_frame)

func _dragon_take(id: String, output: String, reduced: bool) -> Dictionary:
	_case = id
	_output = output
	_reduced = reduced
	_complete = false
	_steps.clear()
	DirAccess.make_dir_recursive_absolute(_output)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["reduced_motion"] = reduced
	Settings.save_settings(settings)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	_dragon_fixture = Cases.fixture(id, _run_engine, _combat_engine, profile, DEFAULT_SEED, _witness)
	if _dragon_fixture.is_empty():
		_fail("No real resolver step for " + id)
		return {}
	var step: Dictionary = _dragon_fixture["step"]
	_steps.append(step)
	_targets = Dragon.tiles(step)
	if _targets.is_empty():
		_fail("Empty resolved targets for " + id)
		return {}
	if not await _start_take(_dragon_fixture):
		_fail("Could not resume a 1920x1080 RunScene with HUD at 100% UI scale.")
		return {}
	var report: Dictionary = await _observe_dragon()
	_viewport.queue_free()
	await process_frame
	if report.is_empty(): return {}
	var file := FileAccess.open(_output.path_join("take.json"), FileAccess.WRITE)
	if file == null:
		_fail("Could not write take.json.")
		return {}
	file.store_string(JSON.stringify(report, "\t"))
	print("FX-18 TAKE %s %s" % ["headless" if _plan else "renderer", _output.path_join("take.json")])
	return report

func _start_take(fixture: Dictionary) -> bool:
	if not ProgressionStore.save_data(fixture["profile"]) or not ProgressionStore.save_run_state(fixture["run"]): return false
	root.size = SinkSize
	root.content_scale_size = SinkSize
	root.content_scale_factor = 1.0
	_viewport = SubViewport.new()
	_viewport.size = CanvasSize
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _plan else SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	root.set_meta("labyrinth_resume_saved_run", true)
	_run = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if not _base_dir.is_empty():
		_run.set_script(load(_base_dir.path_join("run_scene.gd")))
		_run.get_node("BoardUnderlay/CombatBoard").set_script(load(_base_dir.path_join("combat_board_view.gd")))
	_run._combat_pacing.free()
	_run._combat_pacing = FixedPacing.new()
	_run._combat_pacing.install(_run)
	_viewport.add_child(_run)
	_run._close_dialogue()
	for frame: int in READY_FRAMES:
		await process_frame
		var moving: Tween = _run._board_centering_tween
		if _run.initial_presentation_is_ready() and (moving == null or not moving.is_running()): break
	for frame: int in SETTLE_FRAMES: await process_frame
	var scale: float = preload("res://scripts/ui_typography.gd").ui_scale(_run)
	if _run._run_state.get("mode") != "combat" or not _run.hand_scroll.is_visible_in_tree() or not is_equal_approx(scale, 1.0):
		_fail("Unexpected resumed state: mode=%s HUD=%s scale=%s." % [_run._run_state.get("mode"), _run.hand_scroll.is_visible_in_tree(), scale])
		return false
	return true

func _observe_dragon() -> Dictionary:
	var board: Control = _run.board_view
	var area := Rect2(board._tile_center(_targets[0]), Vector2.ZERO)
	for tile: Vector2i in _targets: area = area.expand(board._tile_center(tile))
	_take_camera_center = board.get_global_transform_with_canvas() * area.get_center()
	var strip: Image
	var raw: FileAccess
	if not _plan:
		strip = Image.create_empty(DRAGON_CROP.x * (2 + CONTACT_OFFSETS.size()), DRAGON_CROP.y, false, Image.FORMAT_RGB8)
		if _record:
			raw = FileAccess.open(_output.path_join("frames.rgb"), FileAccess.WRITE)
			if raw == null:
				_fail("Could not open recording stream.")
				return {}
	var release: int = -1
	var contact: int = -1
	var done: int = -1
	var columns: Dictionary
	var clip_frames: int = 0
	var samples: Dictionary
	var numbers: int = -1
	var action_frames: Dictionary
	_run.set_runtime_performance_instrumentation_enabled(true)
	_run.clear_runtime_animation_clock_snapshot()
	_drive_take()
	for frame: int in TAKE_LIMIT:
		if _plan:
			await _plan_frame.presented
		else:
			await process_frame
			await RenderingServer.frame_post_draw
		if _complete and done < 0: done = frame
		var shown: Dictionary = board.presentation
		if _matches_step(shown.get("effect", {})):
			var progress: float = float(shown.get("effect_progress", 0.0))
			var count: int = int(shown.get("effect_frame_count", 0))
			if count > 0 and progress < 1.0: action_frames[roundi(progress * count)] = true
			if release < 0 and progress >= Dragon.RELEASE: release = frame
			if contact < 0 and progress >= Dragon.CONTACT: contact = frame
			if numbers < 0 and not shown.get("floating_texts", []).is_empty(): numbers = frame
			if _plan: _observe_stamps(samples, frame, progress, board)
		var column: int = -1
		if release == frame: column = 0
		elif release >= 0 and frame == release + RELEASE_OFFSET_FRAMES: column = 1
		elif contact >= 0 and CONTACT_OFFSETS.has(frame - contact): column = 2 + CONTACT_OFFSETS.find(frame - contact)
		if column >= 0: columns[column] = frame
		var record_frame: bool = _record and frame < CLIP_FRAMES
		if record_frame: clip_frames += 1
		if not _plan and (column >= 0 or record_frame):
			var image: Image = _viewport.get_texture().get_image()
			if image == null or image.get_size() != CanvasSize:
				_fail("Expected a 1920x1080 framebuffer.")
				return {}
			image.convert(Image.FORMAT_RGB8)
			if record_frame: raw.store_buffer(image.get_data())
			if column >= 0:
				var crop := Rect2i(Vector2i(_take_camera_center.round()) - DRAGON_CROP / 2, DRAGON_CROP)
				var visible: Rect2i = crop.intersection(Rect2i(Vector2i.ZERO, CanvasSize))
				strip.blit_rect(image, visible, Vector2i(column * DRAGON_CROP.x, 0) + visible.position - crop.position)
				if column == 2 and not _save(image, "native-evidence.png"): return {}
		if done >= 0 and contact >= 0 and frame >= contact + CONTACT_OFFSETS[-1] and (not _record or frame >= CLIP_FRAMES - 1): break
	if raw != null: raw.close()
	if release < 0 or contact < 0 or done < 0:
		_fail("%s incomplete action, release %d, contact %d, done %d." % [_case, release, contact, done])
		return {}
	if not _reduced and columns.size() != 2 + CONTACT_OFFSETS.size():
		_fail("%s incomplete strip columns %s." % [_case, columns])
		return {}
	if _record and (clip_frames != CLIP_FRAMES or contact >= CLIP_FRAMES):
		_fail("%s has no complete recorded segment." % _case)
		return {}
	if not _plan and not _save(strip, "strip.png"): return {}
	var stats: Dictionary = _run.runtime_animation_clock_snapshot()
	return {
		"case": _case, "release_frame": release, "contact_frame": contact, "numbers_frame": numbers,
		"completion_frame": done, "authored_frames": stats.get("authored_frames"),
		"authored_duration_usec": stats.get("authored_duration_usec"),
		"rendered_frames": stats.get("rendered_frames"), "attack_frame_count": action_frames.size(),
		"strip_frames": columns, "clip_frames": clip_frames,
		"targets": _coord_strings(_targets), "stamps": samples,
	}

func _matches_step(effect: Dictionary) -> bool:
	var expected: Dictionary = _dragon_fixture["step"]
	return effect.get("actor_key") == expected["actor_key"] and effect.get("action_type") == expected["action_type"]

func _observe_stamps(samples: Dictionary, frame: int, progress: float, board: Control) -> void:
	for stamp: Fx.Stamp in board._tile_bursts._stamps:
		var key: String = _coord(stamp.tile)
		var entry: Dictionary = samples.get_or_add(key, {"submitted": frame, "progress": progress, "delay": stamp.birth - board._tile_bursts._seconds, "visible": -1, "rows": {}, "instances": {}, "depth": true})
		var face: String = "front" if stamp.front else "rear"
		entry["rows"][face] = stamp.sample.y
		entry["instances"][str(stamp.get_instance_id())] = face
		var layers: Dictionary = board._scene_front_effect_render_layers_by_tile if stamp.front else board._scene_back_effect_render_layers_by_tile
		entry["depth"] = entry["depth"] and layers.values().has(stamp.get_parent())
		if stamp.visible and entry["visible"] < 0:
			entry["visible"] = frame
			entry["cell"] = stamp.sample.x
