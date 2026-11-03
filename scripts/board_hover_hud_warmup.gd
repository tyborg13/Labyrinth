extends RefCounted

# Populate the existing exact-source LRU at a room boundary. These are ordinary
# synchronous layout solves, with the original focus and final HUD restored
# before any draw. No polling, delayed visuals, or alternate layout algorithm.
static func prepare(board: Control) -> void:
	if not board.is_inside_tree() or board.combat_state.is_empty(): return
	if board._all_enemy_intents_expanded() or not (board.presentation.get("expanded_enemy_actor_keys", []) as Array).is_empty(): return
	var hover: Vector2i = board._hover_tile
	var focus: Vector2i = board._controller_focus_tile
	board._controller_focus_tile = Vector2i(-1, -1)
	for unit: Dictionary in board._hud_layout_units():
		if str(unit.get("role", "")) != "enemy" or bool(unit.get("death_animation", false)): continue
		board._hover_tile = unit.get("pos", Vector2i(-1, -1))
		board._rebuild_hud_health_rects_cache()
	board._hover_tile = hover
	board._controller_focus_tile = focus
	board._rebuild_hud_health_rects_cache()
