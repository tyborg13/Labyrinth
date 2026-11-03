extends RefCounted

const Library = preload("res://scripts/grimoire_library.gd")

# Only inputs read by entry_ids_for_run_state / entry_ids_for_combat_state and
# unlock_entries. Store an owned copy so in-place mutations invalidate too.
var dirty: bool = true
var _key: int = 0
var _source: Dictionary = {}
var synchronizations: int = 0

func sync(scene: Node) -> void:
	if scene._run_state.is_empty(): return
	var source: Dictionary = inputs(scene._run_state, scene._combat_state)
	var key: int = hash(source)
	dirty = dirty or key != _key or source != _source
	if not dirty: return
	var candidates: Array[String] = Library.entry_ids_for_run_state(scene._run_state)
	scene._append_unique_grimoire_ids(candidates, Library.entry_ids_for_combat_state(scene._combat_state))
	var receipts_changed: bool = _source.is_empty()
	for field: String in [Library.UNLOCKED_KEY, Library.UNREAD_KEY, "progression_receipts", "progression_active", "has_notice"]:
		receipts_changed = receipts_changed or source.get(field) != _source.get(field)
	var unlocked: Array = scene._run_state.get(Library.UNLOCKED_KEY, [])
	var has_new: bool = false
	for candidate: String in candidates:
		if not unlocked.has(candidate): has_new = true; break
	if receipts_changed or has_new: scene._unlock_grimoire_entries(candidates)
	# Unlocking changes receipts itself; acknowledge that same transaction.
	_source = inputs(scene._run_state, scene._combat_state).duplicate(true)
	_key = hash(_source)
	dirty = false
	synchronizations += 1

static func inputs(run: Dictionary, combat: Dictionary) -> Dictionary:
	var source: Dictionary = {"has_notice": run.has(Library.NOTICE_KEY)}
	for field: String in ["deck_cards", "reward_cards", "attuned_magic_cards", "magic_inventory", "item_inventory", "equipped_items", "collected_equipment", "equipment_inventory", "equipped_equipment", Library.UNLOCKED_KEY, Library.UNREAD_KEY]:
		source[field] = run.get(field)
	var progression: Dictionary = run.get("progression", {})
	source["progression_active"] = not progression.is_empty()
	source["progression_receipts"] = [progression.get(Library.UNLOCKED_KEY), progression.get(Library.UNREAD_KEY)]
	var room: Dictionary = Library._current_room_metadata(run)
	source["room"] = [room.get("npcs"), room.get(Library.MERCHANT_STOCK_KEY)]
	source["reward"] = (run.get("pending_reward", {}) as Dictionary).get("cards")
	source["run_combat"] = _combat_inputs(run.get("combat_state", {}))
	source["combat"] = _combat_inputs(combat)
	return source

static func _combat_inputs(combat: Dictionary) -> Dictionary:
	var enemy_types: Array[String]
	for enemy_var: Variant in combat.get("enemies", []):
		if typeof(enemy_var) != TYPE_DICTIONARY: continue
		var enemy: Dictionary = enemy_var
		var type: String = str(enemy.get("type", ""))
		if not enemy_types.has(type): enemy_types.append(type)
	var equipment: Array = []
	for loot_var: Variant in combat.get("loot", []):
		if typeof(loot_var) != TYPE_DICTIONARY: continue
		var loot: Dictionary = loot_var
		if str(loot.get("kind", "")) == "equipment" and bool(loot.get("claimed", false)) and str(loot.get("resolution", "")) != "missed": equipment.append(loot.get("equipment_id", ""))
	var deck: Dictionary = combat.get("deck", {})
	var cards: Array = []
	for pile: String in ["hand", "draw", "discard", "burned", "consumed"]:
		var values: Variant = deck.get(pile, [])
		if typeof(values) == TYPE_ARRAY: cards.append_array(values)
	return {"surfaces": combat.get("surfaces"), "umbra": (combat.get("umbra", {}) as Dictionary).get("stage"),
		"traps": not (combat.get("traps", []) as Array).is_empty(), "enemies": enemy_types, "equipment": equipment,
		"collected": combat.get("collected_equipment"), "cards": _sorted_ids(cards)}

static func _sorted_ids(values: Array) -> Array[String]:
	var ids: Array[String]
	for value: Variant in values:
		var id: String = str(value)
		if not ids.has(id): ids.append(id)
	ids.sort()
	return ids
