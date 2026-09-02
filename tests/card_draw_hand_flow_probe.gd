extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

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
