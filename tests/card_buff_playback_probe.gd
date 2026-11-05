extends SceneTree

## Native input -> committed card -> production popup timeline, in one fight.
## tests/card_buff_movie_godot.sh adds the engine's built-in AVI writer.
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const OUTPUT_DIR: String = "user://probes/card_buff_playback"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)
const UI_SCALE: float = 1.0
const FIXTURE_SEED: int = 9811
const FIXTURE_ROOM_WIDTH: int = 8
const FIXTURE_HERO_TILE: Vector2i = Vector2i(2, 4)
const FIXTURE_FOE_TILE: Vector2i = Vector2i(5, 4)
const FIXTURE_HEALTH: int = 30
const SETTLE_FRAMES: int = 8
const PLAYBACK_TIMEOUT_SECONDS: float = 20.0
const CAPTURE_MIN_PROGRESS: float = 0.15
const CAPTURE_MAX_PROGRESS: float = 0.60
const CASES: Array = [
	{"card": "whetstone", "icon": "next_attack", "text": "+4", "color": Color("ffb08a")},
	{"card": "undertaker_stand", "icon": "retaliate", "text": "+5", "color": Color("f0c27a")},
	{"card": "hourglass_sand", "icon": "quicken", "text": "+4", "color": Color("a8e4ff")},
]

var _failures: Array[String]
var _captures: Array[Dictionary]
var _viewport: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	Progression.set_storage_path("user://fx01_progression.json")
	Progression.set_run_storage_path("user://fx01_run.save")
	Settings.set_storage_path("user://fx01_settings.json")
	Progression.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = UI_SCALE
	settings["reduced_motion"] = false
	settings["combat_speed"] = Settings.COMBAT_NORMAL
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	# A fixed render viewport keeps both proof geometry and captures independent
	# of desktop window bounds and the headless display's dummy window size.
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.msaa_2d = root.msaa_2d
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var display := TextureRect.new()
	display.texture = _viewport.get_texture()
	display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	display.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(display)
	display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	scene.call("_close_dialogue")
	scene.set("_settings", settings.duplicate(true))
	_install_fight(scene)
	await _settle()
	if OS.get_cmdline_user_args().has("--fixture-only"):
		await _check_fixture(scene)
		scene.queue_free()
		await _settle()
		for failure: String in _failures: push_error(failure)
		print("CARD BUFF FIXTURE: %s (%d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _failures.size()])
		quit(0 if _failures.is_empty() else 1)
		return
	for case: Dictionary in CASES:
		await _play_and_capture(scene, case)
	var manifest := FileAccess.open(OUTPUT_DIR.path_join("captures.json"), FileAccess.WRITE)
	_expect(manifest != null, "Capture manifest opens")
	if manifest != null:
		manifest.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": UI_SCALE, "captures": _captures, "errors": _failures}, "\t"))
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	for failure: String in _failures: push_error(failure)
	print("CARD BUFF PLAYBACK PROBE: %s (%d captures, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _captures.size(), _failures.size()])
	scene.queue_free()
	await process_frame
	quit(0 if _failures.is_empty() else 1)

func _check_fixture(scene: Control) -> void:
	var snapshot: Dictionary = scene.get("_combat_state").duplicate(true)
	_expect(not (snapshot.get("enemies", []) as Array).is_empty(), "Proof uses a real encounter")
	_expect(scene.get_viewport_rect().size == Vector2(VIEWPORT_SIZE), "Proof viewport is 1920x1080")
	_expect(scene.get("_settings")["ui_scale"] == UI_SCALE, "Proof UI scale is 100%")
	for case: Dictionary in CASES:
		var index: int = (snapshot["deck"]["hand"] as Array).find(case["card"])
		scene.call("_on_card_pressed", index)
		await process_frame
		_expect_armed(scene, index, str(case["card"]))
		scene.call("_reset_card_resolution")
	_expect(scene.get("_combat_state") == snapshot, "Fixture selection preserves combat, saves and RNG")

func _expect_armed(scene: Control, index: int, card_id: String) -> void:
	_expect(index >= 0 and int(scene.get("_selected_card_index")) == index, card_id + " arms through normal card input")
	_expect(int(scene.get("_pending_action_index")) >= (scene.get("_pending_actions") as Array).size(), card_id + " reaches targetless hero confirmation")

func _play_and_capture(scene: Control, case: Dictionary) -> void:
	var hand: Array = scene.get("_combat_state")["deck"]["hand"]
	var index: int = hand.find(case["card"])
	_expect(index >= 0, case["card"] + " is in the live hand")
	if index < 0: return
	scene.call("_on_card_pressed", index)
	await process_frame
	_expect(int(scene.get("_selected_card_index")) == index, case["card"] + " arms through normal card input")
	scene.call("_on_board_tile_clicked", scene.get("_combat_state")["player"]["pos"])
	var captured: bool = false
	var started: int = Time.get_ticks_msec()
	while float(Time.get_ticks_msec() - started) / 1000.0 < PLAYBACK_TIMEOUT_SECONDS:
		await RenderingServer.frame_post_draw
		var board: Control = scene.get("board_view")
		var matching: Array = (board.get("presentation").get("floating_texts", []) as Array).filter(func(entry: Dictionary) -> bool: return str(entry.get("icon", "")) == case["icon"])
		if not captured and not matching.is_empty():
			var entry: Dictionary = matching[0]
			var progress: float = float(entry.get("animation_progress", -1.0))
			if progress >= CAPTURE_MIN_PROGRESS and progress <= CAPTURE_MAX_PROGRESS:
				_expect(matching.size() == 1, case["card"] + " renders exactly one keyword float")
				_expect(entry.get("text") == case["text"] and entry.get("color") == case["color"], case["card"] + " renders the specified text and keyword colour")
				_expect(entry.get("tile") == scene.get("_combat_state")["player"]["pos"], case["card"] + " anchors on the live hero")
				var image: Image = _viewport.get_texture().get_image()
				_expect(image.get_size() == VIEWPORT_SIZE, "Native capture is 1920x1080 at 100% UI scale")
				var path: String = OUTPUT_DIR.path_join(str(case["card"]) + ".png")
				_expect(image.save_png(path) == OK, "Native capture saves: " + path)
				_captures.append({"path": ProjectSettings.globalize_path(path), "card": case["card"], "text": entry["text"], "icon": entry["icon"], "color": (entry["color"] as Color).to_html(), "progress": progress, "tile": str(entry["tile"])})
				captured = true
		if not bool(scene.get("_animation_lock")) and int(scene.get("_selected_card_index")) < 0: break
	_expect(captured, case["card"] + " shows its float during actual card playback")
	_expect(not bool(scene.get("_animation_lock")), case["card"] + " completes within the proof deadline")
	var resolved_deck: Dictionary = scene.get("_combat_state")["deck"]
	_expect(not (resolved_deck["hand"] as Array).has(case["card"]) and ((resolved_deck["burned"] as Array).has(case["card"]) or (resolved_deck["discard"] as Array).has(case["card"])), case["card"] + " commits to its real pile")
	await _settle()

func _install_fight(scene: Control) -> void:
	var grid: Array
	for y: int in range(FIXTURE_ROOM_WIDTH):
		var row: Array
		for x: int in range(FIXTURE_ROOM_WIDTH): row.append("wall" if x == 0 or y == 0 or x == FIXTURE_ROOM_WIDTH - 1 or y == FIXTURE_ROOM_WIDTH - 1 else "stone")
		grid.append(row)
	var enemy: Dictionary = preload("res://scripts/game_data.gd").enemy_def("crawler")
	var room: Dictionary = {"name": "Cinder Crossing", "coord": Vector2i.ZERO, "type": "combat", "grid": grid, "player_start": FIXTURE_HERO_TILE,
		"enemies": [{"id": 1, "type": "crawler", "pos": FIXTURE_FOE_TILE, "hp": enemy["max_hp"], "max_hp": enemy["max_hp"], "block": 0}], "terrain": [], "traps": [], "loot": []}
	var cards: Array[String]
	for case: Dictionary in CASES: cards.append(str(case["card"]))
	var combat: Dictionary = Combat.new().create_combat(FIXTURE_SEED, room, {"hp": FIXTURE_HEALTH, "max_hp": FIXTURE_HEALTH, "deck_cards": cards, "relics": [], "hand_size": cards.size()})
	combat["deck"]["hand"] = cards.duplicate()
	combat["deck"]["draw"] = ["quick_stab"]
	combat["deck"]["discard"] = []
	combat["deck"]["burned"] = []
	# Proof-only extra plays allow the three production cards in one encounter.
	combat["card_play_bonus_this_turn"] = CASES.size()
	combat["current_actor"] = {"kind": "player", "key": "player"}
	var run: Dictionary = scene.get("_run_state").duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["combat_state"] = combat
	scene.set("_run_state", run)
	scene.set("_combat_state", combat)
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition: _failures.append(message)
