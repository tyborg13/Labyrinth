extends RefCounted
## Existing Marked medallions, using the approved keyword asset. Meteorfall
## already paints its landed marks at this same location: never stack badges.
const Areas = preload("res://scripts/boss_area_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Badge = preload("res://scripts/enemy_mechanics/lob_view.gd")

static func tiles(state: Dictionary, enemy: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for action: Dictionary in enemy.get("intent", {}).get("actions", []):
		if not Areas.fixed(action): continue
		for tile: Vector2i in Areas.shown(action):
			if not result.has(tile): result.append(tile)
	for tile: Vector2i in Areas.pending_wall_tiles(enemy):
		if not result.has(tile): result.append(tile)
	for mark: Dictionary in state.get("meteor_marks", []):
		for tile: Vector2i in mark.get("tiles", []): result.erase(tile)
	return result

static func draw_badges(view: Control) -> void:
	var drawn: Dictionary = {}
	for enemy: Dictionary in view.combat_state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		for tile: Vector2i in tiles(view.combat_state, enemy):
			if drawn.has(tile) or not preload("res://scripts/path_utils.gd").is_in_bounds(view.combat_state["grid"], tile): continue
			drawn[tile] = true
			Badge.draw_mark_badge(view, tile, Icons.icon_texture("marked"), Icons.tooltip("marked"))
