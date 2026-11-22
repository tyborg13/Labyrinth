extends RefCounted
const Geometry = preload("res://scripts/battlefield_rules/geometry.gd")
const Hit = preload("res://scripts/battlefield_rules/hit.gd")

# pla-01: storms never Chain; damage is the only dial. A legacy saved "chain"
# dial is ignored (and dropped on load by dispatcher.repair_saved_rule).
static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	var dials: Dictionary = instance.get("dials", {})
	return "Lightning Storm requires nonnegative damage" if int(dials.get("damage", -1)) < 0 else ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary, trace: Dictionary = {}) -> Dictionary:
	var tiles: Array[Vector2i] = Geometry.affected_tiles(engine, state, instance)
	if tiles.is_empty(): return state
	var action: Dictionary = {"type": "lightning_strikes", "element": "lightning", "damage": int(instance["dials"]["damage"]), "_battlefield_all_units": true}
	# Primitive: full Lightning Strikes resolution, without Chain. No surface rider:
	# ordinary strikes do not create or replace the Electrified field.
	return Hit.resolve(engine, state, instance, action, tiles, trace)

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
