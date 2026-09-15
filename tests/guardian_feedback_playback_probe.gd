extends "res://tests/guardian_ui_probe.gd"
const Fixtures = preload("res://tests/suites/guardian_suite.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Rules = preload("res://scripts/guardian_combat_rules.gd")
const Data = preload("res://scripts/game_data.gd")
var playback_finished: bool = false
var captured: bool = false
var expected_feedback_tile := Vector2i(-1,-1)

func _run() -> void:
	root.size = Vector2i(1920,1080)
	root.content_scale_size = root.size
	Settings.set_storage_path("user://guardian_playback_settings.json")
	Progression.set_storage_path("user://guardian_playback_profile.json")
	Progression.set_run_storage_path("user://guardian_playback_run.save")
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
	var fixtures := Fixtures.new()
	for reduced: bool in [false,true]:
		settings["reduced_motion"] = reduced
		scene.set("_settings",settings.duplicate(true))
		var suffix: String = "_reduced" if reduced else "_normal"
		for type: String in ["move","blink"]:
			var before: Dictionary = fixtures.fixture("",[Vector2i(7,7)])
			before["player"]["pos"] = Vector2i(2,4)
			before["player"]["block"] = 0
			before["umbra"]["vision_bonus"] = 12
			Ground.place(before,Vector2i(3,4),"fire")
			var action: Dictionary = {"type":type,"range":2}
			_check(combat.valid_targets_for_player_action(before,action).has(Vector2i(3,4)),type+" Fire tile is a legal target")
			var after: Dictionary = combat.apply_player_action(before,action,Vector2i(3,4))
			_check(after["player"]["hp"]<before["player"]["hp"],type+" really loses health on Fire")
			await _load_battle(engine,before)
			scene.call("begin_feedback_trace")
			expected_feedback_tile = Vector2i(3,4)
			_play_player(before,after,"",action,Vector2i(3,4))
			await _observe(type+"_fire"+suffix)
			_check(_player_loss_groups(after["player"]["pos"])==1,type+" Fire loss is presented exactly once"+suffix)
			_check(_sound_count("fire")==1,type+" Fire contact plays one elemental sound"+suffix)
		# A Bleed-only move has no surface event and still needs its loss beat.
		var bleed_before: Dictionary = fixtures.fixture("",[Vector2i(7,7)])
		bleed_before["player"]["bleed"] = 2
		var move_action: Dictionary = {"type":"move","range":2}
		var bleed_after: Dictionary = combat.apply_player_action(bleed_before,move_action,Vector2i(2,1))
		await _load_battle(engine,bleed_before)
		scene.call("begin_feedback_trace")
		expected_feedback_tile = Vector2i(-1,-1)
		_play_player(bleed_before,bleed_after,"",move_action,Vector2i(2,1))
		await _observe("move_bleed"+suffix)
		_check(_player_loss_groups(bleed_after["player"]["pos"])==1,"Bleed movement retains its loss beat"+suffix)
		var before: Dictionary = fixtures.fixture("",[Vector2i(7,7)])
		before["player"]["pos"] = Vector2i(2,4)
		before["umbra"]["vision_bonus"] = 12
		before["traps"] = [{"id":"feedback_fire","pos":Vector2i(3,4),"element":"fire","damage":1,"blast_radius":0}]
		var frost: Dictionary = combat.card_play_actions("frostbolt",before)[0]
		_check(combat.valid_targets_for_player_action(before,frost).has(Vector2i(3,4)),"Frostbolt can target the Fire trap")
		var after: Dictionary = combat.apply_player_action(before,frost,Vector2i(3,4))
		await _load_battle(engine,before)
		scene.call("begin_feedback_trace")
		expected_feedback_tile = Vector2i(3,4)
		_play_player(before,after,"frostbolt",frost,Vector2i(3,4))
		await _observe("frostbolt_fire_trap"+suffix)
		_check(_sound_count("ice")==1 and _sound_count("fire")==1,"Mixed-element trap plays its primary Ice and trap Fire sounds once each"+suffix)
		before = fixtures.guardian_fixture("storm_cantor")
		_clear_floor(before)
		before["player"]["pos"] = Vector2i(6,4)
		before["player"]["block"] = 0
		before["enemies"][0]["pos"] = Vector2i(2,4)
		before["enemies"][1]["pos"] = Vector2i(4,2)
		before["enemies"][2]["pos"] = Vector2i(6,2)
		for x: int in range(3,7): Ground.place(before,Vector2i(x,4),"electrified")
		var peal: Dictionary = Data.enemy_def("storm_cantor")["intents"][1].duplicate(true)
		peal["actions"].pop_front()
		before["enemies"][0]["intent"] = Rules.commit(combat,before,0,peal)
		var center: Vector2i = before["enemies"][0]["intent"]["actions"][0]["declared_tiles"][0]
		before["traps"] = [{"id":"feedback_fire","pos":center,"element":"fire","damage":1,"blast_radius":0}]
		var result: Dictionary = combat.resolve_enemy_turn_with_steps(before,0)
		var steps: Array
		for step: Dictionary in result["steps"]:
			if not (step.get("triggered_traps",[]) as Array).is_empty(): steps.append(step)
		_check(steps.size()==1 and result["state"]["player"]["hp"]<before["player"]["hp"],"Cantor trap fixture really conducts damage to the indirect victim")
		await _load_battle(engine,before)
		scene.call("begin_feedback_trace")
		expected_feedback_tile = Vector2i(6,4)
		_play_enemy(before,steps)
		await _observe("cantor_trap_conduction"+suffix)
		_check(_sound_count("lightning")==1 and _sound_count("fire")==1,"Enemy trap handoff retains one sound per elemental outcome"+suffix)
		_check((scene.get("hand_box") as Control).is_visible_in_tree(),"Trap conduction leaves the hand visible")
	for message: String in failures: push_error(message)
	print("GUARDIAN FEEDBACK PLAYBACK: ","PASS" if failures.is_empty() else "FAIL", " ",failures)
	quit(0 if failures.is_empty() else 1)

func _load_battle(engine: RefCounted,battle: Dictionary) -> void:
	scene.set("feedback_trace_enabled",false)
	var run: Dictionary = engine.create_new_run(9152603,Progression.default_data())
	run["mode"] = "combat"
	run["combat_state"] = battle
	await _load(run)

func _play_player(before: Dictionary,after: Dictionary,card: String,action: Dictionary,target: Vector2i) -> void:
	playback_finished = false
	await scene.call("_animate_player_action_step",before,after,card,action,target)
	playback_finished = true

func _play_enemy(before: Dictionary,steps: Array) -> void:
	playback_finished = false
	await scene.call("_animate_enemy_phase_steps",before.duplicate(true),steps)
	playback_finished = true

func _observe(label: String) -> void:
	captured = false
	var deadline: int = Time.get_ticks_msec()+15000
	while not playback_finished and Time.get_ticks_msec()<deadline:
		await process_frame
		var shown: Dictionary = (scene.get("board_view") as Node).get("presentation")
		var feedback: bool = expected_feedback_tile.x<0 and not (shown.get("floating_texts",[]) as Array).is_empty()
		for event: Dictionary in shown.get("surface_feedback_events",[]):
			if event.get("tile",Vector2i(-1,-1))==expected_feedback_tile: feedback = true
		if not captured and feedback and (expected_feedback_tile.x<0 or float(shown.get("surface_feedback_progress",0.0))>=0.28):
			captured = true
			if DisplayServer.get_name().to_lower()!="headless": await _capture(label)
	_check(captured,label+" shows its resolved feedback during real playback")
	_check(playback_finished,label+" playback finishes")

func _sound_count(element: String) -> int:
	return (scene.get("feedback_sound_ids") as Array).count("attack.elemental."+element)

func _player_loss_groups(tile: Vector2i) -> int:
	var count: int = 0
	for presentation: Dictionary in scene.get("feedback_presentations"):
		for entry: Dictionary in presentation.get("floating_texts",[]):
			if entry.get("tile",Vector2i(-1,-1))==tile and str(entry.get("text","")).begins_with("-"):
				count += 1
				break
	return count

func _clear_floor(state: Dictionary) -> void:
	for y: int in range(state["grid"].size()):
		for x: int in range(state["grid"][y].size()):
			state["grid"][y][x] = "wall" if x==0 or y==0 or x==state["grid"][y].size()-1 or y==state["grid"].size()-1 else "stone"
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["umbra"]["vision_bonus"] = 12
