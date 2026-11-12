extends SceneTree

const Cases = preload("res://tools/ptf07/forecast_cases.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const OUTPUT_DIR: String = "/private/tmp/labyrinth_codex/ptf-08/captures"
const PROOF_VIEWPORT := Vector2i(1920, 1080)
const HOVER_SETTLE_SECONDS: float = 1.0
const DEFIANCE_ROW_VALUE: String = "−1 → 4/24"
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
	for kind: String in ["second_move", "fatigue", "safe", "defiance"]:
		var state: Dictionary = Cases.fixture(kind)
		var engine := Run.new()
		var run_state: Dictionary = engine.create_new_run(123, Progression.default_data())
		for coord: Vector2i in engine.available_moves(run_state):
			if str(engine.room_metadata(run_state, coord).get("type", "")) == "combat":
				run_state = engine.move_to_room(run_state, coord)
				break
		run_state["mode"] = "combat"
		if kind == "defiance":
			apply_defiance_fixture(run_state, state)
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
		if chip == null:
			failed = true
			continue
		if scene.find_child("PassPreviewForecastLine", true, false) != null or scene.find_child("PassPreviewDamageRow", true, false) != null:
			failed = true
			print("FAIL: obsolete strip nodes remain")
		root.warp_mouse(Vector2.ZERO)
		chip.grab_focus()
		await create_timer(0.12).timeout
		await process_frame
		var focus_rect: Rect2 = require_panel(chip, kind, "focus")
		if kind == "defiance" and not require_defiance(chip):
			continue
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
		if kind == "defiance" and not require_defiance(chip):
			continue
		await capture(kind + "_hover")
		chip.release_focus()
		root.warp_mouse(Vector2.ZERO)
		var exit_motion := InputEventMouseMotion.new()
		exit_motion.position = Vector2.ZERO
		root.push_input(exit_motion, true)
		await process_frame
		await process_frame
		await create_timer(0.12).timeout
		var retained_panel: Control = chip.get_node("PassForecastFocusTooltip") as Control
		if retained_panel.visible:
			failed = true
			print("FAIL: panel remains visible after hover/focus exit")
		for badge: Node in scene.find_children("PassForecastDoubleTurnBadge", "", true, false):
			if (badge as Control).visible:
				failed = true
				print("FAIL: rail badge remains visible after hover/focus exit")
		print("PROOF %s: %s | %s" % [kind, str(chip.get_meta("forecast_rows", [])), chip.tooltip_text.replace("\n", " / ")])
	root.warp_mouse(Vector2.ZERO)
	scene.queue_free()
	await process_frame
	print(OUTPUT_DIR)
	print("PTF08 VISUAL RESULT: %s" % ("FAIL" if failed else "PASS"))
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
	if panel.get_meta("forecast_rows", []) != chip.get_meta("forecast_rows", []):
		failed = true
		print("FAIL: panel must display current icon rows")
	if kind == "second_move":
		var badge: Control = root.find_child("PassForecastDoubleTurnBadge", true, false) as Control
		if badge == null or not badge.is_visible_in_tree():
			failed = true
			print("FAIL: missing rail ×2 badge")
	return bounds

func require_defiance(chip: Button) -> bool:
	var summary: Dictionary = chip.get_meta("pass_forecast_summary", {})
	var summary_ok: bool = int(summary.get("defiance_spent", 0)) == 1 and int(summary.get("projected_hp", -1)) == 4
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip") as Control
	var row_ok: bool = false
	if panel != null and panel.is_visible_in_tree():
		for row: Dictionary in panel.get_meta("forecast_rows", []):
			for part: Dictionary in row.get("parts", []):
				if str(part.get("icon", "")) == "defiance" and str(part.get("text", "")) == DEFIANCE_ROW_VALUE:
					row_ok = true
	if not summary_ok:
		failed = true
		print("FAIL: Defiance capture requires one charge spent and projected Health 4")
	if not row_ok:
		failed = true
		print("FAIL: Defiance capture requires visible defiance icon row: " + DEFIANCE_ROW_VALUE)
	return summary_ok and row_ok

static func apply_defiance_fixture(run_state: Dictionary, state: Dictionary) -> void:
	# Run loading derives capacity before repairing combat charges. Mirror the
	# protected fixture on the run and supply its capacity through the run bonus.
	run_state["event_defiance_bonus"] = int(state[Run.DEFIANCE_CAPACITY_KEY])
	run_state[Run.DEFIANCE_CAPACITY_KEY] = int(state[Run.DEFIANCE_CAPACITY_KEY])
	run_state[Run.DEFIANCE_REMAINING_KEY] = int(state[Run.DEFIANCE_REMAINING_KEY])
