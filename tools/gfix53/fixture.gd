extends RefCounted
## Fixed combat layouts adapted from txt-39 and txt-40.

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const SEED: int = 73021
const SIZE: int = 9
const HEALTH: int = 80
const ILLUSION_HEALTH: int = 3
const LIGHT_RANGE: int = 8
const LIGHT_RADIUS: int = 1
const HERO := Vector2i(3, 4)
const NEAR := Vector2i(4, 4)
const ENEMY := Vector2i(5, 4)
const SECOND := Vector2i(6, 4)
const GUARDIAN := Vector2i(7, 6)
const AWAY_LIGHT := Vector2i(7, 4)
const REMOTE_SHADE := Vector2i(7, 2)
const HIDDEN_CRAWLER := Vector2i(1, 4)
const GHOST_TARGET := Vector2i(4, 6)
const SUNPATH_TARGET := Vector2i(6, 4)

static func unit(pos: Vector2i, id: int = 0, kind: String = "crawler") -> Dictionary:
	var health: int = int(Data.enemy_def(kind)["max_hp"])
	return {"id": id, "type": kind, "pos": pos, "hp": health, "max_hp": health}

static func room(enemies: Array) -> Dictionary:
	var grid: Array = []
	for y: int in range(SIZE):
		var row: Array = []
		for x: int in range(SIZE):
			row.append("wall" if x in [0, SIZE - 1] or y in [0, SIZE - 1] else "floor")
		grid.append(row)
	return {"grid": grid, "player_start": HERO, "enemies": enemies}

static func fight(engine: Combat, skills: Array, enemies: Array) -> Dictionary:
	return engine.create_combat(SEED, room(enemies), {
		"hp": HEALTH, "max_hp": HEALTH, "deck_cards": Data.starting_deck(), "skill_ids": skills
	})

static func shadowstep(engine: Combat, blocked: bool) -> Dictionary:
	var enemies: Array = [unit(GUARDIAN, 0, "last_lamplighter"), unit(ENEMY, 1, "wick_shade")]
	if not blocked:
		enemies.append(unit(REMOTE_SHADE, 2, "wick_shade"))
		enemies.append(unit(HIDDEN_CRAWLER, 3))
	var state: Dictionary = fight(engine, [], enemies)
	state["umbra"]["stage"] = "eclipse"
	if blocked:
		state = engine._create_illusion(state, NEAR, ILLUSION_HEALTH)
		state = engine._create_umbra_light_source(state, AWAY_LIGHT, {"radius": LIGHT_RADIUS})
	Rules.install(engine, state, Rules.instance_for("last_lamplighter", 0))
	return state

static func ghost_stride(engine: Combat) -> Dictionary:
	var state: Dictionary = fight(engine, ["ghost_stride"], [unit(ENEMY)])
	return engine.arm_ghost_stride(engine.apply_player_movement(state, NEAR))

static func sunpath(engine: Combat, destination: Vector2i) -> Dictionary:
	var state: Dictionary = fight(engine, ["sunpath"], [unit(SECOND + Vector2i.DOWN)])
	return engine.apply_player_action(state, action(engine, state, "trapdoor"), destination)

static func action(engine: Combat, state: Dictionary, card: String) -> Dictionary:
	return engine.card_def(card, state)["actions"][0]

static func light(engine: Combat, state: Dictionary, tile: Vector2i) -> Dictionary:
	return engine.apply_player_action(state, {"type": "illuminate", "range": LIGHT_RANGE, "radius": LIGHT_RADIUS}, tile)

static func event_count(engine: Combat, state: Dictionary, skill: String) -> int:
	return engine.skill_events(state).filter(func(event: Dictionary) -> bool: return event["skill_id"] == skill).size()

static func sources(state: Dictionary) -> Array:
	return state["umbra"]["light_sources"].map(func(source: Dictionary) -> Vector2i: return source["pos"])
