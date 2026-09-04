extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const ItemRules = preload("res://scripts/battlefield_item_rules.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const Cursor = preload("res://scripts/controller_analog_cursor.gd")
const CardWidget = preload("res://scripts/card_widget.gd")

static func run(expect: Callable) -> void:
	_test_collection_and_consumption(expect)
	_test_full_hand_and_slots(expect)
	_test_restore_and_legacy(expect)
	_test_rich_controller_previews(expect)
	_test_missed_pickups(expect)
	_test_pickup_analytics(expect)
	_test_blink_and_forced_movement(expect)

static func _state(equipped: Array = [], hand: Array = [], inventory: Array = []) -> Dictionary:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("stone" if x > 0 and x < 8 and y > 0 and y < 8 else "wall")
		grid.append(row)
	var state: Dictionary = CombatEngine.new().create_combat(82, {
		"coord": Vector2i(1, 0), "depth": 1, "grid": grid, "player_start": Vector2i(1, 3),
		"enemies": [{"id": 1, "type": "warden", "pos": Vector2i(6, 3), "hp": 50, "max_hp": 50}],
		"loot": [{"id": "a", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(2, 3)}, {"id": "b", "kind": "item", "card_id": "crimson_draught", "pos": Vector2i(3, 3)}]
	}, {"hp": 10, "max_hp": 24, "deck_cards": [], "equipped_items": equipped, "item_inventory": inventory})
	state["deck"] = {"hand": hand.duplicate(), "draw": [], "discard": [], "burned": [], "consumed": [], "cycles": 0}
	return state

static func _test_collection_and_consumption(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var engine := RunEngine.new()
	var before: Dictionary = _state()
	var state: Dictionary = combat.apply_player_movement(before, Vector2i(3, 3))
	expect.call(state["deck"]["hand"] == ["crimson_draught", "crimson_draught"], "A route crossing two pickups should grant two distinct copies immediately")
	expect.call(state["equipped_items"] == ["crimson_draught", "crimson_draught"], "Each collected copy occupies one item slot")
	expect.call(before["deck"]["hand"].is_empty() and not before["loot"][0].get("claimed", false), "Movement previews must not mutate their source state")
	expect.call(int(state["player"]["hp"]) == 10 and int(state["player"]["block"]) == 0, "Collection itself must not heal or grant block")
	state = combat.apply_player_action(state, GameData.card_def("crimson_draught")["actions"][0], Vector2i(-1, -1))
	expect.call(int(state["player"]["hp"]) == 12, "The acquired item can be used on the same activation for its rebalanced effect")
	state = combat.finish_player_card(state, 0)
	expect.call(state["equipped_items"] == ["crimson_draught"] and state["deck"]["consumed"] == ["crimson_draught"], "Consumption removes only one duplicate copy")
	expect.call(state["deck"]["discard"].is_empty() and state["deck"]["burned"].is_empty(), "Consumed items never return through discard or exhaust")
	var run_state: Dictionary = engine.create_new_run(82, ProgressionStore.default_data())
	run_state["mode"] = "combat"
	run_state = engine.set_combat_state(run_state, state)
	expect.call(engine.loadout_asset_is_new(run_state, "equipment", "crimson_draught"), "Battlefield acquisitions receive the same NEW indication as purchased items")
	run_state = engine.mark_loadout_asset_seen(run_state, "equipment", "crimson_draught")
	var repeated: Dictionary = engine.set_combat_state(run_state, state)
	expect.call(not engine.loadout_asset_is_new(repeated, "equipment", "crimson_draught"), "Recommitting a pickup must not restore an acknowledged NEW tag")
	expect.call(repeated["equipped_items"] == run_state["equipped_items"] and repeated["deck_cards"] == run_state["deck_cards"], "Repeated combat commits must not duplicate acquisitions or consumption")
	expect.call((repeated["deck_cards"] as Array).count("crimson_draught") == 1, "Only the surviving copy belongs to future decks")
	var preserved: Dictionary = _state(["crimson_draught"], ["crimson_draught"])
	preserved["skill_ids"] = ["makeshift"]
	preserved["skill_flags"] = {"item_preserve_armed": true}
	# Resolve through the actual skill id instead of assuming its display name.
	var skills = preload("res://scripts/skill_tree_library.gd")
	preserved["skill_ids"] = [skills.skill_id_for_effect("preserve_item")]
	preserved = combat.finish_player_card(preserved, 0)
	expect.call(preserved["equipped_items"] == ["crimson_draught"] and preserved["deck"]["discard"] == ["crimson_draught"], "The existing preserve-item skill should keep ownership")

static func _test_full_hand_and_slots(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var full_hand: Array = ["quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab", "quick_stab"]
	var state: Dictionary = combat.apply_player_movement(_state([], full_hand), Vector2i(2, 3))
	expect.call(state["deck"]["hand"].size() == CombatEngine.MAX_HAND_SIZE, "Pickup must never exceed the hand cap")
	expect.call(state["equipped_items"] == ["crimson_draught"] and state["deck"]["draw"] == ["crimson_draught"], "Full-hand pickup auto-equips and becomes the next draw")
	expect.call(state["loot"][0].get("destination") == "draw", "Full-hand acquisition records the draw-pile destination")
	state = combat.finish_player_card(state, 0)
	state = combat.apply_player_action(state, {"type": "draw", "amount": 1}, Vector2i(-1, -1))
	expect.call(state["deck"]["hand"].back() == "crimson_draught" and state["deck"]["hand"].size() == 7, "The queued pickup is drawn once space opens")
	state = combat.apply_player_movement(_state(["nail_bomb", "smoke_bomb"], ["nail_bomb", "smoke_bomb"], ["jaw_trap"]), Vector2i(2, 3))
	expect.call(state["item_inventory"] == ["jaw_trap", "crimson_draught"], "Full slots append the pickup to reserve inventory")
	expect.call(state["deck"]["hand"] == ["nail_bomb", "smoke_bomb"] and state["deck"]["draw"].is_empty(), "Full-slot pickup must not enter any deck zone")
	state = combat.finish_player_card(state, 0)
	state = combat.apply_player_movement(state, Vector2i(3, 3))
	expect.call(state["equipped_items"] == ["smoke_bomb", "crimson_draught"], "Consuming an item opens a slot for the next pickup on the same turn")
	expect.call(state["item_inventory"] == ["jaw_trap", "crimson_draught"], "Stored items do not automatically equip when another is consumed")

static func _test_restore_and_legacy(expect: Callable) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = CombatEngine.new().apply_player_movement(_state(["nail_bomb"], ["nail_bomb"]), Vector2i(3, 3))
	var run_state: Dictionary = engine.create_new_run(82, ProgressionStore.default_data())
	run_state["mode"] = "combat"
	run_state = engine.set_combat_state(run_state, state)
	var restored: Dictionary = engine.repair_loaded_run_state(bytes_to_var(var_to_bytes(run_state)))
	expect.call(restored["equipped_items"] == ["nail_bomb", "crimson_draught"] and restored["item_inventory"] == ["crimson_draught"], "Save/reload preserves active and reserve duplicate copies")
	expect.call(restored["combat_state"]["deck"] == state["deck"], "Save/reload preserves the actual combat hand and piles")
	var legacy: Dictionary = run_state.duplicate(true)
	legacy["combat_state"].erase("equipped_items")
	legacy["combat_state"].erase("item_inventory")
	legacy["combat_state"]["loot"] = [{"id": "old_vial", "kind": "healing_vial", "amount": 2, "pos": Vector2i(2, 3)}, {"id": "old_shield", "kind": "rusty_shield", "claimed": true, "pos": Vector2i(3, 3)}]
	legacy = engine.repair_loaded_run_state(legacy)
	expect.call(legacy["combat_state"]["loot"][0]["card_id"] == "crimson_draught", "Unclaimed legacy vials migrate to item cards")
	expect.call(legacy["combat_state"]["loot"][1]["claimed"], "Already-claimed legacy pickups must never be granted again")
	expect.call(legacy["combat_state"]["equipped_items"] == run_state["equipped_items"], "Old combat snapshots recover the existing loadout")

static func _test_rich_controller_previews(expect: Callable) -> void:
	var host := RunScene.new()
	var board := Board.new()
	board.equipment_tooltip_builder = Callable(host, "_build_equipment_tooltip_panel")
	board.item_tooltip_builder = Callable(host, "_build_item_pickup_tooltip_panel")
	var cursor := Cursor.new()
	cursor.detail_builder = Callable(board, "_make_custom_tooltip")
	for key: String in ["equipment:iron_cleaver", "item:crimson_draught", "equipment:training_sword", "item:nail_bomb"]:
		cursor.call("_set_detail", "pickup", key)
		var panel: Control = cursor.get("_detail_panel")
		expect.call(_panel_has_card_widget(panel), "Analog focus must build real cards for " + key)
		var original_id: int = panel.get_instance_id()
		cursor.call("_set_detail", "pickup", key)
		expect.call((cursor.get("_detail_panel") as Control).get_instance_id() == original_id, "Stable focus should reuse the rich panel instead of rebuilding every frame")
	cursor.hide_cursor()
	expect.call(cursor.get("_detail_panel") == null, "Leaving a pickup clears its preview and stale destination text")
	cursor.free()
	board.free()
	host.free()

static func _panel_has_card_widget(panel: Control) -> bool:
	if panel == null:
		return false
	for node: Node in panel.find_children("*", "Button", true, false):
		if node.get_script() == CardWidget:
			return true
	return false

static func _test_missed_pickups(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = _state()
	state["enemies"][0]["hp"] = 0
	var resolved: Dictionary = combat.resolve_missed_equipment_after_victory(state)
	expect.call(resolved["loot"][0].get("resolution") == "missed" and resolved["loot"][1].get("claimed", false), "Uncollected items leave the board after victory")
	expect.call(resolved["equipped_items"].is_empty() and resolved["item_inventory"].is_empty() and resolved["missed_equipment"].is_empty(), "Missed items grant no ownership or salvageable equipment")
	expect.call(ItemRules.pickups_between(state, resolved).is_empty(), "Victory cleanup is not reported as a collection")

static func _test_pickup_analytics(expect: Callable) -> void:
	var analytics = preload("res://scripts/analytics_store.gd")
	var old_storage: String = analytics.storage_dir()
	analytics.set_storage_dir("user://item_pickup_analytics_suite")
	analytics.clear_storage()
	var host := RunScene.new()
	var before: Dictionary = _state()
	var after: Dictionary = CombatEngine.new().apply_player_movement(before, Vector2i(3, 3))
	host.set("_run_state", RunEngine.new().create_new_run(82, ProgressionStore.default_data()))
	host.set("_analytics_store", analytics.new())
	host.call("_analytics_initialize_combat_tracker", before)
	var tracker_before: Dictionary = host.call("_analytics_snapshot_combat_tracker")
	host.call("_analytics_reconcile_combat_tracker", before, after)
	host.call("_log_item_pickups", before, after)
	host.call("_log_item_pickups", after, after)
	host.call("_analytics_log_card_draws", before, after, tracker_before, host.call("_analytics_snapshot_combat_tracker"), "player_movement")
	var pickup_events: int = 0
	var draw_events: int = 0
	var instance_ids: Dictionary = {}
	for event: Dictionary in analytics.load_all_events():
		if event.get("event_type") == "item_picked_up":
			pickup_events += 1
			expect.call(event["payload"]["destination"] == "hand", "Pickup events record the actual acquisition destination")
		elif event.get("event_type") == "card_drawn":
			draw_events += 1
			instance_ids[event.get("card_instance_id", "")] = true
			expect.call(event["payload"]["reason"] == "item_pickup", "Immediate pickup cards are distinct from ordinary draws in analytics")
	expect.call(pickup_events == 2 and draw_events == 2 and instance_ids.size() == 2 and not instance_ids.has(""), "Two identical pickups emit two distinct card instances without repeat-commit events")
	host.free()
	analytics.set_storage_dir(old_storage)

static func _test_blink_and_forced_movement(expect: Callable) -> void:
	var combat := CombatEngine.new()
	var state: Dictionary = combat.apply_player_action(_state(), {"type": "blink", "range": 2}, Vector2i(2, 3))
	expect.call(state["deck"]["hand"] == ["crimson_draught"] and state["equipped_items"] == ["crimson_draught"], "Blinking onto a pickup uses the same immediate acquisition rules")
	state = _state()
	state = combat.call("_move_player_from_source", state, Vector2i(4, 3), 1, false)
	expect.call(state["player"]["pos"] == Vector2i(2, 3) and state["deck"]["hand"] == ["crimson_draught"], "Forced movement onto a pickup acquires the card")
	var pending: Dictionary = RunEngine.new().create_new_run(82, ProgressionStore.default_data())
	pending["pending_combat_checkpoints"] = [{"boundary": "enemy_action", "state": state}]
	var restored: Dictionary = ItemRules.repair_loaded_run(bytes_to_var(var_to_bytes(pending)))
	expect.call(restored["pending_combat_checkpoints"][0]["state"]["equipped_items"] == ["crimson_draught"], "Unreplayed enemy checkpoints retain their own item ownership")
