extends SceneTree
## atk-07 native proof (not a test): resume a real save the atk-07 audit wrote at
## a real decision point before a turn Freeze skips (production boot path, cel
## look), then
##   1. pass: PASS hovered with a real pointer (the panel rows and totals),
##   2. frozen: PASS pressed with a real click; the live round resolves and the
##      hero's next turn is skipped (captured when input unlocks),
##   3. after: PASS pressed again on the frozen turn; the live round after it
##      resolves. The span's real losses are compared with the forecast.
## Usage (after --): --save-dir <repro dir> --out-dir <dir> --name <prefix>
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Discs = preload("res://scripts/pass_forecast_discs.gd")
const ForecastRows = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const SIZE := Vector2i(1920, 1080)
const ROUND_FRAME_LIMIT: int = 6000
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
	var prefix: String = _arg("--name", "atk07")
	DirAccess.make_dir_recursive_absolute(out_dir)
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
	report["point"] = {"turn": int(state.get("turn", 0)), "hero_tile": str(state["player"]["pos"]), "hero_hp": int(state["player"].get("hp", 0)), "enemies": (state.get("enemies", []) as Array).map(func(e: Dictionary) -> String: return "%s %s hp %d" % [e.get("type", ""), str(e.get("pos")), int(e.get("hp", 0))])}
	var board: Control = scene.get("board_view")
	var rest: Array = []
	for badge: Dictionary in Discs.apply((board.get("presentation") as Dictionary).get("threats_at_rest", {}), scene.get("_rest_pass_disc_marks"), int(scene.get("_combat_preview_revision")), true).get("badges", []):
		rest.append({"key": badge.get("key"), "danger": badge.get("danger"), "repeats": badge.get("repeats")})
	report["rest_discs"] = rest

	# 1. PASS hovered: the panel rows and totals.
	var chip: Control = scene.find_child("PassPreviewChip", true, false) as Control
	_check(chip != null, "PASS control present")
	var chip_center: Vector2 = chip.get_global_rect().get_center()
	_motion(chip_center)
	await create_timer(1.2).timeout
	var summary: Dictionary = scene.call("_pass_preview_summary")
	report["pass"] = {"rows": _rows(chip), "hp_loss": int(summary.get("hp_loss", 0)), "block_loss": int(summary.get("block_loss", 0)), "stoneskin_loss": int(summary.get("stoneskin_loss", 0)), "defeat": bool(summary.get("defeat", false)), "row_losses": ForecastRows.row_losses(summary), "skipped_turns": int(summary.get("skipped_turns", 0)), "counted_repeats": summary.get("counted_repeats", []), "enemy_hits": summary.get("enemy_hits", {}), "enemy_activations": summary.get("enemy_activations", {}), "tone": summary.get("tone", "")}
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	_check(panel != null and panel.is_visible_in_tree(), "forecast panel is open on screen")
	await _capture(out_dir.path_join(prefix + "_pass_hover.png"))
	if panel != null: _crop(out_dir.path_join(prefix + "_pass_hover.png"), out_dir.path_join(prefix + "_pass_panel_2x.png"), panel.get_global_rect().grow(24.0))

	# 2. Press PASS; the live round resolves up to the hero's next turn.
	var hero_before: Dictionary = (scene.get("_combat_state") as Dictionary)["player"].duplicate(true)
	_click(chip_center)
	_motion(Vector2(150, 330))
	await _wait_for_player_turn(scene, engine, int(state.get("turn", 0)))
	var live: Dictionary = scene.get("_combat_state")
	var frozen: bool = bool((live.get("player_turn_restrictions", {}) as Dictionary).get("frozen", false))
	report["frozen_turn"] = {"frozen": frozen, "turn": int(live.get("turn", 0)), "hero_hp": int(live["player"].get("hp", 0)), "outcome": engine.combat_outcome(live)}
	_check(frozen or not engine.combat_outcome(live).is_empty(), "the hero's next turn is Frozen")
	await create_timer(0.6).timeout
	await _capture(out_dir.path_join(prefix + "_frozen_turn.png"))

	# 3. PASS again on the frozen turn; the live round after it resolves.
	var spans: int = 0
	while frozen and engine.combat_outcome(scene.get("_combat_state")).is_empty() and spans < 4:
		spans += 1
		var turn_now: int = int((scene.get("_combat_state") as Dictionary).get("turn", 0))
		_motion(chip_center)
		await create_timer(0.8).timeout
		_click(chip_center)
		_motion(Vector2(150, 330))
		await _wait_for_player_turn(scene, engine, turn_now)
		frozen = bool(((scene.get("_combat_state") as Dictionary).get("player_turn_restrictions", {}) as Dictionary).get("frozen", false))
	var hero_after: Dictionary = (scene.get("_combat_state") as Dictionary)["player"]
	var dealt: Dictionary = {"hp": int(hero_before["hp"]) - int(hero_after["hp"]), "block": maxi(0, int(hero_before.get("block", 0)) - int(hero_after.get("block", 0))), "stoneskin": maxi(0, int(hero_before.get("stoneskin", 0)) - int(hero_after.get("stoneskin", 0)))}
	var forecast: Dictionary = {"hp": int(summary.get("hp_loss", 0)), "block": int(summary.get("block_loss", 0)), "stoneskin": int(summary.get("stoneskin_loss", 0))}
	report["after"] = {"dealt_over_span": dealt, "forecast": forecast, "matches": dealt == forecast, "skipped_live": spans, "outcome": engine.combat_outcome(scene.get("_combat_state")), "turn": int((scene.get("_combat_state") as Dictionary).get("turn", 0))}
	await create_timer(0.6).timeout
	await _capture(out_dir.path_join(prefix + "_after_span.png"))
	var file := FileAccess.open(out_dir.path_join(prefix + "_capture_report.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("ATK07 CAPTURE REPORT " + JSON.stringify(report))
	for failure: String in failures: push_error(failure)
	print("ATK07 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL " + str(failures)))
	quit(0 if failures.is_empty() else 1)

func _wait_for_player_turn(scene: Node, engine: RefCounted, turn_before: int) -> void:
	var unlocked_at: int = -1
	for frame: int in range(ROUND_FRAME_LIMIT):
		await process_frame
		var live: Dictionary = scene.get("_combat_state")
		if not engine.combat_outcome(live).is_empty() and not bool(scene.get("_animation_lock")): return
		var ready: bool = engine.is_player_turn(live) and int(live.get("turn", 0)) > turn_before and not bool(scene.get("_animation_lock"))
		if ready and unlocked_at < 0: unlocked_at = Time.get_ticks_msec()
		if ready and Time.get_ticks_msec() - unlocked_at > 1200: return
	_check(false, "the live round reached the hero's turn")

func _rows(chip: Control) -> Array:
	var rows: Array = []
	for row: Dictionary in chip.get_meta("forecast_rows", []):
		var parts: Array = []
		for part: Dictionary in row.get("parts", []): parts.append("%s %s" % [part.get("icon", ""), part.get("text", "")])
		rows.append(("portrait:%s " % row["portrait"]["actor_key"] if row.has("portrait") else "") + " ".join(parts))
	return rows

func _capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var picture: Image = canvas.get_texture().get_image()
	_check(picture.get_size() == SIZE and picture.save_png(path) == OK, "1920x1080 PNG " + path.get_file())
	print(path)

# A 2x crop of the panel (presentation only; for inspection).
func _crop(source: String, target: String, rect: Rect2) -> void:
	if not FileAccess.file_exists(source): return
	var image: Image = Image.load_from_file(source)
	var region := Rect2i(rect).intersection(Rect2i(Vector2i.ZERO, SIZE))
	if region.size.x <= 0 or region.size.y <= 0: return
	var crop: Image = image.get_region(region)
	crop.resize(region.size.x * 2, region.size.y * 2, Image.INTERPOLATE_NEAREST)
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
