extends "res://tools/fel01/policy.gd"
## Keep fel-01's legal offers and resolver scoring. With diagnostic Health,
## favor forward progress when the same movement choices repeat.

const REVISIT_COST := 0.65
const HIDDEN_DISTANCE_VALUE := 0.5
const DIAGNOSTIC_HEALTH := 9999

var _fight: Vector2i
var _last_position := Vector2i(-1, -1)
var _visits: Dictionary


func choose(scene: Node, candidates: Array) -> Dictionary:
	var run: Dictionary = scene._run_state
	if run.get("mode") == "pre_battle":
		for offer: Dictionary in candidates:
			if offer["kind"] == "begin_combat": return offer
	if run.get("mode") == "combat":
		var room: Vector2i = run["current_room"]
		if _fight != room:
			_fight = room
			_visits.clear()
			_last_position = Vector2i(-1, -1)
		var tile: Vector2i = scene._combat_state["player"]["pos"]
		if _last_position != tile:
			_visits[tile] = int(_visits.get(tile, 0)) + 1
			_last_position = tile
	return super.choose(scene, candidates)


func _value(engine: RefCounted, before: Dictionary, after: Dictionary, visible: Array) -> float:
	var score: float = super._value(engine, before, after, visible)
	var origin: Vector2i = before["player"]["pos"]
	var destination: Vector2i = after["player"]["pos"]
	if origin == destination: return score
	score += REVISIT_COST * (int(_visits.get(origin, 0)) - int(_visits.get(destination, 0)))
	if visible.is_empty():
		var hidden: Array[Vector2i]
		for enemy: Dictionary in before.get("enemies", []):
			if int(enemy.get("hp", 0)) > 0: hidden.append(enemy["pos"])
		score += HIDDEN_DISTANCE_VALUE * (_distance(origin, hidden) - _distance(destination, hidden))
	return score


func _forecast_cost(engine: RefCounted, state: Dictionary) -> float:
	if int(state.get("player", {}).get("max_hp", 0)) >= DIAGNOSTIC_HEALTH: return 0.0
	return super._forecast_cost(engine, state)
