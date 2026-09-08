extends SceneTree

const RunEngine = preload("res://scripts/run_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GameData = preload("res://scripts/game_data.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
var _errors: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	var engine := RunEngine.new()
	var results: Dictionary = {}
	for seed: int in [0, 1, 7319, 84217, 2147483647]:
		for coord: Vector2i in [Vector2i(2, 1), Vector2i(-3, 2)]:
			for fixture: Dictionary in _cases(engine, seed, coord):
				var original: Dictionary = fixture["state"].duplicate(true)
				var state: Dictionary = original.duplicate(true)
				if fixture["legacy"]:
					state = engine.repair_loaded_run_state(original)
					_expect(original == fixture["state"], "Legacy repair must not mutate source")
				var before: Dictionary = state.duplicate(true)
				var kind: String = engine.merchant_kind_for_current_room(state)
				var offers: Array = engine.merchant_offer_ids(state, kind)
				_expect(state == before and original == fixture["state"], "Stock reads must leave caller data unchanged")
				_expect(offers == engine.merchant_offer_ids(state, kind), "Stock repair must be deterministic")
				results["%d/%s/%s" % [seed, str(coord), fixture["name"]]] = {"offers": offers, "kind": kind, "reservation": state["skill_state"].get("reserved_merchant", {}), "room": engine.room_metadata(state, coord), "source_hash": hash(original)}
	print("MERCHANT STOCK EQUIVALENCE RESULT: %s" % JSON.stringify({"case_count": results.size(), "cases": results, "semantic_errors": _errors}))
	quit(0 if _errors.is_empty() else 1)

func _cases(engine: RefCounted, seed: int, coord: Vector2i) -> Array[Dictionary]:
	var base: Dictionary = engine.create_new_run(seed, ProgressionStore.default_data())
	base["current_room"] = coord
	base["mode"] = "room"
	base["combat_state"] = {}
	var key: String = "%d,%d" % [coord.x, coord.y]
	var room: Dictionary = engine.room_metadata(base, coord)
	room.merge({"type": "scavenger", "merchant_kind": "scavenger", "revealed": true, "visited": true, "sealed": false, "merchant_sold_items": [], "merchant_purchased_items": [], "merchant_refill_count": 7}, true)
	room.erase("merchant_stock")
	base["rooms"][key] = room
	var magic: Array = engine.call("_available_merchant_offer_ids", base, "magic", [])
	var gear: Array = engine.call("_available_merchant_offer_ids", base, "gear", [])
	var items: Array = engine.call("_available_merchant_offer_ids", base, "item", [])
	_expect(magic.size() >= 4 and gear.size() >= 4 and items.size() >= 4, "Stock fixture needs four legal offers in every category")
	var full: Array = [gear[0], items[0], magic[0], gear[1], magic[1], items[1], items[2], gear[2], magic[2]]
	var equipped: Dictionary = base["equipped_equipment"].duplicate(true)
	equipped[GameData.equipment_slot(gear[1])] = gear[1]
	var specs: Array = [
		{"name": "missing", "missing": true}, {"name": "empty", "stock": []},
		{"name": "wrong_container", "stock": "broken"},
		{"name": "partial", "stock": [gear[0], magic[0], items[0]]},
		{"name": "full_interleaved", "stock": full},
		{"name": "overfull_reversed", "stock": [magic[3], gear[3], items[3], magic[2], gear[2], items[2], magic[1], gear[1], items[1], magic[0], gear[0], items[0]]},
		{"name": "duplicates", "stock": [magic[0], magic[0], gear[0], gear[0], items[0], items[0]]},
		{"name": "invalid", "stock": ["", "not_a_content_id", 47, null, magic[0], gear[0], items[0]]},
		{"name": "owned_gear_magic", "stock": full, "run": {"equipment_inventory": [gear[0]], "equipped_equipment": equipped, "magic_inventory": [magic[0]], "reward_cards": [magic[1]], "attuned_magic_cards": [magic[2]]}},
		{"name": "owned_consumables", "stock": full, "run": {"item_inventory": [items[0], items[0]], "equipped_items": [items[1]]}},
		{"name": "sold", "stock": full, "room": {"merchant_sold_items": [magic[0], gear[0], items[0], magic[0]]}},
		{"name": "purchased", "stock": full, "run": {"item_inventory": [items[0], items[0], items[0]]}, "room": {"merchant_purchased_items": [items[0], items[0]]}},
		{"name": "exhausted", "stock": full, "run": {"equipment_inventory": gear, "magic_inventory": magic}, "room": {"merchant_sold_items": items}}
	]
	for category: String in ["magic", "gear", "item"]:
		var pools: Dictionary = {"magic": magic, "gear": gear, "item": items}
		for same_origin: bool in [true, false]:
			specs.append({"name": "reserved_%s_%s" % [category, str(same_origin)], "stock": [], "reservation": {"kind": "scavenger", "item_id": pools[category][0], "origin_coord": coord if same_origin else coord + Vector2i(1, 0)}})
	specs.append({"name": "legacy_blacksmith", "stock": [gear[1], magic[0], items[0]], "legacy": "blacksmith", "reservation": {"kind": "blacksmith", "item_id": gear[0]}})
	specs.append({"name": "legacy_arcanist", "stock": [magic[1], gear[0], items[0]], "legacy": "arcanist", "reservation": {"kind": "arcanist", "item_id": magic[0], "origin_coord": coord}})
	specs.append({"name": "reserved_id_still_in_stock", "stock": full, "reservation": {"kind": "scavenger", "item_id": magic[0], "origin_coord": coord}})
	var cases: Array[Dictionary]
	for spec: Dictionary in specs:
		var state: Dictionary = base.duplicate(true)
		state.merge(spec.get("run", {}).duplicate(true), true)
		var changed_room: Dictionary = state["rooms"][key]
		changed_room.merge(spec.get("room", {}).duplicate(true), true)
		if spec.get("missing", false): changed_room.erase("merchant_stock")
		else: changed_room["merchant_stock"] = spec.get("stock", []).duplicate(true) if spec.get("stock") is Array else spec.get("stock", [])
		if spec.has("reservation"): state["skill_state"]["reserved_merchant"] = spec["reservation"].duplicate(true)
		var legacy: String = spec.get("legacy", "")
		if not legacy.is_empty():
			changed_room["type"] = legacy
			changed_room["merchant_kind"] = legacy
			for field: String in ["type", "merchant_kind", "room_type"]: state["current_room_layout"][field] = legacy
		cases.append({"name": spec["name"], "state": state, "legacy": not legacy.is_empty()})
	return cases

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
