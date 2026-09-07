extends RefCounted

const RunEngine = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")
const OFFERED_CARDS: Array = ["spark_dart", "frostbolt", "firebrand_volley"]
var _probe: SceneTree
var _instance: Node
var _sampler: Node

func run(probe: SceneTree, instance: Node, sampler: Node) -> Dictionary:
	_probe = probe
	_instance = instance
	_sampler = sampler
	var result: Dictionary = {"schema_version": 1, "workload_id": "live_shop_reward_map_v1", "viewport": "1920x1080", "ui_scale": 1.0, "cpu_profile": OS.get_environment("LABYRINTH_PERF_CPU_PROFILE"), "renderer": RenderingServer.get_video_adapter_name(), "rendering_method": RenderingServer.get_current_rendering_method(), "sample_boundary": "RenderingServer.frame_post_draw", "phases": {}}
	var phases: Dictionary = result["phases"]
	var engine := RunEngine.new()
	# Construct every immutable fixture/oracle outside the measurement window.
	var merchant: Dictionary = _scavenger_state(engine)
	var reward: Dictionary = _reward_state()
	for fixture: Dictionary in [merchant, reward]:
		fixture["progression"] = Tutorial.complete_tutorial(fixture["progression"])
		fixture["notice"] = ""
		fixture["grimoire_notice"] = ""
		fixture["grimoire_unread"] = []
	var repeat_nodes: Array[int]
	for cycle: int in range(3):
		var prefix: String = "cold" if cycle == 0 else "warm_%d" % cycle
		probe.call("_phase_log", "%s shop" % prefix)
		# Loading a saved merchant room is a real resume path, reported separately
		# from live pointer interactions instead of pretending it is map travel.
		phases[prefix + "/shop_resume"] = await _phase(func() -> void:
			instance.call("_load_run_state", merchant.duplicate(true))
			instance.call("_close_dialogue")
		, 45)
		var shop: Control = instance.get("_scavenger_shop_view") as Control
		_check(shop != null and shop.is_visible_in_tree(), "Merchant resume must show shop")
		if shop == null: return result
		phases[prefix + "/shop_idle"] = await _phase(func() -> void: pass, 90)
		for item_id: String in ["grave_mortar", "boiled_leather", "duelist_rapier", "nail_bomb"]:
			var offer: Control = (shop.get("_offer_sources") as Dictionary).get("buy:" + item_id) as Control
			phases[prefix + "/inspect_" + item_id] = await _phase(func() -> void: _click(offer), 24)
			_check(str((shop.call("semantic_snapshot") as Dictionary).get("selected_item_id")) == item_id, "Shop click inspection must select " + item_id)
		var buy_id: String = "duelist_rapier"
		var buy_offer: Control = (shop.get("_offer_sources") as Dictionary).get("buy:" + buy_id) as Control
		await _phase(func() -> void: _click(buy_offer), 12)
		var before: Dictionary = instance.get("_run_state") as Dictionary
		var expected: Dictionary = engine.buy_merchant_item(before, RunEngine.MERCHANT_SCAVENGER, buy_id)
		phases[prefix + "/shop_buy"] = await _phase(func() -> void: _click(shop.find_child("ScavengerTradeActionButton", true, false)), 100)
		_assert_trade(expected, "buy", phases[prefix + "/shop_buy"])
		var sell_sources: Dictionary = shop.get("_offer_sources") as Dictionary
		var sell_key: String = ""
		for key: String in sell_sources:
			if key.begins_with("sell:"):
				sell_key = key
				break
		_check(not sell_key.is_empty(), "Merchant pack must expose a sellable item")
		var sell_offer: Control = sell_sources.get(sell_key) as Control
		await _phase(func() -> void: _click(sell_offer), 12)
		before = instance.get("_run_state") as Dictionary
		expected = engine.sell_merchant_item(before, RunEngine.MERCHANT_SCAVENGER, sell_key.trim_prefix("sell:"))
		phases[prefix + "/shop_sell"] = await _phase(func() -> void: _click(shop.find_child("ScavengerTradeActionButton", true, false)), 80)
		_assert_trade(expected, "sell", phases[prefix + "/shop_sell"])
		if cycle == 0:
			await probe.call("_save_root_screenshot", "flow_shop_after_trades.png")
		phases[prefix + "/shop_leave"] = await _phase(func() -> void: _click(shop.find_child("ScavengerLeaveButton", true, false)), 24)
		_check(not shop.visible, "Leave must expose room board")
		phases[prefix + "/shop_reopen"] = await _phase(func() -> void: _click(instance.find_child("MerchantReturnToShopButton", true, false)), 24)
		_check(shop.visible, "Return to shop must reopen offers")
		await _phase(func() -> void: _click(shop.find_child("ScavengerLeaveButton", true, false)), 12)
		phases[prefix + "/map_open"] = await _phase(func() -> void: _key(KEY_M), 24)
		_check((instance.get("_large_map_scrim") as Control).visible, "M must open map")
		phases[prefix + "/map_idle"] = await _phase(func() -> void: pass, 90)
		phases[prefix + "/map_close"] = await _phase(func() -> void: _key(KEY_ESCAPE), 12)
		_check(not (instance.get("_large_map_scrim") as Control).visible, "Escape must close map")
		probe.call("_phase_log", "%s rewards" % prefix)
		var reveal: Dictionary = reward.duplicate(true)
		reveal["pending_reward"]["intro_pending"] = true
		phases[prefix + "/reward_resume_reveal"] = await _phase(func() -> void:
			instance.call("_load_run_state", reveal)
			instance.call("_close_dialogue")
		, 360)
		_check(not bool(instance.call("_reward_intro_pending")), "Reward reveal must finish its saved intro")
		phases[prefix + "/reward_idle"] = await _phase(func() -> void: pass, 90)
		if cycle == 0: await probe.call("_save_root_screenshot", "flow_reward_revealed.png")
		var row: Control = instance.find_child("RewardCardRow", true, false) as Control
		var cards: Array = row.find_children("*", "Control", true, false) if row != null else []
		var selected: Control
		for card: Control in cards:
			if card.has_signal("activated") and card.get("card_id") == "frostbolt": selected = card
		_check(selected != null, "Reward must expose Frostbolt card")
		phases[prefix + "/reward_hover"] = await _phase(func() -> void: _motion(selected), 30)
		before = instance.get("_run_state") as Dictionary
		expected = engine.claim_card_reward(before, "frostbolt")
		phases[prefix + "/reward_claim"] = await _phase(func() -> void: _click(selected), 100)
		_assert_trade(expected, "reward claim", phases[prefix + "/reward_claim"])
		instance.call("_load_run_state", reward.duplicate(true))
		instance.call("_close_dialogue")
		await probe.call("_settle_render_frames", 12)
		before = instance.get("_run_state") as Dictionary
		expected = engine.skip_reward_for_heal(before)
		phases[prefix + "/reward_heal"] = await _phase(func() -> void: _click(instance.find_child("RewardRecoverButton", true, false)), 30)
		_assert_trade(expected, "reward heal", phases[prefix + "/reward_heal"])
		repeat_nodes.append(int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)))
	result["interaction_semantics"] = {}
	for name: String in phases:
		if (phases[name] as Dictionary).has("semantics"): result["interaction_semantics"][name] = phases[name]["semantics"]
	result["repeat_nodes"] = repeat_nodes
	result["orphan_nodes"] = int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))
	result["static_memory_bytes"] = int(Performance.get_monitor(Performance.MEMORY_STATIC))
	result["focus_observations"] = probe.get("_focus_observation_count")
	result["unfocused_observations"] = probe.get("_unfocused_observation_count")
	_check(int(result["orphan_nodes"]) == 0, "Flow workload must leave no orphan nodes")
	_check(repeat_nodes.size() == 3 and repeat_nodes[1] == repeat_nodes[2], "Repeated warm shop/reward cycles must keep live nodes bounded")
	return result

func _phase(action: Callable, minimum_frames: int) -> Dictionary:
	# A fresh boundary excludes fixture oracles, PNG readback and prior results.
	await _probe.call("_settle_render_frames", 3)
	_instance.call("set_runtime_performance_instrumentation_enabled", true)
	var compilations_before: int = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS)
	_sampler.call("begin")
	var started: int = Time.get_ticks_usec()
	action.call()
	var handler_ms: float = float(Time.get_ticks_usec() - started) / 1000.0
	var frames: int = 0
	while frames < minimum_frames or bool(_instance.get("_animation_lock")) or bool(_instance.get("_merchant_trade_animation_active")) or bool(_instance.get("_loadout_acquisition_in_progress")) or bool(_instance.get("_campfire_choice_action_pending")) or bool(_instance.get("_relic_claim_in_progress")) or bool(_instance.get("_equipment_swap_animation_active")) or bool(_instance.get("_item_swap_animation_active")):
		await _probe.call("_await_render_frame")
		frames += 1
		if frames >= 1200:
			_check(false, "UI interaction must settle before deadlock guard")
			break
	var result: Dictionary = _probe.call("_sampler_phase_result", _sampler.call("finish"))
	result["canvas_pipeline_compilations"] = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_PIPELINE_COMPILATIONS_CANVAS) - compilations_before
	result["handler_ms"] = handler_ms
	result["stage_profile"] = _instance.call("runtime_performance_instrumentation_snapshot")
	result["stage_frame_profile"] = _instance.call("runtime_performance_frame_instrumentation_snapshot")
	_instance.call("set_runtime_performance_instrumentation_enabled", false)
	return result

func _assert_trade(expected: Dictionary, label: String, phase: Dictionary) -> void:
	var actual: Dictionary = _instance.get("_run_state") as Dictionary
	var semantics: Dictionary = {}
	for key: String in ["mode", "held_embers", "player_hp", "player_max_hp", "equipment_inventory", "magic_inventory", "item_inventory", "reward_cards", "pending_reward"]:
		_check(actual.get(key) == expected.get(key), label + " must match engine oracle: " + key)
		semantics[key] = actual.get(key)
	phase["semantics"] = semantics

func _click(control: Control) -> void:
	_check(control != null and control.is_visible_in_tree(), "Live click target must be visible")
	if control != null: _probe.call("_routed_left_click", control, control.size * 0.5)

func _motion(control: Control) -> void:
	_check(control != null and control.is_visible_in_tree(), "Live hover target must be visible")
	if control != null: _probe.call("_routed_pointer_motion", control, control.size * 0.5)

func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_probe.root.push_input(event, true)

func _check(condition: bool, message: String) -> void:
	_probe.call("_expect", condition, message)

func _fixture_fail(message: String) -> void:
	_check(false, message)

func _first_available_room_coord_of_type(engine: RunEngine, state: Dictionary, kind: String) -> Vector2i:
	for coord: Vector2i in engine.available_moves(state):
		if str(engine.room_metadata(state, coord).get("type", "")) == kind: return coord
	return Vector2i.ZERO

func _scavenger_state(run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 720)
	var state: Dictionary = run_engine.create_new_run(73491, progression)
	var coord: Vector2i = _first_scavenger_coord(run_engine, state)
	if coord.x >= 900:
		_fixture_fail("Generated run should include a Scavenger room")
		return state
	var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	room[RunEngine.MERCHANT_STOCK_KEY] = [
		"grave_mortar",
		"icicle_lance",
		"dawnstep",
		"boiled_leather",
		"dust_tabi",
		"duelist_rapier",
		"crimson_draught",
		"nail_bomb",
		"jaw_trap",
	]
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = "room"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	state["held_embers"] = 720
	state["unbanked_embers"] = 720
	state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	state["magic_inventory"] = ["spark_dart", "frostbolt"]
	state["reward_cards"] = ["spark_dart", "frostbolt"]
	state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	return state

func _first_scavenger_coord(run_engine: RunEngine, state: Dictionary) -> Vector2i:
	for radius: int in range(1, RunEngine.MAX_DEPTH + 1):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var coord := Vector2i(x, y)
				if str(run_engine.room_metadata(state, coord).get("type", "")) == RunEngine.MERCHANT_SCAVENGER:
					return coord
	return Vector2i(999, 999)

func _reward_state() -> Dictionary:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7319, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_room_coord_of_type(engine, state, "combat")
	if combat_coord == Vector2i.ZERO:
		_fixture_fail("reward workload run must expose an available combat room")
		return state
	state = engine.move_to_room(state, combat_coord)
	if str(state.get("mode", "")) == RunEngine.MODE_PRE_BATTLE:
		state = engine.begin_pre_battle_combat(state)
	if str(state.get("mode", "")) != "combat":
		_fixture_fail("reward workload must enter combat before constructing its reward")
		return state
	state = engine.finish_combat(state, _victory_combat_state(state.get("combat_state", {}) as Dictionary))
	state["player_hp"] = 12
	state["player_max_hp"] = 24
	state["attuned_magic_cards"] = ["pale_spark", "dull_bolt", "waning_pulse", "chain_bolt"]
	state["magic_inventory"] = ["spark_dart"]
	state["reward_cards"] = ["spark_dart"]
	var pending_reward: Dictionary = (state.get("pending_reward", {}) as Dictionary).duplicate(true)
	pending_reward["cards"] = OFFERED_CARDS.duplicate()
	pending_reward["heal_amount"] = RunEngine.REWARD_HEAL
	pending_reward["ember_amount"] = 0
	pending_reward["intro_pending"] = false
	state["pending_reward"] = pending_reward
	return state

func _victory_combat_state(combat_state: Dictionary) -> Dictionary:
	var victory: Dictionary = combat_state.duplicate(true)
	var objective: Dictionary = victory.get("objective", {}) as Dictionary
	var objective_type: String = str(objective.get("type", CombatObjectiveRules.KILL_ALL))
	if objective_type == CombatObjectiveRules.REACH_EXIT:
		var target_tiles: Array[Vector2i] = CombatObjectiveRules.exit_target_tiles(objective)
		if not target_tiles.is_empty():
			var player: Dictionary = (victory.get("player", {}) as Dictionary).duplicate(true)
			player["pos"] = target_tiles[0]
			victory["player"] = player
		return victory
	if objective_type == CombatObjectiveRules.SURVIVE:
		victory["initiative_clock"] = int(objective.get("target_clock", victory.get("initiative_clock", 0)))
		return victory
	var enemies: Array = (victory.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	victory["enemies"] = enemies
	return victory
