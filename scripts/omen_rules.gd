extends RefCounted
class_name OmenRules

const GameData = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const EFFECT_TYPES: Array = ["start_block", "start_stoneskin", "start_expose", "start_vision_turns", "first_turn_card_plays", "first_turn_movement", "start_on_fire", "umbra_stage_delta", "ember_drop_percent", "extra_enemies"]
const START_APPLIED_KEY: String = "omen_start_applied_ids"

static func active(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in state.get("omens", []):
		var definition: Dictionary = GameData.omen_def(str(entry.get("id", "")))
		if definition.is_empty() or int(entry.get("fights_left", 0)) <= 0: continue
		result.append({"id": entry["id"], "name": definition["name"], "kind": definition["kind"], "description": definition["description"], "fights_left": int(entry["fights_left"])})
	return result

static func add(state: Dictionary, id: String) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var definition: Dictionary = GameData.omen_def(id)
	if definition.is_empty(): return next
	var entries: Array = next.get("omens", []).duplicate(true)
	var refreshed: bool = false
	var duration: int = int(definition["fights"])
	for entry: Dictionary in entries:
		if str(entry.get("id", "")) == id:
			duration = maxi(int(entry.get("fights_left", 0)), duration)
			entry["fights_left"] = duration
			refreshed = true
	if not refreshed: entries.append({"id": id, "fights_left": int(definition["fights"])})
	next["omens"] = entries
	Graph.record_event(next, "omen_gained", {"id": id, "fights": duration})
	return next

static func tick(state: Dictionary) -> Dictionary:
	if (state.get("omens", []) as Array).is_empty(): return state
	var next: Dictionary = state.duplicate(true)
	var remaining: Array[Dictionary]
	for entry: Dictionary in next.get("omens", []):
		entry["fights_left"] = int(entry.get("fights_left", 0)) - 1
		if int(entry["fights_left"]) > 0: remaining.append(entry)
		else: Graph.record_event(next, "omen_expired", {"id": entry["id"]})
	next["omens"] = remaining
	return next

static func effects(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for entry: Dictionary in active(state):
		result.append(GameData.omen_def(str(entry["id"]))["effect"])
	return result

static func amount(state: Dictionary, type: String) -> int:
	var total: int = 0
	for effect: Dictionary in effects(state):
		if str(effect.get("type", "")) == type: total += int(effect.get("amount", 0))
	return total

static func start_combat(engine: RefCounted, state: Dictionary, snapshot: Dictionary, extra_enemies_added: int = 0) -> Dictionary:
	if active(snapshot).is_empty(): return state
	state["omens"] = snapshot.get("omens", []).duplicate(true)
	state.erase(START_APPLIED_KEY)
	var entries: Array[Dictionary] = active(state)
	var applied: Dictionary = {}
	var player: Dictionary = state["player"]
	for entry: Dictionary in entries:
		var effect: Dictionary = GameData.omen_def(str(entry["id"]))["effect"]
		var value: int = int(effect.get("amount", 0))
		var changed: bool = false
		match str(effect["type"]):
			"start_block", "start_stoneskin", "start_expose":
				var field: String = str(effect["type"]).trim_prefix("start_")
				player[field] = int(player.get(field, 0)) + value
				changed = value != 0
			"start_vision_turns":
				var old_vision: Array = [state["umbra"].get("vision_bonus", 0), state["umbra"].get("vision_bonus_activations", 0)]
				state = engine._apply_umbra_vision(state, {"amount": int(effect["radius"]), "duration": value})
				changed = old_vision != [state["umbra"].get("vision_bonus", 0), state["umbra"].get("vision_bonus_activations", 0)]
			"first_turn_card_plays", "first_turn_movement": pass
			"start_on_fire":
				var old_surface: Dictionary = Surfaces.surface_at(state, player["pos"]).duplicate(true)
				if Surfaces.can_place(state, player["pos"]): Surfaces.place(state, player["pos"], "fire")
				changed = old_surface != Surfaces.surface_at(state, player["pos"])
			"umbra_stage_delta":
				var umbra: Dictionary = state["umbra"]
				var stages: Array = engine.UMBRA_STAGE_ORDER
				var old_stage: String = str(umbra["stage"])
				umbra["stage"] = stages[clampi(stages.find(str(umbra["stage"])) + value, 0, stages.size() - 2)]
				changed = old_stage != str(umbra["stage"])
			"extra_enemies": changed = value > 0 and extra_enemies_added > 0
		if changed: applied[str(entry["id"])] = true
	var plays: int = amount(state, "first_turn_card_plays")
	if plays != 0:
		var base_plays: int = int(state["cards_per_turn"])
		var old_bonus: int = int(state.get("card_play_bonus_this_turn", 0))
		state["card_play_bonus_this_turn"] = maxi(1, base_plays + int(state.get("card_play_bonus_this_turn", 0)) + plays) - base_plays
		if old_bonus != int(state["card_play_bonus_this_turn"]): _mark_type(entries, "first_turn_card_plays", applied)
	var movement: int = amount(state, "first_turn_movement")
	if movement != 0:
		var old_capacity: int = int(state["player_movement_capacity"])
		var old_remaining: int = int(state["player_movement_remaining"])
		state["player_movement_capacity"] = maxi(0, int(state["player_movement_capacity"]) + movement)
		state["player_movement_remaining"] = state["player_movement_capacity"]
		if old_capacity != int(state["player_movement_capacity"]) or old_remaining != int(state["player_movement_remaining"]): _mark_type(entries, "first_turn_movement", applied)
	var ids: Array[String]
	for entry: Dictionary in entries:
		if applied.has(str(entry["id"])): ids.append(str(entry["id"]))
	# Additive presentation receipt. No receipt for no-op or drop-time effects.
	if not ids.is_empty(): state[START_APPLIED_KEY] = ids
	return state

static func _mark_type(entries: Array[Dictionary], type: String, applied: Dictionary) -> void:
	for entry: Dictionary in entries:
		var effect: Dictionary = GameData.omen_def(str(entry["id"]))["effect"]
		if str(effect["type"]) == type and int(effect.get("amount", 0)) != 0: applied[str(entry["id"])] = true

static func first_movement(state: Dictionary) -> int:
	if int(state.get("turn", 1)) != 1 or (state.get("omens", []) as Array).is_empty(): return 0
	return amount(state, "first_turn_movement")

static func ember_drop(state: Dictionary, base: int) -> int:
	var value: float = float(base)
	for effect: Dictionary in effects(state):
		if str(effect.get("type", "")) == "ember_drop_percent": value *= float(effect["amount"]) / 100.0
	return int(floor(value + 0.5))
