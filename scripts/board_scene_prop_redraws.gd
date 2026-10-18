extends RefCounted

# A room prop can change the opacity of a different tile's foreground pillar.
# Redrawing only the prop's own tile leaves that pillar's retained commands stale.
static func queue_obstruction_changes(board: Control, previous_props: Array, next_props: Array) -> void:
	var units: Array[Dictionary]
	units.assign(board._visible_units())
	var previous_entries: Array[Dictionary]
	previous_entries.assign(board._foreground_obstruction_entries(units, previous_props))
	var next_entries: Array[Dictionary]
	next_entries.assign(board._foreground_obstruction_entries(units, next_props))
	for candidate: Dictionary in board._foreground_obstruction_candidates():
		var tile: Vector2i = candidate["tile"]
		var rect: Rect2 = candidate["rect"]
		var tile_id: String = candidate["tile_id"]
		# Reuse the draw path's effective tint, including unchanged actors and
		# objects. A new prop cannot change alpha already fixed by an actor.
		var previous_alpha: float = board._foreground_blocker_tint(tile_id, tile, rect, previous_entries).a
		var next_alpha: float = board._foreground_blocker_tint(tile_id, tile, rect, next_entries).a
		if previous_alpha != next_alpha:
			board._queue_scene_render_layer_for_tile(tile)
