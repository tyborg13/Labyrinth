extends RefCounted

## Original paint order, with retained enemy ownership at command boundaries.
const Isolation = preload("res://scripts/board_threat_isolation.gd")

static func effects(board: Control) -> void:
	board._slice_op("_draw_effect_overlay", [], true)
	for marker: Dictionary in board.presentation.get("collision_markers", []):
		board._threat_slice_keys = Isolation.owner_keys(marker)
		board._slice_op("_draw_isolated_collision", [marker])
	board._threat_slice_keys.clear()
	for kind: String in ["burrow", "meteor", "icefall", "lob"]:
		if kind == "meteor":
			board._slice_op("_draw_meteor_mark_badges", [false])
			continue
		for enemy: Dictionary in board.combat_state.get("enemies", []):
			if kind == "burrow" and not bool(enemy.get("burrowed", false)): continue
			if kind == "icefall" and (enemy.get("icefall_tiles", []) as Array).is_empty(): continue
			if kind == "lob" and (enemy.get("lob_tiles", []) as Array).is_empty() and not (enemy.get("intent", {}).get("actions", []) as Array).any(func(action: Dictionary) -> bool: return str(action.get("type", "")) in ["lob_mark", "lob_land"]): continue
			board._threat_slice_keys.append("enemy_%d" % int(enemy.get("id", -1)))
			board._slice_op("_draw_isolated_mechanic_badges", [kind, enemy])
			board._threat_slice_keys.clear()
	var wind_source: int = int(board.combat_state.get("wind", {}).get("source_id", -1))
	if wind_source >= 0: board._threat_slice_keys.append("enemy_%d" % wind_source)
	board._slice_op("_draw_isolated_wind_collisions", [])
	board._threat_slice_keys.clear()
	board._slice_op("_draw_lethal_preview_icons", [board._visible_units()], true)
	board._slice_op("_draw_movement_risk_chips", [])
	board._slice_op("_draw_status_text", [])
	board._slice_op("_draw_floating_texts", [], true)

static func telegraphs(board: Control) -> void:
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		if str(threat.get("projected_attack_action", {}).get("type", "")) != "chain_discharge": continue
		board._threat_slice_keys.append(str(threat.get("enemy_key", "")))
		board._slice_op("_draw_isolated_chain", [threat], true)
		board._threat_slice_keys.clear()

static func scene(board: Control) -> void:
	var tile: Vector2i = board._render_layer_tile
	if tile.x < 0: return
	if board._render_layer_scene_effect_pass != 0:
		board._slice_op("_draw_elemental_scene_depth_pass", [tile, board._render_layer_scene_effect_pass > 0], true)
		return
	board._slice_op("_draw_board_surface", [tile])
	for entry: Array in board._scene_tile_preparation.paths(board):
		if not (entry[0] as Array).has(tile): continue
		board._threat_slice_keys.clear()
		for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
			if entry[0] == board._vector2i_array(threat.get("projected_path", [])) and not bool(entry[2]): board._threat_slice_keys.append(str(threat.get("enemy_key", "")))
		board._slice_op("_draw_isolated_path", [entry, tile])
	board._threat_slice_keys.clear()
	for echo: Dictionary in board.presentation.get("illusion_echo_previews", []):
		if board._ranged_preview_depth_tile(echo) == tile: board._slice_op("_draw_isolated_arrow", [echo])
	for threat: Dictionary in board.presentation.get("enemy_threat_previews", []):
		var effect: Dictionary = board._enemy_threat_ranged_effect(threat)
		if effect.is_empty() or board._ranged_preview_depth_tile(effect) != tile: continue
		board._threat_slice_keys.append(str(threat.get("enemy_key", "")))
		board._slice_op("_draw_isolated_arrow", [effect])
		board._threat_slice_keys.clear()
	board._slice_op("_draw_noctyrax_refuge_tile", [tile])
	board._slice_op("_draw_isolated_props", [tile], true)
	var owner: Control = board.get("_render_instrumentation_owner")
	if is_instance_valid(owner) and is_instance_valid(owner.get("_occlusion_silhouettes")) and bool(owner.get("_occlusion_silhouettes").get("tool_enabled")): return
	for unit: Dictionary in board._visible_units():
		if board._effective_unit_tile(unit) != tile: continue
		board._threat_slice_keys = Isolation.owner_keys(unit, board)
		board._slice_op("_draw_unit_body", [unit], true)
	board._threat_slice_keys.clear()

