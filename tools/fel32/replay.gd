extends SceneTree
## Replay the fel-30 input witnesses through the live combat scene in either build.

const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Events = preload("res://scripts/recent_event_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Inputs = preload("res://tools/fel30/input_driver.gd")
const Screens = preload("res://tools/fel30/screens.gd")
const Observe = preload("observe.gd")
const SamplePixels = preload("sample_pixels.gd")
const Threats = preload("res://scripts/threat_tiles.gd")

const SIZE := Vector2i(1920, 1080)
const SEED := 30002
const STONE_COMBAT := 1
const FIRE_COMBAT := 4
const FIRE_TURN := 3
const FPS := 60
const HEADLESS_SPEED := 4.0
const INPUT_SETTLE_FRAMES := 3
const INPUT_TIMEOUT_MS := 120000
const HEADLESS_LOADING_TIMEOUT_MS := 300000
const LOADING_SCREENS := ["boot", "loading", "title_boot", "between_scenes"]

var _inputs: Inputs
var _screens: Screens
var _output: String
var _headless: bool
var _combat: int
var _room: String
var _turn: int = -1
var _captures: Dictionary
var _moments: Array[Dictionary]


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		_fail("expected the fel-30 transcript and a fresh output directory")
		return
	var rows: Array[Dictionary] = _load_transcript(args[0])
	_output = args[1]
	if rows.is_empty() or DirAccess.make_dir_recursive_absolute(_output) != OK or not _profile():
		_fail("cannot read replay inputs or prepare an isolated profile")
		return
	Runtime.apply_from_environment()
	_headless = DisplayServer.get_name() == "headless"
	if _headless: Engine.time_scale = HEADLESS_SPEED
	Engine.max_fps = FPS
	OS.low_processor_usage_mode = false
	root.title = "Escape the Umbra"
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = SIZE
	root.size = SIZE
	root.set_meta("labyrinth_performance_probe_seed", SEED)
	_inputs = Inputs.new(root)
	_screens = Screens.new(self, _inputs)
	if change_scene_to_file("res://scenes/main_menu.tscn") != OK:
		_fail("cannot load the title")
		return
	var index: int = 0
	var last_progress: int = Time.get_ticks_msec()
	var last_screen: String
	while index < rows.size():
		await _draw_frame()
		var scene: Node = _screens.run_scene()
		var screen: String = _screens.screen()
		if screen != last_screen:
			last_screen = screen
			last_progress = Time.get_ticks_msec()
		var timeout: int = HEADLESS_LOADING_TIMEOUT_MS if _headless and screen in LOADING_SCREENS else INPUT_TIMEOUT_MS
		if Time.get_ticks_msec() - last_progress > timeout:
			_fail("input %d stalled at %s, expected %s" % [index, _screens.witness(), rows[index]["before"]])
			return
		if not _dispatchable(scene, screen): continue
		if screen == "recap": break
		if screen == "combat":
			if not await _observe(scene): return
		if not _headless and _captures.size() == 3: break
		var row: Dictionary = rows[index]
		if row["before"] == _screens.witness():
			var input: Dictionary = row["input"]
			_inputs.prepare(input)
			for frame: int in INPUT_SETTLE_FRAMES: await _draw_frame()
			input = _inputs.resolve(current_scene, input)
			if not input.is_empty():
				_inputs.prepare(input)
				_inputs.send(input)
				index += 1
				last_progress = Time.get_ticks_msec()
	if _headless:
		if index != rows.size() or _combat != FIRE_COMBAT or not _write_json("moments", _moments):
			_fail("missing replay combat or moment output")
			return
		print("FEL32 REPLAY seed=%d inputs=%d moments=%d" % [SEED, index, _moments.size()])
	elif _captures.size() != 3:
		_fail("missing capture cases: %s" % str(_captures.keys()))
		return
	quit()


func _draw_frame() -> void:
	if _headless:
		await process_frame
		RenderingServer.frame_pre_draw.emit()
		RenderingServer.frame_post_draw.emit()
	else:
		await RenderingServer.frame_post_draw


func _profile() -> bool:
	var folder: String = _output.path_join("profile")
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


func _load_transcript(path: String) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null: return result
	while not file.eof_reached():
		var line: String = file.get_line()
		if line.is_empty(): continue
		var row: Dictionary = JSON.parse_string(line)
		if int(row["seed"]) != SEED: continue
		var witness: Array = row["before"]
		if witness.size() > 11:
			witness[10] = int(witness[10])
			witness[11] = int(witness[11])
		result.append(row)
	return result


func _dispatchable(scene: Node, screen: String) -> bool:
	if not is_instance_valid(current_scene) or root.gui_disable_input: return false
	if screen in LOADING_SCREENS: return false
	if scene == null: return true
	if scene._animation_lock or is_instance_valid(scene._section_transition) or scene._treasure_presentation_busy(): return false
	if is_instance_valid(scene._event_view) and scene._event_view.visible:
		if scene._event_view._busy or scene._event_view._closing or scene._event_view._request_pending: return false
	if scene._large_map_scrim.visible and scene._large_map_view.activation_coord != Vector2i(-999, -999): return false
	return screen != "combat" or scene._combat_engine.is_player_turn(scene._combat_state)


func _observe(scene: Node) -> bool:
	var room: String = str(scene._run_state["current_room"])
	if room != _room:
		_room = room
		_combat += 1
		_turn = -1
		print("FEL32 COMBAT seed=%d combat=%d room=%s" % [SEED, _combat, _room])
	if _combat not in [STONE_COMBAT, FIRE_COMBAT]: return true
	var turn: int = int(scene._combat_state["turn"])
	if turn == _turn: return true
	_turn = turn
	if _headless: await _draw_frame()
	var row: Dictionary = Observe.moment(scene.board_view, _headless)
	row["combat"] = _combat
	row["turn"] = _turn
	if _headless:
		for tile: Dictionary in row["tiles"]:
			if tile["strokes"].is_empty():
				_fail("no CanvasItem submission at combat=%d turn=%d tile=%s" % [_combat, _turn, tile["tile"]])
				return false
		_moments.append(row)
		return true
	if _combat == FIRE_COMBAT and turn == FIRE_TURN and not _capture("fire", row): return false
	if _combat == STONE_COMBAT and not _captures.has("stone") and _has_stone_threat(row) and not _capture("stone", row): return false
	if _combat == FIRE_COMBAT and turn != FIRE_TURN and row["hero_threatened"] and not _captures.has("hero") and not _capture("hero", row): return false
	return true


func _has_stone_threat(row: Dictionary) -> bool:
	for tile: Dictionary in row["tiles"]:
		if tile["surface"].is_empty() and not tile["rubble"]: return true
	return false


func _capture(label: String, row: Dictionary) -> bool:
	var image: Image = root.get_texture().get_image()
	var filename: String = _output.path_join(label + ".png")
	if image == null or image.get_size() != SIZE or not SamplePixels.has_red_core(image, row["tiles"], Threats.OUTLINE_COLOR, Threats.OUTLINE_ALPHA):
		_fail("cannot capture a 1920x1080 frame with telegraphed tiles for " + label)
		return false
	if image.save_png(filename) != OK or not _write_json(label, row):
		_fail("cannot write " + filename)
		return false
	_captures[label] = true
	print(filename)
	return true


func _write_json(stem: String, data: Variant) -> bool:
	var file := FileAccess.open(_output.path_join(stem + ".json"), FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(data))
	return true


func _fail(message: String) -> void:
	push_error("FEL32 REPLAY: " + message)
	quit(1)
