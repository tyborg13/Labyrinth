extends RefCounted

const Ui = preload("res://scripts/card_empower_controller.gd")
const Charge = preload("res://scripts/card_empower_charge.gd")
const Data = preload("res://scripts/game_data.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Router = preload("res://scripts/input_router.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const SETTLE_FRAMES: int = 5
const FIXTURE_SEEDS := {"mouse": 60301, "drag": 60302, "blocked": 60303, "multi": 60304, "rotation": 60305, "survivor": 60306}

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var fixtures: Script = load("res://tests/suites/card_keywords_suite.gd")
	var original_size: Vector2i = tree.root.size
	tree.root.size = PROOF_SIZE
	_test_instances(expect)
	await _mouse_and_persistence(tree, expect, fixtures)
	await _drag(tree, expect, fixtures)
	await _surviving_copy(tree, expect, fixtures)
	await _blocked_and_lock(tree, expect, fixtures)
	await _rotation_and_precedence(tree, expect, fixtures)
	_expect_toggle_domains(expect)
	tree.root.size = original_size

static func _settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame

static func _seal(scene: Node, index: int = 0) -> Button:
	return (scene.call("_hand_card_control", index) as Node).get_node("EmpowerSeal") as Button

static func _key(scene: Node) -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_E
	key.physical_keycode = KEY_E
	key.pressed = true
	await scene.call("_input", key)

static func _mouse(tree: SceneTree, position: Vector2, click: bool = false) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = position
	motion.global_position = position
	Input.parse_input_event(motion)
	await _settle(tree)
	if click:
		for pressed: bool in [true, false]:
			var button := InputEventMouseButton.new()
			button.position = position
			button.global_position = position
			button.button_index = MOUSE_BUTTON_LEFT
			button.pressed = pressed
			Input.parse_input_event(button)
			await _settle(tree)

static func _test_instances(expect: Callable) -> void:
	var charge = Charge.new()
	var state: Dictionary = {"turn": 1, "deck": {"hand": ["same", "same", "other"]}}
	charge.observe(state)
	charge.toggle(1)
	charge.remove(0, state)
	var after: Dictionary = {"turn": 1, "deck": {"hand": ["same", "other", "new"]}}
	charge.observe(after)
	expect.call(charge.is_charged(0) and not charge.is_charged(1) and not charge.is_charged(2), "Charge follows the surviving identical copy, never newly drawn cards")
	charge.remove(0, after)
	charge.observe({"turn": 1, "deck": {"hand": ["other", "new", "same"]}})
	expect.call(not charge.is_charged(2), "Discarded or burned copies return uncharged")
	charge.toggle(0)
	charge.observe({"turn": 1, "player_turn_ending": true, "deck": {"hand": ["other", "new", "same"]}})
	expect.call(not charge.is_charged(0), "Charges clear immediately at turn end")

static func _mouse_and_persistence(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_empower_time"], FIXTURE_SEEDS["mouse"])
	var card: Control = scene.call("_hand_card_control", 0)
	await _mouse(tree, card.get_global_transform_with_canvas() * (card.size * 0.5))
	await _settle(tree)
	var hand_seal: Button = _seal(scene)
	var hand_point: Vector2 = hand_seal.get_global_transform_with_canvas() * (hand_seal.size * 0.5)
	await _mouse(tree, hand_point, true)
	expect.call(bool(scene.call("_hand_card_empowered", 0)) and int(scene.get("_selected_card_index")) == -1, "An unselected hovered card's seal can charge without selecting")
	await _mouse(tree, hand_point, true)
	await scene.call("_on_card_pressed", 0)
	await _settle(tree)
	var point: Vector2 = scene.call("_controller_board_point", fixtures.NEAR_TILE)
	await _mouse(tree, point)
	scene.call("_sync_click_targeting_arrow", point)
	expect.call(bool(scene.get_meta("targeting_cursor_suppressed", false)), "Click-targeting starts with the board arrow active")
	var seal: Button = _seal(scene)
	var seal_point: Vector2 = seal.get_global_transform_with_canvas() * (seal.size * 0.5)
	await _mouse(tree, seal_point)
	expect.call(not bool(scene.get_meta("targeting_cursor_suppressed", false)), "Pointer over the seal restores the action cursor")
	await _mouse(tree, seal_point, true)
	expect.call(bool(scene.call("_selected_card_empowered")) and int(scene.get("_selected_card_index")) == 0 and int(scene.get("_drag_card_index")) == -1, "A real mouse click on the seal charges during targeting without selecting or dragging")
	var found: bool = false
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) == "empower_toggled":
			var payload: Dictionary = event.get("payload", {})
			found = found or (payload.get("card_id") == "kwtest_empower_time" and payload.get("on") == true and payload.get("source") == "mouse" and payload.get("phase") == "targeting")
	expect.call(found, "Empower toggles append the specified analytics event")
	scene.call("_cancel_card_selection")
	await _settle(tree)
	expect.call(bool(scene.call("_hand_card_empowered", 0)) and _seal(scene).visible and not _seal(scene).get_node("Badge").visible, "Charged seal remains visible without a raised card or key hint")
	await scene.call("_on_card_pressed", 0)
	expect.call(bool(scene.call("_selected_card_empowered")), "Charge persists through deselect and reselect")
	var state: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	state["player_turn_ending"] = true
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	expect.call(not bool(scene.call("_hand_card_empowered", 0)), "Live turn-end state clears charge")
	# Charging a hand card is a UI choice even if its play budget is spent.
	state["player_turn_ending"] = false
	state["cards_played_this_turn"] = int(state.get("cards_per_turn", 3))
	scene.set("_combat_state", state)
	scene.call("_cancel_card_selection")
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_on_card_hover_started", 0)
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 0)), "A hovered hand card can be charged before it has a legal play")
	scene.queue_free()
	await _settle(tree)

static func _drag(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_empower_time"], FIXTURE_SEEDS["drag"])
	scene.call("_on_card_hover_started", 0)
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 0)), "E charges the hovered hand card")
	await scene.call("_on_card_drag_started", 0)
	var proxy: Node = scene.get("_drag_card_proxy")
	expect.call(proxy != null and bool(proxy.get_child(0).get_node("EmpowerSeal").get("charged")), "A card charged before dragging keeps its lit seal on the held proxy")
	await _key(scene)
	expect.call(proxy.get_child(0).get_node("EmpowerSeal").visible and not bool(proxy.get_child(0).get_node("EmpowerSeal").get("charged")), "An uncharged held card keeps its seal offered during the drag")
	await _key(scene)
	var point: Vector2 = scene.call("_controller_board_point", fixtures.NEAR_TILE)
	await scene.call("_update_card_drag", point)
	expect.call(bool(scene.call("_selected_card_empowered")), "A charged card enters drag targeting empowered")
	await _key(scene)
	expect.call(not bool(scene.call("_hand_card_empowered", 0)), "E can cancel charge mid-drag")
	await _key(scene)
	await scene.call("_commit_drag_drop", "play", point)
	expect.call(int((scene.get("_combat_state") as Dictionary).get("player_turn_time_spent", 0)) == 6, "Charged drag-drop pays Empower Time")
	expect.call(not bool(scene.call("_hand_card_empowered", 0)), "Playing removes the hand card's charge")
	scene.queue_free()
	await _settle(tree)

static func _blocked_and_lock(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_empower_health"], FIXTURE_SEEDS["blocked"])
	var state: Dictionary = scene.get("_combat_state")
	(state["player"] as Dictionary)["hp"] = 2
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_on_card_hover_started", 0)
	var toggles_before: int = _toggle_event_count()
	await _key(scene)
	expect.call(_toggle_event_count() == toggles_before, "Blocked attempts do not emit toggle analytics")
	expect.call(not bool(scene.call("_hand_card_empowered", 0)) and bool(_seal(scene).get("blocked")), "A lethal Empower health cost cannot be charged")
	expect.call(_seal(scene).tooltip_text == "Not enough health: Empower costs 2 HP." and not _seal(scene).get_node("Badge").visible, "Blocked seal gives the exact health explanation and hides the hint")
	state["relics"] = ["iron_lung"]
	(state["player"] as Dictionary)["stoneskin"] = 2
	scene.call("_mark_combat_preview_state_changed")
	expect.call(Ui.blocked_health(scene, 0) == 0, "Iron Lung Stoneskin makes a survivable cost chargeable")
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 0)), "Iron Lung's survivable health Empower charges")
	(state["player"] as Dictionary)["hp"] = 1
	scene.call("_mark_combat_preview_state_changed")
	expect.call(Ui.blocked_health(scene, 0) == 1, "An Iron Lung remainder equal to HP is blocked")
	scene.queue_free()
	await _settle(tree)
	var cards: Dictionary = Data.cards()
	cards["ui03_multi"] = fixtures._card("ui03 multi", 3, [{"type": "melee", "damage": 1, "range": 1}, {"type": "melee", "damage": 1, "range": 1}], {"empower": {"cost": {"time": 1}, "mods": [{"action": 0, "add": {"damage": 1}}]}})
	scene = await fixtures._live_instance(tree, expect, ["ui03_multi"], FIXTURE_SEEDS["multi"])
	await scene.call("_on_card_pressed", 0)
	await _key(scene)
	await scene.call("_on_board_tile_clicked", fixtures.NEAR_TILE)
	expect.call(int(scene.get("_selected_card_index")) == 0 and bool(_seal(scene).get("locked")), "Multi-target seal locks after its first target")
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 0)), "Locked seal preserves the charged choice")
	scene.queue_free()
	await _settle(tree)
	cards.erase("ui03_multi")

static func _rotation_and_precedence(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var cards: Dictionary = Data.cards()
	cards["ui03_aoe"] = fixtures._card("ui03 area", 3, [{"type": "aoe", "damage": 1, "range": 4, "pattern": [[0, 0], [1, 0]]}], {"empower": {"cost": {"time": 1}, "mods": [{"action": 0, "add": {"damage": 1}}]}})
	var scene: Node = await fixtures._live_instance(tree, expect, ["ui03_aoe", "kwtest_empower_time"], FIXTURE_SEEDS["rotation"])
	await scene.call("_on_card_pressed", 0)
	scene.call("_set_aoe_aim_orientation", Vector2i(0, 1))
	scene.set("_force_aim_key", "ui03-proof")
	scene.set("_force_aim_tile", fixtures.NEAR_TILE)
	scene.set("_force_aim_index", 1)
	scene.set("_hovered_card_index", 1)
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 0)) and not bool(scene.call("_hand_card_empowered", 1)), "E chooses selected card ahead of hovered card")
	expect.call(scene.get("_aoe_aim_orientation") == Vector2i(0, 1) and scene.get("_force_aim_key") == "ui03-proof" and int(scene.get("_force_aim_index")) == 1, "Empower preserves area rotation and force-aim")
	scene.set("_drag_card_index", 1)
	await _key(scene)
	expect.call(bool(scene.call("_hand_card_empowered", 1)), "Dragged card takes E precedence over the selected card")
	scene.set("_drag_card_index", -1)
	scene.call("_cancel_card_selection")
	scene.set("_hovered_card_index", 1)
	scene.set("_controller_hand_focused", false)
	expect.call(Ui.index_for_input(scene, true) == -1, "Controller toggling requires focus or selection, independent of pointer hover")
	var router: Node = tree.root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "steam_deck")
	scene.set("_controller_hand_focused", true)
	scene.set("_controller_hand_index", 1)
	scene.call("_refresh_controller_prompts")
	var seal: Button = _seal(scene, 1)
	expect.call(seal.get_node("Badge").text == "R3" and seal.tooltip_text.ends_with("Charged. Press RS to cancel.") and not seal.tooltip_text.contains("[E]"), "Controller seal uses the existing right-stick glyph and controller copy")
	var stick := InputEventJoypadButton.new()
	stick.button_index = JOY_BUTTON_RIGHT_STICK
	stick.pressed = true
	await scene.call("_handle_controller_input", stick)
	expect.call(not bool(scene.call("_hand_card_empowered", 1)), "Controller right stick toggles the focused hand card")
	router.call("clear_forced_state_for_test")
	router.call("set_modality", "pointer")
	scene.queue_free()
	await _settle(tree)
	cards.erase("ui03_aoe")

static func _surviving_copy(tree: SceneTree, expect: Callable, fixtures: Script) -> void:
	var scene: Node = await fixtures._live_instance(tree, expect, ["kwtest_empower_block", "kwtest_empower_block"], FIXTURE_SEEDS["survivor"])
	scene.call("_on_card_hover_started", 1)
	await _key(scene)
	await scene.call("_on_card_pressed", 0)
	await scene.call("_on_confirm_card_play_pressed")
	expect.call(bool(scene.call("_hand_card_empowered", 0)), "Playing an identical uncharged copy preserves the charged survivor")
	await scene.call("_on_card_pressed", 0)
	expect.call(int(((scene.get("_preview_combat_state") as Dictionary).get("player", {}) as Dictionary).get("block", 0)) == 11, "Prepared hand caches preserve the survivor's Empower bonus")
	scene.queue_free()
	await _settle(tree)

static func _expect_toggle_domains(expect: Callable) -> void:
	var sources: Dictionary = {}
	var phases: Dictionary = {}
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) != "empower_toggled": continue
		var payload: Dictionary = event.get("payload", {})
		sources[str(payload.get("source", ""))] = true
		phases[str(payload.get("phase", ""))] = true
	expect.call(sources.has("mouse") and sources.has("keyboard") and sources.has("controller"), "Toggle analytics cover all supported input sources")
	expect.call(phases.has("hand") and phases.has("targeting") and phases.has("drag") and phases.has("confirm"), "Toggle analytics cover all four interaction phases")

static func _toggle_event_count() -> int:
	var count: int = 0
	for event: Dictionary in Analytics.load_all_events():
		if str(event.get("event_type", "")) == "empower_toggled": count += 1
	return count
