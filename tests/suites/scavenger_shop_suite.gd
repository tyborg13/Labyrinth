extends RefCounted

const GameData = preload("res://scripts/game_data.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const SCAN_DEPTH: int = 8
const PURCHASE_BUDGET: int = 1000

static func run(expect: Callable) -> void:
	_test_generation_and_stock_shape(expect)
	_test_each_category_buys_and_refills_in_place(expect)
	_test_coherent_cross_category_sales(expect)
	_test_legacy_merchant_save_migration(expect)

static func _test_generation_and_stock_shape(expect: Callable) -> void:
	var engine := RunEngine.new()
	var fixture: Dictionary = _scavenger_fixture(engine)
	expect.call(not fixture.is_empty(), "Generated runs should include a Scavenger room")
	if fixture.is_empty():
		return
	var state: Dictionary = fixture.get("state", {}) as Dictionary
	var coord: Vector2i = fixture.get("coord", Vector2i(999, 999))
	for seed: int in range(1, 21):
		var generated: Dictionary = engine.create_new_run(seed, ProgressionStore.default_data())
		for x: int in range(-SCAN_DEPTH, SCAN_DEPTH + 1):
			for y: int in range(-SCAN_DEPTH, SCAN_DEPTH + 1):
				var room_type: String = str(engine.room_metadata(generated, Vector2i(x, y)).get("type", ""))
				expect.call(room_type not in [RunEngine.LEGACY_MERCHANT_BLACKSMITH, RunEngine.LEGACY_MERCHANT_ARCANIST], "New maps must never generate retired merchant room types")
	state["current_room"] = coord
	state["mode"] = "room"
	expect.call(engine.merchant_kind_for_current_room(state) == RunEngine.MERCHANT_SCAVENGER, "The unified merchant room should identify as Scavenger")
	var offers: Array = engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER)
	expect.call(offers.size() == RunEngine.MERCHANT_OFFER_COUNT, "A Scavenger should present three full shelves")
	var category_counts: Dictionary = {
		RunEngine.MERCHANT_ITEM_KIND_MAGIC: 0,
		RunEngine.MERCHANT_ITEM_KIND_GEAR: 0,
		RunEngine.MERCHANT_ITEM_KIND_ITEM: 0,
	}
	for item_id_var: Variant in offers:
		var kind: String = engine.merchant_item_kind(str(item_id_var))
		category_counts[kind] = int(category_counts.get(kind, 0)) + 1
	for kind: String in category_counts:
		expect.call(int(category_counts[kind]) == RunEngine.MERCHANT_OFFERS_PER_CATEGORY, "Each Scavenger shelf should contain exactly three %s offers" % kind)

static func _test_each_category_buys_and_refills_in_place(expect: Callable) -> void:
	var engine := RunEngine.new()
	var fixture: Dictionary = _scavenger_fixture(engine)
	if fixture.is_empty():
		return
	var source: Dictionary = fixture.get("state", {}) as Dictionary
	source["current_room"] = fixture.get("coord", Vector2i.ZERO)
	source["mode"] = "room"
	source = engine.set_held_embers(source, PURCHASE_BUDGET)
	var original_offers: Array = engine.merchant_offer_ids(source, RunEngine.MERCHANT_SCAVENGER)
	for category: String in [RunEngine.MERCHANT_ITEM_KIND_MAGIC, RunEngine.MERCHANT_ITEM_KIND_GEAR, RunEngine.MERCHANT_ITEM_KIND_ITEM]:
		var item_id: String = _first_offer_of_kind(engine, original_offers, category)
		expect.call(not item_id.is_empty(), "The %s shelf should contain a purchasable offer" % category)
		if item_id.is_empty():
			continue
		var bought: Dictionary = engine.buy_merchant_item(source, RunEngine.MERCHANT_SCAVENGER, item_id)
		var cost: int = engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, item_id)
		expect.call(engine.held_embers(bought) == PURCHASE_BUDGET - cost, "Buying %s should spend its displayed ember price" % category)
		match category:
			RunEngine.MERCHANT_ITEM_KIND_MAGIC:
				expect.call((bought.get("magic_inventory", []) as Array).has(item_id), "Bought Magic should enter reserve Magic")
			RunEngine.MERCHANT_ITEM_KIND_GEAR:
				expect.call((bought.get("equipment_inventory", []) as Array).has(item_id), "Bought Gear should enter equipment inventory")
			RunEngine.MERCHANT_ITEM_KIND_ITEM:
				expect.call((bought.get("item_inventory", []) as Array).has(item_id), "Bought Items should enter item inventory")
		var refilled: Array = engine.merchant_offer_ids(bought, RunEngine.MERCHANT_SCAVENGER)
		expect.call(refilled.size() == RunEngine.MERCHANT_OFFER_COUNT and not refilled.has(item_id), "A purchase should replace only the bought ware and keep all shelves full")
		for index: int in range(original_offers.size()):
			if str(original_offers[index]) == item_id:
				expect.call(engine.merchant_item_kind(str(refilled[index])) == category, "A purchased slot should refill from its original shelf category")
			else:
				expect.call(str(refilled[index]) == str(original_offers[index]), "Unpurchased Scavenger offers should remain stable")
		var blocked_resale: Dictionary = engine.sell_merchant_item(bought, RunEngine.MERCHANT_SCAVENGER, item_id)
		expect.call(engine.held_embers(blocked_resale) == engine.held_embers(bought), "Newly bought %s should not be immediately resold" % category)

static func _test_coherent_cross_category_sales(expect: Callable) -> void:
	var engine := RunEngine.new()
	var fixture: Dictionary = _scavenger_fixture(engine)
	if fixture.is_empty():
		return
	var state: Dictionary = fixture.get("state", {}) as Dictionary
	state["current_room"] = fixture.get("coord", Vector2i.ZERO)
	state["mode"] = "room"
	state = engine.set_held_embers(state, 100)
	state["equipment_inventory"] = ["ward_kite"]
	state["collected_equipment"] = ["ward_kite"]
	state["magic_inventory"] = ["spark_dart"]
	state["reward_cards"] = ["spark_dart"]
	state["item_inventory"] = ["crimson_draught"]
	var expected_sale_total: int = 100
	for item_id: String in ["ward_kite", "spark_dart", "crimson_draught"]:
		expect.call(engine.merchant_sellable_ids(state, RunEngine.MERCHANT_SCAVENGER).has(item_id), "Sell From Pack should list owned %s" % engine.merchant_item_kind(item_id))
		expected_sale_total += engine.merchant_sell_value(RunEngine.MERCHANT_SCAVENGER, item_id)
		state = engine.sell_merchant_item(state, RunEngine.MERCHANT_SCAVENGER, item_id)
	expect.call(engine.held_embers(state) == expected_sale_total, "Selling Magic, Gear, and Items should pay each explicit value")
	expect.call(not (state.get("equipment_inventory", []) as Array).has("ward_kite"), "Sold Gear should leave equipment inventory")
	expect.call(not (state.get("magic_inventory", []) as Array).has("spark_dart"), "Sold Magic should leave reserve Magic")
	expect.call(not (state.get("item_inventory", []) as Array).has("crimson_draught"), "Sold Items should leave item inventory")
	var offers_after_sale: Array = engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER)
	expect.call(not offers_after_sale.has("ward_kite") and not offers_after_sale.has("spark_dart") and not offers_after_sale.has("crimson_draught"), "Sold wares should not immediately reappear on the Scavenger shelves")

static func _test_legacy_merchant_save_migration(expect: Callable) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(4401, ProgressionStore.default_data())
	var legacy_coord := Vector2i(2, 1)
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["2,1"] = {
		"coord": legacy_coord,
		"depth": 2,
		"type": RunEngine.LEGACY_MERCHANT_BLACKSMITH,
		"merchant_kind": RunEngine.LEGACY_MERCHANT_BLACKSMITH,
		"npcs": [{"id": RunEngine.LEGACY_MERCHANT_BLACKSMITH, "pos": Vector2i(3, 4)}],
		"merchant_stock": ["iron_cleaver", "spark_dart", "crimson_draught"],
	}
	state["rooms"] = rooms
	state["current_room"] = legacy_coord
	state["mode"] = "room"
	state["skill_state"] = {
		"reserved_merchant": {
			"kind": RunEngine.LEGACY_MERCHANT_ARCANIST,
			"item_id": "rime_shard",
			"origin_coord": Vector2i(1, 1),
		}
	}
	var repaired: Dictionary = engine.repair_loaded_run_state(state)
	var repaired_room: Dictionary = engine.room_metadata(repaired, legacy_coord)
	expect.call(str(repaired_room.get("type", "")) == RunEngine.MERCHANT_SCAVENGER, "Legacy Blacksmith rooms should migrate to Scavenger")
	expect.call(str(repaired_room.get("merchant_kind", "")) == RunEngine.MERCHANT_SCAVENGER, "Legacy merchant metadata should migrate to Scavenger")
	var npcs: Array = repaired_room.get("npcs", []) as Array
	expect.call(npcs.size() == 1 and str((npcs[0] as Dictionary).get("id", "")) == RunEngine.MERCHANT_SCAVENGER, "Legacy merchant NPCs should migrate to the single Scavenger")
	var reservation: Dictionary = ((repaired.get("skill_state", {}) as Dictionary).get("reserved_merchant", {}) as Dictionary)
	expect.call(str(reservation.get("kind", "")) == RunEngine.MERCHANT_SCAVENGER, "Legacy Layaway reservations should migrate to the unified Scavenger")

static func _scavenger_fixture(engine) -> Dictionary:
	for seed: int in range(1, 90):
		var state: Dictionary = engine.create_new_run(seed, ProgressionStore.default_data())
		for x: int in range(-SCAN_DEPTH, SCAN_DEPTH + 1):
			for y: int in range(-SCAN_DEPTH, SCAN_DEPTH + 1):
				var coord := Vector2i(x, y)
				if str(engine.room_metadata(state, coord).get("type", "")) == RunEngine.MERCHANT_SCAVENGER:
					return {"state": state, "coord": coord}
	return {}

static func _first_offer_of_kind(engine, offers: Array, category: String) -> String:
	for item_id_var: Variant in offers:
		var item_id: String = str(item_id_var)
		if engine.merchant_item_kind(item_id) == category:
			return item_id
	return ""
