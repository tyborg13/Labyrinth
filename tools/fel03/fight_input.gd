extends RefCounted
## Choose from normal card previews, then submit the normal board and hand inputs.

const Attack = preload("res://scripts/attack_fx_library.gd")
const INVALID := Vector2i(-1, -1)


static func melee_plan(scene: Node) -> Dictionary:
	var state: Dictionary = scene._combat_state
	var engine: RefCounted = scene._combat_engine
	var hand: Array = state["deck"]["hand"]
	var adjacent: Dictionary = _adjacent_enemies(engine, state)
	# Exhaust the hand for adjacent targets before considering ordinary movement.
	for index: int in hand.size():
		if not scene._guided_tutorial_card_allowed(index): continue
		var plan: Dictionary = _melee_plan_for(scene, index, _live_preview(scene, index), adjacent)
		if not plan.is_empty(): return plan
	var moves: Array[Vector2i] = engine.player_movement_targets(state)
	var projected_moves: Dictionary
	for tile: Vector2i in moves:
		var projected: Dictionary = engine.apply_player_movement(state, tile)
		if projected["player"]["pos"] == tile and engine.combat_outcome(projected).is_empty() and not _adjacent_enemies(engine, projected).is_empty():
			projected_moves[tile] = projected
	for index: int in hand.size():
		if not scene._guided_tutorial_card_allowed(index): continue
		if not _has_melee(scene._card_def(hand[index], state).get("actions", [])): continue
		for tile: Vector2i in projected_moves:
			var projected: Dictionary = projected_moves[tile]
			var projected_hand: Array = projected["deck"]["hand"]
			if index >= projected_hand.size() or projected_hand[index] != hand[index] or not engine.hand_card_has_play_budget(projected, index):
				continue
			var prepared: Dictionary = engine.prepare_player_card(projected, index, "play")
			var actions: Array = engine.card_play_actions(hand[index], prepared)
			var preview: Dictionary = scene._card_preview_from_state(hand[index], prepared, actions, 0)
			var plan: Dictionary = _melee_plan_for(scene, index, preview, _adjacent_enemies(engine, projected))
			if not plan.is_empty():
				plan["move"] = tile
				return plan
	return {}


static func _live_preview(scene: Node, index: int) -> Dictionary:
	return scene._card_play_options_for_index(index).get("play", {})


static func _has_melee(actions: Array) -> bool:
	return actions.any(func(action: Dictionary) -> bool: return Attack.protagonist_uses_melee_motion(action))


static func _adjacent_enemies(engine: RefCounted, state: Dictionary) -> Dictionary:
	var tiles: Dictionary
	var from: Vector2i = state["player"]["pos"]
	for enemy: Dictionary in state["enemies"]:
		if int(enemy["hp"]) <= 0 or not engine.is_enemy_visible_to_player(state, enemy): continue
		for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
			var delta: Vector2i = tile - from
			if absi(delta.x) + absi(delta.y) == 1:
				tiles[tile] = true
	return tiles


static func _melee_plan_for(scene: Node, index: int, preview: Dictionary, adjacent: Dictionary) -> Dictionary:
	if adjacent.is_empty() or not preview.get("playable", false) or not _has_melee(preview.get("actions", [])):
		return {}
	var action: Dictionary = preview.get("action", {})
	if preview.get("complete", false):
		# A targetless melee sweep must actually cover an adjacent enemy.
		for strike: Dictionary in preview["actions"]:
			if strike.get("type") != "aoe" or not Attack.protagonist_uses_melee_motion(strike): continue
			var state: Dictionary = preview["state"]
			for tile: Vector2i in scene._aoe_tiles_for_action(state, strike, state["player"]["pos"]):
				if adjacent.has(tile): return {"index": index, "target": INVALID, "sweep": true}
	elif Attack.protagonist_uses_melee_motion(action):
		for tile: Vector2i in preview.get("target_tiles", []):
			if adjacent.has(tile): return {"index": index, "target": tile}
	elif action.get("type") in ["move", "blink"]:
		for tile: Vector2i in adjacent:
			var shortcut: Dictionary = scene._shortcut_plan_for_tile(preview, tile)
			if not shortcut.is_empty() and Attack.protagonist_uses_melee_motion(shortcut["action"]):
				return {"index": index, "target": tile}
	return {}


static func block_plan(scene: Node) -> Dictionary:
	var state: Dictionary = scene._combat_state
	var hand: Array = state["deck"]["hand"]
	for index: int in hand.size():
		if not scene._guided_tutorial_card_allowed(index): continue
		var preview: Dictionary = _live_preview(scene, index)
		if not preview.get("playable", false): continue
		var actions: Array = preview["actions"]
		if not actions.any(func(action: Dictionary) -> bool: return action.get("type") == "block"): continue
		if preview.get("complete", false): return {"index": index, "target": INVALID}
		# Guarded Step can use the production Stay target when it is offered.
		var targets: Array = preview["target_tiles"]
		var from: Vector2i = state["player"]["pos"]
		if targets.has(from): return {"index": index, "target": from}
		if not targets.is_empty(): return {"index": index, "target": targets.front()}
	return {}


static func move(scene: Node, tile: Vector2i) -> bool:
	await scene._on_board_tile_clicked(scene._combat_state["player"]["pos"])
	if not scene._player_movement_target_tiles.has(tile): return false
	await scene._on_board_tile_clicked(tile)
	return scene._combat_state["player"]["pos"] == tile


static func play(scene: Node, plan: Dictionary) -> bool:
	var index: int = plan["index"]
	var previous_state: Dictionary = scene._combat_state
	await scene._on_card_pressed(index)
	if scene._selected_card_index == index and plan["target"] != INVALID:
		await scene._on_board_tile_clicked(plan["target"])
	if scene._pending_card_requires_confirmation():
		await scene._on_confirm_card_play_pressed()
	return scene._selected_card_index < 0 and not is_same(previous_state, scene._combat_state)
