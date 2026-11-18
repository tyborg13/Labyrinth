extends RefCounted
## Reuse the Thornwall marked-area presentation; no new marker or palette.
const Combat = preload("res://scripts/combat_engine.gd")
const Pressure = preload("res://scripts/snare_pressure_rules.gd")
const SurfaceVisibility = preload("res://scripts/board_surface_visibility.gd")
const THREAT_KEY: String = "snare_pressure"
static var _memo := preload("res://scripts/combat_preview_memo.gd").new()
# Initialize on first use in case CombatEngine is still loading this script.
static var _engine_instance: RefCounted = null

static func _engine() -> RefCounted:
	if _engine_instance == null: _engine_instance = Combat.new()
	return _engine_instance

static func presentation_for(state: Dictionary, original: Dictionary, use_board_mask: bool = false) -> Dictionary:
	if str(state.get("objective", {}).get("special_type", "")) != "umbral_snare": return original
	var effect: Dictionary = original.get("effect", {})
	if str(state.get("battlefield_rule", {}).get("rule", "")) == "shadowstep" and (str(state.get("current_actor", {}).get("kind", "player")) != "player" or (not effect.is_empty() and not bool(effect.get("preview", false)))): return original
	var definitions: Array
	for enemy: Dictionary in state.get("enemies", []): definitions.append(_engine().GameData.enemies().get(str(enemy.get("type", "")), {}))
	var board_sight: Dictionary = SurfaceVisibility.projection_input(original) if use_board_mask or original.has("umbra_visible_tiles") else {}
	var forecast: Dictionary = _memo.resolve([state, definitions, Pressure.definition(state), _engine()._relic_effects(state), board_sight], func() -> Dictionary: return Pressure.presentation_projection(Pressure.present_now(_engine(), state, board_sight)))
	var result: Dictionary = original.duplicate(false)
	result["snare_pressure_preview"] = forecast
	var rest: Dictionary = original.get("threats_at_rest", {}).duplicate(false)
	var threats: Array = rest.get("threats", []).duplicate(false)
	threats = threats.filter(func(threat: Dictionary) -> bool: return str(threat.get("key", "")) != THREAT_KEY)
	threats.append({"key": THREAT_KEY, "area": true, "tiles": forecast["tiles"], "rule_outline": not state.get("battlefield_rule", {}).is_empty()})
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

