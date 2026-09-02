extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute("user://card_draw_hand_flow_test")
	ProgressionStore.set_storage_path("user://card_draw_hand_flow_test/progression.json")
	ProgressionStore.set_run_storage_path("user://card_draw_hand_flow_test/current_run.save")
	SettingsStore.set_storage_path("user://card_draw_hand_flow_test/settings.json")
	ProgressionStore.clear_saved_run()
	await _run_transition_regression()
	if _failed:
		print("CARD DRAW HAND FLOW TEST RESULT: FAIL")
		quit(1)
		return
	print("CARD DRAW HAND FLOW TEST RESULT: PASS")
	quit()

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
