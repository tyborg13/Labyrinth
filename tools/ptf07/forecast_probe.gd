extends SceneTree

const Cases = preload("res://tools/ptf07/forecast_cases.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-07/captures"
const PROOF_VIEWPORT := Vector2i(1920, 1080)
const HOVER_SETTLE_SECONDS: float = 1.0
var failed: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Settings.set_storage_path("user://ptf07_settings.json")
	Progression.set_storage_path("user://ptf07_progression.json")
	Progression.set_run_storage_path("user://ptf07_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["display_mode"] = "windowed"
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROOF_VIEWPORT
	root.size = PROOF_VIEWPORT
	DirAccess.make_dir_recursive_absolute(OUTPUT_DIR)
	var scene: Node = preload("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	await process_frame
	for kind: String in ["second_move", "fatigue", "safe"]:
		var state: Dictionary = Cases.fixture(kind)
		var engine := Run.new()
		var run_state: Dictionary = engine.create_new_run(123, Progression.default_data())
		for coord: Vector2i in engine.available_moves(run_state):
			if str(engine.room_metadata(run_state, coord).get("type", "")) == "combat":
				run_state = engine.move_to_room(run_state, coord)
				break
		run_state["mode"] = "combat"
		run_state["combat_state"] = state
		scene.call("_load_run_state", run_state)
		scene.set("_animation_lock", false)
		scene.call("_reset_card_resolution")
		scene.call("_mark_combat_preview_state_changed")
		scene.call("_refresh_ui")
		await scene.call("_await_pass_preview_cache_warm")
		scene.call("_refresh_selected_card_forecast")
		await process_frame
		await process_frame
		var chip: Button = scene.find_child("PassPreviewChip", true, false) as Button
		var label: Label = scene.find_child("PassPreviewForecastLine", true, false) as Label
		if chip == null or label == null:
			failed = true
			continue
		var expected: String = "+ ? 2ND MOVE" if kind == "second_move" else "-15" if kind == "fatigue" else "SAFE"
		if not label.text.contains(expected):
			failed = true
			print("FAIL: %s label: %s" % [kind, label.text])
		root.warp_mouse(Vector2.ZERO)
		chip.grab_focus()
		await process_frame
		await process_frame
		var focus_rect: Rect2 = require_panel(chip, kind, "focus")
		await capture(kind + "_focus")
		chip.release_focus()
		var at: Vector2 = chip.get_global_rect().get_center()
		root.warp_mouse(at)
		var motion := InputEventMouseMotion.new()
		motion.position = at
		root.push_input(motion, true)
		await create_timer(HOVER_SETTLE_SECONDS).timeout
		var hover_rect: Rect2 = require_panel(chip, kind, "hover")
		if hover_rect != focus_rect:
			failed = true
			print("FAIL: hover/focus placement differs for " + kind)
		await capture(kind + "_hover")
		print("PROOF %s: %s | %s" % [kind, label.text, chip.tooltip_text.replace("\n", " / ")])
	root.warp_mouse(Vector2.ZERO)
	scene.queue_free()
	await process_frame
	print(OUTPUT_DIR)
	print("PTF07 VISUAL RESULT: %s" % ("FAIL" if failed else "PASS"))
	quit(1 if failed else 0)

func capture(stem: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = OUTPUT_DIR.path_join(stem + ".png")
	if root.get_texture().get_image().save_png(path) != OK:
		failed = true
		print("FAIL: save " + path)

func require_panel(chip: Button, kind: String, mode: String) -> Rect2:
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	if panel == null or not panel.is_visible_in_tree():
		failed = true
		print("FAIL: missing visible %s panel for %s" % [mode, kind])
		return Rect2()
	var bounds: Rect2 = panel.get_global_rect()
	var anchor: Rect2 = chip.get_global_rect()
	if not is_equal_approx(bounds.end.x, anchor.end.x) or not is_equal_approx(bounds.end.y, anchor.position.y):
		failed = true
		print("FAIL: %s panel must be above/right-aligned for %s" % [mode, kind])
	if panel.z_as_relative or panel.z_index != RenderingServer.CANVAS_ITEM_Z_MAX:
		failed = true
		print("FAIL: panel must paint above HUD")
	if str(panel.get_meta("forecast_text", "")) != chip.tooltip_text or str(chip.call("_get_tooltip", Vector2.ZERO)) != "":
		failed = true
		print("FAIL: shared panel text/native suppression")
	if mode == "hover" and (chip.has_focus() or not bool(chip.get_meta("pass_pointer_hover", false))):
		failed = true
		print("FAIL: hover proof requires pointer hover without focus")
	return bounds
