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
const Observer = preload("res://tests/helpers/section_transition_observer.gd")
const Data = preload("res://scripts/game_data.gd")

# Invisible fixture values and watchdogs; never applied to production runs.
const FIXTURE_SEED: int = 410
const SETTLE_FRAMES: int = 8
const WAIT_TIMEOUT_MSEC: int = 12000
const BOUNDARY_EPSILON_SECONDS: float = 0.01
const AUDIO_SETTLE_SECONDS: float = 1.0
const FRAME_SECONDS: float = 1.0 / 60.0
const FRAMING_EPSILON_PX: float = 0.1
const COLOR_EPSILON: float = 0.0001
const SCALE_EPSILON: float = 0.001

class MoveObserver extends Run:
	var move_calls: int = 0
	func move_to_room(state: Dictionary, target: Vector2i) -> Dictionary:
		move_calls += 1
		return super.move_to_room(state, target)

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

static func settle_audio(tree: SceneTree) -> void:
	await tree.create_timer(AUDIO_SETTLE_SECONDS, true, false, true).timeout
	await settle(tree)

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
	var probe := RichTextLabel.new()
	probe.name = "PlaceholderProbe"
	probe.add_text("TODO_DESIGN_LEGACY_REWARD_RULES")
	expect.call(placeholder_labels(probe, false).has("PlaceholderProbe"), "Placeholder guard reads parsed rich text, not only .text")
	probe.free()
	var pose: Dictionary = Transition.presentation_at(0.24, false)
	expect.call(is_zero_approx(float(pose["reward_alpha"])) and is_zero_approx(float(pose["camera_y"])), "Reward fades first for 0.24 seconds")
	pose = Transition.presentation_at(0.7, false)
	expect.call(is_equal_approx(float(pose["camera_y"]), -140.0) and is_equal_approx(float(pose["black"]), 1.0) and is_zero_approx(float(pose["music_gain"])), "Descent ends at black, camera down 140px and music silent at 0.70s")
	pose = Transition.presentation_at(1.4, false)
	expect.call(is_equal_approx(float(pose["text_alpha"]), 1.0) and is_zero_approx(float(pose["text_y"])), "Both title lines finish the 8px rise/fade at 1.40s")
	expect.call(is_equal_approx(float(Transition.presentation_at(2.6, false)["painting_scale"]), 1.05), "Centred linear push reaches 1.05 at 2.60s")
	pose = Transition.presentation_at(1.5, true)
	expect.call(is_zero_approx(float(pose["camera_y"])) and is_equal_approx(float(pose["painting_scale"]), 1.0), "Reduced motion removes both camera motion and push-in")
	expect.call(is_equal_approx(Transition.arrival_at(true), 1.7) and is_equal_approx(Transition.duration(true), 2.0), "Non-map reduced arrival retains its existing 0.30-second black fade and immediate room reveal")
	expect.call(is_zero_approx(float(Transition.presentation_at(0.12, true)["reward_alpha"])), "Reduced motion fades the reward panel and banner in 0.12 seconds")
	expect.call(is_equal_approx(Transition.map_duration(false), 3.0) and is_equal_approx(Transition.map_duration(true), 2.0) and is_equal_approx(Transition.map_crossfade_seconds(false, true), 0.12) and is_equal_approx(Transition.map_crossfade_seconds(true, true), 0.12), "Map arrival ends at 3.00s normal / 2.00s reduced; skip cross-fades in 0.12s")
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
	var offered: Dictionary = fixture()
	var claimed: Dictionary = engine.continue_dragon_reward(offered)
	Transition.remember_claim(claimed, offered["pending_reward"])
	var previously_broken: Dictionary = engine.continue_dragon_reward(offered)
	previously_broken["mode"] = "reward"
	expect.call(Flow.next_section_destination(previously_broken, engine) == Graph.section(claimed, 1)["entry"], "A legacy empty reward screen from an earlier failed entry is recoverable on load")
	var already_entered: Dictionary = claimed.duplicate(true)
	Graph.section(already_entered, 1)["entered"] = true
	expect.call(Flow.next_section_destination(already_entered, engine) == Graph.INVALID, "An already-entered next section cannot be entered again even from a stale cleared-boss save")
	var move_observer := MoveObserver.new()
	for invalid: Vector2i in [Graph.INVALID, claimed["current_room"]]:
		var rejected: Dictionary = Flow.transition_entry(claimed, move_observer, invalid, "auto_transition")
		expect.call(rejected == claimed and move_observer.move_calls == 0, "Invalid transition destinations leave all state unchanged and never reach movement")
	var panel := preload("res://scripts/section_map_panel.gd").new()
	panel.call("_build")
	expect.call(panel.find_child("NextSectionButton", true, false) == null and not panel.has_method("_request_onward"), "No Next section control or onward action remains")
	panel.free()

static func run_live(tree: SceneTree, expect: Callable) -> void:
	prepare_storage()
	tree.root.size = Vector2i(1920, 1080)
	var host: Node = Observer.host()
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
	var starts_before: int = int(host.get("_section_test_music_starts"))
	var entry_saves_before: int = int(host.get("_section_test_entry_saves"))
	var before_invalid: Dictionary = host.get("_run_state").duplicate(true)
	var disk_before_invalid: Dictionary = Store.load_saved_run()
	for invalid: Vector2i in [Graph.INVALID, reward["current_room"]]:
		expect.call(not host.call("_enter_section_from_transition", invalid, "auto_transition"), "Live transition rejects invalid and same-room destinations")
	expect.call(host.get("_run_state") == before_invalid and Store.load_saved_run() == disk_before_invalid and int(host.get("_section_test_entry_saves")) == entry_saves_before, "Rejected live destinations never attempt a save or alter memory/disk state")
	var cursor: Node = tree.root.get_node("CursorFeedback")
	expect.call(cursor.call("glyph_visibility_suppressed"), "In-game transition suppresses the cursor glyph")
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
	transition.advance(1.09)
	expect.call(host.get("_run_state")["current_room"] == reward["current_room"] and handoffs[0] == 0, "No room or music handoff before the 2.60-second map arrival")
	transition.advance(0.02)
	var entered: Dictionary = host.get("_run_state")
	expect.call(entered["current_room"] == Graph.section(entered, 1)["entry"] and entered["mode"] == "room", "Arrival enters the next section entry through the production move/save path")
	expect.call(host.get("board_view").position.is_equal_approx(host.get("_board_centering_target")), "Entry framing settles under the title-to-map cover")
	expect.call(payout(entered) == payout(reward) and handoffs[0] == 1, "Full transition grants rewards once and hands off audio once")
	expect.call(event_count("auto_transition") == 1, "Saved JSONL section entry carries entry=auto_transition exactly once")
	var arrival_track: String = str(host.get("_active_music_id"))
	transition.advance(0.09)
	expect.call(is_equal_approx(host.get("_large_map_scrim").modulate.a, 0.0625) and is_equal_approx(transition.get("_title").modulate.a, 0.9375), "Normal handoff uses cubic in-out at the quarter point")
	transition.advance(0.31)
	var map_backdrop: TextureRect = host.get("_large_map_view").call("transition_backdrop")
	expect.call(transition.get("_painting").get_global_rect().is_equal_approx(map_backdrop.get_global_rect()) and transition.get("_painting").scale == Vector2.ONE and transition.get("_painting").modulate == Color(0.56, 0.54, 0.59), "The completion frame exactly matches map cover-fit framing, scale and brightness")
	await settle_audio(tree)
	expect.call(handoffs[0] == 1 and int(host.get("_section_test_music_starts")) - starts_before == 1, "After the map cross-fade and deferred callbacks there is exactly one arrival and one music playback start")
	expect.call(not cursor.call("glyph_visibility_suppressed"), "Completion restores the cursor glyph")
	expect.call(not tree.root.gui_disable_input and not host.get("_animation_lock"), "Map arrival releases input only after the cross-fade")
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
	for release: String in ["cancel", "exit"]:
		cursor.call("set_glyph_visibility_suppressed", "section_transition_test_other", true)
		host.call("_load_run_state", claimed)
		transition = host.get("_section_transition")
		transition.set_process(false)
		if release == "cancel": transition.cancel()
		else: transition.queue_free()
		await settle(tree)
		expect.call(cursor.call("glyph_visibility_suppressed"), "Transition cleanup preserves another cursor suppression owner")
		cursor.call("set_glyph_visibility_suppressed", "section_transition_test_other", false)
		expect.call(not cursor.call("glyph_visibility_suppressed"), "Transition " + release + " restores its cursor glyph suppression")
	host.call("_load_run_state", saved_entry)

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
		transition.advance(0.06)
		expect.call(host.get("_run_state")["current_room"] == Graph.section(claimed, 1)["entry"] and host.get("_large_map_scrim").visible and is_equal_approx(host.get("_large_map_scrim").modulate.a, 0.5), kind + " skips directly into the map cross-fade, halfway through its 0.12 seconds")
		expect.call(transition.get("_painting").scale == Vector2.ONE * float(Transition.presentation_at(0.4, false)["painting_scale"]), "Skip has no push or reframing during its cross-fade")
		transition.advance(0.06 + BOUNDARY_EPSILON_SECONDS)
		expect.call(host.get("_section_transition") == null and host.get("_large_map_scrim").visible, kind + " finishes on the map at 0.52s after the earliest skip")
		await settle(tree)

	host.get("_settings")["reduced_motion"] = true
	host.call("_load_run_state", claimed)
	transition = host.get("_section_transition")
	transition.set_process(false)
	transition.advance(1.69)
	expect.call(not transition.get("_entered") and transition.get("_painting").scale == Vector2.ONE, "Reduced motion holds the still title until 1.70s")
	transition.advance(0.16)
	expect.call(transition.get("_entered") and host.get("_large_map_scrim").visible and is_equal_approx(host.get("_large_map_scrim").modulate.a, 0.5) and transition.get("_painting").scale == Vector2.ONE, "Reduced-motion arrival is a stationary map cross-fade, halfway at 1.85s")
	transition.advance(0.16)
	expect.call(transition.get("_entered"), "Reduced-motion map arrival is complete at 2.00s")
	await settle(tree)
	expect.call(host.get("_section_transition") == null, "Reduced-motion arrival completes on the map at 2.00s")

	host.get("_settings")["reduced_motion"] = false
	host = await _save_failure_cases(tree, host, expect)
	await _frame_handoffs(tree, host, claimed, expect)
	await _non_map_arrival(tree, host, claimed, expect)

	await install(tree, host, fixture(5))
	button = host.find_child("DragonRewardContinue", true, false)
	expect.call(button != null and button.text == "COMPLETE ASCENT", "Final reward retains COMPLETE ASCENT")
	button.pressed.emit()
	expect.call(host.get("_section_transition") == null and host.get("_run_state")["mode"] == "victory", "Final CONTINUE keeps the existing terminal path")
	var deadline: int = Time.get_ticks_msec() + WAIT_TIMEOUT_MSEC
	while bool(host.call("_treasure_presentation_busy")) and Time.get_ticks_msec() < deadline: await tree.process_frame
	host.queue_free()
	await settle(tree)

# Advance the real scene one displayed frame at a time, including the exact
# frame that persists/opens the destination and the frame that frees the overlay.
static func _frame_handoffs(tree: SceneTree, host: Node, claimed: Dictionary, expect: Callable) -> void:
	for reduced: bool in [false, true]:
		tree.root.get_node("InputRouter").call("set_modality", "controller")
		host.get("_settings")["reduced_motion"] = reduced
		host.call("_load_run_state", claimed)
		var overlay: Node = host.get("_section_transition")
		overlay.set_process(false)
		var handoffs: Array[int] = [0]
		overlay.arrived.connect(func() -> void: handoffs[0] += 1)
		var starts: int = int(host.get("_section_test_music_starts"))
		var arrival: float = Transition.arrival_at(reduced)
		overlay.advance(arrival - FRAME_SECONDS)
		var frame: int = 0
		while is_instance_valid(overlay) and overlay.get("active"):
			overlay.advance(FRAME_SECONDS)
			if overlay.get("active"):
				expect.call(overlay.get("_black").visible and overlay.get("_black").modulate.a == 1.0 and overlay.get("_card").visible and overlay.get("_arrival_shade").modulate.a == 0.0, "Every title-to-map frame keeps opaque coverage over the board: %s / %d" % [str(reduced), frame])
				expect.call(host.get("_large_map_scrim").is_visible_in_tree() and host.get("_large_map_scrim").get_parent() == overlay.get("_surface") and host.get("_large_map_scrim").mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_DISABLED and host.get("_large_map_scrim").focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED, "Every arrival frame draws the actual map above the title painting: %s / %d" % [str(reduced), frame])
				var midpoint: float = arrival + Transition.map_crossfade_seconds(reduced) * 0.5
				if absf(float(overlay.get("elapsed")) - midpoint) < BOUNDARY_EPSILON_SECONDS:
					expect.call(is_equal_approx(host.get("_large_map_scrim").modulate.a, 0.5) and is_equal_approx(overlay.get("_title").modulate.a, 0.5) and is_equal_approx(overlay.get("_text_band").modulate.a, 0.5), "Cubic in-out midpoint fades map in and title/band out together")
			await tree.process_frame
			frame += 1
		var scrim: ColorRect = host.get("_large_map_scrim")
		var painting: TextureRect = host.get("_large_map_view").call("transition_backdrop")
		expect.call(scrim.is_visible_in_tree() and scrim.modulate == Color.WHITE and painting.visible and scrim.get_parent() == host.get("ui_root") and scrim.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED and scrim.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED, "Completion atomically returns the fully open map to its ordinary host")
		await settle_audio(tree)
		expect.call(handoffs[0] == 1 and int(host.get("_section_test_music_starts")) - starts == 1, "Frame-driven arrival starts planning music exactly once after all callbacks")
		# Inspect the last cross-fade sample without freeing it yet, so exact
		# image framing can be compared with the live map's cover-fit rectangle.
		host.call("_load_run_state", claimed)
		overlay = host.get("_section_transition")
		overlay.set_process(false)
		overlay.advance(Transition.map_duration(reduced) - BOUNDARY_EPSILON_SECONDS)
		if not reduced:
			var target: Rect2 = painting.get_global_rect()
			expect.call(overlay.get("_painting").get_global_rect().position.distance_to(target.position) < FRAMING_EPSILON_PX and overlay.get("_painting").get_global_rect().size.distance_to(target.size) < FRAMING_EPSILON_PX and overlay.get("_painting").scale.distance_to(Vector2.ONE) < SCALE_EPSILON, "Final normal cross-fade frame matches the real map cover-fit geometry without a framing jump")
			var tint: Color = overlay.get("_painting").modulate
			expect.call(absf(tint.r - 0.56) < COLOR_EPSILON and absf(tint.g - 0.54) < COLOR_EPSILON and absf(tint.b - 0.59) < COLOR_EPSILON, "Final painting brightness lands on the map's own modulate")
		overlay.cancel()
		await settle(tree)
		expect.call(scrim.get_parent() == host.get("ui_root") and painting.visible and scrim.mouse_behavior_recursive == Control.MOUSE_BEHAVIOR_INHERITED and scrim.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_INHERITED, "Cancellation restores live map ownership, backdrop and input")
		host.call("_load_run_state", claimed)
		overlay = host.get("_section_transition")
		overlay.set_process(false)
		overlay.advance(arrival + BOUNDARY_EPSILON_SECONDS)
		overlay.queue_free()
		await settle(tree)
		expect.call(is_instance_valid(scrim) and scrim.get_parent() == host.get("ui_root") and painting.visible and not tree.root.get_node("CursorFeedback").call("glyph_visibility_suppressed"), "Tree exit restores the actual map and cursor after a handoff has begun")
		host.call("_close_large_map")
		expect.call(not scrim.visible and host.get("_run_state")["current_room"] == Graph.section(claimed, 1)["entry"], "Closing the fully open map reveals the loaded entry room")
	host.get("_settings")["reduced_motion"] = false

static func _non_map_arrival(tree: SceneTree, host: Node, claimed: Dictionary, expect: Callable) -> void:
	# A threshold with opening narration cannot auto-open its map. Its former
	# black arrival and room reveal remain intact, including deferred narration.
	var narrated: Dictionary = claimed.duplicate(true)
	var target: Vector2i = Graph.section(narrated, 1)["entry"]
	Graph.room(narrated, target)["npcs"] = [{"id": "emaciated_man"}]
	for reduced: bool in [false, true]:
		host.get("_settings")["reduced_motion"] = reduced
		host.call("_load_run_state", narrated)
		var overlay: Node = host.get("_section_transition")
		overlay.set_process(false)
		expect.call(not overlay.get("_map_arrival"), "Narrated destination retains the non-map arrival")
		overlay.advance(Transition.arrival_at(reduced) + Transition.ARRIVAL_FADE_SECONDS - BOUNDARY_EPSILON_SECONDS)
		expect.call(not overlay.get("_entered") and not host.get("_large_map_scrim").visible, "Non-map arrival keeps the original black fade before entry")
		overlay.advance(BOUNDARY_EPSILON_SECONDS * 2.0)
		expect.call(overlay.get("_entered") and not host.get("_large_map_scrim").visible, "Non-map arrival enters the board without opening a map")
		if overlay.get("active"): overlay.advance(Transition.duration(reduced) - float(overlay.get("elapsed")) + BOUNDARY_EPSILON_SECONDS)
		await settle(tree)
		expect.call(host.get("_section_transition") == null, "Non-map arrival keeps its existing normal/reduced completion timing")
	host.get("_settings")["reduced_motion"] = false

static func _save_failure_cases(tree: SceneTree, host: Node, expect: Callable) -> Node:
	# Inject one failing atomic write after the claim boundary. Removing the
	# blocker before retry permits the real store to succeed on its next write.
	var cases: Array[Dictionary]
	for format: String in ["new", "old", "old_no_offer"]:
		for quit_after: bool in [false, true]:
			for reduced: bool in [false, true]:
				cases.append({"format": format, "quit": quit_after, "reduced": reduced, "run_offset": cases.size() + 2})
	for format: String in ["old_broken", "old_no_relic", "old_placeholder"]:
		for quit_after: bool in [false, true]:
			cases.append({"format": format, "quit": quit_after, "reduced": false, "run_offset": cases.size() + 2})
	for test_case: Dictionary in cases:
		var quit_after_failure: bool = test_case["quit"]
		var reduced: bool = test_case["reduced"]
		host.get("_settings")["reduced_motion"] = reduced
		var reward: Dictionary = fixture()
		reward["run_index"] = int(reward.get("run_index", 0)) + int(test_case["run_offset"])
		reward["pending_reward"]["milestone_id"] += ":recovery_%d" % int(test_case["run_offset"])
		if test_case["format"] == "new":
			await install(tree, host, reward)
			host.find_child("DragonRewardContinue", true, false).pressed.emit()
		else:
			if test_case["format"] == "old":
				await install(tree, host, reward)
				host.call("_analytics_log_reward_offered", {}, "section_transition_legacy_fixture")
			var legacy: Dictionary = Run.new().continue_dragon_reward(reward)
			if test_case["format"] == "old_broken": legacy["mode"] = "reward"
			if test_case["format"] == "old_no_relic": (legacy["relics"] as Array).erase(reward["pending_reward"]["relic_id"])
			expect.call(not legacy.has(Transition.CLAIMED_REWARD_KEY), "Old-format fixture has no presentation metadata")
			if test_case["format"] == "old_placeholder":
				legacy[Transition.CLAIMED_REWARD_KEY] = {"kind": "dragon", "boss_id": reward["pending_reward"]["boss_id"], "relic_id": reward["pending_reward"]["relic_id"], "intro_pending": false, "payout_text": "TODO_DESIGN_old_save_payout", "shard_text": "TODO_DESIGN_old_save_shards"}
			expect.call(Store.save_run_state(legacy), "Legacy fixture is persisted before loading")
			host.call("_load_run_state", Store.load_saved_run())
		var transition: Node = host.get("_section_transition")
		transition.set_process(false)
		var handoffs: Array[int]
		handoffs.append(0)
		transition.arrived.connect(func() -> void: handoffs[0] += 1)
		var saved_claim: Dictionary = Store.load_saved_run()
		var claims_before: int = claim_count()
		var entries_before: int = event_count("auto_transition") + event_count("resume_transition")
		expect.call(saved_claim.has(Transition.CLAIMED_REWARD_KEY), "New claims save their summary atomically; old saves migrate it before descent")
		var summary: Dictionary = saved_claim[Transition.CLAIMED_REWARD_KEY]
		var expected_relic: String = "" if test_case["format"] == "old_no_relic" else str(reward["pending_reward"]["relic_id"])
		expect.call(summary["kind"] == "dragon" and summary["boss_id"] == reward["pending_reward"]["boss_id"] and summary["relic_id"] == expected_relic, "Migration preserves only recorded reward identities")
		if test_case["format"] in ["new", "old"]:
			for key: String in ["ember_amount", "healed_amount", "moltshards"]:
				expect.call(summary[key] == reward["pending_reward"][key], "Exact historical reward delta is recovered: " + key)
		if test_case["format"] != "old_placeholder":
			expect.call(not summary.has("payout_text") and not summary.has("shard_text"), "Migration creates no placeholder copy for unavailable totals")
		var claim_calls_before: int = int(host.get("_section_test_claim_calls"))
		var blocked_path: String = ProjectSettings.globalize_path("user://section_transition_run.save.tmp")
		DirAccess.make_dir_absolute(blocked_path)
		transition.advance(Transition.arrival_at(reduced) + Transition.ARRIVAL_FADE_SECONDS + BOUNDARY_EPSILON_SECONDS)
		expect.call(not transition.get("_entered") and host.get("_run_state")["current_room"] == reward["current_room"] and Store.load_saved_run()["current_room"] == reward["current_room"], "One-shot entry-save failure retains the cleared boss room in memory and on disk")
		expect.call(host.get("_run_state")["notice"] == "Could not save. Your rewards are still here; try Continue again." and transition.get("_arrival_shade").modulate.a == 1.0, "Failure uses the existing Continue notice and rebuilds its claimed screen under black")
		expect.call(event_count("auto_transition") + event_count("resume_transition") == entries_before and handoffs[0] == 0, "Failed destination writes emit no section entry or destination music handoff")
		DirAccess.remove_absolute(blocked_path)
		transition.advance(Transition.reward_fade_seconds(reduced) * 0.5)
		expect.call(is_equal_approx(transition.get("_arrival_shade").modulate.a, 0.5), "Save failure reverses the existing reward fade, including reduced motion")
		transition.advance(Transition.reward_fade_seconds(reduced) * 0.5 + BOUNDARY_EPSILON_SECONDS)
		await settle(tree)
		var retry: Button = host.find_child("DragonRewardContinue", true, false)
		expect.call(host.get("_section_transition") == null and not host.get("_animation_lock") and retry != null and retry.is_visible_in_tree() and retry.text == "CONTINUE", "Reverse finishes on the post-claim reward screen with a working CONTINUE")
		assert_reward_screen(host, str(reward["pending_reward"]["boss_id"]), expected_relic, test_case["format"] == "new", expect)
		expect.call(payout(host.get("_run_state")) == payout(saved_claim) and claim_count() == claims_before, "Failure and reverse do not repeat payouts or the durable claim receipt")
		if quit_after_failure:
			# Exercise the ordinary quit save, then discard/reload all scene state.
			host.call("_persist_committed_boundary", "section_transition_test_quit")
			var quit_save: Dictionary = Store.load_saved_run()
			host.queue_free()
			await settle(tree)
			host = Observer.host()
			tree.root.add_child(host)
			await settle(tree)
			host.get("_settings")["reduced_motion"] = reduced
			host.call("_load_run_state", quit_save)
			claim_calls_before = 0
		else:
			retry.pressed.emit()
		transition = host.get("_section_transition")
		expect.call(transition != null and transition.get("entry") == ("resume_transition" if quit_after_failure else "auto_transition"), "Fail -> quit -> resume and fail -> retry both replay the complete transition")
		var starts_before: int = int(host.get("_section_test_music_starts"))
		if transition != null:
			transition.set_process(false)
			transition.arrived.connect(func() -> void: handoffs[0] += 1)
			expect.call(transition.get("elapsed") == 0.0, "Retry starts from descent at zero")
			transition.advance(Transition.arrival_at(reduced) + Transition.ARRIVAL_FADE_SECONDS + BOUNDARY_EPSILON_SECONDS)
			if transition.get("active"): transition.advance(Transition.duration(reduced) - float(transition.get("elapsed")) + BOUNDARY_EPSILON_SECONDS)
		await settle_audio(tree)
		expect.call(int(host.get("_section_test_claim_calls")) == claim_calls_before, "Claimed-reward retry and resume bypass the claim transaction entirely")
		expect.call(handoffs[0] == 1 and int(host.get("_section_test_music_starts")) - starts_before == 1, "After completion and deferred callbacks, recovery has exactly one arrival and music playback start")
		expect.call(host.get("_run_state")["current_room"] == Graph.section(reward, 1)["entry"] and not Store.load_saved_run().has(Transition.CLAIMED_REWARD_KEY), "Successful retry saves Section II and removes recovery metadata")
		expect.call(payout(host.get("_run_state")) == payout(saved_claim) and claim_count() == claims_before and event_count("auto_transition") + event_count("resume_transition") == entries_before + 1 and handoffs[0] == 1, "Recovery preserves rewards/claim once and emits only the successful entry/music handoff")
	host.get("_settings")["reduced_motion"] = false
	return host

# Compare the live visible result against the owner decision, not migration
# flags/constants. Rows must not exist; merely hiding their text is insufficient.
static func assert_reward_screen(host: Node, boss_id: String, relic_id: String, totals: bool, expect: Callable) -> void:
	var defeated: Label = host.find_child("DragonRewardDefeated", true, false)
	expect.call(defeated != null and defeated.is_visible_in_tree() and defeated.text == "%s defeated" % str(Data.enemy_def(boss_id)["name"]), "Restored reward shows the recorded dragon name")
	var relic: Label = host.find_child("DragonRewardRelic", true, false)
	var rules: RichTextLabel = host.find_child("DragonRewardRules", true, false)
	if relic_id.is_empty():
		expect.call(relic == null and rules == null and host.find_child("DragonRewardArtwork", true, false) == null and host.find_child("DragonRewardDestination", true, false) == null, "Unrecorded relic rows and artwork are absent")
	else:
		expect.call(relic != null and relic.is_visible_in_tree() and relic.text == str(Data.relic_def(relic_id)["name"]) and rules != null and rules.is_visible_in_tree() and not rules.get_parsed_text().is_empty(), "Recorded relic and its rules remain visible")
	for row: String in ["DragonRewardPayout", "DragonRewardShard"]:
		var label: Label = host.find_child(row, true, false)
		expect.call(label != null and label.is_visible_in_tree() if totals else label == null, "Totals row visible only for a complete recorded summary: " + row)
	var placeholders: Array[String] = placeholder_labels(host)
	expect.call(placeholders.is_empty(), "No visible label contains internal design placeholders: " + ", ".join(placeholders))
	var button: Button = host.find_child("DragonRewardContinue", true, false)
	expect.call(button != null and button.is_visible_in_tree() and button.text == "CONTINUE", "Known-only legacy reward retains CONTINUE")

static func placeholder_labels(root: Node, require_visible: bool = true) -> Array[String]:
	# Rich labels built with add_text() keep .text empty, so read their parsed text.
	var found: Array[String] = []
	var nodes: Array = [root]
	nodes.append_array(root.find_children("*", "", true, false))
	for node: Node in nodes:
		if not (node is Label or node is RichTextLabel):
			continue
		if require_visible and not (node as Control).is_visible_in_tree():
			continue
		var shown: String = (node as RichTextLabel).get_parsed_text() if node is RichTextLabel else (node as Label).text
		if shown.contains("TODO_DESIGN"):
			found.append(str(node.name))
	return found

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
