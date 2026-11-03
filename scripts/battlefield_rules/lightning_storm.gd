extends RefCounted
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Hit = preload("res://scripts/battlefield_rules/hit.gd")

static func dial_error(_state: Dictionary, instance: Dictionary) -> String:
	var dials: Dictionary = instance.get("dials", {})
	if int(dials.get("damage", -1)) < 0: return "Lightning Storm requires nonnegative damage"
	return "Lightning Storm chain must be 0..3" if int(dials.get("chain", -1)) not in range(4) else ""

static func resolve_beat(engine: RefCounted, state: Dictionary, instance: Dictionary) -> Dictionary:
	var tiles: Array[Vector2i] = Surfaces.fuel_tiles(state, "electrified")
	if tiles.is_empty(): return state
	var action: Dictionary = {"type": "lightning_strikes", "element": "lightning", "damage": int(instance["dials"]["damage"]), "shock": 1, "chain": int(instance["dials"]["chain"]), "_battlefield_all_units": true}
	# Primitive: full Lightning Strikes / Chain resolution. No surface rider:
	# ordinary strikes do not create or replace the Electrified field.
	return Hit.resolve(engine, state, instance, action, tiles)

static func forecast(engine: RefCounted, state: Dictionary) -> Dictionary:
	return load("res://scripts/battlefield_rules/dispatcher.gd").forecast(engine, state)
