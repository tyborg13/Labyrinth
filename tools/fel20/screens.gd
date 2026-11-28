extends RefCounted
## Read presentation and input surfaces without calling a game handler.

var tree: SceneTree
var inputs


func _init(host: SceneTree, driver: RefCounted) -> void:
	tree = host
	inputs = driver


func run_scene() -> Node:
	var scene := tree.current_scene
	return scene if is_instance_valid(scene) and scene.has_method("has_installed_run") else null


func visible(control: Variant) -> bool:
	return is_instance_valid(control) and control is Control and control.is_visible_in_tree()


func screen() -> String:
	var scene := tree.current_scene
	if not is_instance_valid(scene): return "between_scenes"
	if not scene.has_method("has_installed_run"):
		if scene.name == "MenuRunTransition" or scene.get("_loading_run"): return "loading"
		if scene.get("_boot_preparing"): return "title_boot"
		return "title"
	if visible(scene._run_end_recap): return "recap"
	if visible(scene._menu_scrim): return "pause"
	if visible(scene._upgrade_scrim): return {"equipment": "gear", "magic": "magic", "skills": "skills"}.get(scene._progression_overlay_mode, "gear")
	if visible(scene._grimoire_scrim): return "grimoire"
	if visible(scene._event_view): return "event_" + str(scene._event_view.page)
	if visible(scene._scavenger_shop_view): return "shop"
	if visible(scene._pre_battle_scrim): return "prebattle"
	if visible(scene._large_map_scrim): return "map"
	if scene._dialogue_active: return "dialogue"
	return str(scene._run_state.get("mode", "boot"))


func witness() -> Array:
	var scene := run_scene()
	var state: Array = [screen()]
	if scene == null: return state
	var run: Dictionary = scene._run_state
	var combat: Dictionary = scene._combat_state
	state.append_array([str(run.get("seed", "")), str(run.get("current_room", "")),
		str(combat.get("turn", "")), str(combat.get("current_actor", "")),
		str(combat.get("player", {}).get("pos", "")), str(combat.get("player", {}).get("hp", "")),
		str(combat.get("deck", {}).get("hand", [])), str(scene._selected_card_index),
		scene._player_movement_selected, scene._pending_action_index,
		scene._dialogue_line_index if scene._dialogue_active else -1,
		str(scene._run_engine.held_embers(run))])
	return state


func matches(expected: Array) -> bool:
	var actual: Array = witness()
	return actual.slice(0, expected.size()) == expected


func destination(expected: String) -> bool:
	var actual: String = screen()
	return actual == expected or (expected == "character" and actual in ["gear", "magic", "skills"])


func probe(expected: String) -> String:
	# Keep the cursor stationary while the source owns input. The destination
	# probe leaves and re-enters its target to distinguish a new acknowledgement.
	inputs.motion(inputs.pointer)
	if not destination(expected): return ""
	var scene := run_scene()
	if scene == null:
		var title := tree.current_scene
		return _hover(title.start_button if title.continue_button.disabled else title.continue_button)
	if scene._animation_lock or is_instance_valid(scene._section_transition): return ""
	match expected:
		"combat":
			if not scene._combat_engine.is_player_turn(scene._combat_state): return ""
			var tile: Vector2i = scene._combat_state["player"]["pos"]
			inputs.motion(Vector2(-2, -2))
			var previous: Vector2i = scene._hovered_board_tile
			inputs.motion(inputs.tile_point(scene, tile))
			if previous != tile and scene._hovered_board_tile == tile: return "board hover on hero tile"
			return ""
		"map":
			var map: Control = scene._large_map_view
			if map.activation_coord != Vector2i(-999, -999): return ""
			return _hover_tree(map)
		"prebattle":
			if scene._pre_battle_panel.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_DISABLED: return ""
			return _hover(inputs.named(scene._pre_battle_scrim, "PreBattleStartButton"))
		"reward":
			if scene._reward_intro_in_progress: return ""
			return _hover_tree(scene._relic_choice_bar)
		"event_choices":
			var event: Control = scene._event_view
			if event._busy or event._request_pending or event._closing: return ""
			for option: Button in event.choices:
				if option.available:
					return _hover(option)
			return ""
		"event_result":
			return _hover(scene._event_view.continue_button)
		"shop": return _hover(scene._scavenger_shop_view._leave_button)
		"recap": return _hover(inputs.named(scene._run_end_recap, "MainMenuButton"))
		"character", "gear", "magic", "skills": return _hover_tree(scene._upgrade_scrim)
		"grimoire": return _hover_tree(scene._grimoire_scrim)
		"pause": return _hover_tree(scene._menu_scrim)
	return ""


func _hover_tree(scope: Control) -> String:
	for target: Node in scope.find_children("*", "BaseButton", true, false):
		if not inputs.available(target) or target.focus_mode == Control.FOCUS_NONE: continue
		var result: String = _hover(target)
		if not result.is_empty(): return result
	return ""


func _hover(target: Control) -> String:
	var input: Dictionary = inputs.control(target)
	if input.is_empty(): return ""
	inputs.motion(Vector2(-2, -2))
	var before: Control = tree.root.gui_get_hovered_control()
	inputs.prepare(input)
	var after: Control = tree.root.gui_get_hovered_control()
	if after != before and is_instance_valid(after) and (after == target or target.is_ancestor_of(after)):
		return "GUI hover on " + (target.text if target is Button and not target.text.is_empty() else str(target.name))
	return ""
