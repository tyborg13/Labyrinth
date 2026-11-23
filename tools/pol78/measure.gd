extends "res://tools/inspection_fixture.gd"
## Use the same live RunScene and input handlers in both capture modes.

const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const STAGE := Vector2i(1920, 1080)
const READY_SECONDS := 30.0
const SETTLE_FRAMES := 3
const RECT_TOLERANCE := 1.0
const OBJECTIVE_SEED := 3
const BANKED_PLAY_SKILL := "measured_breath"
const GUARDIAN_ID := "ashen_reaver"
const FIXTURE_CARD := "brace"
const BANKED_PLAYS := 1
const WINDOW_MARGIN := Vector2i(64, 96)
const POINTER_REST := Vector2(960, 540)
const CASES := {"normal": "combat", "objective": "reach_exit", "guardian": "guardian"}
const CAPTURE_HANDS := [3, 1, 0]

var _viewport: SubViewport
var _scene: Control
var _output: String
var _headless: bool
var _verify_held: bool
var _cases: Dictionary
var _opening: Array[Dictionary]
var _next_deal: Array[Dictionary]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_measure.call_deferred()

func _measure() -> void:
	var args := OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	_output = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	_headless = args.has("--dry-run")
	_verify_held = args.has("--verify-held")
	if not _check(_output.is_absolute_path() and _headless == (DisplayServer.get_name() == "headless") and OS.get_environment("LABYRINTH_CEL_LOOK") == "all", "Expected absolute --out, matching display mode and LABYRINTH_CEL_LOOK=all."):
		return
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.set_storage_path(_output.path_join("settings.json"))
	Settings.save_settings(settings)
	ProgressionStore.set_storage_path(_output.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(_output.path_join("run.save"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(_output.path_join("analytics"))
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = STAGE
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_factor = 1.0
	if _headless:
		root.size = STAGE
		process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	else:
		var available: Vector2i = DisplayServer.screen_get_usable_rect().size - WINDOW_MARGIN
		var fit: float = minf(1.0, minf(float(available.x) / STAGE.x, float(available.y) / STAGE.y))
		root.size = Vector2i(Vector2(STAGE) * fit)
	var profile: Dictionary = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids():
		profile = Tutorial.resolve_progression(profile, prompt)
	for kind: String in CASES:
		if not await _measure_case(kind, profile):
			return
	var path: String = _output.path_join("rects.json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not _check(file != null, "Open rect table."):
		return
	file.store_string(JSON.stringify(_cases, "\t") + "\n")
	for kind: String in CASES:
		var drift: float = _max_drift(_cases[kind])
		print("POL-78 %s maximum dock drift: %.3f px" % [kind, drift])
		if _verify_held and not _check(drift <= RECT_TOLERANCE, "%s dock moved more than 1 px. See %s." % [kind, path]):
			return
	print("POL-78 %s PASS — %s" % ["HEADLESS" if _headless else "NATIVE", path])
	quit(0)

func _measure_case(kind: String, profile: Dictionary) -> bool:
	_options = {"seed": OBJECTIVE_SEED if kind == "objective" else DEFAULT_SEED,
		"guardian_id": GUARDIAN_ID, "guardian_case": "encounter"}
	var state: Dictionary = _build_run_state(CASES[kind], profile)
	var battle: Dictionary = state.get("combat_state", {})
	if not _check(not _failed and state.get("mode") == "combat", "Build live %s encounter." % kind):
		return false
	var maximum: int = int(battle["hand_size"])
	var cards: Array[String]
	for index: int in range(maximum):
		cards.append(FIXTURE_CARD)
	battle["deck"]["hand"] = cards
	battle["deck"]["draw"] = cards.duplicate()
	battle["cards_per_turn"] = maximum
	if kind == "guardian":
		var skills: Array[String] = [BANKED_PLAY_SKILL]
		battle["skill_ids"] = skills
		battle["banked_play_active"] = BANKED_PLAYS
	if not await _open(state):
		return false
	_opening.clear()
	_next_deal.clear()
	var opening_sample := func() -> void: _observe(_opening, true)
	_frame_signal().connect(opening_sample)
	_scene.call("_on_pre_battle_start_pressed")
	var ready: bool = await _wait_for_hand(maximum)
	_frame_signal().disconnect(opening_sample)
	if not _check(ready and _opening.any(func(row: Dictionary) -> bool: return row["phase"] == "deal"), "Observe %s opening deal and full hand." % kind):
		return false
	var settled: Array[Dictionary]
	for size: int in range(maximum, -1, -1):
		var row: Dictionary = _sample("rest")
		if not _check(_has_dock(row["rects"], kind == "guardian"), "Observe the dock in %s at hand size %d." % [kind, size]):
			return false
		settled.append(row)
		print("POL-78 %s hand=%d %s" % [kind, size, JSON.stringify(row["rects"])])
		if (kind == "guardian" and size == maximum) or (kind != "guardian" and (size == maximum or size in CAPTURE_HANDS)):
			var label: String = "max" if size == maximum else str(size)
			if not await _capture("%s_%s" % [kind, label]):
				return false
		if size > 0:
			await _scene.call("_on_card_pressed", 0)
			if not _check(_scene.get("_selected_card_index") == 0, "Select %s card at hand size %d." % [kind, size]):
				return false
			await _scene.call("_on_confirm_card_play_pressed")
			if not _check(await _wait_for_hand(size - 1), "Play one card in %s at hand size %d." % [kind, size]):
				return false
	var next_sample := func() -> void: _observe(_next_deal, false)
	_frame_signal().connect(next_sample)
	await _scene.call("_on_pass_turn_pressed")
	var dealt: bool = await _wait_for_hand(int(battle["draw_per_turn"]))
	_frame_signal().disconnect(next_sample)
	if not _check(dealt and not _next_deal.is_empty(), "Observe %s next-turn deal and returned hand." % kind):
		return false
	_cases[kind] = {
		"room": str(battle.get("room_coord")), "seed": state["seed"], "maximum": maximum,
		"opening": _opening.duplicate(), "rest": settled,
		"next_deal": _next_deal.duplicate(), "next_rest": _sample("rest"),
	}
	_viewport.get_parent().queue_free()
	await process_frame
	return true

func _has_dock(rects: Dictionary, banked: bool) -> bool:
	for field: String in ["Pass", "Card Plays", "Count", "Movement", "Objective", "Objective home"]:
		if rects[field].is_empty(): return false
	return not banked or not rects["Banked"].is_empty()

func _max_drift(measurements: Dictionary) -> float:
	var full_hand: Dictionary = measurements["rest"][0]["rects"]
	var rows: Array = measurements["rest"].duplicate()
	rows.append(measurements["next_rest"])
	for entry: Dictionary in measurements["opening"] + measurements["next_deal"]:
		rows.append(entry["sample"])
	var maximum: float = 0.0
	for row: Dictionary in rows:
		for field: String in full_hand:
			# The Objective card travels to its existing home before the deal.
			if field == "Objective" and row["phase"] == "intro":
				continue
			var rect: Array = row["rects"][field]
			if rect.is_empty() or full_hand[field].is_empty():
				continue
			for index: int in range(rect.size()):
				maximum = maxf(maximum, absf(rect[index] - full_hand[field][index]))
	return maximum

func _open(state: Dictionary) -> bool:
	# Start from the encounter report. Start owns the opening frame, while the
	# prepared factory supplies the deterministic encounter and probe hand.
	var room: Dictionary = state.duplicate(true)
	room["mode"] = "room"
	room["combat_state"] = {}
	if not _check(ProgressionStore.save_data(room["progression"]) and ProgressionStore.save_run_state(room), "Save the probe room."):
		return false
	root.set_meta("labyrinth_resume_saved_run", true)
	var container := SubViewportContainer.new()
	container.size = Vector2(STAGE)
	root.add_child(container)
	_viewport = SubViewport.new()
	_viewport.size = STAGE
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED if _headless else SubViewport.UPDATE_ALWAYS
	container.add_child(_viewport)
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport.add_child(_scene)
	var deadline: int = Time.get_ticks_msec() + roundi(READY_SECONDS * 1000.0)
	while not _scene.initial_presentation_is_ready() and Time.get_ticks_msec() < deadline:
		await process_frame
	if not _check(_scene.initial_presentation_is_ready() and _viewport.size == STAGE and is_equal_approx(Typography.ui_scale(_scene), 1.0), "Initialize production scene at 1920×1080 and 100%."):
		return false
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	var motion := InputEventMouseMotion.new()
	motion.position = POINTER_REST
	motion.global_position = POINTER_REST
	_viewport.push_input(motion, true)
	room["mode"] = RunEngine.MODE_PRE_BATTLE
	room["pre_battle_pending"] = true
	_scene.call("_load_run_state", room)
	await process_frame
	var pre_battle: Dictionary = _scene.get("_run_state")
	var prepared: Dictionary = _run_engine.prepare_pre_battle_combat(pre_battle)
	if not _check(not prepared.is_empty(), "Prepare the encounter through the Start factory."):
		return false
	prepared["combat_state"] = state["combat_state"]
	_scene.set("_prepared_pre_battle_factory", prepared)
	return true

func _wait_for_hand(count: int) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(READY_SECONDS * 1000.0)
	var stable: int = 0
	while Time.get_ticks_msec() < deadline:
		await process_frame
		var hand: Control = _scene.get("hand_box")
		var shown: bool = hand != null and hand.is_visible_in_tree() and hand.get_child_count() == count and not hand.is_sliding()
		if _hand_count() == count and shown and not _scene.get("_animation_lock") and _scene.get("_hand_layout_pending_revision") < 0:
			stable += 1
			if stable >= SETTLE_FRAMES:
				return true
		else:
			stable = 0
	return false

func _hand_count() -> int:
	return _scene.get("_combat_state").get("deck", {}).get("hand", []).size()

func _frame_signal() -> Signal:
	return process_frame if _headless else RenderingServer.frame_pre_draw

func _observe(rows: Array[Dictionary], opening: bool) -> void:
	var proxies: Array = _scene.get("_draw_hand_transition_proxies")
	var dealing: bool = not proxies.is_empty()
	var objective: Control = _scene.get("_combat_objective_hud")
	if _scene.get("_run_state").get("mode") != "combat" or (not opening and not dealing):
		return
	var phase: String = "deal" if dealing else ("intro" if objective.get("intro_active") else "entry")
	var row: Dictionary = _sample(phase)
	for index: int in range(proxies.size()):
		row["obstacles"]["dealing card %d" % index] = _visible_rect(proxies[index])
	# Record every distinct sampled geometry and count. Consecutive repeats
	# keep their frame span, so renderer pacing does not expand the report.
	if not rows.is_empty() and rows.back()["sample"] == row:
		rows.back()["last_frame"] = Engine.get_process_frames()
		return
	var frame: int = Engine.get_process_frames()
	rows.append({"first_frame": frame, "last_frame": frame, "sample": row, "phase": phase})

func _sample(phase: String) -> Dictionary:
	var objective: Control = _scene.get("_combat_objective_hud")
	var dock: Rect2 = _scene.get("_combat_objective_dock_home")
	var ui: Control = _scene.get("ui_root")
	var controls := {
		"Pass": _scene.find_child("PassPreviewChip", true, false),
		"Card Plays": _scene.get("_play_meter"),
		"Count": _scene.get("_play_meter_count"),
		"Banked": _scene.get("_play_meter_banked_badge"),
		"Movement": _scene.get("_movement_meter"),
		"Objective": objective,
	}
	var rects: Dictionary
	for name: String in controls:
		rects[name] = _visible_rect(controls[name])
	rects["Objective home"] = _rect(ui.get_global_transform_with_canvas() * dock) if dock.has_area() else []
	var obstacles: Dictionary
	for field: String in ["_boss_health_overlay", "_grimoire_badge", "_loadout_badge", "_relic_icon_grid"]:
		var visible_rect: Array = _visible_rect(_scene.get(field) as Control)
		if not visible_rect.is_empty(): obstacles[field] = visible_rect
	var hand: Control = _scene.get("hand_box")
	if hand != null and hand.is_visible_in_tree():
		for index: int in range(hand.get_child_count()):
			var card: Control = _scene.call("_hand_card_control", index)
			if card != null and card.is_visible_in_tree():
				obstacles["card %d" % index] = _rect(card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size))
	return {"phase": phase, "hand": _hand_count(), "rects": rects, "obstacles": obstacles}

func _visible_rect(control: Control) -> Array:
	if control == null or not control.is_visible_in_tree():
		return []
	# The objective stack blanks its parent canvas layer until framing settles.
	var item: CanvasItem = control
	while item != null:
		if item.visibility_layer == 0 or item.modulate.a <= 0.0:
			return []
		item = item.get_parent() as CanvasItem
	return _rect(control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size))

func _rect(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]

func _capture(label: String) -> bool:
	if _headless:
		return true
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _output.path_join(label + ".png")
	if not _check(image != null and image.get_size() == STAGE and image.save_png(path) == OK, "Capture " + path):
		return false
	print(path)
	return true

func _check(condition: bool, message: String) -> bool:
	if not condition:
		_fail("POL-78: " + message)
	return condition
