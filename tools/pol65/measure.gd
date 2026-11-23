extends "res://tools/scn01/census.gd"
## Headless HUD measurements from the same Continue checkpoints as the census.

const IDLE_FRAMES: int = 120
const LAYOUT_PHASE: String = "deferred_layout_boss_health_overlay"
const DESKTOP_SIZE := Vector2i(1920, 1080)
const DECK_SIZE := Vector2i(1280, 800)

var _capture_viewport: Viewport


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var feedback: bool = args.size() == 6 and args[5] == "--feedback"
	if (args.size() != 5 and not feedback) or DisplayServer.get_name() != "headless":
		_finish("Expected save, profile, settings, size and UI scale arguments in a headless run.")
		return
	_headless = true
	if Runtime.apply_from_environment().is_empty():
		_finish("Measurement requires a task-local Godot user directory.")
		return
	for pair: Array in [
		[args[0], Store.DEFAULT_RUN_STORAGE_PATH],
		[args[1], Store.DEFAULT_STORAGE_PATH],
		[args[2], Settings.DEFAULT_STORAGE_PATH],
	]:
		if DirAccess.copy_absolute(pair[0], ProjectSettings.globalize_path(pair[1])) != OK:
			_finish("Could not install checkpoint file %s." % pair[0])
			return
	var ui_scale: float = float(args[4])
	var settings: Dictionary = Settings.load_settings()
	settings["ui_scale"] = ui_scale
	if not Settings.save_settings(settings):
		_finish("Could not persist the isolated UI scale setting.")
		return
	var dimensions: PackedStringArray = args[3].split("x")
	var size := Vector2i(int(dimensions[0]), int(dimensions[1]))
	_options = {"--mode": "combat"}
	Engine.max_fps = HEADLESS_FPS
	process_frame.connect(_submit_headless_frame)
	if is_equal_approx(ui_scale, 1.0):
		_viewport = SubViewport.new()
		_viewport.size = size
		_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		root.add_child(_viewport)
		_capture_viewport = _viewport
	else:
		# A Window applies the real scale setting with fractional logical
		# dimensions. SubViewport's integer size override would round them.
		root.mode = Window.MODE_WINDOWED
		root.size = size
		_capture_viewport = root
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_screen = packed.instantiate() as Control
	if not _prepare_checkpoint():
		_screen.free()
		_finish("Could not prepare the boss checkpoint.")
		return
	root.set_meta("labyrinth_resume_saved_run", true)
	_capture_viewport.add_child(_screen)
	var input := InputPath.new(self, _capture_viewport, _screen, {})
	_capture_tree = _capture_viewport
	await _settle(input, null)
	var overlay: Control = _screen.get("_boss_health_overlay")
	var run: Dictionary = _screen.get("_run_state")
	if _result["capped"] or not input.matches() or run.get("mode") != "combat" or not overlay.is_visible_in_tree():
		_finish("The restored boss HUD did not settle.")
		return
	_result.merge(_measure(overlay, run))
	if not is_equal_approx(root.content_scale_factor, ui_scale):
		_finish("The live window did not apply the requested UI scale.")
		return
	if feedback and _viewport != null:
		_result["idle"] = await _measure_idle()
		if size == DECK_SIZE:
			await _measure_feedback_lifecycle(input, overlay, run)
	_finish("")


func _measure(overlay: Control, run: Dictionary) -> Dictionary:
	var name_label: Label = _screen.get("_boss_health_name")
	var frame: Control = _screen.get("_boss_health_frame")
	var stats: Control = _screen.get("stats_label")
	var title_box: Control = _screen.get("title_box")
	var band: Rect2 = overlay.get_global_rect()
	var stretch: Transform2D = _capture_viewport.get_stretch_transform()
	var title_right: float = title_box.get_global_rect().position.x
	for child: Node in title_box.get_children():
		var line := child as Label
		if line == null or not line.is_visible_in_tree() or line.text.is_empty():
			continue
		var rect: Rect2 = line.get_global_rect()
		if band.position.y < rect.end.y and rect.position.y < band.end.y:
			title_right = maxf(title_right, rect.position.x + line.get_minimum_size().x * line.get_global_transform().x.length())
	var buttons: Dictionary = {}
	var top_bar: Control = _screen.get("top_bar")
	for child: Node in top_bar.get_children():
		if child is Button and child.is_visible_in_tree():
			buttons[str(child.name)] = _pixel_rect(child)[0]
	var title_children: Dictionary = {}
	for child: Control in title_box.get_children():
		title_children[str(child.name)] = {"visible": child.is_visible_in_tree(), "rect": _pixel_rect(child)}
	return {
		"title_right": (stretch * Vector2(title_right, 0.0)).x,
		"stats_left": _pixel_rect(stats)[0],
		"buttons": buttons,
		"overlay": _pixel_rect(overlay),
		"name": _pixel_rect(name_label),
		"frame": _pixel_rect(frame),
		"name_width": name_label.get_minimum_size().x * stretch.x.length(),
		"line_count": name_label.get_line_count(),
		"name_text": name_label.text,
		"name_font_size": name_label.get_theme_font_size("font_size"),
		"debug_boss_run": run.get("debug_boss_run", false),
		"section_map_version": run.get("section_map_version", 0),
		"viewport_size": str(_capture_viewport.get_visible_rect().size),
		"pixel_scale": stretch.x.length(),
		"title_children": title_children,
		"relic_slot": _pixel_rect(_screen.get("relic_bar")),
		"board": _measure_board(),
	}


func _measure_board() -> Dictionary:
	var board: Control = _screen.get("board_view")
	var stretch: Transform2D = _capture_viewport.get_stretch_transform()
	var origin: Vector2 = stretch * (board.get_global_transform() * (board.call("_board_origin") as Vector2))
	return {
		"fit": _rect_values(stretch * (board.call("_board_layout_available_rect") as Rect2)),
		"rect": _rect_values(stretch * (_screen.call("_contextual_combat_rendered_board_bounds") as Rect2)),
		"tile_width": float(board.call("_tile_width")) * stretch.x.length(),
		"origin": [origin.x, origin.y],
	}


func _measure_idle() -> Dictionary:
	_screen.call("set_runtime_performance_instrumentation_enabled", true)
	var peak: int = 0
	var previous_total: int = 0
	for frame: int in range(IDLE_FRAMES):
		await process_frame
		var counts: Dictionary = _screen.get("_runtime_performance_counts")
		var total: int = int(counts.get(LAYOUT_PHASE, 0))
		peak = maxi(peak, total - previous_total)
		previous_total = total
	return {"frames": IDLE_FRAMES, "calls": previous_total, "peak": peak}


func _measure_feedback_lifecycle(input: RefCounted, overlay: Control, run: Dictionary) -> void:
	var title: Label = _screen.get("room_title")
	var initially_hidden: bool = not title.is_visible_in_tree()
	var boss_name: Label = _screen.get("_boss_health_name")
	var name_text: String = boss_name.text
	var after_header: Dictionary = _recapture_board_budget()
	# Recreate the other capture order with a fully laid-out HUD and no
	# presented boss name, then present the boss over that frozen budget.
	overlay.hide()
	boss_name.text = ""
	var pre_header_settled: bool = await _settle_again(input)
	_recapture_board_budget()
	boss_name.text = name_text
	overlay.show()
	var post_header_settled: bool = await _settle_again(input)
	_result["budget_orders"] = {
		"settled": pre_header_settled and post_header_settled,
		"capture_after_header": after_header,
		"capture_before_header": _measure_board(),
	}
	_viewport.size = DESKTOP_SIZE
	var desktop_settled: bool = await _settle_again(input)
	var desktop := _measure(overlay, _screen.get("_run_state"))
	desktop["settled"] = desktop_settled
	desktop["overlay_visible"] = overlay.is_visible_in_tree()
	desktop["same_room"] = _same_run_room(run)
	_result["resize_restore"] = desktop

	if not initially_hidden:
		return
	_viewport.size = DECK_SIZE
	var deck_settled: bool = await _settle_again(input)
	var hidden_again: bool = not title.is_visible_in_tree() and overlay.is_visible_in_tree()
	var combat: Dictionary = (_screen.get("_combat_state") as Dictionary).duplicate(true)
	for enemy: Dictionary in combat.get("enemies", []):
		enemy["hp"] = 0
	var next: Dictionary = _screen.call("_run_state_for_combat_checkpoint", run, combat, "card_play")
	_screen.call("_load_run_state", next)
	var reward_visible: bool = await _wait_for_reward_header(overlay, title)
	var next_run: Dictionary = _screen.get("_run_state")
	_result["fight_exit"] = {
		"reward_with_title_visible": reward_visible,
		"deck_settled": deck_settled,
		"hidden_again_at_deck_size": hidden_again,
		"mode": next_run.get("mode"),
		"same_room": _same_run_room(run),
		"overlay_visible": overlay.is_visible_in_tree(),
		"title_visible": title.is_visible_in_tree(),
		"title_text": title.text,
	}


func _wait_for_reward_header(overlay: Control, title: Label) -> bool:
	var deadline: int = Time.get_ticks_msec() + InputPath.REACH_MSEC
	var previous := Rect2()
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var reward := _screen.find_child("DragonMilestoneReward", true, false) as Control
		if reward == null or not reward.is_visible_in_tree() or overlay.is_visible_in_tree() or not title.is_visible_in_tree():
			previous = Rect2()
			continue
		var current: Rect2 = title.get_global_rect()
		if current == previous and current.has_area():
			return true
		previous = current
	return false


func _recapture_board_budget() -> Dictionary:
	var budget: RefCounted = _screen.get("_board_hud_budget")
	budget.set("key", [])
	_screen.call("_freeze_board_hud_budget")
	return _measure_board()


func _same_run_room(initial: Dictionary) -> bool:
	var current: Dictionary = _screen.get("_run_state")
	return current.get("seed") == initial.get("seed") and current.get("current_room") == initial.get("current_room")


func _settle_again(input: RefCounted) -> bool:
	var saved_result: Dictionary = _result
	_result = {"settle_frames": 0, "observed_frames": 0, "capped": false}
	await _settle(input, null)
	var settled: bool = not _result["capped"]
	_result = saved_result
	return settled


func _pixel_rect(control: Control) -> Array:
	return _rect_values(_capture_viewport.get_stretch_transform() * control.get_global_rect())


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]
