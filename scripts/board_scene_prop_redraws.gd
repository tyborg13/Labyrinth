extends RefCounted

# A room prop can change the opacity of a different tile's foreground pillar.
# Redrawing only the prop's own tile leaves that pillar's retained commands stale.
static func queue_obstruction_changes(board: Control, previous_props: Array, next_props: Array) -> void:
	var previous_entries: Array[Dictionary] = _entries(board, previous_props)
	var next_entries: Array[Dictionary] = _entries(board, next_props)
	for candidate: Dictionary in board._foreground_obstruction_candidates():
		if board._moving_entries_obstruct_candidate(previous_entries, candidate) != board._moving_entries_obstruct_candidate(next_entries, candidate):
			board._queue_scene_render_layer_for_tile(candidate.get("tile", Vector2i(-1, -1)))

static func _entries(board: Control, props: Array) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for value: Variant in props:
		if not value is Dictionary: continue
		var prop: Dictionary = value
		var tile: Vector2i = prop.get("tile", Vector2i(-1, -1))
		if tile.x < 0: continue
		var texture: Texture2D = board._texture_for_scene_prop(prop)
		if texture != null:
			result.append({"tile": tile, "rect": board._scene_prop_rect(texture, prop)})
	return result
