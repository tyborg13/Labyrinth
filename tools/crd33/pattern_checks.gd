extends RefCounted
## Measure actual single-area effects on an open board that includes the
## displayed footprint and neighboring control tiles.
const Fight = preload("res://tools/crd33/fight.gd")
const Data = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const AIM_TILE := Vector2i(4, 4)
const HERO_TILE := Vector2i(4, 5)
const RADIUS := 2
const RESERVE_ENEMY_TILE := Vector2i(7, 7)

static func measure(fight: Fight, id: String, legacy: bool) -> Dictionary:
	var card: Dictionary = Data.card_def(id, legacy)
	var actions: Array = card.get("actions", [])
	var areas: Array = actions.filter(func(a: Dictionary) -> bool:
		return a.has("pattern") and str(a.get("type", "")) in ["aoe", "surface", "outcrop"])
	if areas.size() != 1 or actions[0] != areas[0]:
		return {}
	var area: Dictionary = areas[0]
	var kind: String = area["type"]
	var targeted: bool = int(area.get("range", 0)) > 0
	var center: Vector2i = AIM_TILE if targeted else HERO_TILE
	var enemies: Array[Vector2i]
	if kind == "aoe":
		for y: int in range(-RADIUS, RADIUS + 1):
			for x: int in range(-RADIUS, RADIUS + 1):
				var tile: Vector2i = center + Vector2i(x, y)
				if tile != HERO_TILE: enemies.append(tile)
	else:
		enemies.append(RESERVE_ENEMY_TILE)
	var state: Dictionary = fight.fresh(enemies)
	state["player"]["pos"] = HERO_TILE
	state[Data.LEGACY_STARTER_CARDS_KEY] = legacy
	var preferred: Array = [AIM_TILE] if targeted else []
	var result: Dictionary = fight.play(state, id, preferred)
	if result.has("blocked") or result["steps"].is_empty(): return {}
	var step: Dictionary = result["steps"][0]
	if targeted and step["tile"] != center: return {}
	var affected: Array = []
	match kind:
		"aoe":
			var before: Array = step["before"]["enemies"]
			for index: int in range(before.size()):
				var after: Dictionary = step["after"]["enemies"][index]
				if before[index] != after and (before[index]["hp"] != after["hp"] or before[index]["expose"] != after["expose"] or before[index]["bleed"] != after["bleed"] or before[index]["delay"] != after["delay"]):
					affected.append(before[index]["pos"])
		"surface":
			affected = Ground.tiles(result["after"], str(area.get("surface", "")))
		"outcrop":
			for terrain: Dictionary in step["after"]["terrain"]: affected.append(terrain["pos"])
	if affected.is_empty(): return {}
	var sampled: Array = []
	for y: int in range(-RADIUS, RADIUS + 1):
		for x: int in range(-RADIUS, RADIUS + 1):
			var tile: Vector2i = center + Vector2i(x, y)
			if tile != HERO_TILE or kind == "surface": sampled.append(tile)
	return {"kind": kind, "center": center, "hero": HERO_TILE, "orientation": step["orientation"],
		"affected": affected, "sampled": sampled}
