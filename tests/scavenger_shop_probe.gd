extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")

const OUTPUT_DIR := "user://scavenger_shop_probe"
const VIEWPORT_SIZE := Vector2i(1920, 1080)

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
	await _save("normal.png")

	var offers: Array = run_engine.merchant_offer_ids(state, RunEngine.MERCHANT_SCAVENGER)
	var controller_offer_id: String = ""
	for offer_var: Variant in offers:
		if run_engine.merchant_item_kind(str(offer_var)) == RunEngine.MERCHANT_ITEM_KIND_GEAR:
			controller_offer_id = str(offer_var)
			break
	var controller_offer: Control = _offer_source(shop, controller_offer_id, false)
	if controller_offer == null:
		_fail("Scavenger Gear should expose a controller-focusable offer")
	else:
		controller_offer.grab_focus()
		await _settle()
		if root.gui_get_focus_owner() != controller_offer:
			_fail("Controller focus should remain on the selected shelf offer")
		var controller_snapshot: Dictionary = shop.call("semantic_snapshot")
		if str(controller_snapshot.get("selected_item_id", "")) != controller_offer_id:
			_fail("Controller focus should populate the same detail panel as pointer selection")
		await _save("controller_focus.png")
	var trade_action: Button = shop.find_child("ScavengerTradeActionButton", true, false) as Button
	var purchase_embers_before: int = int((instance.get("_run_state") as Dictionary).get("held_embers", 0))
	if trade_action == null or trade_action.disabled:
		_fail("A selected affordable ware should expose an enabled Buy action")
	else:
		trade_action.grab_focus()
		trade_action.pressed.emit()
		await create_timer(0.70).timeout
		await _settle()
		var purchased_state: Dictionary = instance.get("_run_state") as Dictionary
		if int(purchased_state.get("held_embers", 0)) >= purchase_embers_before:
			_fail("The integrated Buy action should spend held embers")
		if not (purchased_state.get("equipment_inventory", []) as Array).has(controller_offer_id):
			_fail("The integrated Gear purchase should enter equipment inventory")
		var post_purchase_snapshot: Dictionary = shop.call("semantic_snapshot")
		if str(post_purchase_snapshot.get("selected_item_id", "")) == controller_offer_id:
			_fail("Purchased wares should clear from the detail panel after the shelf restocks")
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
	shop.call("_select_item", expensive_id, false, expensive_source)
	await _settle()
	trade_action = shop.find_child("ScavengerTradeActionButton", true, false) as Button
	if trade_action == null or not trade_action.disabled:
		_fail("Unaffordable selected offers should explain and disable purchase")
	await _save("focused_unaffordable.png")

	state = _scavenger_state(run_engine)
	shop.call("configure", state, run_engine, false)
	await _settle()
	var sellable: Array = run_engine.merchant_sellable_ids(state, RunEngine.MERCHANT_SCAVENGER)
	if sellable.is_empty():
		_fail("Probe state should expose owned wares in Sell From Pack")
		return
	var sell_id: String = str(sellable[0])
	var sell_source: Control = _offer_source(shop, sell_id, true)
	shop.call("_select_item", sell_id, true, sell_source)
	await _settle()
	if trade_action == null or not trade_action.text.begins_with("SELL FOR"):
		_fail("Sell drawer selection should produce one explicit Sell For action")
	await _save("sell_selected.png")

	var before_embers: int = run_engine.held_embers(state)
	state = run_engine.sell_merchant_item(state, RunEngine.MERCHANT_SCAVENGER, sell_id)
	if run_engine.held_embers(state) <= before_embers:
		_fail("Selling should increase held embers")
	shop.call("configure", state, run_engine, false)
	await _settle()
	await _save("post_sale.png")

	shop.call("configure", state, run_engine, true)
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
	leave_button.pressed.emit()
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
