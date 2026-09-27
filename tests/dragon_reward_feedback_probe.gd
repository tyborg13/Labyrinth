extends SceneTree
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "user://probes/dragon_reward_feedback_v3"
var scene: Node
var canvas: SubViewport
var failed: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")
func _run() -> void:
	Store.set_storage_path("user://reward_feedback_profile.json")
	Store.set_run_storage_path("user://reward_feedback_run.save")
	Settings.set_storage_path("user://reward_feedback_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920,1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version":Tutorial.VERSION,"status":"dismissed","completed_steps":[]}
	profile["moltshards"] = 1
	profile["embers"] = 100
	profile["run_counter"] = 8
	var state: Dictionary = engine.create_new_run(2926, profile)
	await _load(state)
	scene.call("_speak_to_emaciated_man")
	await _capture("awakening_intro")
	expect(bool((scene.get("_dialogue_script") as Dictionary).get("marks_emaciated_awakening_seen",false)), "First post-dragon Speak presents narrative introduction")
	scene.call("_close_dialogue")
	expect(not Store.emaciated_services_unlocked(scene.get("_progression")), "Interrupted introduction does not unlock service")
	scene.call("_speak_to_emaciated_man")
	scene.call("_show_dialogue_line", 2)
	scene.call("_complete_current_dialogue_line")
	await _capture("awakening_final_line")
	var blocked_path: String = ProjectSettings.globalize_path("user://reward_feedback_profile.json.tmp")
	DirAccess.make_dir_recursive_absolute(blocked_path)
	scene.call("_close_dialogue")
	expect(not Store.emaciated_services_unlocked(scene.get("_progression")), "Failed save leaves introduction due")
	DirAccess.remove_absolute(blocked_path)
	scene.call("_speak_to_emaciated_man")
	scene.call("_show_dialogue_line", 2)
	scene.call("_complete_current_dialogue_line")
	scene.call("_advance_dialogue")
	expect(Store.emaciated_services_unlocked(Store.load_data()), "Completed narrative saves permanent service unlock")
	scene.call("_refresh_ui")
	await process_frame
	scene.call("_close_large_map")
	await _capture("separate_room_actions")
	var choices: Control = scene.get("_context_choice_bar")
	expect(choices.get_child_count() == 2, "Speak and Awaken Power are separate room actions")
	var awaken: Button = choices.get_child(1) as Button
	expect(awaken.text == "Awaken Power", "Second room action is explicitly named")
	expect((scene.call("_controller_navigation_candidates") as Array).any(func(candidate: Dictionary) -> bool: return candidate.get("control",null) == awaken), "Room action participates in controller navigation")
	awaken.grab_focus()
	await _capture("awaken_keyboard_focus")
	scene.set("_controller_focus_candidate", scene.call("_controller_candidate_for_control", awaken))
	scene.call("_controller_activate_current")
	await _capture("awaken_funded")
	expect(bool((scene.call("_current_dialogue_line") as Dictionary).get("service",false)), "Controller activates the separate service action")
	scene.call("_on_dialogue_option_pressed", {"action":"exchange_moltshard"})
	await _capture("awaken_trade_receipt")
	expect(str(scene.call("_board_status_label", {})).is_empty(), "Service dialogue suppresses the unrelated Choose Door prompt")
	expect(engine.held_embers(scene.get("_run_state")) == 350, "One trade credits live wallet")
	scene.call("_close_dialogue")
	scene.call("_speak_to_emaciated_man")
	expect(not bool((scene.call("_current_dialogue_line") as Dictionary).get("service",false)), "Repeat Speak remains ordinary dialogue")
	scene.call("_close_dialogue")
	# Standard acquisition, blocking/repeated activation, and smooth map arrival.
	state = _reward_state(engine, combat, "vyraketh", profile)
	await _load(state)
	await _capture("reward_before_continue")
	var button: Button = scene.find_child("DragonRewardContinue", true, false)
	button.grab_focus()
	button.pressed.emit()
	expect(str((scene.get("_run_state") as Dictionary)["mode"]) == "room" and bool(scene.get("_relic_claim_in_progress")), "Claim commits synchronously before presentation")
	var saved: Dictionary = Store.load_saved_run()
	expect(str(saved.get("mode","")) == "room", "Interruption during delivery resumes saved room")
	scene.call("_on_dragon_reward_continue")
	await create_timer(0.17).timeout
	await _capture("relic_standard_delivery")
	expect(scene.find_child("RelicAcquisitionBeam",true,false) != null, "Dragon uses standard relic beam")
	expect(not (scene.get("_large_map_scrim") as Control).visible, "Map is hidden during delivery")
	await _wait_phase("settlement")
	await _capture("relic_hud_settlement")
	expect(not (scene.get("_large_map_scrim") as Control).visible, "Map remains hidden during settlement")
	await _wait_phase("map_transition")
	await create_timer(0.09).timeout
	await _capture("map_fade")
	await _wait_complete()
	await _capture("map_ready")
	expect((scene.get("_large_map_scrim") as Control).visible and is_equal_approx((scene.get("_large_map_scrim") as Control).modulate.a,1.0), "Map settles fully visible after delivery")
	# Reduced motion keeps final states and completion without beam travel.
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, root, false)
	scene.set("_settings", settings)
	await _load(_reward_state(engine,combat,"vyraketh",profile))
	scene.call("_on_dragon_reward_continue")
	await process_frame
	expect(scene.find_child("RelicAcquisitionBeam",true,false) == null, "Reduced motion omits moving beam")
	await _capture("reduced_motion_receipt")
	await _wait_complete()
	await _capture("reduced_motion_map")
	# Final trophy is explicitly delivered to the next-run receipt, not current HUD.
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, root, false)
	scene.set("_settings", settings)
	await _load(_reward_state(engine,combat,"noctyrax",profile))
	scene.call("_on_dragon_reward_continue")
	await create_timer(0.17).timeout
	await _capture("next_run_trophy_delivery")
	await _wait_complete()
	expect(str((scene.get("_run_state") as Dictionary)["mode"]) == "victory", "Final dragon reaches recap after delivery")
	# Cancel a sleeping delivery by loading its already committed snapshot.
	await _load(_reward_state(engine,combat,"vyraketh",profile))
	scene.call("_on_dragon_reward_continue")
	await process_frame
	saved = Store.load_saved_run()
	await _load(saved)
	expect(not bool(scene.get("_relic_claim_in_progress")) and scene.find_child("RelicAcquisitionBeam",true,false) == null, "Resume cancels transient delivery and preserves the committed claim")
	print("DRAGON REWARD FEEDBACK PROOF: ", "PASS" if failed == 0 else "FAIL")
	canvas.queue_free()
	await process_frame
	quit(1 if failed else 0)
func _reward_state(engine: RefCounted, combat: RefCounted, id: String, profile: Dictionary) -> Dictionary:
	var options := {"dragon_id":id,"dragon_depth":24 if id == "noctyrax" else 4,"dragon_case":"reward"}
	var state: Dictionary = Factory.build(engine,combat,engine.create_new_run(Factory.seed_for_options(options),profile),options)
	state["pending_reward"]["intro_pending"] = false
	return state
func _load(state: Dictionary) -> void:
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	scene.call("_close_large_map")
	await create_timer(0.15).timeout
func _wait_phase(phase: String) -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while str(scene.get("_relic_delivery_phase")) != phase and bool(scene.get("_relic_claim_in_progress")) and Time.get_ticks_msec() < deadline: await process_frame
	expect(str(scene.get("_relic_delivery_phase")) == phase, "Presentation reaches " + phase)
func _wait_complete() -> void:
	var deadline: int = Time.get_ticks_msec() + 5000
	while bool(scene.get("_relic_claim_in_progress")) and Time.get_ticks_msec() < deadline: await process_frame
	expect(not bool(scene.get("_relic_claim_in_progress")), "Presentation completes in bounded time")
func _capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	expect(image.get_size() == Vector2i(1920,1080), "Native 1920x1080 proof")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT,label]
	expect(image.save_png(path) == OK, "PNG saved")
	print(ProjectSettings.globalize_path(path))
func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
