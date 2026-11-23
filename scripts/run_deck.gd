extends RefCounted

const Data = preload("res://scripts/game_data.gd")
const ElementData = preload("res://scripts/element_data.gd")

const ADDITION_ORDER_KEY: String = "deck_card_addition_order"
const ITEM_SLOT_ORDER_KEY: String = "deck_item_slot_addition_order"
const STARTER_BUFFET_SLOT_KEY: String = "starter_buffet_magic_slot"
const STARTER_BUFFET_ID: String = "buffet"
const COPY_ORDER_KEY: String = "deck_copy_addition_order"
const MAGIC_REWARD_SLOTS_KEY: String = "magic_slot_reward_indices"
const LEGACY_DECK_CARD_ORDER_KEY: String = "deck_cards"
const MAGIC_PREFIX: String = "magic:"
const ITEM_PREFIX: String = "item:"

static func element(state: Dictionary) -> String:
	var counts: Dictionary = {}
	var largest: int = 0
	var order: Array = state.get(ADDITION_ORDER_KEY, state.get(LEGACY_DECK_CARD_ORDER_KEY, []))
	var starter: int = _starter_buffet_slot(state)
	if starter >= 0:
		var keys: Array = state.get(COPY_ORDER_KEY, []) if state.has(ADDITION_ORDER_KEY) else _copies(state).keys()
		var order_index: int = keys.find(_slot_key(MAGIC_PREFIX, starter))
		if order_index < 0: order_index = order.find(STARTER_BUFFET_ID)
		if order_index >= 0 and order_index < order.size() and order[order_index] == STARTER_BUFFET_ID:
			order = order.duplicate()
			order.remove_at(order_index)
	for card_id: String in order:
		var card_element: String = Data.card_element(card_id)
		if not ElementData.is_elemental(card_element): continue
		var count: int = int(counts.get(card_element, 0)) + 1
		counts[card_element] = count
		largest = maxi(largest, count)
	if largest == 0: return ""
	for index: int in range(order.size() - 1, -1, -1):
		var card_element: String = Data.card_element(order[index])
		if int(counts.get(card_element, 0)) == largest: return card_element
	return ""

static func restore_starter_buffet_slot(state: Dictionary) -> void:
	var magic: Array = state.get("attuned_magic_cards", [])
	var rewards: Array = state.get("reward_cards", [])
	if not state.has(STARTER_BUFFET_SLOT_KEY):
		state[STARTER_BUFFET_SLOT_KEY] = magic.find(STARTER_BUFFET_ID) if magic.count(STARTER_BUFFET_ID) > rewards.count(STARTER_BUFFET_ID) else -1
	if not magic.has(STARTER_BUFFET_ID): return
	var indices: Array = _magic_reward_indices(state)
	var starter_slot: int = _starter_buffet_slot(state)
	for slot: int in range(magic.size()):
		if magic[slot] != STARTER_BUFFET_ID or slot == starter_slot or int(indices[slot]) >= 0: continue
		indices[slot] = rewards.size()
		rewards.append(STARTER_BUFFET_ID)
		state[MAGIC_REWARD_SLOTS_KEY] = indices

static func add_magic(state: Dictionary, card_id: String) -> void:
	var history: Dictionary = _history(state, _copies(state))
	var rewards: Array = state["reward_cards"]
	var indices: Array = _magic_reward_indices(state)
	var magic: Array = state["attuned_magic_cards"]
	indices.append(rewards.size())
	rewards.append(card_id)
	magic.append(card_id)
	state[MAGIC_REWARD_SLOTS_KEY] = indices
	_store(state, _copies(state), history)

static func change_magic_slot(state: Dictionary, slot: int, replacement: String = "") -> void:
	var magic: Array = state["attuned_magic_cards"]
	if slot < 0 or slot >= magic.size(): return
	var history: Dictionary = _history(state, _copies(state))
	var indices: Array = _magic_reward_indices(state)
	var starter_slot: int = _starter_buffet_slot(state)
	if slot == starter_slot:
		state[STARTER_BUFFET_SLOT_KEY] = -1
	elif replacement.is_empty() and slot < starter_slot:
		state[STARTER_BUFFET_SLOT_KEY] = starter_slot - 1
	var slots: Array = range(magic.size())
	if replacement.is_empty():
		magic.remove_at(slot)
		# Purging removes the deck copy. Its receipt still records a past award.
		indices.remove_at(slot)
		slots.remove_at(slot)
	else:
		magic[slot] = replacement
		slots[slot] = -1
		var rewards: Array = state.get("reward_cards", [])
		var reward_index: int = indices[slot]
		if reward_index < 0:
			indices[slot] = rewards.size()
			rewards.append(replacement)
		else:
			rewards[reward_index] = replacement
		state["reward_cards"] = rewards
	state[MAGIC_REWARD_SLOTS_KEY] = indices
	_store(state, _copies(state), _remap_slots(history, MAGIC_PREFIX, slots))

static func _magic_reward_indices(state: Dictionary) -> Array:
	var magic: Array = state.get("attuned_magic_cards", [])
	var rewards: Array = state.get("reward_cards", [])
	var starter: int = _starter_buffet_slot(state)
	var saved: Array = state.get(MAGIC_REWARD_SLOTS_KEY, [])
	var used: Dictionary = {}
	if state.has(MAGIC_REWARD_SLOTS_KEY) and saved.size() == magic.size():
		var valid: bool = true
		for slot: int in range(saved.size()):
			var index: int = int(saved[slot])
			if index == -1: continue
			if index < 0 or index >= rewards.size() or rewards[index] != magic[slot] or used.has(index) or slot == starter:
				valid = false
				break
			used[index] = true
		if valid: return saved.duplicate()
	# With no copy receipts, match from the newest end of each old list.
	used.clear()
	var indices: Array = []
	indices.resize(magic.size())
	indices.fill(-1)
	for slot: int in range(magic.size() - 1, -1, -1):
		if slot == starter: continue
		for index: int in range(rewards.size() - 1, -1, -1):
			if rewards[index] != magic[slot] or used.has(index): continue
			indices[slot] = index
			used[index] = true
			break
	return indices

static func _starter_buffet_slot(state: Dictionary) -> int:
	var magic: Array = state.get("attuned_magic_cards", [])
	var slot: int = int(state.get(STARTER_BUFFET_SLOT_KEY, -1))
	return slot if slot >= 0 and slot < magic.size() and magic[slot] == STARTER_BUFFET_ID else -1

static func rebuild(state: Dictionary, previous: Dictionary = {}) -> void:
	var copies: Dictionary = _copies(state)
	var history: Dictionary = _history(state, copies) if previous.is_empty() else _history(previous, _copies(previous))
	_store(state, copies, history)
	if state.has(MAGIC_REWARD_SLOTS_KEY):
		state[MAGIC_REWARD_SLOTS_KEY] = _magic_reward_indices(state)

static func set_items(state: Dictionary, equipped: Array, edited_slot: int = -1, retained_slots: Array = []) -> void:
	var previous: Array = state.get("equipped_items", [])
	var history: Dictionary = _history(state, _copies(state))
	if edited_slot >= 0:
		retained_slots = range(previous.size())
		if equipped.size() < previous.size():
			retained_slots.remove_at(edited_slot)
		elif equipped.size() == previous.size():
			retained_slots[edited_slot] = -1
	elif retained_slots.is_empty():
		retained_slots = _legacy_combat_item_slots(previous, equipped)
	state["equipped_items"] = equipped
	_store(state, _copies(state), _remap_slots(history, ITEM_PREFIX, retained_slots))

static func _legacy_combat_item_slots(previous: Array, equipped: Array) -> Array:
	# Pre-receipt combat snapshots consumed the first slot for an ID and appended pickups.
	for count: int in range(mini(previous.size(), equipped.size()), 0, -1):
		var prefix: Array = equipped.slice(0, count)
		var remaining: Array = prefix.duplicate()
		var slots: Array = []
		var surviving: Array = []
		for slot: int in range(previous.size() - 1, -1, -1):
			var id: String = previous[slot]
			if not remaining.has(id): continue
			remaining.erase(id)
			slots.push_front(slot)
			surviving.push_front(id)
		if surviving == prefix: return slots
	return []

static func _remap_slots(history: Dictionary, prefix: String, slots: Array) -> Dictionary:
	var remapped: Dictionary = {}
	for key: String in history:
		if not key.begins_with(prefix):
			remapped[key] = history[key]
			continue
		var new_slot: int = slots.find(int(key.trim_prefix(prefix)))
		if new_slot >= 0: remapped[_slot_key(prefix, new_slot)] = history[key]
	return remapped

static func _slot_key(prefix: String, slot: int) -> String:
	return prefix + str(slot)

static func _copies(state: Dictionary) -> Dictionary:
	var copies: Dictionary = {}
	var equipped: Dictionary = state.get("equipped_equipment", {})
	var gear_counts: Dictionary = {}
	for slot: String in Data.equipment_slots():
		var gear: String = str(equipped.get(slot, ""))
		if gear.is_empty(): continue
		var copy: int = int(gear_counts.get(gear, 0))
		gear_counts[gear] = copy + 1
		var origin: String = gear if copy == 0 else "%s:%d" % [gear, copy]
		var cards: Array = Data.equipment_cards(gear, state)
		for index: int in range(cards.size()):
			copies["gear:%s:%d" % [origin, index]] = cards[index]
	var magic: Array = state.get("attuned_magic_cards", [])
	for slot: int in range(magic.size()):
		if not str(magic[slot]).is_empty(): copies[_slot_key(MAGIC_PREFIX, slot)] = magic[slot]
	var items: Array = state.get("equipped_items", [])
	for slot: int in range(items.size()):
		if Data.card_is_item(items[slot]): copies[_slot_key(ITEM_PREFIX, slot)] = items[slot]
	return copies

static func _history(state: Dictionary, copies: Dictionary) -> Dictionary:
	var order: Array = state.get(ADDITION_ORDER_KEY, state.get(LEGACY_DECK_CARD_ORDER_KEY, []))
	var keys: Array = state.get(COPY_ORDER_KEY, [])
	var history: Dictionary = {}
	if state.has(ADDITION_ORDER_KEY) and not keys.is_empty() and keys.size() == order.size():
		for index: int in range(order.size()):
			history[keys[index]] = order[index]
		return history
	# Older saves identify copies only by card ID. The equipped-item slot
	# history disambiguates duplicates when it is a permutation of the loadout.
	var items: Array = state.get("equipped_items", [])
	var natural_slots: Array = range(items.size())
	var saved_slots: Variant = state.get(ITEM_SLOT_ORDER_KEY)
	var item_slots: Array = natural_slots
	if saved_slots is Array and saved_slots.size() == natural_slots.size() and natural_slots.all(func(slot: int) -> bool: return saved_slots.has(slot)):
		item_slots = saved_slots
	if item_slots == natural_slots and copies.values() == order: return copies
	keys = copies.keys().filter(func(key: String) -> bool: return not key.begins_with(ITEM_PREFIX))
	for slot: int in item_slots: keys.append(_slot_key(ITEM_PREFIX, slot))
	var matched: Array = []
	matched.resize(order.size())
	var unused: Dictionary = copies.duplicate()
	for index: int in range(order.size() - 1, -1, -1):
		for cursor: int in range(keys.size() - 1, -1, -1):
			var key: String = keys[cursor]
			if unused.get(key) != order[index]: continue
			matched[index] = key
			unused.erase(key)
			break
	for index: int in range(matched.size()):
		if matched[index] != null: history[matched[index]] = order[index]
	return history

static func _store(state: Dictionary, copies: Dictionary, history: Dictionary) -> void:
	var ordered: Dictionary = {}
	for key: String in history:
		if copies.get(key) == history[key]: ordered[key] = copies[key]
	for key: String in copies:
		if not ordered.has(key): ordered[key] = copies[key]
	state["deck_cards"] = copies.values()
	if ordered.keys() == copies.keys():
		state.erase(ADDITION_ORDER_KEY)
		state.erase(COPY_ORDER_KEY)
	else:
		state[ADDITION_ORDER_KEY] = ordered.values()
		state[COPY_ORDER_KEY] = ordered.keys()
	var slots: Array = []
	for key: String in ordered:
		if key.begins_with(ITEM_PREFIX): slots.append(int(key.trim_prefix(ITEM_PREFIX)))
	if slots == range((state.get("equipped_items", []) as Array).size()): state.erase(ITEM_SLOT_ORDER_KEY)
	else: state[ITEM_SLOT_ORDER_KEY] = slots
