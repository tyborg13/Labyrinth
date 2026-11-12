extends RefCounted

## Consume the same sanitized preview and shortcut cache as the click path.
## Enemy footprints are visibility-filtered so a movement hover reveals nothing.
static func choosing(scene: Node) -> bool:
	if scene._dialogue_active or scene._animation_lock or str(scene._run_state.get("mode", "")) != "combat": return false
	if scene._board_targeting_active(): return true
	return scene._selected_card_index >= 0 and scene._pending_action_index >= 0 and scene._pending_action_index < scene._pending_actions.size() and scene._combat_engine.player_action_needs_target(scene._pending_actions[scene._pending_action_index])

static func build(scene: Node, preview: Dictionary) -> Dictionary:
	if not choosing(scene): return {}
	var action: Dictionary = preview.get("action", {})
	var action_type: String = str(action.get("type", ""))
	var attack: bool = action_type in ["melee", "ranged", "aoe", "push", "pull", "detonate"]
	var shortcuts: Dictionary = {}
	if action_type in ["move", "blink"]:
		scene._prepare_preview_shortcuts_for_current_action(preview)
		shortcuts = scene._preview_shortcuts_cache.get("plans", {})
	var enemy_tiles: Dictionary = {}
	# Ground/self/utility choices do not become enemy targets merely because a
	# body shares that tile. Movement attacks are supplied explicitly as shortcuts.
	if not attack and action_type not in ["surface", "confirm", "move", "blink", "guardian_move"]:
		for enemy: Dictionary in scene._combat_state.get("enemies", []):
			if int(enemy.get("hp", 0)) <= 0 or not scene._combat_engine.is_enemy_visible_to_player(scene._combat_state, enemy): continue
			for tile: Vector2i in scene._enemy_footprint_tiles(enemy): enemy_tiles[tile] = true
	var colors: Dictionary = {}
	for tone: String in ["move", "attack", "valid", "invalid"]:
		colors[tone] = scene._action_context_target_color(tone)
	return {"active": true, "targets": preview.get("target_tiles", []), "shortcuts": shortcuts,
		"move": action_type in ["move", "blink"], "attack": attack,
		"enemy_tiles": enemy_tiles, "colors": colors, "reduced_motion": scene._reduced_motion_enabled()}
