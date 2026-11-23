extends RefCounted
## Choose ordinary plays on a read-only snapshot, then replay them through the
## live hand, board and Pass controls. No policy state is installed in the run.

const Policy = preload("res://tools/smoke_recording/capture_policy.gd")
const OPENING_ATTACK: String = "dull_bolt"
const OPENING_MOVES: PackedStringArray = ["shadow_step", "guarded_step"]
const MAX_ACTIONS: int = 65
const INVALID := Vector2i(-1, -1)

var route
var policy := Policy.new()

func _init(owner: SceneTree) -> void:
	route = owner

func scene() -> Node:
	return route.scene

func board() -> Control:
	return scene().get("board_view")

func tile_point(tile: Vector2i) -> Vector2:
	return board().get_global_transform_with_canvas() * board().call("_tile_center", tile)

func hero() -> Vector2i:
	return route.battle()["player"]["pos"]

func selected() -> int:
	return int(scene().get("_selected_card_index"))

func tooltip_owned(card: Control) -> bool:
	var stack: Control = scene().get("_card_focus_tooltip_stack")
	return is_instance_valid(card) and stack.visible and stack.get("_follow_target") == card

func hand_point(index: int) -> Vector2:
	# Fan slots can overlap at their edges. Use the visible center of the card
	# within the viewport so the same adapter works with the tucked hand.
	var card: Control = scene().call("_hand_card_control", index)
	var rect: Rect2 = card.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, card.size)
	return rect.intersection(route.root.get_visible_rect()).get_center()

func select_mouse(index: int) -> bool:
	if not route.require(index >= 0 and route.driver.usable(scene().call("_hand_card_control", index)), "Hand card for selection"): return false
	route.driver.motion(hand_point(index))
	await route.frames(route.LAYOUT_FRAMES)
	await route.driver.click(hand_point(index))
	return route.require(selected() == index, "Mouse selected hand card %s (actual %s)" % [index, selected()])

func aim(tile: Vector2i) -> void:
	route.driver.motion(tile_point(tile))
	var started: int = Engine.get_process_frames()
	await route.until(func() -> bool: return scene().get("_hovered_board_tile") == tile, "Board hover reached %s" % str(tile), 60)
	var waited: int = Engine.get_process_frames() - started
	if waited > route.LAYOUT_FRAMES: print("CAP09 NOTE: hover %s took %d frames" % [tile, waited])
	if route.failed: print("CAP09 NOTE: hovered %s, board hover %s, pointer %s, aim %s" % [scene().get("_hovered_board_tile"), board().get("_hover_tile"), route.root.get_mouse_position(), tile_point(tile)])
	await route.frames(route.LAYOUT_FRAMES)

func click_tile(tile: Vector2i) -> void:
	await route.driver.click(tile_point(tile))

func cancel_mouse() -> void:
	await route.driver.click(tile_point(hero()), MOUSE_BUTTON_RIGHT)
	route.require(selected() < 0, "Mouse deselected the card")

func opening() -> void:
	for index: int in range(3):
		route.driver.motion(hand_point(index))
		if not await route.until(func() -> bool: return tooltip_owned(scene().call("_hand_card_control", index)), "Hand tooltip %d" % index): return
		route.witness("hand_tooltip " + str(route.hand()[index]))
		await route.hold()
	await route.still(1)

	var attack_index: int = route.hand().find(OPENING_ATTACK)
	for cycle: int in range(3):
		if not await select_mouse(attack_index): return
		if not route.require(not scene().get("_pending_target_tiles").is_empty(), "Selected attack has targets"): return
		await route.beat()
		await cancel_mouse()
		if route.failed: return
		await route.beat()
		route.witness("mouse_targeted_select_deselect %d" % (cycle + 1))

	if not await select_mouse(attack_index): return
	var targets: Array = scene().get("_pending_target_tiles")
	var target: Vector2i = targets[0]
	await aim(target)
	await route.hold()
	await click_tile(target)
	if not await wait_after_play(): return
	if not route.require(not route.hand().has(OPENING_ATTACK), "Targeted attack committed"): return
	route.witness("mouse_attack %s %s" % [OPENING_ATTACK, str(target)])

	var movement_index: int = -1
	for id: String in OPENING_MOVES:
		movement_index = route.hand().find(id)
		if movement_index >= 0: break
	if not await select_mouse(movement_index): return
	var movement_id: String = route.hand()[movement_index]
	var origin: Vector2i = hero()
	var move_tile: Vector2i = opening_move_target()
	await aim(move_tile)
	await route.beat()
	await click_tile(move_tile)
	if not await wait_after_play(): return
	if not route.require(hero() == move_tile and hero() != origin, "Movement card committed"): return
	route.witness("mouse_movement_card %s %s" % [movement_id, str(move_tile)])

	await hover_enemy_and_threat()
	if route.failed: return
	var turn: int = int(route.battle()["turn"])
	await pass_turn()
	if not route.require(route.mode() == "combat" and int(route.battle()["turn"]) > turn, "Pass advanced to the next player turn"): return
	route.witness("pass_enemy_phase turn=%d" % int(route.battle()["turn"]))
	await controller_play()

func opening_move_target() -> Vector2i:
	# Stay close enough to inspect an attack intent on the real board and
	# leave enough free movement to stop before the explicit Pass.
	var targets: Array = scene().get("_pending_target_tiles")
	var current: Vector2i = hero()
	for tile: Vector2i in targets:
		if tile.distance_squared_to(current) == 1: return tile
	return targets[0] if not targets.is_empty() else INVALID

func hover_enemy_and_threat() -> void:
	var state: Dictionary = route.battle()
	var engine = scene().get("_combat_engine")
	var enemy_hovered: bool = false
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["hp"]) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		await aim(enemy["pos"])
		if route.failed: return
		var shown: Dictionary = board().get("presentation")
		if not (shown.get("expanded_enemy_actor_keys", []) as Array).has("enemy_%d" % int(enemy["id"])): continue
		route.witness("enemy_hover " + str(enemy["type"]))
		await route.hold()
		enemy_hovered = true
		break
	if not route.require(enemy_hovered, "Enemy hover expanded a real intent"): return

	var threats: Array = board().get("presentation").get("threats_at_rest", {}).get("threats", [])
	for threat: Dictionary in threats:
		for red: Vector2i in threat.get("tiles", []):
			if bool(scene().call("_state_has_visible_enemy_at_tile", state, red)): continue
			route.driver.motion(tile_point(red))
			await route.frames(route.LAYOUT_FRAMES)
			if scene().get("_hovered_board_tile") != red: continue
			var red_keys: Array = preload("res://scripts/board_threat_isolation.gd").tile_keys(board(), red)
			if not red_keys.has(threat["key"]): continue
			route.witness("red_tile_hover " + str(red))
			await route.hold()
			return
	route.require(false, "Opening combat supplies a visible red threat tile: " + str(threats))

func controller_select(index: int) -> bool:
	if not bool(scene().call("_controller_is_active")) or scene().get("_controller_region") != "hand":
		await route.driver.joy(JOY_BUTTON_X)
		# The modality handoff may already have focused the hand when X lands.
		if scene().get("_controller_region") != "hand":
			await route.driver.joy(JOY_BUTTON_X)
	if not route.require(scene().get("_controller_region") == "hand" and bool(scene().call("_controller_is_active")), "Controller entered hand"): return false
	for _card: int in range(route.hand().size()):
		if int(scene().get("_controller_hand_index")) == index: break
		await route.driver.joy(JOY_BUTTON_RIGHT_SHOULDER)
	await route.driver.joy(JOY_BUTTON_A)
	return route.require(selected() == index and bool(scene().call("_controller_is_active")), "Controller selected hand card %d" % index)

func controller_play() -> void:
	var index: int = -1
	for id: String in ["pale_spark", "dull_bolt", "lantern_shot", "shadow_step", "brace"]:
		var slot: int = route.hand().find(id)
		if slot < 0: continue
		var options: Dictionary = scene().call("_card_play_options_for_index", slot)
		if bool(options.get("printed_playable", false)):
			index = slot
			break
	if not route.require(index >= 0, "Controller can play an opening card from %s" % str(route.hand())): return
	var id: String = route.hand()[index]
	if not await controller_select(index): return
	await route.beat()
	await route.driver.joy(JOY_BUTTON_B)
	if not route.require(selected() < 0, "Controller deselected the card"): return
	route.witness("controller_select_deselect " + id)
	await route.beat()
	if not await controller_select(index): return
	await route.hold()
	var target: Vector2i = scene().get("_controller_board_tile")
	var before: int = route.hand().count(id)
	await route.driver.joy(JOY_BUTTON_A)
	if not await wait_after_play(): return
	if not route.require(selected() < 0 and route.hand().count(id) < before, "Controller confirmed its focused target %s" % str(target)): return
	route.witness("controller_play " + id)
	await route.driver.click(route.POINTER_AWAY)
	if not route.require(not bool(scene().call("_controller_is_active")), "Pointer resumed after controller play"): return

func pass_turn() -> void:
	await route.click_named(scene(), "PassPreviewChip")
	await wait_after_play()

func wait_after_play() -> bool:
	if not await route.until(func() -> bool: return route.mode() != "combat" or route.combat_ready(), "Live combat finishes its animation"): return false
	await route.frames(route.LAYOUT_FRAMES)
	return true

func move_hero(tile: Vector2i) -> bool:
	if tile == hero(): return true
	var turn: int = int(route.battle()["turn"])
	await click_tile(hero())
	if not route.require((scene().get("_player_movement_target_tiles") as Array).has(tile), "Legal movement to %s from %s" % [str(tile), str(hero())]): return false
	await click_tile(tile)
	if not route.require(not bool(scene().get("_player_movement_selected")), "Live board committed movement to %s" % str(tile)): return false
	if not await wait_after_play(): return false
	# A move can spend the last resource, triggering an enemy phase whose
	# forced movement replaces the original landing before the hand returns.
	return route.require(route.mode() != "combat" or int(route.battle()["turn"]) != turn or hero() == tile, "Finished movement to %s" % str(tile))

func finish_fight(stop_at_turn: int = 0) -> void:
	for _action: int in range(MAX_ACTIONS):
		if route.failed or route.mode() != "combat": return
		var state: Dictionary = route.battle()
		if stop_at_turn > 0 and int(state["turn"]) >= stop_at_turn: return
		var decision: Dictionary = policy.choose(state)
		if decision.is_empty():
			var dodge: Dictionary = policy.best_dodge(state)
			var turn: int = int(state["turn"])
			if not await move_hero(dodge["state"]["player"]["pos"]): return
			if route.mode() != "combat": return
			if int(route.battle()["turn"]) == turn:
				await pass_turn()
		else:
			if not await play_decision(decision["commit"]): return
	route.require(false, "Combat policy exceeded its action budget")

func play_decision(decision: Dictionary) -> bool:
	var target_origin: Vector2i = decision["before"]["player"]["pos"]
	var index: int = int(decision["index"])
	var turn: int = int(route.battle()["turn"])
	if not await move_hero(target_origin): return false
	if route.mode() != "combat" or int(route.battle()["turn"]) != turn: return true
	if not await select_mouse(index): return false
	var targets: Array = decision["targets"]
	var preview: Dictionary = scene().call("_active_card_preview")
	var targeted_actions: Array = (decision["actions"] as Array).filter(policy.engine.player_action_needs_target)
	# A move-and-attack card commits a move-only play when the landing is
	# clicked. Hover that landing first, then click the enemy to select the
	# production approach shortcut for both actions.
	var first: int = 0
	if targets.size() >= 2 and targeted_actions.size() >= 2:
		var move: Vector2i = targets[0]
		var strike: Vector2i = targets[1]
		var move_kind: String = str(targeted_actions[0].get("type", ""))
		var strike_kind: String = str(targeted_actions[1].get("type", ""))
		if move_kind in ["move", "blink"] and strike_kind in ["melee", "ranged", "aoe", "push", "pull"] and strike.x >= 0:
			await aim(move if move.x >= 0 else hero())
			await aim(strike)
			if route.failed: return false
			var shortcut: Dictionary = scene().call("_shortcut_plan_for_tile", preview, strike)
			if not shortcut.is_empty():
				# Use the approach the UI can actually offer at this location.
				# The next policy choice reads the resulting board.
				await click_tile(strike)
				if not await wait_after_play(): return false
				first = 2
	for target: Vector2i in targets.slice(first):
		if selected() < 0 or route.mode() != "combat": break
		if target.x < 0:
			# The game may already omit an unavailable optional sub-action.
			continue
		if not route.require((scene().get("_pending_target_tiles") as Array).has(target), "Policy target %s is exposed by the live card %s" % [str(target), str(route.hand()[index])]): return false
		await click_tile(target)
		if not await wait_after_play(): return false
	if route.mode() == "combat" and bool(scene().call("_pending_card_requires_confirmation")):
		await click_tile(hero())
		if not await wait_after_play(): return false
	return route.require(selected() < 0, "Policy card finished resolving")
