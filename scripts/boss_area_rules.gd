extends RefCounted
## area-01: held stamps travel with their source; sky/ground marks stay put.
## Both retain the announced shape; ordinary follow-ups keep live targeting.
const Typed = preload("res://scripts/typed_arrays.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const BurstRules = preload("res://scripts/burst_rules.gd")
const MOVES: Dictionary = {
	"tharokh": ["stonewake", "worldspine_claw", "bedrock_breath", "faultline"],
	"vyraketh": ["cinderfall", "kindle_ground", "cinder_maw", "crownfire"],
	"vaeloryx": ["razor_dive", "hollow_gale", "eye_of_storm"],
	"iskaldra": ["shatterstorm", "whiteout_lance"],
	"noctyrax": ["night_coil", "starless_breath", "last_eclipse"],
	"zekarion": ["skybreak"],
	"ashen_reaver": ["raking_flame", "hooked_sweep", "executioners_fall"],
	"storm_cantor": ["lay_the_choir"], "gallows_roc": ["hookwind", "razor_pinion"],
	"last_lamplighter": ["mourning_hook"], "craghide": ["groundsplit"],
	"bell_tender": ["connector"], "briar_weaver": ["thornwall"]}
const FIELD: String = "area_fixed_tiles"
const RELATIVE: Dictionary = {
	"tharokh": ["stonewake", "worldspine_claw", "bedrock_breath"],
	"vyraketh": ["cinderfall"], "vaeloryx": ["razor_dive", "hollow_gale", "eye_of_storm"],
	"iskaldra": ["shatterstorm", "whiteout_lance"], "noctyrax": ["night_coil", "starless_breath"],
	"ashen_reaver": ["raking_flame", "hooked_sweep", "executioners_fall"],
	"gallows_roc": ["hookwind", "razor_pinion"], "last_lamplighter": ["mourning_hook"],
	"storm_cantor": ["lay_the_choir"], "bell_tender": ["connector"]}
const RELATIVE_KIND: String = "relative_to_source"
const FIXED_KIND: String = "fixed_at_announcement"
const FORECAST_RECEIPT: String = "_pass_forecast_relative_areas"

static func selected(enemy: Dictionary, intent: Dictionary) -> bool:
	return (MOVES.get(str(enemy.get("type", "")), []) as Array).has(str(intent.get("id", "")))

static func kind_for(enemy_type: String, move: String) -> String:
	if not (MOVES.get(enemy_type, []) as Array).has(move): return ""
	return RELATIVE_KIND if (RELATIVE.get(enemy_type, []) as Array).has(move) else FIXED_KIND

# Raw library/pre-battle rows have no declared footprint. Annotate a private
# presentation copy so the same keyword appears before and during the fight.
static func presentation_intent(enemy_type: String, intent: Dictionary) -> Dictionary:
	if kind_for(enemy_type, str(intent.get("id", ""))) != FIXED_KIND: return intent
	var result: Dictionary = intent.duplicate(true)
	for action: Dictionary in result.get("actions", []):
		if area_action(action): action["area_targeting"] = FIXED_KIND
	return result

static func marked(action: Dictionary) -> bool:
	return str(action.get("area_targeting", "")) == FIXED_KIND or fixed(action)

static func area_action(action: Dictionary) -> bool:
	return action.has("committed_shape") or action.has("guardian_shape") or str(action.get("type", "")) in ["cinder_marks", "lightning_strikes", "terrain_burst", "detonate_cinders", "umbra_eclipse", "upheaval_mark"]

static func held(action: Dictionary) -> bool:
	return action.has(FIELD)

static func relative(action: Dictionary) -> bool:
	return held(action) and str(action.get("area_targeting", FIXED_KIND)) == RELATIVE_KIND

static func fixed(action: Dictionary) -> bool:
	return held(action) and not relative(action)

static func has_held(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions", []):
		if held(action): return true
	return false

static func shown(action: Dictionary) -> Array[Vector2i]:
	return Typed.vector2i(action.get(FIELD, []))

static func at_anchor(action: Dictionary, anchor: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var offset: Vector2i = anchor - Vector2i(action.get("area_planned_origin", anchor)) if relative(action) else Vector2i.ZERO
	for tile: Vector2i in shown(action): result.append(tile + offset)
	return result

static func forecast_signature(intent: Dictionary) -> Array:
	for action: Dictionary in intent.get("actions", []):
		# shown() may borrow the intent's typed tile array. Published stamps
		# and forecast receipts own their signature.
		if relative(action): return [str(intent.get("id", "")), shown(action).duplicate(), action.get("area_planned_origin"), action.get("area_announcement_origin")]
	return []

# Opt-in receipt on the PASS-loss copy only. Planning copies own deep copies of
# this map. Keep the full stamp at the resolved anchor (including inert cells),
# alongside its contact receipt; future board changes must not reshape it.
static func record_forecast(state: Dictionary, enemy: Dictionary, action: Dictionary, tiles: Array[Vector2i]) -> void:
	if not state.has(FORECAST_RECEIPT) or not relative(action): return
	var key: String = "enemy_%d" % int(enemy["id"])
	var records: Dictionary = state[FORECAST_RECEIPT]
	if records.has(key): return
	var warning: Array[Vector2i]
	for tile: Vector2i in at_anchor(action,enemy["pos"]):
		if preload("res://scripts/path_utils.gd").is_in_bounds(state["grid"],tile): warning.append(tile)
	records[key] = {"signature":forecast_signature(enemy.get("intent", {})), "anchor":enemy["pos"], "tiles":warning, "struck_tiles":tiles.duplicate()}

# Keep existing terrain victims (Faultline's own centers, for example). A newly
# impassable mark is inert; it must never trim the rest of a lane behind it.
static func strike_tiles(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var original: Dictionary = action.get("area_terrain_at_declaration", {})
	var anchor: Vector2i = action.get("area_planned_origin", Vector2i.ZERO)
	if relative(action):
		var source: int = engine._enemy_index_for_id(state, int(action.get("area_source_id", -1)))
		if source >= 0: anchor = state["enemies"][source]["pos"]
	var offset: Vector2i = anchor - Vector2i(action.get("area_planned_origin", anchor)) if relative(action) else Vector2i.ZERO
	for tile: Vector2i in at_anchor(action, anchor):
		if not engine._tile_is_passable(state, tile): continue
		var index: int = engine._terrain_index_at_tile(state, tile)
		if index >= 0:
			var terrain: Dictionary = state["terrain"][index]
			if not original.has(tile - offset) or original[tile - offset] != terrain.get("id", terrain.get("pos")): continue
		result.append(tile)
	return result

static func freeze(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	if not selected(enemy, intent): return intent
	for action: Dictionary in intent.get("actions", []):
		if not area_action(action): continue
		if held(action):
			_stamp_metadata(enemy, intent, action)
			continue
		var affected: Array[Vector2i]
		if action.has("declared_tiles"): affected.assign(action["declared_tiles"])
		elif action.has("committed_shape") or action.has("guardian_shape"):
			affected.assign(intent.get("committed_plan", {}).get("projected_attack", []))
		elif str(action["type"]) == "upheaval_mark": affected = engine.BrambleRules.tiles(engine, state, enemy, action)
		elif str(action["type"]) == "lightning_strikes": affected = engine._lightning_strike_tiles(state, enemy, action)
		else: affected = engine._boss_action_threat_tiles(state, enemy, action)
		action[FIELD] = affected
		_stamp_metadata(enemy, intent, action)
		action["area_terrain_at_declaration"] = {}
		for tile: Vector2i in affected:
			var index: int = engine._terrain_index_at_tile(state, tile)
			if index >= 0:
				var terrain: Dictionary = state["terrain"][index]
				action["area_terrain_at_declaration"][tile] = terrain.get("id", terrain.get("pos"))
		if str(action["type"]) == "lightning_strikes": action["no_conduction"] = true
		if str(action["type"]) == "detonate_cinders":
			var fuel: Array[Vector2i]
			for entry: Dictionary in engine._cinder_fire_entries(state, int(enemy["id"])): fuel.append(entry["pos"])
			action["area_fuel_tiles"] = fuel
			action["area_fuel_sources"] = {}
			for tile: Vector2i in fuel: action["area_fuel_sources"][tile] = Surfaces.surface_at(state, tile).get("elemental_source", {}).duplicate(true)
		if str(action["type"]) == "terrain_burst":
			var fuel: Array[Dictionary]
			for stone: Dictionary in engine.DragonCombatRules.owned_stone(state, int(enemy["id"])):
				fuel.append({"pos": stone["pos"], "identity": stone.get("id", stone["pos"])})
			action["area_stone_fuel"] = fuel
	return intent

# Old geometry's declared_origin is the planned attack anchor, not necessarily
# the body's announcement position. A saved path retains both ends. With no
# historical origin, the stored footprint is treated as announced here.
static func _stamp_metadata(enemy: Dictionary, intent: Dictionary, action: Dictionary) -> void:
	if action.has("area_targeting"): return
	var is_relative: bool = kind_for(str(enemy.get("type", "")), str(intent.get("id", ""))) == RELATIVE_KIND
	action["area_targeting"] = RELATIVE_KIND if is_relative else FIXED_KIND
	action["area_source_id"] = int(enemy["id"])
	if not is_relative: return
	var plan: Dictionary = intent.get("committed_plan", {})
	var path: Array = plan.get("path", [])
	var moving: bool = (intent.get("actions",[]) as Array).any(func(value: Dictionary) -> bool: return str(value.get("type","")) in ["move_toward","move_away"] and int(value.get("range",0))>0)
	var known: bool = not path.is_empty() or (not moving and action.get("declared_origin") is Vector2i)
	var announced: Vector2i = enemy["pos"]
	var planned: Vector2i = enemy["pos"]
	if known:
		announced = path[0] if not path.is_empty() else action["declared_origin"]
		var saved: Variant = action.get("declared_origin",plan.get("destination"))
		planned = saved if saved is Vector2i else path[-1] if not path.is_empty() else announced
	action["area_announcement_origin"] = announced
	action["area_planned_origin"] = planned
	action["area_origin_basis"] = "stored_announcement" if known else "current_position_fallback"

static func stone_fuel(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for held: Dictionary in action.get("area_stone_fuel", []):
		var index: int = engine._terrain_index_at_tile(state, held["pos"])
		if index < 0: continue
		var stone: Dictionary = state["terrain"][index]
		if stone.get("id", stone["pos"]) == held["identity"]: result.append(held["pos"])
	return result

static func cinder_fuel(state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var marked_sources: Dictionary = action.get("area_fuel_sources", {})
	for tile: Vector2i in Typed.vector2i(action.get("area_fuel_tiles", [])):
		if Surfaces.has_surface(state, tile, "fire") and marked_sources.get(tile, {}) == Surfaces.surface_at(state, tile).get("elemental_source", {}):
			result.append(tile)
	return result

static func pending_tiles(intent: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for action: Dictionary in intent.get("actions", []):
		for tile: Vector2i in shown(action):
			if not result.has(tile): result.append(tile)
	return result

static func pending_wall_tiles(enemy: Dictionary) -> Array[Vector2i]:
	# Older Upheaval payloads already hold fixed marks. The optional flag
	# selects a rise resolver, so deriving the warning must not change it.
	var result: Array[Vector2i]
	if str(enemy.get("type", "")) == "briar_weaver":
		result.assign(enemy.get("upheaval_pending", {}).get("marks", []))
	return result

static func announced_tiles(enemy: Dictionary, engine: RefCounted = null, state: Dictionary = {}) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var intent: Dictionary = enemy.get("intent", {})
	var anchor: Vector2i = enemy["pos"]
	if engine != null and intent.has("committed_plan") and has_held(intent):
		var plan: Dictionary = engine.enemy_intent_plan(state, engine._enemy_index_for_id(state, int(enemy["id"])), intent)
		anchor = plan.get("destination", anchor)
	for action: Dictionary in intent.get("actions", []):
		for tile: Vector2i in at_anchor(action, anchor):
			if not state.is_empty() and not preload("res://scripts/path_utils.gd").is_in_bounds(state["grid"], tile): continue
			if not result.has(tile): result.append(tile)
	for tile: Vector2i in pending_wall_tiles(enemy):
		if not result.has(tile): result.append(tile)
	return result

# A save has no historical board to re-aim against. Its stored declared tiles
# (including an empty array) win. For legacy detonations without stored tiles,
# snapshot the saved fuel/refuges once, before the first post-resume input.
static func migrate_combat(value: Variant) -> void:
	if not value is Dictionary: return
	var state: Dictionary = value
	if state.is_empty() or not state.has("grid"): return
	var engine: RefCounted = load("res://scripts/combat_engine.gd").new()
	for enemy: Dictionary in state.get("enemies", []):
		var intent: Dictionary = enemy.get("intent", {})
		if not selected(enemy, intent): continue
		# Pending Thornwall already owns its stored marks. A raw Thornwall
		# action carries no announcement to recover from the load-time board.
		if str(enemy.get("type", "")) == "briar_weaver" and not (intent.get("actions", []) as Array).any(_has_stored_tiles): continue
		freeze(engine, state, enemy, intent)
		for action: Dictionary in intent.get("actions", []):
			_migrate_burst_stamp(action)
		# Some older saves held tiles without a route. Seal the existing planner's
		# saved-board offset once, before a hover can re-aim the missing body plan.
		if not intent.has("committed_plan") and not forecast_signature(intent).is_empty():
			enemy["intent"] = engine.GuardianCombatRules.commit(engine,state,engine._enemy_index_for_id(state,int(enemy["id"])),intent)

static func _has_stored_tiles(action: Dictionary) -> bool:
	return held(action) or action.has("declared_tiles")

static func _migrate_burst_stamp(action: Dictionary) -> void:
	var sources: Array[Vector2i]
	match str(action.get("type", "")):
		"detonate_cinders":
			sources.assign(Typed.vector2i(action.get("area_fuel_tiles", [])))
		"terrain_burst":
			if not bool(action.get("consume_terrain", true)): return
			for stone: Dictionary in action.get("area_stone_fuel", []):
				sources.append(stone["pos"])
		_:
			return
	if sources.is_empty(): return
	# Trim the saved warning against its original sources. A spent source or
	# a tile that became inert since announcement still belongs to the stamp.
	var cross_lookup: Dictionary = {}
	for source: Vector2i in sources:
		for offset: Vector2i in BurstRules.OFFSETS:
			cross_lookup[source + offset] = true
	var tiles: Array[Vector2i]
	for tile: Vector2i in shown(action):
		if cross_lookup.has(tile): tiles.append(tile)
	action[FIELD] = tiles
