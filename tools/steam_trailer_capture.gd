extends Control

const RunScene = preload("res://scenes/run_scene.tscn")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const GameDataScript = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const CAPTURE_SEED: int = 126044
const INVALID_TILE: Vector2i = Vector2i(-1, -1)
const INVALID_ROOM: Vector2i = Vector2i(999, 999)

var _run_scene: Control
var _run_engine = RunEngineScript.new()
var _combat_engine = CombatEngineScript.new()
var _clip_id: String = "route"

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	get_window().size = Vector2i(1920, 1080)
	ProgressionStore.set_storage_path("user://steam_trailer_progression.json")
	ProgressionStore.set_run_storage_path("user://steam_trailer_current_run.save")
	ProgressionStore.clear_saved_run()
	_clip_id = _requested_clip_id()
	_run_scene = RunScene.instantiate()
	_run_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_run_scene.visible = false
	add_child(_run_scene)
	call_deferred("_capture_requested_clip")

func _requested_clip_id() -> String:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--clip="):
			return argument.trim_prefix("--clip=")
	return "route"

func _capture_requested_clip() -> void:
	await _settle(0.35)
	_seed_showcase_run()
	await _settle(0.45)
	match _clip_id:
		"route":
			await _capture_route()
		"prebattle":
			await _capture_prebattle()
		"trap_combo":
			await _capture_trap_combo()
		"aoe":
			await _capture_aoe_combo()
		"umbra":
			await _capture_umbra_reveal()
		"merchant":
			await _capture_merchant_purchase()
		"relic":
			await _capture_relic_claim()
		"spell":
			await _capture_spell_reward()
		"equipment":
			await _capture_equipment_pickup_and_equip()
		_:
			push_error("Unknown Steam trailer clip: %s" % _clip_id)
			get_tree().quit(2)
			return
	await _settle(0.35)
	get_tree().quit()

func _seed_showcase_run() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 22
	progression["run_counter"] = 3
	progression["card_upgrades_unlocked"] = true
	var state: Dictionary = _run_engine.create_new_run(CAPTURE_SEED, progression)
	match _clip_id:
		"route":
			state = _build_deep_route_state(state)
		"prebattle":
			state = _build_prebattle_origin_state(state)
		"merchant":
			state = _build_target_room_state(state, "merchant", 2)
			state = _run_engine.set_held_embers(state, 220)
		"relic":
			state = _build_target_room_state(state, "relic", 2)
		"spell":
			state = _build_post_combat_reward_state(_build_target_room_state(state, "spell", 2))
		"equipment":
			state = _build_target_room_state(state, "equipment", 2)
		_:
			state["held_embers"] = 11
			state["unbanked_embers"] = 11
	_run_scene.call("_load_run_state", state)
	_suppress_current_room_dialogue()

func _show_run_scene() -> void:
	_run_scene.visible = true

func _suppress_current_room_dialogue() -> void:
	_run_scene.call("_close_dialogue")
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var room: Dictionary = _run_engine.room_metadata(state, state.get("current_room", Vector2i.ZERO))
	_run_scene.set("_last_auto_dialogue_key", _run_scene.call("_dialogue_trigger_key", room))

func _capture_route() -> void:
	_run_scene.call("_open_large_map")
	await _settle(1.2)
	_show_run_scene()
	await _settle(0.8)
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var choices: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(state))
	_assert_capture(not choices.is_empty(), "Deep route capture must expose at least one legal next room")
	var large_map_view: Control = _run_scene.get("_large_map_view") as Control
	if large_map_view != null and not choices.is_empty():
		large_map_view.call("begin_travel_animation", current, choices[0])
	await _settle(2.0)
	if large_map_view != null and not choices.is_empty():
		large_map_view.set("_hover_coord", choices[0])
		large_map_view.queue_redraw()
	await _settle(2.2)

func _capture_prebattle() -> void:
	var destination: Vector2i = _first_combat_destination()
	if destination == INVALID_TILE:
		push_error("Capture seed has no available combat destination")
		return
	await _run_scene.call("_on_map_view_room_selected", destination)
	await _settle(1.8)
	_show_run_scene()
	await _settle(5.0)

func _build_prebattle_origin_state(initial_state: Dictionary) -> Dictionary:
	var route: Dictionary = _find_target_route(initial_state, "spell", 2)
	_assert_capture(not route.is_empty(), "Engine-generated path must find a non-start combat room for pre-battle capture")
	var origin: Dictionary = (route.get("origin", initial_state) as Dictionary).duplicate(true)
	var destination: Vector2i = route.get("destination", INVALID_ROOM)
	var choices: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(origin))
	_assert_capture(destination != INVALID_ROOM and choices.has(destination), "Pre-battle destination must be a legal move")
	_assert_capture(origin.get("current_room", Vector2i.ZERO) != Vector2i.ZERO, "Pre-battle capture must not begin in the starting room")
	print("STEAM_TRAILER_PREBATTLE_ORIGIN current=%s depth=%d destination=%s path=%s" % [
		str(origin.get("current_room", Vector2i.ZERO)),
		_room_depth_for_state(origin, origin.get("current_room", Vector2i.ZERO)),
		str(destination),
		str(route.get("path", []))
	])
	return origin

func _build_target_room_state(initial_state: Dictionary, target: String, min_depth: int) -> Dictionary:
	var route: Dictionary = _find_target_route(initial_state, target, min_depth)
	_assert_capture(not route.is_empty(), "Engine-generated path must find target room: %s" % target)
	if route.is_empty():
		return initial_state
	var origin: Dictionary = (route.get("origin", initial_state) as Dictionary).duplicate(true)
	var destination: Vector2i = route.get("destination", INVALID_ROOM)
	if target == "equipment":
		origin["equipment_drop_misses"] = RunEngineScript.EQUIPMENT_DROP_PITY_MISSES
	var result: Dictionary = _run_engine.move_to_room(origin, destination)
	var room: Dictionary = _run_engine.room_metadata(result, destination)
	_assert_capture(result.get("current_room", Vector2i.ZERO) == destination, "Target room entry must use RunEngine.move_to_room")
	_assert_capture(destination != Vector2i.ZERO, "Progression capture target must not be the starting room")
	_assert_capture(_target_room_matches(room, target, min_depth), "Entered room must match requested progression target")
	if target == "equipment":
		_assert_capture(_first_unclaimed_equipment_loot(result.get("combat_state", {}) as Dictionary).size() > 0, "Forced-pity combat must contain real equipment loot")
	print("STEAM_TRAILER_TARGET_RESULT target=%s room=%s depth=%d type=%s path=%s mode=%s" % [
		target,
		str(destination),
		int(room.get("depth", 0)),
		str(room.get("type", "")),
		str(route.get("path", [])),
		str(result.get("mode", ""))
	])
	return result

func _find_target_route(initial_state: Dictionary, target: String, min_depth: int) -> Dictionary:
	var initial: Dictionary = _run_engine.repair_loaded_run_state(initial_state)
	var queue: Array = []
	queue.append({"state": initial, "path": [Vector2i.ZERO]})
	var visited: Dictionary = {_room_key(Vector2i.ZERO): true}
	var safety: int = 0
	while not queue.is_empty() and safety < 96:
		safety += 1
		var entry: Dictionary = queue.pop_front() as Dictionary
		var state: Dictionary = entry.get("state", {}) as Dictionary
		var path: Array = (entry.get("path", []) as Array).duplicate()
		var moves: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(state))
		for destination: Vector2i in moves:
			var room: Dictionary = _run_engine.room_metadata(state, destination)
			if _target_room_matches(room, target, min_depth):
				var target_path: Array = path.duplicate()
				target_path.append(destination)
				return {"origin": state, "destination": destination, "path": target_path}
		for destination: Vector2i in moves:
			var key: String = _room_key(destination)
			if visited.has(key):
				continue
			var traversed: Dictionary = _run_engine.move_to_room(state, destination)
			traversed = _resolve_search_room(traversed)
			if str(traversed.get("mode", "")) != "room":
				continue
			visited[key] = true
			var next_path: Array = path.duplicate()
			next_path.append(destination)
			queue.append({"state": traversed, "path": next_path})
	return {}

func _resolve_search_room(state: Dictionary) -> Dictionary:
	var mode: String = str(state.get("mode", "room"))
	if mode == "combat":
		var victory: Dictionary = _victory_combat_state(state.get("combat_state", {}) as Dictionary)
		var reward_state: Dictionary = _run_engine.finish_combat(state, victory)
		return _run_engine.skip_reward_for_heal(reward_state) if str(reward_state.get("mode", "")) == "reward" else reward_state
	if mode == "treasure":
		var relics: Array = state.get("pending_relics", []) as Array
		return _run_engine.claim_relic(state, str(relics[0])) if not relics.is_empty() else state
	if mode == "campfire":
		return _run_engine.leave_campfire(state)
	return state

func _target_room_matches(room: Dictionary, target: String, min_depth: int) -> bool:
	if int(room.get("depth", 0)) < min_depth:
		return false
	match target:
		"merchant":
			return not _run_engine.merchant_kind_for_room(room).is_empty()
		"relic":
			return str(room.get("type", "")) == "treasure"
		"spell", "equipment":
			return str(room.get("type", "")) == "combat"
	return false

func _victory_combat_state(combat_state: Dictionary) -> Dictionary:
	var victory: Dictionary = combat_state.duplicate(true)
	var enemies: Array = (victory.get("enemies", []) as Array).duplicate(true)
	for index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[index] as Dictionary).duplicate(true)
		enemy["hp"] = 0
		enemies[index] = enemy
	victory["enemies"] = enemies
	return victory

func _build_post_combat_reward_state(combat_run_state: Dictionary) -> Dictionary:
	var current: Vector2i = combat_run_state.get("current_room", Vector2i.ZERO)
	var combat_state: Dictionary = (combat_run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var reward_loot: Array = []
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY and str((loot_var as Dictionary).get("kind", "")) == "equipment":
			continue
		reward_loot.append(loot_var)
	combat_state["loot"] = reward_loot
	var reward_state: Dictionary = _run_engine.finish_combat(
		combat_run_state,
		_victory_combat_state(combat_state)
	)
	var cards: Array = (reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array
	_assert_capture(str(reward_state.get("mode", "")) == "reward", "Post-combat spell capture must enter the real reward mode")
	_assert_capture(not cards.is_empty(), "Post-combat spell capture must generate real card rewards")
	print("STEAM_TRAILER_POST_COMBAT_REWARD room=%s depth=%d cards=%s" % [
		str(current),
		_room_depth_for_state(reward_state, current),
		str(cards)
	])
	return reward_state

func _build_deep_route_state(initial_state: Dictionary) -> Dictionary:
	var state: Dictionary = _run_engine.repair_loaded_run_state(initial_state)
	var path: Array[Vector2i] = []
	path.append(Vector2i.ZERO)
	var safety: int = 0
	while _room_depth_for_state(state, state.get("current_room", Vector2i.ZERO)) < 3 and safety < 24:
		safety += 1
		var destination: Vector2i = _choose_showcase_route_step(state)
		_assert_capture(destination != INVALID_ROOM, "Engine-generated route must reach depth 3")
		if destination == INVALID_ROOM:
			break
		state = _advance_showcase_route(state, destination)
		path.append(destination)
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var current_depth: int = _room_depth_for_state(state, current)
	var choices: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(state))
	var cleared_count: int = 0
	for room_var: Variant in (state.get("rooms", {}) as Dictionary).values():
		if typeof(room_var) == TYPE_DICTIONARY and bool((room_var as Dictionary).get("cleared", false)):
			cleared_count += 1
	_assert_capture(current_depth >= 3, "Engine-generated route capture must reach depth 3")
	_assert_capture(path.size() >= 5, "Engine-generated route must show a meaningful cleared path")
	_assert_capture(cleared_count >= path.size(), "Every traveled room in the route capture must be cleared")
	_assert_capture(not choices.is_empty(), "Deep route capture must leave realistic next-room choices")
	state["turns_spent"] = path.size() - 1
	print("STEAM_TRAILER_ROUTE_RESULT depth=%d path=%s choices=%s cleared=%d" % [current_depth, str(path), str(choices), cleared_count])
	return state

func _choose_showcase_route_step(state: Dictionary) -> Vector2i:
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var current_depth: int = _room_depth_for_state(state, current)
	var choices: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(state))
	for choice: Vector2i in choices:
		if _room_depth_for_state(state, choice) > current_depth:
			return choice
	for choice: Vector2i in choices:
		var room: Dictionary = _run_engine.room_metadata(state, choice)
		if not bool(room.get("visited", false)):
			return choice
	return choices[0] if not choices.is_empty() else INVALID_ROOM

func _advance_showcase_route(state: Dictionary, destination: Vector2i) -> Dictionary:
	var next_state: Dictionary = state.duplicate(true)
	var rooms: Dictionary = (next_state.get("rooms", {}) as Dictionary).duplicate(true)
	var current: Vector2i = next_state.get("current_room", Vector2i.ZERO)
	var current_room: Dictionary = _run_engine.room_metadata(next_state, current)
	current_room["sealed"] = true
	rooms[_room_key(current)] = current_room
	var destination_room: Dictionary = _run_engine.room_metadata(next_state, destination)
	destination_room["revealed"] = true
	destination_room["visited"] = true
	destination_room["cleared"] = true
	destination_room["sealed"] = false
	rooms[_room_key(destination)] = destination_room
	next_state["rooms"] = rooms
	next_state["current_room"] = destination
	next_state["mode"] = "room"
	next_state["combat_state"] = {}
	next_state["pending_reward"] = {}
	next_state["pending_relics"] = []
	return _run_engine.repair_loaded_run_state(next_state)

func _room_depth_for_state(state: Dictionary, coord: Vector2i) -> int:
	return int(_run_engine.room_metadata(state, coord).get("depth", 0))

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _capture_trap_combo() -> void:
	var layout: Dictionary = _base_combat_layout("The Ember Snare", "fire", 7)
	var trap_grid: Array = _simple_grid()
	(trap_grid[3] as Array)[4] = "wall"
	(trap_grid[5] as Array)[4] = "wall"
	layout["grid"] = trap_grid
	layout["player_start"] = Vector2i(3, 4)
	layout["enemies"] = [
		_enemy(1, "crawler", Vector2i(4, 4), 36),
		_enemy(2, "harrier", Vector2i(5, 3), 30),
		_enemy(3, "acolyte", Vector2i(5, 5), 30),
		_enemy(4, "grave_surgeon", Vector2i(7, 6), 48)
	]
	layout["traps"] = [{
		"id": "trailer_fire_snare",
		"element": "fire",
		"pos": Vector2i(5, 4),
		"damage": 30,
		"burn": 2,
		"armed": true
	}]
	var state: Dictionary = _create_showcase_combat(layout, ["cleaver_hook", "sidestep_slash", "brace"])
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.15)
	_preview_card_and_tile(0, Vector2i(4, 4))
	await _settle(1.15)
	_clear_hover(0)
	var action: Dictionary = {
		"type": "push",
		"damage": 6,
		"range": 1,
		"amount": 1,
		"_card_element": "neutral"
	}
	var after_state: Dictionary = _combat_engine.apply_player_action(state.duplicate(true), action, Vector2i(4, 4))
	_assert_capture((after_state.get("traps", []) as Array).is_empty(), "Cleaver Hook must consume the fire trap")
	_assert_capture(_live_enemy_count(after_state) == 1, "Cleaver Hook fire-trap blast must kill exactly three showcase enemies")
	_assert_capture(int((after_state.get("player", {}) as Dictionary).get("hp", 0)) > 0, "Cleaver Hook trap combo must leave the player alive")
	print("STEAM_TRAILER_TRAP_RESULT trap_consumed=true enemies_killed=3 player_alive=true")
	await _run_scene.call("_animate_player_action_step", state.duplicate(true), after_state, "cleaver_hook", action, Vector2i(4, 4))
	_apply_combat_state(layout, after_state)
	await _settle(1.7)

func _capture_aoe_combo() -> void:
	var layout: Dictionary = _base_combat_layout("Storm Gallery", "lightning", 14)
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [
		_enemy(1, "crawler", Vector2i(4, 4), 12),
		_enemy(2, "harrier", Vector2i(5, 4), 12),
		_enemy(3, "acolyte", Vector2i(6, 4), 12),
		_enemy(4, "warden", Vector2i(7, 2), 45)
	]
	var state: Dictionary = _create_showcase_combat(layout, ["thunderline", "storm_relay", "updraft"])
	state["elemental_intensity"] = {"fire": 0, "ice": 0, "lightning": 3, "air": 1, "earth": 0}
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.15)
	_preview_card_and_tile(0, Vector2i(4, 4))
	await _settle(1.15)
	_clear_hover(0)
	var action: Dictionary = {
		"type": "aoe",
		"damage": 5,
		"range": 6,
		"pattern": [[0, 0], [1, 0], [2, 0]],
		"rotate": true,
		"orientation": Vector2i(1, 0),
		"intensity_bonus": {"element": "lightning", "threshold": 3, "damage": 7, "shock": 1},
		"_card_element": "lightning"
	}
	var after_state: Dictionary = _combat_engine.apply_player_action(state.duplicate(true), action, Vector2i(4, 4))
	await _run_scene.call("_animate_player_action_step", state.duplicate(true), after_state, "thunderline", action, Vector2i(4, 4))
	_apply_combat_state(layout, after_state)
	await _settle(1.7)

func _capture_umbra_reveal() -> void:
	var layout: Dictionary = _base_combat_layout("Heart Umbra", "ice", 31)
	layout["umbra_stage"] = "heart"
	layout["player_start"] = Vector2i(2, 4)
	layout["enemies"] = [
		_enemy(1, "grave_surgeon", Vector2i(5, 4), 36),
		_enemy(2, "crawler", Vector2i(6, 5), 22),
		_enemy(3, "harrier", Vector2i(7, 2), 24),
		_enemy(4, "acolyte", Vector2i(3, 2), 28)
	]
	var state: Dictionary = _create_showcase_combat(layout, ["lantern_shot", "guiding_flare", "dawnstep"])
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.4)
	_preview_card_and_tile(0, Vector2i(5, 4))
	await _settle(1.0)
	_clear_hover(0)
	var illuminate: Dictionary = {"type": "illuminate", "range": 6, "radius": 2, "duration": 2}
	var lit_state: Dictionary = _combat_engine.apply_player_action(state.duplicate(true), illuminate, Vector2i(5, 4))
	await _run_scene.call("_animate_player_action_step", state.duplicate(true), lit_state, "lantern_shot", illuminate, Vector2i(5, 4))
	_apply_combat_state(layout, lit_state)
	await _settle(0.45)
	var ranged: Dictionary = {"type": "ranged", "damage": 4, "range": 6, "_card_element": "neutral"}
	var after_state: Dictionary = _combat_engine.apply_player_action(lit_state.duplicate(true), ranged, Vector2i(5, 4))
	await _run_scene.call("_animate_player_action_step", lit_state.duplicate(true), after_state, "lantern_shot", ranged, Vector2i(5, 4))
	_apply_combat_state(layout, after_state)
	await _settle(1.45)

func _capture_merchant_purchase() -> void:
	_show_run_scene()
	await _settle(0.75)
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var merchant_kind: String = _run_engine.merchant_kind_for_current_room(state)
	var offers: Array = _run_engine.merchant_offer_ids(state, merchant_kind)
	_assert_capture(current != Vector2i.ZERO, "Merchant capture must not use the starting room")
	_assert_capture(not merchant_kind.is_empty() and not offers.is_empty(), "Merchant capture must expose real stock")
	var item_id: String = str(offers[0])
	for offer_var: Variant in offers:
		var candidate: String = str(offer_var)
		if _run_engine.merchant_buy_cost(merchant_kind, candidate) < _run_engine.merchant_buy_cost(merchant_kind, item_id):
			item_id = candidate
	var tooltip_key: String = ("equipment:" if merchant_kind == RunEngineScript.MERCHANT_BLACKSMITH else "card:") + item_id
	var source_row: Control = _find_control_with_tooltip(_run_scene, tooltip_key)
	_assert_capture(source_row != null, "Merchant capture must find the production shop row")
	var before_embers: int = _run_engine.held_embers(state)
	_run_scene.call("_on_merchant_row_mouse_entered", merchant_kind, item_id, source_row)
	await _settle(0.55)
	await _run_scene.call("_on_merchant_buy_pressed", merchant_kind, item_id, source_row)
	var after_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var after_embers: int = _run_engine.held_embers(after_state)
	_assert_capture(after_embers < before_embers, "Merchant purchase must spend held embers")
	print("STEAM_TRAILER_MERCHANT_RESULT room=%s depth=%d merchant=%s item=%s embers=%d->%d" % [
		str(current),
		_room_depth_for_state(after_state, current),
		merchant_kind,
		item_id,
		before_embers,
		after_embers
	])
	await _settle(0.9)

func _capture_relic_claim() -> void:
	_show_run_scene()
	await _settle(0.75)
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var relics: Array = (state.get("pending_relics", []) as Array).duplicate()
	_assert_capture(current != Vector2i.ZERO and str(state.get("mode", "")) == "treasure", "Relic capture must use a real non-start treasure room")
	_assert_capture(not relics.is_empty(), "Relic capture must expose generated relic choices")
	var relic_id: String = str(relics[0])
	var source_panel: Control = _find_control_with_meta(_run_scene, "relic_id", relic_id)
	_assert_capture(source_panel != null, "Relic capture must find the production relic choice panel")
	await _settle(0.45)
	await _run_scene.call("_on_relic_pressed", relic_id, source_panel.get_global_rect())
	var after_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	_assert_capture((after_state.get("relics", []) as Array).has(relic_id), "Relic claim must add the selected relic to the run")
	print("STEAM_TRAILER_RELIC_RESULT room=%s depth=%d relic=%s mode=%s" % [
		str(current),
		_room_depth_for_state(after_state, current),
		relic_id,
		str(after_state.get("mode", ""))
	])
	await _settle(0.9)

func _capture_spell_reward() -> void:
	_show_run_scene()
	await _settle(0.75)
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var cards: Array = ((state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array).duplicate()
	_assert_capture(current != Vector2i.ZERO and str(state.get("mode", "")) == "reward", "Spell capture must use a real post-combat reward state")
	_assert_capture(not cards.is_empty(), "Spell capture must expose generated reward cards")
	var card_id: String = str(cards[0])
	var source_slot: Control = _find_control_with_meta(_run_scene, "reward_card_id", card_id)
	_assert_capture(source_slot != null, "Spell capture must find the production reward card slot")
	await _settle(0.45)
	await _run_scene.call("_on_reward_card_pressed", card_id, source_slot)
	var after_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	_assert_capture((after_state.get("magic_inventory", []) as Array).has(card_id), "Spell reward must enter learned magic inventory")
	print("STEAM_TRAILER_SPELL_RESULT room=%s depth=%d card=%s mode=%s" % [
		str(current),
		_room_depth_for_state(after_state, current),
		card_id,
		str(after_state.get("mode", ""))
	])
	await _settle(0.9)

func _capture_equipment_pickup_and_equip() -> void:
	var run_state: Dictionary = (_run_scene.get("_run_state") as Dictionary).duplicate(true)
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var room: Dictionary = _run_engine.room_metadata(run_state, current)
	var layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	var before_combat: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var loot: Dictionary = _first_unclaimed_equipment_loot(before_combat)
	_assert_capture(current != Vector2i.ZERO and str(run_state.get("mode", "")) == "combat", "Equipment capture must use a real non-start combat room")
	_assert_capture(not loot.is_empty(), "Equipment capture must begin with a real equipment drop")
	var equipment_id: String = str(loot.get("equipment_id", ""))
	var equipment_tile: Vector2i = loot.get("pos", INVALID_TILE)
	var blink_action: Dictionary = {"type": "blink", "range": 99}
	var after_combat: Dictionary = _combat_engine.apply_player_action(before_combat, blink_action, equipment_tile)
	_assert_capture((after_combat.get("collected_equipment", []) as Array).has(equipment_id), "Production combat action must collect the equipment drop")
	_show_run_scene()
	await _settle(0.75)
	_preview_card_and_tile(0, equipment_tile)
	await _settle(0.35)
	_clear_hover(0)
	await _run_scene.call("_animate_player_action_step", before_combat, after_combat, "shadow_step", blink_action, equipment_tile)
	_apply_combat_state(layout, after_combat)
	await _settle(0.25)
	run_state = _run_engine.set_combat_state(run_state, after_combat)
	var reward_state: Dictionary = _run_engine.finish_combat(run_state, _victory_combat_state(after_combat))
	var room_state: Dictionary = _run_engine.claim_card_reward(reward_state, "") if str(reward_state.get("mode", "")) == "reward" else reward_state
	_run_scene.call("_load_run_state", room_state)
	_suppress_current_room_dialogue()
	_run_scene.call("_open_character_overlay", "equipment")
	await _settle(0.65)
	var slot: String = GameDataScript.equipment_slot(equipment_id)
	var source_rect: Rect2 = _run_scene.call("_equipment_inventory_icon_rect", equipment_id) as Rect2
	var target_rect: Rect2 = _run_scene.call("_equipment_slot_icon_rect", slot) as Rect2
	_assert_capture(source_rect.size.x > 0.0 and target_rect.size.x > 0.0, "Equipment capture must render inventory and target slot icons")
	_run_scene.set("_equipment_drag_source_rect", source_rect)
	await _run_scene.call("_equip_equipment_from_overlay", equipment_id, slot, target_rect)
	var equipped_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var equipped: Dictionary = equipped_state.get("equipped_equipment", {}) as Dictionary
	_assert_capture(str(equipped.get(slot, "")) == equipment_id, "Production equipment swap must equip the collected item")
	print("STEAM_TRAILER_EQUIPMENT_RESULT room=%s depth=%d room_type=%s equipment=%s slot=%s collected=true equipped=true" % [
		str(current),
		int(room.get("depth", 0)),
		str(room.get("type", "")),
		equipment_id,
		slot
	])
	await _settle(1.0)

func _first_unclaimed_equipment_loot(combat_state: Dictionary) -> Dictionary:
	for loot_var: Variant in combat_state.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var as Dictionary
		if str(loot.get("kind", "")) == "equipment" and not bool(loot.get("claimed", false)):
			return loot
	return {}

func _find_control_with_meta(root: Node, key: String, value: String) -> Control:
	if root is Control and str(root.get_meta(key, "")) == value:
		return root as Control
	for child: Node in root.get_children():
		var match: Control = _find_control_with_meta(child, key, value)
		if match != null:
			return match
	return null

func _find_control_with_tooltip(root: Node, tooltip: String) -> Control:
	if root is Control and (root as Control).tooltip_text == tooltip:
		return root as Control
	for child: Node in root.get_children():
		var match: Control = _find_control_with_tooltip(child, tooltip)
		if match != null:
			return match
	return null

func _create_showcase_combat(layout: Dictionary, hand: Array[String]) -> Dictionary:
	var state: Dictionary = _combat_engine.create_combat(CAPTURE_SEED, layout, {
		"hp": 24,
		"max_hp": 24,
		"deck_cards": hand,
		"relics": [],
		"hand_size": hand.size(),
		"cards_per_turn": 3,
		"draw_per_turn": 3,
		"heal_bonus": 0
	})
	var deck: Dictionary = (state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state.erase("player_turn_restrictions")
	return state

func _apply_combat_state(layout: Dictionary, combat_state: Dictionary) -> void:
	var run_state: Dictionary = (_run_scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state
	_run_scene.set("_run_state", run_state)
	_run_scene.set("_combat_state", combat_state)
	_run_scene.call("_reset_card_resolution")
	_run_scene.set("_animation_lock", false)
	_run_scene.set("_card_play_count_override", -1)
	_run_scene.call("_refresh_ui")

func _preview_card_and_tile(card_index: int, tile: Vector2i) -> void:
	_run_scene.call("_on_card_hover_started", card_index)
	_run_scene.call("_on_board_tile_hovered", tile)

func _clear_hover(card_index: int) -> void:
	_run_scene.call("_on_card_hover_ended", card_index)
	_run_scene.call("_on_board_tile_hovered", INVALID_TILE)

func _first_combat_destination() -> Vector2i:
	var run_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var moves: Array[Vector2i] = _vector2i_array(_run_engine.available_moves(run_state))
	for coord: Vector2i in moves:
		var room: Dictionary = _run_engine.room_metadata(run_state, coord)
		if str(room.get("type", "")) == "combat":
			return coord
	return INVALID_TILE

func _base_combat_layout(room_name: String, element: String, depth: int) -> Dictionary:
	return {
		"name": room_name,
		"coord": Vector2i(depth, 0),
		"depth": depth,
		"type": "combat",
		"element": element,
		"grid": _simple_grid(),
		"player_start": Vector2i(2, 4),
		"enemies": [],
		"traps": [],
		"terrain": [],
		"loot": []
	}

func _enemy(id: int, type: String, pos: Vector2i, hp: int) -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0}

func _simple_grid() -> Array:
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or y == 0 or x == 9 or y == 8 else "ash")
		grid.append(row)
	return grid

func _vector2i_array(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for value: Variant in values:
		result.append(value as Vector2i)
	return result

func _live_enemy_count(combat_state: Dictionary) -> int:
	var live_count: int = 0
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		if int((enemy_var as Dictionary).get("hp", 0)) > 0:
			live_count += 1
	return live_count

func _assert_capture(condition: bool, message: String) -> void:
	if condition:
		return
	push_error(message)
	get_tree().quit(2)

func _settle(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame
	await get_tree().process_frame
