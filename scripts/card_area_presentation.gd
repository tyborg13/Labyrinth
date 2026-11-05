extends RefCounted

## Shared presentation-only attack delivery. Patterns describe geometry;
## they never own a keyword, and their red squares remain unchanged.
static func attack_type(action: Dictionary, actions: Array = []) -> String:
	if str(action.get("target", "")) == "previous_target":
		# Cyclone Seal inherits the tile selected by its preceding Pull area.
		var previous: Dictionary = {}
		for candidate: Dictionary in actions:
			if candidate == action or str(candidate.get("target", "")) == "previous_target": break
			previous = candidate
		# A standalone step has no card context. The shipped inherited area is
		# Cyclone Seal's remotely selected range-3 tile.
		if previous.is_empty(): return "ranged" if actions.is_empty() else ""
		return attack_type(previous)
	if str(action.get("type", "")) in ["melee", "ranged"]:
		return str(action["type"])
	if str(action.get("aim", "")) == "facing": return "melee"
	var shape: String = str(action.get("committed_shape", action.get("guardian_shape", "")))
	if shape in ["ring", "cross", "crescent", "sweep", "swept_path"]: return "melee"
	return "ranged" if int(action.get("range", 0)) > 1 else "melee"

static func tokens(source: Array, action: Dictionary, actions: Array = [], include_hit: bool = false) -> Array:
	var result: Array = []
	var delivery: String = attack_type(action, actions)
	if delivery.is_empty(): return source # An unresolved inherited target keeps its current presentation.
	var area_action: bool = str(action.get("type", "")) == "aoe" or (str(action.get("type", "")) == "surface" and action.has("guardian_shape"))
	var has_hit: bool = false
	var needs_pierce: bool = false
	for original: Dictionary in source:
		var token: Dictionary = original
		var icon: String = str(token.get("icon", ""))
		if str(token.get("kind", "")) == "aoe_pattern":
			token = _pattern(token)
		elif icon == "aoe" or (area_action and icon == "pierce" and token.has("value")):
			token = token.duplicate(true)
			needs_pierce = needs_pierce or icon == "pierce"
			token["icon"] = delivery
			# Authored rider panels (e.g. Shatter) retain their own wording/term.
			if str(token.get("card_term", "aoe")) == "aoe":
				for key: String in ["tooltip", "card_tooltip", "card_title", "card_term", "glossary_key", "panel_id"]:
					token.erase(key)
			has_hit = true
		elif area_action and icon == delivery:
			has_hit = true
		result.append(token)
	if area_action and include_hit and not has_hit:
		# Status-only areas expose delivery without inventing a 0-damage value.
		result.push_front({"icon": delivery, "tone": "neutral"})
	if needs_pierce: result.append({"icon": "pierce", "tone": "neutral"})
	return result

static func patterns(rows: Array) -> Array:
	var result: Array = []
	for row: Array in rows:
		var copy: Array = []
		for token: Dictionary in row:
			copy.append(_pattern(token) if str(token.get("kind", "")) == "aoe_pattern" else token)
		result.append(copy)
	return result

static func _pattern(source: Dictionary) -> Dictionary:
	var token: Dictionary = source.duplicate(true)
	token["card_keyword"] = false
	# Native card-chip hover and the inspection stack both omit this topic.
	token["tooltip"] = ""
	token["card_tooltip"] = ""
	for key: String in ["card_title", "card_term", "glossary_key", "panel_id"]: token.erase(key)
	return token
