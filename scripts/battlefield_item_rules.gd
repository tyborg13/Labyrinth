extends RefCounted

const MAX_HAND_SIZE: int = 7

const GameData = preload("res://scripts/game_data.gd")

static func normalized_loot(entries: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry_var: Variant in entries:
		if typeof(entry_var) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = (entry_var as Dictionary).duplicate(true)
		var legacy_kind: String = str(entry.get("kind", ""))
		if legacy_kind in ["healing_vial", "rusty_shield"]:
			entry["kind"] = "item"
			entry["card_id"] = "crimson_draught" if legacy_kind == "healing_vial" else "bone_ward_charm"
			entry.erase("amount")
		result.append(entry)
	return result

static func active_items_from_deck(deck: Dictionary) -> Array:
	var items: Array = []
	for zone: String in ["draw", "hand", "discard", "burned"]:
		for card_var: Variant in deck.get(zone, []):
			if GameData.card_is_item(str(card_var)):
				items.append(str(card_var))
	return items

static func collect(state: Dictionary, loot: Dictionary) -> void:
	var card_id: String = str(loot.get("card_id", ""))
	if not GameData.card_is_item(card_id):
		return
	var deck: Dictionary = state.get("deck", {})
	var equipped: Array = state.get("equipped_items", active_items_from_deck(deck)).duplicate()
	var inventory: Array = state.get("item_inventory", []).duplicate()
	if equipped.size() < GameData.item_loadout_limit():
		equipped.append(card_id)
		var hand: Array = deck.get("hand", []).duplicate()
		# Keep the ordinary hand cap: the next draw receives a pickup when full.
		if hand.size() < MAX_HAND_SIZE:
			hand.append(card_id)
			deck["hand"] = hand
			loot["destination"] = "hand"
		else:
			var draw_pile: Array = deck.get("draw", []).duplicate()
			draw_pile.append(card_id)
			deck["draw"] = draw_pile
			loot["destination"] = "draw"
		state["deck"] = deck
	else:
		inventory.append(card_id)
		loot["destination"] = "inventory"
	state["equipped_items"] = equipped
	state["item_inventory"] = inventory

static func consume(state: Dictionary, card_id: String) -> void:
	if not state.has("equipped_items"):
		return
	var equipped: Array = state.get("equipped_items", []).duplicate()
	equipped.erase(card_id)
	state["equipped_items"] = equipped

static func repair_loaded_run(run_state: Dictionary) -> Dictionary:
	# Restore legacy floor objects without granting anything or replaying a
	# collection. Claimed flags/ids remain intact, including in saved checkpoints.
	var result: Dictionary = run_state.duplicate(true)
	for key: String in ["combat_state", "current_room_layout"]:
		if typeof(result.get(key)) == TYPE_DICTIONARY:
			result[key] = _repair_board(result[key], result)
	for key: String in ["pending_reward", "pending_escape"]:
		var pending: Dictionary = result.get(key, {})
		if typeof(pending.get("board_state")) == TYPE_DICTIONARY:
			pending["board_state"] = _repair_board(pending["board_state"], result)
	for checkpoint_var: Variant in result.get("pending_combat_checkpoints", []):
		if typeof(checkpoint_var) == TYPE_DICTIONARY and typeof(checkpoint_var.get("state")) == TYPE_DICTIONARY:
			checkpoint_var["state"] = _repair_board(checkpoint_var["state"], result)
	return result

static func pickups_between(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	var claimed_before: Dictionary = {}
	for loot_var: Variant in before.get("loot", []):
		if typeof(loot_var) == TYPE_DICTIONARY and bool(loot_var.get("claimed", false)):
			claimed_before[str(loot_var.get("id", loot_var.get("pos", "")))] = true
	var result: Array[Dictionary] = []
	for loot_var: Variant in after.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY:
			continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) != "item" or not bool(loot.get("claimed", false)) or str(loot.get("resolution", "")) == "missed":
			continue
		if not claimed_before.has(str(loot.get("id", loot.get("pos", "")))):
			result.append(loot.duplicate(true))
	return result

static func hand_pickup_counts(before: Dictionary, after: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for loot: Dictionary in pickups_between(before, after):
		if str(loot.get("destination", "")) == "hand":
			var card_id: String = str(loot.get("card_id", ""))
			result[card_id] = int(result.get(card_id, 0)) + 1
	return result

static func _repair_board(board: Dictionary, run_state: Dictionary) -> Dictionary:
	var result: Dictionary = board.duplicate(true)
	if result.is_empty():
		return result
	result["loot"] = normalized_loot(result.get("loot", []))
	if result.has("deck"):
		if not result.has("equipped_items"):
			result["equipped_items"] = run_state.get("equipped_items", []).duplicate()
		if not result.has("item_inventory"):
			result["item_inventory"] = run_state.get("item_inventory", []).duplicate()
	return result
