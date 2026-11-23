extends RefCounted
const Geometry = preload("res://scripts/battlefield_rules/geometry.gd")
const Hit = preload("res://scripts/battlefield_rules/hit.gd")

static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	var dials: Dictionary = instance.get("dials", {}) as Dictionary
	if int(dials.get("damage", -1)) < 0:
		return "Frostbite requires nonnegative damage"
	return "Frostbite requires nonnegative Stagger" if int(dials.get("stagger", 0)) < 0 else ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	# pla-06: Freeze is cut; Frostbite is its Ice hit only (Ice Exposes on contact).
	var dials: Dictionary = instance["dials"]
	var action: Dictionary = {"type": "aoe", "element": "ice", "damage": int(dials["damage"])}
	if dials.has("stagger"):
		action["stagger"] = int(dials["stagger"])
	# Primitive: Ice area hit on the current Ice tiles. The attack planner owns
	# targetability, including buried units; there are no rule-specific exemptions.
	var tiles: Array[Vector2i] = Geometry.affected_tiles(engine, state, instance)
	return Hit.resolve(engine, state, instance, action, tiles)

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
