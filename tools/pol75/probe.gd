extends "res://tools/inspection_fixture.gd"
## Candidate comparison through the production RunScene in a 1920×1080 viewport.

const Settings = preload("res://scripts/settings_store.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const Floating = preload("res://scripts/floating_combat_text.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Events = preload("res://tests/suites/event_view_suite.gd")
const Gear = preload("res://tools/fx34/cases.gd")
const Dragon = preload("res://tools/dragon_boss_inspection.gd")
const STAGE := Vector2i(1920, 1080)
const FIXTURE_SEED := 919042
const READY_SECONDS := 20.0
const POINTER_SECONDS := 45.0
const HEADLESS_POINTER_SECONDS := 5.0
const WINDOW_MARGIN := Vector2i(64, 96)
const PASS_REST_SECONDS := 0.18
const ESCAPE_TRIALS := 3
const FINISHER := "quick_stab"
const PASS_HIT := Vector2(135, 33)
const PICKUP := Vector2i(5, 4)
const DROP := "ward_kite"
const EXPIRED := "Unclaimed gear crumbles into dust."

var _viewport: SubViewport
var _scene: Control
var _profile: Dictionary
var _out: String
var _headless: bool
var _inject: bool
var _after: bool
var _facts: Dictionary

class SampleFrame extends Node:
	signal sampled
	var pass_input: String
	func _input(event: InputEvent) -> void:
		if event is InputEventKey and event.pressed and event.keycode == KEY_P:
			pass_input = "key"
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			pass_input = "click"
	func _process(_delta: float) -> void: sampled.emit()

var _samples: SampleFrame

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_index: int = args.find("--out")
	_out = args[out_index + 1] if out_index >= 0 and out_index + 1 < args.size() else ""
	_headless = args.has("--dry-run")
	_inject = _headless or args.has("--inject")
	_after = args.has("--after")
	if not _out.is_absolute_path() or _headless != (DisplayServer.get_name() == "headless") or OS.get_environment("LABYRINTH_CEL_LOOK") != "all":
		_fail("Expected an absolute output path and LABYRINTH_CEL_LOOK=all in the selected renderer mode.")
		return
	DirAccess.make_dir_recursive_absolute(_out)
	ProgressionStore.set_storage_path(_out.path_join("progression.json"))
	ProgressionStore.set_run_storage_path(_out.path_join("run.save"))
	Settings.set_storage_path(_out.path_join("settings.json"))
	preload("res://scripts/analytics_store.gd").set_storage_dir(_out.path_join("analytics"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["mute_in_background"] = false
	Settings.save_settings(settings)
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
	_samples = SampleFrame.new()
	_samples.process_priority = 1000
	root.add_child(_samples)
	_profile = Tutorial.dismiss_tutorial(ProgressionStore.default_data())
	for prompt: String in Tutorial.prompt_ids(): _profile = Tutorial.resolve_progression(_profile, prompt)
	var study_index: int = args.find("--study")
	var study: String = args[study_index + 1] if study_index >= 0 else ""
	if study in ["", "pass"] and (not await _pass("click") or not await _pass("key")): return
	if study in ["", "event"]:
		for amount: int in [1, 12, -1, -12]:
			if not await _event(amount): return
	if study in ["", "gear"]:
		for gear_case: String in ["left", "none", "picked_up"]:
			if not await _gear(gear_case): return
	if study in ["", "escape"]:
		for trial: int in ESCAPE_TRIALS:
			if not await _escape(trial): return
	if study in ["", "arrival"]:
		for arrival_case: String in ["opening", "dragon_opening", "summon", "reinforcement"]:
			if not await _arrival(arrival_case): return
	if study in ["", "reward"] and not await _reward(): return
	await _close()
	var file := FileAccess.open(_out.path_join("observations.json"), FileAccess.WRITE)
	if not _check(file != null, "Open the observation output."): return
	file.store_string(JSON.stringify(_facts, "\t") + "\n")
	print("POL-75 %s %s PASS — %s" % ["after" if _after else "before", "headless" if _headless else "native", _out.path_join("observations.json")])
	quit(0)

func _check(ok: bool, message: String) -> bool:
	if not ok: _fail("POL-75: " + message)
	return ok

func _record(key: String, values: Dictionary) -> void:
	_facts[key] = values
	print("POL-75 %s %s" % [key, JSON.stringify(values)])

func _wait_until(condition: Callable, seconds: float = READY_SECONDS) -> bool:
	var deadline: int = Time.get_ticks_msec() + roundi(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		if condition.call(): return true
		await _samples.sampled
	return false

func _close() -> void:
	if is_instance_valid(_viewport):
		_viewport.get_parent().queue_free()
		await process_frame
	_scene = null
	_viewport = null

func _open(state: Dictionary) -> bool:
	await _close()
	if not _check(not state.is_empty() and ProgressionStore.save_data(state["progression"]) and ProgressionStore.save_run_state(state), "Save the proof fixture."): return false
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
	if not _check(await _wait_until(_scene.initial_presentation_is_ready), "RunScene initialization."): return false
	if _scene._dialogue_active: _scene._close_dialogue()
	await _samples.sampled
	return _check(_viewport.size == STAGE and is_equal_approx(Typography.ui_scale(_scene), 1.0), "Exact viewport and UI scale.")

func _capture(key: String) -> bool:
	if _headless: return true
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	var path: String = _out.path_join(key + ".png")
	if not _check(image != null and image.get_size() == STAGE and image.save_png(path) == OK, "Capture " + path): return false
	print(path)
	return true

func _combat_fixture() -> Dictionary:
	_options = Gear.options("missed", FIXTURE_SEED)
	var state: Dictionary = _build_run_state("combat", _profile)
	Gear.configure("missed", state["combat_state"])
	return state

func _pass(route: String) -> bool:
	var state: Dictionary = _combat_fixture()
	var battle: Dictionary = state["combat_state"]
	battle["loot"] = []
	Gear.Witness._intent(battle["enemies"][0], "bite")
	if not await _open(state): return false
	var chip: Button = _scene._selected_card_forecast_chip()
	if not _check(chip != null and not chip.disabled, "Pass fixture has a live PASS button."): return false
	await _samples.sampled
	await _samples.sampled
	var point: Vector2 = chip.get_global_rect().position + PASS_HIT
	var hover_timeout: float = HEADLESS_POINTER_SECONDS if _inject else POINTER_SECONDS
	var scheduled: Dictionary = _combat_engine.finish_player_activation(_scene._combat_state)
	if not _check(_combat_engine.enemy_acts_before_next_player_turn(scheduled), "Pass hands off to an enemy."): return false
	if _inject:
		_motion(Vector2(32, 110))
		await _samples.sampled
		point = chip.get_global_rect().position + PASS_HIT
		_motion(point)
	else:
		root.title = "POL-75 • Hover PASS, then %s without moving" % ["click PASS" if route == "click" else "press P"]
	var hover_open: bool = await _wait_until(func() -> bool: return not chip.disabled and _forecast_alpha(chip) > 0.0 and _pointer_on_pass(chip), hover_timeout)
	if not _check(hover_open, "A live pointer hover opened the %s forecast (hover=%s, alpha=%.3f, pointer=%s, live=%s)." % [route, chip.get_meta("pass_pointer_hover", false), _forecast_alpha(chip), _pointer_on_pass(chip), not chip.disabled]): return false
	_samples.pass_input = ""
	if _inject: _end_turn(route, point)
	if not _check(await _wait_until(func() -> bool: return chip.disabled, hover_timeout), "PASS disabled after " + route): return false
	var lock_alpha: float = _forecast_alpha(chip)
	var pointer_on_pass: bool = _pointer_on_pass(chip)
	var pointer: Vector2 = chip.get_local_mouse_position() if not _inject else chip.get_global_transform_with_canvas().affine_inverse() * _test_pointer
	if not _check(pointer_on_pass and _samples.pass_input == route, "The pointer stayed on PASS during the %s lock." % route): return false
	if not _check(not _after or lock_alpha == 0.0, "The lock concealed the PASS forecast synchronously."): return false
	if not await _capture("01_pass_" + route): return false
	if not _check(await _wait_until(func() -> bool: return not chip.disabled and not _scene._animation_lock), "Return to a live player turn."): return false
	await create_timer(PASS_REST_SECONDS).timeout
	var resting_alpha: float = _forecast_alpha(chip)
	if not _check(not _after or resting_alpha == 0.0, "The resting pointer did not re-open the forecast."): return false
	if _inject:
		_motion(Vector2(32, 110))
		await _samples.sampled
		_motion(chip.get_global_rect().position + PASS_HIT)
	else:
		root.title = "POL-75 • Move off PASS, then hover it again"
	var reopened: bool = await _wait_until(func() -> bool: return _forecast_alpha(chip) > 0.0 and _pointer_on_pass(chip), hover_timeout)
	_record("pass_" + route, {"lock_alpha": lock_alpha, "resting_alpha": resting_alpha, "reopened": reopened,
		"pointer_on_pass": pointer_on_pass, "pointer_in_button": str(pointer), "injected": _inject})
	return _check(reopened, "A fresh hover opened the forecast.")

func _pointer_on_pass(chip: Button) -> bool:
	return chip._has_point(chip.get_local_mouse_position()) or (_inject and chip._has_point(chip.get_global_transform_with_canvas().affine_inverse() * _test_pointer))

func _forecast_alpha(chip: Button) -> float:
	var panel: Control = chip.get_node_or_null("PassForecastFocusTooltip")
	return panel.modulate.a if panel != null and panel.is_visible_in_tree() else 0.0

var _test_pointer: Vector2

func _motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _test_pointer
	_test_pointer = point
	root.push_input(event, true)

func _end_turn(route: String, point: Vector2) -> void:
	for down: bool in [true, false]:
		if route == "click":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			click.position = point
			click.global_position = point
			click.pressed = down
			root.push_input(click, true)
		else:
			var key := InputEventKey.new()
			key.keycode = KEY_P
			key.physical_keycode = KEY_P
			key.pressed = down
			root.push_input(key, true)

func _event(amount: int) -> bool:
	# Use the authored 25% heal, capped to the desired amount by fixture HP.
	# Losses use a process-local copy of the Basin choice with a test-only amount.
	var gain: bool = amount > 0
	var event_id: String = "weeping_statue" if gain else "bloodletters_basin"
	var state: Dictionary = Events.fixture(event_id, false, _run_engine.create_new_run(Events.FIXTURE_SEED, _profile))
	state["player_max_hp"] = 48
	state["player_hp"] = 48 - amount if gain else 48
	var definition: Dictionary = GameData.event_def(event_id)
	var option: Dictionary = definition["choices"][1 if gain else 0]
	var saved_amount: int = int(option["effects"][0].get("amount", 0))
	if not gain: option["effects"][0]["amount"] = amount
	if not await _open(state): return false
	var view: Control = _scene._event_view
	view.finish_animation_for_test()
	_scene._on_section_map_event(str(option["id"]))
	if not gain: option["effects"][0]["amount"] = saved_amount
	if not _check(await _wait_until(func() -> bool: return not view.health._popups.is_empty()), "Result Health number for %d." % amount): return false
	var number: Label = view.health._popups[0]
	var key: String = "02_health_%s_%d" % ["gain" if gain else "loss", absi(amount)]
	var combat_size: int = Floating.animate_entry(Floating.damage_entry(Vector2i.ZERO, str(amount), Color.WHITE), 0.0, false)["font_size"]
	var font_size: int = number.get_theme_font_size("font_size")
	_record(key, {"text": number.text, "font_size": font_size, "scale": number.scale.x, "combat_font_size": combat_size})
	return _check(number.text == ("%+d" % amount).replace("-", "−") and font_size == combat_size,
		"Health result matched the combat size step for %d." % amount) and await _capture(key)

func _finish_with_card(tile: Vector2i) -> void:
	var hand: Array = _scene._combat_state.get("deck", {}).get("hand", [])
	_scene._on_card_pressed(hand.find(FINISHER))
	_scene._on_board_tile_clicked(tile)

func _gear(study: String) -> bool:
	var state: Dictionary = _combat_fixture()
	var battle: Dictionary = state["combat_state"]
	battle["loot"] = [] if study == "none" else [{"id": "pol75_floor_gear", "kind": "equipment", "equipment_id": DROP, "pos": PICKUP}]
	if not await _open(state): return false
	if study == "picked_up":
		_scene._begin_player_movement_selection()
		_scene._on_board_tile_clicked(PICKUP)
		if not _check(await _wait_until(func() -> bool: return not _scene._animation_lock and DROP in _scene._combat_state.get("collected_equipment", [])), "Collected floor gear via movement."): return false
		# Step back into Quick Stab range.
		_scene._begin_player_movement_selection()
		_scene._on_board_tile_clicked(Gear.Witness.HERO)
		if not _check(await _wait_until(func() -> bool: return not _scene._animation_lock and _scene._combat_state["player"]["pos"] == Gear.Witness.HERO), "Return to finisher tile."): return false
	_finish_with_card(Gear.Witness.TICK)
	if not _check(await _reward_ready(), "Reward after live gear case " + study): return false
	var state_notice: String = _scene._run_state.get("notice", "")
	var visible_notice: String = _scene.log_label.text if _scene.log_overlay.is_visible_in_tree() else ""
	var resolved: Dictionary = _scene._run_state["pending_reward"]["board_state"]
	_record("gear_" + study, {"notice": state_notice, "visible_notice": visible_notice, "loot": resolved["loot"], "missed": resolved.get("missed_equipment", [])})
	return _check(visible_notice.contains(EXPIRED) == (study == "left"), "Only left-behind gear triggers the notice.") and await _capture("03_gear_" + study)

func _reward_ready() -> bool:
	return await _wait_until(func() -> bool: return _scene._run_state.get("mode") == "reward" and not _scene._animation_lock and not _scene._reward_intro_pending())

func _escape(trial: int) -> bool:
	var options := {"dragon_id": "noctyrax", "dragon_depth": RunEngine.MAX_DEPTH, "dragon_case": "encounter", "seed": FIXTURE_SEED + trial}
	_options = options.duplicate()
	_options.merge({"hand": FINISHER, "umbra_stage": "clear"})
	var state: Dictionary = _build_run_state("dragon", _profile)
	var battle: Dictionary = state["combat_state"]
	var boss: Dictionary = battle["enemies"][0]
	var tile: Vector2i = boss["pos"]
	battle["player"]["pos"] = tile + Vector2i.DOWN * int(boss.get("footprint", Vector2i.ONE).y)
	battle["grid"][battle["player"]["pos"].y][battle["player"]["pos"].x] = "stone"
	boss["hp"] = 1
	boss["block"] = 0
	if not await _open(state): return false
	_finish_with_card(tile + Vector2i.DOWN * (int(boss.get("footprint", Vector2i.ONE).y) - 1))
	if not _check(await _reward_ready(), "A live final-dragon win reached the milestone reward."): return false
	var overlay: Control = _scene._post_combat_victory_overlay
	var recap: Control = _scene._run_end_recap
	_scene._on_dragon_reward_continue()
	if not _check(await _wait_until(func() -> bool: return recap.visible or is_instance_valid(_scene.find_child("LeaveNothing", true, false))), "Final Continue reached the heirloom choice or recap."): return false
	var leave: Button = _scene.find_child("LeaveNothing", true, false)
	if leave != null: leave.pressed.emit()
	if not _check(await _wait_until(func() -> bool: return _scene._run_state.get("mode") == "victory" and recap.is_visible_in_tree()), "Final Continue reached the escape screen."): return false
	var first_visible: bool = overlay.is_visible_in_tree()
	if not _check(await _wait_until(func() -> bool: return not _scene._relic_claim_in_progress and recap._title.modulate.a >= 0.99), "The escape recap settled."): return false
	_record("escape_%d" % trial, {"banner_on_first_recap_frame": first_visible, "banner_visible": overlay.is_visible_in_tree(),
		"board_status": _scene.board_view.status_label, "title": recap._title.text})
	return await _capture("04_escape_%d" % trial)

func _arrival(study: String) -> bool:
	var state: Dictionary
	var opening: bool = study in ["opening", "dragon_opening"]
	if study == "dragon_opening":
		_options = {"dragon_id": "noctyrax", "dragon_depth": RunEngine.MAX_DEPTH, "dragon_case": "pre_battle", "seed": FIXTURE_SEED}
		state = _build_run_state("dragon", _profile)
	elif study == "opening":
		_options = {"room_coord": "1,0", "seed": FIXTURE_SEED, "notice": " "}
		state = _build_run_state("pre_battle", _profile)
	elif study == "summon":
		_options = Gear.Witness.options("chain_bolt", FIXTURE_SEED)
		_options.merge({"enemy_types": "storm_cantor", "enemy_positions": "4:2"}, true)
		state = _build_run_state("combat", _profile)
		Gear.Witness.configure("chain_bolt", state["combat_state"])
		Gear.Witness._intent(state["combat_state"]["enemies"][0], "call_the_spark")
	else: state = _combat_fixture()
	var battle: Dictionary = state["combat_state"]
	if study == "reinforcement":
		battle["objective"] = {"type": CombatObjectiveRules.SURVIVE, "target_clock": 80, "reinforcement_interval": 80,
			"next_reinforcement_clock": 1, "reinforcement_waves_spawned": 0, "reinforcement_pool": ["crawler"]}
	if not await _open(state): return false
	var requests: Array[Dictionary]
	var bank: Node = _scene._sfx_bank
	bank.cue_requested.connect(func(cue: String, result: String) -> void:
		requests.append({"cue": cue, "result": result, "ms": bank.now_ms(), "frame": Engine.get_process_frames()}))
	var initial: Array = (battle.get("enemies", []) as Array).map(func(enemy: Dictionary) -> int: return int(enemy["id"]))
	if opening:
		_scene._on_pre_battle_start_pressed()
		if not _check(await _wait_until(func() -> bool: return _scene._run_state.get("mode") == "combat"), "Start enters ordinary combat."): return false
		await _samples.sampled
		_record("arrival_" + study, {"ms": bank.now_ms(), "frame": Engine.get_process_frames(),
			"ids": _scene._combat_state["enemies"].map(func(enemy: Dictionary) -> int: return int(enemy["id"]))})
		if study == "dragon_opening":
			if not _check(await _wait_until(func() -> bool: return _played(requests, "dragon.roar")), "The dragon opening played its roar."): return false
		if not await _capture("05_" + study): return false
	else:
		_scene._on_pass_turn_pressed()
		if not _check(await _wait_until(func() -> bool: return not _arriving(initial).is_empty()), "A visible body arrived in the live " + study + " fixture."): return false
		_record("arrival_" + study, {"ids": _arriving(initial), "ms": bank.now_ms(), "frame": Engine.get_process_frames()})
		if not await _capture("05_" + study): return false
	if not _check(await _wait_until(func() -> bool: return not _scene._animation_lock), "Opening or enemy phase settled for " + study): return false
	var trace: Dictionary = {"requests": requests}
	if study == "opening" and not _played(requests, "summon.arrive"):
		trace["TODO_DESIGN_arrival_cue"] = "Ordinary combat has no generic opening arrival cue."
	_record("sound_" + study, trace)
	return true

func _played(requests: Array[Dictionary], cue: String) -> bool:
	return requests.any(func(row: Dictionary) -> bool: return row["cue"] == cue and row["result"] == "played")

func _arriving(initial: Array) -> Array:
	var shown: Dictionary = _scene.board_view.presentation
	var units: Array = shown.get("death_animation_units", [])
	var hidden: Dictionary = shown.get("self_burst_hide_arrivals", {})
	for unit: Dictionary in units:
		if unit.get("arrival_animation", false) and float(unit.get("death_progress", 1)) < 1.0 and not hidden.has(str(unit.get("key", ""))):
			return [int(unit.get("id", -1))]
	var visible: Array = shown.get("visible_enemy_ids", [])
	return visible.filter(func(id: Variant) -> bool: return not initial.has(id))

func _reward() -> bool:
	var state: Dictionary = _combat_fixture()
	state["combat_state"]["loot"] = []
	if not await _open(state): return false
	_finish_with_card(Gear.Witness.TICK)
	if not _check(await _reward_ready(), "An ordinary live win reached the three-card reward."): return false
	var banner: Control = _scene._relic_choice_banner
	var skip: Control = _scene.find_child("RewardSecondaryActions", true, false)
	if not _check(is_instance_valid(banner) and is_instance_valid(skip), "Reward layout owners are present."): return false
	_record("reward", {"banner": str(banner.get_global_rect()), "actions": str(skip.get_global_rect()),
		"notice": _scene.log_label.text if _scene.log_overlay.is_visible_in_tree() else "",
		"notice_rect": str(_scene.log_overlay.get_global_rect()), "hand": _scene.hand_scroll.is_visible_in_tree()})
	return await _capture("06_reward")
