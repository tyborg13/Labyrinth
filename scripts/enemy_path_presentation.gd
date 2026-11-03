extends RefCounted

## Resting mechanic overlays retain their attack evidence. Ordered movement
## paths belong to the ordinary explicit enemy focus/show-all submission.
static func without_enemy_paths(original: Dictionary, submitted: Dictionary = {}) -> Dictionary:
	if not submitted.get("enemy_threat_previews", []).is_empty() or bool(submitted.get("show_all_enemy_intents", false)) or not submitted.get("expanded_enemy_actor_keys", []).is_empty(): return original
	var result: Dictionary = original.duplicate(false)
	# Enemy decorators can add both approach and collateral displacement paths.
	# Keep the caller's player/animation routes, not the decorators' additions.
	for key: String in ["path_tiles", "path_color", "projected_destination", "displacement_paths"]:
		if submitted.has(key): result[key] = submitted[key]
		else: result.erase(key)
	var previews: Array[Dictionary]
	for entry: Dictionary in original.get("enemy_threat_previews", []):
		var threat: Dictionary = entry.duplicate(false)
		threat.erase("projected_path")
		previews.append(threat)
	if original.has("enemy_threat_previews"): result["enemy_threat_previews"] = previews
	return result
