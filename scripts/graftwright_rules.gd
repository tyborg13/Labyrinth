extends RefCounted
class_name GraftwrightRules

const Data = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const MIN_COMBATS: int = 3

static func completed_combats(state: Dictionary) -> int:
	var count: int = 0
	for value: Variant in (state.get("rooms", {}) as Dictionary).values():
		if typeof(value) != TYPE_DICTIONARY: continue
		var room: Dictionary = value as Dictionary
		if str(room.get("type", "")) in ["combat", "boss"] and bool(room.get("cleared", false)):
			count += 1
	return count

static func owned(state: Dictionary) -> Array[String]:
	var result: Array[String]
	var items: Array = (state.get("equipped_equipment", {}) as Dictionary).values()
	items.append_array(state.get("equipment_inventory", []) as Array)
	for value: Variant in items:
		var id: String = str(value)
		if not id.is_empty() and not Data.equipment_def(id).is_empty() and not result.has(id): result.append(id)
	return result

static func equipped_slot(state: Dictionary, id: String) -> String:
	var equipped: Dictionary = state.get("equipped_equipment", {}) as Dictionary
	for slot: String in equipped:
		if str(equipped[slot]) == id: return slot
	return ""

static func room_error(state: Dictionary) -> String:
	if str(state.get("mode", "")) != "graftwright": return "Visit the Graftwright to inherit a card."
	var room: Dictionary = Graph.room(state, state.get("current_room", Vector2i.ZERO))
	if str(room.get("type", "")) != "graftwright": return "Visit the Graftwright to inherit a card."
	if bool(room.get("graft_used", false)): return "The work is complete."
	if completed_combats(state) < MIN_COMBATS: return "Complete three combats first."
	return ""

static func pair_error(state: Dictionary, recipient: String, donor: String) -> String:
	if recipient == donor: return "Choose a different item to sacrifice."
	var items: Array[String] = owned(state)
	if not items.has(recipient) or not items.has(donor): return "Choose equipment you own."
	if Data.equipment_slot(recipient) != Data.equipment_slot(donor): return "Equipment must be the same type."
	return ""

static func donors(state: Dictionary, recipient: String) -> Array[String]:
	var result: Array[String]
	for id: String in owned(state):
		if pair_error(state, recipient, id).is_empty(): result.append(id)
	return result

static func inherited_index(state: Dictionary, id: String) -> int:
	return int(((state.get("equipment_grafts", {}) as Dictionary).get(id, {}) as Dictionary).get("index", -1))

static func error(state: Dictionary, recipient: String, donor: String, donor_index: int, target_index: int) -> String:
	var reason: String = room_error(state)
	if not reason.is_empty(): return reason
	reason = pair_error(state, recipient, donor)
	if not reason.is_empty(): return reason
	var source: Array = Data.equipment_cards(donor, state)
	var target: Array = Data.equipment_cards(recipient, state)
	if donor_index < 0 or donor_index >= source.size(): return "Choose a card to inherit."
	if target_index < 0 or target_index >= target.size(): return "Choose a card to replace."
	var inherited: int = inherited_index(state, recipient)
	if inherited >= 0 and inherited != target_index: return "Replace the existing inherited card."
	if source[donor_index] == target[target_index]: return "That card is already here."
	return ""

static func apply(state: Dictionary, recipient: String, donor: String, donor_index: int, target_index: int) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var reason: String = error(state, recipient, donor, donor_index, target_index)
	if not reason.is_empty():
		next["notice"] = reason
		return next
	var before: Array = Data.equipment_cards(recipient, state)
	var incoming: String = str(Data.equipment_cards(donor, state)[donor_index])
	var grafts: Dictionary = (state.get("equipment_grafts", {}) as Dictionary).duplicate(true)
	var origin: String = donor
	if inherited_index(state, donor) == donor_index:
		origin = str((grafts.get(donor, {}) as Dictionary).get("source", donor))
	grafts.erase(donor)
	grafts[recipient] = {"index": target_index, "card_id": incoming, "source": origin}
	next["equipment_grafts"] = grafts
	var inventory: Array = (state.get("equipment_inventory", []) as Array).duplicate()
	inventory.erase(donor)
	var donor_slot: String = equipped_slot(state, donor)
	if not donor_slot.is_empty():
		var equipped: Dictionary = (state.get("equipped_equipment", {}) as Dictionary).duplicate(true)
		var recipient_slot: String = equipped_slot(state, recipient)
		if recipient_slot.is_empty():
			equipped[donor_slot] = recipient
		else:
			# Open Arsenal can equip a second piece of the same native type.
			# Keep the survivor in its native slot and leave the extra slot empty.
			var native_slot: String = Data.equipment_slot(recipient)
			equipped[donor_slot] = ""
			equipped[recipient_slot] = ""
			equipped[native_slot] = recipient
		inventory.erase(recipient)
		next["equipped_equipment"] = equipped
	next["equipment_inventory"] = inventory
	# Collected remains historical, preserving the existing drop exclusions.
	# Shops may sell this equipment again; its consumed graft record is gone.
	for flag: String in ["unread_loadout_equipment", "new_loadout_equipment"]:
		var values: Array = (next.get(flag, []) as Array).duplicate()
		values.erase(donor)
		if not values.has(recipient): values.append(recipient)
		next[flag] = values
	var rooms: Dictionary = (next.get("rooms", {}) as Dictionary).duplicate(true)
	var key: String = Graph.key(next.get("current_room", Vector2i.ZERO))
	var room: Dictionary = (rooms[key] as Dictionary).duplicate(true)
	room["graft_used"] = true
	room["cleared"] = true
	rooms[key] = room
	next["rooms"] = rooms
	next["deck_cards"] = Data.compile_deck_cards(next.get("equipped_equipment", {}) as Dictionary, next.get("attuned_magic_cards", []) as Array, next.get("equipped_items", []) as Array, next)
	var result: Dictionary = {"recipient": recipient, "donor": donor, "slot": Data.equipment_slot(recipient), "room": next.get("current_room", Vector2i.ZERO), "recipient_equipped": not equipped_slot(next, recipient).is_empty(), "card_id": incoming, "replaced_card_id": str(before[target_index]), "index": target_index, "source": origin, "before_cards": before, "after_cards": Data.equipment_cards(recipient, next)}
	next["last_graft"] = result
	room["graft_result"] = result.duplicate(true)
	rooms[key] = room
	next["rooms"] = rooms
	next["notice"] = "%s inherited %s." % [Data.equipment_def(recipient).get("name", recipient), Data.card_def(incoming).get("name", incoming)]
	Graph.record_event(next, "equipment_grafted", result)
	return next

static func leave(state: Dictionary) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if str(next.get("mode", "")) != "graftwright": return next
	var rooms: Dictionary = (next.get("rooms", {}) as Dictionary).duplicate(true)
	var key: String = Graph.key(next.get("current_room", Vector2i.ZERO))
	if not rooms.has(key): return next
	var room: Dictionary = (rooms[key] as Dictionary).duplicate(true)
	room["cleared"] = true
	rooms[key] = room
	next["rooms"] = rooms
	next["mode"] = "room"
	return next
