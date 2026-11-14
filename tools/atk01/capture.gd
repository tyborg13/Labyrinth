extends SceneTree
## atk-01 native proof: resume a real save written by the audit at a real
## decision point (production boot path), then hover PASS or a hero-movement
## destination with a real pointer motion and save the 1920x1080 frame.
## Usage (after --): --save-dir <repro dir> --tile x,y|pass --out <png> [--expect <json>]
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
var canvas: SubViewport
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	# Headless checks of the same summary need a draw boundary for production coroutines.
	if DisplayServer.get_name() == "headless": process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _arg(name: String, fallback: String = "") -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var i: int = args.find(name)
	return args[i + 1] if i >= 0 and i + 1 < args.size() else fallback

func _run() -> void:
	var save_dir: String = _arg("--save-dir")
	var out: String = _arg("--out")
	DirAccess.make_dir_recursive_absolute(out.get_base_dir())
	Store.set_storage_path("user://progression.json")
	Store.set_run_storage_path("user://current_run.save")
	_check(DirAccess.copy_absolute(save_dir.path_join("progression.json"), ProjectSettings.globalize_path("user://progression.json")) == OK, "copy profile")
	_check(DirAccess.copy_absolute(save_dir.path_join("run.save"), ProjectSettings.globalize_path("user://current_run.save")) == OK, "copy real save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
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
	for frame: int in range(90): await process_frame
	await create_timer(2.0).timeout
	var parsed: Variant = str_to_var(FileAccess.get_file_as_string(save_dir.path_join("combat_state.txt")))
	if not parsed is Dictionary:
		push_error("ATK01 CAPTURE: no audited combat state in " + save_dir)
		quit(1)
		return
	var expected: Dictionary = parsed
	var state: Dictionary = scene.get("_combat_state")
	_check(str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat", "resumed into real combat")
	_check(state.get("player", {}).get("pos") == expected["player"]["pos"] and state.get("enemies") == expected["enemies"], "resumed board equals the audited decision point")
	_check(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0), "UI scale 100%")
	var board: Control = scene.get("board_view")
	var target: String = _arg("--tile", "pass")
	var summary: Dictionary = {}
	if target == "pass":
		var chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
		_check(chip != null, "PASS control present")
		if chip != null: _motion(chip.get_global_rect().get_center())
	else:
		var parts: PackedStringArray = target.split(",")
		var tile := Vector2i(int(parts[0]), int(parts[1]))
		scene.call("_begin_player_movement_selection")
		await create_timer(0.3).timeout
		_check((scene.get("_player_movement_target_tiles") as Array).has(tile), "destination is a legal hero move")
		_motion(board.get_global_transform_with_canvas() * Vector2(board.call("world_position_for_tile", tile)))
	await create_timer(1.2).timeout
	if target != "pass":
		_check(scene.get("_hovered_board_tile") == Vector2i(int(target.get_slice(",", 0)), int(target.get_slice(",", 1))), "real pointer owns the hovered tile")
	summary = scene.call("_pass_preview_summary")
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		var picture: Image = canvas.get_texture().get_image()
		_check(picture.get_size() == SIZE and picture.save_png(out) == OK, "1920x1080 PNG")
	var rows: Array = preload("res://scripts/pass_forecast_focus_tooltip.gd").row_losses(summary).values()
	var chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	var shown: Array = []
	if chip != null:
		for row: Dictionary in chip.get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []): shown.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control if chip != null else null
	_check(panel != null and panel.is_visible_in_tree(), "forecast panel is open on screen")
	print("ATK01 CAPTURE %s summary hp=%d block=%d stoneskin=%d tone=%s rows=%s panel=%s" % [out, int(summary.get("hp_loss", 0)), int(summary.get("block_loss", 0)), int(summary.get("stoneskin_loss", 0)), summary.get("tone", ""), str(rows), str(shown)])
	if FileAccess.file_exists(out): print(out)
	for failure: String in failures: push_error(failure)
	print("ATK01 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)

func _motion(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	root.push_input(motion, true)

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
