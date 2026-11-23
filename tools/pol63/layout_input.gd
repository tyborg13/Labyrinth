extends "res://tools/scn01/census_input.gd"
## Exercise the production pointer, number shortcut, and joypad routes.

const SAMPLE_FRAMES: int = 24

var _idle: Dictionary
var _failure: String = ""


func exercise() -> String:
	_viewport.notify_mouse_entered()
	var hand: Array = _screen.get("_combat_state")["deck"]["hand"].duplicate()
	_idle = _stack()
	await _sample("idle")
	for index: int in range(hand.size()):
		_card_index = index
		if not await _wait(_point_at_hand_card):
			return "Pointer did not reach %s." % hand[index]
		await _sample("pointer_hover:" + str(hand[index]))
	var plain: bool = _shot["scenario"] == "combat"
	var entry_proof: bool = _shot.has("entry")
	if plain or entry_proof:
		_shot["card"] = "quick_stab" if plain else "chain_bolt"
		_state = "keyword"
		var error: String = await _hand_state()
		if not error.is_empty(): return error
		if not await _wait(matches): return "Keyword popup did not open for %s." % _shot["card"]
		await _sample("keyword_popup")
	await _move(Vector2(2, 2))
	if not await _wait(func() -> bool: return _screen.get("_hovered_card_index") == -1):
		return "Pointer hover did not clear."
	await _sample("unhover")
	if plain or entry_proof:
		var aim_card: String = "pale_spark" if plain else "shadow_step"
		_card_index = hand.find(aim_card)
		if not await _wait(_point_at_hand_card): return "%s pointer click position unavailable." % aim_card
		await _click_pointer()
		if _screen.get("_selected_card_index") != _card_index: return "Pointer did not select %s." % aim_card
		await _sample("pointer_selected")
		await _key(KEY_ESCAPE)
		var error: String = await _aim_with_number(aim_card, plain)
		if not error.is_empty(): return error
		await _sample("number_key_aim")
		await _key(KEY_ESCAPE)
		await _move(Vector2(2, 2))
	await _joy(JOY_BUTTON_RIGHT_SHOULDER)
	if not await _wait(func() -> bool: return _screen.call("_controller_is_active") and _screen.get("_hovered_card_index") >= 0):
		return "Controller shoulder did not focus a card."
	await _sample("controller_focus")
	if plain or entry_proof:
		if not plain:
			# The Ashen Reaver's opening distance leaves Chain Bolt out of
			# range. Focus the same targeted card the keyboard check used.
			var target_index: int = hand.find("shadow_step")
			for index: int in range(hand.size()):
				if _screen.get("_controller_hand_index") == target_index: break
				await _joy(JOY_BUTTON_RIGHT_SHOULDER)
			if _screen.get("_controller_hand_index") != target_index:
				return "Controller could not focus Shadow Step."
		await _joy(JOY_BUTTON_A)
		if _screen.get("_selected_card_index") < 0: return "Controller did not select the focused card."
		await _sample("controller_selected")
		await _joy(JOY_BUTTON_B)
	var combat: Dictionary = _screen.get("_combat_state")
	var turn: int = combat["turn"]
	_state = "enemy_turn"
	await _key(KEY_P)
	if not await _wait(matches): return "No enemy activation presented after Pass."
	_log("enemy_turn", _stack(), true)
	if not await _wait(func() -> bool:
		return not _screen.get("_animation_lock") and int(_screen.get("_combat_state").get("turn", 0)) > turn
	):
		return "No player turn after the resolved enemy turn."
	await _sample("after_enemy_turn")
	return _failure


func _aim_with_number(card_id: String, at_enemy: bool) -> String:
	_shot["card"] = card_id
	_state = "aim"
	if at_enemy:
		return await _hand_state()
	await _key((KEY_1 + _card_index) as Key)
	var targets: Array = _screen.get("_pending_target_tiles")
	if _screen.get("_selected_card_index") != _card_index or targets.is_empty():
		return "Number shortcut did not reach targeting for %s." % card_id
	_enemy_tile = targets.front()
	var board: Control = _screen.get("board_view")
	var target: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", _enemy_tile)
	await _move(target)
	if not await _wait(func() -> bool: return _screen.get("_hovered_board_tile") == _enemy_tile):
		return "Keyboard-selected %s did not aim at its legal tile." % card_id
	return ""


func reveal_waypoint() -> String:
	if _screen.get("_dialogue_active"):
		await _key(KEY_ESCAPE)
	if _visible(_screen.get("_large_map_scrim")):
		await _key(KEY_M)
	if await _wait(func() -> bool:
		return not _screen.get("_dialogue_active") and not _visible(_screen.get("_large_map_scrim"))
	):
		return ""
	return "Waypoint dialogue or map remained open after dismissal."


func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)
		await _tree.process_frame


func _click_pointer() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = _pointer
		event.global_position = _pointer
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await _tree.process_frame


func _stack() -> Dictionary:
	var stack: Dictionary = {}
	var fields: Dictionary = {
		"objective": "_combat_objective_hud", "rule": "_battlefield_rule_hud",
		"plays": "_play_meter", "movement": "_movement_meter",
	}
	for key: String in fields:
		var item: Control = _screen.get(fields[key])
		stack[key] = _rect_values(_rect(item)) if _visible(item) else []
	return stack


func _sample(phase: String) -> void:
	var stable: bool = true
	for index: int in range(SAMPLE_FRAMES):
		stable = stable and same_stack(_stack(), _idle)
		await _tree.process_frame
	var stack: Dictionary = _stack()
	_log(phase, stack, stable and same_stack(stack, _idle))


func _log(phase: String, stack: Dictionary, stable: bool) -> void:
	var scroll: Control = _screen.get("hand_scroll")
	var home: Rect2 = _screen.get("_combat_objective_dock_home")
	var dock: RefCounted = _screen.get("_combat_hud_layout")
	var hand: Rect2 = dock.get("_held_bounds")
	var board: Rect2 = _screen.call("_combat_objective_board_bounds")
	var row: Dictionary = {
		"case": _shot["shot"], "seed": _screen.get("_run_state")["seed"],
		"frame": Engine.get_process_frames(), "phase": phase, "stack": stack,
		"scroll": _rect_values(_rect(scroll)), "held_hand": _rect_values(hand),
		"home": _rect_values(home), "board": _rect_values(board),
		"dock_placed": dock.get("_placed"), "matches_idle": stable and same_stack(stack, _idle),
	}
	print("POL63_LAYOUT ", JSON.stringify(row))
	if _shot.get("check_fit") and not row["matches_idle"] and _failure.is_empty():
		_failure = "The objective stack moved during %s." % phase


func _rect_values(rect: Rect2) -> Array:
	return [rect.position.x, rect.position.y, rect.size.x, rect.size.y]


func enter_door(destination: Vector2i) -> String:
	await _tree.process_frame
	await _tree.process_frame
	_viewport.notify_mouse_entered()
	var error: String = await reveal_waypoint()
	if not error.is_empty(): return error
	if not await _wait(_ready_for_input): return "Incoming room did not become interactive."
	if not await _wait(func() -> bool:
		var centering: Tween = _screen.get("_board_centering_tween")
		return centering == null or not centering.is_running()
	):
		return "Incoming room did not finish board centering."
	var door: Vector2i = _screen.call("_door_tile_for_destination", destination)
	if door.x < 0: return "Incoming room has no playable door to %s." % destination
	var board: Control = _screen.get("board_view")
	var point: Vector2 = board.get_global_transform_with_canvas() * board.call("world_position_for_tile", door)
	await _move(point)
	var hovered: Control = _viewport.gui_get_hovered_control()
	var tile: Vector2i = board.call("tile_at_global_position", point)
	await _click_pointer()
	var start: Control
	if not await _wait(func() -> bool: return _visible(_find(_screen, "PreBattleStartButton"))):
		return "Door %s at %s (board tile %s, pointer owner %s) left the game in %s with lock %s." % [
			door, point, tile, hovered.name if is_instance_valid(hovered) else "none",
			_screen.get("_run_state").get("mode"), _screen.get("_animation_lock"),
		]
	start = _find(_screen, "PreBattleStartButton")
	if not await _click(start):
		return "Could not press the pre-battle Start button."
	return ""


func wait_for_idle() -> bool:
	return await _wait(func() -> bool:
		if _screen.get("_run_state").get("mode") != "combat" or not _ready_for_input():
			return false
		var hud: Control = _screen.get("_combat_objective_hud")
		return _visible(hud) and not hud.get("intro_active") and bool(hud.visibility_layer & _viewport.canvas_cull_mask)
	)


func play_first_card() -> Dictionary:
	_viewport.notify_mouse_entered()
	var combat: Dictionary = _screen.get("_combat_state")
	var hand: Array = combat["deck"]["hand"]
	var card_id: String = hand.front()
	var before: int = combat["cards_played_this_turn"]
	var error: String = await _aim_with_number(card_id, true)
	if not error.is_empty(): return {"error": error}
	if _card_index != 0: return {"error": "The probe did not select the first card."}
	await _click_pointer()
	if not await _wait(func() -> bool:
		return int(_screen.get("_combat_state").get("cards_played_this_turn", 0)) > before
	):
		return {"error": "The first card did not spend a Card Play."}
	if not await wait_for_idle(): return {"error": "The first card did not finish resolving."}
	var after: Dictionary = _screen.get("_combat_state")
	if card_id in after["deck"]["hand"]: return {"error": "The first card stayed in hand after the play."}
	return {
		"card": card_id, "target": [_enemy_tile.x, _enemy_tile.y],
		"plays_before": before, "plays_after": after["cards_played_this_turn"],
		"removed_from_hand": true,
	}


func painted_stack() -> Dictionary:
	var result: Dictionary = _stack()
	var hud: Control = _screen.get("_combat_objective_hud")
	if hud.self_modulate.a * hud.modulate.a <= 0.0 or hud.get("intro_active"):
		result["objective"] = []
	# During its authored travel the intro plate is independent of the dock.
	for entry: Array in [["objective", "_combat_objective_hud"], ["rule", "_battlefield_rule_hud"],
			["plays", "_play_meter"], ["movement", "_movement_meter"]]:
		var chip: Control = _screen.get(entry[1])
		if chip.modulate.a <= 0.0 or not (chip.visibility_layer & _viewport.canvas_cull_mask):
			result[entry[0]] = []
	return result


static func same_stack(a: Dictionary, b: Dictionary) -> bool:
	for key: String in a:
		if not same_rect(a[key], b[key]): return false
	return true


static func same_rect(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for index: int in range(a.size()):
		if not is_equal_approx(a[index], b[index]): return false
	return true
