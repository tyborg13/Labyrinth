extends RefCounted

const CombatEngine = preload("res://scripts/combat_engine.gd")
const Stay = preload("res://scripts/card_stay_rules.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Maneuver = preload("res://scripts/maneuver_rules.gd")
const Keyboard = preload("res://scripts/movement_target_keyboard.gd")

# Test/proof-only defaults. No production presentation or tuning lives here.
const FIXTURE_SEED: int = 90101
const FIXTURE_GRID_SIZE := Vector2i(9, 7)
const HERO := Vector2i(4, 3)
const FIXTURE_PLAYER_HP: int = 30
const FIXTURE_ENEMY_HP: int = 40
const SETTLE_FRAMES: int = 3
const KEYBOARD_SETTLE_PHYSICS_FRAMES: int = 10
const ARROW_ENDPOINT_TOLERANCE_PX: float = 1.0
# Invisible fixtures force a board tween to advance after the last physics
# sample, without depending on host load, elapsed time, or idle animation.
const FRAME_ORDER_BOARD_OFFSET := Vector2(0.0, 8.0)
const FRAME_ORDER_TWEEN_SECONDS: float = 1.0
const FRAME_ORDER_STEP_SECONDS: float = 0.5
const KEYBOARD_APPROACH_OFFSET := Vector2i(-1, -1)
const NO_TARGET := Vector2i(-1, -1)

static func run(expect: Callable) -> void:
	_test_support_cards(expect)
	_test_movement_triggers(expect)
	_test_eligibility_and_restrictions(expect)
	_test_successive_stay_analytics(expect)
	_test_immolation(expect)

static func _test_support_cards(expect: Callable) -> void:
	var engine := CombatEngine.new()
	for id: String in ["guarded_step", "warded_advance", "trapdoor", "hotfoot"]:
		var before: Dictionary = fixture(engine, id)
		if id == "hotfoot":
			Surface.place(before, HERO, "fire")
			Maneuver.record_activation_start(before)
		var prepared: Dictionary = engine.prepare_player_card(before, 0)
		var actions: Array = engine.card_play_actions(id, prepared)
		var action: Dictionary = actions[0]
		var targets: Array[Vector2i] = engine.valid_targets_for_player_action(prepared, action)
		expect.call(targets.has(HERO) and targets[0] != HERO, "%s offers Stay without changing the default target" % id)
		var after: Dictionary = _resolve(engine, prepared, actions)
		expect.call(after["player"]["pos"] == HERO, "%s Stay preserves position" % id)
		var blocks: Dictionary = {"guarded_step": 3, "warded_advance": 7, "trapdoor": 5, "hotfoot": 4}
		expect.call(after["player"]["block"] == blocks[id], "%s Stay applies its Block" % id)
		expect.call(int(after.get("card_stay_sequence", 0)) == 1, "%s records one resolved Stay" % id)
		if id == "guarded_step":
			expect.call(int(after.get("card_play_bonus_this_turn", 0)) == int(prepared.get("card_play_bonus_this_turn", 0)) + 1, "Guarded Step preserves its card-play reward")
		if id == "hotfoot":
			expect.call(after["deck"]["hand"].size() == before["deck"]["hand"].size() + 1, "Hotfoot draws one on Fire Stay")
		expect.call(prepared["player"]["block"] == 0 and prepared["player"]["pos"] == HERO, "%s resolution leaves the source state unchanged" % id)
		var finished: Dictionary = engine.finish_player_card(after, 0)
		expect.call(finished["deck"]["discard"].has(id) and int(finished.get("player_turn_time_spent", 0)) == engine.card_time_cost(id, prepared), "%s Stay pays ordinary card costs once" % id)
	var cold: Dictionary = fixture(engine, "hotfoot")
	var no_reward: Dictionary = _resolve(engine, cold, engine.card_play_actions("hotfoot", cold))
	expect.call(no_reward["player"]["block"] == 0 and no_reward["deck"]["hand"].size() == cold["deck"]["hand"].size(), "Hotfoot Stay off Fire grants no conditional rewards")
	Surface.place(cold, HERO, "fire")
	Maneuver.record_activation_start(cold)
	Surface.remove(cold, HERO, "fire")
	var left_fire: Dictionary = _resolve(engine, cold, engine.card_play_actions("hotfoot", cold))
	expect.call(left_fire["player"]["block"] == 4, "Hotfoot depends on activation start even after Fire is removed")

static func _test_movement_triggers(expect: Callable) -> void:
	var engine := CombatEngine.new()
	for id: String in ["cinder_trail", "trapdoor"]:
		var before: Dictionary = fixture(engine, id)
		before["relics"] = ["pilgrim_boots", "static_soles", "gale_tabi"]
		before["player"]["bleed"] = 2
		before["traps"] = [{"id": 90, "pos": HERO, "type": "fire", "damage": 6}]
		Surface.place(before, HERO, "ice")
		Maneuver.gain_flag(before, {"flag": "ice_skate"}, "fixture")
		var actions: Array = engine.card_play_actions(id, before)
		var movement: Dictionary = actions[actions.size() - 1] if id == "cinder_trail" else actions[0]
		var after: Dictionary = engine.apply_player_action(before, movement, HERO)
		expect.call(after["player"]["pos"] == HERO and after["player"]["hp"] == before["player"]["hp"], "%s Stay causes no Bleed, arrival, trap, or collision damage" % id)
		expect.call(after["enemies"] == before["enemies"], "Stay causes no enemy trail, collision, or movement-trigger effects")
		expect.call(after["traps"] == before["traps"] and after.get("surfaces", {}) == before.get("surfaces", {}), "%s Stay neither triggers traps nor paints trails" % id)
		expect.call(after.get("turn_flags", {}) == before.get("turn_flags", {}) and after.get("umbra", {}) == before.get("umbra", {}), "%s Stay does not fire movement relics, light trails, counters, or Skate" % id)
		expect.call(after.get("player_movement_remaining") == before.get("player_movement_remaining"), "Stay never spends independent movement")
		var moved: Dictionary = engine.apply_player_action(before, movement, HERO + Vector2i.UP)
		expect.call(moved.get("surfaces", {}) != before.get("surfaces", {}) or moved.get("turn_flags", {}) != before.get("turn_flags", {}), "Positive control: an actual movement fires movement consequences")

static func _test_eligibility_and_restrictions(expect: Callable) -> void:
	var engine := CombatEngine.new()
	var state: Dictionary = fixture(engine, "guarded_step")
	for id: String in ["flowing_step", "grapple", "seek_the_light"]:
		for action: Dictionary in engine.card_play_actions(id, state):
			expect.call(not Stay.action_offers_stay(action) and not engine.valid_targets_for_player_action(state, action).has(HERO), "%s pure movement cannot Stay" % id)
	var action: Dictionary = engine.card_play_actions("guarded_step", state)[0]
	for direction: Vector2i in [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]:
		state["grid"][HERO.y + direction.y][HERO.x + direction.x] = "wall"
	expect.call(engine.valid_targets_for_player_action(state, action) == _tiles([HERO]) and engine.player_action_has_valid_target(state, action), "An enclosed hero can still Stay for support")
	state["player_turn_restrictions"] = {"immobilized": true}
	expect.call(engine.valid_targets_for_player_action(state, action).is_empty(), "Immobilized movement remains unavailable")
	var blocked: Dictionary = engine.apply_player_action(state, action, HERO)
	expect.call(not blocked.has("card_stay_sequence"), "An immobilized action never records Stay")
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var after: Dictionary = engine.apply_player_action(fixture(engine, "guarded_step"), action, HERO)
	var targets: Array[Vector2i] = _tiles([HERO])
	var payload: Dictionary = scene.call("_analytics_card_play_payload", "guarded_step", fixture(engine, "guarded_step"), after, [action], targets)
	expect.call(payload.get("stayed", false) == true and payload["move_distance"] == 0, "Card analytics records stayed only for a resolved Stay")
	expect.call(engine.card_keyword_play_summary("guarded_step", fixture(engine, "guarded_step"), after, [action]).get("stayed", false), "Shared play summary also supplies stayed to headless analytics")
	payload = scene.call("_analytics_card_play_payload", "guarded_step", state, blocked, [action], targets)
	expect.call(not payload.has("stayed"), "Blocked actions omit stayed analytics")
	var walked: Dictionary = fixture(engine, "guarded_step")
	var returned: Dictionary = engine.apply_player_action(walked, action, HERO + Vector2i.UP)
	returned = engine.apply_player_action(returned, action, HERO)
	var walk_targets: Array[Vector2i] = _tiles([HERO + Vector2i.UP, HERO])
	payload = scene.call("_analytics_card_play_payload", "guarded_step", walked, returned, [action, action], walk_targets)
	expect.call(not payload.has("stayed") and payload["move_distance"] == 0, "Returning to the origin through real moves never reports Stay")
	scene.free()

static func _test_successive_stay_analytics(expect: Callable) -> void:
	var engine := CombatEngine.new()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var initial: Dictionary = fixture(engine, "guarded_step")
	initial["deck"]["hand"] = ["guarded_step", "guarded_step"]
	var live_states: Array[Dictionary]
	var live_payloads: Array[Dictionary]
	for replay: bool in [false, true]:
		var before: Dictionary = bytes_to_var(var_to_bytes(initial)) if replay else initial
		for play: int in range(2):
			# The production save uses the same Variant codec. Restore between plays
			# too, so the second event must compare against a persisted nonzero counter.
			if replay:
				before = (bytes_to_var(var_to_bytes({"combat_state": before})) as Dictionary)["combat_state"]
			var prepared: Dictionary = engine.prepare_player_card(before, 0)
			var actions: Array = engine.card_play_actions("guarded_step", prepared)
			var after: Dictionary = engine.finish_player_card(_resolve(engine, prepared, actions), 0)
			var targets: Array[Vector2i] = _tiles([HERO])
			var payload: Dictionary = scene.call("_analytics_card_play_payload", "guarded_step", before, after, actions, targets)
			expect.call(payload.get("stayed", false) == true and payload["move_distance"] == 0, "Successive Stay %d reports stayed (serialized replay: %s)" % [play + 1, replay])
			expect.call(engine.card_keyword_play_summary("guarded_step", before, after, actions).get("stayed", false), "Successive Stay %d also reaches headless analytics (serialized replay: %s)" % [play + 1, replay])
			expect.call(int(after.get("card_stay_sequence", 0)) == play + 1 and after["deck"]["discard"].size() == play + 1, "Each successive Stay advances the sequence and finishes its own card")
			if replay:
				expect.call(after == live_states[play] and payload == live_payloads[play], "Serialized Stay %d replays the exact state and analytics payload" % (play + 1))
			else:
				live_states.append(after)
				live_payloads.append(payload)
			before = after
	scene.free()

static func _test_immolation(expect: Callable) -> void:
	var engine := CombatEngine.new()
	for fire: bool in [false, true]:
		var state: Dictionary = fixture(engine, "immolation")
		if fire: Surface.place(state, HERO + Vector2i.RIGHT, "fire")
		var actions: Array = engine.card_play_actions("immolation", state)
		var after: Dictionary = _resolve(engine, state, actions)
		expect.call(after["enemies"][0]["hp"] == FIXTURE_ENEMY_HP - (11 if fire else 3), "Immolation deals 3 innate plus 8 only with Fire")
		expect.call(after["enemies"][1]["hp"] == FIXTURE_ENEMY_HP - (8 if fire else 0) and after["player"]["hp"] == FIXTURE_PLAYER_HP, "Base Immolation spares hero; Fire blast retains its ordinary neighboring splash")
	var state: Dictionary = fixture(engine, "immolation")
	Surface.place(state, HERO + Vector2i.RIGHT * 2, "fire")
	var empowered: Dictionary = engine.prepare_player_card(state, 0, "empower")
	var actions: Array = engine.card_play_actions("immolation", empowered)
	expect.call(actions.size() == 2 and actions[0]["pattern"].size() == 4 and actions[0]["damage"] == 3 and actions[1]["pattern"].size() == 13, "Empower widens only the second detonate action")
	var after: Dictionary = _resolve(engine, empowered, actions)
	expect.call(after["enemies"][0]["hp"] == FIXTURE_ENEMY_HP - 11 and after["enemies"][1]["hp"] == FIXTURE_ENEMY_HP - 8, "Empower's outer enemy takes only detonation damage")
	after = engine.finish_player_card(after, 0)
	expect.call(after["player"]["hp"] == FIXTURE_PLAYER_HP - 2, "Empower pays its authored 2 HP once")

static func run_live(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/fixtures/cbt_01_presentation_scene.gd"))
	tree.root.add_child(scene)
	await settle(tree)
	install(scene, "guarded_step")
	await scene.call("_on_card_pressed", 0)
	var targets: Array = scene.get("_pending_target_tiles")
	expect.call(targets.has(HERO) and targets[0] != HERO, "UI targeting preserves default and includes hero")
	scene.call("_on_board_tile_hovered", HERO)
	await settle(tree)
	assert_stay_preview(scene, expect)
	var router: Node = tree.root.get_node_or_null("InputRouter")
	if router != null: router.call("set_forced_state_for_test", "pointer", "steam_deck")
	await keyboard_focus_hero(scene)
	await settle_keyboard(tree)
	await assert_keyboard_stay_focus(scene, expect)
	await _test_presented_arrow_frame(tree, scene, expect, "direct")
	assert_stay_preview(scene, expect)
	var neutral_stick := InputEventJoypadMotion.new()
	neutral_stick.axis = JOY_AXIS_LEFT_X
	neutral_stick.axis_value = 0.0
	await scene.call("_input", neutral_stick)
	await assert_keyboard_stay_focus(scene, expect)
	var pointer := InputEventMouseMotion.new()
	pointer.position = scene.call("_controller_board_point", HERO)
	await scene.call("_input", pointer)
	expect.call(not preload("res://scripts/movement_target_keyboard.gd").active(scene) and (scene.get("board_view") as Control).get("_controller_focus_tile") == NO_TARGET, "Pointer input releases keyboard-owned focus")
	await keyboard_focus_hero(scene)
	await settle_keyboard(tree)
	await assert_keyboard_stay_focus(scene, expect)
	await _test_keyboard_cancel_reselect(tree, scene, expect)
	var confirm := InputEventKey.new()
	confirm.keycode = KEY_ENTER
	confirm.pressed = true
	await scene.call("_input", confirm)
	var after: Dictionary = scene.get("_combat_state")
	expect.call(after["player"]["pos"] == HERO and after["player"]["block"] == 3 and after["deck"]["discard"].has("guarded_step"), "Keyboard confirm commits Stay and support effects")
	expect.call(int(scene.get("cbt_01_walk_presentations")) == 0, "Move Stay presents no walk animation")
	expect.call(not preload("res://scripts/movement_target_keyboard.gd").active(scene), "Keyboard targeting ends with its card selection")
	if router != null:
		router.call("set_forced_state_for_test", "controller", "steam_deck")
		install(scene, "trapdoor")
		await scene.call("_on_card_pressed", 0)
		scene.set("_controller_region", "board")
		scene.call("_controller_set_board_tile", HERO)
		var accept := InputEventJoypadButton.new()
		accept.button_index = JOY_BUTTON_A
		accept.pressed = true
		await scene.call("_input", accept)
		var blink_stay: Dictionary = scene.get("_combat_state")
		expect.call(blink_stay["player"]["pos"] == HERO and blink_stay["player"]["block"] == 5 and blink_stay["deck"]["discard"].has("trapdoor"), "Controller A confirms Blink Stay and support effects")
		expect.call(int(scene.get("cbt_01_blink_presentations")) == 0, "Blink Stay presents no Blink effect")
		router.call("set_forced_state_for_test", "pointer", "steam_deck")
		router.call("clear_forced_state_for_test")
	install(scene, "immolation")
	await scene.call("_on_card_pressed", 0)
	await settle(tree)
	assert_immolation_preview(scene, expect)
	install(scene, "riposte_lunge")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", HERO)
	await settle(tree)
	var riposte_preview: Dictionary = scene.call("_board_display_state")
	expect.call(int((riposte_preview.get("retaliate", {}) as Dictionary).get("amount", 0)) == 4, "Stay hover includes riders after the movement-only attack omission")
	expect.call(not (scene.get("_combat_state") as Dictionary).has("retaliate"), "Stay hover does not commit Retaliate")
	await scene.call("_on_board_tile_clicked", HERO)
	var riposte_stay: Dictionary = scene.get("_combat_state")
	expect.call(int((riposte_stay.get("retaliate", {}) as Dictionary).get("amount", 0)) == 4 and riposte_stay["player"]["pos"] == HERO and riposte_stay["enemies"][0]["hp"] == FIXTURE_ENEMY_HP, "Stay commit matches its movement-only continuation preview")
	# The same preview remains useful under limited sight, without exposing the
	# Vision rider or any concealed board consequences.
	install(scene, "guarded_step")
	var limited: Dictionary = scene.get("_combat_state")
	limited["umbra"]["stage"] = "heart"
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", HERO)
	await settle(tree)
	assert_stay_preview(scene, expect)
	scene.queue_free()
	await tree.process_frame
	await _test_staged_arrow_startup(tree, expect)

static func _test_staged_arrow_startup(tree: SceneTree, expect: Callable) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(preload("res://tests/fixtures/cbt_01_presentation_scene.gd"))
	# Match MenuRunTransition: request staging before _ready, disable destination
	# processing while loading owns it, then run the production UI preparation.
	scene.call("request_staged_initial_ui")
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	tree.root.add_child(scene)
	expect.call(not bool(scene.get("_initial_ui_complete")), "Staged arrow fixture takes the early return before UI preparation")
	await tree.process_frame
	await scene.get_script().call("prepare_initial_ui_for", scene, _present_loading_frame.bind(tree), func() -> bool: return is_instance_valid(scene) and not scene.is_queued_for_deletion())
	expect.call(bool(scene.get("_initial_ui_complete")), "Staged arrow fixture completes the production startup jobs")
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	await settle(tree)
	install(scene, "guarded_step")
	await scene.call("_on_card_pressed", 0)
	var router: Node = tree.root.get_node_or_null("InputRouter")
	if router != null: router.call("set_forced_state_for_test", "pointer", "steam_deck")
	await keyboard_focus_hero(scene)
	await settle_keyboard(tree)
	await assert_keyboard_stay_focus(scene, expect)
	await _test_presented_arrow_frame(tree, scene, expect, "staged")
	if router != null: router.call("clear_forced_state_for_test")
	scene.queue_free()
	await tree.process_frame

static func _present_loading_frame(tree: SceneTree) -> void:
	await tree.process_frame

static func _test_keyboard_cancel_reselect(tree: SceneTree, scene: Node, expect: Callable) -> void:
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	var cancel := InputEventKey.new()
	cancel.keycode = KEY_ESCAPE
	cancel.pressed = true
	await scene.call("_input", cancel)
	await settle_keyboard(tree)
	expect.call(int(scene.get("_selected_card_index")) == -1 and scene.get("_combat_state") == before, "Keyboard cancellation deselects Stay without committing the card")
	expect.call(not scene.has_meta(Keyboard.FOCUS_META), "Cancellation removes keyboard ownership metadata")
	# Reselect without a mouse event: pointer handoff would independently clear
	# stale ownership and hide a missing selection-reset cleanup.
	await scene.call("_on_card_pressed", 0)
	await settle_keyboard(tree)
	expect.call(int(scene.get("_selected_card_index")) == 0, "Cancelled Stay can be selected again")
	expect.call(not Keyboard.active(scene), "Reselection without a keypress does not inherit keyboard ownership")
	var board: Control = scene.get("board_view")
	expect.call(board.get("_controller_focus_tile") == NO_TARGET and scene.get("_hovered_board_tile") == NO_TARGET, "Reselection without a keypress does not restore the rendered keyboard cursor or hover")
	await keyboard_focus_hero(scene)
	await settle_keyboard(tree)
	await assert_keyboard_stay_focus(scene, expect)
	assert_stay_preview(scene, expect)

static func keyboard_focus_hero(scene: Node) -> void:
	scene.set("_controller_region", "board")
	scene.call("_controller_set_board_tile", HERO + KEYBOARD_APPROACH_OFFSET)
	var down := InputEventKey.new()
	down.keycode = KEY_DOWN
	down.pressed = true
	await scene.call("_input", down)

static func settle_keyboard(tree: SceneTree) -> void:
	for frame: int in range(KEYBOARD_SETTLE_PHYSICS_FRAMES): await tree.physics_frame
	await settle(tree)

static func assert_keyboard_stay_focus(scene: Node, expect: Callable) -> void:
	var board: Control = scene.get("board_view")
	expect.call(not scene.call("_controller_is_active"), "Stay regression uses keyboard/pointer modality")
	expect.call(scene.get("_controller_board_tile") == HERO and scene.get("_hovered_board_tile") == HERO, "Keyboard focus and hover remain on (4,3) after physics frames")
	expect.call(board.get("_controller_focus_tile") == HERO, "Rendered board focus remains on (4,3) after physics frames")
	await assert_arrow_at_hero(scene, expect)

static func assert_arrow_at_hero(scene: Node, expect: Callable) -> void:
	# process_frame resumes before node processing and idle tweens. Compare at
	# the presentation boundary, after production has sampled that same frame.
	await presented_frame(scene.get_tree())
	var arrow: Control = scene.get("_drag_target_arrow")
	var arrow_endpoint: Vector2 = arrow.get_global_transform_with_canvas() * (arrow.call("targeting_end") as Vector2)
	var hero_point: Vector2 = scene.call("_controller_board_point", HERO)
	expect.call(arrow.is_visible_in_tree() and arrow_endpoint.distance_to(hero_point) <= ARROW_ENDPOINT_TOLERANCE_PX, "Targeting arrow remains visible and ends on the hero (visible: %s, endpoint: %s, hero: %s)" % [arrow.is_visible_in_tree(), arrow_endpoint, hero_point])

static func presented_frame(tree: SceneTree) -> void:
	if DisplayServer.get_name() == "headless":
		# The dummy renderer has no native boundary. Emit only that missing signal
		# after this frame's nodes/tweens, matching other headless scene fixtures.
		await tree.process_frame
		RenderingServer.frame_pre_draw.emit.call_deferred()
	await RenderingServer.frame_pre_draw

static func _test_presented_arrow_frame(tree: SceneTree, scene: Node, expect: Callable, startup_path: String) -> void:
	var board: Control = scene.get("board_view")
	var callback := Callable(scene, "_sync_card_targeting_arrow_after_layout")
	var connection_count: int = 0
	for connection: Dictionary in board.item_rect_changed.get_connections():
		if connection["callable"] == callback: connection_count += 1
	expect.call(connection_count == 1, "%s startup connects the board transform to the arrow exactly once" % startup_path)
	var centering: Tween = scene.get("_board_centering_tween")
	if centering != null and centering.is_valid(): centering.kill()
	var original_position: Vector2 = board.position
	var physics_enabled: bool = scene.is_physics_processing()
	scene.set_physics_process(false)
	Keyboard.preserve_focus(scene)
	var sampled_point: Vector2 = scene.call("_controller_board_point", HERO)
	var tween: Tween = tree.create_tween()
	tween.pause()
	tween.tween_property(board, "position", original_position + FRAME_ORDER_BOARD_OFFSET, FRAME_ORDER_TWEEN_SECONDS)
	tween.custom_step(FRAME_ORDER_STEP_SECONDS)
	var moved_point: Vector2 = scene.call("_controller_board_point", HERO)
	expect.call(sampled_point.distance_to(moved_point) > ARROW_ENDPOINT_TOLERANCE_PX, "Frame-order fixture advances the real board transform beyond the unchanged arrow tolerance")
	await assert_arrow_at_hero(scene, expect)
	var candidate: Dictionary = scene.get("_controller_focus_candidate")
	expect.call((candidate.get("point", Vector2.INF) as Vector2).distance_to(scene.call("_controller_board_point", HERO)) <= ARROW_ENDPOINT_TOLERANCE_PX, "Controller focus candidate and arrow retain the same presented board geometry")
	var arrow: Control = scene.get("_drag_target_arrow")
	var endpoint: Vector2 = arrow.get_global_transform_with_canvas() * (arrow.call("targeting_end") as Vector2)
	print("DET-01 ARROW STARTUP %s: connections=%d physics=%s presented=%s endpoint_error=%.6f" % [startup_path, connection_count, sampled_point, moved_point, endpoint.distance_to(scene.call("_controller_board_point", HERO))])
	tween.kill()
	board.position = original_position
	scene.set_physics_process(physics_enabled)
	await assert_arrow_at_hero(scene, expect)

static func assert_stay_preview(scene: Node, expect: Callable) -> void:
	var board: Control = scene.get("board_view")
	var chips: Array = (board.get("presentation") as Dictionary).get("movement_risk_chips", [])
	expect.call(chips.any(func(chip: Dictionary) -> bool: return chip.get("label") == "Stay" and chip.get("tile") == HERO), "Hero hover displays the Stay destination chip")
	var shown: Dictionary = scene.call("_board_display_state")
	expect.call(shown["player"]["pos"] == HERO and shown["player"]["block"] == 3, "Stay board preview shows Block without moving")
	expect.call((scene.get("_combat_state") as Dictionary)["player"]["block"] == 0, "Hover never commits Block")

static func assert_immolation_preview(scene: Node, expect: Callable) -> void:
	var board: Control = scene.get("board_view")
	var losses: Dictionary = (board.get("presentation") as Dictionary).get("damage_preview", {})
	expect.call(int((losses.get("enemy_1", {}) as Dictionary).get("hp", -1)) == FIXTURE_ENEMY_HP - 3, "Immolation preview shows innate 3 with no Fire")
	expect.call((scene.get("_combat_state") as Dictionary).get("surfaces", {}).is_empty(), "Immolation preview fixture has no Fire")

static func fixture(engine: RefCounted, id: String) -> Dictionary:
	var state: Dictionary = engine.create_combat(FIXTURE_SEED, room(), {
		"hp": FIXTURE_PLAYER_HP, "max_hp": FIXTURE_PLAYER_HP,
		"deck_cards": [id, "brace"], "hand_size": 2, "relics": [], "heal_bonus": 0,
	})
	state["deck"]["hand"] = [id, "brace"]
	state["deck"]["draw"] = ["quick_stab", "brace"]
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	return state

static func room() -> Dictionary:
	var grid: Array = []
	for y: int in range(FIXTURE_GRID_SIZE.y):
		var row: Array[String]
		for x: int in range(FIXTURE_GRID_SIZE.x):
			row.append("wall" if x == 0 or y == 0 or x == FIXTURE_GRID_SIZE.x - 1 or y == FIXTURE_GRID_SIZE.y - 1 else "stone")
		grid.append(row)
	return {"name": "Cinder Crossing", "coord": Vector2i(1, 0), "type": "combat", "depth": 1,
		"grid": grid, "player_start": HERO, "traps": [], "terrain": [], "loot": [],
		"enemies": [_enemy(1, HERO + Vector2i.RIGHT), _enemy(2, HERO + Vector2i.RIGHT * 2)]}

static func _enemy(id: int, pos: Vector2i) -> Dictionary:
	return {"id": id, "type": "crawler", "pos": pos, "hp": FIXTURE_ENEMY_HP, "max_hp": FIXTURE_ENEMY_HP, "block": 0, "stoneskin": 0, "base_initiative": 9}

static func install(scene: Node, id: String) -> void:
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	var state: Dictionary = fixture(CombatEngine.new(), id)
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = room()["coord"]
	run["current_room_layout"] = room()
	run["combat_state"] = state
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.set("_animation_lock", false)
	scene.set("_guided_tutorial_phase_id", "")
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")

static func _resolve(engine: RefCounted, state: Dictionary, actions: Array) -> Dictionary:
	var after: Dictionary = state
	for action: Dictionary in actions:
		after = engine.apply_player_action(after, action, HERO if engine.player_action_needs_target(action) else NO_TARGET)
	return after

static func _tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for value: Vector2i in values: result.append(value)
	return result

static func settle(tree: SceneTree) -> void:
	for frame: int in range(SETTLE_FRAMES): await tree.process_frame
