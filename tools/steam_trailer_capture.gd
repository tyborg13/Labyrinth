extends Control

const RunScene = preload("res://scenes/run_scene.tscn")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const CombatEngineScript = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")

const CAPTURE_SEED: int = 126044
const INVALID_TILE: Vector2i = Vector2i(-1, -1)

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
		"reward":
			await _capture_reward()
		_:
			push_error("Unknown Steam trailer clip: %s" % _clip_id)
			get_tree().quit(2)
			return
	await _settle(0.35)
	get_tree().quit()

func _seed_showcase_run() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 22
	progression["card_upgrades_unlocked"] = true
	var state: Dictionary = _run_engine.create_new_run(CAPTURE_SEED, progression)
	state["unbanked_embers"] = 11
	_run_scene.call("_load_run_state", state)
	_run_scene.call("_close_dialogue")

func _capture_route() -> void:
	await _settle(0.8)
	_run_scene.call("_open_large_map")
	await _settle(4.4)
	_run_scene.call("_close_large_map")
	await _settle(0.8)

func _capture_prebattle() -> void:
	await _settle(0.75)
	var destination: Vector2i = _first_combat_destination()
	if destination == INVALID_TILE:
		push_error("Capture seed has no available combat destination")
		return
	await _run_scene.call("_on_map_view_room_selected", destination)
	await _settle(3.4)
	_run_scene.call("_on_pre_battle_start_pressed")
	await _settle(1.9)

func _capture_trap_combo() -> void:
	var layout: Dictionary = _base_combat_layout("The Ember Snare", "fire", 7)
	layout["player_start"] = Vector2i(3, 4)
	layout["enemies"] = [
		_enemy(1, "warden", Vector2i(4, 4), 36),
		_enemy(2, "crawler", Vector2i(5, 3), 30),
		_enemy(3, "acolyte", Vector2i(5, 5), 30)
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

func _capture_reward() -> void:
	var state: Dictionary = (_run_scene.get("_run_state") as Dictionary).duplicate(true)
	state["mode"] = "reward"
	state["pending_reward"] = {
		"cards": ["cinderburst", "thunderline", "grave_cleave"],
		"heal_amount": RunEngineScript.REWARD_HEAL,
		"ember_amount": 12
	}
	state["unbanked_embers"] = 27
	state["combat_state"] = {}
	_run_scene.call("_load_run_state", state)
	_run_scene.call("_close_dialogue")
	await _settle(4.8)

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

func _settle(seconds: float) -> void:
	if seconds > 0.0:
		await get_tree().create_timer(seconds).timeout
	await get_tree().process_frame
	await get_tree().process_frame

