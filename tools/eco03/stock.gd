extends "res://tests/helpers/counted_program.gd"

const Run = preload("res://scripts/run_engine.gd")
const Game = preload("res://scripts/game_data.gd")
const Depth = preload("res://scripts/depth_rules.gd")
const STOCK_SEEDS: int = 500
const SHOP: String = "scavenger"

var engine := Run.new()
var changed: Dictionary = {"magic": 0, "gear": 0}
var protected_reservations: int = 0

func _initialize() -> void:
	for seed_value: int in range(1, STOCK_SEEDS + 1):
		for depth: int in range(1, 16):
			witness(seed_value, depth)
	print("ECO03 STOCK COVERAGE seeds=%d depths=1-15 stocks=%d changed_gear=%d changed_magic=%d protected_reservations=%d" %
		[STOCK_SEEDS, STOCK_SEEDS * 15, changed["gear"], changed["magic"], protected_reservations])
	_finish("ECO03 STOCK")

func witness(seed_value: int, depth: int) -> void:
	var coord := Vector2i(depth, seed_value % depth)
	var key: String = "%d,%d" % [coord.x, coord.y]
	var room: Dictionary = {"type": SHOP, "merchant_kind": SHOP, "coord": coord, "depth": depth}
	var state: Dictionary = {"seed": seed_value, Depth.STATE_KEY: depth, "current_room": coord, "mode": "room",
		"equipped_equipment": Game.starting_equipped_equipment(), "attuned_magic_cards": Game.starting_magic_cards(),
		"rooms": {key: room}}
	var offers: Array = engine.merchant_offer_ids(state, SHOP)
	_expect(offers.size() == Run.MERCHANT_OFFER_COUNT, "Three full shelves at %s / %d" % [key, seed_value])
	for category: String in ["magic", "gear", "item"]:
		var label: String = "%s seed=%d depth=%d" % [category, seed_value, depth]
		var available: Array = engine._available_merchant_offer_ids(state, category, [])
		var original: Array = engine._weighted_merchant_choices(seed_value, coord, available, Run.MERCHANT_OFFERS_PER_CATEGORY,
			engine._merchant_offer_salt(category), category)
		var shown: Array = offers.filter(func(id: String) -> bool: return engine.merchant_item_kind(id) == category)
		_expect(shown.size() == 3, label + " retains three slots")
		if category == "item" or engine._merchant_row_has_common(category, original):
			_expect(shown == original, label + " retains the original row")
		else:
			changed[category] += 1
			var differences: int = 0
			for index: int in range(original.size()): differences += int(original[index] != shown[index])
			_expect(differences == 1, label + " replaces exactly one offer")
		if category == "item": continue
		_expect(engine._merchant_row_has_common(category, shown), label + " has a common")
		var rare: Array = available.filter(func(id: String) -> bool: return engine._merchant_offer_rarity(category, id) != "common")
		var common: Array = shown.filter(func(id: String) -> bool: return engine._merchant_offer_rarity(category, id) == "common")
		if not common.is_empty() and rare.size() >= 3:
			witness_reservation(state, key, offers, category, common[0], rare, label)

func witness_reservation(state: Dictionary, key: String, offers: Array, category: String, common_id: String, rare: Array, label: String) -> void:
	var prepared: Dictionary = state.duplicate(true)
	var last_rare: String = rare[1]
	var stored: Array = offers.filter(func(id: String) -> bool: return engine.merchant_item_kind(id) != category)
	stored.append_array([rare[0], last_rare, common_id])
	var reserved: String = rare[2]
	prepared["rooms"][key]["merchant_stock"] = stored
	prepared[Run.SKILL_STATE_KEY] = {"reserved_merchant": {"kind": SHOP, "item_id": reserved, "origin_coord": Vector2i.ZERO}}
	var injected: Dictionary = engine._inject_reserved_merchant_offer(prepared, state["current_room"], SHOP)
	var result: Array = engine.merchant_offer_ids(injected, SHOP)
	_expect(result.has(reserved) and result.has(common_id) and result.has(rare[0]) and not result.has(last_rare),
		label + " reserved offer replaces a different offer when the last slot is the only common")
	_expect(result.size() == offers.size() and injected[Run.SKILL_STATE_KEY]["reserved_merchant"].is_empty(), label + " consumes the reservation exactly once")
	protected_reservations += 1
