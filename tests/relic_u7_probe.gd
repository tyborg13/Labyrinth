extends SceneTree
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixture = preload("res://tests/suites/surface_relic_suite.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/relic_overhaul_u7"
var scene: Node
var canvas: SubViewport
var failed: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	Store.set_storage_path("user://u7_profile.json")
	Store.set_run_storage_path("user://u7_run.save")
	Settings.set_storage_path("user://u7_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var state: Dictionary = _fixture(["black_sun_dial"])
	state["combat_state"]["relic_stored_surfaces"] = ["fire", "ice"]
	await _load(state)
	await scene.call("_on_card_pressed", 0)
	_aim_at_target(Vector2i(4, 3))
	await _settle()
	expect(scene.find_child("RelicStoredSurface_0", true, false) != null and scene.find_child("RelicStoredSurface_1", true, false) != null, "Dial's two stored pips appear in the actual relic bar")
	var first_pip: Control = scene.find_child("RelicStoredSurface_0", true, false) as Control
	var second_pip: Control = scene.find_child("RelicStoredSurface_1", true, false) as Control
	expect(first_pip.size == Vector2(16, 16) and second_pip.size == Vector2(16, 16) and second_pip.position.x - first_pip.position.x == 16.0, "Dial pips use exactly 16x16 and storage order along the badge bottom")
	expect((first_pip.get_parent().get_parent() as Control).tooltip_text.ends_with("Stored: Fire, Ice"), "Dial tooltip lists stored elements in order")
	var attack: Dictionary = Data.card_def_for_progression("pale_spark", state["combat_state"])["actions"][0]
	var source_before: Dictionary = state["combat_state"].duplicate(true)
	var options: Array = scene.call("_action_step_damage_options", state["combat_state"], [attack, attack], [])
	expect(int(options[0]["final_damage"]) == 7 and int(options[1]["final_damage"]) == 3 and state["combat_state"] == source_before, "Sequential card damage display releases Dial once without mutating source state")
	await _capture("black_sun_dial")
	state = _fixture(["fivefold_knot"])
	state["combat_state"]["relic_element_knots"] = ["fire", "ice", "air"]
	await _load(state)
	expect(str((scene.find_child("RelicKnots", true, false) as Label).text) == "3", "Fivefold counter shows three knots")
	expect((scene.find_child("RelicKnots", true, false).get_parent() as Control).tooltip_text.ends_with("Knots: Fire, Ice, Air (3 of 5): attacks Pierce."), "Fivefold tooltip uses the specified three-knot line")
	await _tooltip("fivefold_knot", "fivefold_knot")
	state = _fixture(["unclouded_sun"])
	state["combat_state"]["umbra"]["light_sources"] = [{"pos": Vector2i(2, 3), "radius": 0, "owner": "player", "remaining_activations": 3}, {"pos": Vector2i(6, 4), "radius": 0, "owner": "player", "remaining_activations": 3}]
	await _load(state)
	scene.call("_begin_player_movement_selection")
	_aim_at_target(Vector2i(6, 4))
	await _settle()
	var presentation: Dictionary = (scene.get("board_view") as Node).get("presentation")
	expect((presentation.get("path_tiles", []) as Array).size() == 2, "Actual Sun preview contains the one-step Light jump")
	await _capture("unclouded_sun")
	state = _fixture(["vaulting_sigil"])
	state["combat_state"]["enemies"][0]["pos"] = Vector2i(3, 3)
	await _load(state)
	scene.call("_begin_player_movement_selection")
	_aim_at_target(Vector2i(4, 3))
	await _settle()
	expect(int((scene.call("_turn_order_stagger_preview_delays") as Dictionary).get(1, 0)) == 2, "Independent Move hover also forecasts Vault's Stagger on the rail")
	state = _fixture(["vaulting_sigil"])
	state["combat_state"]["deck"]["hand"] = ["headlong", "brace"]
	state["combat_state"]["enemies"][0]["pos"] = Vector2i(3, 3)
	var second: Dictionary = Base.enemy(2, Vector2i(4, 3))
	second["hp"] = 24
	second["max_hp"] = 24
	state["combat_state"]["enemies"].append(second)
	state["combat_state"]["turn_queue"].append({"kind": "enemy", "enemy_id": 2, "time": 13, "seq": 2})
	await _load(state)
	await scene.call("_on_card_pressed", 0)
	_aim_at_target(Vector2i(5, 3))
	await _settle()
	expect((scene.call("_turn_order_stagger_preview_delays") as Dictionary).size() == 2, "Actual Move hover forecasts Stagger for both enemies on the rail")
	await _capture("vaulting_sigil")
	state = _fixture(["overflow_censer"])
	state["combat_state"]["deck"]["hand"] = ["frost_lane", "brace"]
	Surface.place(state["combat_state"], Vector2i(4, 3), "fire")
	await _load(state)
	await scene.call("_on_card_pressed", 0)
	_aim_at_target(Vector2i(4, 3))
	await _settle()
	await _capture("overflow_censer")
	print("RELIC U7 PROBE TEST RESULT: ", "PASS" if failed == 0 else "FAIL")
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)
func _fixture(ids: Array) -> Dictionary:
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	var state: Dictionary = Run.new().create_new_run(9421, profile)
	state["mode"] = "combat"
	state["pre_battle_pending"] = false
	state["current_room"] = Vector2i(1, 0)
	state["relics"] = ids
	var combat: Dictionary = Fixture.fixture(Combat.new(), ids)
	combat["room_name"] = "Relic Proving Ground"
	combat["player"]["hp"] = 24
	combat["player"]["max_hp"] = 24
	combat["enemies"][0]["hp"] = 24
	combat["enemies"][0]["max_hp"] = 24
	combat["deck"]["hand"] = ["pale_spark", "brace", "frostbolt"]
	state["rooms"]["1,0"]["type"] = "combat"
	state["current_room_layout"] = {"name": "Relic Proving Ground", "type": "combat", "grid": combat["grid"], "npcs": [], "exits": []}
	state["combat_state"] = combat
	return state
func _hand_card(id: String) -> Node:
	for child: Node in (scene.get("hand_box") as Node).get_children():
		var card: Node = scene.call("_card_widget_descendant",child)
		if card != null and str(card.get("card_id")) == id: return card
	return null
func _tooltip(id: String,label: String) -> void:
	for badge: Control in (scene.get("_relic_icon_grid") as Node).get_children():
		if str(badge.get_meta("relic_id","")) != id: continue
		var tip: Control = badge.call("_make_custom_tooltip",badge.tooltip_text)
		var overlay := CanvasLayer.new()
		overlay.layer = 100
		scene.add_child(overlay)
		overlay.add_child(tip)
		tip.position = Vector2(620,120)
		await _capture(label)
		expect(Rect2(Vector2.ZERO,Vector2(1920,1080)).encloses(tip.get_global_rect()),"Rules tooltip is entirely on-screen")
		overlay.queue_free()
		await process_frame
func _aim_at_target(target: Vector2i) -> void:
	var board: Control = scene.get("board_view")
	var point: Vector2 = board.global_position + (board.call("_tile_center",target) as Vector2)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	canvas.push_input(motion,true)
	scene.call("_on_board_tile_hovered",target)
func _load(state: Dictionary) -> void:
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression",state["progression"])
	scene.call("_load_run_state",state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await _settle()
func _settle() -> void:
	for i: int in range(4): await process_frame
func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	expect(image.get_size() == Vector2i(1920,1080),"Native 1920x1080 proof")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT,label]
	expect(image.save_png(path)==OK,"PNG saved")
	print(ProjectSettings.globalize_path(path))
func expect(ok: bool,message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
