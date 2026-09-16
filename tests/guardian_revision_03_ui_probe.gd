extends "res://tests/guardian_ui_probe.gd"
const Outcomes = preload("res://scripts/combat_outcome_feedback.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")

func _run() -> void:
	if DisplayServer.get_name().to_lower()=="headless":
		push_error("Native renderer required")
		quit(1)
		return
	root.size=Vector2i(1920,1080)
	root.content_scale_size=root.size
	Settings.set_storage_path("user://guardian_revision_03_settings.json")
	var settings: Dictionary=Settings.default_settings()
	settings["ui_scale"]=1.0
	settings["display_mode"]="windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings,root,false)
	Progression.set_storage_path("user://guardian_revision_03_profile.json")
	Progression.set_run_storage_path("user://guardian_revision_03_run.save")
	canvas=root
	root.gui_embed_subwindows=true
	scene=load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	root.mode=Window.MODE_WINDOWED
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_VIEWPORT
	root.content_scale_aspect=Window.CONTENT_SCALE_ASPECT_KEEP
	root.size=Vector2i(1920,1080)
	root.content_scale_size=root.size
	await process_frame
	var engine:=RunEngine.new()
	var combat:=Combat.new()
	var outcrop_only: bool=OS.get_cmdline_user_args().has("--outcrop-only")
	if not outcrop_only: await _interactions(engine,combat)
	scene.set("_settings",settings.duplicate(true))
	for guardian: String in ["ashen_reaver","storm_cantor","craghide"]:
		if outcrop_only and guardian!="craghide": continue
		var state: Dictionary=Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":guardian,"guardian_case":"encounter"})
		var battle: Dictionary=state["combat_state"]
		battle["player"]["pos"]=(battle["enemies"][0]["pos"] as Vector2i)+Vector2i(0,2)
		await _load(state)
		var tile: Vector2i=battle["enemies"][0]["pos"]
		await scene.call("_on_board_tile_clicked",tile)
		_check(int(scene.get("_focused_intent_enemy_id"))==int(battle["enemies"][0]["id"]),guardian+" click focuses enemy")
		scene.call("_on_board_tile_hovered",Vector2i(1,7))
		await process_frame
		var board: Node=scene.get("board_view")
		_check((board.get("presentation") as Dictionary).get("expanded_enemy_actor_keys",[]).has("enemy_1"),"Intent remains expanded away from enemy")
		var intent_rect: Rect2=board.call("enemy_intent_visual_global_rect","enemy_1")
		_check(intent_rect.has_area(),"Focused intent has real drawn bounds")
		_check(not str(board.call("enemy_intent_tooltip","enemy_1")).is_empty(),"Controller can inspect the same intent token definitions")
		await _capture(guardian+"_focused_intent")
		await scene.call("_on_board_cancel_requested")
		_check(int(scene.get("_focused_intent_enemy_id"))<0,"Board cancel clears focus")
		if guardian=="craghide":
			var before: Dictionary=(scene.get("_combat_state") as Dictionary).duplicate(true)
			var after: Dictionary=before.duplicate(true)
			_check(preload("res://scripts/combat_terrain_rules.gd").raise_outcrop(combat,after,Vector2i(3,5),3,{"actor_kind":"enemy","actor_id":1}),"Native emergence fixture creates an actual outcrop")
			var events: Array=Outcomes.prepare(scene.call("_surface_events_between",before,after))
			_check(not bool(scene.call("_reduced_motion_enabled")) and not events.is_empty(),"Normal emergence has real creation feedback and motion enabled")
			for t: float in [0.18,0.45,0.80,1.0]:
				scene.call("_render_board_state",after,{"surface_feedback_events":events,"surface_feedback_progress":t})
				await _capture("outcrop_emergence_%d" % int(t*100))
			settings["reduced_motion"]=true
			scene.set("_settings",settings)
			await scene.call("_animate_surface_change",before,after)
			await _capture("outcrop_reduced_motion")
			settings["reduced_motion"]=false
			scene.set("_settings",settings)
	if not outcrop_only:
		await _shared_inspection(engine,combat)
		await _conduction_playback(engine,combat)
	var file:=FileAccess.open("user://probes/guardian_ui/revision_03_manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"size":[1920,1080],"ui_scale":1.0,"errors":failures},"\t"))
	print("GUARDIAN REVISION 03 UI: ","PASS" if failures.is_empty() else "FAIL",failures)
	quit(0 if failures.is_empty() else 1)

func _shared_inspection(engine: RefCounted, combat: RefCounted) -> void:
	var state: Dictionary=Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"ashen_reaver","guardian_case":"reinforcements"})
	state["combat_state"]["umbra"]["vision_bonus"]=12
	await _load(state)
	var battle: Dictionary=scene.get("_combat_state")
	await scene.call("_on_board_tile_clicked",battle["enemies"][0]["pos"])
	var board: Node=scene.get("board_view")
	var markers: Dictionary=board.get("_summon_tiles_lookup_cache")
	_check(markers.size()==1,"Shared board renders one green summon marker")
	for tile: Vector2i in markers:
		_check(not (board.get("_projected_attack_tiles_lookup_cache") as Dictionary).has(tile),"Summon marker has no attack overlay")
	await _capture("green_summon_marker")
	state=Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"ashen_reaver","guardian_case":"relic"})
	await _load(state)
	battle=scene.get("_combat_state")
	await scene.call("_on_board_tile_clicked",battle["enemies"][0]["pos"])
	_check(int(scene.get("_focused_intent_enemy_id"))==1,"Ordinary enemies use the same focus interaction")
	scene.call("_on_board_tile_hovered",Vector2i(7,7))
	await _capture("ordinary_enemy_focused")
	# Probe real tooltip hit regions inside the expanded panel.
	_check(not str(board.call("enemy_intent_tooltip","enemy_1")).is_empty(),"Ordinary intent resolves default keyword tooltips")
	var rect: Rect2=board.call("enemy_intent_visual_global_rect","enemy_1")
	var tooltip_point:=Vector2.ZERO
	var tooltip_samples: int=0
	for y: int in range(int(rect.position.y),int(rect.end.y),4):
		for x: int in range(int(rect.position.x),int(rect.end.x),4):
			var point:=Vector2(x,y)
			var text: String=board.call("_get_tooltip",point-(board as Control).global_position)
			if text.contains("Bleed"):
				tooltip_point+=point
				tooltip_samples+=1
	if tooltip_samples>0: tooltip_point/=float(tooltip_samples)
	_check(tooltip_point!=Vector2.ZERO,"Expanded intent exposes actual hoverable token hit regions")
	if tooltip_point!=Vector2.ZERO:
		root.warp_mouse(tooltip_point)
		await process_frame
		var motion:=InputEventMouseMotion.new()
		motion.position=tooltip_point
		motion.global_position=tooltip_point
		canvas.push_input(motion,true)
		await create_timer(2.0).timeout
		_check(canvas.gui_get_hovered_control()==board,"Pointer reaches the actual intent token")
		_check(_visible_tooltip_with_text(root,"Deals damage before moving or attacking."),"Native pointer hover opens the Bleed definition")
		await _capture("intent_keyword_hover")
		root.warp_mouse(Vector2(8,8))
		motion.position=Vector2(8,8)
		motion.global_position=motion.position
		canvas.push_input(motion,true)
		await process_frame
	var input=preload("res://scripts/input_router.gd")
	var router: Node=root.get_node_or_null("InputRouter")
	if router!=null:
		router.call("set_forced_state_for_test",input.MODALITY_CONTROLLER,input.FAMILY_STEAM_DECK)
		scene.set("_controller_region","board")
		scene.call("_controller_set_board_tile",battle["enemies"][0]["pos"])
		await scene.call("_controller_activate_current")
		_check(int(scene.get("_focused_intent_enemy_id"))==1,"Controller activation retains enemy intent")
		await _capture("intent_controller_inspection")
		var other: Dictionary=scene.call("_controller_candidate_for_tile",battle["enemies"][1]["pos"])
		_check(str(other.get("detail","")).is_empty(),"Moving to another enemy does not describe the pinned enemy")
		await scene.call("_on_board_cancel_requested")
		_check(int(scene.get("_focused_intent_enemy_id"))<0,"Controller cancel clears intent focus")
		await scene.call("_on_board_tile_clicked",battle["enemies"][0]["pos"])
		scene.set("_controller_focus_candidate",{"kind":"control","control":scene.get("_section_map_hud_button")})
		await scene.call("_controller_activate_current")
		_check(int(scene.get("_focused_intent_enemy_id"))<0,"Selecting another controller control clears focus")
		scene.call("_close_large_map")
		router.call("set_forced_state_for_test",input.MODALITY_POINTER,input.FAMILY_STEAM_DECK)
		scene.call("_refresh_controller_interface")
	await scene.call("_on_card_pressed",0)
	_check(int(scene.get("_focused_intent_enemy_id"))<0,"Card selection clears enemy focus")

var playback_running: bool=false
func _play_steps(state: Dictionary, steps: Array) -> void:
	playback_running=true
	await scene.call("_animate_enemy_phase_steps",state,steps)
	playback_running=false

func _conduction_playback(engine: RefCounted, combat: RefCounted) -> void:
	var state: Dictionary=Factory.build(engine,combat,engine.create_new_run(7262026,Progression.default_data()),{"guardian_id":"storm_cantor","guardian_case":"encounter"})
	var battle: Dictionary=state["combat_state"]
	battle["player"]["pos"]=Vector2i(6,4)
	battle["enemies"][0]["pos"]=Vector2i(2,4)
	battle["enemies"][1]["pos"]=Vector2i(4,2)
	battle["enemies"][2]["pos"]=Vector2i(6,2)
	battle["umbra"]["vision_bonus"]=12
	for x: int in range(2,7):
		battle["grid"][4][x]="stone"
		Surfaces.place(battle,Vector2i(x,4),"electrified")
	var peal: Dictionary=preload("res://scripts/game_data.gd").enemy_def("storm_cantor")["intents"][1].duplicate(true)
	peal["actions"].pop_front()
	battle["enemies"][0]["intent"]=preload("res://scripts/guardian_combat_rules.gd").commit(combat,battle,0,peal)
	await _load(state)
	var result: Dictionary=combat.resolve_enemy_turn_with_steps(battle,0)
	_check(result["state"]["player"]["hp"]<battle["player"]["hp"],"Conduction playback uses an actual indirect hit")
	playback_running=true
	call_deferred("_play_steps",battle.duplicate(true),result["steps"])
	var found: bool=false
	var heard: bool=false
	var deadline: int=Time.get_ticks_msec()+12000
	while playback_running and Time.get_ticks_msec()<deadline:
		await process_frame
		var shown: Dictionary=(scene.get("board_view") as Node).get("presentation")
		for player: AudioStreamPlayer in scene.get("_sfx_players"):
			if str(player.get_meta("sfx_id",""))=="attack.elemental.lightning": heard=true
		if not found and float(shown.get("surface_feedback_progress",0.0))>.15:
			for event: Dictionary in shown.get("surface_feedback_events",[]):
				if event.get("tile",Vector2i.ZERO)==Vector2i(6,4) and str(event.get("feedback_element",""))=="lightning":
					found=true
			if found: await _capture("indirect_conduction_impact")
	_check(found,"Indirect victim receives an elemental board effect during playback")
	_check(heard,"Conduction playback uses elemental sound")
	_check(not playback_running,"Conduction playback completes")
	_check((scene.get("hand_box") as Control).is_visible_in_tree(),"Conduction playback leaves the hand visible")
	await _capture("indirect_conduction_complete")

func _visible_tooltip_with_text(node: Node, needle: String) -> bool:
	if node is Label and (node as Label).is_visible_in_tree() and (node as Label).text.contains(needle): return true
	if node is RichTextLabel and (node as RichTextLabel).is_visible_in_tree() and (node as RichTextLabel).get_parsed_text().contains(needle): return true
	for child: Node in node.get_children():
		if _visible_tooltip_with_text(child,needle): return true
	return false
