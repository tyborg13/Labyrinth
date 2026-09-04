extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")

const OUTPUT_DIR: String = "user://probes/card_draw_hand_flow_v1"
const PROBE_VIEWPORT: Vector2i = Vector2i(1920, 1080)

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(PROBE_VIEWPORT)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = PROBE_VIEWPORT
	root.size = PROBE_VIEWPORT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://card_draw_hand_flow_probe"))
	_clear_probe_output(OUTPUT_DIR)
	ProgressionStore.set_storage_path("user://card_draw_hand_flow_probe/progression.json")
	ProgressionStore.set_run_storage_path("user://card_draw_hand_flow_probe/current_run.save")
	SettingsStore.set_storage_path("user://card_draw_hand_flow_probe/settings.json")
	ProgressionStore.clear_saved_run()
	await _capture_hand_flow()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit()

func _capture_hand_flow() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_assert(packed != null, "Run scene should load for card-draw hand-flow proof")
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	await _capture_opening_hand_entry(instance)
	var normal_proof: Dictionary = await _prepare_transition(instance, false)
	var normal_target: Array = normal_proof.get("target_hand", []) as Array
	var normal_completion: Dictionary = normal_proof.get("completion", {}) as Dictionary

	await create_timer(0.08).timeout
	_assert_staged_hand(instance, normal_target, "normal first launch")
	await _save_root_screenshot("%s/card_draw_flow_v1_01_first_launch.png" % OUTPUT_DIR)

	await create_timer(0.16).timeout
	_assert_staged_hand(instance, normal_target, "normal overlapping stream")
	await _save_root_screenshot("%s/card_draw_flow_v1_02_overlapping_stream.png" % OUTPUT_DIR)

	await create_timer(0.14).timeout
	_assert_staged_hand(instance, normal_target, "normal first settle")
	await _save_root_screenshot("%s/card_draw_flow_v1_03_first_settled_second_inflight.png" % OUTPUT_DIR)

	await _await_completion(normal_completion)
	var normal_settled_centers: Array[Vector2] = _proxy_centers(instance)
	_assert_exact_staged_slots(instance, normal_target, normal_settled_centers, "normal settled")
	await _save_root_screenshot("%s/card_draw_flow_v1_04_staged_settled.png" % OUTPUT_DIR)
	await _commit_authoritative_hand(instance, normal_target)
	_assert_authoritative_handoff(instance, normal_target, normal_settled_centers, "normal")
	await _save_root_screenshot("%s/card_draw_flow_v1_05_authoritative_handoff.png" % OUTPUT_DIR)

	var reduced_proof: Dictionary = await _prepare_transition(instance, true)
	var reduced_target: Array = reduced_proof.get("target_hand", []) as Array
	var reduced_completion: Dictionary = reduced_proof.get("completion", {}) as Dictionary
	await create_timer(0.08).timeout
	_assert_staged_hand(instance, reduced_target, "reduced-motion stream")
	for proxy_var: Variant in instance.get("_draw_hand_transition_proxies") as Array:
		var proxy: Control = proxy_var as Control
		_assert(proxy != null and absf(rad_to_deg(proxy.rotation)) <= 3.01, "Reduced-motion draws should omit decorative tilt while settling into the static fan pose")
	await _save_root_screenshot("%s/card_draw_flow_v1_06_reduced_motion_stream.png" % OUTPUT_DIR)
	await _await_completion(reduced_completion)
	var reduced_settled_centers: Array[Vector2] = _proxy_centers(instance)
	_assert_exact_staged_slots(instance, reduced_target, reduced_settled_centers, "reduced-motion settled")
	await _commit_authoritative_hand(instance, reduced_target)
	_assert_authoritative_handoff(instance, reduced_target, reduced_settled_centers, "reduced motion")
	await _save_root_screenshot("%s/card_draw_flow_v1_07_reduced_motion_handoff.png" % OUTPUT_DIR)
	await _capture_real_turn_draw_unlock(instance)
	instance.queue_free()
	await process_frame

func _capture_opening_hand_entry(instance: Node) -> void:
	instance.call("_close_dialogue")
	var run_engine := RunEngine.new()
	var progression: Dictionary = ContextualCombatTutorial.dismiss_tutorial((instance.get("_progression") as Dictionary).duplicate(true))
	instance.set("_progression", progression)
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["progression"] = progression.duplicate(true)
	run_state.erase("guided_combat_scenario_eligible")
	instance.call("_load_run_state", run_state)
	await _settle()
	instance.call("_close_dialogue")
	run_state = (instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_coord := Vector2i(999, 999)
	for coord_var: Variant in run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			combat_coord = coord
			break
	_assert(combat_coord != Vector2i(999, 999), "Opening-hand visual proof needs an available combat room")
	await instance.call("_on_map_view_room_selected", combat_coord)
	await _settle()
	var preview_scrim: Control = instance.get("_pre_battle_scrim") as Control
	_assert(preview_scrim != null and preview_scrim.visible, "Opening-hand proof should begin at the production pre-battle preview")
	await _save_root_screenshot("%s/card_draw_flow_v1_00_pre_battle.png" % OUTPUT_DIR)

	var sfx_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_on_pre_battle_start_pressed")
	var hand_box: Control = instance.get("hand_box") as Control
	var objective_hud: Control = instance.get("_combat_objective_hud") as Control
	_assert(preview_scrim != null and not preview_scrim.visible, "Start should uncover the combat room")
	_assert(hand_box != null and not hand_box.visible, "Opening-hand proof should hide the authoritative complete hand")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Room-reveal proof should precede the first card launch")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before, "Room-reveal proof should precede the first draw sound")
	_assert(objective_hud != null and str(objective_hud.get("intro_phase")) == "prepared", "Room-reveal proof should stage the objective invisibly at upper center")
	if objective_hud != null:
		var prepared_viewport_size: Vector2 = instance.get_viewport_rect().size
		var prepared_center := Vector2(prepared_viewport_size.x * 0.5, prepared_viewport_size.y * 0.28)
		var prepared_target: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_assert(objective_hud.position + objective_hud.size * 0.5 == prepared_center, "Room-reveal proof should place the hidden objective at upper center")
		_assert(not objective_hud.position.is_equal_approx(prepared_target.position), "Room-reveal proof must not show the objective in its final dock before the pop")
		_assert(is_zero_approx(objective_hud.modulate.a), "Room-reveal proof should keep the prepared upper-center objective transparent")
		var prepared_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		_assert(prepared_intro_text != null and is_zero_approx(prepared_intro_text.modulate.a), "Room-reveal proof should keep the transform-independent objective copy transparent before its pop")
		_assert(is_zero_approx(float(objective_hud.get("intro_shadow_progress"))), "Room-reveal proof should keep the objective shadow out of the clean pre-pop frame")
		_assert(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "Room-reveal proof should keep all widget chrome hidden")
	await _save_root_screenshot("%s/card_draw_flow_v1_00_room_revealed.png" % OUTPUT_DIR)
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "The uncovered room should remain card-free for its presentation frame")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before, "The uncovered-room frame should remain silent")
	if objective_hud != null:
		var reveal_viewport_size: Vector2 = instance.get_viewport_rect().size
		var reveal_center := Vector2(reveal_viewport_size.x * 0.5, reveal_viewport_size.y * 0.28)
		var reveal_target: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_assert(objective_hud.position + objective_hud.size * 0.5 == reveal_center, "The first uncovered-room frame should keep the objective at upper center as its pop begins")
		_assert(not objective_hud.position.is_equal_approx(reveal_target.position), "The first uncovered-room frame should never expose the final objective dock")

	var objective_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "holding" and Time.get_ticks_msec() < objective_deadline:
		await process_frame
	_assert(objective_hud != null and str(objective_hud.get("intro_phase")) == "holding", "Objective visual proof should reach the readable upper-center hold")
	var intro_text_stack: Control = objective_hud.get("_intro_text_stack") as Control if objective_hud != null else null
	var intro_kicker: Label = objective_hud.get("_intro_kicker") as Label if objective_hud != null else null
	var intro_title: Label = objective_hud.get("_intro_title") as Label if objective_hud != null else null
	_assert(objective_hud != null and objective_hud.visible, "Objective upper-center proof should show the enlarged text")
	_assert(intro_text_stack != null and intro_text_stack.scale.is_equal_approx(Vector2.ONE), "Objective upper-center proof should render the large copy at native 1x scale")
	_assert(intro_kicker != null and intro_kicker.get_theme_font_size("font_size") == 46, "Objective upper-center proof should use the authored large kicker size")
	_assert(intro_title != null and intro_title.get_theme_font_size("font_size") == 92, "Objective upper-center proof should use the crisp enlarged title size")
	_assert(intro_kicker != null and intro_kicker.get_theme_color("font_shadow_color").a > 0.65, "Objective upper-center proof should show the kicker drop shadow")
	_assert(intro_title != null and intro_title.get_theme_color("font_shadow_color").a > 0.75, "Objective upper-center proof should show the title drop shadow")
	_assert(objective_hud != null and is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "Objective upper-center proof should contain no panel background or compact widget content")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Objective center proof should remain visually separate from the opening deal")
	await _save_root_screenshot("%s/objective_intro_v5_00_shadowed_crisp_text_hold.png" % OUTPUT_DIR)

	var travel_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "traveling" and Time.get_ticks_msec() < travel_deadline:
		await process_frame
	_assert(objective_hud != null and str(objective_hud.get("intro_phase")) == "traveling", "Objective visual proof should reach the center-to-HUD travel")
	var chrome_arrival_deadline: int = Time.get_ticks_msec() + 1000
	while (
		objective_hud != null
		and float(objective_hud.get("intro_chrome_progress")) < 0.5
		and Time.get_ticks_msec() < chrome_arrival_deadline
	):
		await process_frame
	_assert(intro_text_stack != null and intro_text_stack.scale.x > 0.32 and intro_text_stack.scale.x < 1.0, "Objective travel proof should show the text shrinking in flight")
	_assert(objective_hud != null and float(objective_hud.get("intro_shadow_progress")) < 0.01, "Objective travel proof should retire the board-separation shadow before compact content arrives")
	_assert(objective_hud != null and float(objective_hud.get("intro_chrome_progress")) >= 0.5, "Objective travel proof should show the compact widget background appearing behind the text")
	_assert(objective_hud != null and is_zero_approx(float(objective_hud.get("intro_content_progress"))), "Objective travel proof should avoid overlapping the large and compact objective copy")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Objective travel proof should precede opening-card motion")
	await _save_root_screenshot("%s/objective_intro_v5_01_chrome_arriving_shadow_retired.png" % OUTPUT_DIR)

	var content_arrival_deadline: int = Time.get_ticks_msec() + 1000
	while (
		objective_hud != null
		and is_zero_approx(float(objective_hud.get("intro_content_progress")))
		and Time.get_ticks_msec() < content_arrival_deadline
	):
		await process_frame
	var late_intro_text: Control = objective_hud.get("_intro_text_stack") as Control if objective_hud != null else null
	_assert(late_intro_text != null and late_intro_text.modulate.a < 0.01, "Content-arrival proof should fully retire the large objective copy")
	_assert(objective_hud != null and float(objective_hud.get("intro_content_progress")) > 0.0, "Content-arrival proof should capture the compact widget content fading in")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Content-arrival proof should remain separate from opening-card motion")
	await _save_root_screenshot("%s/objective_intro_v5_02_content_arriving.png" % OUTPUT_DIR)

	var launch_deadline: int = Time.get_ticks_msec() + 3000
	while _sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before and Time.get_ticks_msec() < launch_deadline:
		await process_frame
	var opening_hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	_assert((instance.get("_draw_hand_transition_proxies") as Array).size() == opening_hand.size(), "First launch should stage the complete opening-hand composition")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + 1, "First visible launch should start exactly the first draw sound")
	await create_timer(0.07).timeout
	await _save_root_screenshot("%s/card_draw_flow_v1_00_first_opening_card.png" % OUTPUT_DIR)

	await create_timer(0.16).timeout
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) >= sfx_before + 2, "Opening-hand stream should preserve the authored card-by-card cadence")
	await _save_root_screenshot("%s/card_draw_flow_v1_00_opening_stream.png" % OUTPUT_DIR)

	var completion_deadline: int = Time.get_ticks_msec() + 5000
	while bool(instance.get("_opening_hand_draw_in_progress")) and Time.get_ticks_msec() < completion_deadline:
		await process_frame
	_assert(not bool(instance.get("_opening_hand_draw_in_progress")), "Opening-hand visual proof should reach authoritative handoff")
	_assert(not bool(instance.get("_animation_lock")), "Opening-hand visual proof should restore combat input")
	_assert(hand_box != null and hand_box.visible, "Final opening-hand proof should show the playable authoritative hand")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Final opening-hand proof should retire staged proxies")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + opening_hand.size(), "Opening-hand visual proof should play one draw sound per visible card")
	await _save_root_screenshot("%s/card_draw_flow_v1_00_opening_complete.png" % OUTPUT_DIR)

	instance.call("_load_run_state", run_state.duplicate(true))
	await _settle()
	instance.call("_close_dialogue")
	await instance.call("_on_map_view_room_selected", combat_coord)
	await _settle()
	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	var reduced_scrim: Control = instance.get("_pre_battle_scrim") as Control
	_assert(reduced_scrim != null and reduced_scrim.visible, "Reduced Motion proof should begin from the production pre-battle preview")
	instance.call("_on_pre_battle_start_pressed")
	var reduced_phase_deadline: int = Time.get_ticks_msec() + 1500
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "reduced_hold" and Time.get_ticks_msec() < reduced_phase_deadline:
		await process_frame
	_assert(objective_hud != null and str(objective_hud.get("intro_phase")) == "reduced_hold", "Reduced Motion proof should use the static objective hold")
	_assert(objective_hud != null and objective_hud.get("_intro_tween") == null, "Reduced Motion proof should omit center-to-HUD tweening")
	var reduced_intro_text: Control = objective_hud.get("_intro_text_stack") as Control if objective_hud != null else null
	var reduced_intro_title: Label = objective_hud.get("_intro_title") as Label if objective_hud != null else null
	_assert(reduced_intro_text != null and reduced_intro_text.scale.is_equal_approx(Vector2.ONE), "Reduced Motion proof should render its static objective at native 1x scale")
	_assert(reduced_intro_title != null and reduced_intro_title.get_theme_font_size("font_size") == 92, "Reduced Motion proof should retain the crisp enlarged title size")
	_assert(reduced_intro_title != null and reduced_intro_title.get_theme_color("font_shadow_color").a > 0.75, "Reduced Motion proof should retain the shadowed static objective treatment")
	var reduced_hand_box: Control = instance.get("hand_box") as Control
	_assert(reduced_hand_box != null and not reduced_hand_box.visible, "Reduced Motion objective proof should still precede the opening deal")
	_assert(bool(instance.get("_animation_lock")), "Reduced Motion objective proof should keep combat input locked")
	_assert(objective_hud != null and is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "Reduced Motion proof should retain the text-only presentation before snapping to the HUD")
	await _save_root_screenshot("%s/objective_intro_v5_03_reduced_motion_shadowed_text.png" % OUTPUT_DIR)
	var reduced_deadline: int = Time.get_ticks_msec() + 5000
	while bool(instance.get("_opening_hand_draw_in_progress")) and Time.get_ticks_msec() < reduced_deadline:
		await process_frame
	_assert(not bool(instance.get("_opening_hand_draw_in_progress")), "Reduced Motion production entry should complete its opening deal")
	_assert(objective_hud != null and not bool(objective_hud.get("intro_active")), "Reduced Motion objective proof should settle promptly")
	reduced_settings["reduced_motion"] = false
	instance.set("_settings", reduced_settings)

func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total

func _capture_real_turn_draw_unlock(instance: Node) -> void:
	var combat_state: Dictionary = await _load_combat_fixture(instance)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["brace"]
	deck["draw"] = ["patch_up", "lantern_shot"]
	deck["discard"] = ["shadow_step", "quick_stab"]
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_combat_state", combat_state)
	instance.set("_run_state", run_state)
	instance.call("_mark_combat_preview_state_changed")
	instance.set("_hand_panel_signature", "<unset>")
	instance.call("_refresh_ui")
	await _await_initial_presentation(instance)
	instance.set("_hovered_card_index", 0)

	var completion: Dictionary = {"done": false}
	_resolve_enemy_round_and_mark(instance, completion)
	var injected_races: bool = false
	var deadline: int = Time.get_ticks_msec() + 15000
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		if not injected_races and not (instance.get("_draw_hand_transition_proxies") as Array).is_empty():
			injected_races = true
			instance.call("_refresh_hand_panel")
			instance.call("_on_card_hover_ended", 0)
		await process_frame
	_assert(injected_races, "Production turn proof should reach a live staged next-turn draw")
	_assert(bool(completion.get("done", false)), "Production enemy round should finish after staged draw refresh and hover invalidation")
	_assert(not bool(instance.get("_animation_lock")), "Production next-turn handoff should release combat animation lock")
	_assert(not bool(instance.get("_pass_preview_warm_active")), "Production next-turn handoff should retire Pass-preview warmup ownership")
	_assert(str(instance.get("_pass_preview_warm_key")).is_empty(), "Production next-turn handoff should release the Pass-preview warm key")
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Production next-turn handoff should retire staged draw proxies")
	var hand_box: Control = instance.get("hand_box") as Control
	_assert(hand_box != null and hand_box.visible, "Production next-turn handoff should expose the authoritative live hand")
	await _save_root_screenshot("%s/card_draw_flow_v1_08_next_turn_unlocked.png" % OUTPUT_DIR)

	await instance.call("_on_card_pressed", 0)
	_assert(
		int(instance.get("_selected_card_index")) == 0 or int(instance.get("_card_action_choice_index")) == 0,
		"The authoritative next-turn hand should accept card input immediately after draw"
	)
	instance.call("_reset_card_resolution")

func _resolve_enemy_round_and_mark(instance: Node, completion: Dictionary) -> void:
	await instance.call("_resolve_enemy_round")
	completion["done"] = true

func _prepare_transition(instance: Node, reduced_motion: bool) -> Dictionary:
	var before_state: Dictionary = await _load_combat_fixture(instance)
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var intermediate_state: Dictionary = before_state.duplicate(true)
	var intermediate_deck: Dictionary = (intermediate_state.get("deck", {}) as Dictionary).duplicate(true)
	intermediate_deck["hand"] = ["shadow_step", "brace", "quick_stab", "lantern_shot", "patch_up"]
	intermediate_deck["draw"] = []
	intermediate_state["deck"] = intermediate_deck
	var transition: Dictionary = instance.call(
		"_draw_hand_transition_between_states",
		before_state,
		intermediate_state,
		0,
		true
	) as Dictionary
	var target_hand: Array = transition.get("target_hand", []) as Array
	var draw_entries: Array = transition.get("draw_entries", []) as Array
	_assert(target_hand == ["brace", "quick_stab", "lantern_shot", "patch_up"], "Visual proof should target the played-card-free authoritative hand")
	_assert(draw_entries.size() == 2, "Visual proof should stream two incoming cards")
	instance.set("_animating_hand_card_index", 0)
	instance.set("_animation_lock", true)
	instance.call("_refresh_animation_lock_ui")
	await process_frame
	var completion: Dictionary = {"done": false}
	instance.call(
		"_animate_draw_cards_fx_and_complete",
		draw_entries,
		Rect2(),
		0,
		transition,
		completion
	)
	await process_frame
	return {
		"target_hand": target_hand,
		"intermediate_state": intermediate_state,
		"completion": completion,
	}

func _load_combat_fixture(instance: Node) -> Dictionary:
	instance.call("_finish_draw_hand_transition_for_refresh")
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = {
		"name": "Card Draw Flow",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [{"id": 1, "type": "crawler", "pos": Vector2i(5, 5), "hp": 20, "max_hp": 20, "block": 0}],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(77105, layout, {
		"hp": 20,
		"max_hp": 20,
		"deck_cards": ["shadow_step", "brace", "quick_stab", "lantern_shot", "patch_up"],
		"relics": [],
		"hand_size": 3,
		"heal_bonus": 0,
	})
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["shadow_step", "brace", "quick_stab"]
	deck["draw"] = ["patch_up", "lantern_shot"]
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.call("_mark_combat_preview_state_changed")
	instance.set("_animating_hand_card_index", -1)
	instance.set("_animation_lock", false)
	instance.set("_hand_panel_signature", "<unset>")
	instance.call("_refresh_ui")
	await _await_initial_presentation(instance)
	await _settle()
	return combat_state

func _await_initial_presentation(instance: Node) -> void:
	var readiness_deadline: int = Time.get_ticks_msec() + 2000
	while not bool(instance.call("initial_presentation_is_ready")) and Time.get_ticks_msec() < readiness_deadline:
		await process_frame
	_assert(bool(instance.call("initial_presentation_is_ready")), "Card-draw proof fixture should settle deferred hand layout before staging motion")

func _commit_authoritative_hand(instance: Node, target_hand: Array) -> void:
	var final_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
	var final_deck: Dictionary = (final_state.get("deck", {}) as Dictionary).duplicate(true)
	final_deck["hand"] = target_hand.duplicate()
	final_deck["draw"] = []
	final_state["deck"] = final_deck
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"] = final_state.duplicate(true)
	instance.set("_combat_state", final_state)
	instance.set("_run_state", run_state)
	instance.call("_mark_combat_preview_state_changed")
	instance.set("_animating_hand_card_index", -1)
	instance.set("_animation_lock", false)
	instance.set("_hand_panel_signature", "<unset>")
	instance.call("_refresh_ui")
	await _settle()

func _assert_staged_hand(instance: Node, target_hand: Array, label: String) -> void:
	var hand_box: Control = instance.get("hand_box") as Control
	var proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_assert(hand_box != null and not hand_box.visible, "%s should hide the stale live hand" % label)
	_assert((instance.get("_draw_hand_transition_cards") as Array) == target_hand, "%s should retain authoritative target order" % label)
	_assert(proxies.size() == target_hand.size(), "%s should visibly represent every final hand identity" % label)

func _assert_exact_staged_slots(instance: Node, target_hand: Array, centers: Array[Vector2], label: String) -> void:
	_assert_staged_hand(instance, target_hand, label)
	for target_index: int in range(target_hand.size()):
		var card_size: Vector2 = instance.call("_hand_card_size", target_hand.size(), false)
		var target_rect: Rect2 = instance.call("_hand_receive_rect", target_index, target_hand.size(), card_size)
		_assert(centers[target_index].distance_to(target_rect.get_center()) <= 1.0, "%s card %d should settle in its exact final fan slot" % [label, target_index])

func _assert_authoritative_handoff(instance: Node, target_hand: Array, staged_centers: Array[Vector2], label: String) -> void:
	var hand_box: Control = instance.get("hand_box") as Control
	_assert(hand_box != null and hand_box.visible, "%s authoritative hand should be visible" % label)
	_assert((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "%s authoritative hand should retire staged proxies" % label)
	_assert(hand_box.get_child_count() == target_hand.size(), "%s authoritative hand should retain every card" % label)
	for target_index: int in range(target_hand.size()):
		var card: Control = instance.call("_hand_card_control", target_index) as Control
		var final_center: Vector2 = card.get_global_transform_with_canvas() * (card.size * 0.5) if card != null else Vector2.ZERO
		_assert(final_center.distance_to(staged_centers[target_index]) <= 2.0, "%s card %d should replace its proxy without a visible snap" % [label, target_index])

func _await_completion(completion: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + 2000
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_assert(bool(completion.get("done", false)), "Card draw motion should complete before the probe deadline")

func _proxy_centers(instance: Node) -> Array[Vector2]:
	var centers: Array[Vector2]
	for proxy_var: Variant in instance.get("_draw_hand_transition_proxies") as Array:
		var proxy: Control = proxy_var as Control
		centers.append((instance.call("_card_proxy_visual_rect", proxy) as Rect2).get_center())
	return centers

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _settle() -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw()
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	RenderingServer.force_draw()
	await process_frame
	var image: Image = root.get_viewport().get_texture().get_image()
	_assert(image != null, "Card-draw flow proof should capture a renderer image")
	if image == null:
		return
	var source_size: Vector2i = image.get_size()
	var valid_aspect: bool = is_equal_approx(float(source_size.x) / float(source_size.y), float(PROBE_VIEWPORT.x) / float(PROBE_VIEWPORT.y))
	_assert(valid_aspect, "Card-draw flow proof should preserve the 16:9 canvas")
	if not valid_aspect:
		return
	if source_size != PROBE_VIEWPORT:
		image.resize(PROBE_VIEWPORT.x, PROBE_VIEWPORT.y, Image.INTERPOLATE_LANCZOS)
	_assert(image.save_png(ProjectSettings.globalize_path(output_path)) == OK, "Could not save %s" % output_path)

func _clear_probe_output(output_dir: String) -> void:
	var directory := DirAccess.open(output_dir)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		directory.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	quit(1)
