extends "res://tools/gfix13/pass_truth.gd"
## Open the real Pass panel at both decision points. Headless runs record
## the instantiated panel's content and geometry; native runs also save PNGs.

const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const SIZE := Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const SETTLE_FRAMES: int = 8
const OUTPUT_DIR: String = "output/mrg-07"
var canvas: SubViewport

func _run() -> void:
	var headless: bool = DisplayServer.get_name() == "headless"
	var directory: String = ProjectSettings.globalize_path("res://").path_join(OUTPUT_DIR).path_join("headless" if headless else "native")
	DirAccess.make_dir_recursive_absolute(directory)
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = true
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.msaa_2d = root.msaa_2d
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	for kind: String in ["frozen_expiry", "earth_snare", "earth_snare_waits"]:
		await _capture(kind, directory, headless)
	print("GFIX13 CAPTURE %s: %s (%d checks, %d failures)" % ["HEADLESS" if headless else "NATIVE", "PASS" if failures == 0 else "FAIL", checks, failures])
	quit(0 if failures == 0 else 1)

func _capture(kind: String, directory: String, headless: bool) -> void:
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await _settle()
	var run: Dictionary
	if kind.begins_with("earth_snare"):
		run = _snare_run(scene)
		if kind == "earth_snare_waits":
			var state: Dictionary = run["combat_state"]
			state["cards_played_this_turn"] = state["cards_per_turn"]
	else:
		run = preload("res://scripts/run_engine.gd").new().create_new_run(Snare.FIXTURE_SEED, Store.default_data())
		run["combat_state"] = _block_state(kind)
		run["mode"] = "combat"
	scene._load_run_state(run)
	scene._animation_lock = false
	scene._reset_card_resolution()
	scene._mark_combat_preview_state_changed()
	scene._refresh_ui()
	await scene._await_pass_preview_cache_warm()
	scene._refresh_selected_card_forecast()
	await _settle()
	var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
	_check(chip != null and not chip.disabled and chip.is_visible_in_tree(), kind + ": available Pass chip")
	if chip == null:
		scene.queue_free()
		return
	chip.emit_signal("mouse_entered")
	await _settle()
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	_check(panel != null and panel.is_visible_in_tree(), kind + ": Pass panel opened")
	if panel == null:
		scene.queue_free()
		return
	var size: Vector2i = canvas.size
	var bounds: Rect2 = panel.get_global_rect()
	_check(size == SIZE and is_equal_approx(Typography.ui_scale(scene), UI_SCALE), kind + ": 1920×1080 at 100% UI scale")
	_check(bounds.has_area() and Rect2(Vector2.ZERO, Vector2(size)).encloses(bounds), kind + ": Pass panel fits on screen")
	var summary: Dictionary = chip.get_meta("pass_forecast_summary", {})
	var parts: Array
	for row: Dictionary in panel.get_meta("forecast_rows", []):
		for part: Dictionary in row.get("parts", []):
			parts.append("%s:%s" % [part["icon"], part["text"]])
	_check(not parts.is_empty(), kind + ": rendered panel has forecast rows")
	if kind == "frozen_expiry":
		_check(int(summary.get("skipped_turns", 0)) == 1 and int(summary.get("block_loss", -1)) == 0, kind + ": one skipped turn and zero Block lost")
		_check(not parts.any(func(part: String) -> bool: return part.begins_with("block:")), kind + ": no Block loss row")
	else:
		var acts_first: bool = kind == "earth_snare"
		_check(parts.count("turn_clock:?") == (1 if acts_first else 0), kind + ": clock row matches the hunter's initiative")
		_check(parts.has(":Safe") != acts_first, kind + ": Safe only when the hunter waits")
		_check(int(summary.get("hp_loss", -1)) == 0 and int(summary.get("block_loss", -1)) == 0, kind + ": Pass total remains zero")
	var basename: String = directory.path_join(kind + "_1920x1080")
	var receipt := FileAccess.open(basename + ".json", FileAccess.WRITE)
	_check(receipt != null, kind + ": write panel receipt")
	if receipt != null:
		receipt.store_string(JSON.stringify({
			"width": size.x, "height": size.y, "ui_scale": Typography.ui_scale(scene),
			"panel_bounds": [bounds.position.x, bounds.position.y, bounds.size.x, bounds.size.y],
			"rows": parts, "health_loss": summary.get("hp_loss"), "block_loss": summary.get("block_loss"),
			"new_arrival": summary.get("new_arrival_before_player"), "skipped_turns": summary.get("skipped_turns"),
		}, "\t") + "\n")
		receipt.close()
		print("GFIX13 CAPTURE %s %s" % [kind, basename + ".json"])
	if not headless:
		await RenderingServer.frame_post_draw
		var image: Image = canvas.get_texture().get_image()
		_check(image != null and image.get_size() == SIZE and image.save_png(basename + ".png") == OK, kind + ": write native image")
		print(basename + ".png")
	scene.queue_free()
	await process_frame

func _settle() -> void:
	for frame: int in range(SETTLE_FRAMES):
		await process_frame
