extends "res://tools/inspection_fixture.gd"
## Replay pol-81's generated fight through RunScene and its normal input routes.

const Settings = preload("res://scripts/settings_store.gd")
const Router = preload("res://scripts/input_router.gd")
const CelLook = preload("res://scripts/cel_look.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Navigation = preload("res://scripts/controller_navigation.gd")

const STAGE := Vector2i(1920, 1080)
const UI_SCALE := 1.0
const SEED := 919042
const PLAYER := Vector2i(4, 4)
const EXPOSED := Vector2i(5, 4)
const CHIPLESS := Vector2i(4, 5)
const FLOOR_SAMPLE := Vector2i(4, 3)
const ROSTER := "crawler,ash_hound,crawler"
const POSITIONS := "5:4,6:4,4:5"
const HAND := "quick_stab,pale_spark,ember_rain,guarded_step,beacon"
const STATUS_STACKS := 2
const HERO_SHOCK := 1
const DEVICE := 0
const SAMPLE_FPS := 60
const LAYOUT_FRAMES := 6
const WAIT_SECONDS := 12.0
const WINDOW_MARGIN := Vector2i(64, 96)
const ANCHOR_TOLERANCE := 1.5
const IDLE_POINTER := Vector2(960, 20)
const ROUTE_LIMIT := 32
const TOOLTIP_DELAY_SETTING := "gui/timers/tooltip_delay_sec"
const DPAD := {
	Vector2.UP: JOY_BUTTON_DPAD_UP, Vector2.DOWN: JOY_BUTTON_DPAD_DOWN,
	Vector2.LEFT: JOY_BUTTON_DPAD_LEFT, Vector2.RIGHT: JOY_BUTTON_DPAD_RIGHT,
}

var viewport: SubViewport
var scene: Control
var board: Control
var output: String
var dry: bool
var _baseline: String
var _release_comparison: bool

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	dry = args.has("--dry-run")
	output = _argument(args, "--out")
	_baseline = _argument(args, "--baseline")
	_release_comparison = args.has("--release-comparison")
	if not _check(output.is_absolute_path() and dry == (DisplayServer.get_name() == "headless")
			and CelLook.mode == "all" and not CelLook._files.is_empty(), "Expected an absolute output, the requested renderer and Cel Look all."):
		quit(1)
		return
	Engine.max_fps = SAMPLE_FPS
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.content_scale_size = STAGE
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if dry:
		root.size = STAGE
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		var usable: Vector2i = DisplayServer.screen_get_usable_rect().size - WINDOW_MARGIN
		var fit: float = minf(1.0, minf(float(usable.x) / STAGE.x, float(usable.y) / STAGE.y))
		root.size = Vector2i(Vector2(STAGE) * fit)

	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): profile = Tutorial.resolve_progression(profile, prompt)
	ProgressionStore.save_data(profile)
	_options = {"seed": SEED, "enemy_types": ROSTER, "enemy_positions": POSITIONS,
		"player_position": "%d:%d" % [PLAYER.x, PLAYER.y], "umbra_stage": "clear", "hand": HAND}
	var run: Dictionary = _build_run_state("combat", profile)
	if _failed:
		quit(1)
		return
	run["combat_state"]["objective"] = {"type": "kill_all"}
	run["combat_state"]["enemies"][0]["expose"] = STATUS_STACKS
	# Use the existing Expose and Shock pills to cover the hero path in the same fight.
	run["combat_state"]["player"]["expose"] = STATUS_STACKS
	run["combat_state"]["player"]["shock"] = HERO_SHOCK
	ProgressionStore.save_run_state(run)
	root.set_meta("labyrinth_resume_saved_run", true)
	viewport = SubViewport.new()
	viewport.size = STAGE
	viewport.msaa_2d = root.msaa_2d
	viewport.gui_embed_subwindows = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if dry else SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	viewport.notify_mouse_entered()
	if not dry:
		var preview := TextureRect.new()
		preview.texture = viewport.get_texture()
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(preview)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	board = scene.board_view
	var booted: bool = await _wait_for(func() -> bool: return scene.initial_presentation_is_ready() and scene._controller_custom_combat_available())
	if _check(booted and viewport.size == STAGE and is_equal_approx(Typography.ui_scale(scene), UI_SCALE), "RunScene must show the ready combat checkpoint at 1920x1080 UI100."):
		await _prove_combat(args.has("--record-baseline"))
	if dry and not _release_comparison and not args.has("--record-baseline") and not _failed:
		scene.queue_free()
		await process_frame
		await load("res://tools/pol82/grimoire.gd").check(self, profile)
	viewport.queue_free()
	await process_frame
	var label: String = "RELEASE COMPARISON" if _release_comparison else "BASELINE" if args.has("--record-baseline") else "PROBE"
	print("POL-82 %s: %s" % [label, "FAIL" if _failed else "PASS"])
	quit(1 if _failed else 0)

func _prove_combat(record_baseline: bool) -> void:
	var mouse: Dictionary = await _mouse_snapshot()
	if not _check(not mouse.is_empty(), "Mouse must hover the Expose chip and open its native popup."): return
	var mouse_path: String = output.path_join("mouse.json")
	var file := FileAccess.open(mouse_path, FileAccess.WRITE)
	if not _check(file != null, "Could not write mouse receipt."): return
	file.store_line(JSON.stringify(mouse))
	file.close()
	print(mouse_path)
	if record_baseline: return
	if not _baseline.is_empty():
		var original: Variant = JSON.parse_string(FileAccess.get_file_as_string(_baseline))
		if not _check(original == JSON.parse_string(JSON.stringify(mouse)), "Mouse popup, unit and floor hover must match the release receipt."): return
		print("POL-82 release mouse parity: PASS")

	# Enter board focus through X, the same hand toggle used in pol-81.
	await _tap(JOY_BUTTON_X)
	if not _check(scene._controller_board_tile == PLAYER, "X must enter board focus at the hero."): return
	if not await _focus_tile(EXPOSED): return
	if not await _status_frame(EXPOSED, ["expose"], "combat_status_tooltip"): return
	if not _release_comparison:
		var expose: Control = _stack().get_child(0)
		if not _check(Array(_panel_text(expose)) == mouse["panel_text"]
				and str(expose.size) == mouse["panel_size"], "Controller Expose popup must match mouse text and size."):
			print("POL-82 Expose diff: ", _panel_text(expose), " ", expose.size, " vs ", mouse)
			return
	if not await _focus_tile(PLAYER): return
	if not await _status_frame(PLAYER, ["shock", "expose"], "combat_status_two_chips"): return
	if not await _focus_tile(CHIPLESS): return
	if not await _status_frame(CHIPLESS, [], "combat_status_chipless"): return
	if _release_comparison: return

	# The chipless frame also proves moving off a unit retires the previous stack.
	if not await _focus_tile(PLAYER): return
	if not _check(_stack().is_visible_in_tree(), "Returning to a status unit must reopen the stack."): return
	await _tap(JOY_BUTTON_X)
	for index: int in scene._combat_state["deck"]["hand"].size():
		if scene._combat_state["deck"]["hand"][scene._controller_hand_index] == "quick_stab": break
		await _tap(JOY_BUTTON_DPAD_RIGHT)
	await _tap(JOY_BUTTON_A)
	if not _check(scene._targeted_card_aiming_active() and not _stack().is_visible_in_tree(), "Starting card aim must close the stack."): return
	await _tap(JOY_BUTTON_B)
	if scene._controller_region == "hand": await _tap(JOY_BUTTON_X)
	if not await _focus_tile(PLAYER): return
	if not _check(scene._controller_board_tile == PLAYER and _stack().is_visible_in_tree(), "Return to the hero before pointer handoff."): return
	await create_timer((Router.POINTER_HANDOFF_GRACE_MSEC + 1) / 1000.0).timeout
	_point(board.get_global_transform_with_canvas() * _first_chip(EXPOSED))
	await _settle()
	if not _check(not scene._controller_is_active() and not _stack().is_visible_in_tree(), "Mouse motion must switch modality and close the stack."): return
	print("POL-82 focus, card aim and mouse handoff: PASS")
	await _wait_for_board_centering()
	_point(board.get_global_transform_with_canvas() * board.world_position_for_tile(FLOOR_SAMPLE))
	var mouse_popup_open: bool = await _wait_for(func() -> bool: return not _board_mouse_popups().is_empty())
	if not _check(mouse_popup_open, "The pointer must be able to reopen a board tooltip after returning from pad focus."): return
	await _tap(JOY_BUTTON_X)
	if not _check(scene._controller_is_active() and _board_mouse_popups().is_empty(), "An already-open board mouse tooltip must close on pad handoff."): return
	print("POL-82 open mouse popup handoff: PASS")

func _status_frame(tile: Vector2i, icons: Array, filename: String) -> bool:
	await _settle()
	if not _check(scene._controller_board_tile == tile and scene._controller_analog_cursor.is_visible_in_tree(),
			"Expected real pad focus at %s, got %s." % [tile, scene._controller_board_tile]): return false
	var stack: Control = _stack()
	var cursor: Control = scene._controller_analog_cursor
	if icons.size() > 1:
		# Give a pointer tooltip still queued at handoff time to show itself.
		await create_timer(float(ProjectSettings.get_setting(TOOLTIP_DELAY_SETTING))).timeout
	var native_popups: Array[String]
	for popup: Window in _board_mouse_popups():
		native_popups.append("%s at %s" % [_panel_text(popup), popup.position])
	print("POL-82 %s %s: cursor_detail=%s, board_mouse_popups=%s" % [
		"release" if _release_comparison else "candidate", filename, cursor._detail_key, native_popups])
	if _release_comparison:
		if not _check(stack == null, "Release comparison must run without controller status chips."): return false
	elif not _check(stack != null and stack.is_visible_in_tree() == not icons.is_empty() and stack.get_child_count() == icons.size(),
			"Expected %d visible chip panels at %s." % [icons.size(), tile]): return false
	if not _release_comparison and not icons.is_empty():
		var entries: Array[Dictionary] = _entries(tile)
		var expected_anchor: Vector2 = board.get_global_transform_with_canvas() * (entries[0]["rect"] as Rect2).get_center()
		expected_anchor += Vector2(ProjectSettings.get_setting("display/mouse_cursor/tooltip_position_offset"))
		if not _check((stack.get_global_transform_with_canvas().origin).distance_to(expected_anchor) <= ANCHOR_TOLERANCE,
				"Stack must stay at the first chip's mouse anchor."): return false
		var bottom: float = -INF
		for index: int in icons.size():
			var panel: Control = stack.get_child(index)
			if not _check(entries[index]["icon"] == icons[index] and stack._texts[index] == entries[index]["tooltip"]
					and panel.is_visible_in_tree() and panel.position.y >= bottom, "Chip panels must follow the painted order and existing text."): return false
			bottom = panel.position.y + panel.size.y
		if icons.size() > 1:
			var intersections: PackedStringArray = _panel_intersections(stack)
			if not _check(intersections.is_empty(), "Another panel intersects the chip stack: " + str(intersections)): return false
			print("POL-82 two-chip panel overlap: PASS (0 intersecting panels)")
	if not _release_comparison and not _check(native_popups.is_empty(), "A mouse tooltip is visible under pad focus."): return false
	if not dry:
		await RenderingServer.frame_post_draw
		var image: Image = viewport.get_texture().get_image()
		var path: String = output.path_join(filename + ".png")
		if not _check(image != null and image.get_size() == STAGE and image.save_png(path) == OK, "Could not capture " + filename): return false
		print(path)
	print("POL-82 %s: PASS (%d chip tooltips at %s)" % [filename, 0 if _release_comparison else icons.size(), tile])
	return true

func _mouse_snapshot() -> Dictionary:
	_point(IDLE_POINTER)
	await _settle()
	await _wait_for_board_centering()
	var chip: Vector2 = _first_chip(EXPOSED)
	if chip == Vector2.INF:
		print("POL-82 mouse chip missing at ", EXPOSED, " ", _entries(EXPOSED), " ", scene._combat_state["enemies"])
		return {}
	_point(board.get_global_transform_with_canvas() * chip)
	var hovered: bool = await _wait_for(func() -> bool: return _mouse_panel() != null)
	if not hovered:
		print("POL-82 mouse diagnostic: chip=", chip, " text=", board._get_tooltip(chip), " last=", board._last_pointer_position,
			" hovered=", viewport.gui_get_hovered_control(), " children=", board.get_children().filter(func(child: Node) -> bool: return child is Window))
		return {}
	await _settle()
	var panel: Control = _mouse_panel()
	if panel == null: return {}
	var popup: Window = panel.get_parent()
	var text: String = board._get_tooltip(chip)
	var panel_text: PackedStringArray = _panel_text(panel)
	var panel_size: Vector2 = panel.size
	var offset: Vector2 = Vector2(popup.position) - (board.get_global_transform_with_canvas() * chip)
	var expected_offset := Vector2(ProjectSettings.get_setting("display/mouse_cursor/tooltip_position_offset"))
	if not _check(offset.distance_to(expected_offset) <= ANCHOR_TOLERANCE, "Native tooltip uses a different offset at the Expose chip: " + str(offset)): return {}

	var tile_text := {}
	for tile: Vector2i in [EXPOSED, FLOOR_SAMPLE]:
		var local: Vector2 = board.world_position_for_tile(tile)
		_point(board.get_global_transform_with_canvas() * local)
		await _settle()
		tile_text[str(tile)] = [board._get_tooltip(local), str(scene._hovered_board_tile)]
	print("POL-82 mouse Expose popup: %s %s" % [panel_text, panel_size])
	return {"hover_text": text, "panel_text": Array(panel_text), "panel_size": str(panel_size), "tile_hover": tile_text}

func _mouse_panel() -> Control:
	for popup: Window in _board_mouse_popups():
		for content: Node in popup.get_children():
			if content is PanelContainer: return content
	return null

func _board_mouse_popups() -> Array[Window]:
	var result: Array[Window]
	for child: Node in board.get_children():
		if child is Window and child.visible and child.theme_type_variation == &"TooltipPanel": result.append(child)
	return result

func _panel_intersections(stack: Control) -> PackedStringArray:
	var stack_rect: Rect2 = stack.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, stack.size)
	var intersections := PackedStringArray()
	for node: Node in viewport.find_children("*", "Control", true, false):
		var panel := node as Control
		if not (panel is Panel or panel is PanelContainer or panel.has_meta("tooltip_surface")): continue
		if not panel.is_visible_in_tree() or panel == stack or stack.is_ancestor_of(panel): continue
		var rect: Rect2 = panel.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, panel.size)
		var host: Viewport = panel.get_viewport()
		while host is Window and host != viewport:
			rect.position += Vector2(host.position)
			host = host.get_parent().get_viewport()
		if host == viewport and rect.intersects(stack_rect): intersections.append(str(panel.get_path()))
	return intersections

func _panel_text(panel: Node) -> PackedStringArray:
	var result := PackedStringArray()
	for child: Node in panel.find_children("*", "Control", true, false):
		if child is Label: result.append(child.text)
		elif child is RichTextLabel: result.append(child.get_parsed_text())
	return result

func _entries(tile: Vector2i) -> Array[Dictionary]:
	var empty: Array[Dictionary]
	for unit: Dictionary in board._visible_units():
		if unit["pos"] != tile: continue
		var frame: Rect2 = board._hud_health_rects_cache.get(unit["key"], Rect2())
		return board._unit_status_pill_entries(unit, frame)
	return empty

func _first_chip(tile: Vector2i) -> Vector2:
	var entries: Array[Dictionary] = _entries(tile)
	return Vector2.INF if entries.is_empty() else (entries[0]["rect"] as Rect2).get_center()

func _stack() -> Control:
	return scene._controller_analog_cursor.get_node_or_null("ControllerStatusChips") as Control

func _focus_tile(tile: Vector2i) -> bool:
	var key: String = scene._controller_tile_key(tile)
	for step: int in ROUTE_LIMIT:
		if scene._controller_board_tile == tile: return true
		var current: Dictionary = scene._controller_focus_candidate
		var button: int = _first_dpad_step(current, scene._controller_navigation_candidates(), key)
		if button < 0: break
		await _tap(button)
	return _check(scene._controller_board_tile == tile, "D-pad could not route to " + key)

static func _first_dpad_step(start: Dictionary, candidates: Array[Dictionary], wanted: String) -> int:
	if start.is_empty(): return -1
	var pending: Array[Dictionary]
	pending.append(start)
	var first_steps: Dictionary = {start["key"]: -1}
	while not pending.is_empty():
		var current: Dictionary = pending.pop_front()
		var key: String = current["key"]
		for direction: Vector2 in DPAD:
			var next: Dictionary = Navigation.best_candidate_in_direction(current["point"], direction, candidates, key)
			if next.is_empty() or first_steps.has(next["key"]): continue
			var first: int = DPAD[direction] if key == start["key"] else first_steps[key]
			if next["key"] == wanted: return first
			first_steps[next["key"]] = first
			pending.append(next)
	return -1

func _tap(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.device = DEVICE
		event.button_index = button
		event.pressed = pressed
		_deliver(event)
		await process_frame
	await process_frame

func _point(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	motion.relative = point - viewport.get_mouse_position()
	_deliver(motion)

func _deliver(event: InputEvent) -> void:
	root.get_node("InputRouter").record_input_activity(event)
	viewport.push_input(event, true)

func _settle() -> void:
	for frame: int in LAYOUT_FRAMES: await process_frame

func _wait_for(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(WAIT_SECONDS * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() >= deadline: return false
		await process_frame
	return true

func _wait_for_board_centering() -> void:
	await _wait_for(func() -> bool:
		var tween: Tween = scene._board_centering_tween
		return tween == null or not tween.is_running())

func _check(ok: bool, message: String) -> bool:
	if not ok: _fail(message)
	return ok

static func _argument(args: PackedStringArray, flag: String) -> String:
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 and index + 1 < args.size() else ""
