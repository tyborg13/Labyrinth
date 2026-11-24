extends "res://tests/helpers/counted_program.gd"

const Run = preload("res://scripts/run_engine.gd")
const Game = preload("res://scripts/game_data.gd")
const Graph = preload("res://scripts/section_map_graph.gd")
const Store = preload("res://scripts/progression_store.gd")
const Depth = preload("res://scripts/depth_rules.gd")
const Route = preload("res://tools/eco03/route.gd")
const SEEDS: int = 1000
const FIXTURE_SEED: int = 83
const MERCHANT: String = "scavenger"
const RECEIPTS: String = "res://.godot/eco03"
const CATEGORIES: Array[String] = Array(["gear", "magic", "item"], TYPE_STRING, "", null)

var engine := Run.new()

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var baseline: bool = args.has("--baseline")
	var phase: String = "before" if baseline else "after"
	var first_seed: int = int(option(args, "--seed", "1"))
	var sample_size: int = int(option(args, "--runs", str(SEEDS)))
	var release: String = RECEIPTS.path_join("release.save")
	if baseline and not FileAccess.file_exists(release):
		assert(Graph.LAYOUT_REVISION == 7, "Record the release fixture on the release source")
		Store.set_run_storage_path(release)
		_expect(Store.save_run_state(engine.create_new_run(FIXTURE_SEED, Store.default_data())), "Record a production release save")
	if not baseline: check_release_save()
	var name: String = option(args, "--label", phase if first_seed == 1 else "%s-%d" % [phase, first_seed])
	var receipt := FileAccess.open(RECEIPTS.path_join(name + ".jsonl"), FileAccess.WRITE)
	assert(receipt != null)
	receipt.store_line(JSON.stringify({"prices": prices()}))
	var early_seeds: int = 0
	var early_sections: int = 0
	var fallback_sections: int = 0
	for seed_value: int in range(first_seed, first_seed + sample_size):
		var state: Dictionary = engine.create_new_run(seed_value, Store.default_data(), false)
		var diagnostics: Dictionary = {"enabled": true}
		if baseline: state["section_map_layout_revision"] = 7
		Graph.initialize(state, diagnostics)
		var shops: Array[int]
		var early: int = 0
		var fallbacks: int = 0
		var row: Dictionary = {"seed": seed_value}
		for index: int in range(state["map_sections"].size()):
			var routes: Dictionary = Route.section_routes(state, index)
			shops.append(int(routes["count"]))
			early += int(routes["early"] > 0)
			fallbacks += int(diagnostics["sections"][index].get("fallback", 0) > 0)
			if index != 0: continue
			var first: Dictionary = routes["first"]
			_expect(not first.is_empty(), "Section I has a reachable Scavenger, seed %d" % seed_value)
			if first.is_empty(): continue
			var arrival: Dictionary = Route.enter_path(engine, state, first["path"])
			var original: Array = rolled_stock(arrival)
			row.merge({"fights": first["fights"], "embers": engine.held_embers(arrival),
				"path": first["path"].map(func(coord: Vector2i) -> String: return Graph.key(coord)),
				"kinds": first["path"].map(func(coord: Vector2i) -> String: return Route.kind(Graph.room(state, coord))),
				"stock": stock_prices(arrival, original) if baseline else stock_prices(arrival), "rolled_stock": stock_prices(arrival, original)})
		early_seeds += int(early > 0)
		early_sections += early
		fallback_sections += fallbacks
		row.merge({"shops": shops, "early_sections": early, "fallback_sections": fallbacks})
		receipt.store_line(JSON.stringify(row))
		if seed_value % 100 == 0: print("ECO03 MAP %s seeds=%d early_seeds=%d fallback_sections=%d" % [phase, seed_value, early_seeds, fallback_sections])
	receipt.close()
	print("ECO03 MAP RESULT phase=%s seeds=%d early_seeds=%d early_sections=%d fallback_sections=%d" % [phase, sample_size, early_seeds, early_sections, fallback_sections])
	_finish("ECO03 " + phase.to_upper())

func option(args: PackedStringArray, flag: String, fallback: String) -> String:
	var index: int = args.find(flag)
	return args[index + 1] if index >= 0 else fallback

func check_release_save() -> void:
	Store.set_run_storage_path(RECEIPTS.path_join("release.save"))
	var file := FileAccess.open(Store._run_storage_path, FileAccess.READ)
	var raw: Dictionary = file.get_var(false)
	file.close()
	var loaded: Dictionary = engine.repair_loaded_run_state(Store.load_saved_run())
	_expect(raw["section_map_layout_revision"] == 7 and loaded["section_map_layout_revision"] == 7, "Release save remains revision 7")
	_expect(loaded["rooms"] == raw["rooms"] and loaded["map_sections"] == raw["map_sections"], "Release save reloads every stored room and section unchanged")
	var regenerated: Dictionary = {"seed": FIXTURE_SEED, "current_room": Vector2i.ZERO, "mode": "room", "section_map_layout_revision": 7}
	Graph.initialize(regenerated)
	_expect(regenerated["map_sections"] == raw["map_sections"], "Explicit revision 7 still regenerates the release topology")
	for key: String in regenerated["rooms"]:
		var original: Dictionary = raw["rooms"][key]
		var node: Dictionary = regenerated["rooms"][key]
		for field: String in ["type", "mystery_type", "connections", "depth", "element"]:
			_expect(node.get(field) == original.get(field), "Revision 7 regenerates release %s at %s" % [field, key])
	print("ECO03 RELEASE SAVE seed=%d rooms=%d sections=%d" % [FIXTURE_SEED, raw["rooms"].size(), raw["map_sections"].size()])

func rarity(category: String, id: String) -> String:
	return Game.equipment_rarity(id) if category == "gear" else Game.card_rarity(id)

func prices() -> Dictionary:
	var rows: Dictionary = {}
	var ids: Array = Game.equipment_ids() + Game.cards().keys()
	for id: String in ids:
		var category: String = engine.merchant_item_kind(id)
		if category.is_empty(): continue
		var key: String = "%s/%s" % [category, rarity(category, id)]
		var row: Dictionary = {"buy": [], "debt_buy": [], "sell": engine.merchant_sell_value(MERCHANT, id)}
		for depth: int in range(Depth.MAX_DEPTH + 1):
			row["buy"].append(engine.merchant_buy_cost(MERCHANT, id, {Depth.STATE_KEY: depth}))
			row["debt_buy"].append(engine.merchant_buy_cost(MERCHANT, id, {Depth.STATE_KEY: depth, "boon_debt": {"room": Vector2i.ZERO}}))
		_expect(not rows.has(key) or rows[key] == row, "A category and rarity have one price")
		rows[key] = row
	var purges: Array[Dictionary]
	for count: int in range(3):
		purges.append({"base": engine.scavenger_purge_price({"priced_magic_purges": count}),
			"debt": engine.scavenger_purge_price({"priced_magic_purges": count, "boon_debt": {"room": Vector2i.ZERO}})})
	return {"rows": rows, "purge": purges}

func rolled_stock(state: Dictionary) -> Array:
	var stock: Array = []
	for category: String in ["magic", "gear", "item"]:
		stock.append_array(engine._weighted_merchant_choices(state["seed"], state["current_room"],
			engine._available_merchant_offer_ids(state, category, []), Run.MERCHANT_OFFERS_PER_CATEGORY,
			engine._merchant_offer_salt(category), category))
	return stock

func stock_prices(state: Dictionary, offers: Array = []) -> Array:
	var rows: Array = []
	if offers.is_empty(): offers = engine.merchant_offer_ids(state, MERCHANT)
	for id: String in offers:
		var category: String = engine.merchant_item_kind(id)
		rows.append({"id": id, "category": category, "rarity": rarity(category, id),
			"buy": engine.merchant_buy_cost(MERCHANT, id, state)})
	return rows
