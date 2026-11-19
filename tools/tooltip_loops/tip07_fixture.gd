extends RefCounted
## Board setups and receipt checks for the three force recordings.
const Combat = preload("res://scripts/hero_facing_combat.gd")
const Data = preload("res://scripts/game_data.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Events = preload("res://tools/tooltip_loops/tip06_checks.gd")

const PUSH: String = "push_card"
const PULL: String = "pull_card"
const COLLISION: String = "collision_push"
const IDS: Array = [PUSH, PULL, COLLISION]
const TERMS: Dictionary = {PUSH: "push", PULL: "pull", COLLISION: "collision"}
const CARDS: Dictionary = {PUSH: "haft_shove", PULL: "yank", COLLISION: "haft_shove"}
const EQUIPMENT: Dictionary = {PUSH: "war_maul", PULL: "grapple_hook", COLLISION: "war_maul"}
const BIOME: String = "stone"
const ENEMY: String = "crawler"
const PATCH := Rect2i(0, 0, 5, 3)
const HERO := Vector2i(0, 2)
const PUSH_TARGET := HERO + Vector2i.RIGHT
const BLOCKER := HERO + Vector2i.RIGHT * 3
const COLLISION_END := HERO + Vector2i.RIGHT * 2
const PULL_START_DISTANCE: int = 4
const PULL_TARGET := HERO + Vector2i.RIGHT * PULL_START_DISTANCE
const PULL_TILES: int = 3
const PULL_DAMAGE: int = 3
const PUSH_TILES: int = 2

static func configure(layout: Dictionary, id: String) -> Dictionary:
	for row: Array in layout["grid"]:
		row.resize(PATCH.size.x)
		row.fill("stone")
	layout["player_start"] = HERO
	layout["element"] = "none"
	var units: Array = [[ENEMY, PULL_TARGET if id == PULL else PUSH_TARGET]]
	if id == COLLISION:
		units.append([ENEMY, BLOCKER])
	return {"units": units, "card": CARDS[id]}

static func plan(fixture: Dictionary, engine: RefCounted) -> Dictionary:
	var before: Dictionary = fixture["state"]
	var card: String = fixture["card"]
	var action_type: String = "pull" if fixture["id"] == PULL else "push"
	var target: Vector2i = before["enemies"][0]["pos"]
	var beats: Array[Dictionary]
	for action: Dictionary in engine.card_play_actions(card, before):
		if action["type"] != action_type:
			continue
		if not engine.player_action_can_resolve(before, action) or not engine.valid_targets_for_player_action(before, action).has(target):
			break
		beats.append(preload("res://tools/tooltip_loops/tip03_fixture.gd").player_beat(engine, before, action, target, card))
		return {"beats": beats, "final": beats[0]["after"], "force_loop": true}
	return {"beats": beats, "final": before}

static func collision_events(before: Dictionary, after: Dictionary) -> Array[Dictionary]:
	return Events.events(before, after, "force_collision")

static func validate(fixture: Dictionary, result: Dictionary) -> Array[String]:
	var failures: Array[String]
	var id: String = fixture["id"]
	var before: Dictionary = fixture["state"]
	var after: Dictionary = result["final"]
	var count: int = 2 if id == COLLISION else 1
	if result["beats"].size() != 1 or before["enemies"].size() != count or after["enemies"].size() != count:
		failures.append(id + ": one legal card action must resolve with the fixture's actors")
		return failures
	var action: Dictionary = result["beats"][0]["action"]
	var mover: Dictionary = before["enemies"][0]
	var landed: Dictionary = after["enemies"][0]
	var start: Vector2i = mover["pos"]
	var end: Vector2i = landed["pos"]
	var direction := Vector2i.LEFT if id == PULL else Vector2i.RIGHT
	var amount: int = PULL_TILES if id == PULL else PUSH_TILES
	var steps: int = 1 if id == COLLISION else amount
	var expected_start: Vector2i = PULL_TARGET if id == PULL else PUSH_TARGET
	if before["player"]["pos"] != HERO or after["player"]["pos"] != HERO or start != expected_start or end != start + direction * steps or int(action["amount"]) != amount:
		failures.append(id + ": must travel %d tiles on the straight line from %s" % [steps, expected_start])
	for step: int in range(1, steps + 1):
		var tile: Vector2i = start + direction * step
		if not Paths.is_passable(before["grid"], tile) or not before["terrain"].is_empty() or not before["surfaces"].is_empty():
			failures.append(id + ": travel must use open floor")
	for actor: Dictionary in before["enemies"]:
		var health: int = Data.enemy_def(actor["type"])["max_hp"]
		if actor["hp"] != health or actor["max_hp"] != health:
			failures.append(id + ": Health must come from the enemy definition")
	var collisions: Array[Dictionary] = collision_events(before, after)
	var direct_damage: int = int(action["damage"])
	if id == PULL and direct_damage != PULL_DAMAGE:
		failures.append(id + ": Yank must deal 3 damage")
	if id != COLLISION:
		if not collisions.is_empty() or mover["hp"] - landed["hp"] != direct_damage:
			failures.append(id + ": only the card's direct damage should be applied")
		return failures
	var blocker: Dictionary = before["enemies"][1]
	var blocker_after: Dictionary = after["enemies"][1]
	var damage: int = Data.fixed_point_amount(Combat.FORCE_COLLISION_DAMAGE_PER_TILE)
	if collisions.size() != 1 or blocker["pos"] != BLOCKER or blocker_after["pos"] != BLOCKER:
		failures.append(id + ": must hit the stationary second enemy exactly once")
	else:
		var event: Dictionary = collisions[0]
		if event["force"] != "push" or event["tile"] != COLLISION_END or event["blocked_tile"] != BLOCKER or event["lost_tiles"] != 1 or event["blocker_kind"] != "enemy":
			failures.append(id + ": wrong collision contact or unused Push distance")
		if event["target_damage"] != damage or event["blocker_damage"] != damage or mover["hp"] - landed["hp"] != direct_damage + damage or blocker["hp"] - blocker_after["hp"] != damage:
			failures.append(id + ": both enemies must lose the real one-tile Collision damage")
	return failures
