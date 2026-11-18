extends RefCounted
const Geometry = preload("res://scripts/battlefield_rules/geometry.gd")
const Hit = preload("res://scripts/battlefield_rules/hit.gd")

static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	return "Frostbite requires nonnegative damage" if int(instance.get("dials", {}).get("damage", -1)) < 0 else ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var action: Dictionary = {"type": "aoe", "element": "ice", "damage": int(instance["dials"]["damage"]), "_battlefield_frostbite": true}
	# Primitive: Ice area hit on the current Ice tiles. The attack planner owns
	# targetability, including buried units; there are no rule-specific exemptions.
	var tiles: Array[Vector2i] = Geometry.affected_tiles(engine, state, instance)
	return Hit.resolve(engine, state, instance, action, tiles)

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
