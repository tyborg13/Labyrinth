extends SceneTree

const Shop = preload("res://scripts/scavenger_shop_view.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Fixture = preload("res://tests/ui_flow_performance_workload.gd")
var _errors: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	root.size = Vector2i(1920, 1080)
	var engine := RunEngine.new()
	var fixture := Fixture.new()
	fixture.set("_probe", self)
	var state: Dictionary = fixture.call("_scavenger_state", engine)
	var shop := Shop.new()
	root.add_child(shop)
	await process_frame
	await process_frame
	shop.configure(state, engine, false)
	shop.present()
	await process_frame
	await process_frame
	var original: Dictionary = (shop.get("_offer_sources") as Dictionary).duplicate()
	var gear: Control = original["buy:duelist_rapier"] as Control
	gear.grab_focus()
	await process_frame
	var detail: Array[Node] = shop.find_children("DetailCard_*", "Control", true, false)
	_expect(not detail.is_empty(), "Focusing gear must build its granted-card detail")
	var detail_id: int = detail[0].get_instance_id() if not detail.is_empty() else 0
	shop.configure(state.duplicate(true), engine, false)
	await process_frame
	for key: String in original:
		_expect((shop.get("_offer_sources") as Dictionary).get(key) == original[key], "Unchanged shelves and pack must retain live controls")
	_expect(root.gui_get_focus_owner() == gear, "An unchanged refresh must preserve controller focus")
	detail = shop.find_children("DetailCard_*", "Control", true, false)
	_expect(not detail.is_empty() and detail[0].get_instance_id() == detail_id, "Focus and click of the same ware must retain its detail card")
	var cost: int = engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, "duelist_rapier")
	var poor: Dictionary = state.duplicate(true)
	poor["held_embers"] = cost - 1
	shop.configure(poor, engine, false)
	var unaffordable: Control = (shop.get("_offer_sources") as Dictionary)["buy:duelist_rapier"]
	_expect(not bool(unaffordable.get_meta("shop_affordable", true)), "Affordability changes must update offer treatment")
	_expect((shop.find_child("ScavengerTradeActionButton", true, false) as Button).disabled, "Unaffordable selection must disable buying")
	poor["held_embers"] = cost - 2
	shop.configure(poor, engine, false)
	_expect((shop.get("_offer_sources") as Dictionary)["buy:duelist_rapier"] == unaffordable, "Changed deficit can retain an already unaffordable card")
	_expect("need 2 more" in unaffordable.tooltip_text, "Retained offer tooltip must report the new exact deficit")
	shop.configure(state, engine, false)
	gear = (shop.get("_offer_sources") as Dictionary)["buy:duelist_rapier"]
	gear.grab_focus()
	await create_timer(0.16).timeout
	_expect(gear.scale.x > 1.03, "Normal-motion focused offer must use authored emphasis")
	shop.configure(state, engine, true)
	_expect((shop.get("_offer_sources") as Dictionary)["buy:duelist_rapier"] == gear, "Motion preference change must retain unchanged stock")
	_expect(gear.scale.is_equal_approx(Vector2.ONE), "Enabling reduced motion must retire existing emphasis immediately")
	_expect((shop.get("_slot_tweens") as Dictionary).is_empty(), "Reduced motion must stop retained offer tweens")
	await create_timer(0.16).timeout
	_expect(gear.scale.is_equal_approx(Vector2.ONE), "A retired emphasis tween must not resume after preference change")
	shop.call("_turn_sell_page", 1)
	var page: int = int(shop.get("_sell_page"))
	var page_sources: Dictionary = (shop.get("_offer_sources") as Dictionary).duplicate()
	shop.configure(state, engine, true)
	_expect(int(shop.get("_sell_page")) == page and page > 0, "Unchanged pack refresh must retain page selection")
	for key: String in page_sources:
		_expect((shop.get("_offer_sources") as Dictionary).get(key) == page_sources[key], "Current sell page must retain its controls")
	var before_sources: Dictionary = (shop.get("_offer_sources") as Dictionary).duplicate()
	var bought: Dictionary = engine.buy_merchant_item(state, RunEngine.MERCHANT_SCAVENGER, "duelist_rapier")
	shop.configure(bought, engine, true)
	_expect((shop.call("semantic_snapshot") as Dictionary).get("categories") == {"magic": 3, "gear": 3, "item": 3}, "Purchase must retain all authored shelf counts")
	for key: String in before_sources:
		if key.begins_with("buy:") and engine.merchant_item_kind(key.trim_prefix("buy:")) != RunEngine.MERCHANT_ITEM_KIND_GEAR:
			_expect((shop.get("_offer_sources") as Dictionary).get(key) == before_sources[key], "A gear replacement must retain the other two shelves")
	_expect((shop.get("_slot_tweens") as Dictionary).size() <= (shop.get("_offer_sources") as Dictionary).size(), "Offer replacement must not accumulate retired tween entries")
	shop.queue_free()
	await process_frame
	print("SHOP RETAINED CONTENT TEST RESULT: %s" % ("PASS" if _errors.is_empty() else "FAIL: " + str(_errors)))
	quit(0 if _errors.is_empty() else 1)

func _expect(condition: bool, message: String) -> void:
	if not condition: _errors.append(message)
