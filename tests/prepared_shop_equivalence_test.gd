extends SceneTree
const CardWidget = preload("res://scripts/card_widget.gd")
const Shop = preload("res://scripts/scavenger_shop_view.gd")
const Reference = preload("res://tests/fixtures/scavenger_inventory_reference.gd")
const EngineScript = preload("res://scripts/run_engine.gd")
const Flow = preload("res://tests/ui_flow_performance_workload.gd")
const Parallel = preload("res://scripts/parallel_runtime.gd")
var errors: Array[String]
var active: bool = true
var cancel_next_frame: bool = false
var remove_next_frame: Node
var presented: int = 0
var cases: int = 0
func _initialize() -> void:
	Parallel.apply_from_environment()
	_run.call_deferred()
func _run() -> void:
	var engine := EngineScript.new()
	var state: Dictionary = Flow.new()._scavenger_state(engine)
	var original: Dictionary = state.duplicate(true)
	var shop := Shop.new()
	var reference := Reference.new()
	shop.visible = false
	reference.visible = false
	root.add_child(shop)
	root.add_child(reference)
	for held: int in [0, 100, 10000]:
		state["held_embers"] = held
		reference.configure(state, engine, false)
		await Shop.prepare_hidden_for(shop, state, engine, false, _present, _alive)
		shop.configure(state, engine, false)
		_check(_snapshot(shop) == _snapshot(reference), "Prepared stock must match original order, art, prices, affordability, selection and pack for %d embers" % held)
		var identities: Dictionary = shop._offer_sources.duplicate()
		var before: int = presented
		await Shop.prepare_hidden_for(shop, state, engine, false, _present, _alive)
		_check(shop._offer_sources == identities and presented == before, "Warm preparation must retain offer identities without adding frames")
		cases += 1
	# Force a different affordability signature, interrupt a partial real build,
	# then require the ordinary configure path to recover the complete original.
	state["held_embers"] = 0
	for kind: String in [Shop.MAGIC, Shop.GEAR, Shop.ITEM]: shop._clear_shelf(kind)
	cancel_next_frame = true
	await Shop.prepare_hidden_for(shop, state, engine, false, _present, _alive)
	active = true
	cancel_next_frame = false
	shop.configure(state, engine, false)
	reference.configure(state, engine, false)
	_check(_snapshot(shop) == _snapshot(reference), "Cancelled partial stock must recover through synchronous arrival with no stale signature")
	# A visible shop must preserve its live state throughout preparation.
	shop.visible = true
	var visible_snapshot: Dictionary = _snapshot(shop)
	var future: Dictionary = state.duplicate(true)
	future["held_embers"] = 10000
	await Shop.prepare_hidden_for(shop, future, engine, false, _present, _alive)
	_check(_snapshot(shop) == visible_snapshot, "Preparation must not alter a visible shop")
	shop.visible = false
	for kind: String in [Shop.MAGIC, Shop.GEAR, Shop.ITEM]: shop._clear_shelf(kind)
	remove_next_frame = shop
	await Shop.prepare_hidden_for(shop, future, engine, false, _present, _alive)
	_check(not is_instance_valid(shop), "Real preparation suspension must tolerate the hidden shop being freed")
	reference.free()
	await process_frame
	_check(state.get("rooms") == original.get("rooms"), "Preparation must not mutate caller merchant stock")
	_check(int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)) == 0, "Preparation and cancellation must leave no orphan nodes")
	print("PREPARED SHOP EQUIVALENCE RESULT: " + JSON.stringify({"errors": errors, "cases": cases, "presented_frames": presented}))
	quit(0 if errors.is_empty() else 1)
func _snapshot(shop: Control) -> Dictionary:
	var offers: Dictionary = {}
	for key: String in shop._offer_sources:
		var offer: Control = shop._offer_sources[key]
		var prices: Array[int]
		for child: Node in offer.find_children("ScavengerPriceTag", "", true, false): prices.append(int(child.get("amount")))
		var cards: Array[String]
		for child: Node in offer.find_children("*", "Button", true, false):
			if child is CardWidget: cards.append(str(child.get("card_id")))
		offers[key] = {"tooltip": offer.tooltip_text, "affordable": offer.get_meta("shop_affordable", false), "retired": offer.get_meta("shop_offer_retired", false), "prices": prices, "cards": cards}
	return {"semantics": shop.semantic_snapshot(), "offers": offers, "shelves": shop._shelf_signatures.duplicate(), "pack": shop._sell_page_signature}
func _alive() -> bool: return active
func _present() -> void:
	presented += 1
	if cancel_next_frame:
		cancel_next_frame = false
		active = false
	if is_instance_valid(remove_next_frame):
		remove_next_frame.free()
		remove_next_frame = null
	await process_frame
func _check(ok: bool, message: String) -> void:
	if not ok: errors.append(message)
