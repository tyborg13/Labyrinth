extends RefCounted

const Transition = preload("res://scripts/section_transition.gd")
const Flow = preload("res://scripts/start_room_map_flow.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")

# Invisible fixture values and watchdogs; never applied to production runs.
const FIXTURE_SEED: int = 410
const SETTLE_FRAMES: int = 8
const WAIT_TIMEOUT_MSEC: int = 12000
const BOUNDARY_EPSILON_SECONDS: float = 0.01

static func prepare_storage() -> void:
	Store.set_storage_path("user://section_transition_profile.json")
	Store.set_run_storage_path("user://section_transition_run.save")
	Settings.set_storage_path("user://section_transition_settings.json")
	Analytics.set_storage_dir("user://section_transition_analytics")
	Analytics.clear_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = Settings.DISPLAY_WINDOWED
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Store.save_data(Store.default_data())
	Store.clear_saved_run()

static func fixture(section_index: int = 0, study: String = "reward") -> Dictionary:
	var depth: int = (section_index + 1) * 4
	var profile: Dictionary = Store.default_data()
	profile[Tutorial.PROGRESSION_KEY] = {"version": Tutorial.VERSION, "status": "dismissed", "completed_steps": []}
	var engine := Run.new()
	var options: Dictionary = {"seed": FIXTURE_SEED, "dragon_id": Bosses.boss_id_for_depth(FIXTURE_SEED, depth), "dragon_depth": depth, "dragon_case": study}
	var state: Dictionary = Factory.build(engine, Combat.new(), engine.create_new_run(FIXTURE_SEED, profile), options)
	if study == "reward": state["pending_reward"]["intro_pending"] = false
	return state

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func install(tree: SceneTree, host: Node, state: Dictionary) -> void:
	host.call("_load_run_state", state)
	await settle(tree)
	var deadline: int = Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while bool(host.call("_treasure_presentation_busy")) and Time.get_ticks_msec() < deadline:
		await tree.process_frame

static func event_count(entry: String) -> int:
	var count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type", "") == "section_entered" and event.get("payload", {}).get("entry", "") == entry: count += 1
	return count

static func claim_count() -> int:
	var count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if event.get("event_type", "") == "reward_claimed": count += 1
	return count

static func payout(state: Dictionary) -> Dictionary:
	return {"hp": state["player_hp"], "embers": Run.new().held_embers(state), "relics": state["relics"].duplicate(), "shards": state["progression"]["moltshards"]}

static func run(expect: Callable) -> void:
	var pose: Dictionary = Transition.presentation_at(0.24, false)
	expect.call(is_zero_approx(float(pose["reward_alpha"])) and is_zero_approx(float(pose["camera_y"])), "Reward fades first for 0.24 seconds")
	pose = Transition.presentation_at(0.7, false)
	expect.call(is_equal_approx(float(pose["camera_y"]), -140.0) and is_equal_approx(float(pose["black"]), 1.0) and is_zero_approx(float(pose["music_gain"])), "Descent ends at black, camera down 140px and music silent at 0.70s")
	pose = Transition.presentation_at(1.4, false)
	expect.call(is_equal_approx(float(pose["text_alpha"]), 1.0) and is_zero_approx(float(pose["text_y"])), "Both title lines finish the 8px rise/fade at 1.40s")
	expect.call(is_equal_approx(float(Transition.presentation_at(2.6, false)["painting_scale"]), 1.05), "Centred linear push reaches 1.05 at 2.60s")
	pose = Transition.presentation_at(1.5, true)
	expect.call(is_zero_approx(float(pose["camera_y"])) and is_equal_approx(float(pose["painting_scale"]), 1.0), "Reduced motion removes both camera motion and push-in")
	expect.call(is_equal_approx(Transition.arrival_at(true), 1.7) and is_equal_approx(Transition.duration(true), 2.0), "Reduced motion crossfades 0.30s, holds 1.40s and fades 0.30s; its existing room reveal is immediate")
	expect.call(is_zero_approx(float(Transition.presentation_at(0.12, true)["reward_alpha"])), "Reduced motion fades the reward panel and banner in 0.12 seconds")
	var engine := Run.new()
	for index: int in range(5):
		var reward: Dictionary = fixture(index)
		var claimed: Dictionary = engine.continue_dragon_reward(reward)
		var target: Vector2i = Flow.next_section_destination(claimed, engine)
		expect.call(target == Graph.section(claimed, index + 1)["entry"], "Each non-final cleared dragon leads directly to the next threshold")
		var entered: Dictionary = Flow.transition_entry(claimed, engine, target, "auto_transition")
		expect.call(entered["current_room"] == target and entered["mode"] == "room" and payout(entered) == payout(reward), "Entry preserves already granted heal, Embers, trophy and Moltshards")
		expect.call(Flow.next_section_destination(entered, engine) == Graph.INVALID, "An entered threshold cannot replay the section transition")
	var final: Dictionary = engine.continue_dragon_reward(fixture(5))
	expect.call(final["mode"] == "victory" and Flow.next_section_destination(final, engine) == Graph.INVALID, "Final dragon acknowledgment still completes the ascent")
	var panel := preload("res://scripts/section_map_panel.gd").new()
	panel.call("_build")
	expect.call(panel.find_child("NextSectionButton", true, false) == null and not panel.has_method("_request_onward"), "No Next section control or onward action remains")
	panel.free()

static func run_live(tree: SceneTree, expect: Callable) -> void:
	prepare_storage()
	tree.root.size = Vector2i(1920, 1080)
	var host: Node = load("res://scenes/run_scene.tscn").instantiate()
	tree.root.add_child(host)
	await settle(tree)
	var reward: Dictionary = fixture()
	await install(tree, host, reward)
	var button: Button = host.find_child("DragonRewardContinue", true, false)
	expect.call(button != null and button.text == "CONTINUE", "Live non-final reward exposes CONTINUE")
	button.pressed.emit()
	var transition: Node = host.get("_section_transition")
	expect.call(transition != null and not host.get("_large_map_scrim").visible, "CONTINUE immediately starts descent without a map step")
	if transition == null:
		host.queue_free()
		return
	transition.set_process(false)
	expect.call(Store.load_saved_run()["current_room"] == reward["current_room"] and Store.load_saved_run()["mode"] == "room", "Interrupted descent retains a durable claimed boss-room save")
	transition.advance(0.24)
	for field: String in ["_relic_choice_host", "_relic_choice_banner", "_relic_choice_title"]:
		expect.call(is_zero_approx(host.get(field).modulate.a), "Reward panel and DRAGON VANQUISHED banner fade together: " + field)
	var handoffs: Array[int]
	handoffs.append(0)
	transition.arrived.connect(func() -> void: handoffs[0] += 1)
	transition.advance(1.26)
	expect.call(is_equal_approx(transition.get("_title").get_global_rect().get_center().y, 540.0) and is_equal_approx(transition.get("_eyebrow").get_global_rect().get_center().y, 470.0), "Live title lines use the exact approved 1920x1080 centres")
	expect.call(transition.get("_painting").modulate == Color.WHITE, "Backdrop painting retains full brightness, without map modulation")
	var label: Label = transition.get("_eyebrow")
	expect.call(label.get_theme_font_size("font_size") == 24 and label.get_theme_color("font_color") == preload("res://scripts/ui_palette.gd").GOLD_BRIGHT, "Section numeral uses 24px bright accent gold")
	for line: Label in [label, transition.get("_title")]:
		expect.call(line.get_theme_color("font_shadow_color") == host.get("_relic_choice_title").get_theme_color("font_shadow_color") and line.get_theme_constant("shadow_offset_y") == host.get("_relic_choice_title").get_theme_constant("shadow_offset_y"), "Both title lines copy the existing reward banner shadow")
	var band: ColorRect = transition.get("_text_band")
	expect.call(band.size == Vector2(1920.0, 260.0) and is_equal_approx(band.get_global_rect().get_center().y, 505.0) and band.modulate.a == label.modulate.a, "Full-width band spans 130px above/below the text-block centre and fades with the text")
	transition.advance(1.39)
	expect.call(host.get("_run_state")["current_room"] == reward["current_room"] and handoffs[0] == 0, "No room or music handoff before arrival is black")
	transition.advance(0.02)
	var entered: Dictionary = host.get("_run_state")
	expect.call(entered["current_room"] == Graph.section(entered, 1)["entry"] and entered["mode"] == "room", "Arrival enters the next section entry through the production move/save path")
	expect.call(host.get("board_view").position.is_equal_approx(host.get("_board_centering_target")), "Entry uses its normal run-scene framing before the arrival fade reveals it")
	expect.call(payout(entered) == payout(reward) and handoffs[0] == 1, "Full transition grants rewards once and hands off audio once")
	expect.call(event_count("auto_transition") == 1, "Saved JSONL section entry carries entry=auto_transition exactly once")
	var arrival_track: String = str(host.get("_active_music_id"))
	transition.advance(0.30)
	await settle(tree)
	expect.call(not tree.root.gui_disable_input and not host.get("_animation_lock"), "Arrival releases input after the existing room reveal")
	expect.call(str(host.get("_active_music_id")) == arrival_track, "Existing threshold map handoff does not restart or replace arrival music")

	# Reconstruct the actual on-disk state between claim and entry, then load it.
	var claimed: Dictionary = Run.new().continue_dragon_reward(reward)
	claimed["run_index"] = int(claimed.get("run_index", 0)) + 1
	Store.save_run_state(claimed)
	host.call("_load_run_state", Store.load_saved_run())
	transition = host.get("_section_transition")
	expect.call(transition != null and not host.get("_large_map_scrim").visible, "Load in a claimed cleared boss room immediately starts descent")
	if transition != null:
		transition.set_process(false)
		transition.advance(3.2)
	await settle(tree)
	expect.call(payout(host.get("_run_state")) == payout(reward) and event_count("resume_transition") == 1, "Resume preserves payout and emits entry=resume_transition")
	var saved_entry: Dictionary = Store.load_saved_run()
	host.call("_load_run_state", saved_entry)
	expect.call(host.get("_section_transition") == null, "Loading the entered threshold does not repeat the transition")

	# Exercise real viewport input routing, including the pre-skip lock and menu.
	for kind: String in ["click", "A", "Enter", "Space", "Esc"]:
		var router: Node = tree.root.get_node("InputRouter")
		if kind == "click": router.call("set_modality", "controller")
		host.call("_load_run_state", claimed)
		transition = host.get("_section_transition")
		transition.set_process(false)
		var input: InputEvent = _skip_input(kind)
		tree.root.push_input(input, true)
		await tree.process_frame
		if kind in ["click", "A"]: expect.call(bool(router.call("using_controller")) == (kind == "A"), "Modal skip records the active input device without dispatching another action")
		expect.call(float(transition.get("_arrival_start")) < 0.0, kind + " cannot skip before 0.40s")
		transition.advance(0.4)
		tree.root.push_input(input, true)
		await tree.process_frame
		expect.call(is_equal_approx(float(transition.get("_arrival_start")), 0.4) and not host.get("_menu_scrim").visible, kind + " reaches only skip at 0.40s")
		transition.advance(0.29)
		expect.call(host.get("_run_state")["current_room"] == claimed["current_room"], "Skip retains the fade-to-black before entry")
		transition.advance(0.24)
		expect.call(host.get("_section_transition") != null and host.get("_run_state")["current_room"] == Graph.section(claimed, 1)["entry"], kind + " enters once and retains the full 0.60-second arrival step")
		transition.advance(1.0 - float(transition.get("elapsed")) + BOUNDARY_EPSILON_SECONDS)
		expect.call(host.get("_section_transition") == null, kind + " finishes the arrival step at 1.00s after the earliest skip")
		await settle(tree)

	host.get("_settings")["reduced_motion"] = true
	host.call("_load_run_state", claimed)
	transition = host.get("_section_transition")
	transition.set_process(false)
	transition.advance(1.69)
	expect.call(not transition.get("_entered") and transition.get("_painting").scale == Vector2.ONE, "Reduced motion holds the still title until 1.70s")
	transition.advance(0.30)
	expect.call(not transition.get("_entered"), "Reduced-motion arrival keeps the room covered until 2.00s")
	transition.advance(0.02)
	expect.call(transition.get("_entered"), "Reduced-motion arrival enters at 2.00s")
	await settle(tree)
	expect.call(host.get("_section_transition") == null, "Reduced-motion arrival completes at 2.00s with its immediate existing room reveal")

	host.get("_settings")["reduced_motion"] = false
	host = await _save_failure_cases(tree, host, expect)

	await install(tree, host, fixture(5))
	button = host.find_child("DragonRewardContinue", true, false)
	expect.call(button != null and button.text == "COMPLETE ASCENT", "Final reward retains COMPLETE ASCENT")
	button.pressed.emit()
	expect.call(host.get("_section_transition") == null and host.get("_run_state")["mode"] == "victory", "Final CONTINUE keeps the existing terminal path")
	var deadline: int = Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while bool(host.call("_treasure_presentation_busy")) and Time.get_ticks_msec() < deadline: await tree.process_frame
	host.queue_free()
	await settle(tree)

static func _save_failure_cases(tree: SceneTree, host: Node, expect: Callable) -> Node:
	# Inject one failing atomic write after the claim boundary. Removing the
	# blocker before retry permits the real store to succeed on its next write.
	for test_case: Dictionary in [{"quit": false, "reduced": false, "run_offset": 2}, {"quit": true, "reduced": false, "run_offset": 3}, {"quit": false, "reduced": true, "run_offset": 4}]:
		var quit_after_failure: bool = test_case["quit"]
		var reduced: bool = test_case["reduced"]
		host.get("_settings")["reduced_motion"] = reduced
		var reward: Dictionary = fixture()
		reward["run_index"] = int(reward.get("run_index", 0)) + int(test_case["run_offset"])
		await install(tree, host, reward)
		host.find_child("DragonRewardContinue", true, false).pressed.emit()
		var transition: Node = host.get("_section_transition")
		transition.set_process(false)
		var handoffs: Array[int]
		handoffs.append(0)
		transition.arrived.connect(func() -> void: handoffs[0] += 1)
		var saved_claim: Dictionary = Store.load_saved_run()
		var claims_before: int = claim_count()
		var entries_before: int = event_count("auto_transition") + event_count("resume_transition")
		expect.call(saved_claim.has(Transition.CLAIMED_REWARD_KEY), "Original reward summary is saved atomically with the claim for recovery")
		var blocked_path: String = ProjectSettings.globalize_path("user://section_transition_run.save.tmp")
		DirAccess.make_dir_absolute(blocked_path)
		transition.advance(Transition.arrival_at(reduced) + Transition.ARRIVAL_FADE_SECONDS + BOUNDARY_EPSILON_SECONDS)
		expect.call(not transition.get("_entered") and host.get("_run_state")["current_room"] == reward["current_room"] and Store.load_saved_run()["current_room"] == reward["current_room"], "One-shot entry-save failure retains the cleared boss room in memory and on disk")
		expect.call(host.get("_run_state")["notice"] == Transition.SAVE_FAILURE_NOTICE and transition.get("_arrival_shade").modulate.a == 1.0, "Failure uses the existing Continue notice and rebuilds its claimed screen under black")
		expect.call(event_count("auto_transition") + event_count("resume_transition") == entries_before and handoffs[0] == 0, "Failed destination writes emit no section entry or destination music handoff")
		DirAccess.remove_absolute(blocked_path)
		transition.advance(Transition.reward_fade_seconds(reduced) * 0.5)
		expect.call(is_equal_approx(transition.get("_arrival_shade").modulate.a, 0.5), "Save failure reverses the existing reward fade, including reduced motion")
		transition.advance(Transition.reward_fade_seconds(reduced) * 0.5 + BOUNDARY_EPSILON_SECONDS)
		await settle(tree)
		var retry: Button = host.find_child("DragonRewardContinue", true, false)
		expect.call(host.get("_section_transition") == null and not host.get("_animation_lock") and retry != null and retry.is_visible_in_tree() and retry.text == "CONTINUE", "Reverse finishes on the post-claim reward screen with a working CONTINUE")
		expect.call(payout(host.get("_run_state")) == payout(reward) and claim_count() == claims_before, "Failure and reverse do not repeat payouts or the durable claim receipt")
		if quit_after_failure:
			# Exercise the ordinary quit save, then discard/reload all scene state.
			host.call("_persist_committed_boundary", "section_transition_test_quit")
			var quit_save: Dictionary = Store.load_saved_run()
			host.queue_free()
			await settle(tree)
			host = load("res://scenes/run_scene.tscn").instantiate()
			tree.root.add_child(host)
			await settle(tree)
			host.call("_load_run_state", quit_save)
		else:
			retry.pressed.emit()
		transition = host.get("_section_transition")
		expect.call(transition != null and transition.get("entry") == ("resume_transition" if quit_after_failure else "auto_transition"), "Fail -> quit -> resume and fail -> retry both replay the complete transition")
		if transition != null:
			transition.set_process(false)
			transition.arrived.connect(func() -> void: handoffs[0] += 1)
			expect.call(transition.get("elapsed") == 0.0, "Retry starts from descent at zero")
			transition.advance(3.2)
		await settle(tree)
		expect.call(host.get("_run_state")["current_room"] == Graph.section(reward, 1)["entry"] and not Store.load_saved_run().has(Transition.CLAIMED_REWARD_KEY), "Successful retry saves Section II and removes recovery metadata")
		expect.call(payout(host.get("_run_state")) == payout(reward) and claim_count() == claims_before and event_count("auto_transition") + event_count("resume_transition") == entries_before + 1 and handoffs[0] == 1, "Recovery preserves rewards/claim once and emits only the successful entry/music handoff")
	host.get("_settings")["reduced_motion"] = false
	return host

static func _skip_input(kind: String) -> InputEvent:
	if kind == "click":
		var mouse := InputEventMouseButton.new()
		mouse.button_index = MOUSE_BUTTON_LEFT
		mouse.pressed = true
		return mouse
	if kind == "A":
		var joy := InputEventJoypadButton.new()
		joy.button_index = JOY_BUTTON_A
		joy.pressed = true
		return joy
	var key := InputEventKey.new()
	key.keycode = {"Enter": KEY_ENTER, "Space": KEY_SPACE, "Esc": KEY_ESCAPE}[kind]
	key.pressed = true
	return key
