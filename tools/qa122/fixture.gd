extends RefCounted
## Shared, deterministic combat board and compact receipts from the live engine.

const Seed: int = 122017
const BoardSize: int = 11
const Health: int = 100
const Hero := Vector2i(4, 5)
const Foe := Vector2i(5, 5)
const Invalid := Vector2i(-1, -1)
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const UnitFields: Array = ["hp", "block", "stoneskin", "bleed", "expose", "shock", "freeze",
	"chilled", "petrify", "immobilize", "retaliate", "stagger", "frost_armor", "charge", "summoned", "kindled_bonus", "burrowed", "icefall_tiles", "lob_tiles", "lob_centers"]
const StateFields: Array = ["player_turn_time_spent", "cards_played_this_turn", "card_play_bonus_this_turn",
	"death_bonus_card_plays_this_turn", "player_movement_remaining", "player_movement_capacity",
	"retaliate", "cards_per_turn", "defiance_remaining", "tempo_turn_time_debt", "pending_summon_card_plays", "last_card_destination", "battlefield_rule", "player_turn_restrictions", "turn_flags", "active_rites", "objective"]

static func enemy(pos: Vector2i, id: int = 1, type: String = "crawler") -> Dictionary:
	return {"id": id, "type": type, "pos": pos, "hp": Health, "max_hp": Health, "block": 0,
		"stoneskin": 0, "intent": {}, "footprint": Vector2i.ONE}

static func layout(pos: Vector2i = Foe, type: String = "crawler") -> Dictionary:
	var grid: Array = []
	for y: int in range(BoardSize):
		var row: Array = []
		for x: int in range(BoardSize):
			row.append("wall" if x in [0, BoardSize - 1] or y in [0, BoardSize - 1] else "stone")
		grid.append(row)
	return {"name": "QA122", "type": "combat", "coord": Vector2i(1, 1), "depth": 1,
		"element": "none", "umbra_stage": "clear", "grid": grid, "player_start": Hero,
		"terrain": [], "traps": [], "loot": [], "enemies": [enemy(pos, 1, type)]}

static func state(engine: RefCounted, pos: Vector2i = Foe, type: String = "crawler",
		extra: Dictionary = {}) -> Dictionary:
	var snapshot: Dictionary = {"hp": Health >> 1, "max_hp": Health,
		"deck_cards": ["quick_stab", "quick_stab", "quick_stab", "quick_stab",
			"quick_stab", "quick_stab", "quick_stab", "quick_stab"],
		"hand_size": 5, "cards_per_turn": 3, "relics": []}
	snapshot.merge(extra, true)
	var result: Dictionary = engine.create_combat(Seed, layout(pos, type), snapshot)
	result["current_actor"] = {"kind": "player", "key": "player"}
	return result

static func tile(pos: Vector2i) -> Array:
	return [pos.x, pos.y]

static func tiles(positions: Array) -> Array:
	return positions.map(func(pos: Vector2i) -> Array: return tile(pos))

static func unit(actor: Dictionary) -> Dictionary:
	var result: Dictionary = {"pos": tile(actor.get("pos", Invalid))}
	for field: String in UnitFields:
		if actor.has(field): result[field] = actor[field]
	return result

static func receipt(value: Dictionary) -> Dictionary:
	var result: Dictionary = {"hero": unit(value["player"]), "enemies": {}, "illusions": {},
		"surfaces": {}, "terrain": [], "vision": {}}
	for actor: Dictionary in value.get("enemies", []):
		var record: Dictionary = unit(actor)
		record["type"] = str(actor.get("type", ""))
		result["enemies"][str(actor["id"])] = record
	for actor: Dictionary in value.get("illusions", []):
		result["illusions"][str(actor["id"])] = unit(actor)
	for pos: Vector2i in Surface.tiles(value):
		var ground: Dictionary = Surface.surface_at(value, pos)
		result["surfaces"][Surface.tile_key(pos)] = [ground.get("elemental", ""), ground.get("rubble", false)]
	for terrain: Dictionary in value.get("terrain", []):
		result["terrain"].append([tile(terrain.get("pos", Invalid)), terrain.get("hp", 0)])
	for field: String in StateFields:
		if value.has(field): result[field] = value[field]
	for field: String in ["stage", "vision_bonus", "vision_bonus_activations", "truesight_activations", "light_sources"]:
		if value.get("umbra", {}).has(field): result["vision"][field] = value["umbra"][field]
	var deck: Dictionary = value.get("deck", {})
	result["piles"] = {}
	for pile: String in ["hand", "draw", "discard", "burned", "consumed"]:
		result["piles"][pile] = deck.get(pile, []).size()
	return result.duplicate(true)

static func delta(before: Dictionary, after: Dictionary) -> Dictionary:
	var changes: Dictionary = {}
	for field: String in after:
		if before.get(field) != after[field]:
			changes[field] = [before.get(field), after[field]]
	return changes

static func json_safe(value: Variant) -> Variant:
	match typeof(value):
		TYPE_VECTOR2I: return tile(value)
		TYPE_ARRAY: return value.map(json_safe)
		TYPE_DICTIONARY:
			var converted: Dictionary = {}
			for key: Variant in value:
				converted[str(key)] = json_safe(value[key])
			return converted
	return value
