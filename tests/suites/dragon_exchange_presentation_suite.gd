extends RefCounted
const Store = preload("res://scripts/progression_store.gd")
const Run = preload("res://scripts/run_engine.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Sfx = preload("res://scripts/run_sfx_library.gd")
const Loader = preload("res://scripts/asset_loader.gd")
const Data = preload("res://scripts/game_data.gd")
const Analytics = preload("res://scripts/analytics_store.gd")

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var profile_path: String = Store._storage_path
	var run_path: String = Store._run_storage_path
	var settings_path: String = Settings.storage_path()
	var analytics_path: String = Analytics.storage_dir()
	var previous_settings: Dictionary = Settings.load_settings()
	var previous_reduced: bool = Settings._applied_reduced_motion
	var prefix: String = "user://dragon_exchange_live_%d" % Time.get_ticks_usec()
	Store.set_storage_path(prefix+"_profile.json")
	Store.set_run_storage_path(prefix+"_run.save")
	Settings.set_storage_path(prefix+"_settings.json")
	Analytics.set_storage_dir(prefix+"_events")
	var isolated_settings: Dictionary = previous_settings.duplicate(true)
	isolated_settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(isolated_settings)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/fixtures/dragon_exchange_run_scene.gd"))
	tree.root.add_child(scene)
	await tree.process_frame
	await run(tree,scene,expect)
	scene.queue_free()
	await tree.process_frame
	await tree.process_frame
	Store.set_storage_path(profile_path)
	Store.set_run_storage_path(run_path)
	Settings.set_storage_path(settings_path)
	Analytics.set_storage_dir(analytics_path)
	Settings.apply_settings(previous_settings,tree.root,false)
	Settings._applied_reduced_motion = previous_reduced

static func setup(tree: SceneTree, scene: Node, shards: int, reduced: bool = false) -> Dictionary:
	var profile: Dictionary = Store.default_data()
	profile[Store.EMACIATED_AWAKENING_SEEN_KEY] = true
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION,"status":"dismissed","completed_steps":[]}
	profile["embers"] = 100
	profile["moltshards"] = shards
	profile["run_counter"] = 828
	var run: Dictionary = Run.new().create_new_run(20260928,profile)
	Store.save_data(profile)
	Store.save_run_state(run)
	scene.set("_progression",profile)
	scene.call("_load_run_state",run)
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	var settings: Dictionary = Settings.default_settings()
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	settings["reduced_motion"] = reduced
	scene.set("_settings",settings)
	scene.call("_show_emaciated_services")
	scene.set("heard_cues",_strings())
	await tree.process_frame
	return run

static func _strings() -> Array[String]:
	var result: Array[String]
	return result

static func run(tree: SceneTree, scene: Node, expect: Callable, capture: Callable = Callable()) -> void:
	var cue: Dictionary = Sfx.entry(Sfx.HEARTH_STRENGTH_ID)
	var audio: AudioStream = Loader.load_audio_stream(str(cue["path"]))
	expect.call(audio != null and absf(audio.get_length()-.95)<.01,"Trade uses the complete brief Hearth success cue")
	expect.call(cue.get("bus","")==Settings.UI_SFX_BUS,"Trade sound respects UI audio settings")
	var copy: String = Data.relics()["stormroad_coil"]["description"]
	expect.call(copy.contains("relay once") and copy.contains("each leg") and not copy.to_lower().contains("visible") and not copy.to_lower().contains("line of sight"),"Coil keeps the relay rule without redundant visibility prose")
	for reduced: bool in [false,true]:
		await setup(tree,scene,2,reduced)
		var exchange: Button = (scene.get("_dialogue_choice_bar") as Control).get_child(0)
		exchange.grab_focus()
		if reduced:
			scene.set("_controller_focus_candidate",scene.call("_controller_candidate_for_control",exchange))
			scene.call("_controller_activate_current")
		else: exchange.pressed.emit()
		# A queued second signal must not spend the second available shard.
		scene.call("_on_dialogue_option_pressed",{"action":"exchange_moltshard"})
		expect.call(int((scene.get("_progression") as Dictionary)["moltshards"])==1 and Run.new().held_embers(scene.get("_run_state"))==350,"Successful trade spends and credits exactly once despite duplicate activation")
		expect.call(int(Store.load_data()["moltshards"])==1,"Fanfare follows durable purchase")
		expect.call((scene.get("heard_cues") as Array).count(Sfx.HEARTH_STRENGTH_ID)==1,"Exactly one success sound")
		var candidate: Dictionary = scene.get("_controller_focus_candidate")
		expect.call(not candidate.has("control") or is_instance_valid(candidate["control"]),"Rebuilt service buttons cannot leave a freed controller candidate")
		# Pixel callers observe the actual fade plateau; logic-only callers retain
		# the short asynchronous wait before checking the active service state.
		if not capture.is_valid(): await tree.create_timer(.18).timeout
		var receipt: Control = scene.find_child("MoltShardExchangeFeedback",true,false)
		expect.call(receipt != null and receipt.get_meta("amount")==250 and receipt.get_meta("reduced_motion")==reduced,"Success receipt records exact gain and motion mode")
		if capture.is_valid(): await capture.call("exchange_"+("reduced" if reduced else "normal"))
		expect.call((scene.get("_dialogue_choice_bar") as Control).get_child(0).disabled,"Trade disabled during brief acknowledgment")
		var leave: Button = (scene.get("_dialogue_choice_bar") as Control).get_child(2)
		leave.grab_focus()
		await tree.create_timer(1.0).timeout
		expect.call(scene.find_child("MoltShardExchangeFeedback",true,false)==null and not scene.get("_molt_exchange_feedback").active,"Receipt retires and permits later intentional purchases")
		expect.call(scene.get_viewport().gui_get_focus_owner()!=null and not (scene.get_viewport().gui_get_focus_owner() as BaseButton).disabled,"Focus recovers to a usable service action")
		expect.call(scene.get_viewport().gui_get_focus_owner()==leave,"Fanfare completion preserves the player's newly highlighted Leave action")
		if capture.is_valid(): await capture.call("exchange_focus_"+("reduced" if reduced else "normal"))
	await setup(tree,scene,0)
	scene.call("_exchange_moltshard_at_entrance")
	expect.call(not scene.get("_molt_exchange_feedback").active and (scene.get("heard_cues") as Array).is_empty(),"No shard means no success presentation")
	if capture.is_valid(): await capture.call("exchange_empty")
	await setup(tree,scene,2)
	var blocked: String = ProjectSettings.globalize_path(Store._storage_path+".tmp")
	expect.call(DirAccess.make_dir_absolute(blocked)==OK,"Inject profile save failure")
	scene.call("_exchange_moltshard_at_entrance")
	DirAccess.remove_absolute(blocked)
	expect.call(int((scene.get("_progression") as Dictionary)["moltshards"])==2 and Run.new().held_embers(scene.get("_run_state"))==100,"Failed profile commit spends nothing")
	expect.call(not scene.get("_molt_exchange_feedback").active and (scene.get("heard_cues") as Array).is_empty(),"Failed profile commit has no success cue")
	if capture.is_valid(): await capture.call("exchange_failed_save")
	await setup(tree,scene,2)
	scene.set("fail_next_ack",true)
	scene.call("_exchange_moltshard_at_entrance")
	expect.call(bool(scene.get("blocked_ack_observed")),"Acknowledgment failure was exercised")
	expect.call(scene.get("_molt_exchange_feedback").active and (scene.get("heard_cues") as Array).count(Sfx.HEARTH_STRENGTH_ID)==1 and int(Store.load_data()["embers"])==350,"Committed purchase still celebrates when analytics acknowledgment retries")
	if capture.is_valid(): await capture.call("exchange_ack_retry_success")
	else: await tree.create_timer(.18).timeout
	scene.call("_on_dialogue_option_pressed",{"action":"close"})
	expect.call(not scene.get("_molt_exchange_feedback").active and not bool(scene.get("_dialogue_active")),"Leave cancels the transient receipt immediately")
	await tree.create_timer(1.0).timeout
	expect.call(not bool(scene.get("_dialogue_active")),"Expired receipt cannot reopen a closed dialogue")
	await setup(tree,scene,2)
	scene.call("_exchange_moltshard_at_entrance")
	scene.call("_on_dialogue_option_pressed",{"action":"emaciated_level_up"})
	expect.call(not scene.get("_molt_exchange_feedback").active and (scene.get("_upgrade_scrim") as Control).visible,"Level-up remains usable during the fanfare and cancels it")
	expect.call(Run.new().held_embers(scene.get("_run_state"))==170 and int((scene.get("_progression") as Dictionary)["level"])==2,"Immediate level-up uses the newly credited Embers once")
	await tree.create_timer(1.0).timeout
	expect.call((scene.get("_upgrade_scrim") as Control).visible,"Expired receipt cannot steal level-up focus")
	scene.call("_close_card_upgrade_overlay")
	var saved: Dictionary = await setup(tree,scene,2)
	scene.call("_exchange_moltshard_at_entrance")
	scene.call("_load_run_state",saved)
	expect.call(not scene.get("_molt_exchange_feedback").active,"Loading clears pending presentation")
	await tree.create_timer(1.0).timeout
	expect.call(not scene.get("_molt_exchange_feedback").active,"Old completion does not reenable or reopen loaded UI")
