extends Node
## Fresh seeded descents, using viewport input and the fel-20 hunt policy.

const Shutdown = preload("res://scripts/application_shutdown.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Events = preload("res://scripts/recent_event_store.gd")
const Inputs = preload("res://tools/fel30/input_driver.gd")
const Screens = preload("res://tools/fel30/screens.gd")
const Paint = preload("res://tools/fel30/paint_list.gd")
const Coverage = preload("res://tools/fel30/coverage.gd")
const Route = preload("res://tools/fel30/route.gd")

const SIZE := Vector2i(1920, 1080)
const FPS := 60
const HEADLESS_TIME_SCALE := 4.0
const SETUP_FRAMES := 3
const INPUT_TIMEOUT_MS := 120000
const MAX_COMBATS := 12
const SEEDS := [30001, 30002, 30003, 30004, 30005, 30006]
const RARE := ["Warband", "Guardian", "dragon"]

var _tree: SceneTree
var _inputs: Inputs
var _screens: Screens
var _route: Route
var _native: bool
var _output: String
var _seed: int
var _combat: int
var _room: String
var _kind: String
var _combat_turn: int
var _action_number: int
var _moment: int
var _last_screen: String
var _highest_depth: int
var _highest_section: int
var _rare_seen: Dictionary
var _enemy_index: int
var _moment_file: FileAccess
var _run_file: FileAccess
var _limit_seeds: int = SEEDS.size()
var _seed_start: int = 0
var _paint := Paint.new()
var _coverage := Coverage.new()
var _capture: Dictionary
var _wanted: Dictionary
var _transcript: Dictionary
var _input_file: FileAccess
var _seed_actions: int
var _categories: Dictionary
var _flagged: int
var _end_override: String


func start(tree: SceneTree) -> void:
	_tree = tree
	Runtime.apply_from_environment()
	_native = DisplayServer.get_name() != "headless"
	_output = OS.get_environment("FEL30_OUTPUT")
	if OS.has_environment("FEL30_SEED_START"): _seed_start = int(OS.get_environment("FEL30_SEED_START"))
	if OS.has_environment("FEL30_SEED_LIMIT"): _limit_seeds = int(OS.get_environment("FEL30_SEED_LIMIT"))
	if _output.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK:
		_fail("set FEL30_OUTPUT to an output directory")
		return
	if _native:
		if not _load_replay():
			_fail("cannot load native replay log or capture selection")
			return
		_tree.root.title = "Escape the Umbra"
	_tree.root.mode = Window.MODE_WINDOWED
	_tree.root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	_tree.root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	_tree.root.content_scale_size = SIZE
	_tree.root.size = SIZE
	Engine.max_fps = FPS
	if not _native: Engine.time_scale = HEADLESS_TIME_SCALE
	OS.low_processor_usage_mode = false
	if not _native: _tree.process_frame.connect(_fake_draw.call_deferred)
	_tree.root.set_meta("fel30_enemy_action", _enemy_action)
	_inputs = Inputs.new(_tree.root)
	_screens = Screens.new(_tree, _inputs)
	_moment_file = FileAccess.open(_output.path_join("moments.jsonl"), FileAccess.WRITE)
	_run_file = FileAccess.open(_output.path_join("runs.jsonl"), FileAccess.WRITE)
	_input_file = FileAccess.open(_output.path_join("inputs.jsonl"), FileAccess.WRITE)
	if _moment_file == null or _run_file == null or _input_file == null:
		_fail("cannot open output files")
		return
	_run.call_deferred()


func _fake_draw() -> void:
	RenderingServer.frame_pre_draw.emit()
	RenderingServer.frame_post_draw.emit()


func _run() -> void:
	for seed: int in SEEDS.slice(_seed_start, _seed_start + _limit_seeds):
		if _native and not _transcript.has(seed): continue
		if not _native and _seed_start == 0 and seed >= SEEDS[3] and _rare_seen.size() == RARE.size(): break
		if _native and is_instance_valid(_tree.current_scene):
			_tree.unload_current_scene()
			await _tree.process_frame
		_seed = seed
		_seed_actions = 0
		_combat = 0
		_room = ""
		_last_screen = ""
		_highest_depth = 0
		_highest_section = 0
		_tree.root.set_meta("labyrinth_performance_probe_seed", seed)
		_route = Route.new()
		_route.inputs = _inputs
		_route.no_embrace = true
		_route.rng = RandomNumberGenerator.new()
		_route.rng.seed = seed
		if not _profile():
			_fail("cannot prepare profile for %d" % seed)
			return
		if _tree.change_scene_to_file("res://scenes/main_menu.tscn") != OK:
			_fail("cannot load title")
			return
		var reason: String = await _play()
		if _native and _seed_actions != (_transcript[seed] as Array).size():
			_fail("seed %d used %d replay inputs, expected %d" % [seed, _seed_actions, _transcript[seed].size()])
			return
		_write(_run_file, {"seed": seed, "end": reason, "combats": _combat, "depth": _highest_depth, "section": _highest_section})
		print("FEL30 RUN seed=%d combats=%d section=%d depth=%d end=%s" % [seed, _combat, _highest_section, _highest_depth, reason])
		if reason == "blocked" or reason == "capture error":
			_fail("route blocked")
			return
	if _native and not _wanted.is_empty():
		_fail("native replay missed %s" % str(_wanted.keys()))
		return
	if _native:
		print("FEL30 NATIVE frames=%d" % _capture.size())
	else:
		print("FEL30 CENSUS moments=%d flagged=%d" % [_moment, _flagged])
		for category: String in Coverage.WEIGHTS:
			print("FEL30 CATEGORY %s=%d" % [category, _categories.get(category, 0)])
	_tree.quit()


func _profile() -> bool:
	var folder: String = _output.path_join("profiles").path_join(str(_seed))
	if DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) != OK: return false
	Store.set_run_storage_path(folder.path_join("run.save"))
	Store.set_storage_path(folder.path_join("progression.json"))
	Settings.set_storage_path(folder.path_join("settings.json"))
	Analytics.set_storage_dir(folder.path_join("analytics"))
	Events.set_storage_path(folder.path_join("recent_events.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	return Settings.save_settings(settings)


func _play() -> String:
	var last_progress: int = Time.get_ticks_msec()
	var last_moment: int = _moment
	while true:
		await RenderingServer.frame_post_draw
		if not _end_override.is_empty(): return _end_override
		if _tree.root.get_visible_rect().size != Vector2(SIZE):
			_fail("unexpected logical viewport " + str(_tree.root.get_visible_rect().size))
			return "capture error"
		var screen: String = _screens.screen()
		var scene: Node = _screens.run_scene()
		if scene != null: _observe_combat(scene)
		if last_moment != _moment:
			last_moment = _moment
			last_progress = Time.get_ticks_msec()
		if screen == "recap": return "recap"
		if _combat >= MAX_COMBATS and screen in ["map", "room", "reward"]: return "combat cap"
		if _dispatchable(scene, screen):
			var source: Array = _screens.witness()
			_route.observe(source)
			var input: Dictionary = _route.next(_tree.current_scene) if not _native else _replay_input(source)
			if not input.is_empty():
				_inputs.prepare(input)
				for frame: int in SETUP_FRAMES: await RenderingServer.frame_post_draw
				input = _inputs.resolve(_tree.current_scene, input)
				if not input.is_empty():
					_inputs.prepare(input)
					_inputs.send(input)
					_route.dispatched(input)
					_write(_input_file, {"seed": _seed, "before": source, "input": input})
					_action_number += 1
					_seed_actions += 1
					if _action_number % 50 == 0:
						print("FEL30 INPUT action=%d %s %s" % [_action_number, input["label"], str(source)])
					if source != _screens.witness(): last_progress = Time.get_ticks_msec()
		if Time.get_ticks_msec() - last_progress > INPUT_TIMEOUT_MS:
			print("FEL30 STALLED seed=%d witness=%s" % [_seed, str(_screens.witness())])
			return "blocked"
		if screen != _last_screen:
			last_progress = Time.get_ticks_msec()
			_last_screen = screen

	return "blocked"


func _dispatchable(scene: Node, screen: String) -> bool:
	if not is_instance_valid(_tree.current_scene) or Shutdown.departure_requested(_tree) or _tree.root.gui_disable_input: return false
	if screen in ["boot", "loading", "title_boot", "between_scenes"]: return false
	if scene == null: return true
	if scene._animation_lock or is_instance_valid(scene._section_transition) or scene._treasure_presentation_busy(): return false
	if is_instance_valid(scene._event_view) and scene._event_view.visible:
		if scene._event_view._busy or scene._event_view._closing or scene._event_view._request_pending: return false
	if scene._large_map_scrim.visible and scene._large_map_view.activation_coord != Vector2i(-999, -999): return false
	return screen != "combat" or scene._combat_engine.is_player_turn(scene._combat_state)


func _observe_combat(scene: Node) -> void:
	var run: Dictionary = scene._run_state
	if run.is_empty(): return
	var node: Variant = run.get("current_room")
	var room: Dictionary = scene._run_engine.room_metadata(run, node)
	var section: int = int(room.get("section_index", 0))
	var depth: int = int(room.get("depth", 0))
	_highest_depth = maxi(_highest_depth, depth)
	_highest_section = maxi(_highest_section, section)
	if run.get("mode") != "combat" or scene._combat_state.is_empty(): return
	var key: String = "%d:%s" % [section, node]
	if _room != key:
		_room = key
		_combat += 1
		_combat_turn = -1
		_enemy_index = 0
		_kind = _encounter(room, scene._combat_state)
		if _kind in RARE: _rare_seen[_kind] = true
		_write(_run_file, {"seed": _seed, "combat": _combat, "room": str(node), "section": section, "depth": depth,
			"encounter": _kind, "room_type": room.get("type"), "definition": room.get("encounter_id", room.get("special_type", ""))})
		print("FEL30 COMBAT seed=%d combat=%d encounter=%s room=%s" % [_seed, _combat, _kind, key])
	var screen: String = _screens.screen()
	var turn: int = int(scene._combat_state.get("turn", 0))
	if turn == _combat_turn or screen != "combat" or not _dispatchable(scene, screen): return
	_combat_turn = turn
	_enemy_index = 0
	_sample(scene, "player_turn", turn, {})


func _encounter(room: Dictionary, state: Dictionary) -> String:
	if str(room.get("type", "")) == "boss": return "dragon"
	if str(room.get("type", "")) == "guardian": return "Guardian"
	var objective: String = str(state.get("objective", {}).get("type", ""))
	if room.get("special_type") == "warband" or state.get("objective", {}).get("special_type") == "warband": return "Warband"
	if objective not in ["", "eliminate", "kill_all"]: return "objective"
	return "normal"


func _enemy_action(scene: Node, step: Dictionary) -> void:
	if int(step["enemies_before"]) < 4: return
	await RenderingServer.frame_post_draw
	_enemy_index += 1
	_sample(scene, "enemy_action", int(step.get("turn", _combat_turn)), step)


func _sample(scene: Node, kind: String, turn: int, action: Dictionary) -> void:
	_moment += 1
	var state: Dictionary = scene.board_view.combat_state
	var alive: Array[String]
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0: alive.append(str(enemy.get("type", "")))
	var row: Dictionary = {"id": _moment, "seed": _seed, "combat": _combat, "encounter": _kind,
		"turn": turn, "moment": kind, "enemy_action": _enemy_index, "action": action,
		"enemies_alive": alive, "units_alive": alive.size() + int(int(state.get("player", {}).get("hp", 0)) > 0)}
	var key: String = _moment_key(row)
	row["key"] = key
	if _native:
		if _wanted.has(key):
			_capture_frame(scene, key, _wanted[key])
			row["frame"] = _capture.get(key, "")
			_write(_moment_file, row)
		return
	var reach: Array = []
	if kind == "player_turn":
		reach = scene._combat_engine.player_movement_targets(scene._combat_state)
		reach.append(state.get("player", {}).get("pos", Vector2i(-1, -1)))
	var paint: Array[Dictionary] = _paint.collect(scene)
	if _moment == 1:
		var biggest: float = 0.0
		for part: Dictionary in paint: biggest = maxf(biggest, (part["bounds"] as Rect2).get_area())
		print("FEL30 PAINT first frame primitives=%d largest_area=%d" % [paint.size(), int(biggest)])
	var result: Dictionary = _coverage.inspect(paint, reach)
	row.merge(result)
	if int(result["paint_primitives"]) == 0:
		_fail("board submitted no measurable paint at " + key)
		_end_override = "capture error"
		return
	if not result["flags"].is_empty(): _flagged += 1
	for flag: Dictionary in result["flags"]:
		var category: String = flag["category"]
		_categories[category] = int(_categories.get(category, 0)) + 1
	_write(_moment_file, row)


func _load_replay() -> bool:
	var selection: Variant = JSON.parse_string(FileAccess.get_file_as_string(OS.get_environment("FEL30_SELECTION")))
	if not selection is Array or selection.is_empty(): return false
	for row: Dictionary in selection: _wanted[row["key"]] = row
	var file := FileAccess.open(OS.get_environment("FEL30_REPLAY"), FileAccess.READ)
	if file == null: return false
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = JSON.parse_string(line)
		var seed: int = int(row["seed"])
		if not _transcript.has(seed): _transcript[seed] = []
		var source: Array = row["before"]
		if source.size() > 11:
			source[10] = int(source[10])
			source[11] = int(source[11])
		_transcript[seed].append(row)
	return not _transcript.is_empty()


func _replay_input(source: Array) -> Dictionary:
	var sequence: Array = _transcript[_seed]
	if _seed_actions >= sequence.size(): return {}
	var row: Dictionary = sequence[_seed_actions]
	if source != row["before"]: return {}
	return row["input"]


func _moment_key(row: Dictionary) -> String:
	return "%d-%02d-%02d-%s-%02d" % [row["seed"], row["combat"], row["turn"], row["moment"], row["enemy_action"]]


func _capture_frame(scene: Node, key: String, selected: Dictionary) -> void:
	var rank: int = int(selected["rank"])
	var image: Image = _tree.root.get_texture().get_image()
	if image == null or image.get_size() != SIZE:
		_fail("frame has wrong resolution at " + key)
		_end_override = "capture error"
		return
	var filename: String = _output.path_join("%02d-%s.png" % [rank, key])
	if image.save_png(filename) != OK:
		_fail("cannot write " + filename)
		_end_override = "capture error"
		return
	var geometry: Dictionary = _coverage.inspect(_paint.collect(scene), [])
	var drawn: Array[Dictionary]
	for flag: Dictionary in selected["flags"]:
		var projected: Dictionary = flag.duplicate()
		var anchor := Vector2(flag["rect"][0], flag["rect"][1])
		var best: float = INF
		for subject: Dictionary in geometry["subjects"]:
			if subject["kind"] != flag["kind"] or subject["what"] != flag["what"] or subject["actor"] != flag["actor"] or str(subject["tile"]) != str(flag["tile"]): continue
			var distance: float = anchor.distance_squared_to(Vector2(subject["rect"][0], subject["rect"][1]))
			if distance < best:
				best = distance
				projected["rect"] = subject["rect"]
		drawn.append(projected)
	var write := FileAccess.open(filename.get_basename() + ".json", FileAccess.WRITE)
	if write == null:
		_fail("cannot save native annotation geometry at " + key)
		return
	write.store_string(JSON.stringify(drawn))
	_capture[key] = filename
	_wanted.erase(key)
	print(filename)


func _write(file: FileAccess, row: Dictionary) -> void:
	file.store_line(JSON.stringify(row))
	file.flush()


func _fail(message: String) -> void:
	push_error("FEL30: " + message)
	_tree.quit(1)
