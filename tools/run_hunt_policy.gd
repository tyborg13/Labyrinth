extends RefCounted
## Read-only offer enumeration; all mutations enter the scene's input paths.
const ATTACK_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull", "detonate", "meteor_marks"]
const ATTACK_PREFERENCE: float = 0.8
const CardWidget = preload("res://scripts/card_widget.gd")
const BROWSE_DECISION_LIMIT: int = 8
const TERMINAL_METHODS: Array = ["_on_campfire_embrace_pressed", "_on_abandon_run_pressed", "_on_save_and_quit_pressed", "_on_exit_to_desktop_pressed", "_on_return_to_menu_pressed"]
var no_embrace: bool = false
var browse_key: String = ""
var browse_decisions: int = 0
var rng: RandomNumberGenerator

func offers(scene: Node) -> Array:
	var browsing: Dictionary = _browse(scene)
	var key: String = str(browsing.get("key", ""))
	if browse_key != key:
		browse_key = key
		browse_decisions = 0
	if not key.is_empty() and browse_decisions >= BROWSE_DECISION_LIMIT:
		return [{"kind":"leave_browse", "method":browsing["close"]}]
	var flow: RefCounted = scene.get("_opening_boon_flow")
	if flow.active(): return _controls(flow.overlay)
	for field: String in ["_settings_panel", "_magic_purge_overlay", "_skill_choice_scrim", "_upgrade_scrim", "_pile_scrim", "_grimoire_scrim", "_menu_scrim"]:
		var modal: Variant = scene.get(field)
		if _visible(modal): return _controls(modal)
	if bool(scene.get("_dialogue_active")):
		var choices: Array = _controls(scene.get("_dialogue_choice_bar"))
		if not choices.is_empty(): return choices
		return [{"kind": "dialogue", "method": "_on_dialogue_overlay_gui_input", "args": [_click()]}]
	var tutorial: Variant = scene.get("_contextual_combat_prompt")
	if _visible(tutorial):
		var prompt_choices: Array = _controls(tutorial)
		if not prompt_choices.is_empty(): return prompt_choices
	var run: Dictionary = scene.get("_run_state")
	var mode: String = str(run.get("mode", ""))
	if _visible(scene.get("_large_map_scrim")):
		var destinations: Array = []
		for tile: Vector2i in scene.get("_large_map_view").available_destinations():
			if not scene.get("_run_engine").available_moves(run).has(tile): continue
			destinations.append({"kind": "map_room", "method": "_on_large_map_room_selected", "args": [tile]})
		if not destinations.is_empty(): return destinations
		return _controls(scene.get("_large_map_scrim"))
	if mode == "combat": return _combat(scene)
	if mode == "event":
		var event_view: Node = scene.get("_event_view")
		if event_view != null and (bool(event_view.get("_busy")) or bool(event_view.get("_request_pending")) or bool(event_view.get("_closing"))): return []
		return _controls(event_view)
	if mode == "graftwright": return _controls(scene.get("_graftwright_view"))
	if mode == "pre_battle":
		var result: Array = [{"kind": "begin_combat", "method": "_on_pre_battle_start_pressed"}, {"kind": "equipment", "method": "_on_pre_battle_equip_pressed"}]
		return result
	if mode in ["reward", "treasure", "campfire"]:
		var choices: Array = _controls(scene.get("_relic_choice_bar"))
		choices.append_array(_controls(scene.get("_choice_button_overlay")))
		choices.append_array(_controls(scene.get("choice_bar")))
		return choices
	if mode == "room":
		if not str(scene.call("_current_room_merchant_kind")).is_empty() and bool(scene.get("_merchant_shop_open")):
			return _controls(scene.get("_scavenger_shop_view"))
		var result: Array = []
		for tile: Vector2i in scene.get("_run_engine").available_moves(run):
			result.append({"kind": "map_room", "method": "_on_map_view_room_selected", "args": [tile]})
		# Equipment is offered by the header throughout rooms.
		result.append({"kind": "equipment", "method": "_on_loadout_button_pressed"})
		result.append_array(_controls(scene.get("_context_choice_bar")))
		return result
	return []

func _combat(scene: Node) -> Array:
	var result: Array = []
	var state: Dictionary = scene.get("_combat_state")
	var engine: RefCounted = scene.get("_combat_engine")
	if not engine.is_player_turn(state): return result
	if bool(scene.call("_orientation_pending")):
		for tile: Vector2i in scene.call("_direction_choice_tiles", scene.get("_pending_orientation_target_tile")):
			result.append(_tile(tile, "orientation"))
		return result
	if bool(scene.get("_player_movement_selected")):
		for tile: Vector2i in scene.get("_player_movement_target_tiles"):
			result.append(_tile(tile, "move", _toward_enemy(state, tile)))
		return result
	if int(scene.get("_selected_card_index")) >= 0:
		if bool(scene.call("_pending_card_requires_confirmation")):
			return [{"kind": "confirm_card", "method": "_on_confirm_card_play_pressed", "preferred": true}]
		var preview: Dictionary = scene.call("_active_card_preview")
		var action: Dictionary = preview.get("action", {})
		var action_type: String = str(action.get("type", ""))
		var preview_state: Dictionary = scene.get("_preview_combat_state")
		for tile: Vector2i in scene.get("_pending_target_tiles"):
			var preferred: bool = ATTACK_TYPES.has(action_type) and _hits_enemy(engine, preview_state, action, tile)
			if action_type in ["move", "blink"]: preferred = _toward_enemy(preview_state, tile)
			result.append(_tile(tile, action_type, preferred))
		if result.is_empty() and not bool(scene.get("_pending_umbra_commit_locked")):
			result.append({"kind": "cancel_card", "method": "_on_board_cancel_requested"})
		return result
	var hand: Array = state.get("deck", {}).get("hand", [])
	for index: int in range(hand.size()):
		var options: Dictionary = scene.call("_card_play_options_for_index", index)
		if not bool(options.get("printed_playable", false)): continue
		var preferred: bool = false
		for action: Dictionary in options.get("play", {}).get("actions", []):
			if ATTACK_TYPES.has(str(action.get("type", ""))): preferred = true
		# Some previews expose only their current action.
		if ATTACK_TYPES.has(str(options.get("play", {}).get("action", {}).get("type", ""))): preferred = true
		result.append({"kind": "card", "method": "_on_card_pressed", "args": [index], "card_id": str(hand[index]), "preferred": preferred})
	var moves: Array = engine.player_movement_targets(state)
	for tile: Vector2i in moves:
		result.append({"kind": "move", "tile": tile, "preferred": _toward_enemy(state, tile)})
	result.append({"kind": "pass", "method": "_on_pass_turn_pressed"})
	return result

func _hits_enemy(engine: RefCounted, state: Dictionary, action: Dictionary, tile: Vector2i) -> bool:
	var affected: Array = [tile]
	if str(action.get("type", "")) in ["aoe", "meteor_marks"]:
		affected = engine.aoe_tiles_for_player_action(state, action, tile)
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		for occupied: Vector2i in engine._enemy_footprint_tiles(enemy):
			if affected.has(occupied): return true
	return false

func _toward_enemy(state: Dictionary, tile: Vector2i) -> bool:
	var origin: Vector2i = state.get("player", {}).get("pos", Vector2i(-1, -1))
	var before: int = 100000
	var after: int = 100000
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		var pos: Vector2i = enemy.get("pos", origin)
		before = mini(before, absi(origin.x - pos.x) + absi(origin.y - pos.y))
		after = mini(after, absi(tile.x - pos.x) + absi(tile.y - pos.y))
	return after < before

func _tile(tile: Vector2i, kind: String, preferred: bool = false) -> Dictionary:
	return {"kind": kind, "method": "_on_board_tile_clicked", "args": [tile], "preferred": preferred}

func choose(scene: Node, candidates: Array) -> Dictionary:
	var preferred: Array = []
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat" and rng.randf() < ATTACK_PREFERENCE:
		for candidate: Dictionary in candidates:
			if bool(candidate.get("preferred", false)): preferred.append(candidate)
	var pool: Array = preferred if not preferred.is_empty() else candidates
	return pool[rng.randi_range(0, pool.size() - 1)]

func dispatch(scene: Node, action: Dictionary) -> void:
	if not browse_key.is_empty(): browse_decisions += 1
	if action.has("control"):
		var control: Control = action["control"]
		match str(action.get("signal", "")):
			"pressed": control.emit_signal("pressed")
			"activated": control.emit_signal("activated")
			"gui_input": control.emit_signal("gui_input", _click())
	elif action.has("method"):
		scene.callv(str(action["method"]), action.get("args", []))
	elif str(action.get("kind", "")) == "move":
		# Select the player, then use the same board click path as a player.
		scene.call("_on_board_tile_clicked", (scene.get("_combat_state") as Dictionary).get("player", {}).get("pos"))
		if bool(scene.get("_player_movement_selected")): scene.call("_on_board_tile_clicked", action["tile"])

func _controls(host: Variant) -> Array:
	var result: Array = []
	if not is_instance_valid(host): return result
	_collect(host, result)
	return result

func _collect(node: Node, result: Array) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is BaseButton:
		if node.has_meta("event_label") and not bool(node.get("available")): return
		if not node.disabled and not node.get_signal_connection_list("pressed").is_empty():
			if no_embrace and _terminal_control(node): return
			result.append({"kind": "ui", "control": node, "signal": "pressed", "path": str(node.get_path()), "text": str(node.text) if node is Button else ""})
		return
	if node is Control:
		if no_embrace and _terminal_control(node): return
		if node is CardWidget and not bool(node.get("_interactive")): return
		if node.has_signal("activated") and not node.get_signal_connection_list("activated").is_empty():
			result.append({"kind": "ui", "control": node, "signal": "activated", "path": str(node.get_path())})
			return
		for connection: Dictionary in node.get_signal_connection_list("gui_input"):
			var method: String = str((connection["callable"] as Callable).get_method())
			if method in ["_on_campfire_choice_gui_input", "_on_relic_choice_gui_input"]:
				if node.has_meta("choice_revealed") and not bool(node.get_meta("choice_revealed")): return
				if node.has_meta("choice_enabled") and not bool(node.get_meta("choice_enabled")): return
				result.append({"kind": "ui", "control": node, "signal": "gui_input", "path": str(node.get_path()), "handler": method})
				return
	for child: Node in node.get_children(): _collect(child, result)

func _visible(value: Variant) -> bool:
	return is_instance_valid(value) and value is Control and value.is_visible_in_tree()

func _click() -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	return event

func side_actions_available(scene: Node) -> bool:
	if bool(scene.get("_dialogue_active")) or int(scene.get("_selected_card_index")) >= 0 or bool(scene.get("_player_movement_selected")) or scene.get("_opening_boon_flow").active(): return false
	if str((scene.get("_run_state") as Dictionary).get("mode", "")) in ["victory", "defeat", "embrace"]: return false
	for field: String in ["_magic_purge_overlay", "_skill_choice_scrim", "_upgrade_scrim", "_pile_scrim", "_grimoire_scrim", "_menu_scrim"]:
		if _visible(scene.get(field)): return false
	if bool(scene.call("_treasure_presentation_busy")): return false
	return true

func side_available(scene: Node, kind: String) -> bool:
	match kind:
		"hover_hand", "deck": return str((scene.get("_run_state") as Dictionary).get("mode", "")) == "combat"
		"map": return str((scene.get("_run_state") as Dictionary).get("mode", "")) != "event"
		"heirloom": return false # This view is offered only by the terminal boon flow.
		_: return true

func side_action(scene: Node, kind: String) -> void:
	match kind:
		"hover_hand":
			for index: int in range((scene.get("_combat_state") as Dictionary).get("deck", {}).get("hand", []).size()):
				scene.call("_on_card_hover_started", index)
				await scene.get_tree().process_frame
				scene.call("_on_card_hover_ended", index)
		"deck":
			scene.call("_on_pile_gui_input", _click(), "draw")
			await scene.get_tree().process_frame
			scene.call("_close_pile_view")
		"map":
			scene.call("_open_large_map", true)
			await scene.get_tree().process_frame
			scene.call("_close_large_map")
		"settings":
			scene.call("_on_menu_button_pressed")
			scene.call("_open_settings_overlay")
			await scene.get_tree().process_frame
			scene.call("_close_settings_overlay")
			scene.call("_close_menu_overlay")
		"escape":
			var event := InputEventKey.new()
			event.keycode = KEY_ESCAPE
			event.pressed = true
			scene.call("_input", event)
			await scene.get_tree().process_frame
			if _visible(scene.get("_menu_scrim")): scene.call("_close_menu_overlay")
		"reduced_motion":
			scene.call("_on_menu_button_pressed")
			scene.call("_open_settings_overlay")
			var panel: Node = scene.get("_settings_panel")
			var button: Button = (panel.get("_controls") as Dictionary)["reduced_motion"]
			button.button_pressed = not button.button_pressed
			await scene.get_tree().process_frame
			scene.call("_close_settings_overlay")
			scene.call("_close_menu_overlay")
	await scene.get_tree().process_frame

# Browse budgets use modal identity, not node IDs: refreshes can rebuild a tree
# after every skill selection. Exit through the same handlers as its Close UI.
func _browse(scene: Node) -> Dictionary:
	for entry: Array in [["_settings_panel","_close_settings_overlay"],["_pile_scrim","_close_pile_view"],["_grimoire_scrim","_close_grimoire_overlay"],["_upgrade_scrim","_on_progression_overlay_close_pressed"],["_menu_scrim","_close_menu_overlay"],["_magic_purge_overlay","_close_magic_purge"]]:
		if _visible(scene.get(entry[0])): return {"key":entry[0],"close":entry[1]}
	var mode: String = str((scene.get("_run_state") as Dictionary).get("mode", ""))
	if mode == "graftwright": return {"key":"graftwright","close":"_on_graftwright_leave"}
	if mode == "room" and bool(scene.get("_merchant_shop_open")) and not str(scene.call("_current_room_merchant_kind")).is_empty(): return {"key":"merchant","close":"_on_merchant_hide_pressed"}
	return {}

func browsing(scene: Node) -> bool:
	return not _browse(scene).is_empty()

func _terminal_control(node: Control) -> bool:
	if str(node.get_meta("choice_id", "")) == "embrace": return true
	for signal_name: String in ["pressed","activated","gui_input"]:
		if not node.has_signal(signal_name): continue
		for connection: Dictionary in node.get_signal_connection_list(signal_name):
			var callback: Callable = connection["callable"]
			if str(callback.get_method()) in TERMINAL_METHODS: return true
	return false
