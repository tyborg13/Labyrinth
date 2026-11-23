extends RefCounted
## Inspect the prop commands for only the fading pickup, without a GPU.

static func sample(board: Control, loot: Dictionary) -> Dictionary:
	var tile: Vector2i = loot["pos"]
	var texture: Texture2D = board._loot_texture(loot)
	if texture == null:
		return {"count": -1}
	var cache: RefCounted = board._prop_command_cache
	var previous: Array = cache.commands
	var recording: bool = cache.recording
	cache.recording = true
	cache.commands = []
	board._draw_equipment_pickup(tile, board._loot_rect_for_tile(tile, texture, loot), texture, loot)
	var commands: Array = cache.commands
	cache.recording = recording
	cache.commands = previous
	if commands.size() != 1:
		return {"count": commands.size()}
	var command: Array = commands[0]
	var tint: Color
	var bounds: String
	match command[0]:
		"polygon":
			tint = command[2][0]
			bounds = str(command[1])
		"texture":
			tint = command[3]
			bounds = str(command[2])
		_:
			return {"count": -1}
	return {"count": 1, "rgb": [tint.r, tint.g, tint.b], "opacity": tint.a, "bounds": bounds}

static func matches(sampled: Dictionary, progress: float, bounds: String) -> bool:
	if progress == 1.0:
		return sampled["count"] == 0
	return sampled["count"] == 1 and sampled["rgb"] == [1.0, 1.0, 1.0] \
		and is_equal_approx(float(sampled["opacity"]), 1.0 - progress) and sampled["bounds"] == bounds
