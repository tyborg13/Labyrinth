extends RefCounted
## Additional census paths through production input, with a state check at capture.

const DIALOGUE_ADVANCE_LIMIT: int = 24
const LOADING_COVER_DELAY_FRAMES: int = 600

var _input_ref: WeakRef
var _target: Control
var _room: Vector2i
var _tile: Vector2i
var _transition: CanvasLayer
var _loading_cover_held: bool


func _init(input: RefCounted) -> void:
	_input_ref = weakref(input)


func reach(state: String) -> String:
	var input: RefCounted = _input_ref.get_ref()
	var screen: Control = input._screen
	match state:
		"title", "replacement", "depth", "loading", "opening", "first_room", "chronicle":
			return await _menu_path(input, state)
		"enemy_hover":
			var board: Control = screen.get("board_view")
			for enemy: Dictionary in screen.get("_combat_state").get("enemies", []):
				_tile = enemy["pos"]
				var point: Vector2 = board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", _tile) as Vector2)
				await input._move(point)
				if matches(state): return ""
			return "No visible enemy tile accepted pointer hover."
		"rail_hover":
			for slot: Control in screen.get("_turn_order_bar").get_children():
				if input._visible(slot) and slot.get_meta("turn_order_team", "") == "enemy":
					_target = slot
					await input._move(input._rect(slot).get_center())
					if matches(state): return ""
			return "No enemy turn-order chip accepted pointer hover."
		"pass_hover":
			_target = input._find(screen, "PassPreviewChip")
			if _target == null: return "Pass chip was unavailable."
			await input._move(input._rect(_target).get_center())
		"details":
			if not await input._click(screen.get("_enemy_intent_toggle_button")): return "Details control was unavailable."
		"map_unvisited", "map_visited":
			return await _map_path(input, state == "map_visited")
		"sell_hover":
			var shop: Control = screen.get("_scavenger_shop_view")
			if not await input._wait(func() -> bool: return input._visible(shop)):
				return "Scavenger shop was unavailable."
			if not await input._click(input._find(shop, "ScavengerSellMode")):
				return "Scavenger sell tab was unavailable."
			return await _hover_marked(input, input._find(shop, "SellInventoryRow"), &"shop_pointer_hovered", state)
		"graft_confirm":
			var view: Control = screen.get("_graftwright_view")
			for name: String in ["GraftBrowse", "ChooseSacrifice", "Pick_patched_cloak", "ChooseRecipient", "Pick_undertaker_plate", "SourceCard_1", "TargetCard_1"]:
				if not await input._wait(func() -> bool: return input._visible(input._find(view, name))):
					return "Graft path did not expose %s." % name
				if not await input._click(input._find(view, name)): return "Graft path could not click %s." % name
		"gear_hover":
			return await _hover_marked(input, input._find(screen.get("_upgrade_scrim"), "ItemInventoryRows"), &"character_hovered", state)
		"withdraw":
			var choices: Control = screen.get("_relic_choice_bar")
			for choice: Control in choices.get_children():
				if choice.get_meta("choice_id", "") != "embrace": continue
				if not await input._wait(func() -> bool: return input._visible(choice) and bool(choice.get_meta("choice_revealed", false))):
					return "Ember Hearth did not reveal the withdrawal choice."
				if not await input._click(choice): return "Ember Hearth withdrawal choice was unavailable."
				return ""
			return "Ember Hearth had no withdrawal choice."
		"full_health", "guardian_prize", "dragon_prize":
			pass
		_:
			return "Unknown census state %s." % state
	return ""


func matches(state: String) -> bool:
	var input: RefCounted = _input_ref.get_ref()
	var screen: Control = input._screen
	match state:
		"title":
			return input._visible(screen.get("start_button")) and not bool(screen.get("_loading_run"))
		"replacement":
			return bool(screen.get("_replacement_confirmation_open")) and input._visible(screen.get("replacement_confirm_button"))
		"depth":
			return input._visible(screen.get("_new_descent_panel"))
		"loading":
			return is_instance_valid(_transition) and _transition.phase == &"loading" and input._visible(_transition.message_label)
		"opening", "first_room":
			if not screen.has_method("has_installed_run") or not screen.call("has_installed_run"): return false
			var run: Dictionary = screen.get("_run_state")
			if run.get("mode") != "room" or run.get("current_room") != Vector2i.ZERO: return false
			var dialogue_active: bool = screen.get("_dialogue_active")
			if state == "first_room": return not dialogue_active and screen.call("initial_presentation_is_ready")
			return dialogue_active and bool(screen.get("_dialogue_text_complete")) and int(screen.get("_dialogue_line_index")) == int(input._shot.get("dialogue_line", 0))
		"chronicle":
			return input._visible(screen.get("_chronicle")) and input._visible(input._find(screen, "DescentRow0"))
		"enemy_hover":
			return screen.get("_hovered_board_tile") == _tile and screen.call("_hovered_tile_has_visible_enemy", _tile)
		"rail_hover":
			return is_instance_valid(_target) and input._visible(_target) and not str(screen.get("_turn_order_hovered_enemy_key")).is_empty() and _target.get_meta("rd05_actor_key", "") == screen.get("_turn_order_hovered_enemy_key")
		"pass_hover":
			return input._visible(_target) and bool(_target.get_meta("pass_forecast_active", false)) and input._visible(input._find(_target, "ForecastRows"))
		"details":
			return input._visible(screen.get("_enemy_intent_toggle_button")) and bool(screen.get("_show_all_enemy_intents"))
		"push":
			var board: Control = screen.get("board_view")
			var forecast: Dictionary = board.get("presentation")
			return input.aim_matches() and not (forecast.get("collision_markers", []) as Array).is_empty() and not (forecast.get("damage_preview", {}) as Dictionary).is_empty()
		"map_visited", "map_unvisited":
			var map: Control = screen.get("_large_map_view")
			return input._visible(map) and map.get("selected_coord") == _room and input._visible(map.get("_preview"))
		"sell_hover":
			return bool(screen.get("_scavenger_shop_view").get("_pack_mode")) and input._visible(_target) and bool(_target.get_meta("shop_pointer_hovered", false))
		"graft_confirm":
			var view: Control = screen.get("_graftwright_view")
			var commit: Button = input._find(view, "GraftCommit")
			return input._visible(view) and input._visible(commit) and not commit.disabled and bool(view.call("semantic_snapshot").get("can_commit"))
		"gear_hover":
			return input._visible(screen.get("_upgrade_scrim")) and screen.get("_progression_overlay_mode") == "equipment" and input._visible(_target) and bool(_target.get_meta("character_hovered", false))
		"full_health":
			var run: Dictionary = screen.get("_run_state")
			return run.get("player_hp") == run.get("player_max_hp") and input.matches_reward()
		"guardian_prize":
			var run: Dictionary = screen.get("_run_state")
			return not (run.get("guardian_reward", {}) as Dictionary).is_empty() and input._visible(screen.get("_relic_choice_bar")) and not screen.call("_treasure_presentation_busy")
		"dragon_prize":
			return input._visible(input._find(screen, "DragonRewardContinue")) and not screen.call("_treasure_presentation_busy")
		"withdraw":
			return screen.get("_run_state").get("mode") == "embrace" and input._visible(screen.get("_run_end_recap"))
	return false


func _map_path(input: RefCounted, visited: bool) -> String:
	await input._key(KEY_M)
	var map: Control = input._screen.get("_large_map_view")
	if not await input._wait(func() -> bool: return input._visible(map) and not (map.get("node_buttons") as Dictionary).is_empty()):
		return "Section map or its room buttons were unavailable."
	var rooms: Dictionary = map.get("run_state").get("rooms")
	for coord: Vector2i in map.get("node_buttons"):
		var data: Dictionary = rooms.get("%d,%d" % [coord.x, coord.y], {})
		var node: Control = map.get("node_buttons")[coord]
		if bool(data.get("visited", false)) != visited or not input._visible(node): continue
		var point: Vector2 = input._rect(node).get_center()
		if not input._viewport.get_visible_rect().has_point(point): continue
		_room = coord
		await input._move(point)
		if matches(input._state): return ""
	return "No %s room button opened the production preview." % ("visited" if visited else "unvisited")


func _hover_marked(input: RefCounted, host: Control, marker: StringName, state: String) -> String:
	if host == null: return "Inventory control was unavailable."
	for item: Node in host.find_children("*", "Control", true, false):
		if not input._visible(item): continue
		var is_offer: bool = item.has_meta(marker)
		if marker == &"character_hovered":
			is_offer = (item as Control).tooltip_text.begins_with("card:")
		if not is_offer: continue
		var rect: Rect2 = input._rect(item)
		if not input._viewport.get_visible_rect().has_point(rect.get_center()): continue
		_target = item
		await input._move(rect.get_center())
		if matches(state): return ""
	return "No visible inventory item accepted pointer hover."


func _menu_path(input: RefCounted, state: String) -> String:
	var menu: Control = input._screen
	if state == "title": return ""
	if state == "chronicle":
		return "" if await input._click(menu.get("chronicle_button")) else "Chronicle button was unavailable."
	if not await input._click(menu.get("start_button")):
		return "New Run was unavailable."
	if state == "replacement": return ""
	if not await input._click(menu.get("replacement_confirm_button")):
		return "Save replacement confirmation was unavailable."
	if state == "depth": return ""
	var root: Window = input._tree.root
	if state == "loading":
		root.set_meta("labyrinth_load_request_delay_frames", LOADING_COVER_DELAY_FRAMES)
	if not await input._click(input._find(menu, "DepthBegin")):
		return "Begin Descent was unavailable."
	if state == "loading":
		_transition = root.get_node_or_null("MenuRunTransition") as CanvasLayer
		if _transition == null: return "New Run did not show its loading cover."
		if input._viewport == root: return ""
		# Render the live CanvasLayer into the proof camera without breaking
		# the loader's root ownership or moving the title widgets a second time.
		_transition.custom_viewport = input._viewport
		var surface: Control = _transition.get("_surface")
		if not await input._wait(func() -> bool: return surface.size.is_equal_approx(Vector2(input._viewport.size))):
			await release_loading()
			return "Loading cover measured %s in the %s proof camera." % [surface.size, input._viewport.size]
		return ""
	if not await input._wait(func() -> bool: return input._tree.current_scene != null and input._tree.current_scene.has_method("has_installed_run") and not root.gui_disable_input):
		return "New Run did not hand off to the first room."
	input._screen = input._tree.current_scene
	if input._viewport != root:
		input._screen.reparent(input._viewport, false)
	input._input_viewport = input._viewport
	input._input_viewport.notify_mouse_entered()
	await input._tree.process_frame
	var wanted_line: int = int(input._shot.get("dialogue_line", 0))
	for _step: int in range(DIALOGUE_ADVANCE_LIMIT):
		if not bool(input._screen.get("_dialogue_active")):
			return "" if state == "first_room" else "Opening dialogue closed before the requested page."
		if state == "opening" and int(input._screen.get("_dialogue_line_index")) == wanted_line:
			return ""
		if bool(input._screen.call("_has_current_dialogue_options")):
			return "Opening dialogue required a branch choice."
		await input._key(KEY_ENTER)
	return "Opening dialogue did not reach the requested boundary."


func hold_loading() -> void:
	if is_instance_valid(_transition) and not _loading_cover_held:
		_loading_cover_held = true
		_transition.set_process(false)


func loading_tree() -> Node:
	return _transition


func release_loading() -> void:
	if not is_instance_valid(_transition): return
	_transition.cancel_loading_for_quit()
	var input: RefCounted = _input_ref.get_ref()
	_transition.custom_viewport = input._tree.root
	await input._tree.process_frame
	_transition.queue_free()
	await input._tree.process_frame
