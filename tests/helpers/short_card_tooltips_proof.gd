extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Stack = preload("res://scripts/card_focus_tooltip_stack.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Profile = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const BoonInspection = preload("res://scripts/opening_boon_inspection.gd")
const COPY_PATH: String = "res://spec/peer_benchmark/staged/tt-01/tooltips.json"
const OUTPUT_DIR: String = "res://proof/tt-01"
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_SCALE: float = 1.0
const PROOF_SEED: int = 73101
const SCAN_OWNER_POSITION := Vector2(700, 320)
const SCAN_OWNER_SIZE := Vector2(250, 352)
const SETTLE_FRAMES: int = 4
const HOVER_SETTLE_SECONDS: float = 0.5
const FIXTURE := {"room_size": 8, "coord": Vector2i(4, 3), "hero_hp": 24, "hero_pos": Vector2i(2, 4), "enemy_hp": 14, "enemy_pos": Vector2i(4, 4)}
var _tree: SceneTree
var _expect: Callable
var _copy: Dictionary
var _viewport: SubViewport

func run(tree: SceneTree, expect: Callable, capture: bool) -> void:
	_tree = tree
	_expect = expect
	_copy = JSON.parse_string(FileAccess.get_file_as_string(COPY_PATH))
	# Retired identities (including dormant Flurry) and new shared copy are outside the tt-01 comparison.
	_copy["entries"] = (_copy["entries"] as Array).filter(func(entry: Dictionary) -> bool: return entry["id"] not in ["mirror", "retaliate", "flurry", "aoe"])
	if capture and DisplayServer.get_name().to_lower() == "headless":
		_expect.call(false, "Captures require a real windowed renderer")
		return
	Profile.set_storage_path("user://tt01_progression.json")
	Profile.set_run_storage_path("user://tt01_run.save")
	Settings.set_storage_path("user://tt01_settings.json")
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
	var ranked: Array[Dictionary] = await _rank_baseline()
	var selected: Array[String]
	selected.append("lantern_shot")
	for entry: Dictionary in ranked:
		if str(entry["id"]) != "lantern_shot":
			selected.append(str(entry["id"]))
		if selected.size() == 3: break
	print("TT01 TALLEST BASELINE CARDS: %s (%s px), %s (%s px)" % [ranked[0]["id"], ranked[0]["height_px"], ranked[1]["id"], ranked[1]["height_px"]])
	var results: Array[Dictionary]
	for id: String in selected:
		results.append(await _hover_pair(id, capture))
	_test_boon_inspection()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var result_name: String = "measurements.json" if capture else "measurements_headless.json"
	var file := FileAccess.open(OUTPUT_DIR.path_join(result_name), FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution": [1920, 1080], "ui_scale": PROOF_SCALE, "renderer": DisplayServer.get_name(), "baseline_ranking": ranked, "cards": results}, "\t") + "\n")
	if capture:
		print("TT01_PROOF_DIR=" + ProjectSettings.globalize_path(OUTPUT_DIR))
	else:
		print("TT01 HEADLESS LAYOUT ONLY: renderer captures remain pending")
	_viewport.free()
	await _settle()

func _set_copy(before: bool) -> void:
	Glossary.all_entries()
	for change: Dictionary in _copy["entries"]:
		if str(change["id"]) in ["dive", "veil", "lob", "icefall", "burrow", "erupt"]: continue # sta-01/mrk-01 retired identities.
		Glossary._entries[str(change["id"])]["definition"] = change["old"] if before else change["tooltip"]
	if not before:
		var tt02: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://spec/peer_benchmark/staged/tt-02/card_panels.json"))
		for edit: Dictionary in tt02["glossary_edits"]:
			if edit["id"] == "retaliate": continue
			Glossary._entries[str(edit["id"])]["definition"] = edit["text"]

func _rank_baseline() -> Array[Dictionary]:
	_set_copy(true)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	var battle: Dictionary = Combat.new().create_combat(PROOF_SEED, _layout(), {"hp": FIXTURE["hero_hp"], "max_hp": FIXTURE["hero_hp"], "deck_cards": ["quick_stab"], "hand_size": 1, "relics": []})
	var owner := Control.new()
	owner.position = SCAN_OWNER_POSITION
	owner.size = SCAN_OWNER_SIZE
	_viewport.add_child(owner)
	var stack := Stack.new()
	_viewport.add_child(stack)
	var ranking: Array[Dictionary]
	for id: String in Data.cards():
		var card: Dictionary = scene.call("_card_def", id, battle)
		var display: Dictionary = scene.call("_card_widget_display", id, battle)
		var leading: Array = []
		if int(card.get("time", 0)) > 0: leading.append("time")
		if Icons.card_is_rite(card): leading.append("rite")
		stack.show_for(owner, Icons.tooltip_entries_for_rows(display["summary_rows"], leading))
		await _settle()
		ranking.append({"id": id, "height_px": stack.size.y, "panels": stack.entry_count()})
	ranking.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["height_px"]) > float(b["height_px"]) if a["height_px"] != b["height_px"] else str(a["id"]) < str(b["id"]))
	stack.free()
	owner.free()
	scene.free()
	_set_copy(false)
	return ranking

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
		_set_copy(before)
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
			# Reconstruct only the removed leading panel; all old definitions come
			# from protected director data, using the unchanged production layout.
			var card: Dictionary = scene.call("_card_def", id, scene.get("_combat_state"))
			var display: Dictionary = scene.call("_card_widget_display_for_index", 1)
			var leading: Array = []
			if int(card.get("time", 0)) > 0: leading.append("time")
			if Icons.card_is_rite(card): leading.append("rite")
			stack.show_for(widget, Icons.tooltip_entries_for_rows(display["summary_rows"], leading))
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
	_expect.call(int(result["after_panels"]) == int(result["before_panels"]) - 1, id + " loses only the automatic Time panel")
	_expect.call(float(result["after_height_px"]) < float(result["before_height_px"]), id + " has a shorter stack")
	if id == "lantern_shot":
		_expect.call((result["after_icons"] as Array).count("time") == 1, "Lantern Shot retains duration despite its shared Time icon")
	print("TT01 STACK %s: %s -> %s px; %s -> %s panels" % [id, result["before_height_px"], result["after_height_px"], result["before_panels"], result["after_panels"]])
	scene.free()
	_set_copy(false)
	return result

func _test_boon_inspection() -> void:
	var owner: Control = preload("res://scenes/card_widget.tscn").instantiate()
	owner.configure("lantern_shot")
	var stack := Stack.new()
	_viewport.add_child(owner)
	_viewport.add_child(stack)
	var inspection := BoonInspection.new()
	inspection.configure(stack)
	inspection.bind_card(owner)
	inspection._show(owner)
	_expect.call(not stack._entries.any(func(e: Dictionary) -> bool: return e["title"] == "Time"), "Opening-boon card inspection omits automatic Time")
	inspection.clear()
	owner.free()
	stack.free()

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
	return {"name": "tt-01 proof", "coord": FIXTURE["coord"], "type": "combat", "grid": grid, "player_start": FIXTURE["hero_pos"], "enemies": [{"id": 1, "type": "crawler", "pos": FIXTURE["enemy_pos"], "hp": FIXTURE["enemy_hp"], "max_hp": FIXTURE["enemy_hp"], "block": 0}], "traps": [], "terrain": [], "loot": []}
