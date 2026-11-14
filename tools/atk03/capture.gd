extends SceneTree
## atk-03 native proof (not a test): resume a real save written by the atk-01
## audit at a real decision point (production boot path, cel look), then
##   1. rest: the compact intent discs at rest (the repeat foe's disc and pip),
##   2. pass: PASS hovered with a real pointer (the panel rows and totals),
##   3. after: PASS pressed with a real click; the live enemy round resolves and
##      the hero's losses are compared with the forecast the panel showed.
## It also times the disc flip on the next player turn (state commit -> the
## board showing the forecast's disc marks). Usage (after --):
##   --save-dir <repro dir> --out-dir <dir> --foe enemy_<id>
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const SIZE := Vector2i(1920, 1080)
const ROUND_FRAME_EVERY: int = 6
const ROUND_FRAME_LIMIT: int = 2400
var canvas: SubViewport
var failures: Array[String]
var report: Dictionary = {}

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out_dir: String = _arg("--out-dir")
	var foe: String = _arg("--foe")
	DirAccess.make_dir_recursive_absolute(out_dir.path_join("round"))
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy real save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	var container := SubViewportContainer.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	root.add_child(container)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(canvas)
	root.set_meta("labyrinth_resume_saved_run", true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	_motion(Vector2(150, 330))
	for frame: int in range(90): await process_frame
	await create_timer(2.0).timeout
	var expected: Dictionary = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	_check(str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat", "resumed into real combat")
	_check(state.get("player", {}).get("pos") == expected["player"]["pos"] and state.get("enemies") == expected["enemies"], "resumed board equals the audited decision point")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale 100%")
	var board: Control = scene.get("board_view")

	# 1. Rest: the disc of the repeat foe, against today's geometric at-rest rule.
	var geometric: Dictionary = _badge(Badges.build(engine, state, state).get("badges", []), foe)
	var rest: Dictionary = _badge((board.get("presentation") as Dictionary).get("threats_at_rest", {}).get("badges", []), foe)
	report["rest"] = {"foe": foe, "shown_danger": rest.get("danger"), "shown_repeats": rest.get("repeats"), "order": rest.get("order"), "geometric_danger": geometric.get("danger"), "discs_stale": Discs.stale((board.get("presentation") as Dictionary).get("threats_at_rest", {}), scene.get("_rest_pass_disc_marks"), int(scene.get("_combat_preview_revision")))}
	_check(bool(rest.get("danger", false)) and int(rest.get("repeats", 0)) >= 2, "the repeat foe's disc is red with its pip at rest")
	await _capture(out_dir.path_join("atk03_rest.png"))
	_crop(out_dir.path_join("atk03_rest.png"), out_dir.path_join("atk03_rest_disc_zoom.png"), board, rest)

	# 2. PASS hovered: the panel rows and totals.
	var chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	_check(chip != null, "PASS control present")
	var chip_center: Vector2 = chip.get_global_rect().get_center()
	_motion(chip_center)
	await create_timer(1.2).timeout
	var summary: Dictionary = scene.call("_pass_preview_summary")
	var rows: Array = []
	for row: Dictionary in chip.get_meta("forecast_rows", []):
		var parts: Array = []
		for part: Dictionary in row.get("parts", []): parts.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
		rows.append(("portrait:%s " % row["portrait"]["actor_key"] if row.has("portrait") else "") + " ".join(parts))
	var losses: Dictionary = preload("res://scripts/pass_forecast_focus_tooltip.gd").row_losses(summary)
	report["pass"] = {"rows": rows, "hp_loss": int(summary.get("hp_loss", 0)), "block_loss": int(summary.get("block_loss", 0)), "stoneskin_loss": int(summary.get("stoneskin_loss", 0)), "row_losses": losses, "counted_repeats": summary.get("counted_repeats", []), "repeated_enemy_names": summary.get("repeated_enemy_names", []), "unrevealed": summary.get("unrevealed_before_player", false), "umbra_unknown": summary.get("umbra_unknown_before_player", false)}
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	_check(panel != null and panel.is_visible_in_tree(), "forecast panel is open on screen")
	_check(not str(rows).contains("?"), "no '?' row for the visible repeat foe")
	_check(str(rows).contains("portrait:enemy:" + foe), "the repeat foe's portrait row is present")
	await _capture(out_dir.path_join("atk03_pass_hover.png"))

	# 3. Press PASS with a real click; the live round resolves.
	var hero_before: Dictionary = (scene.get("_combat_state") as Dictionary)["player"].duplicate(true)
	var revision_before: int = int(scene.get("_combat_preview_revision"))
	var turn_before: int = int((scene.get("_combat_state") as Dictionary).get("turn", 0))
	_click(chip_center)
	var started_msec: int = Time.get_ticks_msec()
	var commit_msec: int = -1
	var marks_msec: int = -1
	var flip_msec: int = -1
	var unlock_msec: int = -1
	var saved_frames: int = 0
	for frame: int in range(ROUND_FRAME_LIMIT):
		await process_frame
		if frame % ROUND_FRAME_EVERY == 0 and saved_frames < 120 and commit_msec < 0:
			await _capture(out_dir.path_join("round/frame_%04d.png" % frame), false)
			saved_frames += 1
		var live: Dictionary = scene.get("_combat_state")
		var now: int = Time.get_ticks_msec() - started_msec
		var player_turn: bool = engine.is_player_turn(live) and int(live.get("turn", 0)) > turn_before
		if player_turn and commit_msec < 0 and int(scene.get("_combat_preview_revision")) != revision_before: commit_msec = now
		if commit_msec >= 0:
			var revision: int = int(scene.get("_combat_preview_revision"))
			var marks: Dictionary = scene.get("_rest_pass_disc_marks")
			if marks_msec < 0 and int(marks.get("revision", -1)) == revision: marks_msec = now
			if flip_msec < 0 and marks_msec >= 0 and not Discs.stale((board.get("presentation") as Dictionary).get("threats_at_rest", {}), marks, revision): flip_msec = now
			if unlock_msec < 0 and not bool(scene.get("_animation_lock")): unlock_msec = now
			if flip_msec >= 0 and unlock_msec >= 0 and now - unlock_msec > 1500: break
	var hero_after: Dictionary = (scene.get("_combat_state") as Dictionary)["player"]
	var dealt: Dictionary = {"hp": int(hero_before["hp"]) - int(hero_after["hp"]), "block": maxi(0, int(hero_before.get("block", 0)) - int(hero_after.get("block", 0))), "stoneskin": maxi(0, int(hero_before.get("stoneskin", 0)) - int(hero_after.get("stoneskin", 0)))}
	report["after"] = {"dealt": dealt, "forecast": {"hp": int(summary.get("hp_loss", 0)), "block": int(summary.get("block_loss", 0)), "stoneskin": int(summary.get("stoneskin_loss", 0))}, "round_frames_saved": saved_frames}
	report["flip_timing_msec"] = {"state_commit": commit_msec, "marks_ready_after_commit": marks_msec - commit_msec if marks_msec >= 0 else -1, "board_flipped_after_commit": flip_msec - commit_msec if flip_msec >= 0 else -1, "input_unlocked_after_commit": unlock_msec - commit_msec if unlock_msec >= 0 else -1}
	_check(dealt["hp"] == int(summary.get("hp_loss", 0)) and dealt["block"] == int(summary.get("block_loss", 0)) and dealt["stoneskin"] == int(summary.get("stoneskin_loss", 0)), "the live round dealt exactly the forecast")
	_motion(Vector2(150, 330))
	await create_timer(0.6).timeout
	await _capture(out_dir.path_join("atk03_after_pass.png"))
	var file := FileAccess.open(out_dir.path_join("atk03_capture_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ATK03 CAPTURE REPORT " + JSON.stringify(report))
	for failure: String in failures: push_error(failure)
	print("ATK03 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _badge(badges: Array, key: String) -> Dictionary:
	for badge: Dictionary in badges:
		if str(badge.get("key", "")) == key: return badge
	return {}

func _capture(path: String, announce: bool = true) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = canvas.get_texture().get_image()
	_check(picture.get_size() == SIZE and picture.save_png(path) == OK, "1920x1080 PNG " + path.get_file())
	if announce: print(path)

# A 4x crop around the foe's compact disc (presentation only; for inspection).
func _crop(source: String, target: String, board: Control, badge: Dictionary) -> void:
	if not FileAccess.file_exists(source): return
	var layouts: Array[Dictionary] = Badges.layouts(board, [badge])
	if layouts.is_empty(): return
	var center: Vector2 = board.get_global_transform_with_canvas() * (layouts[0]["center"] as Vector2)
	var image: Image = Image.load_from_file(source)
	var region := Rect2i(Vector2i(center) - Vector2i(60, 60), Vector2i(120, 120)).intersection(Rect2i(Vector2i.ZERO, SIZE))
	var crop: Image = image.get_region(region)
	crop.resize(region.size.x * 4, region.size.y * 4, Image.INTERPOLATE_NEAREST)
	crop.save_png(target)

func _motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)

func _click(point: Vector2) -> void:
	for pressed: bool in [true, false]:
		var button := InputEventMouseButton.new()
		button.button_index = MOUSE_BUTTON_LEFT
		button.pressed = pressed
		button.position = point
		button.global_position = point
		root.push_input(button, true)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
