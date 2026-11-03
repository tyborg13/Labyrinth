extends RefCounted

# Path polygons are clipped to a tile in _draw_path_depth_pass, and the path
# renderer rejects tiles absent from that path. Ranged curves belong entirely
# to their destination's depth layer. Preserve the union so removed commands
# disappear as well as new commands appearing; no geometry or draw order changes.
static func tiles(board: Control, previous: Dictionary, next: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for source: Dictionary in [previous, next]:
		_append(result, source.get("path_tiles", []))
		for path: Array in source.get("displacement_paths", []): _append(result, path)
		for threat_var: Variant in source.get("enemy_threat_previews", []):
			if not threat_var is Dictionary: continue
			var threat: Dictionary = threat_var
			_append(result, threat.get("projected_path", []))
			var effect: Dictionary = board._enemy_threat_ranged_effect(threat)
			if not effect.is_empty(): result[board._ranged_preview_depth_tile(effect)] = true
		for echo: Dictionary in source.get("illusion_echo_previews", []):
			result[board._ranged_preview_depth_tile(echo)] = true
	return result

static func _append(target: Dictionary, path: Array) -> void:
	for tile: Variant in path:
		if tile is Vector2i: target[tile] = true
