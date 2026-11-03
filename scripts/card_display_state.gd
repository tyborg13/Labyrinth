extends RefCounted

## Only inputs read by card definitions, keyword pricing and untargeted hand
## damage projection. Logs, currency, deck order and unrelated UI state do not
## invalidate card faces. Spatial inputs remain relevant to surface/light rules.
const FIELDS: Array = [
	"player", "relics", "active_rites", "skill_ids", "card_upgrades", "card_mods",
	"equipped_equipment", "equipment_grafts", "turn_flags", "card_play_modifiers",
	"current_actor", "room_element", "surfaces", "grid", "umbra", "illusions",
	"surface_rule_overrides", "relic_element_knots", "relic_time_reserve"
]
const STATUS_FIELDS: Array = ["block", "stoneskin", "bleed", "expose", "freeze", "shock", "immobilize", "chilled", "petrify", "truesight"]

static func normalise(state: Dictionary) -> Dictionary:
	# Real combat state is already authoritative, including its statuses/position.
	if state.has("player"): return state
	var result: Dictionary = state.duplicate(false)
	var player: Dictionary = (state.get("player_statuses", {}) as Dictionary).duplicate(false)
	player["hp"] = int(state.get("player_hp", 1))
	player["max_hp"] = int(state.get("player_max_hp", 1))
	for field: String in STATUS_FIELDS:
		if state.has("player_" + field): player[field] = state["player_" + field]
	if state.has("player_pos"): player["pos"] = state["player_pos"]
	result["player"] = player
	var progression: Dictionary = state.get("progression", {})
	for field: String in ["skill_ids", "card_upgrades", "card_mods"]:
		if not result.has(field) and progression.has(field): result[field] = progression[field]
	if not result.has("room_element"):
		var coord: Vector2i = state.get("current_room", Vector2i.ZERO)
		var room: Dictionary = (state.get("rooms", {}) as Dictionary).get("%d,%d" % [coord.x, coord.y], {})
		result["room_element"] = str(room.get("element", "none"))
	return result

static func inputs(state: Dictionary) -> Dictionary:
	var normalised: Dictionary = normalise(state)
	var result: Dictionary = {}
	for field: String in FIELDS:
		if normalised.has(field): result[field] = normalised[field]
	return result

static func signature(state: Dictionary) -> int:
	return hash(inputs(state))
