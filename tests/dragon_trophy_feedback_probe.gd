extends SceneTree
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/dragon_trophy_rules.gd")
const Fixture = preload("res://tests/suites/surface_relic_suite.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/dragon_trophy_feedback_v3"
var scene: Node
var canvas: SubViewport
var failed: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	Store.set_storage_path("user://trophy_profile.json")
	Store.set_run_storage_path("user://trophy_run.save")
	Settings.set_storage_path("user://trophy_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var combat := Combat.new()
	var engine := Run.new()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION,"status":"dismissed","completed_steps":[]}
	var run_state: Dictionary = engine.create_new_run(9421,profile)
	run_state["mode"] = "combat"
	run_state["pre_battle_pending"] = false
	run_state["current_room"] = Vector2i(1,0)
	run_state["relics"] = ["winters_hour","stormroad_coil"]
	var state: Dictionary = Fixture.fixture(combat,run_state["relics"])
	state["room_name"] = "Trophy Proving Ground"
	run_state["rooms"]["1,0"]["type"] = "combat"
	run_state["current_room_layout"] = {"name":"Trophy Proving Ground","type":"combat","grid":state["grid"],"npcs":[],"exits":[]}
	state["player"]["hp"] = Data.fixed_point_amount(20)
	state["player"]["max_hp"] = Data.fixed_point_amount(24)
	state["enemies"][0]["pos"] = Vector2i(6,3)
	state["enemies"][0]["hp"] = Data.fixed_point_amount(12)
	state["enemies"][0]["max_hp"] = Data.fixed_point_amount(12)
	state["deck"]["hand"] = ["frostbolt","pale_spark","brace","quick_stab"]
	Surface.place(state,Vector2i(4,3),"electrified")
	run_state["combat_state"] = state
	await _load(run_state)
	await _capture("hourglass_empty")
	expect(_counter() == "0", "Persistent relic counter begins at zero")
	await scene.call("_on_card_pressed",0)
	await scene.call("_on_board_tile_clicked",Vector2i(6,3))
	if bool(scene.call("_pending_card_requires_confirmation")): await scene.call("_on_confirm_card_play_pressed")
	await _settle()
	state = scene.get("_combat_state")
	expect(Rules.reserve(state,"winters_hour") == 3 and _counter() == "3", "Actual Ice play updates reserve and visible counter")
	var pale: Node = _hand_card("pale_spark")
	expect(pale != null and int((pale.call("_display_card_def") as Dictionary).get("time",0)) == 1,"Hand cache immediately displays exact discounted Time")
	await _capture("hourglass_banked_exact_costs")
	await _tooltip("winters_hour","hourglass_rules")
	await _tooltip("stormroad_coil","coil_rules")
	await scene.call("_on_card_pressed",0)
	_aim_at_target()
	await _settle()
	var arcs: Array = ((scene.get("board_view") as Node).get("presentation") as Dictionary).get("surface_preview_arcs",[])
	expect(arcs.size() >= 2,"Actual targeting preview displays both relay legs")
	await _capture("coil_target_preview")
	scene.call("_on_board_tile_clicked",Vector2i(6,3))
	await process_frame
	if bool(scene.call("_pending_card_requires_confirmation")): scene.call("_on_confirm_card_play_pressed")
	await _capture_leg(Vector2i(2,3),Vector2i(4,3),"coil_first_leg")
	await _capture_leg(Vector2i(4,3),Vector2i(6,3),"coil_second_leg")
	await _wait_idle()
	await _capture("hourglass_spent_relay_settled")
	expect(Rules.reserve(scene.get("_combat_state"),"winters_hour") == 1,"One actual Pale Spark spends exactly two stored Time")
	# Same normal card/target path with reduced motion, without another input step.
	settings["reduced_motion"] = true
	Settings.apply_settings(settings,root,false)
	scene.set("_settings",settings)
	state = run_state["combat_state"]
	state["deck"]["hand"] = ["pale_spark","brace"]
	state["relic_time_reserve"] = {"winters_hour":3}
	await _load(run_state)
	await scene.call("_on_card_pressed",0)
	_aim_at_target()
	await _capture("coil_reduced_motion_preview")
	await scene.call("_on_board_tile_clicked",Vector2i(6,3))
	if bool(scene.call("_pending_card_requires_confirmation")): await scene.call("_on_confirm_card_play_pressed")
	await _wait_idle()
	await _capture("coil_reduced_motion_settled")
	expect(Rules.reserve(scene.get("_combat_state"),"winters_hour") == 1,"Reduced motion preserves exact payment")
	print("DRAGON TROPHY FEEDBACK PROOF: ","PASS" if failed == 0 else "FAIL")
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)
func _counter() -> String:
	var label: Label = scene.find_child("RelicTimeReserve",true,false) as Label
	return label.text if label != null else "missing"
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
func _aim_at_target() -> void:
	var board: Control = scene.get("board_view")
	var point: Vector2 = board.global_position + (board.call("_tile_center",Vector2i(6,3)) as Vector2)
	var motion := InputEventMouseMotion.new()
	motion.position = point
	motion.global_position = point
	canvas.push_input(motion,true)
	scene.call("_on_board_tile_hovered",Vector2i(6,3))
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
func _wait_idle() -> void:
	var deadline: int = Time.get_ticks_msec()+7000
	while bool(scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline: await process_frame
	expect(not bool(scene.get("_animation_lock")),"Input recovers after real card animation")
	await _settle()
func _capture_leg(from: Vector2i,to: Vector2i,label: String) -> void:
	var deadline: int = Time.get_ticks_msec()+7000
	while Time.get_ticks_msec()<deadline:
		var shown: Dictionary = (scene.get("board_view") as Node).get("presentation")
		var effect: Dictionary = shown.get("effect",{})
		if effect.get("from") == from and effect.get("to") == to and float(shown.get("effect_progress",0.0)) >= 0.25:
			await _capture(label)
			return
		await process_frame
	expect(false,"Animation reaches "+label)
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
