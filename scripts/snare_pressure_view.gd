extends RefCounted
## Reuse the Thornwall marked-area presentation; no new marker or palette.
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
static var _engine := preload("res://scripts/combat_engine.gd").new()
static var _memo := preload("res://scripts/combat_preview_memo.gd").new()

static func presentation_for(state: Dictionary, original: Dictionary) -> Dictionary:
	if str(state.get("objective", {}).get("special_type", "")) != "umbral_snare" or str(state.get("current_actor", {}).get("kind", "player")) != "player": return original
	var effect: Dictionary = original.get("effect", {})
	if not effect.is_empty() and not bool(effect.get("preview", false)): return original
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(_engine.GameData.enemies().get(str(enemy.get("type", "")), {}))
	var forecast: Dictionary = _memo.resolve([state, definitions, Pressure.definition(state), _engine._relic_effects(state)], func() -> Dictionary: return Pressure.presentation_projection(Pressure.preview(_engine, state)))
	var result: Dictionary = original.duplicate(false)
	result["snare_pressure_preview"] = forecast
	var rest: Dictionary = original.get("threats_at_rest", {}).duplicate(false)
	var threats: Array = rest.get("threats", []).duplicate(false)
	threats = threats.filter(func(threat: Dictionary) -> bool: return str(threat.get("key", "")) != "snare_pressure")
	threats.append({"key": "snare_pressure", "area": true, "tiles": forecast["tiles"]})
	rest["threats"] = threats
	rest["hero_tile"] = state["player"]["pos"]
	result["threats_at_rest"] = rest
	# Door art, thresholds, chips and Sealbinders remain outside the fog mask.
	if result.has("umbra_visible_tiles"):
		var visible: Array = result["umbra_visible_tiles"].duplicate()
		for exit: Dictionary in state["objective"]["exits"]:
			for tile: Vector2i in [exit["target_tile"], exit["door_tile"]]:
				if not visible.has(tile): visible.append(tile)
		for enemy: Dictionary in state["enemies"]:
			if bool(enemy.get("snare_sealbinder", false)) and int(enemy.get("hp", 0)) > 0 and not visible.has(enemy["pos"]): visible.append(enemy["pos"])
		result["umbra_visible_tiles"] = visible
	return result

