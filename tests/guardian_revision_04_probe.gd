extends "res://tests/guardian_feedback_playback_probe.gd"

func _run() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	Settings.set_storage_path("user://guardian_revision_04_settings.json")
	Progression.set_storage_path("user://guardian_revision_04_profile.json")
	Progression.set_run_storage_path("user://guardian_revision_04_run.save")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	canvas = root
	scene = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/fixtures/guardian_feedback_run_scene_harness.gd"))
	canvas.add_child(scene)
	await process_frame
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	var engine := RunEngine.new()
	var combat := Combat.new()
	await _map_tooltip(engine,combat)
	for reduced: bool in [false,true]:
		settings["reduced_motion"]=reduced
		scene.set("_settings",settings.duplicate(true))
		var suffix: String = "_reduced" if reduced else "_normal"
		await _cover_and_path(engine,combat,suffix)
		await _patterns(engine,combat,suffix)
		await _brazier(engine,combat,suffix)
		await _detonation(engine,combat,suffix)
		await _sweep(engine,combat,suffix)
	for message: String in failures: push_error(message)
	print("GUARDIAN REVISION 04: ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)

func _load(state: Dictionary) -> void:
	root.warp_mouse(Vector2(440,1040))
	var motion := InputEventMouseMotion.new()
	motion.position=Vector2(440,1040)
	motion.global_position=motion.position
	Input.parse_input_event(motion)
	await process_frame
	await super._load(state)

func _fixture(engine: RefCounted,combat: RefCounted,id: String,study: String) -> Dictionary:
	var run: Dictionary = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":id,"guardian_case":study})
	return run

func _cover_and_path(engine: RefCounted,combat: RefCounted,suffix: String) -> void:
	await _load(_fixture(engine,combat,"craghide","occlusion"))
	var board: Node=scene.get("board_view")
	var tile:=Vector2i(5,5)
	var rect: Rect2=board.call("_terrain_rect_for_tile",tile,null,"crag_outcrop")
	var raw_tint: Color=board.call("_foreground_blocker_tint","terrain",tile,rect,board.get("_foreground_obstruction_entries_cache"))
	_check(raw_tint.a<1.0,"Outcrop study really overlaps an actor")
	await _capture("outcrop_actor_occlusion"+suffix)
	await _load(_fixture(engine,combat,"rimejaw","relic"))
	await scene.call("_on_board_tile_clicked",Vector2i(1,2))
	scene.call("_on_board_tile_hovered",Vector2i(6,2))
	await _capture("ice_and_rubble_path"+suffix)
	_check(((scene.get("board_view") as Node).get("presentation") as Dictionary).get("path_tiles",[]).size()>1,"Ice fixture has an actual movement arrow")
	await scene.call("_on_cancel_requested")

func _patterns(engine: RefCounted,combat: RefCounted,suffix: String) -> void:
	for id: String in ["last_lamplighter","gallows_roc"]:
		await _load(_fixture(engine,combat,id,"displaced_pattern"))
		var state: Dictionary = scene.get("_combat_state")
		await scene.call("_on_board_tile_clicked",state["enemies"][0]["pos"])
		_check(not combat.enemy_intent_plan(state,0)["projected_attack"].is_empty(),id+" displaced attack is visible")
		await _capture(id+"_displaced_pattern"+suffix)
	await _load(_fixture(engine,combat,"craghide","occupied_summon"))
	var state: Dictionary = scene.get("_combat_state")
	await scene.call("_on_board_tile_clicked",state["enemies"][0]["pos"])
	var summon: Array = combat.enemy_intent_plan(state,0).get("projected_summon",[])
	_check(not summon.is_empty() and not summon.has(state["player"]["pos"]),"Occupied summon shows replacement square")
	await _capture("occupied_summon_relocated"+suffix)

func _brazier(engine: RefCounted,combat: RefCounted,suffix: String) -> void:
	await _load(_fixture(engine,combat,"last_lamplighter","relight"))
	await _capture("brazier_dark"+suffix)
	var before: Dictionary = scene.get("_combat_state")
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(before,0)
	scene.call("begin_feedback_trace")
	_play_enemy(before,result["steps"])
	var deadline: int = Time.get_ticks_msec()+15000
	var saw_relit: bool=false
	while not playback_finished and Time.get_ticks_msec()<deadline:
		await process_frame
		var shown: Dictionary = (scene.get("board_view") as Node).get("presentation")
		for entry: Dictionary in shown.get("floating_texts",[]):
			if str(entry.get("text",""))=="Relit" and not saw_relit:
				saw_relit=true
				await _capture("brazier_relight_cue"+suffix)
	_check(playback_finished and saw_relit,"Last Procession visibly restores the brazier"+suffix)
	scene.call("_render_board_state",result["state"],{})
	await _capture("brazier_flame_a"+suffix)
	await create_timer(0.30).timeout
	await _capture("brazier_flame_b"+suffix)

func _detonation(engine: RefCounted,combat: RefCounted,suffix: String) -> void:
	await _load(_fixture(engine,combat,"ashen_reaver","relic"))
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var action: Dictionary = {"type":"detonate","range":4,"damage":3,"_detonate_surface":"fire"}
	var target := Vector2i(3,5)
	var after: Dictionary = combat.apply_player_action(before,action,target)
	_check(after!=before,"Relic study detonates actual connected Fire")
	scene.call("begin_feedback_trace")
	_play_player(before,after,"",action,target)
	var deadline: int = Time.get_ticks_msec()+15000
	var saw_burst: bool=false
	while not playback_finished and Time.get_ticks_msec()<deadline:
		await process_frame
		var board: Node = scene.get("board_view")
		var shown: Dictionary = board.get("presentation")
		var effect: Dictionary = shown.get("effect",{})
		if bool(effect.get("ground_burst",false)) and (suffix.contains("reduced") or float(shown.get("effect_progress",0))>0.38) and not saw_burst:
			saw_burst=true
			_check((board.call("_elemental_scene_depth_tiles_for_presentation",shown) as Array).size()>1,"Detonation has elemental depth effects across its actual blast")
			await _capture("connected_fire_detonation"+suffix)
	_check(playback_finished and saw_burst,"Detonation playback completes"+suffix)
	_check(_sound_count("fire")==1 and not (scene.get("feedback_sound_ids") as Array).has("attack.ranged"),"Fire detonation plays its elemental sound once without an arrow sound")

func _sweep(engine: RefCounted,combat: RefCounted,suffix: String) -> void:
	await _load(_fixture(engine,combat,"storm_cantor","sweep"))
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var hand: Array = before["deck"]["hand"]
	var index: int = hand.find("hamstring_shot")
	_check(index>=0,"Sweep fixture has Low Sweep")
	_check(not bool(scene.call("_guided_tutorial_is_active")),"Ordinary combat ignores an active tutorial profile")
	await scene.call("_on_card_pressed",index)
	await scene.call("_on_cancel_requested")
	_check(int(scene.get("_selected_card_index"))<0,"Pointer cancel works in the recovered fight")
	var router: Node=root.get_node("InputRouter")
	var controller: bool=suffix.contains("reduced")
	if controller:
		router.call("set_forced_state_for_test","controller","steam_deck")
		scene.set("_controller_region","hand")
		scene.call("_controller_set_hand_focused",true)
		scene.call("_controller_set_hand_index",index)
		await scene.call("_controller_activate_current")
		scene.call("_controller_set_board_tile",Vector2i(2,3))
	else:
		await scene.call("_on_card_pressed",index)
		scene.call("_on_board_tile_hovered",Vector2i(2,3))
	await _capture("cantor_low_sweep_target"+suffix)
	if controller: await scene.call("_controller_activate_current")
	else: await scene.call("_on_board_tile_clicked",Vector2i(2,3))
	router.call("set_forced_state_for_test","pointer","steam_deck")
	router.call("clear_forced_state_for_test")
	var after: Dictionary = scene.get("_combat_state")
	_check(int(scene.get("_selected_card_index"))<0 and not bool(scene.get("_pending_umbra_commit_locked")) and not bool(scene.get("_animation_lock")),"Low Sweep finishes and releases all input locks")
	_check(after["enemies"][3]["hp"]<before["enemies"][3]["hp"],"Low Sweep strikes the living replacement Wisp")
	_check((scene.get("hand_box") as Control).is_visible_in_tree(),"The hand remains visible")
	await _capture("cantor_low_sweep_completed"+suffix)
	await scene.call("_on_board_tile_clicked",after["player"]["pos"])
	_check(bool(scene.get("_player_movement_selected")),"Movement still accepts input after Sweep")
	await scene.call("_on_cancel_requested")

func _map_tooltip(engine: RefCounted,combat: RefCounted) -> void:
	await _load(_fixture(engine,combat,"ashen_reaver","map_choice"))
	scene.call("_open_large_map")
	await process_frame
	var panel: Node=scene.get("_large_map_view")
	for room: Dictionary in (scene.get("_run_state") as Dictionary)["rooms"].values():
		if str(room.get("guardian_id",""))!="ashen_reaver": continue
		var text: String=panel.call("room_description",room["coord"])
		_check(not text.contains("Reward") and not text.contains("Ashen Brand"),"Map tooltip omits reward")
		panel.call("_show_preview",room["coord"])
		await _capture("guardian_map_encounter_tooltip")
		break
	scene.call("_close_large_map")
