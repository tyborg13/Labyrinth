extends RefCounted
## Ground surfaces and their rule warnings use the submitted board's sight mask.

static func tile_is_drawn(state: Dictionary, tile: Vector2i, visible_tiles: Variant) -> bool:
	if str(state.get("objective", {}).get("special_type", "")) == "umbral_snare":
		if load("res://scripts/snare_pressure_rules.gd").visible_tile(state, tile): return true
	return not (visible_tiles is Array) or visible_tiles.has(tile)

static func projection_input(presentation: Dictionary) -> Dictionary:
	return {
		"umbra_visible_tiles": presentation.get("umbra_visible_tiles"),
		"visible_enemy_ids": presentation.get("visible_enemy_ids"),
	}
