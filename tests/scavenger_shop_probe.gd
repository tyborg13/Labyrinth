extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const GameData = preload("res://scripts/game_data.gd")

const OUTPUT_DIR := "user://scavenger_shop_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const SHELF_CENTER_X: Array[float] = [815.0, 1075.0, 1335.0]

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_output()
	ProgressionStore.set_storage_path("user://labyrinth_progression_scavenger_shop_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_scavenger_shop_probe.save")
	ProgressionStore.clear_saved_run()
	await _capture_states()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	quit(1 if _failed else 0)

func _capture_states() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for the Scavenger shop probe")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	var run_engine := RunEngine.new()
	var state: Dictionary = _scavenger_state(run_engine)
	instance.call("_load_run_state", state)
	await _settle()
	instance.call("_close_dialogue")
	await _settle()
	var shop: Control = instance.find_child("ScavengerShopView", true, false) as Control
	if shop == null or not shop.visible:
		_fail("Scavenger shop should be the live merchant surface")
		return
	var snapshot: Dictionary = shop.call("semantic_snapshot")
	if str(snapshot.get("title", "")) != "Scavenger's Wares":
		_fail("Shop title should be Scavenger's Wares")
	var categories: Dictionary = snapshot.get("categories", {}) as Dictionary
	for category: String in ["magic", "gear", "item"]:
		if int(categories.get(category, 0)) != RunEngine.MERCHANT_OFFERS_PER_CATEGORY:
			_fail("%s shelf should contain exactly three offers" % category.capitalize())
	if shop.find_child("SellInventoryScroll", true, false) != null:
		_fail("Sell From Pack must use the authored pager instead of a horizontal scrollbar")
	if shop.find_child("ScavengerLayawayButton", true, false) != null or shop.has_signal("reserve_requested"):
		_fail("Hold For Next Visit should be absent from the Scavenger interface and signal flow")
	var currency_panel: Control = shop.find_child("ScavengerCurrencyPanel", true, false) as Control
	var currency_label: Label = shop.find_child("ScavengerEmberCount", true, false) as Label
	if currency_panel == null or currency_label == null or currency_label.text != "EMBERS  720":
		_fail("The header should show the held-ember total as text only")
	elif not currency_panel.find_children("*", "TextureRect", true, false).is_empty():
		_fail("The held-ember header should not use an unrelated resource icon")
	var sell_next: Button = shop.find_child("SellNextPage", true, false) as Button
	if sell_next == null or sell_next.disabled:
		_fail("A full probe pack should expose an enabled next-page affordance")
	_assert_shelf_alignment(shop, state, run_engine)
	await _save("normal.png")

	var offers: Array = run_engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER)
	var controller_offer_id: String = ""
	var second_magic_id: String = ""
	var purchase_offer_id: String = ""
	var purchase_offer_card_count: int = -1
	var item_offer_id: String = ""
	for offer_var: Variant in offers:
		var offer_id: String = str(offer_var)
		var offer_kind: String = run_engine.merchant_item_kind(offer_id)
		if offer_kind == RunEngine.MERCHANT_ITEM_KIND_MAGIC:
			if controller_offer_id.is_empty():
				controller_offer_id = offer_id
			elif second_magic_id.is_empty():
				second_magic_id = offer_id
		elif offer_kind == RunEngine.MERCHANT_ITEM_KIND_GEAR:
			var granted_count: int = GameData.equipment_cards(offer_id).size()
			if granted_count > purchase_offer_card_count:
				purchase_offer_id = offer_id
				purchase_offer_card_count = granted_count
		elif offer_kind == RunEngine.MERCHANT_ITEM_KIND_ITEM and item_offer_id.is_empty():
			item_offer_id = offer_id
	var controller_offer: Control = _offer_source(shop, controller_offer_id, false)
	if controller_offer == null:
		_fail("Scavenger Magic should expose a controller-focusable offer wrapper")
	else:
		_assert_unified_offer(controller_offer, controller_offer_id, run_engine, true)
		controller_offer.grab_focus()
		await _settle()
		if root.gui_get_focus_owner() != controller_offer:
			_fail("Controller focus should remain on the selected shelf offer")
		var controller_snapshot: Dictionary = shop.call("semantic_snapshot")
		if str(controller_snapshot.get("selected_item_id", "")) != controller_offer_id:
			_fail("Controller focus should populate the same detail panel as pointer selection")
		if controller_offer.scale.x < 1.03:
			_fail("Focused Magic should lift its full offer wrapper, including price")
		_assert_detail_card(shop, controller_offer_id, "Magic focus")
		await _save("magic_detail.png")
		var second_magic: Control = _offer_source(shop, second_magic_id, false)
		if second_magic == null:
			_fail("Probe stock should expose a second Magic card for focus traversal")
		else:
			_assert_unified_offer(second_magic, second_magic_id, run_engine, true)
			second_magic.grab_focus()
			await _settle()
			if not controller_offer.scale.is_equal_approx(Vector2.ONE):
				_fail("Moving controller focus should return the previous full Magic offer to neutral")
			if second_magic.scale.x < 1.03:
				_fail("Moving controller focus should lift only the newly focused full Magic offer")
		await _save("controller_focus.png")

	var purchase_offer: Control = _offer_source(shop, purchase_offer_id, false)
	if purchase_offer == null:
		_fail("Scavenger Gear should expose a purchasable board-icon offer")
	else:
		_assert_unified_offer(purchase_offer, purchase_offer_id, run_engine, false)
		purchase_offer.grab_focus()
		await _settle()
		var expected_gear_cards: Array = GameData.equipment_cards(purchase_offer_id)
		var gear_snapshot: Dictionary = shop.call("semantic_snapshot")
		if (gear_snapshot.get("detail_card_ids", []) as Array) != expected_gear_cards:
			_fail("Gear detail should preserve every authored granted card in order")
		if not expected_gear_cards.is_empty():
			_assert_detail_card(shop, str(expected_gear_cards[0]), "Gear focus")
		await _save("gear_detail_first.png")
		if expected_gear_cards.size() != 3:
			_fail("The deterministic Gear offer should prove the full three-card inspection case")
		if expected_gear_cards.size() > 1:
			var gear_next: Button = shop.find_child("ScavengerNextGrantedCard", true, false) as Button
			if gear_next == null or not gear_next.visible or gear_next.disabled:
				_fail("Multi-card gear should expose a usable granted-card navigator")
			else:
				await _navigate_controller_to(shop, gear_next, "Gear offer to granted-card pager")
				await _press_controller_button(JOY_BUTTON_A)
				await _settle()
				_assert_detail_card(shop, str(expected_gear_cards[1]), "Second granted-card page")
				await _save("gear_detail_next.png")
				if expected_gear_cards.size() > 2:
					await _press_controller_button(JOY_BUTTON_A)
					await _settle()
					_assert_detail_card(shop, str(expected_gear_cards[2]), "Third granted-card page")
					await _save("gear_detail_third.png")

	var item_offer: Control = _offer_source(shop, item_offer_id, false)
	if item_offer == null:
		_fail("Scavenger Items should expose a purchasable board-icon offer")
	else:
		_assert_unified_offer(item_offer, item_offer_id, run_engine, false)
		item_offer.grab_focus()
		await _settle()
		_assert_detail_card(shop, item_offer_id, "Item focus")
		await _save("item_detail.png")

	if purchase_offer != null:
		await _navigate_controller_to(shop, purchase_offer, "Items shelf to Gear shelf")
		await _press_controller_button(JOY_BUTTON_A)
		await _settle()
	var trade_action: Button = shop.find_child("ScavengerTradeActionButton", true, false) as Button
	var purchase_embers_before: int = int((instance.get("_run_state") as Dictionary).get("held_embers", 0))
	if trade_action == null or trade_action.disabled:
		_fail("A selected affordable ware should expose an enabled Buy action")
	else:
		await _navigate_controller_to(shop, trade_action, "Gear shelf to Buy action")
		await _press_controller_button(JOY_BUTTON_A)
		await create_timer(0.70).timeout
		await _settle()
		var purchased_state: Dictionary = instance.get("_run_state") as Dictionary
		if int(purchased_state.get("held_embers", 0)) >= purchase_embers_before:
			_fail("The integrated Buy action should spend held embers")
		if not (purchased_state.get("equipment_inventory", []) as Array).has(purchase_offer_id):
			_fail("The integrated Gear purchase should enter equipment inventory")
		var post_purchase_snapshot: Dictionary = shop.call("semantic_snapshot")
		if str(post_purchase_snapshot.get("selected_item_id", "")) == purchase_offer_id:
			_fail("Purchased wares should clear from the detail panel after the shelf restocks")
		var recovered_focus: Control = root.gui_get_focus_owner()
		if recovered_focus == null or not shop.is_ancestor_of(recovered_focus) or not recovered_focus.is_visible_in_tree():
			_fail("A completed purchase should recover controller focus inside the rebuilt shop")
		await _save("post_purchase.png")
	var expensive_id: String = ""
	var expensive_cost: int = -1
	for offer_var: Variant in offers:
		var offer_id: String = str(offer_var)
		var cost: int = run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, offer_id)
		if cost > expensive_cost:
			expensive_id = offer_id
			expensive_cost = cost
	state["held_embers"] = 0
	state["unbanked_embers"] = 0
	shop.call("configure", state, run_engine, false)
	await _settle()
	var expensive_source: Control = _offer_source(shop, expensive_id, false)
	if expensive_source == null or bool(expensive_source.get_meta("shop_affordable", true)) or expensive_source.modulate.is_equal_approx(Color.WHITE):
		_fail("Unaffordable shelf offers should be visibly dim before selection")
	shop.call("_select_item", expensive_id, false, expensive_source)
	await _settle()
	trade_action = shop.find_child("ScavengerTradeActionButton", true, false) as Button
	if trade_action == null or not trade_action.disabled:
		_fail("Unaffordable selected offers should explain and disable purchase")
	await _save("focused_unaffordable.png")

	state = _scavenger_state(run_engine)
	instance.call("_load_run_state", state)
	await _settle()
	instance.call("_close_dialogue")
	await _settle()
	shop = instance.find_child("ScavengerShopView", true, false) as Control
	var sellable: Array = run_engine.merchant_sellable_ids(state, RunEngine.MERCHANT_SCAVENGER)
	if sellable.is_empty():
		_fail("Probe state should expose owned wares in Sell From Pack")
		return
	var sell_id: String = ""
	for index: int in range(sellable.size()):
		if run_engine.merchant_item_kind(str(sellable[index])) == RunEngine.MERCHANT_ITEM_KIND_MAGIC:
			sell_id = str(sellable[index])
			break
	if sell_id.is_empty():
		_fail("Probe state should expose owned Magic in Sell From Pack")
		return
	var sell_source: Control = _offer_source(shop, sell_id, true)
	var sell_page_guard: int = 0
	while sell_source == null and sell_page_guard < 20:
		sell_next = shop.find_child("SellNextPage", true, false) as Button
		if sell_next == null or sell_next.disabled:
			break
		sell_next.pressed.emit()
		await _settle()
		sell_page_guard += 1
		sell_source = _offer_source(shop, sell_id, true)
	if sell_source == null or not (sell_source is Button) or not str(sell_source.name).begins_with("SellMagicOffer_"):
		_fail("Owned Magic should use the same raster-backed sell tile as Items and Gear")
		return
	var sell_cards: Array[Node] = sell_source.find_children("*", "CardWidget", true, false)
	if sell_cards.size() != 1 or str(sell_cards[0].get("card_id")) != sell_id:
		_fail("The raster-backed Magic sell tile should still contain its canonical real CardWidget")
	if not ((sell_source as Button).get_theme_stylebox("normal") is StyleBoxTexture):
		_fail("Magic sell tiles should retain the authored raster backing used by other sell wares")
	sell_source.grab_focus()
	await _settle()
	_assert_detail_card(shop, sell_id, "Sell Magic focus")
	trade_action = shop.find_child("ScavengerTradeActionButton", true, false) as Button
	if trade_action == null or not trade_action.text.begins_with("SELL FOR"):
		_fail("Sell drawer selection should produce one explicit Sell For action")
	await _save("sell_selected.png")

	var before_embers: int = run_engine.held_embers(state)
	trade_action.grab_focus()
	trade_action.pressed.emit()
	await create_timer(0.70).timeout
	await _settle()
	state = instance.get("_run_state") as Dictionary
	if run_engine.held_embers(state) <= before_embers:
		_fail("Selling should increase held embers")
	var sale_focus: Control = root.gui_get_focus_owner()
	if sale_focus == null or not shop.is_ancestor_of(sale_focus) or not sale_focus.is_visible_in_tree():
		_fail("A completed sale should recover controller focus inside the rebuilt shop")
	await _save("post_sale.png")

	var reduced_settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	reduced_settings["reduced_motion"] = true
	instance.set("_settings", reduced_settings)
	state = _scavenger_state(run_engine)
	instance.call("_load_run_state", state)
	await _settle()
	instance.call("_close_dialogue")
	await _settle()
	shop = instance.find_child("ScavengerShopView", true, false) as Control
	var reduced_offer_id: String = ""
	for offer_var: Variant in run_engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER):
		if run_engine.merchant_item_kind(str(offer_var)) == RunEngine.MERCHANT_ITEM_KIND_ITEM:
			reduced_offer_id = str(offer_var)
			break
	var reduced_offer: Control = _offer_source(shop, reduced_offer_id, false)
	if reduced_offer == null:
		_fail("Reduced-motion transaction proof should expose an affordable Item")
	else:
		reduced_offer.grab_focus()
		await _settle()
		if not reduced_offer.scale.is_equal_approx(Vector2.ONE):
			_fail("Reduced motion should suppress offer lift animation")
		trade_action = shop.find_child("ScavengerTradeActionButton", true, false) as Button
		var reduced_embers_before: int = int((instance.get("_run_state") as Dictionary).get("held_embers", 0))
		trade_action.grab_focus()
		await _press_controller_button(JOY_BUTTON_A)
		await _settle()
		if int((instance.get("_run_state") as Dictionary).get("held_embers", 0)) >= reduced_embers_before:
			_fail("A real reduced-motion transaction should still complete without its flash/scale/slide tween")
	shop.call("present")
	await _settle()
	var reduced_snapshot: Dictionary = shop.call("semantic_snapshot")
	if not bool(reduced_snapshot.get("reduced_motion", false)):
		_fail("Reduced-motion shop state should be observable")
	await _save("reduced_motion.png")

	var leave_button: Button = shop.find_child("ScavengerLeaveButton", true, false) as Button
	if leave_button == null:
		_fail("Shop should provide a dedicated Leave action")
		return
	instance.call("_recover_controller_focus")
	await _settle()
	await _navigate_controller_to(shop, leave_button, "Recovered shop focus to Leave")
	await _press_controller_button(JOY_BUTTON_A)
	await _settle()
	if shop.visible:
		_fail("Leave should return to the board")
	await _save("board_after_leave.png")
	instance.queue_free()
	await process_frame

func _scavenger_state(run_engine: RunEngine) -> Dictionary:
	var progression: Dictionary = ProgressionStore.set_embers(ProgressionStore.default_data(), 720)
	var state: Dictionary = run_engine.create_new_run(73491, progression)
	var coord: Vector2i = _first_scavenger_coord(run_engine, state)
	if coord.x >= 900:
		_fail("Generated run should include a Scavenger room")
		return state
	var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = true
	room[RunEngine.MERCHANT_STOCK_KEY] = [
		"grave_mortar",
		"icicle_lance",
		"dawnstep",
		"boiled_leather",
		"dust_tabi",
		"duelist_rapier",
		"crimson_draught",
		"nail_bomb",
		"jaw_trap",
	]
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms[_room_key(coord)] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = "room"
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	state["held_embers"] = 720
	state["unbanked_embers"] = 720
	state["equipment_inventory"] = ["ward_kite", "iron_cleaver"]
	state["magic_inventory"] = ["spark_dart", "frostbolt"]
	state["reward_cards"] = ["spark_dart", "frostbolt"]
	state["item_inventory"] = ["crimson_draught", "nail_bomb", "smoke_bomb"]
	return state

func _first_scavenger_coord(run_engine: RunEngine, state: Dictionary) -> Vector2i:
	for radius: int in range(1, RunEngine.MAX_DEPTH + 1):
		for x: int in range(-radius, radius + 1):
			for y: int in range(-radius, radius + 1):
				if maxi(absi(x), absi(y)) != radius:
					continue
				var coord := Vector2i(x, y)
				if str(run_engine.room_metadata(state, coord).get("type", "")) == RunEngine.MERCHANT_SCAVENGER:
					return coord
	return Vector2i(999, 999)

func _offer_source(shop: Control, item_id: String, selling: bool) -> Control:
	var sources: Dictionary = shop.get("_offer_sources") as Dictionary
	return sources.get("%s:%s" % ["sell" if selling else "buy", item_id], null) as Control

func _assert_shelf_alignment(shop: Control, state: Dictionary, run_engine: RunEngine) -> void:
	var canvas: Control = shop.find_child("ScavengerShopCanvas", true, false) as Control
	if canvas == null:
		_fail("Scavenger shop should expose its authored 1920x1080 canvas")
		return
	var ids_by_kind: Dictionary = {
		RunEngine.MERCHANT_ITEM_KIND_MAGIC: [],
		RunEngine.MERCHANT_ITEM_KIND_GEAR: [],
		RunEngine.MERCHANT_ITEM_KIND_ITEM: [],
	}
	for offer_var: Variant in run_engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER):
		var item_id: String = str(offer_var)
		(ids_by_kind[run_engine.merchant_item_kind(item_id)] as Array).append(item_id)
	for kind: String in [RunEngine.MERCHANT_ITEM_KIND_MAGIC, RunEngine.MERCHANT_ITEM_KIND_GEAR, RunEngine.MERCHANT_ITEM_KIND_ITEM]:
		var item_ids: Array = ids_by_kind[kind] as Array
		for index: int in range(item_ids.size()):
			var offer: Control = _offer_source(shop, str(item_ids[index]), false)
			if offer == null:
				_fail("%s shelf offer %d should exist for alignment proof" % [kind.capitalize(), index + 1])
				continue
			var inverse_canvas_transform: Transform2D = canvas.get_global_transform_with_canvas().affine_inverse()
			var offer_center: Vector2 = inverse_canvas_transform * (offer.get_global_transform_with_canvas() * (offer.size * 0.5))
			if absf(offer_center.x - SHELF_CENTER_X[index]) > 1.0:
				_fail("%s offer %d is left/right shifted: canvas center %.1f, expected %.1f" % [kind.capitalize(), index + 1, offer_center.x, SHELF_CENTER_X[index]])
			var visual: Control = _offer_primary_visual(offer, kind)
			if visual == null:
				_fail("%s offer %d should expose its primary visual for centering proof" % [kind.capitalize(), index + 1])
			else:
				var visual_center: Vector2 = inverse_canvas_transform * (visual.get_global_transform_with_canvas() * (visual.size * 0.5))
				if absf(visual_center.x - SHELF_CENTER_X[index]) > 1.0:
					_fail("%s offer %d art is left/right shifted: canvas center %.1f, expected %.1f" % [kind.capitalize(), index + 1, visual_center.x, SHELF_CENTER_X[index]])

func _offer_primary_visual(offer: Control, kind: String) -> Control:
	if kind == RunEngine.MERCHANT_ITEM_KIND_MAGIC:
		return offer.find_child("MagicCard_*", true, false) as Control
	for child: Node in offer.find_children("*", "TextureRect", true, false):
		var texture_rect := child as TextureRect
		if texture_rect != null and texture_rect.texture != null:
			return texture_rect
	return null

func _navigate_controller_to(scope: Control, target: Control, context: String) -> void:
	if scope == null or target == null:
		_fail("%s should have a valid focus scope and target" % context)
		return
	var start: Control = root.gui_get_focus_owner()
	if start == target:
		return
	if start == null or not (start == scope or scope.is_ancestor_of(start)):
		_fail("%s should begin with focus inside the Scavenger shop" % context)
		return
	var pending: Array[Control]
	pending.append(start)
	var visited: Dictionary = {start.get_instance_id(): true}
	var routes: Dictionary = {start.get_instance_id(): []}
	var target_route: Array = []
	while not pending.is_empty():
		var current: Control = pending.pop_front()
		var current_route: Array = routes.get(current.get_instance_id(), []) as Array
		for edge: Dictionary in _controller_focus_edges():
			var neighbor: Control = current.find_valid_focus_neighbor(int(edge["side"]))
			if neighbor == null or not (neighbor == scope or scope.is_ancestor_of(neighbor)):
				continue
			var neighbor_id: int = neighbor.get_instance_id()
			if visited.has(neighbor_id):
				continue
			visited[neighbor_id] = true
			var next_route: Array = current_route.duplicate()
			next_route.append(int(edge["button"]))
			routes[neighbor_id] = next_route
			if neighbor == target:
				target_route = next_route
				pending.clear()
				break
			pending.append(neighbor)
	if target_route.is_empty():
		_fail("%s should be reachable through native directional focus" % context)
		return
	for button_index_var: Variant in target_route:
		await _press_controller_button(int(button_index_var))
	if root.gui_get_focus_owner() != target:
		_fail("%s should land on %s through real D-pad input" % [context, target.name])

func _controller_focus_edges() -> Array[Dictionary]:
	var result: Array[Dictionary]
	result.append({"side": SIDE_LEFT, "button": JOY_BUTTON_DPAD_LEFT})
	result.append({"side": SIDE_TOP, "button": JOY_BUTTON_DPAD_UP})
	result.append({"side": SIDE_RIGHT, "button": JOY_BUTTON_DPAD_RIGHT})
	result.append({"side": SIDE_BOTTOM, "button": JOY_BUTTON_DPAD_DOWN})
	return result

func _press_controller_button(button_index: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	press.device = 0
	root.push_input(press, true)
	await process_frame
	await process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	release.device = 0
	root.push_input(release, true)
	await process_frame

func _assert_unified_offer(source: Control, item_id: String, run_engine: RunEngine, expect_card: bool) -> void:
	if not (source is Button) or source.focus_mode != Control.FOCUS_ALL:
		_fail("%s should use one controller-focusable outer offer button" % item_id)
		return
	var expected_price: String = "%d EMBERS" % run_engine.merchant_buy_cost(RunEngine.MERCHANT_SCAVENGER, item_id)
	var price_label: Label = _descendant_label_with_text(source, expected_price)
	if price_label == null:
		_fail("%s should keep its ember price inside the same offer wrapper" % item_id)
	elif not source.get_global_rect().encloses(price_label.get_global_rect()):
		_fail("%s price should move and glow within its complete offer wrapper" % item_id)
	var cards: Array[Node] = source.find_children("*", "CardWidget", true, false)
	if expect_card and (cards.size() != 1 or str(cards[0].get("card_id")) != item_id):
		_fail("%s Magic shelf wrapper should contain one canonical passive CardWidget" % item_id)

func _assert_detail_card(shop: Control, expected_card_id: String, context: String) -> void:
	var detail_host: Control = shop.find_child("ScavengerDetailCardHost", true, false) as Control
	if detail_host == null:
		_fail("%s should expose the canonical detail-card host" % context)
		return
	var cards: Array[Node] = detail_host.find_children("*", "CardWidget", true, false)
	if cards.size() != 1:
		_fail("%s should show exactly one readable canonical CardWidget" % context)
		return
	if str(cards[0].get("card_id")) != expected_card_id:
		_fail("%s should show %s, not %s" % [context, expected_card_id, str(cards[0].get("card_id"))])
	if (cards[0] as Control).size != Vector2(250.0, 352.0):
		_fail("%s should preserve the card's authored 250x352 composition" % context)

func _descendant_label_with_text(node: Node, expected_text: String) -> Label:
	for child: Node in node.find_children("*", "Label", true, false):
		var label := child as Label
		if label != null and label.text == expected_text:
			return label
	return null

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.40).timeout
	await process_frame

func _save(filename: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	if image.get_size() != VIEWPORT_SIZE:
		image.resize(VIEWPORT_SIZE.x, VIEWPORT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	image.save_png("%s/%s" % [OUTPUT_DIR, filename])

func _room_key(coord: Vector2i) -> String:
	return "%d,%d" % [coord.x, coord.y]

func _clear_output() -> void:
	var absolute: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var dir := DirAccess.open(absolute)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if not dir.current_is_dir():
			DirAccess.remove_absolute(absolute.path_join(entry))
	dir.list_dir_end()

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
