extends "res://tests/scavenger_shop_probe.gd"
## Native input, semantic transitions, containment and sale/save coverage.
const SettingsStore = preload("res://scripts/settings_store.gd")
const GLOW_OUTPUT := "user://scavenger_glowup_probe"
var _viewport: SubViewport
var _scene: Node
var _shop: Control

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://glow"))
	ProgressionStore.set_storage_path("user://glow/progression.json")
	ProgressionStore.set_run_storage_path("user://glow/run.save")
	SettingsStore.set_storage_path("user://glow/settings.json")
	var settings: Dictionary = SettingsStore.default_settings()
	settings["display_mode"] = SettingsStore.DISPLAY_WINDOWED
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = VIEWPORT_SIZE
	root.size = VIEWPORT_SIZE
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(GLOW_OUTPUT))
	await _capture_states()
	print(ProjectSettings.globalize_path(GLOW_OUTPUT))
	print("SCAVENGER GLOWUP: " + ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _capture_states() -> void:
	_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_viewport = SubViewport.new()
	_viewport.size = VIEWPORT_SIZE
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	_viewport.add_child(_scene)
	await _settle()
	var engine := RunEngine.new()
	var state: Dictionary = _scavenger_state(engine)
	_scene.call("_load_run_state", state)
	await create_timer(0.65).timeout
	_shop = _scene.get("_scavenger_shop_view") as Control
	_check(_shop.visible and not bool(_scene.get("_dialogue_active")), "Entry opens fullscreen shop without board dialogue")
	_check((_shop.find_child("ScavengerDialogueBody", true, false) as Label).is_visible_in_tree(), "Merchant welcome is inside the shop")
	_check(bool((_shop.call("semantic_snapshot") as Dictionary)["portrait_rig"]), "Production segmented portrait is loaded")
	var rig: Node = _shop.get("_portrait")
	var bones: Dictionary = rig.get("bones")
	var rest_root: Transform2D = (bones["root"] as Bone2D).transform
	rig.call("apply_pose", "idle", 0.0)
	var rest_head: Vector2 = (bones["head"] as Bone2D).global_position
	var rest_hand: Vector2 = (bones["grip_hand"] as Bone2D).global_position
	var rest_pack: Vector2 = (bones["pack"] as Bone2D).global_position
	rig.call("apply_pose", "idle", 0.5)
	var head_shift: Vector2 = (bones["head"] as Bone2D).global_position - rest_head
	var hand_shift: Vector2 = (bones["grip_hand"] as Bone2D).global_position - rest_hand
	var pack_shift: Vector2 = (bones["pack"] as Bone2D).global_position - rest_pack
	_check(bones.size() == 11 and head_shift.distance_to(hand_shift) > 3.0 and head_shift.distance_to(pack_shift) > 3.0, "Head, gripping hand and carried pack articulate separately at scene scale")
	_check((bones["root"] as Bone2D).transform == rest_root, "Idle keeps the lower body planted")
	await _save("01_entry.png")
	var sell_mode: Control = _shop.get("_mode_sell") as Control
	await _hover(sell_mode)
	_check((sell_mode as Button).is_hovered(), "Native pointer reaches the bespoke Sell action")
	await _save("02_mode_hover.png")
	await _mouse_button(sell_mode, true)
	await _save("03_mode_pressed.png")
	await _mouse_button(sell_mode, false)
	_check(bool((_shop.call("semantic_snapshot") as Dictionary)["pack_mode"]), "Mode click opens pack grid")
	await _save("04_pack.png")
	await _click(_shop.find_child("PackFilter_gear", true, false) as Control)
	_check(str((_shop.call("semantic_snapshot") as Dictionary)["pack_filter"]) == "gear", "Gear filter selected through pointer input")
	for id: Variant in _shop.get("_sellable_ids") as Array:
		_check(engine.merchant_item_kind(str(id)) == "gear", "Filtered grid contains only equipment")
	await _save("05_gear_filter.png")
	var sale: Control = _offer_source(_shop, "ward_kite", true)
	await _click(sale)
	await _save("06_sale_selected.png")
	var before: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	var amount: int = engine.merchant_sell_value("scavenger", "ward_kite")
	await _click(_shop.get("_detail_action") as Control, false)
	var after: Dictionary = _scene.get("_run_state") as Dictionary
	_check(int(after["held_embers"]) == int(before["held_embers"]) + amount, "Sale immediately pays exact displayed amount")
	_check(not (after["equipment_inventory"] as Array).has("ward_kite"), "Sale removes precisely the selected ware")
	_check(not bool(_scene.get("_merchant_trade_animation_active")), "Sale presentation does not lock further actions")
	var persisted: Dictionary = ProgressionStore.load_saved_run()
	_check(int(persisted.get("held_embers", -1)) == int(after["held_embers"]), "Sale is persisted before animation completes")
	await create_timer(0.10).timeout
	await _save("07_sale_lift.png")
	await create_timer(0.27).timeout
	await _save("08_sale_flight.png")
	await create_timer(0.55).timeout
	await _save("09_sale_receipt.png")
	_assert_receipt("ward_kite", true)
	var receipts_before_repeat: Array[Node] = (_shop.get("_purchase_effects") as Control).get_children()
	var before_repeat: Dictionary = (_scene.get("_run_state") as Dictionary).duplicate(true)
	_scene.call("_on_merchant_sell_pressed", "scavenger", "ward_kite", null)
	var repeated: Dictionary = _scene.get("_run_state") as Dictionary
	for key: String in ["held_embers", "equipment_inventory", "magic_inventory", "item_inventory", "reward_cards", "deck_cards"]:
		_check(repeated.get(key) == before_repeat.get(key), "Denied repeat leaves " + key + " unchanged")
	_check((_shop.get("_purchase_effects") as Control).get_children() == receipts_before_repeat, "Denied repeat sale creates no new receipt effect")
	# Enough distinct spare equipment to exercise page boundaries and filtering.
	state = _scavenger_state(engine)
	state["equipment_inventory"] = GameData.equipment_ids().slice(0, 22)
	state["collected_equipment"] = (state["equipment_inventory"] as Array).duplicate()
	_scene.call("_load_run_state", state)
	await _settle()
	_shop.call("_set_pack_mode", true)
	await _click(_shop.find_child("PackFilter_gear", true, false) as Control)
	var next: Button = _shop.get("_sell_next") as Button
	_check(not next.disabled, "Large pack has a reachable next page")
	await _click(next)
	_check(int(_shop.get("_sell_page")) == 1, "Next page changes visible wares")
	await _save("10_page_two.png")
	await _navigate_controller_to(_shop, _shop.get("_mode_buy") as Control, "Pack page to Browse")
	await _press_controller_button(JOY_BUTTON_A)
	await _settle()
	_check(not bool(_shop.get("_pack_mode")), "Controller changes back to shelves")
	var offer: Control = _offer_source(_shop, "grave_mortar", false)
	await _navigate_controller_to(_shop, offer, "Browse to Magic")
	await _press_controller_button(JOY_BUTTON_A)
	await _settle()
	_check(_viewport.gui_get_focus_owner() == _shop.get("_detail_action"), "Controller Accept enters the exact selected ware's trade action")
	_check(str(_shop.get("_selected_item_id")) == "grave_mortar", "Accept preserves the ware chosen for inspection")
	var hints: Control = _scene.get("_controller_prompt_bar") as Control
	_check(str(hints.call("prompts_snapshot")[0]["label"]) == "Buy", "Controller hint names the currently focused Buy action")
	_check(hints.get_global_rect().position.y >= 1020 and hints.get_global_rect().end.y <= 1080, "Shop controller hints fit below actions without covering the title")
	await _save("11_controller_inspection.png")
	await _navigate_controller_to(_shop, _shop.get("_detail_action") as Control, "Card to Buy")
	await _press_controller_button(JOY_BUTTON_A)
	await create_timer(0.16).timeout
	_check(((_scene.get("_run_state") as Dictionary)["magic_inventory"] as Array).has("grave_mortar"), "Controller Buy purchases the inspected Magic ware")
	await _save("12_purchase.png")
	_assert_receipt("grave_mortar", false)
	await create_timer(0.75).timeout
	# Empty and unaffordable states retain all navigation and explain why.
	state = _scavenger_state(engine)
	state["equipment_inventory"] = []
	state["magic_inventory"] = []
	state["item_inventory"] = []
	state["held_embers"] = 0
	state["unbanked_embers"] = 0
	_scene.call("_load_run_state", state)
	await _settle()
	await _click(_shop.get("_mode_sell") as Control)
	await _click(_shop.find_child("PackFilter_all", true, false) as Control)
	_check((_shop.get("_sellable_ids") as Array).is_empty(), "Empty pack contains no false sell candidates")
	await _save("13_empty_pack.png")
	await _click(_shop.get("_mode_buy") as Control)
	await _click(_offer_source(_shop, "grave_mortar", false))
	_check((_shop.get("_detail_action") as Button).disabled, "Unaffordable buy is visibly disabled")
	await _save("14_unaffordable.png")
	var settings: Dictionary = (_scene.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = true
	_scene.set("_settings", settings)
	_scene.call("_load_run_state", _scavenger_state(engine))
	await _settle()
	await _click(_shop.get("_mode_sell") as Control)
	await _click(_shop.find_child("PackFilter_all", true, false) as Control)
	await _click(_offer_source(_shop, "ward_kite", true))
	await _click(_shop.get("_detail_action") as Control)
	var effects: Control = _shop.get("_purchase_effects") as Control
	_check(effects.get_child_count() == 1 and not (effects.get_child(0).get("proxy") as Control).visible, "Reduced sale keeps static receipt without travelling proxy")
	await _save("15_reduced_sale.png")
	await _click(_shop.get("_leave_button") as Control)
	_check(not _shop.visible, "Leave closes even during a trade receipt")
	_scene.queue_free()
	await process_frame

func _hover(control: Control) -> void:
	var event := InputEventMouseMotion.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	_viewport.push_input(event, true)
	await create_timer(0.15).timeout

func _mouse_button(control: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = control.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_viewport.push_input(event, true)
	await process_frame

func _click(control: Control, settle: bool = true) -> void:
	if control == null:
		_fail("Missing native click target")
		return
	await _hover(control)
	await _mouse_button(control, true)
	await _mouse_button(control, false)
	if settle: await _settle()

func _save(filename: String) -> void:
	await RenderingServer.frame_post_draw
	_check_bounds(_shop)
	if (_shop.get("_detail_panel") as Control).visible:
		var title: Label = _shop.get("_detail_title") as Label
		var action: Button = _shop.get("_detail_action") as Button
		_check(Rect2(44, 54, 332, 84).encloses(Rect2(title.position, title.size)), "Name stays in the dark header interior, below border art")
		_check(Rect2(46, 588, 328, 78).encloses(Rect2(action.position, action.size)), "Trade action stays above the lower frame ornament")
		_check(_shop.find_child("ScavengerDetailKind", true, false) == null and _shop.find_child("ScavengerDetailPrice", true, false) == null, "Inspection omits redundant category, rarity and ownership copy")
	_check(_viewport.get_texture().get_image().get_size() == VIEWPORT_SIZE, "Proof is exactly 1920x1080")
	_viewport.get_texture().get_image().save_png(ProjectSettings.globalize_path(GLOW_OUTPUT.path_join(filename)))

func _check_bounds(node: Node) -> void:
	if node == null or (node is Control and not (node as Control).is_visible_in_tree()): return
	if node is CardWidget: return
	if node is Label:
		var label: Label = node as Label
		_check(label.get_visible_line_count() >= label.get_line_count(), "All lines fit in " + str(label.name) + ": " + label.text)
		var parent: Control = label.get_parent() as Control
		if parent != null:
			_check(parent.get_global_rect().grow(5).encloses(label.get_global_rect()), "Label bounds stay inside parent: " + label.text)
	for child: Node in node.get_children(): _check_bounds(child)

func _check(ok: bool, message: String) -> void:
	if not ok: _fail(message)

func _navigate_controller_to(scope: Control, target: Control, context: String) -> void:
	if scope == null or target == null:
		_fail("%s should have a valid focus scope and target" % context)
		return
	var start: Control = _viewport.gui_get_focus_owner()
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
	if _viewport.gui_get_focus_owner() != target:
		_fail("%s should land on %s through real D-pad input" % [context, target.name])

func _press_controller_button(button_index: int) -> void:
	var press := InputEventJoypadButton.new()
	press.button_index = button_index
	press.pressed = true
	press.device = 0
	_viewport.push_input(press, true)
	await process_frame
	await process_frame
	var release := InputEventJoypadButton.new()
	release.button_index = button_index
	release.pressed = false
	release.device = 0
	_viewport.push_input(release, true)
	await process_frame

func _assert_receipt(item_id: String, selling: bool) -> void:
	var heading: Label = _shop.get("_receipt_heading") as Label
	var name_label: Label = _shop.get("_receipt_detail") as Label
	var amount: Label = _shop.get("_receipt_amount") as Label
	_check(heading.text == ("SOLD" if selling else "PURCHASED"), "Receipt has one clear transaction heading")
	_check(name_label.text == str(_shop.call("_item_name", item_id)), "Receipt names the exact traded item")
	_check((_shop.get("_receipt_visual") as Control).get_child_count() == 1, "Receipt includes a single item visual")
	var tint: Color = amount.get_theme_color("font_color")
	_check(tint.g > tint.r if selling else tint.r > tint.g, "Receipt amount is green for income and red for spend")
	_check(amount.text.begins_with("+" if selling else "−"), "Receipt communicates currency direction without relying on color")
