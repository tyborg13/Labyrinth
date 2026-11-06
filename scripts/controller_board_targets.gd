extends RefCounted
## Navigation consumes the same offered targets as pointer confirmation. Umbra
## visibility governs inspection, not whether an already legal action can run.

static func tiles(scene: Node) -> Array[Vector2i]:
	var legal: Variant = null
	if scene._surface_aim.active():
		legal = scene._surface_skill_tiles
	elif scene._player_movement_selected:
		legal = scene._player_movement_target_tiles
	elif scene._selected_card_index >= 0:
		var offered: Array[Vector2i]
		if scene._pending_card_requires_confirmation():
			offered.append(scene._preview_combat_state.get("player", {}).get("pos", scene.INVALID_TARGET_TILE))
		elif scene._orientation_pending():
			# Pointer orientation confirmation accepts any rendered tile resolving to
			# a legal direction, including the selected target's current direction.
			var action: Dictionary = scene._pending_actions[scene._pending_action_index]
			for tile: Vector2i in scene.board_view.call("_rendered_tiles_in_draw_order"):
				var direction: Vector2i = scene._orientation_direction_for_confirmation(action, scene._pending_orientation_target_tile, tile)
				if direction == Vector2i.ZERO: continue
				var oriented: Dictionary = scene._action_with_pending_orientation(action, direction)
				if scene._combat_engine.valid_targets_for_player_action(scene._preview_combat_state, oriented).has(scene._pending_orientation_target_tile):
					offered.append(tile)
		else:
			offered.assign(scene._pending_target_tiles)
			var preview: Dictionary = scene._active_card_preview()
			if scene._prepare_preview_shortcuts_for_current_action(preview):
				for tile: Vector2i in scene._preview_shortcuts_cache.get("plans", {}):
					if not offered.has(tile): offered.append(tile)
		legal = offered
	var result: Array[Vector2i]
	result.assign(scene.board_view.call("controller_navigable_tiles", false, legal))
	return result

static func hidden_candidate(scene: Node, tile: Vector2i) -> Dictionary:
	# Never classify a hidden occupant, loot or floor effect. Pointer hover at
	# this tile has no inspection payload; only its existing tile highlight.
	return {
		"key": scene._controller_tile_key(tile), "kind": "tile", "tile": tile,
		"point": scene._controller_board_point(tile), "detail": "", "detail_key": "",
		"detail_revision": int(scene.board_view.call("tile_tooltip_revision")),
		"snap_radius": scene.CONTROLLER_TILE_CURSOR_MAGNET_RADIUS,
	}
