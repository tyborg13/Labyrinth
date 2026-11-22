extends SceneTree
## Each seed resumes a real generated room, then drives the production scene.
## Synthetic post-draw in headless uses the same convention as run_hunt.gd.
const Hunt = preload("res://tools/run_hunt.gd")
const Policy = preload("res://tools/run_hunt_policy.gd")
const Board = preload("res://tools/brd01/fixture.gd")
const Oracle = preload("res://tools/qa120/oracle.gd")
const Pass = preload("res://tools/qa120/pass_outcome.gd")
const Inputs = preload("res://tools/qa120/inputs.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Recent = preload("res://scripts/recent_event_store.gd")
const SPEED_SCALE: float = 4.0
const NORMAL_SPEED_SCALE: float = 1.0
const FRAME_RATE: int = 60
const SETTLE_FRAMES: int = 24
const INPUT_READY_TIMEOUT_MS: int = 60000
const MAX_FRAME_GAP: int = 6
const ORDINARY_GAP: int = 24
const DEFAULT_DECISIONS: int = 9
const SEED_BASE: int = 12000
const REGRESSION_SEED: int = 102
const REGRESSION_ENEMIES: String = "crawler,acolyte,harrier"
const CONTROL_CASES := ["gfix23_mouse", "gfix23_rotate", "gfix23_details"]
const CONTROL_FOCUS_FRAMES: int = 12
const Fixture = preload("res://tools/hitch_census/fixtures.gd")
const INVALID := Vector2i(-1, -1)

var output: String
var headless: bool
var options: Dictionary
var scene: Control
var seed_value: int
var section: int
var step: int
var encounter: String
var case_name: String
var trace: FileAccess
var rng := RandomNumberGenerator.new()
var policy := Policy.new()
var input: RefCounted
var oracle: RefCounted
var counts: Dictionary
var errors: Array[String]
var pending_axis: bool
var canvas: SubViewport
var pulse: ColorRect
var captures: Dictionary

func _initialize() -> void:
	Board.Runtime.apply_from_environment()
	headless = DisplayServer.get_name() == "headless"
	OS.set_environment("LABYRINTH_PROBE_WINDOW", "1")
	for arg: String in OS.get_cmdline_user_args():
		var parts: PackedStringArray = arg.split("=", true, 1)
		if parts.size() == 2: options[parts[0]] = parts[1]
	if headless: process_frame.connect(func() -> void: RenderingServer.frame_post_draw.emit())
	call_deferred("_run")

func _run() -> void:
	output = options.get("--out", "")
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		push_error("QA120 needs a writable --out= directory")
		quit(2)
		return
	trace = FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	if trace == null:
		push_error("QA120 could not open trace.jsonl")
		quit(2)
		return
	root.size = Board.DESKTOP
	root.content_scale_size = Board.DESKTOP
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	canvas = SubViewport.new()
	canvas.size = Board.DESKTOP
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	canvas.notify_mouse_entered()
	if not headless:
		var view := TextureRect.new()
		view.texture = canvas.get_texture()
		view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		root.add_child(view)
		pulse = ColorRect.new()
		pulse.size = Vector2.ONE
		pulse.modulate.a = 0.001
		pulse.mouse_filter = Control.MOUSE_FILTER_IGNORE
		canvas.add_child(pulse)
		process_frame.connect(func() -> void: pulse.position.x = float(Engine.get_process_frames() % 2))
	Engine.max_fps = FRAME_RATE if not headless else Hunt.SAMPLE_FPS
	policy.rng = rng
	var chosen_case: String = options.get("--case", "")
	if chosen_case == "all":
		for name: String in CONTROL_CASES: await _regression(name)
	elif chosen_case == "coverage":
		await _exercise_input_matrix()
	elif not chosen_case.is_empty():
		await _regression(chosen_case)
	else:
		var first: int = int(options.get("--seed", SEED_BASE + 1))
		for offset: int in range(int(options.get("--count", 1))):
			await _fight(first + offset)
	trace.close()
	var details: Dictionary = {"counts": counts, "errors": errors, "headless": headless}
	var receipt: FileAccess = FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	if receipt != null: receipt.store_string(JSON.stringify(details, "  ") + "\n")
	print("QA120 RESULT %s %s" % ["PASS" if errors.is_empty() else "FAIL", JSON.stringify(details)])
	quit(0 if errors.is_empty() else 1)

func _mount(run: Dictionary, normal: bool) -> bool:
	if run.get("mode", "") != "combat":
		errors.append("No generated combat for %s/%d/%s" % [seed_value, section + 1, encounter])
		return false
	var key: String = "seed-%d" % seed_value if case_name.is_empty() else case_name
	var path: String = output.path_join(key)
	DirAccess.make_dir_recursive_absolute(path)
	Board.Store.set_storage_path(path.path_join("progression.json"))
	Board.Store.set_run_storage_path(path.path_join("run.save"))
	Settings.set_storage_path(path.path_join("settings.json"))
	Analytics.set_storage_dir(path.path_join("analytics"))
	Recent.set_storage_path(path.path_join("recent.json"))
	var settings: Dictionary = Settings.default_settings()
	settings.merge({"ui_scale": 1.0, "display_mode": "windowed", "reduced_motion": false,
		"combat_speed": Settings.COMBAT_NORMAL if normal else Settings.COMBAT_FASTEST}, true)
	Settings.save_settings(settings)
	Board.Store.save_data(run["progression"])
	if not Board.Store.save_run_state(run):
		errors.append("Could not save combat for seed %d" % seed_value)
		return false
	root.set_meta("labyrinth_resume_saved_run", true)
	root.get_node("InputRouter").set_modality("pointer")
	Engine.time_scale = NORMAL_SPEED_SCALE if normal else SPEED_SCALE
	scene = Board.RunScene.instantiate()
	canvas.add_child(scene)
	oracle = Oracle.new(scene)
	input = Inputs.new(canvas, scene)
	await _frames(SETTLE_FRAMES)
	if not await _ready():
		errors.append("Scene failed to reach combat input for seed %d" % seed_value)
		return false
	if canvas.size != Board.DESKTOP or not is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), 1.0):
		errors.append("Unexpected proof geometry for seed %d" % seed_value)
		return false
	_emit("start", {"normal_speed": normal, "room_name": scene._combat_state.get("room_name"),
		"enemies": scene._combat_state.get("enemies", []).map(func(unit: Dictionary) -> String: return unit.get("type", ""))})
	return true

func _generated(fight_type: String) -> Dictionary:
	var engine := Board.Run.new()
	var progression: Dictionary = Board.Tutorial.complete_tutorial(Board.Store.default_data())
	var run: Dictionary = engine.create_new_run(seed_value, progression)
	var rooms: Array[Dictionary]
	for room: Dictionary in run["rooms"].values():
		if int(room.get("section_index", -1)) == section and room.get("type") == fight_type: rooms.append(room)
	if rooms.is_empty(): return {}
	var chosen: Dictionary = rooms[rng.randi_range(0, rooms.size() - 1)]
	run["current_room"] = chosen["coord"]
	chosen["revealed"] = true
	chosen["visited"] = true
	run["current_room_layout"] = engine._display_layout_for_room(seed_value, chosen, Board.ENTRANCE)
	run["mode"] = "pre_battle"
	run["pre_battle_pending"] = true
	run["pre_battle_travel_dir"] = Board.ENTRANCE
	return engine.begin_pre_battle_combat(run)

func _fight(value: int) -> void:
	seed_value = value
	rng.seed = value
	step = 0
	section = posmod(value - SEED_BASE - 1, 3)
	encounter = "combat"
	if posmod(value - SEED_BASE, 11) == 0: encounter = "guardian"
	if posmod(value - SEED_BASE, 11) == 1: encounter = "boss"
	var run: Dictionary = _generated(encounter)
	if run.is_empty() and encounter == "guardian":
		encounter = "combat"
		run = _generated(encounter)
	var normal: bool = posmod(value, 4) == 0
	if await _mount(run, normal):
		_count("ordinary_speed_seed" if normal else "fast_speed_seed")
		await _pass("mouse" if value % 2 == 0 else "controller")
		for index: int in range(int(options.get("--decisions", DEFAULT_DECISIONS))):
			if not await _ready(): break
			await _decision(index, normal)
		if await _ready():
			await _reset_aim()
			await _pass("controller" if value % 2 == 0 else "mouse")
		_count("seeds")
		_count("section-%d" % (section + 1))
		_count(encounter)
		_emit("finish", {"mode": scene._run_state.get("mode")})
	await _close_scene()

func _decision(index: int, normal: bool) -> void:
	step += 1
	if scene._selected_card_index >= 0 or scene._player_movement_selected:
		await _legal_decision()
		return
	var cards: Array = policy._combat(scene).filter(func(action: Dictionary) -> bool: return action["kind"] == "card")
	if cards.is_empty() or index % 4 == 3:
		await _legal_decision()
		return
	var action: Dictionary = policy.choose(scene, cards)
	var card_index: int = action["args"][0]
	var controller: bool = (index + seed_value) % 2 == 0
	var gap: int = ORDINARY_GAP if normal else (seed_value + index * 3) % (MAX_FRAME_GAP + 1)
	var pair: int = (seed_value + index) % 7
	var first: Dictionary
	if controller:
		input.focus_card(card_index)
		await _frames(SETTLE_FRAMES if normal else 2)
		if scene._controller_hand_index != card_index or scene._controller_region != "hand":
			_count("controller_focus_unavailable")
			await _legal_decision()
			return
		first = {"kind": "controller_select", "card": action.get("card_id"), "index": card_index}
		await _burst(first, input.button.bind(JOY_BUTTON_A), gap, pair)
	else:
		input.card_hover(card_index)
		await _frames(SETTLE_FRAMES if normal else 3)
		first = {"kind": "mouse_select", "card": action.get("card_id"), "index": card_index}
		await _burst(first, input.card_click.bind(card_index), gap, pair)
	if await _ready() and scene._selected_card_index >= 0: await _legal_decision()

func _burst(first: Dictionary, send: Callable, gap: int, pair: int) -> void:
	var started: int = Engine.get_process_frames()
	send.call()
	var selected: bool = scene._selected_card_index == int(first["index"])
	var pending: bool = scene._selected_pass_work.active(scene)
	var samples: Array[Dictionary]
	for frame: int in range(gap):
		samples.append(_sample(frame - gap))
		await process_frame
	var follow: Dictionary = _follow_up(pair)
	var actual_gap: int = Engine.get_process_frames() - started
	_count(first["kind"])
	if selected: _count(first["kind"] + "_accepted")
	if pending: _count("worker_pending_at_first")
	_count("gap-%d" % actual_gap)
	_count(follow["kind"])
	if follow.get("changed", false): _count(follow["kind"] + "_changed")
	first["accepted"] = selected
	first["worker_pending"] = pending
	await _observe([first, follow], actual_gap, samples)
	if selected and not scene._animation_lock and scene._selected_card_index >= 0 and pair != 5:
		step += 1
		var next_first: Dictionary = _follow_up(pair)
		var second_gap: int = ORDINARY_GAP if gap == ORDINARY_GAP else posmod(gap + 2, MAX_FRAME_GAP + 1)
		await _frames(second_gap)
		var next_second: Dictionary = _follow_up(posmod(pair + 3, 7))
		_count("first:" + next_first["kind"])
		if next_first["changed"]: _count("first_accepted:" + next_first["kind"])
		_count("second:" + next_second["kind"])
		await _observe([next_first, next_second], second_gap)

func _follow_up(pair: int) -> Dictionary:
	var before: Array = _input_state()
	var kind: String
	var tile: Vector2i = input.target(rng)
	match pair:
		0:
			kind = "controller_rotate_rb"
			input.button(JOY_BUTTON_RIGHT_SHOULDER)
		1:
			kind = "mouse_retarget"
			input.tile_motion(tile)
		2:
			kind = "controller_aim_dpad"
			input.button(JOY_BUTTON_DPAD_RIGHT)
		3:
			kind = "details_key_i"
			input.details()
		4:
			kind = "controller_stick"
			input.stick(Inputs.STICK_MAGNITUDE)
			pending_axis = true
		5:
			kind = "mouse_board_click"
			if case_name == "input_matrix": tile = input.empty_tile()
			input.tile_click(tile)
		_:
			kind = "mouse_hover_pass"
			input.pass_hover()
	return {"kind": kind, "target": tile, "before": before, "after": _input_state(), "changed": before != _input_state()}

func _input_state() -> Array:
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	return [scene._selected_card_index, scene._hovered_board_tile, scene._aoe_aim_orientation,
		scene._show_all_enemy_intents, scene._controller_region, scene._animation_lock,
		scene._controller_stick, scene._controller_hand_index, scene._hovered_card_index,
		chip.get_meta("pass_pointer_hover", false) if chip != null else false]

func _legal_decision() -> void:
	var candidates: Array = policy._combat(scene)
	if candidates.is_empty():
		if scene._selected_card_index >= 0: await _reset_aim()
		return
	var action: Dictionary = policy.choose(scene, candidates)
	if action["kind"] == "pass":
		await _pass("controller" if seed_value % 2 == 0 else "mouse")
		return
	_emit("legal_action", {"kind": action["kind"], "args": action.get("args", []), "tile": action.get("tile"),
		"card": action.get("card_id", scene._card_id_for_hand_index(scene._selected_card_index))})
	_count("legal:" + action["kind"])
	policy.dispatch(scene, action)
	await _ready()
	if scene._run_state.get("mode", "") == "combat":
		await _observe([{"kind": "legal:" + action["kind"], "args": action.get("args", []), "tile": action.get("tile")}], -1)

func _reset_aim() -> void:
	input.button(JOY_BUTTON_B)
	await _frames(3)

func _pass(path: String) -> void:
	if scene._selected_card_index >= 0 or scene._player_movement_selected: return
	step += 1
	input.pass_hover()
	await _frames(SETTLE_FRAMES)
	if not scene._pass_preview_action_available(): return
	var receipt: Dictionary = oracle.sample()
	var chip: Button = scene._pass_preview_overlay.get_node_or_null("PassPreviewChip")
	var shown: Dictionary = chip.get_meta("pass_forecast_summary", {}) if chip != null else {}
	var before: Dictionary = scene._combat_state.duplicate(true)
	var summary: Dictionary = oracle.fresh
	var resolved: Dictionary = Pass.replay(scene, before)
	var sequence: Array = [{"kind": "mouse_hover_pass"}, {"kind": path + "_pass"}]
	if path == "controller": input.button(JOY_BUTTON_Y)
	else: input.pass_click()
	if not scene._animation_lock and before == scene._combat_state:
		_count("pass_input_rejected:" + path)
		_emit("rejected", {"sequence": sequence})
		return
	_count("pass_input:" + path)
	var finished: bool = await _ready()
	var live: Dictionary = scene._combat_state
	if live.is_empty() and scene._run_state.get("mode") != "combat":
		live = scene._run_state.get("pending_escape", {}).get("board_state", {})
	if not finished and scene._run_state.get("mode") == "combat":
		errors.append("Pass failed to settle at seed %d step %d" % [seed_value, step])
		return
	var terminal: Dictionary = Pass.terminal_receipt(Analytics.storage_dir()) if live.is_empty() else {}
	var outcome: Dictionary = Pass.examine(summary, shown, resolved, live, terminal)
	outcome["pre_pass_issues"] = receipt["issues"]
	outcome["sequence"] = sequence
	outcome["gap"] = SETTLE_FRAMES
	for name: String in outcome["checks"]: _count(name)
	_emit("pass", outcome)

func _regression(name: String) -> void:
	case_name = name
	seed_value = int(options.get("--seed", REGRESSION_SEED))
	section = 0
	encounter = "combat"
	rng.seed = seed_value
	var card: String = {"gfix23_mouse": "stone_plate", "gfix23_rotate": "earthen_rampart", "gfix23_details": "pale_spark"}.get(name, "")
	if card.is_empty():
		errors.append("Unknown regression " + name)
		return
	var run: Dictionary = _control_run(card)
	if run.is_empty(): return
	var battle: Dictionary = run["combat_state"]
	if name == "gfix23_details":
		for unit: Dictionary in battle["enemies"]:
			unit["hp"] = 1
			unit["block"] = 0
			unit["stoneskin"] = 0
	if not await _mount(run, true):
		await _close_scene()
		return
	input.focus_card(0)
	await _frames(CONTROL_FOCUS_FRAMES)
	step = 1
	input.button(JOY_BUTTON_A)
	if scene._selected_card_index != 0 or not scene._selected_pass_work.active(scene):
		errors.append("Control did not start a pending controller forecast for " + name)
	var gap: int = int(options.get("--gap", 0))
	var samples: Array[Dictionary]
	for index: int in range(gap):
		samples.append(_sample(index - gap))
		await process_frame
	var before: Array = _input_state()
	var tile: Vector2i = INVALID
	if name == "gfix23_mouse":
		tile = input.empty_tile()
		input.tile_click(tile)
	elif name == "gfix23_rotate": input.button(JOY_BUTTON_RIGHT_SHOULDER)
	else: input.details()
	await _observe([{"kind": "controller_select", "card": card},
		{"kind": name, "tile": tile, "before": before, "after": _input_state()}], gap, samples)
	await _close_scene()

func _control_run(card: String) -> Dictionary:
	var run: Dictionary
	var archived: String = options.get("--fixture", "")
	if archived.is_empty():
		var fixture := Fixture.new()
		run = fixture.make("combat", seed_value, {"umbra_stage": "clear",
			"enemy_types": REGRESSION_ENEMIES, "hand": "flowing_step,stone_plate,pale_spark"})
		fixture.free()
	elif FileAccess.file_exists(archived):
		var archive: Variant = bytes_to_var(FileAccess.get_file_as_bytes(archived))
		if archive is Dictionary: run = archive.get("cases", {}).get("normal", {}).duplicate(true)
	if run.get("mode") != "combat":
		errors.append("Could not open control fixture")
		return {}
	run["combat_state"]["deck"]["hand"][0] = card
	return run

func _exercise_input_matrix() -> void:
	case_name = "input_matrix"
	seed_value = REGRESSION_SEED
	section = 0
	encounter = "combat"
	rng.seed = seed_value
	var run: Dictionary = _control_run("earthen_rampart")
	if run.is_empty() or not await _mount(run, true):
		await _close_scene()
		return
	# Verify every category as the first input even if the seeded driver never
	# drew a rotatable card at the right position or repeated that focus.
	for pair: int in range(7):
		await _reset_aim()
		var card_index: int = 0
		input.focus_card(card_index)
		await _frames(CONTROL_FOCUS_FRAMES)
		if pair in [0, 1, 2, 4]:
			input.button(JOY_BUTTON_A)
			if scene._selected_card_index != card_index:
				errors.append("Input matrix could not select the rotating card before pair %d" % pair)
			await _frames(SETTLE_FRAMES)
		else:
			input.tile_motion(input.empty_tile())
			await _frames(SETTLE_FRAMES)
		step += 1
		var first_frame: int = Engine.get_process_frames()
		var first: Dictionary = _follow_up(pair)
		await _frames(pair)
		var second: Dictionary
		if pair == 1 or pair == 3 or pair == 5:
			second = _follow_up(3 if pair == 1 else 4 if pair == 3 else 1)
		else:
			second = _follow_up({0: 6, 2: 0, 4: 2, 6: 3}.get(pair, 3))
		if not first["changed"]: errors.append("Input matrix did not change state for " + first["kind"])
		await _observe([first, second], Engine.get_process_frames() - first_frame)
		await _ready()
	await _close_scene()

func _observe(sequence: Array, gap: int, samples: Array[Dictionary] = []) -> void:
	for frame: int in range(SETTLE_FRAMES + 1):
		samples.append(_sample(frame))
		if frame == 0 and not _capture_label().is_empty():
			await _capture(_capture_label() + "-first")
		if pending_axis and frame == 4:
			input.stick(0.0)
			pending_axis = false
		if frame < SETTLE_FRAMES: await process_frame
	var seen: Dictionary = {}
	var coverage: Dictionary = {}
	for sample: Dictionary in samples:
		for check: String in sample["checks"]:
			coverage[check] = int(coverage.get(check, 0)) + 1
			_count(check)
		for issue: String in sample["issues"]:
			if not seen.has(issue): seen[issue] = []
			seen[issue].append({"frame": sample["frame"], "values": sample["issues"][issue], "pending": sample.get("pending", {})})
	var last: Dictionary = samples.back()
	var verdicts: Dictionary = {}
	for key: String in seen:
		verdicts[key] = _verdict(key, last)
	_emit("window", {"sequence": sequence, "gap": gap, "coverage": coverage, "issues": seen,
		"verdicts": verdicts, "last": last, "turn": scene._combat_state.get("turn"), "state": _input_state()})
	if not _capture_label().is_empty(): await _capture(_capture_label() + "-settled")

func _capture_label() -> String:
	if headless: return ""
	if CONTROL_CASES.has(case_name): return case_name
	if step == int(options.get("--capture-step", -1)):
		return "seed-%d-step-%d" % [seed_value, step]
	return ""

func _verdict(key: String, last: Dictionary) -> String:
	if last["checks"].is_empty(): return "superseded or locked"
	if last["issues"].has(key):
		if last["pending"]["owns_selection"] or last["pending"]["board_hover"] or last["pending"]["hand_hover"]:
			return "still pending at frame %d" % SETTLE_FRAMES
		return "persistent at frame %d" % SETTLE_FRAMES
	if key == "details.intents" and not last["checks"].has("details"): return "Details closed"
	if key.begins_with("card.") and key != "card.hand_time_and_rules" and not last["checks"].has("card_damage_and_status"):
		return "aim ended"
	return "settled"

func _sample(frame: int) -> Dictionary:
	var result: Dictionary = oracle.sample() if scene._run_state.get("mode", "") == "combat" else {"checks": [], "issues": {}}
	result["frame"] = frame
	return result

func _ready() -> bool:
	var deadline: int = Time.get_ticks_msec() + INPUT_READY_TIMEOUT_MS
	while Time.get_ticks_msec() < deadline:
		if scene._initial_ui_complete and scene._run_state.get("mode", "") != "combat": return false
		if scene._initial_ui_complete and not scene._animation_lock and scene._hand_layout_pending_revision < 0:
			return scene._combat_engine.is_player_turn(scene._combat_state)
		await process_frame
	errors.append("Input ready timeout at seed %d step %d" % [seed_value, step])
	return false

func _frames(count: int) -> void:
	for index: int in range(count): await process_frame

func _close_scene() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await _frames(CONTROL_FOCUS_FRAMES)
	input = null
	oracle = null
	pending_axis = false

func _capture(label: String) -> void:
	if captures.has(label): return
	captures[label] = true
	await RenderingServer.frame_post_draw
	var picture: Image = canvas.get_texture().get_image()
	var path: String = output.path_join(label + ".png")
	if picture != null and picture.get_size() == Board.DESKTOP and picture.save_png(path) == OK: print(path)
	else: errors.append("Capture failed for " + label)

func _count(key: String) -> void:
	counts[key] = int(counts.get(key, 0)) + 1

func _emit(kind: String, fields: Dictionary) -> void:
	var record: Dictionary = {"event": kind, "seed": seed_value, "step": step, "section": section + 1,
		"encounter": encounter, "case": case_name, "room": scene._run_state.get("current_room") if is_instance_valid(scene) else null}
	record.merge(fields, true)
	transcript_line(record)

func transcript_line(record: Dictionary) -> void:
	trace.store_line(JSON.stringify(record))
	trace.flush()
