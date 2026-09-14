extends SceneTree
const Factory = preload("res://tools/guardian_inspection.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
var failures: Array[String] = []
var canvas: SubViewport
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
	var raise_button: Button = utility.get_node("RaiseCover")
	var reclaim_button: Button = utility.get_node("ReclaimCover")
	_check(not raise_button.disabled and not reclaim_button.disabled,"cover controls are affordable")
	await _click(raise_button.get_global_rect().get_center())
	_check(scene.get("_player_movement_selected"),"pointer click selects Raise Cover")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	await scene.call("_on_cancel_requested")
	_check(scene.get("_combat_state")==before and not scene.get("_player_movement_selected"),"cancelled Raise spends nothing")
	await _click(raise_button.get_global_rect().get_center())
	scene.call("_on_board_tile_hovered",Vector2i(2,5))
	await _capture("cover_raise_target")
	await scene.call("_on_board_tile_clicked",Vector2i(2,5))
	var raised: Dictionary = scene.get("_combat_state")
	_check(raised["terrain"].size()==2 and raised["player"]["stoneskin"]==0 and raised["player_movement_remaining"]==1,"one Raise target converts all armor and one shared Move")
	await _capture("cover_raised")
	await _click(reclaim_button.get_global_rect().get_center())
	await scene.call("_on_board_tile_clicked",Vector2i(3,6))
	var reclaimed: Dictionary = scene.get("_combat_state")
	_check(reclaimed["terrain"].size()==1 and reclaimed["player"]["stoneskin"]==4 and reclaimed["player_movement_remaining"]==0,"Reclaim restores damaged cover HP and exhausts shared Move")
	_check(raise_button.disabled and reclaim_button.disabled,"cover controls disable at zero Move")
	await _capture("cover_reclaimed")
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
		raise_button = (scene.get("_relic_utility_bar") as Node).get_node("RaiseCover")
		_check((scene.call("_controller_header_focus_controls") as Array).has(raise_button),"controller can focus Raise")
		scene.set("_controller_focus_candidate",{"kind":"control","control":raise_button})
		await scene.call("_controller_activate_current")
		_check(scene.get("_player_movement_selected"),"controller activation selects Raise")
		var cancel := InputEventAction.new()
		cancel.action=input.ACTION_CANCEL
		cancel.pressed=true
		before=(scene.get("_combat_state") as Dictionary).duplicate(true)
		_check(await scene.call("_handle_controller_input",cancel),"controller Cancel is handled")
		_check(scene.get("_combat_state")==before,"controller Cancel preserves resources")
		await _capture("cover_controller_cancel")
		router.call("set_forced_state_for_test",input.MODALITY_POINTER,input.FAMILY_STEAM_DECK)
		scene.call("_refresh_controller_interface")
		router.call("clear_forced_state_for_test")
	for pair: Array in [["ashen_reaver","cinderline_tempo"],["storm_cantor","chain_bolt"],["gallows_roc","kite_bash"],["craghide","stone_plate"]]:
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
