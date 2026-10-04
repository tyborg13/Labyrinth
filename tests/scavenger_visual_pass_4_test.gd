extends "res://tests/scavenger_shop_probe.gd"
## Unit 3 acceptance: scene typography, chip, tags, shelf containment, native
## modes/filters/inspection/trades, paging and reduced motion. Visual risk:
## inspect the companion 1920x1080 glowup/shop probes in the real renderer.

const ShopView = preload("res://scripts/scavenger_shop_view.gd")
const PriceTag = preload("res://scripts/scavenger_price_tag.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Typography = preload("res://scripts/ui_typography.gd")
const GlowupProof = preload("res://tests/scavenger_glowup_probe.gd")
const AcquisitionProof = preload("res://tests/merchant_acquisition_probe.gd")

var _state: Dictionary
var _engine := RunEngine.new()
var _motion_reduced: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://scavenger_visual_pass_4"))
	ProgressionStore.set_storage_path("user://scavenger_visual_pass_4/progression.json")
	ProgressionStore.set_run_storage_path("user://scavenger_visual_pass_4/run.save")
	ProbeSettings.set_storage_path("user://scavenger_visual_pass_4/settings.json")
	var settings: Dictionary = ProbeSettings.default_settings()
	settings["ui_scale"] = 1.0
	ProbeSettings.save_settings(settings)
	_probe_viewport = SubViewport.new()
	_probe_viewport.size = VIEWPORT_SIZE
	root.add_child(_probe_viewport)
	var shop := ShopView.new()
	_probe_viewport.add_child(shop)
	await process_frame
	shop.buy_requested.connect(_buy.bind(shop))
	shop.sell_requested.connect(_sell.bind(shop))
	var engine: RunEngine = _engine
	_load(shop, _scavenger_state(engine))
	await _settle()
	_expect(shop != null and shop.visible, "Shop presents the current merchant state")
	if shop == null:
		quit(1)
		return
	var title: Label = shop.find_child("ScavengerWaresTitle", true, false) as Label
	_expect(title.text == "Wares & Oddments" and title.get_theme_font_size("font_size") == 50, "Scene title uses the new string and 50px display type")
	_expect(title.get_theme_font("font") == Typography.display_font() and title.get_theme_color("font_color") == Palette.GOLD_BRIGHT, "Scene title retains display font and gold token")
	_expect(not shop.get("_title_panel") is PanelContainer, "Scene title has no material plaque")
	var currency: Control = shop.get("_currency_panel") as Control
	_expect(currency is StatChip and (shop.get("_currency_label") as Label).text == "720", "Shared chip shows the held ember total")
	_expect((shop.get("_dialogue_panel") as Control).size == Vector2(520, 170), "Leather dialogue fits the authored compact tray")
	var body: Label = shop.get("_dialogue_words") as Label
	_expect(body.text == "“Cards, steel, little miracles in bottles. Spend your embers, or show me what you've brought to sell.”", "Welcome preserves its exact words in quotes")
	_expect(body.get_theme_font_size("font_size") == 23 and body.get_theme_color("font_color") == Palette.TEXT, "Welcome uses 23px body type")
	for category: String in ["Magic", "Gear", "Items"]:
		var brush: TextureRect = shop.find_child(category + "Plaque", true, false) as TextureRect
		_expect(brush != null and brush.self_modulate == Color(0.47, 0.34, 0.20, 0.95), "Category sits on its brighter bronze brush: " + category)
		_expect(brush.size == Vector2(176, 46) and is_equal_approx(brush.position.x + brush.size.x * 0.5, 636.0 - ShopView.SHELF_LEFT), "Category brush is enlarged and centered on the shelf post: " + category)
	_assert_shelf_alignment(shop, _state, engine)
	for id: String in ["grave_mortar", "boiled_leather", "crimson_draught"]:
		var source: Control = _offer_source(shop, id, false)
		_assert_unified_offer(source, id, engine, id == "grave_mortar")
		_assert_tag(source, engine.merchant_buy_cost("scavenger", id), false, true)
	var magic: Control = _offer_source(shop, "grave_mortar", false)
	var card: Control = magic.find_child("MagicCardVisualRoot_grave_mortar", true, false) as Control
	_expect(card.size == ShopView.OFFER_CARD_SIZE and card.size.x / 154.0 > 1.14, "Shelf card is fifteen percent larger with its canonical composition")
	_expect(magic.get_global_rect().encloses(card.get_global_rect()), "Larger shelf card remains inside its offer")
	_assert_labels(shop)
	var browse: Button = shop.get("_mode_buy") as Button
	var sell: Button = shop.get("_mode_sell") as Button
	_expect(browse.get_parent() == sell.get_parent() and is_equal_approx(browse.get_global_rect().end.x, sell.get_global_rect().position.x), "Mode actions form adjacent segments")
	_expect(browse.size.x >= 220.0 and is_equal_approx(browse.size.x, sell.size.x), "Mode segments widen equally")
	_assert_mode_caps(browse)
	_assert_mode_caps(sell)
	_expect((shop.get("_leave_button") as Control).position.x == 1660.0, "Leave uses the far-right quiet plate")
	await _click(sell)
	_expect(bool(shop.get("_pack_mode")) and sell.button_pressed and not browse.button_pressed, "Pointer changes the joined mode selection")
	_assert_mode_caps(browse)
	_assert_mode_caps(sell)
	for category: String in ["all", "magic", "gear", "item"]:
		await _click(shop.find_child("PackFilter_" + category, true, false) as Control)
		_expect(str(shop.get("_pack_filter")) == category, "Native pack filter changes: " + category)
		for id: Variant in shop.get("_sellable_ids") as Array:
			_expect(category == "all" or engine.merchant_item_kind(str(id)) == category, "Filter keeps matching wares")
		_assert_labels(shop)
	var sale: Control = _offer_source(shop, "crimson_draught", true)
	_assert_tag(sale, engine.merchant_sell_value("scavenger", "crimson_draught"), true, true)
	await _click(sale)
	var before: int = int((_state as Dictionary)["held_embers"])
	await _click(shop.get("_detail_action") as Control)
	var paid: int = before + engine.merchant_sell_value("scavenger", "crimson_draught")
	_expect(int((_state as Dictionary)["held_embers"]) == paid, "Native sale pays the precise amount")
	_expect((shop.get("_currency_label") as Label).text == str(paid), "Chip synchronizes before the receipt expires")
	_assert_labels(shop)
	await _click(browse)
	magic = _offer_source(shop, "grave_mortar", false)
	magic.grab_focus()
	await _settle()
	_assert_detail_card(shop, "grave_mortar", "Keyboard inspection")
	await _key(KEY_ENTER)
	_expect(str(shop.get("_selected_item_id")) == "grave_mortar", "Keyboard activation preserves the inspected ware")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	await _press_controller_button(JOY_BUTTON_A)
	_expect(_probe_viewport.gui_get_focus_owner() == shop.get("_detail_action"), "Controller Accept enters the selected ware's trade action")
	await _press_controller_button(JOY_BUTTON_A)
	await _settle()
	_expect(((_state as Dictionary)["magic_inventory"] as Array).has("grave_mortar"), "Controller trade buys the inspected card")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	_assert_labels(shop)
	var state: Dictionary = _scavenger_state(engine)
	state["held_embers"] = 0
	state["unbanked_embers"] = 0
	state["equipment_inventory"] = []
	state["magic_inventory"] = []
	state["item_inventory"] = []
	_load(shop, state)
	await _settle()
	_assert_tag(_offer_source(shop, "grave_mortar", false), engine.merchant_buy_cost("scavenger", "grave_mortar"), false, false)
	for id: String in ["boiled_leather", "crimson_draught"]:
		var source: Control = _offer_source(shop, id, false)
		_assert_tag(source, engine.merchant_buy_cost("scavenger", id), false, false)
		var name_label: Label = source.find_child("WareName", true, false) as Label
		var name_tint: Color = _inherited_modulate(name_label)
		_expect(name_tint.a >= 0.7 and minf(name_tint.r, minf(name_tint.g, name_tint.b)) >= 0.7, "Unaffordable name stays readable independently of dim ware art")
		_expect((source.find_child("WareArt", true, false) as Control).modulate != Color.WHITE, "Unaffordable art keeps its dim state")
	await _click(_offer_source(shop, "grave_mortar", false))
	_assert_tag(_offer_source(shop, "grave_mortar", false), engine.merchant_buy_cost("scavenger", "grave_mortar"), false, false)
	_expect((shop.get("_detail_action") as Button).disabled, "Unaffordable inspection retains a disabled Buy action")
	_expect(_offer_source(shop, "grave_mortar", false).tooltip_text.contains("need 175 more"), "Unaffordable tooltip preserves the exact shortage")
	await _click(sell)
	await _click(shop.find_child("PackFilter_all", true, false) as Control)
	_expect((shop.get("_sellable_ids") as Array).is_empty(), "Empty pack has no false sell candidates")
	_assert_labels(shop)
	_motion_reduced = true
	state = _scavenger_state(engine)
	state["equipment_inventory"] = GameData.equipment_ids().slice(0, 22)
	_load(shop, state)
	await _settle()
	await _click(sell)
	await _click(shop.find_child("PackFilter_gear", true, false) as Control)
	await _click(shop.get("_sell_next") as Control)
	_expect(int(shop.get("_sell_page")) == 1, "Pack pager advances through native input")
	_assert_labels(shop)
	await _click(browse)
	var reduced: Control = _offer_source(shop, "icicle_lance", false)
	reduced.grab_focus()
	await _settle()
	_expect(reduced.scale == Vector2.ONE and bool(shop.get("_reduced_motion")), "Reduced motion keeps inspection without offer lift")
	shop.queue_free()
	await process_frame
	print("SCAVENGER VISUAL PASS 4: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _assert_tag(source: Control, amount: int, selling: bool, affordable: bool) -> void:
	var tag: Control = source.find_child("ScavengerPriceTag", true, false) as Control
	_expect(tag is PriceTag and tag.size == Vector2(118, 60), "Ware uses the approved 118x60 hanging tag")
	var value: Label = tag.find_child("PriceTagValue", true, false) as Label
	_expect(value.text == (("+%d" if selling else "%d") % amount), "Price uses the exact signed number")
	_expect(value.get_theme_color("font_color") == (Color("2f5a24") if selling else Color("3a2616") if affordable else Color("8e1f17")), "Price color follows sale and affordability")
	var artwork: TextureRect = tag.get_node("HangingPriceTagArt") as TextureRect
	_expect(artwork.offset_top == 4.0 and artwork.offset_bottom == 4.0 and (tag.get_node("PriceTagInk") as Control).position.y == 26.0, "Tag twine, parchment and ink shift down four pixels together")
	if not affordable:
		_expect(is_equal_approx(artwork.self_modulate.a * _inherited_modulate(artwork).a, 0.8), "Unaffordable parchment stays at eighty percent opacity")
		_expect(_inherited_modulate(value).is_equal_approx(Color.WHITE), "Unaffordable price ink stays at full opacity and brightness")
	_expect(source.get_global_rect().encloses(tag.get_global_rect()), "Complete hanging tag remains inside the unified offer")
	_expect(source.get_global_rect().encloses(value.get_global_rect()), "Tag ink remains inside the unified offer")
	_expect(tag.get("affordable") == affordable and tag.get("selling") == selling, "Tag state agrees with the live transaction")

func _assert_mode_caps(button: Button) -> void:
	var label: Label = button.get("_label") as Label
	_expect(label.position.x >= 48.0 and label.position.x + label.size.x <= button.size.x - 48.0, "Mode caption clears both painted end caps")
	_expect(label.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, label.get_theme_font_size("font_size")).x <= label.size.x, "Complete mode caption fits between painted end caps")

func _inherited_modulate(node: CanvasItem) -> Color:
	var result := Color.WHITE
	var current: Node = node
	while current is CanvasItem:
		result *= (current as CanvasItem).modulate
		current = current.get_parent()
	return result

func _assert_labels(node: Node) -> void:
	if node is CardWidget or (node is Control and not (node as Control).is_visible_in_tree()):
		return
	if node is Label:
		var label: Label = node as Label
		_expect(label.get_visible_line_count() >= label.get_line_count(), "All text lines fit: " + label.text)
		var parent: Control = label.get_parent() as Control
		_expect(parent == null or parent.get_global_rect().grow(5).encloses(label.get_global_rect()), "Label stays inside its parent: " + label.text)
	for child: Node in node.get_children():
		_assert_labels(child)

func _click(control: Control) -> void:
	var point: Vector2 = control.get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	_probe_viewport.push_input(motion, true)
	await process_frame
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_probe_viewport.push_input(event, true)
		await process_frame
	await _settle()

func _key(keycode: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.pressed = pressed
		_probe_viewport.push_input(event, true)
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _load(shop: Control, state: Dictionary) -> void:
	_state = state
	shop.configure(_state, _engine, _motion_reduced)
	shop.present()

func _buy(item_id: String, source: Control, shop: Control) -> void:
	var origin: Rect2 = shop.purchase_origin(item_id, source)
	_load(shop, _engine.buy_merchant_item(_state, "scavenger", item_id))
	shop.present_purchase(item_id, origin)

func _sell(item_id: String, source: Control, shop: Control) -> void:
	var origin: Rect2 = shop.purchase_origin(item_id, source)
	_load(shop, _engine.sell_merchant_item(_state, "scavenger", item_id))
	shop.present_sale(item_id, origin)
