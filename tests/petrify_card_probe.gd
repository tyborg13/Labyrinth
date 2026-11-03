extends SceneTree

## Director proof of the production Petrify card in hand and its focus stack.
## --check-only validates the fixture and semantics without capturing a renderer.
const Combat = preload("res://scripts/combat_engine.gd")
const CardWidget = preload("res://scripts/card_widget.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const CaptureViewport = preload("res://tests/helpers/ui03_capture_viewport.gd")
const RUN_SCENE = preload("res://scenes/run_scene.tscn")
const OUTPUT: String = "user://petrify_card_probe"
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const PROOF_SEED: int = 20261022
const SETTLE_FRAMES: int = 8
const FOCUSED_INDEX: int = 2
const HAND: Array = ["quick_stab", "guarded_step", "petrify", "rallying_breath", "quick_stab"]
const EXPECTED_TOOLTIP: String = "Petrify\nThe enemy turns to stone: it skips its next turn (the skipped turn still costs its Time) and gains 5 Block, which lasts through your next turn. Dragons are immune."

var _failed: bool = false
var _check_only: bool = false
var _proof_viewport: SubViewport

func _initialize() -> void:
	Parallel.apply_from_environment()
	_check_only = OS.get_cmdline_user_args().has("--check-only")
	if DisplayServer.get_name() == "headless" and not _check_only:
		push_error("PETRIFY CARD PROBE requires a real renderer; use --check-only for headless contract validation")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://petrify_card_settings.json")
	Store.set_storage_path("user://petrify_card_profile.json")
	Store.set_run_storage_path("user://petrify_card_run.save")
	Store.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = PROOF_SIZE
	root.size = PROOF_SIZE
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	var profile: Dictionary = Store.default_data()
	var tutorial_states: Dictionary = {}
	for prompt_id: String in Tutorial.prompt_ids():
		tutorial_states[prompt_id] = Tutorial.STATUS_COMPLETED
	profile[Tutorial.PROGRESSION_KEY] = tutorial_states
	Store.save_data(profile)
	var capture = CaptureViewport.new()
	root.add_child(capture)
	capture.setup(root)
	_proof_viewport = capture.viewport
	var scene: Control = RUN_SCENE.instantiate()
	_proof_viewport.add_child(scene)
	await _settle()
	_expect(_proof_viewport.size == PROOF_SIZE and scene.get_viewport_rect().size == Vector2(PROOF_SIZE), "The scene renders inside the fixed 1920x1080 proof viewport")
	var room: Dictionary = _room()
	var combat: Dictionary = Combat.new().create_combat(PROOF_SEED, room, {"hp": 24, "max_hp": 24, "deck_cards": HAND.duplicate(), "hand_size": HAND.size(), "relics": []})
	combat["deck"]["hand"] = HAND.duplicate()
	combat["deck"]["draw"] = []
	combat["current_actor"] = {"kind": "player", "key": "player"}
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room["coord"]
	run["current_room_layout"] = room
	run["combat_state"] = combat
	run["progression"] = profile
	run["notice"] = ""
	scene.call("_load_run_state", run)
	scene.set("_animation_lock", false)
	scene.get("log_overlay").visible = false
	await _settle()
	_expect(is_equal_approx(Typography.ui_scale(scene), PROOF_UI_SCALE), "UI scale is 100%")
	var hand: Control = scene.get("hand_box") as Control
	_expect(hand.get_child_count() == HAND.size(), "The production hand contains the complete fixture")
	if hand.get_child_count() == HAND.size():
		var widget: CardWidget = hand.get_child(FOCUSED_INDEX).find_child("CardWidget", true, false) as CardWidget
		_expect(widget != null, "The Petrify card uses the production CardWidget")
		if widget != null:
			widget.mouse_entered.emit()
			await _settle()
			_assert_stack(scene, "pointer")
			await _capture("01_petrify_pointer_focus")
			widget.mouse_exited.emit()
			scene.set("_controller_region", "hand")
			scene.call("_controller_set_hand_focused", true)
			scene.call("_controller_set_hand_index", FOCUSED_INDEX)
			await _settle()
			_expect(int(scene.get("_controller_hand_index")) == FOCUSED_INDEX, "Petrify retains keyboard/controller hand focus")
			_assert_stack(scene, "keyboard/controller")
			await _capture("02_petrify_keyboard_focus")
	scene.queue_free()
	await process_frame
	capture.close()
	capture.queue_free()
	await process_frame
	_proof_viewport = null
	print("PETRIFY CARD PROBE %s: %s (Petrify in hand, pointer + keyboard/controller focus, 1920x1080, UI scale 100%%)" % ["CONTRACT" if _check_only else "RENDER", "FAIL" if _failed else "PASS"])
	print("PETRIFY CARD PROOF DIR: " + ProjectSettings.globalize_path(OUTPUT))
	quit(1 if _failed else 0)

func _assert_stack(scene: Control, label: String) -> void:
	var stack: Control = scene.get("_card_focus_tooltip_stack") as Control
	_expect(stack != null and stack.visible, label + " displays the focus tooltip stack")
	if stack == null:
		return
	_expect(stack.call("entry_icon_keys") == ["petrify", "range"], label + " has one Petrify entry, with Range only")
	for entry: Dictionary in stack.get("_entries"):
		if entry.get("icon") == "petrify":
			_expect("%s\n%s" % [entry.get("title", ""), entry.get("description", "")] == EXPECTED_TOOLTIP, label + " has the exact Petrify tooltip")
	_expect(Rect2(Vector2.ZERO, Vector2(PROOF_SIZE)).encloses(stack.get_global_rect()), label + " keeps the entire tooltip stack on screen")

func _room() -> Dictionary:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return {"name": "Petrify proof", "coord": Vector2i(4, 3), "type": "combat", "grid": grid, "player_start": Vector2i(2, 4), "enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(4, 4), "hp": 14, "max_hp": 14, "block": 0}], "traps": [], "terrain": [], "loot": []}

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES):
		await process_frame

func _capture(label: String) -> void:
	if _check_only:
		return
	await RenderingServer.frame_post_draw
	var capture: Image = _proof_viewport.get_texture().get_image()
	_expect(capture != null and capture.get_size() == PROOF_SIZE, label + " has native 1920x1080 dimensions")
	if capture == null:
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	_expect(capture.save_png(path) == OK, label + " saves")
	print("PETRIFY CARD CAPTURE: " + ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failed = true
		push_error("PETRIFY CARD PROBE: " + message)
