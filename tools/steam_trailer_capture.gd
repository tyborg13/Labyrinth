extends Control

const RunScene = preload("res://scenes/run_scene.tscn")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const GameDataScript = preload("res://scripts/game_data.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const PathUtils = preload("res://scripts/path_utils.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const CAPTURE_SEED: int = 126044
const REWARD_CAPTURE_SIZE: Vector2i = Vector2i(2304, 1296)
const REWARD_CAPTURE_RAISE: float = 220.0
const SAFE_FRAME_SCALE: float = 0.82
const CAPTURE_OUTPUT_SIZE: Vector2 = Vector2(1920.0, 1080.0)
const INVALID_TILE: Vector2i = Vector2i(-1, -1)
const INVALID_ROOM: Vector2i = Vector2i(999, 999)

var _run_scene: Control
var _run_engine = RunEngineScript.new()
var _combat_engine = CombatEngineScript.new()
var _clip_id: String = "route"
var _safe_frame_capture: bool = false

func _ready() -> void:
	ParallelRuntime.apply_from_environment()
	get_window().size = Vector2i(1920, 1080)
	ProgressionStore.set_storage_path("user://steam_trailer_progression.json")
	ProgressionStore.set_run_storage_path("user://steam_trailer_current_run.save")
	ProgressionStore.clear_saved_run()
	_clip_id = _requested_clip_id()
	_safe_frame_capture = OS.get_cmdline_user_args().has("--safe-frame")
	_configure_capture_cursor()
	_run_scene = RunScene.instantiate()
	_mount_run_scene_for_capture()
	_run_scene.visible = false
	call_deferred("_capture_requested_clip")

func _mount_run_scene_for_capture() -> void:
	if _clip_id in ["relic", "spell"]:
		# CanvasLayer content ignores parent Control transforms. Render the full
		# production scene in a larger 16:9 viewport instead, then downsample its
		# texture into the 1080p movie frame so lower reward controls are recorded.
		var reward_viewport := SubViewport.new()
		reward_viewport.name = "RewardCaptureViewport"
		reward_viewport.size = REWARD_CAPTURE_SIZE
		reward_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		reward_viewport.gui_disable_input = true
		add_child(reward_viewport)
		reward_viewport.add_child(_run_scene)
		_run_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		if _safe_frame_capture:
			_apply_safe_frame_transform(Vector2(REWARD_CAPTURE_SIZE))

		var reward_display := TextureRect.new()
		reward_display.name = "RewardCaptureDisplay"
		reward_display.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		reward_display.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		reward_display.stretch_mode = TextureRect.STRETCH_SCALE
		reward_display.texture = reward_viewport.get_texture()
		reward_display.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(reward_display)
		return
	add_child(_run_scene)
	_run_scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if _safe_frame_capture:
		_apply_safe_frame_transform()


func _configure_capture_cursor() -> void:
	var cursor_feedback: CanvasLayer = get_node_or_null("/root/CursorFeedback") as CanvasLayer
	if cursor_feedback != null:
		cursor_feedback.visible = false
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	_assert_capture(cursor_feedback == null or not cursor_feedback.visible, "Steam marketing capture must hide the custom cursor layer")


func _apply_safe_frame_transform(frame_size: Vector2 = CAPTURE_OUTPUT_SIZE) -> void:
	var safe_offset: Vector2 = frame_size * (1.0 - SAFE_FRAME_SCALE) * 0.5
	var safe_transform := Transform2D(
		Vector2(SAFE_FRAME_SCALE, 0.0),
		Vector2(0.0, SAFE_FRAME_SCALE),
		safe_offset
	)
	var ui_layer: CanvasLayer = _run_scene.get_node_or_null("UiLayer") as CanvasLayer
	var board_layer: CanvasLayer = _run_scene.get_node_or_null("BoardUnderlay") as CanvasLayer
	_assert_capture(ui_layer != null, "Steam screenshot safe frame requires the production UiLayer")
	_assert_capture(board_layer != null and board_layer.transform == Transform2D.IDENTITY, "Steam screenshot capture must leave the production board full-bleed")
	ui_layer.transform = safe_transform
	print("STEAM_TRAILER_SAFE_FRAME ui_scale=%.2f offset=%s output=%s board_full_bleed=true cursor_hidden=true" % [
		SAFE_FRAME_SCALE,
		str(safe_offset),
		str(frame_size)
	])

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
		"magic_equip":
			await _capture_magic_equip()
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
	_seed_known_grimoire_entries(progression)
	if _clip_id in ["merchant", "relic", "spell", "magic_equip", "equipment"]:
		progression["level"] = 7
	var state: Dictionary = _run_engine.create_new_run(CAPTURE_SEED, progression)
	if _clip_id in ["merchant", "relic", "spell", "magic_equip", "equipment"]:
		state = _seed_deep_showcase_loadout(state)
	match _clip_id:
		"route":
			state = _build_deep_route_state(state)
		"prebattle":
			state = _build_prebattle_origin_state(state)
		"trap_combo":
			state = _build_target_room_state(state, "spell", 2)
		"aoe":
			state = _build_target_room_state(state, "spell", 3)
		"umbra":
			state = _build_target_room_state(state, "spell", 6)
		"merchant":
			state = _build_target_room_state(state, "merchant", 4)
			state = _run_engine.set_held_embers(state, 900)
		"relic":
			state = _build_target_room_state(state, "relic", 4)
		"spell":
			state = _build_post_combat_reward_state(_build_target_room_state(state, "spell", 5))
		"magic_equip":
			state = _build_magic_equip_state(
				_build_post_combat_reward_state(_build_target_room_state(state, "spell", 5))
			)
		"equipment":
			state = _build_target_room_state(state, "equipment", 5)
		_:
			state["held_embers"] = 11
			state["unbanked_embers"] = 11
	_run_scene.call("_load_run_state", state)
	_suppress_current_room_dialogue()


func _seed_known_grimoire_entries(progression: Dictionary) -> void:
	# The trailer presents an established run, not first-discovery onboarding.
	# Pre-unlock every current entry so captures stay free of discovery toasts.
	var known_entry_ids: Array[String] = []
	for entry_var: Variant in GrimoireLibrary.entries():
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_var
		var entry_id: String = str(entry.get("id", ""))
		if not entry_id.is_empty():
			known_entry_ids.append(entry_id)
	progression[GrimoireLibrary.UNLOCKED_KEY] = known_entry_ids
	progression[GrimoireLibrary.UNREAD_KEY] = []
	progression[GrimoireLibrary.NOTICE_KEY] = ""

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

func _build_magic_equip_state(reward_state: Dictionary) -> Dictionary:
	var card_id: String = _showcase_reward_card_id(reward_state)
	_assert_capture(not card_id.is_empty(), "Magic equip capture must choose a generated post-combat spell")
	var room_state: Dictionary = _run_engine.claim_card_reward(reward_state, card_id)
	_assert_capture(str(room_state.get("mode", "")) == "room", "Claimed spell must return the run to a legal room state")
	_assert_capture((room_state.get("magic_inventory", []) as Array).has(card_id), "Claimed spell must enter reserve magic before attunement")
	print("STEAM_TRAILER_MAGIC_EQUIP_STATE card=%s rarity=%s attuned=%s reserve=%s" % [
		card_id,
		GameDataScript.card_rarity(card_id),
		str(room_state.get("attuned_magic_cards", [])),
		str(room_state.get("magic_inventory", []))
	])
	return room_state

func _seed_deep_showcase_loadout(initial_state: Dictionary) -> Dictionary:
	var state: Dictionary = initial_state.duplicate(true)
	var equipped: Dictionary = {
		"weapon": "grave_greatsword",
		"offhand": "chain_guard",
		"armor": "voidsilk_carapace",
		"boots": "cloudstep_sandals",
		"trinket": "rime_locket"
	}
	var equipment_inventory: Array = [
		"duelist_rapier",
		"mirror_guard",
		"cinderweave_mail",
		"worldroot_greaves",
		"ember_hourglass"
	]
	var collected_equipment: Array = GameDataScript.starter_equipment_ids().duplicate()
	for equipment_id_var: Variant in equipped.values():
		var equipment_id: String = str(equipment_id_var)
		if not collected_equipment.has(equipment_id):
			collected_equipment.append(equipment_id)
	for equipment_id_var: Variant in equipment_inventory:
		var equipment_id: String = str(equipment_id_var)
		if not collected_equipment.has(equipment_id):
			collected_equipment.append(equipment_id)
	var attuned_magic: Array = [
		"wildfire_halo",
		"spike_mantle",
		"storm_relay",
		"icebound_chains",
		"cinder_bloom",
		"dawnstep"
	]
	var magic_inventory: Array = [
		"prism_sight",
		"cyclone_seal",
		"white_silence",
		"skybreak_current"
	]
	var reward_cards: Array = attuned_magic.duplicate()
	reward_cards.append_array(magic_inventory)
	state["equipped_equipment"] = equipped
	state["equipment_inventory"] = equipment_inventory
	state["collected_equipment"] = collected_equipment
	state["attuned_magic_cards"] = attuned_magic
	state["magic_inventory"] = magic_inventory
	state["reward_cards"] = reward_cards
	state = _run_engine.repair_loaded_run_state(state)
	_assert_capture((state.get("equipment_inventory", []) as Array).size() >= 5, "Deep run must show multiple unequipped gear choices")
	_assert_capture((state.get("magic_inventory", []) as Array).size() >= 4, "Deep run must show multiple reserve spells")
	_assert_capture(_distinct_equipment_rarity_count(equipped) >= 3, "Deep run must equip mixed gear rarities")
	_assert_capture(_distinct_card_rarity_count(attuned_magic) >= 4, "Deep run must attune mixed spell rarities")
	print("STEAM_TRAILER_DEEP_LOADOUT equipment_rarities=%s equipment_inventory=%d magic_rarities=%s magic_inventory=%d" % [
		str(_equipment_rarities(equipped)),
		equipment_inventory.size(),
		str(_card_rarities(attuned_magic)),
		magic_inventory.size()
	])
	return state

func _showcase_reward_card_id(reward_state: Dictionary) -> String:
	var cards: Array = (reward_state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array
	var selected_id: String = ""
	var selected_rank: int = -1
	for card_id_var: Variant in cards:
		var card_id: String = str(card_id_var)
		var rank: int = _rarity_rank(GameDataScript.card_rarity(card_id))
		if rank > selected_rank:
			selected_rank = rank
			selected_id = card_id
	return selected_id

func _rarity_rank(rarity: String) -> int:
	match rarity:
		"legendary":
			return 3
		"epic":
			return 2
		"rare":
			return 1
	return 0

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
	var layout: Dictionary = _generated_combat_layout("trap_combo")
	var anchor: Vector2i = _find_clear_pattern_anchor(layout, [
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(2, -1),
		Vector2i(2, 1)
	])
	_assert_capture(anchor != INVALID_TILE, "Generated trap room must contain a legal five-tile showcase cluster")
	var primary_target: Vector2i = anchor + Vector2i(1, 0)
	var trap_tile: Vector2i = anchor + Vector2i(2, 0)
	layout["player_start"] = anchor
	layout["enemies"] = [
		_enemy(1, "crawler", primary_target),
		_enemy(2, "harrier", trap_tile + Vector2i(0, -1)),
		_enemy(3, "acolyte", trap_tile + Vector2i(0, 1))
	]
	layout["traps"] = [{
		"id": "trailer_fire_snare",
		"element": "fire",
		"pos": trap_tile,
		"damage": 30,
		"burn": 2,
		"armed": true
	}]
	var state: Dictionary = _create_showcase_combat(layout, ["cleaver_hook", "sidestep_slash", "brace"])
	var projected_action: Dictionary = (((GameDataScript.card_def("cleaver_hook").get("actions", []) as Array)[0]) as Dictionary).duplicate(true)
	projected_action["force_direction"] = Vector2i(1, 0)
	var projected_state: Dictionary = _combat_engine.apply_player_action(state.duplicate(true), projected_action, primary_target)
	_assert_capture((projected_state.get("traps", []) as Array).is_empty() and _live_enemy_count(projected_state) == 0, "Scaled Cleaver Hook setup must project a complete three-enemy trap kill")
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.0)
	await _play_showcase_card("cleaver_hook", primary_target, trap_tile)
	var after_state: Dictionary = _capture_combat_result_state()
	_assert_capture((after_state.get("traps", []) as Array).is_empty(), "Cleaver Hook must consume the fire trap")
	_assert_capture(_live_enemy_count(state) == 3 and _live_enemy_count(after_state) == 0, "Cleaver Hook fire-trap blast must kill all three showcased enemies")
	_assert_capture(int((_run_scene.get("_run_state") as Dictionary).get("player_hp", 0)) > 0, "Cleaver Hook trap combo must leave the player alive")
	print("STEAM_TRAILER_TRAP_RESULT room=%s depth=%d furnished=%s card=cleaver_hook natural_play=true trap_consumed=true enemies=3->0 player_alive=true" % [
		str(layout.get("coord", INVALID_ROOM)),
		int(layout.get("depth", 0)),
		str(_layout_furnishing_summary(layout))
	])
	await _settle(1.4)

func _capture_aoe_combo() -> void:
	var layout: Dictionary = _generated_combat_layout("aoe")
	var center: Vector2i = _find_clear_pattern_anchor(layout, [
		Vector2i(-3, 0),
		Vector2i.ZERO,
		Vector2i(1, 0),
		Vector2i(0, 1)
	])
	_assert_capture(center != INVALID_TILE, "Generated AOE room must contain a legal card-and-impact showcase cluster")
	layout["player_start"] = center + Vector2i(-3, 0)
	layout["enemies"] = [
		_enemy(1, "crawler", center),
		_enemy(2, "harrier", center + Vector2i(1, 0)),
		_enemy(3, "acolyte", center + Vector2i(0, 1))
	]
	layout["traps"] = []
	var state: Dictionary = _create_showcase_combat(layout, ["wildfire_halo", "cinder_bloom", "hearth_rush"])
	state["elemental_intensity"] = {"fire": 3, "ice": 0, "lightning": 0, "air": 0, "earth": 0}
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.0)
	await _play_showcase_card("wildfire_halo", center)
	var after_state: Dictionary = _capture_combat_result_state()
	_assert_capture(_live_enemy_count(state) == 3, "Wildfire Halo showcase must begin with exactly three live enemies")
	_assert_capture(_live_enemy_count(after_state) == 0, "Wildfire Halo must kill every showcased enemy")
	print("STEAM_TRAILER_AOE_RESULT room=%s depth=%d furnished=%s card=wildfire_halo natural_play=true enemies=3->0" % [
		str(layout.get("coord", INVALID_ROOM)),
		int(layout.get("depth", 0)),
		str(_layout_furnishing_summary(layout))
	])
	await _settle(1.4)

func _capture_umbra_reveal() -> void:
	var layout: Dictionary = _generated_combat_layout("umbra")
	var placement: Dictionary = _find_umbra_reveal_placement(layout)
	_assert_capture(not placement.is_empty(), "Generated Umbra room must contain a legal edge-of-vision Lantern Shot setup")
	var target: Vector2i = placement.get("target", INVALID_TILE)
	var enemy_tiles: Array[Vector2i] = _vector2i_array(placement.get("enemies", []))
	layout["player_start"] = placement.get("player", INVALID_TILE)
	layout["enemies"] = [
		_enemy(1, "grave_surgeon", enemy_tiles[0]),
		_enemy(2, "crawler", enemy_tiles[1]),
		_enemy(3, "harrier", enemy_tiles[2])
	]
	layout["traps"] = []
	var state: Dictionary = _create_showcase_combat(layout, ["lantern_shot", "guiding_flare", "dawnstep"])
	var visible_enemies_before: int = _umbra_visible_enemy_count(state)
	_assert_capture(visible_enemies_before == 1, "Lantern Shot setup must begin with one visible target and two enemies in real shadow")
	_apply_combat_state(layout, state)
	_show_run_scene()
	await _settle(1.0)
	await _play_showcase_card("lantern_shot", target)
	var after_state: Dictionary = _run_scene.get("_combat_state") as Dictionary
	var umbra: Dictionary = after_state.get("umbra", {}) as Dictionary
	_assert_capture(str(umbra.get("stage", "clear")) == "fringe", "Current-build Umbra showcase must use the depth-six Fringe stage")
	_assert_capture(not (umbra.get("light_sources", []) as Array).is_empty(), "Lantern Shot must leave a real light source in the Umbra")
	_assert_capture(_umbra_visible_enemy_count(after_state) == 3, "Lantern Shot must reveal both enemies that began inside the shadow")
	print("STEAM_TRAILER_UMBRA_RESULT room=%s depth=%d furnished=%s card=lantern_shot natural_play=true umbra=%s light_sources=%d enemies_visible=1->3" % [
		str(layout.get("coord", INVALID_ROOM)),
		int(layout.get("depth", 0)),
		str(_layout_furnishing_summary(layout)),
		str(umbra.get("stage", "clear")),
		(umbra.get("light_sources", []) as Array).size()
	])
	await _settle(1.4)

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
	_raise_reward_choices_for_capture(true)
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
	_assert_capture(
		_control_fully_inside_capture(source_panel),
		"Relic capture must record the complete production choice panel (rect=%s viewport=%s)" % [
			str(source_panel.get_global_rect()),
			str(source_panel.get_viewport_rect().size),
		]
	)
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
	_raise_reward_choices_for_capture(false)
	_show_run_scene()
	await _settle(0.75)
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var cards: Array = ((state.get("pending_reward", {}) as Dictionary).get("cards", []) as Array).duplicate()
	_assert_capture(current != Vector2i.ZERO and str(state.get("mode", "")) == "reward", "Spell capture must use a real post-combat reward state")
	_assert_capture(not cards.is_empty(), "Spell capture must expose generated reward cards")
	var card_id: String = _showcase_reward_card_id(state)
	var source_slot: Control = _find_control_with_meta(_run_scene, "reward_card_id", card_id)
	_assert_capture(source_slot != null, "Spell capture must find the production reward card slot")
	_assert_capture(
		_control_fully_inside_capture(source_slot),
		"Spell capture must record the complete production reward card (rect=%s viewport=%s)" % [
			str(source_slot.get_global_rect()),
			str(source_slot.get_viewport_rect().size),
		]
	)
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

func _raise_reward_choices_for_capture(relic_choices: bool) -> void:
	var choice_control: Control = (
		_run_scene.get("_relic_choice_host") as Control
		if relic_choices
		else _run_scene.get("bottom_stack") as Control
	)
	_assert_capture(choice_control != null, "Reward capture must find its production choice host")
	choice_control.position.y -= REWARD_CAPTURE_RAISE

func _control_fully_inside_capture(control: Control) -> bool:
	if control == null:
		return false
	var rect: Rect2 = control.get_global_rect()
	var viewport_size: Vector2 = control.get_viewport_rect().size
	return rect.position.y >= 0.0 and rect.end.y <= viewport_size.y - 48.0

func _capture_magic_equip() -> void:
	var state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = state.get("current_room", Vector2i.ZERO)
	var new_magic_ids: Array = _run_engine.loadout_new_asset_ids(state, "magic")
	_assert_capture(current != Vector2i.ZERO and str(state.get("mode", "")) == "room", "Magic equip capture must use a real non-start room after reward claim")
	_assert_capture(not new_magic_ids.is_empty(), "Magic equip capture must preserve the newly learned spell marker")
	var card_id: String = str(new_magic_ids[-1])
	var inventory_before: Array = (state.get("magic_inventory", []) as Array).duplicate()
	var attuned_before: Array = (state.get("attuned_magic_cards", []) as Array).duplicate()
	var inventory_index: int = inventory_before.find(card_id)
	var attuned_index: int = maxi(0, attuned_before.size() - 1)
	_assert_capture(inventory_index >= 0 and attuned_before.size() == GameDataScript.magic_loadout_limit(), "Newly learned spell must be a legal reserve-to-attuned swap")
	_run_scene.call("_open_character_overlay", "magic")
	await _settle(0.8)
	_show_run_scene()
	await _settle(0.75)
	var source_rect: Rect2 = _run_scene.call("_magic_tile_rect", "inventory", inventory_index) as Rect2
	var target_rect: Rect2 = _run_scene.call("_magic_tile_rect", "attuned", attuned_index) as Rect2
	var source_control: Control = _run_scene.call("_magic_tile_control", "inventory", inventory_index) as Control
	_assert_capture(source_control != null and source_rect.size.x > 0.0 and target_rect.size.x > 0.0, "Magic capture must render the reserve spell and attuned target slot")
	_run_scene.call(
		"_begin_magic_overlay_drag",
		"inventory",
		inventory_index,
		card_id,
		source_rect,
		source_control,
		source_rect.get_center()
	)
	await _settle(0.5)
	await _run_scene.call("_release_magic_overlay_drag", target_rect.get_center())
	var after_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var attuned_after: Array = after_state.get("attuned_magic_cards", []) as Array
	var inventory_after: Array = after_state.get("magic_inventory", []) as Array
	_assert_capture(str(attuned_after[attuned_index]) == card_id, "Production magic drag must attune the newly learned spell")
	_assert_capture(inventory_after.has(str(attuned_before[attuned_index])), "Production magic swap must move the replaced spell to reserve")
	_assert_capture(_distinct_card_rarity_count(attuned_after) >= 3, "Attuned magic must retain varied rarities after the swap")
	print("STEAM_TRAILER_MAGIC_EQUIP_RESULT room=%s depth=%d card=%s rarity=%s attuned_slot=%d attuned_rarities=%s reserve_count=%d natural_drag=true" % [
		str(current),
		_room_depth_for_state(after_state, current),
		card_id,
		GameDataScript.card_rarity(card_id),
		attuned_index,
		str(_card_rarities(attuned_after)),
		inventory_after.size()
	])
	await _settle(1.25)

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
	var inventory_after: Array = equipped_state.get("equipment_inventory", []) as Array
	_assert_capture(inventory_after.size() >= 5, "Equipment overlay must retain multiple unequipped gear choices")
	_assert_capture(_distinct_equipment_rarity_count(equipped) >= 2, "Equipped loadout must retain varied gear rarities after the swap")
	print("STEAM_TRAILER_EQUIPMENT_RESULT room=%s depth=%d room_type=%s equipment=%s rarity=%s slot=%s collected=true equipped=true equipped_rarities=%s inventory_count=%d" % [
		str(current),
		int(room.get("depth", 0)),
		str(room.get("type", "")),
		equipment_id,
		GameDataScript.equipment_rarity(equipment_id),
		slot,
		str(_equipment_rarities(equipped)),
		inventory_after.size()
	])
	await _settle(1.0)

func _equipment_rarities(equipped: Dictionary) -> Array:
	var result: Array = []
	for equipment_id_var: Variant in equipped.values():
		var rarity: String = GameDataScript.equipment_rarity(str(equipment_id_var))
		if not result.has(rarity):
			result.append(rarity)
	return result

func _card_rarities(card_ids: Array) -> Array:
	var result: Array = []
	for card_id_var: Variant in card_ids:
		var rarity: String = GameDataScript.card_rarity(str(card_id_var))
		if not result.has(rarity):
			result.append(rarity)
	return result

func _distinct_equipment_rarity_count(equipped: Dictionary) -> int:
	return _equipment_rarities(equipped).size()

func _distinct_card_rarity_count(card_ids: Array) -> int:
	return _card_rarities(card_ids).size()

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

func _play_showcase_card(card_id: String, target: Vector2i, orientation_confirmation: Vector2i = INVALID_TILE) -> void:
	var state_before: Dictionary = _run_scene.get("_combat_state") as Dictionary
	var hand: Array = (state_before.get("deck", {}) as Dictionary).get("hand", []) as Array
	_assert_capture(not hand.is_empty() and str(hand[0]) == card_id, "Showcase card must occupy the first visible hand slot: %s" % card_id)
	_run_scene.call("_on_card_hover_started", 0)
	await _settle(0.8)
	await _run_scene.call("_on_card_pressed", 0)
	_assert_capture(int(_run_scene.get("_selected_card_index")) == 0, "Production card selection must enter target preview for %s" % card_id)
	_run_scene.call("_on_board_tile_hovered", target)
	await _settle(0.7)
	print("STEAM_TRAILER_CARD_COMMIT card=%s target=%s hand_index=0 natural_play=true" % [card_id, str(target)])
	await _run_scene.call("_on_board_tile_clicked", target)
	if int(_run_scene.get("_selected_card_index")) == 0:
		_assert_capture(orientation_confirmation != INVALID_TILE, "Natural play requires an orientation confirmation for %s" % card_id)
		_assert_capture(_run_scene.get("_pending_orientation_target_tile") == target, "Production card flow must request direction confirmation for %s" % card_id)
		_run_scene.call("_on_board_tile_hovered", orientation_confirmation)
		await _settle(0.35)
		print("STEAM_TRAILER_CARD_ORIENTATION card=%s target=%s confirmation=%s natural_play=true" % [card_id, str(target), str(orientation_confirmation)])
		await _run_scene.call("_on_board_tile_clicked", orientation_confirmation)
	_assert_capture(not bool(_run_scene.get("_animation_lock")), "Production card resolution must finish cleanly for %s" % card_id)
	_assert_capture(int(_run_scene.get("_selected_card_index")) == -1, "Production card resolution must clear selection for %s" % card_id)

func _capture_combat_result_state() -> Dictionary:
	var combat_state: Dictionary = _run_scene.get("_combat_state") as Dictionary
	if not combat_state.is_empty():
		return combat_state
	var run_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	return (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)

func _generated_combat_layout(clip_id: String) -> Dictionary:
	var run_state: Dictionary = _run_scene.get("_run_state") as Dictionary
	var current: Vector2i = run_state.get("current_room", Vector2i.ZERO)
	var layout: Dictionary = (run_state.get("current_room_layout", {}) as Dictionary).duplicate(true)
	_assert_capture(current != Vector2i.ZERO, "%s must use a non-start generated room" % clip_id)
	_assert_capture(str(run_state.get("mode", "")) == "combat", "%s must begin from a legal combat-room state" % clip_id)
	_assert_capture(str(layout.get("type", "")) == "combat", "%s must preserve a production combat layout" % clip_id)
	_assert_capture(layout.get("coord", INVALID_ROOM) == current, "%s layout coordinate must match the run's current room" % clip_id)
	_assert_capture(not (layout.get("grid", []) as Array).is_empty(), "%s must preserve its generated grid" % clip_id)
	_assert_capture((layout.get("terrain", []) as Array).size() >= 3, "%s must preserve generated room furniture" % clip_id)
	var moss: Dictionary = layout.get("moss", {}) as Dictionary
	_assert_capture(not moss.is_empty(), "%s must preserve generated moss dressing" % clip_id)
	layout["enemies"] = []
	layout["traps"] = []
	return layout

func _find_clear_pattern_anchor(layout: Dictionary, offsets: Array) -> Vector2i:
	var grid: Array = layout.get("grid", []) as Array
	if grid.is_empty():
		return INVALID_TILE
	var blocked: Dictionary = _layout_occupied_tiles(layout)
	var center: Vector2 = Vector2(float((grid[0] as Array).size() - 1) * 0.5, float(grid.size() - 1) * 0.5)
	var best: Vector2i = INVALID_TILE
	var best_score: float = INF
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var anchor: Vector2i = Vector2i(x, y)
			var valid: bool = true
			for offset_var: Variant in offsets:
				var offset: Vector2i = offset_var as Vector2i
				var tile: Vector2i = anchor + offset
				if not PathUtils.is_passable(grid, tile) or blocked.has(tile):
					valid = false
					break
			if not valid:
				continue
			var score: float = Vector2(anchor).distance_squared_to(center)
			if score < best_score:
				best_score = score
				best = anchor
	return best

func _find_umbra_reveal_placement(layout: Dictionary) -> Dictionary:
	var grid: Array = layout.get("grid", []) as Array
	if grid.is_empty():
		return {}
	var blocked: Dictionary = _layout_occupied_tiles(layout)
	var open_tiles: Array[Vector2i] = []
	for y: int in range(1, grid.size() - 1):
		for x: int in range(1, (grid[y] as Array).size() - 1):
			var tile: Vector2i = Vector2i(x, y)
			if PathUtils.is_passable(grid, tile) and not blocked.has(tile):
				open_tiles.append(tile)
	for player: Vector2i in open_tiles:
		for target: Vector2i in open_tiles:
			if PathUtils.manhattan(player, target) != 6 or not PathUtils.has_line_of_sight(grid, player, target):
				continue
			var hidden_neighbors: Array[Vector2i] = []
			for direction: Vector2i in PathUtils.DIRS_4:
				var neighbor: Vector2i = target + direction
				if not open_tiles.has(neighbor) or PathUtils.manhattan(player, neighbor) <= 6:
					continue
				hidden_neighbors.append(neighbor)
			if hidden_neighbors.size() < 2:
				continue
			var enemies: Array[Vector2i] = _vector2i_array([target, hidden_neighbors[0], hidden_neighbors[1]])
			return {"player": player, "target": target, "enemies": enemies}
	return {}

func _umbra_visible_enemy_count(combat_state: Dictionary) -> int:
	var visible_tiles: Array[Vector2i] = _combat_engine.umbra_visible_tiles(combat_state)
	var visible_count: int = 0
	for enemy_var: Variant in combat_state.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY:
			continue
		var enemy: Dictionary = enemy_var as Dictionary
		if int(enemy.get("hp", 0)) > 0 and visible_tiles.has(enemy.get("pos", INVALID_TILE)):
			visible_count += 1
	return visible_count

func _layout_occupied_tiles(layout: Dictionary) -> Dictionary:
	var occupied: Dictionary = {}
	for collection_key: String in ["terrain", "loot", "npcs"]:
		for entry_var: Variant in layout.get(collection_key, []):
			if typeof(entry_var) != TYPE_DICTIONARY:
				continue
			var tile_var: Variant = (entry_var as Dictionary).get("pos", INVALID_TILE)
			if typeof(tile_var) == TYPE_VECTOR2I:
				occupied[tile_var as Vector2i] = true
	return occupied

func _layout_furnishing_summary(layout: Dictionary) -> String:
	var grid: Array = layout.get("grid", []) as Array
	var interior_obstacles: int = 0
	for y: int in range(1, maxi(1, grid.size() - 1)):
		var row: Array = grid[y] as Array
		for x: int in range(1, maxi(1, row.size() - 1)):
			if str(row[x]) in ["wall", "pillar"]:
				interior_obstacles += 1
	return "terrain=%d interior_obstacles=%d moss=%s loot=%d" % [
		(layout.get("terrain", []) as Array).size(),
		interior_obstacles,
		str(not (layout.get("moss", {}) as Dictionary).is_empty()),
		(layout.get("loot", []) as Array).size()
	]

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

func _enemy(id: int, type: String, pos: Vector2i) -> Dictionary:
	var hp: int = int(GameDataScript.enemy_def(type).get("max_hp", 1))
	return {"id": id, "type": type, "pos": pos, "hp": hp, "max_hp": hp, "block": 0, "stoneskin": 0}

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
