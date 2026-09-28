extends SceneTree

## Two production RunScene frames for the finite-Umbra terrain shortcut repair.
## Reuses the focused regression fixture; this is staged UI proof, not combat
## balance evidence or a native pointer-play session.
const Suite = preload("res://tests/suites/move_attack_shortcut_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const OUTPUT: String = "user://probes/visible_terrain_shortcut"
const VISIBLE_SPIRE := Vector2i(3, 4)
const HIDDEN_SPIRE := Vector2i(2, 7)
const SOURCES = ["scripts/run_scene.gd", "scripts/combat_engine.gd", "scripts/combat_board_view.gd", "scripts/board_surface_rules.gd", "scripts/game_data.gd", "data/cards.json", "tests/suites/move_attack_shortcut_suite.gd", "tests/visible_terrain_shortcut_probe.gd"]
var failures: Array[String]
var witnesses: Array[Dictionary]
var canvas: SubViewport
var scene: Node

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	var hashes: Dictionary = _hashes()
	Store.set_storage_path("user://terrain_shortcut_profile.json")
	Store.set_run_storage_path("user://terrain_shortcut_run.save")
	Settings.set_storage_path("user://terrain_shortcut_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://terrain_shortcut_events")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	_expect(Settings.save_settings(settings), "Isolated 100-percent settings save")
	Settings.apply_settings(settings, root, false)
	_expect(Store.save_data(Tutorial.dismiss_tutorial(Store.default_data())), "Isolated tutorial-dismissed profile save")
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	await process_frame
	var combat := Combat.new()
	var state: Dictionary = Suite._visible_terrain_state(combat)
	state["deck"]["hand"] = ["sidestep_slash", "brace"]
	state["deck"]["draw"] = ["brace"]
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	state["current_actor"] = {"kind":"player", "key":"player"}
	state["cards_played_this_turn"] = 0
	state.erase("player_turn_restrictions")
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room_layout"] = Suite._live_combat_layout("heart", Vector2i(3, 3))
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await process_frame
	var preview: Dictionary = scene.call("_card_preview_for_index", 0)
	await scene.call("_begin_card_preview", 0, preview)
	var board: Node = scene.get_node("BoardUnderlay/CombatBoard")
	# Feed the viewport's real pointer position as well as its tile hover. The
	# card tether reads the former and must not point at an uninitialized (0,0).
	var motion := InputEventMouseMotion.new()
	motion.position = board.global_position + (board.call("_tile_center", VISIBLE_SPIRE) as Vector2)
	motion.global_position = motion.position
	canvas.push_input(motion, true)
	scene.call("_on_board_tile_hovered", VISIBLE_SPIRE)
	var offered: Array = (board.get("attack_tiles") as Array).duplicate()
	_expect(combat.effective_umbra_radius(state) == 2, "Finite committed visibility remains active")
	_expect(offered.has(VISIBLE_SPIRE), "Visible spire offered as combined attack target")
	_expect(not offered.has(HIDDEN_SPIRE), "Hidden geometrically reachable spire is not offered")
	_expect(not combat.is_tile_visible_to_player(state, HIDDEN_SPIRE), "Hidden terrain negative witness is outside committed knowledge")
	await _capture("01_visible_spire_offered", {"offered_attack_tiles":offered, "hidden_spire_offered":offered.has(HIDDEN_SPIRE), "visible_spire_hp":4, "player":state["player"]})
	await scene.call("_on_board_tile_clicked", VISIBLE_SPIRE)
	var actual: Dictionary = scene.get("_combat_state")
	var spire_hp: int = 4
	var hidden_hp: int = 0
	for terrain: Dictionary in actual.get("terrain", []):
		if str(terrain.get("id", "")) == "visible_worldspine": spire_hp = int(terrain.get("hp", 4))
		if str(terrain.get("id", "")) == "hidden_worldspine": hidden_hp = int(terrain.get("hp", 0))
	_expect(spire_hp <= 0 and Surface.has_rubble(actual, VISIBLE_SPIRE), "Same one-click destroys the spire and leaves actual Rubble")
	_expect(hidden_hp == 4, "Hidden terrain remains intact")
	_expect(int(scene.get("_selected_card_index")) < 0 and not bool(scene.get("_animation_lock")), "Click completes the card and its animation")
	_expect(int(actual.get("cards_played_this_turn", 0)) == 1 and int(actual.get("player_turn_time_spent", 0)) == 3, "One card and printed Time paid")
	scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	await _capture("02_spire_destroyed", {"spire_hp":spire_hp, "hidden_spire_hp":hidden_hp, "rubble":Surface.has_rubble(actual, VISIBLE_SPIRE), "cards_played":actual.get("cards_played_this_turn", 0), "time_paid":actual.get("player_turn_time_spent", 0)})
	_expect(witnesses.size() == 2, "Exactly two semantic captures")
	_expect(hashes == _hashes(), "Named source inputs unchanged during proof")
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"), FileAccess.WRITE)
	_expect(file != null, "Witness report opens")
	if file != null:
		file.store_string(JSON.stringify(_json({"kind":"staged_visible_terrain_shortcut", "native_play":false, "viewport":[1920,1080], "ui_scale":1.0, "source_sha256":hashes, "witnesses":witnesses, "failures":failures}), "  "))
		file.close()
	print("VISIBLE TERRAIN SHORTCUT PROBE: ", "PASS" if failures.is_empty() else "FAIL", " ", failures)
	canvas.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)

func _capture(name: String, witness: Dictionary) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	_expect(is_equal_approx(float((scene.get("_settings") as Dictionary).get("ui_scale", 0)), 1.0), name + " at 100-percent UI scale")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == Vector2i(1920,1080), name + " at native 1920x1080")
	_expect(image.save_png(OUTPUT.path_join(name + ".png")) == OK, name + " image saved")
	witness["image"] = name + ".png"
	witnesses.append(witness)
	print(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png")))

func _hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCES: result[path] = FileAccess.get_sha256("res://" + path)
	return result

func _json(value: Variant) -> Variant:
	if value is Vector2i or value is Vector2: return [value.x, value.y]
	if value is Dictionary:
		var result: Dictionary = {}
		for key: Variant in value: result[str(key)] = _json(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item: Variant in value: result.append(_json(item))
		return result
	return value

func _expect(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
