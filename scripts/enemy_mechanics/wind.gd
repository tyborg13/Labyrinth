extends RefCounted

# Compatibility import for WindView and enemy Call the Wind. Gust owns the mover.
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")

static func direction(engine: RefCounted, state: Dictionary, enemy: Dictionary, scan: int = 3) -> Vector2i:
	return Gust.direction(engine, state, enemy, scan)

static func hazard(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return Gust.hazard(engine, state, tile)

static func commit(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	return Gust.commit(engine, state, enemy, intent)

static func announced_direction(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Vector2i:
	return Gust.announced_direction(engine, state, enemy, action)

static func active(engine: RefCounted, state: Dictionary) -> Dictionary:
	return Gust.active(engine, state)

static func persistent(engine: RefCounted, state: Dictionary, value: Dictionary) -> bool:
	return Gust.persistent(engine, state, value)

static func room_sourced(state: Dictionary, value: Dictionary) -> bool:
	return Gust.room_sourced(state, value)

static func anchored(state: Dictionary, kind: String, unit: Dictionary, source_id: int = -1) -> bool:
	return Gust.anchored(state, kind, unit, source_id)

static func force_anchored(engine: RefCounted, state: Dictionary, kind: String, id: int) -> bool:
	return Gust.force_anchored(engine, state, kind, id)

static func actors(state: Dictionary, axis: Vector2i, source_id: int = -1) -> Array[Dictionary]:
	return Gust.actors(state, axis, source_id)

static func engine_key(actor: Dictionary) -> String:
	return Gust.engine_key(actor)

static func push_all(engine: RefCounted, state: Dictionary, value: Dictionary) -> Dictionary:
	return Gust.push_all(engine, state, value)

static func preview(engine: RefCounted, state: Dictionary, value: Dictionary) -> Dictionary:
	return Gust.preview(engine, state, value)

static func plan(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, disabled: bool) -> Dictionary:
	return Gust.plan(engine, state, index, intent, disabled)

static func projected_player_force(engine: RefCounted, state: Dictionary, enemy_id: int, action: Dictionary) -> Dictionary:
	return Gust.projected_player_force(engine, state, enemy_id, action)

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	return Gust.animation_step(engine, before, after, index, action)

static func choose_intent(engine: RefCounted, state: Dictionary, index: int, intents: Array, rng: RandomNumberGenerator) -> Dictionary:
	return Gust.choose_intent(engine, state, index, intents, rng)

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary) -> Dictionary:
	Rules.install_call(engine, state, index, action)
	return state

static func install_headwind(engine: RefCounted, state: Dictionary, axis: Vector2i, tiles: int) -> void:
	var instance: Dictionary = Rules.instance_for("snare_air")
	instance["dials"]["tiles"] = tiles
	instance["locked_direction"] = axis
	Rules.install(engine, state, instance)

static func clear_dead_source(engine: RefCounted, state: Dictionary) -> void:
	Rules.clear_dead_source(state)
	Gust.clear_dead_source(engine, state)

static func lock_legacy_intents(engine: RefCounted, state: Dictionary) -> void:
	Gust.lock_legacy_intents(engine, state)
	# Absence of the additive rule field in an old save means no rule,
	# including its legacy drawing mirror: do not leave a non-firing wind chip.
	if not state.has("battlefield_rule"): state.erase("wind")
	Rules.prepare(engine, state)

# Kept for standalone primitive callers. Production passes the acting source ID
# explicitly to complete_source_turn, including skipped and legacy batch turns.
static func end_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	Rules.adopt_wind(engine, state)
	var source_id: int = int(state.get("current_actor", {}).get("enemy_id", state.get("wind", {}).get("source_id", -1)))
	return Rules.dispatch(engine, state, "after_source_turn", source_id, "", steps)

static func complete_turn(engine: RefCounted, state: Dictionary, steps: Array[Dictionary]) -> Dictionary:
	state = end_turn(engine, state, steps)
	return state
