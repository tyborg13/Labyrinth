extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://card_draw_hand_flow_test")
	ProgressionStore.set_storage_path("user://card_draw_hand_flow_test/progression.json")
	ProgressionStore.set_run_storage_path("user://card_draw_hand_flow_test/current_run.save")
	SettingsStore.set_storage_path("user://card_draw_hand_flow_test/settings.json")
	ProgressionStore.clear_saved_run()
	await _run_opening_hand_entry_regression()
	await _run_transition_regression()
	if _failed:
		print("CARD DRAW HAND FLOW TEST RESULT: FAIL")
		quit(1)
		return
	print("CARD DRAW HAND FLOW TEST RESULT: PASS")
	quit()

func _run_opening_hand_entry_regression() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Run scene should load for opening-hand entry coverage")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")

	var run_engine := RunEngine.new()
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	var combat_coord := Vector2i(999, 999)
	for coord_var: Variant in run_engine.available_moves(run_state):
		if typeof(coord_var) != TYPE_VECTOR2I:
			continue
		var coord: Vector2i = coord_var
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat" and not (preview_state.get("combat_state", {}) as Dictionary).is_empty():
			combat_coord = coord
			break
	_expect(combat_coord != Vector2i(999, 999), "Opening-hand entry coverage needs an available combat room")
	if combat_coord == Vector2i(999, 999):
		instance.queue_free()
		await process_frame
		return

	await instance.call("_on_map_view_room_selected", combat_coord)
	await process_frame
	var preview_scrim: Control = instance.get("_pre_battle_scrim") as Control
	_expect(preview_scrim != null and preview_scrim.visible, "Combat entry should pause on the pre-battle preview before Start")
	var sfx_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_on_pre_battle_start_pressed")
	var hand_box: Control = instance.get("hand_box") as Control
	var objective_hud: Control = instance.get("_combat_objective_hud") as Control
	_expect(preview_scrim != null and not preview_scrim.visible, "Start should uncover the combat room before the opening deal")
	_expect(bool(instance.get("_opening_hand_draw_in_progress")), "Start should enter an explicit opening-hand presentation phase")
	_expect(bool(instance.get("_animation_lock")), "Opening-hand presentation should lock combat input")
	_expect(hand_box != null and not hand_box.visible, "The authoritative complete hand must stay hidden before the first card launches")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "No card proxy should launch before the uncovered room receives its presentation wait")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before, "Draw audio must stay silent while the room is first uncovered")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "prepared", "The uncovered-room frame should pre-stage the objective at upper center before it appears")
	if objective_hud != null:
		var prepared_viewport_size: Vector2 = instance.get_viewport_rect().size
		var prepared_intro_center := Vector2(prepared_viewport_size.x * 0.5, prepared_viewport_size.y * 0.28)
		var prepared_target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position + objective_hud.size * 0.5 == prepared_intro_center, "The hidden objective should already be staged at upper center before the first uncovered-room frame")
		_expect(not objective_hud.position.is_equal_approx(prepared_target_rect.position), "The objective must not flash in its final dock before the center pop")
		_expect(is_zero_approx(objective_hud.modulate.a), "The prepared upper-center objective should stay transparent until its pop begins")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "The prepared objective should keep its widget background and persistent contents hidden")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "The prepared objective should keep the compact icon and detail hidden")

	var objective_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "holding" and Time.get_ticks_msec() < objective_deadline:
		await process_frame
	_expect(objective_hud != null and bool(objective_hud.get("intro_active")), "Battle entry should present the objective before dealing the opening hand")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "holding", "The objective intro should reach its readable upper-center hold")
	_expect(objective_hud != null and objective_hud.visible, "The upper-center objective intro should reuse the visible persistent objective HUD")
	if objective_hud != null:
		var viewport_size: Vector2 = instance.get_viewport_rect().size
		var intro_center := Vector2(viewport_size.x * 0.5, viewport_size.y * 0.28)
		_expect(objective_hud.position + objective_hud.size * 0.5 == intro_center, "The enlarged objective should hold at upper center")
		_expect(objective_hud.scale.x > 2.5, "The text-only objective should be dramatically larger than its permanent HUD size")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "The readable hold should show only objective text without panel chrome")
		var intro_text_stack: Control = objective_hud.get("_intro_text_stack") as Control
		var content_row: Control = objective_hud.get("_content_row") as Control
		_expect(intro_text_stack != null and intro_text_stack.visible and intro_text_stack.modulate.a > 0.99, "The readable hold should show the dedicated OBJECTIVE text treatment")
		_expect(content_row != null and is_zero_approx(content_row.modulate.a), "The icon, live detail, and compact widget copy should remain hidden during the text-only hold")
		_expect(objective_hud.mouse_filter == Control.MOUSE_FILTER_IGNORE, "The objective intro should never intercept pointer input")
	_expect(bool(instance.get("_animation_lock")), "Combat input should remain locked throughout the objective introduction")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Opening cards should wait until the objective has traveled to its HUD position")

	var travel_deadline: int = Time.get_ticks_msec() + 2000
	while objective_hud != null and str(objective_hud.get("intro_phase")) != "traveling" and Time.get_ticks_msec() < travel_deadline:
		await process_frame
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "traveling", "The objective should transition from its center hold toward the permanent HUD")
	await create_timer(0.44).timeout
	if objective_hud != null:
		_expect(objective_hud.scale.x > 1.0 and objective_hud.scale.x < 2.5, "The traveling objective should visibly shrink toward its permanent size")
		var chrome_progress: float = float(objective_hud.get("intro_chrome_progress"))
		_expect(chrome_progress > 0.0 and chrome_progress < 1.0, "The widget background should fade in behind the text during the latter travel")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "The compact widget text and icon should wait until the large text has nearly retired")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Card-deal motion should not compete with the traveling objective")

	var launch_deadline: int = Time.get_ticks_msec() + 3000
	while (
		(instance.get("_draw_hand_transition_proxies") as Array).is_empty()
		and Time.get_ticks_msec() < launch_deadline
	):
		await process_frame
	var opening_hand: Array = ((instance.get("_combat_state") as Dictionary).get("deck", {}) as Dictionary).get("hand", []) as Array
	var launch_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(launch_proxies.size() == opening_hand.size(), "The opening deal should stage every final hand identity once its first card launches")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + 1, "The first draw sound should begin on the same launch tick as the first visible opening card")
	_expect(hand_box != null and not hand_box.visible, "The live complete hand should remain hidden while draw proxies own the deal")

	var completion_deadline: int = Time.get_ticks_msec() + 5000
	while bool(instance.get("_opening_hand_draw_in_progress")) and Time.get_ticks_msec() < completion_deadline:
		await process_frame
	_expect(not bool(instance.get("_opening_hand_draw_in_progress")), "Opening-hand presentation should complete within its authored cadence")
	_expect(not bool(instance.get("_animation_lock")), "Completing the opening deal should restore combat input")
	_expect(hand_box != null and hand_box.visible, "The authoritative playable hand should replace the settled proxies")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Opening-deal proxies should retire at authoritative handoff")
	_expect(_sfx_generation_total(instance.get("_sfx_players") as Array) == sfx_before + opening_hand.size(), "Opening deal should play exactly one synchronized draw sound per visible card")
	var ready_wave_count: int = 0
	if hand_box != null:
		for card_index: int in range(hand_box.get_child_count()):
			var widget: Control = instance.call("_hand_card_control", card_index) as Control
			if widget != null and str(widget.get_meta("ready_wave_reason", "")) == "combat_start":
				ready_wave_count += 1
	_expect(ready_wave_count > 0, "The normal playable-hand ready wave should follow the opening deal")
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "settled", "The objective intro should finish in its persistent HUD state")
	if objective_hud != null:
		var target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position.is_equal_approx(target_rect.position), "The objective should land at the permanent HUD position")
		_expect(objective_hud.scale.is_equal_approx(Vector2.ONE), "The settled objective should return to normal HUD scale")
		_expect(is_equal_approx(float(objective_hud.get("intro_chrome_progress")), 1.0), "The settled objective should restore the complete widget background and content")
		_expect(is_equal_approx(float(objective_hud.get("intro_content_progress")), 1.0), "The settled objective should restore the compact icon, title, and live detail")
		var settled_intro_text: Control = objective_hud.get("_intro_text_stack") as Control
		_expect(settled_intro_text != null and not settled_intro_text.visible, "The separate large intro text should retire after the widget settles")
		_expect(objective_hud.mouse_filter == Control.MOUSE_FILTER_STOP, "The settled objective should restore its existing tooltip interaction")

	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	instance.call("_animate_combat_objective_intro")
	await process_frame
	_expect(objective_hud != null and str(objective_hud.get("intro_phase")) == "reduced_hold", "Reduced Motion should use a static center hold instead of the travel animation")
	_expect(objective_hud != null and objective_hud.get("_intro_tween") == null, "Reduced Motion should not create an objective motion tween")
	if objective_hud != null:
		var reduced_viewport_size: Vector2 = instance.get_viewport_rect().size
		var reduced_intro_center := Vector2(reduced_viewport_size.x * 0.5, reduced_viewport_size.y * 0.28)
		_expect(objective_hud.position + objective_hud.size * 0.5 == reduced_intro_center, "Reduced Motion should retain the clear upper-center objective emphasis")
		_expect(is_equal_approx(objective_hud.scale.x, 2.05), "Reduced Motion should keep the new text treatment large without traveling")
		_expect(is_zero_approx(float(objective_hud.get("intro_chrome_progress"))), "Reduced Motion should preserve the text-only hold before snapping to the complete widget")
		_expect(is_zero_approx(float(objective_hud.get("intro_content_progress"))), "Reduced Motion should keep compact widget content out of its text-only hold")
	var reduced_deadline: int = Time.get_ticks_msec() + 1500
	while objective_hud != null and bool(objective_hud.get("intro_active")) and Time.get_ticks_msec() < reduced_deadline:
		await process_frame
	_expect(objective_hud != null and not bool(objective_hud.get("intro_active")), "Reduced Motion objective emphasis should settle promptly")
	if objective_hud != null:
		var reduced_target_rect: Rect2 = instance.call("_combat_objective_hud_target_rect") as Rect2
		_expect(objective_hud.position.is_equal_approx(reduced_target_rect.position), "Reduced Motion should snap to the same permanent objective HUD position")
		_expect(objective_hud.scale.is_equal_approx(Vector2.ONE), "Reduced Motion should settle at the normal persistent HUD scale")
		_expect(is_equal_approx(float(objective_hud.get("intro_chrome_progress")), 1.0), "Reduced Motion should restore the complete persistent widget after its static hold")
	instance.queue_free()
	await process_frame

func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total

func _run_transition_regression() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Run scene should load for hand-flow coverage")
	if packed == null:
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	var before_state: Dictionary = await _load_combat_fixture(instance)
	await _run_pass_preview_warm_invalidation_regression(instance)
	var intermediate_state: Dictionary = before_state.duplicate(true)
	var intermediate_deck: Dictionary = (intermediate_state.get("deck", {}) as Dictionary).duplicate(true)
	intermediate_deck["hand"] = ["shadow_step", "brace", "quick_stab", "lantern_shot", "patch_up"]
	intermediate_deck["draw"] = []
	intermediate_state["deck"] = intermediate_deck

	# This is the production card-play race: the action state still contains the
	# played card at index zero even though its hand widget has already disappeared.
	var transition: Dictionary = instance.call(
		"_draw_hand_transition_between_states",
		before_state,
		intermediate_state,
		0,
		true
	) as Dictionary
	var target_hand: Array = transition.get("target_hand", []) as Array
	var draw_entries: Array = transition.get("draw_entries", []) as Array
	_expect(target_hand == ["brace", "quick_stab", "lantern_shot", "patch_up"], "Draw transition should remove the played card before authoring final hand slots")
	_expect(draw_entries.size() == 2, "Draw transition should identify both incoming cards")
	if draw_entries.size() == 2:
		_expect(int((draw_entries[0] as Dictionary).get("index", -1)) == 2, "First draw should target final slot two instead of the stale played-card layout")
		_expect(int((draw_entries[1] as Dictionary).get("index", -1)) == 3, "Second draw should target final slot three instead of the stale played-card layout")
		_expect(int((draw_entries[0] as Dictionary).get("total", -1)) == 4, "Draw targets should use the authoritative four-card total")

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
	var hand_box: Control = instance.get("hand_box") as Control
	var initial_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(hand_box != null and not hand_box.visible, "Staged draw should hide the stale live hand")
	_expect(initial_proxies.size() == target_hand.size(), "Staged draw should represent every final hand identity from its first frame")
	instance.call("_refresh_hand_panel")
	_expect(not hand_box.visible, "An incidental locked hand refresh must not expose the stale live hand during staged draw")
	_expect((instance.get("_draw_hand_transition_proxies") as Array).size() == target_hand.size(), "An incidental locked hand refresh must not retire running staged proxies")
	var initial_centers: Array[Vector2] = _proxy_centers(instance, initial_proxies)

	await create_timer(0.07).timeout
	var early_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	var early_centers: Array[Vector2] = _proxy_centers(instance, early_proxies)
	_expect(_moved(initial_centers, early_centers, 0), "First retained card should begin reflowing immediately")
	_expect(_moved(initial_centers, early_centers, 1), "Second retained card should begin reflowing immediately")
	_expect(_moved(initial_centers, early_centers, 2), "First incoming card should begin its arc immediately")
	_expect(not _moved(initial_centers, early_centers, 3, 2.0), "Second incoming card should preserve the authored readable launch stagger")

	await create_timer(0.16).timeout
	var stream_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	var stream_centers: Array[Vector2] = _proxy_centers(instance, stream_proxies)
	_expect(_moved(early_centers, stream_centers, 0), "Retained card reflow should continue while the draw stream advances")
	_expect(_moved(early_centers, stream_centers, 1), "Every retained card should keep flowing instead of freezing around an empty slot")
	_expect(_moved(early_centers, stream_centers, 3), "Second incoming card should launch after its stagger")
	_expect(stream_proxies.size() == target_hand.size(), "No transition frame should drop a hand identity")

	var deadline: int = Time.get_ticks_msec() + 2000
	while not bool(completion.get("done", false)) and Time.get_ticks_msec() < deadline:
		await process_frame
	_expect(bool(completion.get("done", false)), "Multi-card draw transition should complete")
	var settled_proxies: Array = instance.get("_draw_hand_transition_proxies") as Array
	_expect(settled_proxies.size() == target_hand.size(), "Settled staged hand should retain every proxy until authoritative refresh")
	var settled_centers: Array[Vector2] = _proxy_centers(instance, settled_proxies)
	for target_index: int in range(target_hand.size()):
		var card_size: Vector2 = instance.call("_hand_card_size", target_hand.size(), false)
		var target_rect: Rect2 = instance.call("_hand_receive_rect", target_index, target_hand.size(), card_size)
		_expect(settled_centers[target_index].distance_to(target_rect.get_center()) <= 1.0, "Settled proxy %d should occupy its exact authoritative hand slot" % target_index)

	var final_state: Dictionary = intermediate_state.duplicate(true)
	var final_deck: Dictionary = (final_state.get("deck", {}) as Dictionary).duplicate(true)
	final_deck["hand"] = target_hand.duplicate()
	final_state["deck"] = final_deck
	var final_run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	final_run_state["combat_state"] = final_state.duplicate(true)
	instance.set("_combat_state", final_state)
	instance.set("_run_state", final_run_state)
	instance.set("_animating_hand_card_index", -1)
	instance.set("_animation_lock", false)
	instance.set("_hand_panel_signature", "<unset>")
	instance.call("_refresh_ui")
	for _frame: int in range(6):
		await process_frame
	_expect((instance.get("_draw_hand_transition_proxies") as Array).is_empty(), "Authoritative hand refresh should retire every staged proxy")
	_expect(hand_box.visible, "Authoritative hand should become visible on the same refresh that retires proxies")
	for target_index: int in range(target_hand.size()):
		var final_card: Control = instance.call("_hand_card_control", target_index) as Control
		var final_center: Vector2 = final_card.get_global_transform_with_canvas() * (final_card.size * 0.5) if final_card != null else Vector2.ZERO
		_expect(
			final_center.distance_to(settled_centers[target_index]) <= 2.0,
			"Authoritative card %d should replace its proxy without a visible positional snap (proxy=%s real=%s delta=%.2f)" % [
				target_index,
				settled_centers[target_index],
				final_center,
				final_center.distance_to(settled_centers[target_index]),
			]
		)
	instance.queue_free()
	await process_frame

func _run_pass_preview_warm_invalidation_regression(instance: Node) -> void:
	# Production begins warming the next-turn Pass forecast before the staged draw.
	# Hiding a pointer-hovered hand then emits hover-ended while input is locked,
	# changing the forecast key before the warm coroutine finishes.
	instance.set("_hovered_card_index", 0)
	var warm_key: String = str(instance.call("_pass_preview_key"))
	var warm_generation: int = int(instance.get("_pass_preview_warm_generation")) + 1
	instance.set("_pass_preview_warm_generation", warm_generation)
	instance.set("_pass_preview_warm_active", true)
	instance.set("_pass_preview_warm_key", warm_key)
	_expect(bool(instance.get("_pass_preview_warm_active")), "Pass-preview warmup should be active before staged draw invalidation")
	_expect(not warm_key.is_empty(), "Pass-preview warmup should own its scheduled hover key")

	instance.set("_animation_lock", true)
	instance.call("_on_card_hover_ended", 0)
	_expect(int(instance.get("_hovered_card_index")) == -1, "Locked staged draw should still clear the stale card hover")
	_expect(str(instance.call("_pass_preview_key")) != warm_key, "Clearing hover should invalidate the scheduled Pass-preview key")
	_expect(
		bool(instance.call("_finish_pass_preview_cache_warm_if_stale", warm_generation, warm_key)),
		"The current Pass-preview worker should recognize and retire its invalidated key"
	)
	_expect(not bool(instance.get("_pass_preview_warm_active")), "A stale Pass-preview warmup must clear its active lifecycle flag")
	_expect(str(instance.get("_pass_preview_warm_key")).is_empty(), "A stale Pass-preview warmup must release its owned key")
	await instance.call("_await_pass_preview_cache_warm")
	instance.set("_animation_lock", false)

func _load_combat_fixture(instance: Node) -> Dictionary:
	var layout: Dictionary = {
		"name": "Card Draw Hand Flow Test",
		"coord": Vector2i(4, 1),
		"type": "combat",
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [{
			"id": 1,
			"type": "crawler",
			"pos": Vector2i(5, 5),
			"hp": 20,
			"max_hp": 20,
			"block": 0,
		}],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(77104, layout, {
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
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	return combat_state

func _proxy_centers(instance: Node, proxies: Array) -> Array[Vector2]:
	var centers: Array[Vector2]
	for proxy_var: Variant in proxies:
		var proxy: Control = proxy_var as Control
		centers.append((instance.call("_card_proxy_visual_rect", proxy) as Rect2).get_center())
	return centers

func _moved(before: Array[Vector2], after: Array[Vector2], index: int, threshold: float = 0.5) -> bool:
	return index < before.size() and index < after.size() and before[index].distance_to(after[index]) > threshold

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(8):
			row.append("wall" if x == 0 or y == 0 or x == 7 or y == 7 else "stone")
		grid.append(row)
	return grid

func _expect(condition: bool, message: String) -> void:
	if condition:
		return
	_failed = true
	push_error(message)
