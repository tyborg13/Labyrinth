extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-02/base_panels.json"
const OUTPUT_DIR: String = "res://proof/tt-02"
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_SCALE: float = 1.0
const PROOF_SEED: int = 73101
const SETTLE_FRAMES: int = 4
const HOVER_SETTLE_SECONDS: float = 0.5
const FIXTURE := {"room_size": 8, "coord": Vector2i(4, 3), "hero_hp": 24, "hero_pos": Vector2i(2, 4), "enemy_hp": 14, "enemy_pos": Vector2i(4, 4)}
var _tree: SceneTree
var _expect: Callable
var _baseline: Array
var _viewport: SubViewport

func run(tree: SceneTree, expect: Callable, capture: bool = true) -> void:
	_tree = tree
	_expect = expect
	_baseline = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
	if capture and DisplayServer.get_name().to_lower() == "headless":
		_expect.call(false, "Captures require a real windowed renderer")
		return
	Profile.set_storage_path("user://tt02_progression.json")
	Profile.set_run_storage_path("user://tt02_run.save")
	Settings.set_storage_path("user://tt02_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_SCALE
	Settings.apply_settings(settings, tree.root, false)
	tree.root.content_scale_size = PROOF_SIZE
	tree.root.size = PROOF_SIZE
	_viewport = SubViewport.new()
	_viewport.size = PROOF_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	tree.root.add_child(_viewport)
	await _settle()
	var selected: Array = ["royal_bramble", "borrowed_spark", "lantern_shot", "threadbare_guard", "meteorfall", "unsealed_gale", "empty_husk"]
	var results: Array[Dictionary]
	for id: String in selected:
		results.append(await _hover_pair(id, capture))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var result_name: String = "measurements.json" if capture else "measurements_headless.json"
	var file := FileAccess.open(OUTPUT_DIR.path_join(result_name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution": [1920, 1080], "ui_scale": PROOF_SCALE, "renderer": DisplayServer.get_name(), "cards": results}, "\t") + "\n")
	if capture:
		print("TT02_PROOF_DIR=" + ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		print("TT02 HEADLESS LAYOUT ONLY: renderer captures remain pending")
	_viewport.free()
	await _settle()

func _hover_pair(id: String, capture: bool) -> Dictionary:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	var hand: Array = ["quick_stab", id, "guarded_step"]
	var layout: Dictionary = _layout()
	var battle: Dictionary = Combat.new().create_combat(PROOF_SEED, layout, {"hp": FIXTURE["hero_hp"], "max_hp": FIXTURE["hero_hp"], "deck_cards": hand, "hand_size": hand.size(), "relics": []})
	battle["deck"]["hand"] = hand.duplicate()
	for pile: String in ["draw", "discard", "burned"]: battle["deck"][pile] = []
	battle["current_actor"] = {"kind": "player", "key": "player"}
	var state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	state.merge({"mode": "combat", "current_room": layout["coord"], "current_room_layout": layout, "combat_state": battle, "progression": Tutorial.complete_tutorial(Profile.default_data()), "relics": [], "notice": ""}, true)
	scene.call("_load_run_state", state)
	scene.set("_animation_lock", false)
	(scene.get("log_overlay") as Control).hide()
	await _settle()
	var widget: Control = scene.call("_hand_card_control", 1)
	var stack: Control = scene.get("_card_focus_tooltip_stack")
	var result: Dictionary = {"id": id, "name": Data.card_def(id)["name"]}
	for before: bool in [true, false]:
		(scene.get("_card_widget_display_cache") as Dictionary).clear()
		scene.call("_refresh_hand_panel")
		await _settle()
		widget = scene.call("_hand_card_control", 1)
		var motion := InputEventMouseMotion.new()
		motion.position = Stack._visual_global_rect(widget).get_center()
		motion.global_position = motion.position
		_viewport.push_input(motion, true)
		widget.mouse_entered.emit()
		await _tree.create_timer(HOVER_SETTLE_SECONDS).timeout
		if before:
			# The director dump is the exact post-tt01 baseline, including legacy
			# title/body bugs. Render it in the unchanged production stack.
			var baseline_entries: Array[Dictionary]
			for panel: Dictionary in _baseline:
				if panel["card"] == id:
					baseline_entries.append({"icon": panel["icon"], "texture": Icons.icon_texture(panel["icon"]), "title": panel["title"], "description": panel["text"], "tooltip": str(panel["title"]) + "\n" + str(panel["text"])})
			stack.show_for(widget, baseline_entries)
		else:
			scene.call("_show_card_focus_tooltips", 1)
		await _settle()
		var label: String = "before" if before else "after"
		result[label + "_height_px"] = stack.size.y
		result[label + "_panels"] = stack.entry_count()
		result[label + "_icons"] = stack.entry_icon_keys()
		_expect.call(stack.visible, id + " hover exposes the production stack")
		if capture: await _capture(id + "_" + label)
		widget.mouse_exited.emit()
	_expect.call(int(result["after_panels"]) <= int(result["before_panels"]), id + " does not add panels")
	_expect.call(float(result["after_height_px"]) <= float(result["before_height_px"]), id + " stack does not grow")
	if id == "lantern_shot":
		_expect.call((result["after_icons"] as Array).count("time") == 1, "Lantern Shot retains duration despite its shared Time icon")
	print("TT02 STACK %s: %s -> %s px; %s -> %s panels" % [id, result["before_height_px"], result["after_height_px"], result["before_panels"], result["after_panels"]])
	scene.free()
	return result

func _capture(name: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect.call(image != null and image.get_size() == PROOF_SIZE, name + " is native 1920x1080")
	if image != null:
		var path: String = OUTPUT_DIR.path_join(name + ".png")
		_expect.call(image.save_png(path) == OK, "Capture saved: " + name)
		print(ProjectSettings.globalize_path(path))

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await _tree.process_frame

func _layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(int(FIXTURE["room_size"])):
		var row: Array = []
		for x: int in range(int(FIXTURE["room_size"])): row.append("wall" if x == 0 or y == 0 or x == int(FIXTURE["room_size"]) - 1 or y == int(FIXTURE["room_size"]) - 1 else "stone")
		grid.append(row)
	return {"name": "tt-02 proof", "coord": FIXTURE["coord"], "type": "combat", "grid": grid, "player_start": FIXTURE["hero_pos"], "enemies": [{"id": 1, "type": "crawler", "pos": FIXTURE["enemy_pos"], "hp": FIXTURE["enemy_hp"], "max_hp": FIXTURE["enemy_hp"], "block": 0}], "traps": [], "terrain": [], "loot": []}
