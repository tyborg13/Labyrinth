extends RefCounted

## Default for directional enemy cutouts: idle watches the player, actions
## follow their own direction. Use the displayed state so a pending player
## destination does not turn observers before movement has finished.
static func direction_for_delta(delta: Vector2i) -> Dictionary:
	# The four 2:1 isometric directions divide at screen-horizontal/vertical
	# axes. The larger board component picks the closest facing; x wins ties.
	if absi(delta.x) >= absi(delta.y) and delta.x != 0:
		return {"facing": "front" if delta.x > 0 else "rear", "mirrored": true}
	return {"facing": "front" if delta.y >= 0 else "rear", "mirrored": false}

static func with_idle_direction(motion: Dictionary, enemy_tile: Vector2i, player_tile: Vector2i) -> Dictionary:
	var clip: String = str(motion.get("clip", "idle"))
	if clip == "walk" or (clip not in ["idle", "rest"] and float(motion.get("phase", 0.0)) < 1.0):
		return motion
	var result: Dictionary = motion.duplicate(false)
	result["direction"] = player_tile - enemy_tile
	return result
