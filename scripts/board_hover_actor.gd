extends RefCounted

# Rest-badge focus needs only identity. Resolving/copying a complete threat plan
# a second time on the same hover did no presentation work. Keep the original
# alive/visibility/footprint tests and first-match ordering exactly.
static func key_at_tile(scene: Object, state: Dictionary, tile: Vector2i, fallback: String = "") -> String:
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		if not scene._combat_engine.is_enemy_visible_to_player(state, enemy): continue
		if scene._enemy_footprint_tiles(enemy).has(tile): return scene._enemy_key(enemy)
	return fallback
