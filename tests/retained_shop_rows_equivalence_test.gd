extends "res://tests/retained_character_inventory_equivalence_test.gd"
const ShopScript = preload("res://scripts/scavenger_shop_view.gd")
const ShopReference = preload("res://tests/fixtures/scavenger_inventory_reference.gd")
const FlowScript = preload("res://tests/ui_flow_performance_workload.gd")
const ShopCard = preload("res://scripts/card_widget.gd")
const PriceScript = preload("res://scripts/scavenger_price_tag.gd")
var shops: Array[Control]
var reused: int = 0

func _run() -> void:
	var engine := Run.new()
	var state: Dictionary = FlowScript.new()._scavenger_state(engine)
	for original: bool in [false, true]:
		var shop: Control = ShopReference.new() if original else ShopScript.new()
		root.add_child(shop)
		shops.append(shop)
	for held: int in [0, 5, 20, 100, 10000, 15, 0]:
		state["held_embers"] = held
		await _configure_compare(state, engine, "currency " + str(held))
	state["held_embers"] = 10000
	await _configure_compare(state, engine, "rich stock")
	for key: String in ["buy:grave_mortar", "buy:boiled_leather", "buy:duelist_rapier", "buy:nail_bomb"]:
		await _select_compare(key, "inspect " + key)
	var selected: String = "duelist_rapier"
	await _select_compare("buy:" + selected, "select buy")
	var before: Dictionary = shops[0]._offer_sources.duplicate()
	state = engine.buy_merchant_item(state, Run.MERCHANT_SCAVENGER, selected)
	await _configure_compare(state, engine, "buy removes one shelf offer")
	for key: String in before:
		if shops[0]._offer_sources.has(key):
			_check(before[key] == shops[0]._offer_sources[key], "Unchanged buy/pack offer must retain its owner and identity: " + key)
			reused += 1
	for shop: Control in shops: shop._set_pack_mode(true)
	await _compare_shops("pack mode")
	for category: String in ["magic", "gear", "item", "all"]:
		for shop: Control in shops: shop._set_pack_filter(category)
		await _compare_shops("filter " + category)
	for delta: int in [1, 1, -1, -1, 1]:
		for shop: Control in shops: shop._turn_sell_page(delta)
		await _compare_shops("page " + str(delta))
	for shop: Control in shops: shop._sell_page = 0
	await _configure_compare(state, engine, "pack first page")
	var sell_key: String = ""
	for key: String in shops[0]._offer_sources:
		if key.begins_with("sell:"):
			sell_key = key
			break
	await _select_compare(sell_key, "select sale")
	before = shops[0]._offer_sources.duplicate()
	state = engine.sell_merchant_item(state, Run.MERCHANT_SCAVENGER, sell_key.trim_prefix("sell:"))
	await _configure_compare(state, engine, "sell removes one pack offer")
	for key: String in before:
		if shops[0]._offer_sources.has(key):
			_check(before[key] == shops[0]._offer_sources[key], "Unchanged sale offer must retain its identity: " + key)
			reused += 1
	# Exercise real bound actions after rows have moved, including source ownership.
	for key: String in shops[0]._offer_sources:
		await _select_compare(key, "bound retained callback " + key)
	# An externally freed tile must not be read through a typed stale binding.
	var recover_id: String = str(shops[0]._sellable_ids[0])
	var old: Control = shops[0]._offer_sources["sell:" + recover_id]
	old.free()
	shops[0]._sell_page_signature = ""
	await _configure_compare(state, engine, "externally freed pack tile")
	# Repeated changes remain bounded to visible page and actual shelf stock.
	for cycle: int in range(8):
		state["held_embers"] = 0 if cycle % 2 == 0 else 10000
		await _configure_compare(state, engine, "repeat " + str(cycle))
	state["equipment_inventory"] = ["iron_cleaver", "iron_cleaver", "ward_kite", "ward_kite"]
	state["magic_inventory"] = ["frostbolt", "frostbolt", "spark_dart", "spark_dart"]
	state["item_inventory"] = ["nail_bomb", "nail_bomb", "smoke_bomb", "smoke_bomb"]
	for shop: Control in shops: shop._set_pack_filter("all")
	await _configure_compare(state, engine, "duplicate inventory copies")
	for delta: int in [1, -1, 1, -1]:
		for shop: Control in shops: shop._turn_sell_page(delta)
		await _compare_shops("duplicate overlapping page " + str(delta))
	for category: String in ["magic", "gear", "item", "all"]:
		for shop: Control in shops: shop._set_pack_filter(category)
		await _compare_shops("duplicate filter " + category)
	# Every same-ID copy has a distinct actual source bound to its own callback.
	for index: int in shops[0]._sell_row.get_child_count():
		for shop: Control in shops:
			var source: Button = shop._sell_row.get_child(index) as Button
			source.pressed.emit()
			_check(shop._selected_source == source, "Each duplicate callback must bind its own actual tile")
		await _compare_shops("duplicate source callback " + str(index))
	state = engine.sell_merchant_item(state, Run.MERCHANT_SCAVENGER, "iron_cleaver")
	await _configure_compare(state, engine, "sell one duplicate copy")
	for shop: Control in shops:
		var removed: Control = shop._offer_sources["sell:frostbolt"]
		removed.free()
		shop._set_pack_filter("gear")
	await _compare_shops("externally free then filter out")
	for shop: Control in shops: shop._set_pack_filter("all")
	await _compare_shops("restore after external free")
	for shop: Control in shops:
		var removed: Control = shop._offer_sources["sell:iron_cleaver"]
		removed.free()
		shop._turn_sell_page(1)
	await _compare_shops("externally free then page out")
	for shop: Control in shops: shop._turn_sell_page(-1)
	await _compare_shops("restore page after external free")
	var empty: Dictionary = state.duplicate(true)
	empty["equipment_inventory"] = []
	empty["magic_inventory"] = []
	empty["item_inventory"] = []
	for shop: Control in shops: shop._set_pack_filter("magic")
	await _configure_compare(empty, engine, "empty filtered pack")
	for shop: Control in shops: shop.free()
	await _settle(8)
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Shop retention teardown must leave no orphan nodes")
	print("SHOP ROW RETENTION RESULT: " + JSON.stringify({"cases": cases, "errors": errors, "differences": differences, "reused": reused, "orphan_nodes": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT))}))
	quit(0 if errors.is_empty() else 1)

func _configure_compare(state: Dictionary, engine: RefCounted, label: String) -> void:
	var original: Dictionary = state.duplicate(true)
	for shop: Control in shops:
		shop.configure(state, engine, false)
		shop._entry_played_for_room = true
	await _compare_shops(label)
	_check(state == original, "Shop refresh must not mutate authoritative caller state: " + label)

func _select_compare(key: String, label: String) -> void:
	for shop: Control in shops:
		var source: Control = shop._offer_sources.get(key) as Control
		_check(source != null and shop.is_ancestor_of(source), "Retained callback must own its actual source: " + label)
		if source != null: source.pressed.emit()
	await _compare_shops(label)

func _compare_shops(label: String) -> void:
	await _settle(8)
	var actual: Dictionary = _snapshot(shops[0], shops[0])
	var expected: Dictionary = _snapshot(shops[1], shops[1])
	if actual != expected: _print_differences(actual, expected, label)
	_check(actual == expected, "Shop layout, art, fonts, callbacks and prices must match original: " + label)
	_check(shops[0].semantic_snapshot() == shops[1].semantic_snapshot(), "Shop semantic state must match original: " + label)
	_check(shops[0]._sell_row.get_child_count() <= ShopScript.SELL_PAGE_SIZE, "Pack rows must stay bounded by visible page")
	_check(shops[0]._offer_sources.size() == shops[1]._offer_sources.size(), "Retained offers must stay bounded by original live inventory")
	cases += 1

func _snapshot(node: Node, origin: Control) -> Dictionary:
	var result: Dictionary = super._snapshot(node, origin)
	if node is Label: result["font"] = _font_snapshot(node.get_theme_font("font"))
	if node is CanvasItem: result["self_modulate"] = node.self_modulate
	if node is ShopCard: result["card_id"] = node.card_id
	if node.get_script() == PriceScript:
		for property: String in ["amount", "selling", "affordable"]: result[property] = node.get(property)
	if node.get_script() == preload("res://scripts/scavenger_ware.gd"):
		for property: String in ["chosen", "pack", "reduced_motion"]: result[property] = node.get(property)
	return result

func _font_snapshot(font: Font) -> Dictionary:
	if font is FontVariation:
		return {"class": font.get_class(), "base": _font_snapshot(font.base_font), "spacing_top": font.spacing_top, "spacing_bottom": font.spacing_bottom, "spacing_space": font.spacing_space, "spacing_glyph": font.spacing_glyph, "variation_opentype": font.variation_opentype, "variation_embolden": font.variation_embolden, "variation_transform": font.variation_transform}
	return {"class": font.get_class(), "source": font.resource_path, "identity": font.get_instance_id()}
