extends RefCounted
## Navigate the production controls and verify the specific screen requested.
## Read-only scene properties are used as assertions and to locate input targets.

const ExtraStates = preload("census_states.gd")
const TOOLTIP_WAIT_SECONDS: float = 0.8
const REACH_MSEC: int = 12000
const HAND_SAMPLE_FRACTIONS: Array = [0.5, 0.25, 0.75, 0.1, 0.9]

var _tree: SceneTree
var _viewport: Viewport
var _input_viewport: Viewport
var _screen: Control
var _shot: Dictionary
var _state: String
var _section: String
var _card_index: int = -1
var _enemy_tile: Vector2i
var _settings_heading: Label
var _settings_scroll: ScrollContainer
var _pointer := Vector2.ZERO
var _extra: RefCounted


func _init(tree: SceneTree, viewport: Viewport, screen: Control, shot: Dictionary) -> void:
	_tree = tree
	_viewport = viewport
	_input_viewport = screen.get_viewport() if screen.is_inside_tree() else viewport
	_screen = screen
	_shot = shot
	_state = str(shot.get("state", "default"))
	_section = str(shot.get("section", ""))
	_extra = ExtraStates.new(self)


func reach() -> String:
	# Let deferred combat startup and control layout run before sending input.
	await _tree.process_frame
	await _tree.process_frame
	_input_viewport.notify_mouse_entered()
	if _shot.get("fixture") == "four_enemies" and _state != "reward":
		var combat: Dictionary = _screen.get("_combat_state")
		if (combat.get("enemies", []) as Array).size() != 4:
			return "The combat fixture did not load four enemies."
	if _shot["scenario"] == "character" and _screen.get("_dialogue_active"):
		# The fixture starts in the entry room. Close its automatic narration
		# through the game's cancel input before opening the requested surface.
		await _key(KEY_ESCAPE)
	if _shot.get("entry") != "menu" and _state not in ["default", "reward"] and not await _wait(_ready_for_input):
		return "The loaded screen did not become ready for input."
	match _state:
		"default", "reward":
			pass
		"hover", "keyword", "aim", "push":
			var error: String = await _hand_state()
			if not error.is_empty(): return error
		"map":
			await _key(KEY_M)
		"pause":
			if not await _click(_screen.get("menu_button")): return "Menu button was unavailable."
		"settings":
			var error: String = await _settings_state()
			if not error.is_empty(): return error
		"grimoire":
			if not await _click(_screen.get("grimoire_button")): return "Grimoire button was unavailable."
		"character", "gear_hover":
			# Closing the entry narration auto-opens the section map. Back
			# out through its own shortcut to expose the header controls.
			if _shot["scenario"] == "character" and _visible(_screen.get("_large_map_scrim")):
				await _key(KEY_M)
			if _shot["scenario"] == "character" and _screen.call("_guided_tutorial_action_restricted"):
				var guide: Control = _screen.get("_contextual_combat_prompt")
				if guide == null or not await _click(guide.get("_skip_button")):
					return "The default room is tutorial-locked and its dismiss action is unavailable."
			if not await _click(_screen.get("loadout_button")): return "Loadout button was unavailable."
			if not _visible(_screen.get("_upgrade_scrim")):
				var hovered: Control = _viewport.gui_get_hovered_control()
				return "Loadout click did not open Character (pointer owner %s)." % (hovered.name if hovered != null else "none")
			if str(_screen.get("_progression_overlay_mode")) != _section:
				var tab := _find(_screen.get("_upgrade_scrim"), "Character%sTab" % _section.capitalize())
				if not await _click(tab): return "Character tab %s was unavailable." % _section
			if _state == "gear_hover":
				var error: String = await _extra.reach(_state)
				if not error.is_empty(): return error
		"enemy_turn":
			# The native pass shortcut starts an ordinary enemy round.
			await _key(KEY_P)
		_:
			var error: String = await _extra.reach(_state)
			if not error.is_empty(): return error
	if not await _wait(matches):
		return "The game did not present the requested %s state%s." % [
			_state, _unreached_detail(),
		]
	if _state == "loading":
		_extra.hold_loading()
	if _state == "enemy_turn":
		# Enemy activations are transient. Hold the first actually presented
		# enemy-active rail frame so the pixel comparison cannot drift to
		# the next player turn. This happens only inside the isolated probe.
		_tree.paused = true
		hold_enemy_frame()
	return ""


func hold_enemy_frame() -> void:
	if _state == "enemy_turn" and _tree.paused:
		for tween: Tween in _tree.get_processed_tweens():
			if tween.is_running(): tween.pause()


func matches() -> bool:
	match _state:
		"default":
			return _default_screen_ready()
		"hover":
			return _screen.get("_hovered_card_index") == _card_index
		"keyword":
			var stack: Control = _screen.get("_card_focus_tooltip_stack")
			return _screen.get("_hovered_card_index") == _card_index and _visible(stack) and int(stack.call("entry_count")) > 0
		"aim":
			return aim_matches()
		"map":
			return _visible(_screen.get("_large_map_scrim"))
		"pause":
			return _visible(_screen.get("_menu_dialog"))
		"settings":
			return _visible(_settings_heading) and _settings_scroll.get_global_rect().encloses(_settings_heading.get_global_rect())
		"grimoire":
			return _visible(_screen.get("_grimoire_scrim"))
		"character":
			return _visible(_screen.get("_upgrade_scrim")) and _screen.get("_progression_overlay_mode") == _section
		"reward":
			return matches_reward()
		"enemy_turn":
			if not _visible(_screen.get("_turn_order_panel")) or not _screen.get("_animation_lock"):
				return false
			var rail: Control = _screen.get("_turn_order_bar")
			for slot: Control in rail.get_children():
				if _visible(slot) and slot.get_meta("turn_order_team", "") == "enemy" and slot.get_meta("turn_order_animation_role", "") == "active":
					return true
	return _extra.matches(_state)


func _default_screen_ready() -> bool:
	if not _screen.call("initial_presentation_is_ready"): return false
	var run: Dictionary = _screen.get("_run_state")
	match run.get("mode"):
		"pre_battle":
			return _visible(_screen.get("_pre_battle_scrim"))
		"event":
			return _visible(_screen.get("_event_view"))
		"treasure":
			return _visible(_screen.get("_relic_choice_bar")) and not _screen.call("_treasure_presentation_busy")
		"campfire":
			return _visible(_screen.get("_relic_choice_bar"))
		"room":
			if _shot["scenario"] == "scavenger":
				return _visible(_screen.get("_scavenger_shop_view"))
		"victory", "defeat":
			return _visible(_screen.get("_run_end_recap"))
	return true


func _unreached_detail() -> String:
	if _state in ["aim", "push"]:
		var hovered: Control = _viewport.gui_get_hovered_control()
		return " (expected tile %s, actual %s at %s, pointer owner %s, arrow %s)" % [
			_enemy_tile, _screen.get("_hovered_board_tile"), _pointer,
			hovered.name if hovered != null else "none", _visible(_screen.get("_drag_overlay")),
		]
	if _state == "enemy_turn":
		var combat: Dictionary = _screen.get("_combat_state")
		return " (activation %s, turn %s)" % [combat.get("activation_seq"), combat.get("current_actor")]
	return " (%s)" % _section if not _section.is_empty() else ""


func _hand_state() -> String:
	var combat: Dictionary = _screen.get("_combat_state")
	var hand: Array = (combat.get("deck", {}) as Dictionary).get("hand", [])
	_card_index = hand.find(_shot.get("card"))
	if _card_index < 0:
		return "Fixture hand does not contain %s." % _shot.get("card")
	if _state not in ["aim", "push"]:
		return "" if await _wait(_point_at_hand_card) else "No reachable hover point on %s." % _shot.get("card")
	# Use the production number shortcut. Compact layout can overlap the
	# unraised cards, while the shortcut selects the same card as its click.
	if _card_index >= 9: return "The aim card is outside the hand shortcut range."
	await _key((KEY_1 + _card_index) as Key)
	if not await _wait(func() -> bool: return _screen.get("_selected_card_index") == _card_index):
		return "The hand shortcut did not select the requested card."
	var targets: Array = _screen.get("_pending_target_tiles")
	var board: Control = _screen.get("board_view")
	for enemy: Dictionary in combat.get("enemies", []):
		var tile: Vector2i = enemy["pos"]
		if tile not in targets: continue
		_enemy_tile = tile
		return "" if await _wait(_point_at_enemy.bind(board)) else "Aim did not reach its enemy%s." % _unreached_detail()
	return "Selected card has no legal enemy target."


func _point_at_hand_card() -> bool:
	if _screen.get("_hovered_card_index") == _card_index: return true
	var card: Control = _screen.call("_hand_card_control", _card_index)
	var hand_scroll: Control = _screen.get("hand_scroll")
	if not _visible(card) or not _visible(hand_scroll): return false
	var clip: Rect2 = _viewport.get_visible_rect()
	if hand_scroll.clip_contents: clip = clip.intersection(_rect(hand_scroll))
	var target: Rect2 = _rect(card).intersection(clip)
	if not target.has_area(): return false
	var fan: Control = _screen.get("hand_box")
	# The rotated card rectangles can overlap at compact sizes. Find a
	# viewport point the same hit test as real hover assigns to this card.
	for y: float in HAND_SAMPLE_FRACTIONS:
		for x: float in HAND_SAMPLE_FRACTIONS:
			var point: Vector2 = target.position + target.size * Vector2(x, y)
			if int(fan.call("card_index_at_point", point)) == _card_index:
				_dispatch_motion(point)
				return _screen.get("_hovered_card_index") == _card_index
	return false


func _point_at_enemy(board: Control) -> bool:
	if matches(): return true
	var local_point: Vector2 = board.call("world_position_for_tile", _enemy_tile)
	var point: Vector2 = board.get_global_transform_with_canvas() * local_point
	if point != _pointer: _dispatch_motion(point)
	return false


func _settings_state() -> String:
	if not await _click(_screen.get("menu_button")):
		return "Menu button was unavailable."
	var menu: Control = _screen.get("_menu_dialog")
	var button: Button
	for child: Node in menu.find_children("*", "Button", true, false):
		if (child as Button).text == "Settings":
			button = child as Button
			break
	if not await _click(button):
		return "Settings action was unavailable."
	var panel: Control = _screen.get("_settings_panel")
	for child: Node in panel.find_children("*", "Label", true, false):
		if (child as Label).text == _section:
			_settings_heading = child as Label
			break
	if _settings_heading == null:
		return "Settings has no %s section." % _section
	var ancestor: Node = _settings_heading.get_parent()
	while ancestor != null and not ancestor is ScrollContainer:
		ancestor = ancestor.get_parent()
	_settings_scroll = ancestor as ScrollContainer
	if _settings_scroll == null:
		return "Settings section is not in the production scroll container."
	await _tree.process_frame
	var heading_offset: float = _settings_heading.global_position.y - _settings_scroll.global_position.y
	var next_scroll: float = _settings_scroll.scroll_vertical + heading_offset
	var scroll_bar: VScrollBar = _settings_scroll.get_v_scroll_bar()
	_settings_scroll.scroll_vertical = roundi(clampf(next_scroll, 0.0, maxf(0.0, scroll_bar.max_value - scroll_bar.page)))
	return ""


func matches_reward() -> bool:
	var row := _find(_screen, "RewardCardRow")
	return _visible(row) and row.get_child_count() == 3 and not _screen.get("_reward_intro_in_progress")


func aim_matches() -> bool:
	return _screen.get("_selected_card_index") == _card_index and _screen.get("_hovered_board_tile") == _enemy_tile and _visible(_screen.get("_drag_overlay"))


func _ready_for_input() -> bool:
	return _screen.call("initial_presentation_is_ready") and not _screen.get("_animation_lock") and not _visible(_screen.get("_dialogue_overlay"))


func _wait(condition: Callable) -> bool:
	var deadline: int = Time.get_ticks_msec() + REACH_MSEC
	while not condition.call():
		if Time.get_ticks_msec() >= deadline: return false
		await _tree.process_frame
	return true


func _find(parent: Node, node_name: String) -> Control:
	return parent.find_child(node_name, true, false) as Control if is_instance_valid(parent) else null


func _visible(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree()


func _rect(control: Control) -> Rect2:
	return control.get_global_transform_with_canvas() * Rect2(Vector2.ZERO, control.size)


func _move(point: Vector2) -> void:
	_dispatch_motion(point)
	await _tree.process_frame


func _dispatch_motion(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = point - _pointer
	_pointer = point
	_input_viewport.push_input(event, true)


func _click(control: Control) -> bool:
	if not _visible(control) or (control is BaseButton and control.disabled):
		return false
	var point: Vector2 = _rect(control).intersection(_input_viewport.get_visible_rect()).get_center()
	await _move(point)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_input_viewport.push_input(event, true)
		await _tree.process_frame
	return true


func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_input_viewport.push_input(event, true)
		await _tree.process_frame


func needs_popup_wait() -> bool:
	return _state in ["enemy_hover", "rail_hover", "sell_hover", "gear_hover"]


func wait_for_tooltip() -> void:
	# Native tooltips use the Viewport's hover timer. Wait past the timer
	# before comparing frames so an early stable sample cannot omit it.
	await _tree.create_timer(TOOLTIP_WAIT_SECONDS).timeout


func capture_tree() -> Node:
	return _extra.loading_tree() if _state == "loading" else _viewport


func release_loading() -> void:
	await _extra.release_loading()
