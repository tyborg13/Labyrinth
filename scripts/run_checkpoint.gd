extends RefCounted

## The same on-disk contract governs Continue and Windows backup rotation.
const DemoBuild = preload("res://scripts/demo_build.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const SectionMapGraph = preload("res://scripts/section_map_graph.gd")
const GameData = preload("res://scripts/game_data.gd")
const Objectives = preload("res://scripts/combat_objective_rules.gd")

static func normalize_seed(state: Dictionary) -> void:
	var seed: Variant = state.get("seed")
	# Integral Variant floats from older builds fit the same int64 seed space.
	if seed is float and seed == floor(seed) and seed >= -9223372036854775808.0 and seed < 9223372036854775808.0:
		state["seed"] = int(seed)

static func build_stamp_allowed(state: Dictionary) -> bool:
	return (str(state.get("build_kind", "")) == "demo") == DemoBuild.is_demo()

static func past_demo_cutoff(state: Dictionary) -> bool:
	# Invalid coordinate or room types are left for structural validation.
	if not DemoBuild.is_demo() or not state.get("current_room") is Vector2i or not state.get("rooms") is Dictionary:
		return false
	var room: Variant = state["rooms"].get(SectionMapGraph.key(state["current_room"]))
	return room is Dictionary and _is_numeric_value(room.get("section_index", 0)) and DemoRules.is_past_cutoff(state)

static func has_checkpoint(state: Dictionary) -> bool:
	var rooms: Variant = state.get("rooms")
	if not state.get("seed") is int or not rooms is Dictionary or rooms.is_empty(): return false
	if not SectionMapGraph.enabled(state): return true
	var sections: Variant = state.get("map_sections")
	return sections is Array and not sections.is_empty()

static func validated_resume_summary(run_state: Dictionary) -> Dictionary:
	var summary := _validated_summary(run_state)
	if summary.is_empty(): return {}
	var mode: String = summary["mode"]
	if mode in ["abandoned", "embrace"]: return {}
	if mode in ["victory", "defeat"]:
		var boons: Script = load("res://scripts/opening_boon_rules.gd")
		if not boons.call("heirloom_prompt_pending", run_state): return {}
	var engine := load("res://scripts/run_engine.gd") as Script if int(run_state.get("combat_units_schema", 0)) < 1 else null
	if engine != null:
		var migrated: Dictionary = engine.call("migrate_combat_units", run_state)
		summary["hp"] = int(migrated["player_hp"])
		summary["max_hp"] = int(migrated["player_max_hp"])
	return summary

static func is_terminal_record(state: Dictionary) -> bool:
	return state.get("mode") in ["victory", "defeat", "abandoned", "embrace"] and not _validated_summary(state).is_empty()

static func _validated_summary(run_state: Dictionary) -> Dictionary:
	if not _is_numeric_value(run_state.get("section_map_version", 0)) or not run_state.get("combat_state", {}) is Dictionary:
		return {}
	if not has_checkpoint(run_state) or not build_stamp_allowed(run_state) or past_demo_cutoff(run_state):
		return {}
	var mode_value: Variant = run_state.get("mode", null)
	var coord_value: Variant = run_state.get("current_room", null)
	var hp_value: Variant = run_state.get("player_hp", null)
	var max_hp_value: Variant = run_state.get("player_max_hp", null)
	var ember_value: Variant = run_state.get("held_embers", run_state.get("unbanked_embers", null))
	if typeof(mode_value) not in [TYPE_STRING, TYPE_STRING_NAME]:
		return {}
	if typeof(coord_value) != TYPE_VECTOR2I:
		return {}
	if not _is_numeric_value(hp_value) or not _is_numeric_value(max_hp_value) or not _is_numeric_value(ember_value):
		return {}
	# Compare serialized units first. Convert only the display values for old saves.
	var player_hp: int = int(hp_value)
	var player_max_hp: int = int(max_hp_value)
	var held_embers: int = int(ember_value)
	if player_max_hp <= 0 or player_hp < 0 or player_hp > player_max_hp or held_embers < 0:
		return {}
	var coord: Vector2i = coord_value
	if not _has_saved_run_structure(run_state, str(mode_value), coord, player_hp, player_max_hp):
		return {}
	return {"mode": str(mode_value), "coord": coord, "hp": player_hp, "max_hp": player_max_hp, "embers": held_embers}

static func _has_saved_run_structure(run_state: Dictionary, mode: String, coord: Vector2i, player_hp: int, player_max_hp: int) -> bool:
	if typeof(run_state.get("current_room_layout", null)) != TYPE_DICTIONARY or (run_state.get("current_room_layout", {}) as Dictionary).is_empty():
		return false
	var room_value: Variant = run_state["rooms"].get("%d,%d" % [coord.x, coord.y], null)
	if typeof(room_value) != TYPE_DICTIONARY:
		return false
	var room: Dictionary = room_value
	if not _is_numeric_value(room.get("depth", null)) or str(room.get("type", "")).is_empty():
		return false
	var room_coord_value: Variant = room.get("coord", null)
	if typeof(room_coord_value) != TYPE_VECTOR2I or room_coord_value != coord:
		return false
	var deck_value: Variant = run_state.get("deck_cards", null)
	if typeof(deck_value) != TYPE_ARRAY or (deck_value as Array).is_empty():
		return false
	match mode:
		"victory", "defeat":
			return run_state.get("heirloom_end", {}) is Dictionary and run_state.get("equipped_equipment", {}) is Dictionary
		"abandoned", "embrace":
			return true
		"combat":
			return _has_resumable_combat_structure(run_state, player_hp, player_max_hp)
		"pre_battle":
			return bool(run_state.get("pre_battle_pending", false)) and typeof(run_state.get("pre_battle_travel_dir", null)) == TYPE_VECTOR2I
		"reward":
			var reward_value: Variant = run_state.get("pending_reward", null)
			if typeof(reward_value) != TYPE_DICTIONARY:
				return false
			var reward: Dictionary = reward_value
			# A dragon's milestone reward (relic, embers, healing) offers no cards.
			if str(reward.get("kind", "")) == "dragon":
				return not str(reward.get("milestone_id", "")).is_empty()
			return typeof(reward.get("cards", null)) == TYPE_ARRAY and not (reward.get("cards", []) as Array).is_empty()
		"treasure":
			var relics_value: Variant = run_state.get("pending_relics", null)
			return typeof(relics_value) == TYPE_ARRAY and not (relics_value as Array).is_empty()
		"graftwright":
			return str(room.get("type", "")) == "graftwright"
		"event":
			return _has_resumable_event(run_state, room)
		"escape":
			return _has_resumable_escape(run_state, room, coord)
		"room", "campfire":
			return true
	return false

static func _has_resumable_combat_structure(run_state: Dictionary, player_hp: int, player_max_hp: int) -> bool:
	var combat_value: Variant = run_state.get("combat_state", null)
	if typeof(combat_value) != TYPE_DICTIONARY or (combat_value as Dictionary).is_empty():
		return false
	var combat_state: Dictionary = combat_value
	var combat_player_value: Variant = combat_state.get("player", null)
	if typeof(combat_player_value) != TYPE_DICTIONARY:
		return false
	var combat_player: Dictionary = combat_player_value
	if not _is_numeric_value(combat_player.get("hp", null)) or not _is_numeric_value(combat_player.get("max_hp", null)):
		return false
	if int(combat_player.get("hp", -1)) != player_hp or int(combat_player.get("max_hp", -1)) != player_max_hp:
		return false
	var combat_deck_value: Variant = combat_state.get("deck", null)
	var enemies_value: Variant = combat_state.get("enemies", null)
	return (
		typeof(combat_deck_value) == TYPE_DICTIONARY
		and not (combat_deck_value as Dictionary).is_empty()
		and typeof(enemies_value) == TYPE_ARRAY
		and not (enemies_value as Array).is_empty()
	)

static func _is_numeric_value(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))

static func _has_resumable_event(state: Dictionary, room: Dictionary) -> bool:
	if str(room.get("type", "")) != "event" or bool(room.get("cleared", false)): return false
	var id: String = str(room.get("event_id", "lost_cartographer"))
	var definition: Dictionary = GameData.event_def(id)
	if definition.is_empty(): return false
	# Older event rooms let EventRules reconstruct the choices on resume.
	var event: Variant = state.get("event_state", {})
	if not event is Dictionary: return false
	if event.is_empty(): return true
	if str(event.get("event_id", "")) != id: return false
	var outcomes: Variant = event.get("outcomes")
	if not outcomes is Array or not outcomes.all(func(outcome: Variant) -> bool: return outcome is Dictionary): return false
	match str(event.get("page", "")):
		"choices":
			return true
		"result":
			if not event.get("result_text") is String: return false
			for choice: Dictionary in definition["choices"]:
				if choice["id"] == event.get("choice_id"): return true
	return false

static func _has_resumable_escape(state: Dictionary, room: Dictionary, coord: Vector2i) -> bool:
	var escape: Variant = state.get("pending_escape")
	if not escape is Dictionary or not escape.get("target_tile") is Vector2i: return false
	var board: Variant = escape.get("board_state")
	if not board is Dictionary or not board.get("objective") is Dictionary or not board.get("player") is Dictionary: return false
	var objective: Dictionary = board["objective"]
	if objective.get("type") != Objectives.REACH_EXIT or not objective.get("exits") is Array: return false
	# RunEngine repairs the saved route from the objective's unsealed exit.
	var exit: Dictionary = Objectives.exit_spec_for_target(objective, escape["target_tile"])
	var destination: Variant = exit.get("coord")
	if not destination is Vector2i or destination == coord or not exit.get("door_tile", Vector2i(-1, -1)) is Vector2i: return false
	var target_room: Variant = state["rooms"].get(SectionMapGraph.key(destination))
	if not target_room is Dictionary or bool(target_room.get("sealed", false)): return false
	var connections: Variant = room.get("connections")
	return connections is Array and connections.any(func(link: Variant) -> bool:
		return link is Dictionary and link.get("coord") == destination
	)
