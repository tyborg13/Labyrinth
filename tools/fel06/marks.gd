extends RefCounted
## Collect each source before the renderer combines overlapping badges.

const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const Burrow = preload("res://scripts/enemy_mechanics/burrow_view.gd")
const Icefall = preload("res://scripts/enemy_mechanics/icefall_view.gd")
const Lob = preload("res://scripts/enemy_mechanics/marked_strike.gd")
const Red = preload("res://scripts/pass_forecast_red_tiles.gd")
const Threats = preload("res://scripts/threat_tiles.gd")


static func collect(scene: Node, board: Control, state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var engine: RefCounted = scene.get("_combat_engine")
	for meteor: Dictionary in state.get("meteor_marks", []):
		_add(result, meteor.get("tiles", []), "Meteorfall", str(meteor.get("source", meteor.get("card_id", "player"))),
			meteor.get("damage"), "Meteorfall", meteor)
	for mark: Dictionary in Burrow.marks(state):
		_add(result, [mark["tile"]], "Erupt", "enemy_%d" % mark["enemy_id"], mark["damage"], "Erupt", mark)
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) <= 0: continue
		_enemy_marks(result, engine, state, enemy)
	var rule: Dictionary = Rules.active(state)
	if rule.get("rule") == "upheaval":
		var origin: Dictionary = rule.get("source", {})
		var source: String = "enemy_%d" % int(origin["id"]) if origin.get("kind") == "enemy" else "room"
		_add(result, rule.get("marks", []), "Pending wall", source, rule.get("dials", {}).get("health"),
			"", rule)
	var shown: Dictionary = board.get("presentation")
	var threats: Array = shown.get(Threats.REST_KEY, {}).get("threats", [])
	threats = threats + Red.floor_rows(shown) + Threats.marker_rows(shown)
	for threat: Dictionary in threats:
		var source: String = str(threat.get("key", ""))
		var forecast: Dictionary = {}
		var number: Variant
		for enemy: Dictionary in state.get("enemies", []):
			if source == "enemy_%d" % int(enemy["id"]):
				var actions: Array = enemy.get("intent", {}).get("actions", [])
				forecast = {"intent": enemy.get("intent", {}).get("name"), "actions": actions}
				var action: Dictionary = threat.get("plan", {}).get("projected_attack_action", {})
				number = action.get("damage")
				break
		var tiles: Array = threat.get("tiles", []) + threat.get("marker_tiles", [])
		for tile: Vector2i in tiles:
			var local: Array = result.get(tile, [])
			if local.any(func(mark: Dictionary) -> bool: return mark["source"] == source): continue
			_add(result, [tile], "Target or aim" if source.begins_with("enemy_") else source,
				source, number, "", {"forecast": forecast, "threat": threat} if source.begins_with("enemy_") else threat,
				not source.begins_with("enemy_"))
	return result


static func _enemy_marks(result: Dictionary, engine: RefCounted, state: Dictionary, enemy: Dictionary) -> void:
	var source: String = "enemy_%d" % int(enemy["id"])
	var intent: Dictionary = enemy.get("intent", {})
	var ice: Array = enemy.get("icefall_tiles", [])
	if not ice.is_empty():
		_add(result, ice, "Icefall", source, Icefall.landing_damage(state, enemy), "Icefall", {})
	var held: Array = enemy.get("lob_tiles", [])
	var lob_tiles: Array = held
	var centers: Array = enemy.get("lob_centers", [enemy.get("lob_center")])
	if held.is_empty() and (intent.get("actions", []) as Array).any(func(action: Dictionary) -> bool: return action.get("type") == "lob_mark") and engine.is_enemy_visible_to_player(state, enemy):
		var aiming: Dictionary = Lob.aiming_forecast(engine, state, enemy)
		lob_tiles = aiming.get("tiles", [])
		centers = aiming.get("centers", [])
	if not lob_tiles.is_empty():
		var landing: Dictionary = Lob.landing_action(engine, state, enemy)
		for tile: Vector2i in lob_tiles:
			var center: bool = centers.has(tile)
			_add(result, [tile], "Lob", source, landing["center_damage" if center else "arm_damage"],
				"Lob Slag", {"center": center, "held": not held.is_empty()})
	var anchor: Vector2i = enemy["pos"]
	if intent.has("committed_plan") and Areas.has_held(intent):
		var plan: Dictionary = engine.enemy_intent_plan(state, engine._enemy_index_for_id(state, int(enemy["id"])), intent)
		anchor = plan.get("destination", anchor)
	for action: Dictionary in intent.get("actions", []):
		if not Areas.held(action): continue
		var fixed: bool = Areas.fixed(action)
		_add(result, Areas.at_anchor(action, anchor), "Marked" if fixed else "Target or aim",
			source, _number(action), "Marked" if fixed else "", action)
	_add(result, Areas.pending_wall_tiles(enemy), "Pending wall", source, null, "Marked", enemy.get("upheaval_pending", {}))


static func _number(action: Dictionary) -> Variant:
	for key: String in ["damage", "amount", "health", "value"]:
		if action.has(key): return action[key]
	return null


static func _add(result: Dictionary, tiles: Array, kind: String, source: String, number: Variant,
		title: String, raw: Dictionary, hazard: bool = false) -> void:
	for tile: Vector2i in tiles:
		var entries: Array = result.get_or_add(tile, [])
		var mark: Dictionary = {"kind": kind, "source": source, "number": number, "title": title, "raw": raw, "hazard": hazard}
		if not entries.has(mark): entries.append(mark)
