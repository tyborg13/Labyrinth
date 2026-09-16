extends SceneTree
const Factory = preload("res://tools/guardian_inspection.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
var failures: Array[String] = []
var canvas: Viewport
var scene: Node
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	Settings.set_storage_path("user://guardian_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	Progression.set_storage_path("user://guardian_probe_profile.json")
	Progression.set_run_storage_path("user://guardian_probe_run.save")
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := RunEngine.new()
	var combat := Combat.new()
	for info: Dictionary in Guardians.DEFINITIONS.values():
		if OS.get_cmdline_user_args().has("--map-only"):break
		var id: String = info["id"]
		for study: String in ["pre_battle","encounter","relic"]:
			var state: Dictionary = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":id,"guardian_case":study})
			await _load(state)
			await _capture(id+"_"+study)
			if study == "encounter":
				var board: Node = scene.get("board_view")
				var snapshot: Dictionary = board.call("guardian_animation_snapshot","enemy_1")
				if int(snapshot.get("rig_count",0)) != 2: failures.append(id+" missing live cutout")
	for study: String in ["map_entry","map_choice","reward","outage"]:
		if OS.get_cmdline_user_args().has("--map-only") and study!="map_choice":continue
		var id: String = "last_lamplighter" if study in ["outage","map_entry"] else "ashen_reaver"
		await _load(Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":id,"guardian_case":study}))
		if study.begins_with("map"):
			scene.call("_open_large_map")
			await process_frame
		await _capture(id+"_"+study)
		if study=="map_choice":
			var panel: Node = scene.get("_large_map_view")
			var run: Dictionary = scene.get("_run_state")
			for metadata: Dictionary in run["rooms"].values():
				if str(metadata.get("guardian_id",""))!="ashen_reaver": continue
				var coord: Vector2i = metadata["coord"]
				panel.call("select_room",coord)
				_check(panel.call("can_activate_room",coord),"Guardian is a selectable route choice")
				await _capture("guardian_map_details")
				await panel.call("activate_room",coord)
				var deadline: int = Time.get_ticks_msec()+6000
				while Time.get_ticks_msec()<deadline:
					if str((scene.get("_run_state") as Dictionary).get("mode",""))=="pre_battle":break
					await create_timer(.05).timeout
				_check(str((scene.get("_run_state") as Dictionary).get("mode",""))=="pre_battle","map selection enters named Guardian pre-battle; actual "+str((scene.get("_run_state") as Dictionary).get("mode","")))
	if not OS.get_cmdline_user_args().has("--map-only"):await _interactions(engine,combat)
	var output: String = "user://probes/guardian_ui"
	var file := FileAccess.open(output.path_join("manifest.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"errors":failures},"\t"))
	print("GUARDIAN UI: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	quit(0 if failures.is_empty() else 1)
func _load(state: Dictionary) -> void:
	scene.call("_load_run_state",state)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(.28).timeout
	await process_frame
func _capture(name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var output: String = "user://probes/guardian_ui"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	canvas.get_texture().get_image().save_png(output.path_join(name+".png"))

func _interactions(engine: RefCounted, combat: RefCounted) -> void:
	var state: Dictionary = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"craghide","guardian_case":"relic"})
	await _load(state)
	var utility: Node = scene.get("_relic_utility_bar")
	_check(utility.get_node_or_null("RaiseCover")==null and utility.get_node_or_null("ReclaimCover")==null,"Gauntlet has no bespoke controls")
	await scene.call("_on_card_pressed",0)
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	await scene.call("_on_cancel_requested")
	_check(scene.get("_combat_state")==before,"Cancelled Earth spell spends nothing")
	await scene.call("_on_card_pressed",0)
	scene.call("_on_board_tile_hovered",Vector2i(2,5))
	await _capture("outcrop_spell_target")
	await scene.call("_on_board_tile_clicked",Vector2i(2,5))
	var raised: Dictionary = scene.get("_combat_state")
	_check(raised["terrain"].size()==1 and raised["terrain"][0]["hp"]==3 and raised["player_movement_remaining"]==2,"One Earth spell target creates cover without a Move cost")
	_check(int(scene.get("_selected_card_index"))<0,"Gauntlet adds no second target")
	await _capture("outcrop_raised")
	state = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"last_lamplighter","guardian_case":"relic"})
	await _load(state)
	await scene.call("_on_board_tile_clicked",Vector2i(3,3))
	_check(int((scene.get("_player_movement_action") as Dictionary).get("_illusion_id",-1))==1,"selecting Illusion binds only independent movement")
	scene.call("_on_board_tile_hovered",Vector2i(4,3))
	await _capture("illusion_dark_move_target")
	var board: Node = scene.get("board_view")
	var shown: Dictionary = board.get("presentation")
	_check((shown.get("path_tiles",[]) as Array)[0]==Vector2i(3,3),"Illusion path starts at decoy")
	_check((shown.get("effect",{}) as Dictionary).get("from",Vector2i.ZERO)==Vector2i(3,3),"Illusion movement effect starts at decoy")
	await scene.call("_on_board_tile_clicked",Vector2i(4,3))
	var moved: Dictionary = scene.get("_combat_state")
	_check(moved["illusions"][0]["pos"]==Vector2i(4,3) and moved["player"]["pos"]==Vector2i(2,6),"Illusion move leaves hero in place")
	_check(moved["player_movement_remaining"]==1,"Illusion and hero share Move")
	await _capture("illusion_dark_move_committed")
	var router: Node = root.get_node_or_null("InputRouter")
	if router != null:
		var input = preload("res://scripts/input_router.gd")
		router.call("set_forced_state_for_test",input.MODALITY_CONTROLLER,input.FAMILY_STEAM_DECK)
		state = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"craghide","guardian_case":"relic"})
		await _load(state)
		scene.call("_refresh_controller_interface")
		scene.set("_controller_region","hand")
		scene.set("_controller_hand_index",0)
		scene.set("_controller_focus_candidate",{})
		await scene.call("_controller_activate_current")
		_check(int(scene.get("_selected_card_index"))==0,"Controller selects the ordinary Earth spell")
		var cancel := InputEventAction.new()
		cancel.action=input.ACTION_CANCEL
		cancel.pressed=true
		before=(scene.get("_combat_state") as Dictionary).duplicate(true)
		_check(await scene.call("_handle_controller_input",cancel),"Controller Cancel is handled")
		_check(scene.get("_combat_state")==before,"Controller Cancel preserves resources")
		await _capture("outcrop_controller_cancel")
		router.call("set_forced_state_for_test",input.MODALITY_POINTER,input.FAMILY_STEAM_DECK)
		scene.call("_refresh_controller_interface")
		router.call("clear_forced_state_for_test")
	for pair: Array in [["ashen_reaver","cinderline_tempo"],["storm_cantor","chain_bolt"],["gallows_roc","kite_bash"],["craghide","root_snare"]]:
		state = Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":pair[0],"guardian_case":"relic"})
		Factory._seed_hand(state["combat_state"],[pair[1]])
		await _load(state)
		await scene.call("_on_card_pressed",0)
		var targets: Array = (scene.call("_active_card_preview") as Dictionary).get("target_tiles",[])
		if not targets.is_empty():
			scene.call("_on_board_tile_hovered",targets[0])
			if pair[0]=="gallows_roc":
				var preview: Dictionary = (scene.get("board_view") as Node).get("presentation")
				_check((preview.get("displacement_paths",[]) as Array).size()==3,"Galehook previews all three group paths")
			await _capture(pair[0]+"_card_preview")
			await scene.call("_on_board_tile_clicked",targets[0])
			_check(int(scene.get("_selected_card_index"))<0,pair[0]+" card needs no extra relic target")
		else:
			failures.append(pair[0]+" card fixture lacks a valid target")
	await _load(Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"gallows_roc","guardian_case":"encounter"}))
	var battle: Dictionary = scene.get("_combat_state")
	var leader: Dictionary = battle["enemies"][0]
	# This visual facing study moves only the observer into viewing range.
	battle["player"]["pos"]=leader["pos"]+Vector2i(1,0)
	_check(combat.is_enemy_visible_to_player(battle,leader),"Roc is visible in all facing and reduced-motion captures")
	for direction: Vector2i in [Vector2i.UP,Vector2i.DOWN,Vector2i.LEFT,Vector2i.RIGHT]:
		scene.call("_render_board_state",battle,{"guardian_motion":{"enemy_1":{"clip":"walk","phase":.22,"direction":direction}}})
		await _capture("roc_facing_%s_%s" % [direction.x,direction.y])
	var reduced: Dictionary = scene.get("_settings")
	if not reduced.is_empty():
		reduced["reduced_motion"]=true
		scene.set("_settings",reduced)
		scene.call("_render_board_state",battle,{})
		await _capture("roc_reduced_motion")

func _check(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _click(point: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position=point
	motion.global_position=point
	canvas.push_input(motion,true)
	await process_frame
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index=MOUSE_BUTTON_LEFT
		event.pressed=pressed
		event.position=point
		event.global_position=point
		canvas.push_input(event,true)
		await process_frame
