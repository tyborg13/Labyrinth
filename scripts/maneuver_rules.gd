extends RefCounted
class_name ManeuverRules

## Wave-4 family B: area forces (`force_area`), Squall's from-center push,
## Swap, forced-movement Fire trails, player self flags (Skate, Rooted,
## Anchored, Fireproof), Cleanse, Block to Stoneskin, Move and Blink riders,
## Petrify and the player's Crystal Mantle. See spec/card_mechanics_maneuver.md.
##
## CombatEngine keeps one small hook per rule. Every movement here goes through
## the engine's own straight-line mover (`_force_move_enemy_from`), arrival
## (`surface_actor_arrival`) and damage functions, so hover previews (which run
## the real resolver on a copy) and commits agree.

const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const DragonBosses = preload("res://scripts/dragon_boss_library.gd")
const ActionIcons = preload("res://scripts/action_icon_library.gd")

const INVALID: Vector2i = Vector2i(-1, -1)
const DIRECTIONS: Array = [Vector2i(0, -1), Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0)]
const FLAGS_KEY: String = "self_flags"
const ACTIVATION_START_KEY: String = "activation_start"
const FLAG_ICE_SKATE: String = "ice_skate"
const FLAG_NO_MOVE: String = "no_move"
const FLAG_ANCHORED: String = "anchored"
const FLAG_FIRE_IMMUNE: String = "fire_immune_turn"
const FLAG_ORDER: Array = [FLAG_NO_MOVE, FLAG_ANCHORED, FLAG_ICE_SKATE, FLAG_FIRE_IMMUNE]
## Badge icons resolve through ActionIcons.SELF_FLAG_ICON_KEYS, the same
## identity the card rows and action steps use (spec/icon_identity_policy.md).
const FLAG_INFO: Dictionary = {
	"ice_skate": {"label": "Skate", "expires": "activation", "fill": "24506a", "border": "b9f3ff",
		"description": "This turn, moving onto Ice costs no movement and Ice doesn't Chill you."},
	"no_move": {"label": "Rooted", "expires": "activation", "fill": "4a3a22", "border": "e1c27a",
		"description": "You can't Move, Blink or Swap for the rest of this turn."},
	"anchored": {"label": "Anchored", "expires": "next_turn", "fill": "2f3d33", "border": "9fd9b4",
		"description": "Until your next turn, you can't be pushed or pulled. Push and Pull against you move you 0 tiles and never collide."},
	"fire_immune_turn": {"label": "Fireproof", "expires": "activation", "fill": "5a2a1c", "border": "ffb38a",
		"description": "Fire doesn't damage you this turn."}
}
const CLEANSE_LABELS: Dictionary = {"bleed": "Bleed", "immobilize": "Immobilize", "chilled": "Chilled", "shock": "Shock"}
const PETRIFY_FIELD: String = "petrify"
const MANTLE_FIELD: String = "frost_armor"
const DIRECT_HIT_CAUSES: Array = ["enemy_attack", "direct_attack"]
const FORCE_AREA_EVENT: String = "force_area"
const SWAP_EVENT: String = "swap"
const PETRIFY_EVENT: String = "petrified"
const CLEANSE_EVENT: String = "statuses_cleansed"
const MANTLE_EVENT: String = "mantle_gained"

# ------------------------------------------------------------------ self flags

static func flags(state: Dictionary) -> Dictionary:
	var value: Variant = state.get(FLAGS_KEY, {})
	return value as Dictionary if typeof(value) == TYPE_DICTIONARY else {}

static func has_flag(state: Dictionary, flag: String) -> bool:
	return flags(state).has(flag)

static func flag_label(flag: String) -> String:
	return str((FLAG_INFO.get(flag, {}) as Dictionary).get("label", flag.capitalize()))

static func flag_tooltip(flag: String) -> String:
	var info: Dictionary = FLAG_INFO.get(flag, {}) as Dictionary
	return "%s\n%s" % [str(info.get("label", flag)), str(info.get("description", ""))]

static func gain_flag(state: Dictionary, action: Dictionary, source_name: String = "") -> void:
	var flag: String = str(action.get("flag", ""))
	if not FLAG_INFO.has(flag):
		return
	var current: Dictionary = flags(state).duplicate(true)
	var entry: Dictionary = (current.get(flag, {}) as Dictionary).duplicate(true)
	var sources: Array = (entry.get("sources", []) as Array).duplicate()
	if not source_name.is_empty() and not sources.has(source_name):
		sources.append(source_name)
	entry["sources"] = sources
	entry["expires"] = str((FLAG_INFO[flag] as Dictionary).get("expires", "activation"))
	current[flag] = entry
	state[FLAGS_KEY] = current

## `activation` flags end in finish_player_activation; `next_turn` flags end
## when prepare_next_player_turn starts the player's following turn.
static func expire_flags(state: Dictionary, expires: String) -> void:
	var current: Dictionary = flags(state).duplicate(true)
	for flag_var: Variant in current.keys():
		if str((current[flag_var] as Dictionary).get("expires", "")) == expires:
			current.erase(flag_var)
	if current.is_empty():
		state.erase(FLAGS_KEY)
	else:
		state[FLAGS_KEY] = current

static func player_skating(state: Dictionary) -> bool:
	return has_flag(state, FLAG_ICE_SKATE)

static func player_fire_immune(state: Dictionary) -> bool:
	return has_flag(state, FLAG_FIRE_IMMUNE)

static func player_anchored(state: Dictionary) -> bool:
	return has_flag(state, FLAG_ANCHORED)

static func player_rooted(state: Dictionary) -> bool:
	return has_flag(state, FLAG_NO_MOVE)

## Rooted forbids every Move, Blink and swap, card or independent movement.
static func movement_blocked(state: Dictionary, action: Dictionary) -> bool:
	return str(action.get("type", "")) in ["move", "blink", "swap", "illusion_swap"] and player_rooted(state)

static func movement_block_reason(state: Dictionary) -> String:
	if player_rooted(state):
		return "Movement unavailable: you are Rooted until the end of this turn."
	return ""

## A cleanse that removes Shock must be playable while Shocked.
static func resolves_while_shocked(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "cleanse" and (action.get("statuses", []) as Array).has("shock")

## Skate: a step onto Ice costs no movement. Returns -1 when the rule is idle.
static func skate_step_cost(state: Dictionary, unit: Dictionary, to: Vector2i) -> int:
	if unit.has("id") or not player_skating(state):
		return -1
	return 0 if Surfaces.has_surface(state, to, "ice") else -1

static func player_badges(state: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	var current: Dictionary = flags(state)
	for flag_var: Variant in FLAG_ORDER:
		var flag: String = str(flag_var)
		if not current.has(flag):
			continue
		var info: Dictionary = FLAG_INFO[flag] as Dictionary
		var tooltip: String = flag_tooltip(flag)
		var sources: Array = (current[flag] as Dictionary).get("sources", []) as Array
		if not sources.is_empty():
			tooltip += "\nFrom: %s" % _joined(sources)
		badges.append({
			"icon": str(ActionIcons.SELF_FLAG_ICON_KEYS.get(flag, "")),
			"count": 0,
			"fill": Color(str(info.get("fill", "333333"))),
			"border": Color(str(info.get("border", "ffffff"))),
			"icon_tint": Color.WHITE,
			"tooltip": tooltip,
			"self_flag": flag
		})
	# Crystal Mantle layers use the board's existing frost_armor status badge.
	return badges

static func _joined(values: Array) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for value: Variant in values:
		parts.append(str(value))
	return ", ".join(parts)

# ------------------------------------------------------------------ activation start

static func record_activation_start(state: Dictionary) -> void:
	var tile: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var surfaces: Array = []
	var element: String = Surfaces.element_at(state, tile)
	if not element.is_empty():
		surfaces.append(element)
	if Surfaces.has_rubble(state, tile):
		surfaces.append("rubble")
	state[ACTIVATION_START_KEY] = {"turn": int(state.get("turn", 1)), "tile": tile, "surfaces": surfaces}

static func started_activation_on(state: Dictionary, surface: String) -> bool:
	var record: Dictionary = state.get(ACTIVATION_START_KEY, {}) as Dictionary if typeof(state.get(ACTIVATION_START_KEY, null)) == TYPE_DICTIONARY else {}
	if record.is_empty() or int(record.get("turn", -1)) != int(state.get("turn", 1)):
		return false
	return (record.get("surfaces", []) as Array).has(surface)

# ------------------------------------------------------------------ force_area

static func force_area_pushes(action: Dictionary) -> bool:
	return int(action.get("push", 0)) > 0

static func force_area_amount(action: Dictionary) -> int:
	return maxi(0, int(action.get("push", 0))) if force_area_pushes(action) else maxi(0, int(action.get("pull", 0)))

static func force_area_targets_tile(action: Dictionary) -> bool:
	return str(action.get("center", "self")) == "target"

static func force_area_center(state: Dictionary, action: Dictionary, target: Vector2i) -> Vector2i:
	if force_area_targets_tile(action):
		return target
	return action.get("_origin_tile", (state.get("player", {}) as Dictionary).get("pos", INVALID))

## Enemies whose footprint lies within Manhattan `radius` of the center, in
## resolution order: pushes farthest first, pulls nearest first (ties by id).
## An enemy standing on the center has no line away from or toward it, so the
## area never moves, collides or Exposes it.
static func force_area_affected(engine: RefCounted, state: Dictionary, action: Dictionary, center: Vector2i, visible_only: bool = false) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if center == INVALID:
		return result
	var radius: int = maxi(0, int(action.get("radius", 1)))
	var pushing: bool = force_area_pushes(action)
	var lookup: Dictionary = engine.umbra_visible_tile_lookup(state) if visible_only else {}
	for raw_enemy: Dictionary in engine._live_enemies(state):
		var enemy: Dictionary = engine._normalized_enemy(raw_enemy)
		if visible_only and not engine.is_enemy_visible_to_player(state, enemy, lookup):
			continue
		var distance: int = Paths.manhattan(engine._closest_enemy_tile_to(enemy, center), center)
		if distance > radius or distance == 0:
			continue
		result.append({"id": int(enemy.get("id", -1)), "distance": distance})
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["distance"]) != int(b["distance"]):
			return int(a["distance"]) > int(b["distance"]) if pushing else int(a["distance"]) < int(b["distance"])
		return int(a["id"]) < int(b["id"])
	)
	return result

static func _force_rider(action: Dictionary) -> Dictionary:
	var rider: Dictionary = {"type": "force_area"}
	for key: String in ["_card_id", "_card_element", "element"]:
		if action.has(key):
			rider[key] = action[key]
	rider["push" if force_area_pushes(action) else "pull"] = force_area_amount(action)
	return rider

## Legality: the area moves or collides at least one visible enemy, or Exposes one.
static func force_area_has_effect(engine: RefCounted, state: Dictionary, action: Dictionary, center: Vector2i) -> bool:
	var affected: Array[Dictionary] = force_area_affected(engine, state, action, center, true)
	if affected.is_empty():
		return false
	if int(action.get("expose", 0)) > 0:
		return true
	var amount: int = force_area_amount(action)
	if amount <= 0:
		return false
	var pushing: bool = force_area_pushes(action)
	var rider: Dictionary = _force_rider(action)
	var source_tiles: Dictionary = engine._force_source_tiles(state, center)
	for entry: Dictionary in affected:
		var id: int = int(entry["id"])
		var unit: Dictionary = engine._force_unit(state, "enemy", id)
		var direction: Vector2i = engine._resolved_force_direction(state, "enemy", id, rider, center, pushing, amount, source_tiles)
		if direction == Vector2i.ZERO:
			continue
		var contact: Dictionary = engine._force_step_contact(state, "enemy", id, unit, unit.get("pos", INVALID) + direction, source_tiles, pushing, direction)
		if not bool(contact.get("source", false)):
			return true
	return false

static func force_area_can_resolve(engine: RefCounted, state: Dictionary, action: Dictionary) -> bool:
	if force_area_targets_tile(action):
		return true
	return force_area_has_effect(engine, state, action, force_area_center(state, action, INVALID))

static func force_area_targets(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var targets: Array[Vector2i] = []
	var player_pos: Vector2i = action.get("_origin_tile", (state.get("player", {}) as Dictionary).get("pos", INVALID))
	if not force_area_targets_tile(action):
		if force_area_has_effect(engine, state, action, player_pos):
			targets.append(player_pos)
		return targets
	var grid: Array = state.get("grid", []) as Array
	var lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	var consume: String = str(action.get("consume_center", ""))
	for tile: Vector2i in Paths.diamond_tiles(player_pos, maxi(0, int(action.get("range", 0))), grid):
		if not Paths.is_passable(grid, tile) or not engine.is_tile_visible_to_player(state, tile, lookup):
			continue
		if tile != player_pos and not engine.combat_line_of_sight(state, player_pos, tile):
			continue
		if not consume.is_empty() and not Surfaces.has_surface(state, tile, consume):
			continue
		if not force_area_has_effect(engine, state, action, tile):
			continue
		targets.append(tile)
	return targets

## Floor tiles within the area's radius of its center (hover focus).
static func force_area_tiles(state: Dictionary, action: Dictionary, target: Vector2i) -> Array[Vector2i]:
	var tiles: Array[Vector2i] = []
	var center: Vector2i = force_area_center(state, action, target)
	if center == INVALID:
		return tiles
	var grid: Array = state.get("grid", []) as Array
	for tile: Vector2i in Paths.diamond_tiles(center, maxi(0, int(action.get("radius", 1))), grid):
		if Paths.is_passable(grid, tile):
			tiles.append(tile)
	return tiles

static func apply_force_area(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var center: Vector2i = force_area_center(state, action, target)
	if center == INVALID:
		return state
	var consume: String = str(action.get("consume_center", ""))
	if not consume.is_empty():
		if not Surfaces.has_surface(state, center, consume):
			return state
		Surfaces.remove(state, center, consume, "consumed")
	var pushing: bool = force_area_pushes(action)
	var amount: int = force_area_amount(action)
	var expose: int = maxi(0, int(action.get("expose", 0)))
	var rider: Dictionary = _force_rider(action)
	var affected: Array[Dictionary] = force_area_affected(engine, state, action, center, false)
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var moved: Array = []
	for entry: Dictionary in affected:
		var id: int = int(entry["id"])
		var index: int = engine._enemy_index_for_id(state, id)
		if index < 0 or int(engine._surface_actor(state, "enemy", id).get("hp", 0)) <= 0:
			continue
		var from: Vector2i = engine._surface_actor(state, "enemy", id).get("pos", INVALID)
		if amount > 0:
			state = engine._force_move_enemy_from(state, index, rider, center, pushing, amount)
		var after: Dictionary = engine._surface_actor(state, "enemy", id)
		if expose > 0 and int(after.get("hp", 0)) > 0:
			var status_rider: Dictionary = {"type": "force_area", "expose": expose}
			if action.has("_card_id"):
				status_rider["_card_id"] = action["_card_id"]
			state = engine._apply_action_keywords_to_enemy(state, engine._enemy_index_for_id(state, id), status_rider, center, true)
		moved.append({"enemy_id": id, "from": from, "to": after.get("pos", from)})
	Surfaces.record_event(state, {
		"kind": FORCE_AREA_EVENT,
		"center": center,
		"radius": int(action.get("radius", 1)),
		"force": "push" if pushing else "pull",
		"amount": amount,
		"expose": expose,
		"consumed": consume,
		"enemies": moved,
		"source": (state.get("damage_context", {}) as Dictionary).duplicate(true)
	})
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	return state

# ------------------------------------------------------------------ Squall (aoe force_mode from_center)

static func uses_from_center(action: Dictionary) -> bool:
	return str(action.get("type", "")) == "aoe" and str(action.get("force_mode", "")) == "from_center"

## The enemy standing on the pattern center is pushed away from the player;
## every other enemy in the pattern is pushed away from that center.
static func from_center_source(engine: RefCounted, state: Dictionary, enemy_id: int, center: Vector2i, origin: Vector2i) -> Vector2i:
	var enemy: Dictionary = engine._normalized_enemy(engine._surface_actor(state, "enemy", enemy_id))
	if enemy.is_empty() or engine._enemy_footprint_tiles(enemy).has(center):
		return origin
	return center

## Several pushes at once resolve farthest-from-source first.
static func order_from_center_hits(engine: RefCounted, hits: Array, center: Vector2i) -> Array:
	return order_force_hits(engine, hits, center, true)

## One effect that moves several enemies resolves them one at a time: pushes
## farthest from the force source first, pulls nearest first, ties by enemy
## id. Only the pattern's direct enemy hits are reordered, among their own
## slots; Chain hops and every other hit keep their place.
static func order_force_hits(engine: RefCounted, hits: Array, source: Vector2i, pushing: bool) -> Array:
	var slots: Array[int] = []
	var keyed: Array = []
	for index: int in range(hits.size()):
		var hit: Dictionary = hits[index] as Dictionary
		if str(hit.get("kind", "")) != "enemy" or not hit.has("id") or hit.get("from") != hit.get("to"):
			continue
		var unit: Dictionary = hit.get("unit", {}) as Dictionary
		var distance: int = Paths.manhattan(engine._closest_enemy_tile_to(engine._normalized_enemy(unit), source), source) if not unit.is_empty() else 0
		slots.append(index)
		keyed.append({"hit": hit, "distance": distance, "id": int(hit["id"])})
	if keyed.size() < 2:
		return hits
	keyed.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if int(a["distance"]) != int(b["distance"]):
			return int(a["distance"]) > int(b["distance"]) if pushing else int(a["distance"]) < int(b["distance"])
		return int(a["id"]) < int(b["id"])
	)
	var ordered: Array = hits.duplicate()
	for slot: int in range(slots.size()):
		ordered[slots[slot]] = keyed[slot]["hit"]
	return ordered

# ------------------------------------------------------------------ forced-movement trail

## Fan the Flames: Fire on every tile the pushed or pulled target passed
## through, including its final tile, never its start tile.
static func paint_force_trail(engine: RefCounted, state: Dictionary, enemy_id: int, from: Vector2i, action: Dictionary) -> Dictionary:
	var surface: String = str(action.get("trail_surface", ""))
	if surface.is_empty() or from == INVALID:
		return state
	var unit: Dictionary = engine._surface_actor(state, "enemy", enemy_id)
	if unit.is_empty():
		return state
	unit = engine._normalized_enemy(unit)
	var to: Vector2i = unit.get("pos", from)
	if to == from or (to.x != from.x and to.y != from.y):
		return state
	var step: Vector2i = Vector2i(signi(to.x - from.x), signi(to.y - from.y))
	var source: Dictionary = engine._surface_source(state, action)
	var anchor: Vector2i = from
	while anchor != to:
		anchor += step
		for tile: Vector2i in Surfaces.footprint_tiles(unit, anchor):
			Surfaces.place(state, tile, surface, source)
	return state

# ------------------------------------------------------------------ swap

static func swap_targets(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var reach: int = maxi(0, int(action.get("range", 1)))
	var allowed: Array = action.get("targets", ["enemy", "illusion"]) as Array
	var lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	if allowed.has("enemy"):
		for raw_enemy: Dictionary in engine._live_enemies(state):
			var enemy: Dictionary = engine._normalized_enemy(raw_enemy)
			# Only a one-tile body fits the hero's tile.
			if enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE:
				continue
			if not engine.is_enemy_visible_to_player(state, enemy, lookup):
				continue
			var tile: Vector2i = enemy.get("pos", INVALID)
			if _in_reach(engine, state, player_pos, tile, reach):
				result.append(tile)
	if allowed.has("illusion"):
		for illusion: Dictionary in engine._live_illusions(state):
			var tile: Vector2i = illusion.get("pos", INVALID)
			if engine.is_tile_visible_to_player(state, tile, lookup) and _in_reach(engine, state, player_pos, tile, reach) and not result.has(tile):
				result.append(tile)
	return result

static func _in_reach(engine: RefCounted, state: Dictionary, from: Vector2i, tile: Vector2i, reach: int) -> bool:
	var distance: int = Paths.manhattan(from, tile)
	if distance <= 0 or distance > reach:
		return false
	return distance <= 1 or engine.combat_line_of_sight(state, from, tile)

## Both parties arrive normally (traps, surfaces, loot for the hero). Swap is
## not forced movement: nothing collides and Anchored does not stop it.
static func apply_swap(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var player: Dictionary = engine._normalized_player(state.get("player", {}))
	var origin: Vector2i = player.get("pos", INVALID)
	var other_kind: String = ""
	var other_id: int = -1
	var enemy_index: int = engine._enemy_index_at_tile(state, target)
	if enemy_index >= 0:
		var enemy: Dictionary = engine._normalized_enemy((state.get("enemies", []) as Array)[enemy_index])
		if enemy.get("footprint", Vector2i.ONE) != Vector2i.ONE or int(enemy.get("hp", 0)) <= 0:
			return state
		other_kind = "enemy"
		other_id = int(enemy.get("id", -1))
		enemy["pos"] = origin
		var enemies: Array = state.get("enemies", []) as Array
		enemies[enemy_index] = enemy
		state["enemies"] = enemies
	else:
		var illusions: Array = (state.get("illusions", []) as Array).duplicate(true)
		for index: int in range(illusions.size()):
			if typeof(illusions[index]) != TYPE_DICTIONARY:
				continue
			var illusion: Dictionary = illusions[index] as Dictionary
			if int(illusion.get("hp", 0)) > 0 and illusion.get("pos", INVALID) == target:
				other_kind = "illusion"
				other_id = int(illusion.get("id", -1))
				illusion["pos"] = origin
				illusions[index] = illusion
				break
		state["illusions"] = illusions
	if other_kind.is_empty():
		return state
	player["pos"] = target
	state["player"] = player
	engine._collect_loot_at_player(state)
	state = engine.surface_actor_arrival(state, "player", -1, origin)
	if int(engine._surface_actor(state, other_kind, other_id).get("hp", 0)) > 0:
		state = engine.surface_actor_arrival(state, other_kind, other_id, target)
	Surfaces.record_event(state, {
		"kind": SWAP_EVENT,
		"from": origin,
		"to": target,
		"other_kind": other_kind,
		"other_key": engine._surface_actor_key(other_kind, other_id),
		"source": (state.get("damage_context", {}) as Dictionary).duplicate(true)
	})
	return state

# ------------------------------------------------------------------ cleanse / convert / mantle

static func apply_cleanse(engine: RefCounted, state: Dictionary, action: Dictionary) -> Dictionary:
	var player: Dictionary = engine._normalized_player(state.get("player", {}))
	var restrictions: Dictionary = (state.get("player_turn_restrictions", {}) as Dictionary).duplicate(true)
	var removed: Array = []
	for status_var: Variant in action.get("statuses", []):
		match str(status_var):
			"bleed":
				if int(player.get("bleed", 0)) > 0:
					player["bleed"] = 0
					removed.append("bleed")
			"immobilize":
				if bool(player.get("immobilize", false)) or bool(restrictions.get("immobilized", false)):
					player["immobilize"] = false
					restrictions["immobilized"] = false
					removed.append("immobilize")
			"chilled":
				# Ice re-chills only on a later entry or turn start (BoardSurfaceRules).
				if bool(player.get("chilled", false)):
					player["chilled"] = false
					removed.append("chilled")
			"shock":
				if int(player.get("shock", 0)) > 0 or bool(restrictions.get("shocked", false)):
					player["shock"] = 0
					restrictions["shocked"] = false
					removed.append("shock")
	state["player"] = player
	state["player_turn_restrictions"] = restrictions
	if not removed.is_empty():
		Surfaces.record_event(state, {"kind": CLEANSE_EVENT, "actor_kind": "player", "actor_key": "player", "tile": player.get("pos", INVALID), "statuses": removed})
	return state

static func apply_convert_block_to_stoneskin(engine: RefCounted, state: Dictionary) -> Dictionary:
	var player: Dictionary = engine._normalized_player(state.get("player", {}))
	var converted: int = maxi(0, int(player.get("block", 0)))
	if converted <= 0:
		return state
	player["block"] = 0
	player["stoneskin"] = int(player.get("stoneskin", 0)) + converted
	state["player"] = player
	return engine._trigger_stoneskin_relics(state, converted)

static func gain_mantle(state: Dictionary, amount: int) -> void:
	if amount <= 0:
		return
	var player: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
	player[MANTLE_FIELD] = maxi(0, int(player.get(MANTLE_FIELD, 0))) + amount
	state["player"] = player
	Surfaces.record_event(state, {"kind": MANTLE_EVENT, "actor_kind": "player", "actor_key": "player", "tile": player.get("pos", INVALID), "amount": amount, "layers": int(player[MANTLE_FIELD])})

## Iskaldra's Crystal Mantle for the hero: a direct hit with damage breaks one
## layer before Block. `player` is the resolver's working copy; it is mutated.
static func absorb_player_hit(state: Dictionary, player: Dictionary, damage: int, cause: String) -> bool:
	if damage <= 0 or not DIRECT_HIT_CAUSES.has(cause):
		return false
	var layers: int = int(player.get(MANTLE_FIELD, 0))
	if layers <= 0:
		return false
	player[MANTLE_FIELD] = layers - 1
	Surfaces.record_event(state, {
		"kind": "crystal_mantle_broken",
		"actor_kind": "player",
		"id": -1,
		"actor_key": "player",
		"tile": player.get("pos", INVALID),
		"prevented_damage": damage,
		"layers_remaining": layers - 1,
		"source": (state.get("damage_context", {}) as Dictionary).duplicate(true)
	})
	return true

# ------------------------------------------------------------------ petrify

static func is_petrified(enemy: Dictionary) -> bool:
	return int(enemy.get(PETRIFY_FIELD, 0)) > 0

static func petrify_immune(enemy: Dictionary) -> bool:
	return DragonBosses.is_dragon_boss_id(str(enemy.get("type", "")))

static func petrify_targets(engine: RefCounted, state: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
	var reach: int = maxi(0, int(action.get("range", 1)))
	var lookup: Dictionary = engine.umbra_visible_tile_lookup(state)
	for raw_enemy: Dictionary in engine._live_enemies(state):
		var enemy: Dictionary = engine._normalized_enemy(raw_enemy)
		if petrify_immune(enemy) or not engine.is_enemy_visible_to_player(state, enemy, lookup):
			continue
		var reachable: bool = false
		for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
			if _in_reach(engine, state, player_pos, tile, reach):
				reachable = true
				break
		if reachable:
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if not result.has(tile):
					result.append(tile)
	return result

static func apply_petrify(engine: RefCounted, state: Dictionary, action: Dictionary, target: Vector2i) -> Dictionary:
	var index: int = engine._enemy_index_at_tile(state, target)
	if index < 0:
		return state
	var enemies: Array = state.get("enemies", []) as Array
	var enemy: Dictionary = engine._normalized_enemy(enemies[index])
	if int(enemy.get("hp", 0)) <= 0 or petrify_immune(enemy):
		return state
	var block: int = maxi(0, int(action.get("block", 0)))
	enemy["block"] = int(enemy.get("block", 0)) + block
	enemy[PETRIFY_FIELD] = 1
	enemies[index] = enemy
	state["enemies"] = enemies
	Surfaces.record_event(state, {"kind": PETRIFY_EVENT, "enemy_id": int(enemy.get("id", -1)), "actor_key": engine._enemy_key(enemy), "tile": enemy.get("pos", INVALID), "block": block, "source": (state.get("damage_context", {}) as Dictionary).duplicate(true)})
	return state

## Petrify Block survives the skipped activation's start-of-turn reset; the
## next real activation clears it like any enemy Block.
static func keeps_block_at_turn_start(enemy: Dictionary) -> bool:
	return is_petrified(enemy)

static func mark_petrified_turn_entries(engine: RefCounted, state: Dictionary, entries: Array[Dictionary]) -> void:
	var seen: Dictionary = {}
	for entry: Dictionary in entries:
		if str(entry.get("kind", "")) != "enemy" or bool(entry.get("active", false)) or bool(entry.get("hidden_by_umbra", false)):
			continue
		var enemy_id: int = int(entry.get("enemy_id", -1))
		if seen.has(enemy_id):
			continue
		seen[enemy_id] = true
		if is_petrified(engine._surface_actor(state, "enemy", enemy_id)):
			entry["petrified"] = true

# ------------------------------------------------------------------ move riders

static func move_action_with_trail_light(action: Dictionary) -> Dictionary:
	var trail: Variant = action.get("trail_light", null)
	if typeof(trail) != TYPE_DICTIONARY or int(action.get("illuminate_radius", 0)) > 0:
		return action
	# Reuse the Pilgrim Boots / Sunpath path-light machinery.
	var resolved: Dictionary = action.duplicate(true)
	resolved["illuminate_radius"] = maxi(1, int((trail as Dictionary).get("radius", 1)))
	resolved["illuminate_duration"] = int((trail as Dictionary).get("duration", 2))
	resolved["illuminate_position_mode"] = "path"
	return resolved

static func after_player_move(engine: RefCounted, state: Dictionary, action: Dictionary, path: Array[Vector2i]) -> Dictionary:
	var moved_tiles: int = maxi(0, path.size() - 1)
	var source: Dictionary = engine._surface_source(state, action)
	var trail: String = str(action.get("trail_surface", ""))
	if not trail.is_empty():
		for index: int in range(moved_tiles):
			Surfaces.place(state, path[index], trail, source)
	var origin_surface: String = str(action.get("origin_surface", ""))
	if not origin_surface.is_empty() and moved_tiles > 0:
		Surfaces.place(state, path[0], origin_surface, source)
	var per_tile: int = maxi(0, int(action.get("block_per_tile", 0)))
	if per_tile > 0 and moved_tiles > 0:
		var player: Dictionary = engine._normalized_player(state.get("player", {}))
		player["block"] = int(player.get("block", 0)) + per_tile * moved_tiles
		state["player"] = player
	var started: Variant = action.get("if_started_on_surface", null)
	if typeof(started) == TYPE_DICTIONARY and started_activation_on(state, str((started as Dictionary).get("surface", ""))):
		state = engine._apply_relic_rewards(state, (started as Dictionary).get("rewards", []), {"source_name": engine._action_card_name(action)})
	return state

## Joust: destinations on a clear straight cardinal line from the hero.
static func straight_line_navigation(engine: RefCounted, state: Dictionary, unit: Dictionary, budget: int, occupied: Dictionary, minimum_progress: bool, stop_after_reaching: Callable = Callable()) -> Dictionary:
	var start: Vector2i = unit.get("pos", INVALID)
	var start_path: Array[Vector2i] = []
	start_path.append(start)
	var paths: Dictionary = {start: start_path}
	var costs: Dictionary = {start: 0}
	var grid: Array = state.get("grid", []) as Array
	for direction_var: Variant in DIRECTIONS:
		var direction: Vector2i = direction_var
		var path: Array[Vector2i] = start_path.duplicate()
		var tile: Vector2i = start
		for _step: int in range(64):
			var next: Vector2i = tile + direction
			if not Paths.is_passable(grid, next) or occupied.has(next):
				break
			var trial: Array[Vector2i] = path.duplicate()
			trial.append(next)
			if engine.movement_cost_for_path(state, trial, budget, minimum_progress, unit) > budget:
				break
			path = trial
			tile = next
			paths[next] = path.duplicate()
			costs[next] = engine.movement_cost_for_path(state, path, budget, minimum_progress, unit)
			if stop_after_reaching.is_valid() and bool(stop_after_reaching.call(next)):
				return {"paths": paths, "costs": costs}
	return {"paths": paths, "costs": costs}

# ------------------------------------------------------------------ blink riders

static func blink_destination_allowed(engine: RefCounted, state: Dictionary, action: Dictionary, tile: Vector2i, lookup: Dictionary = {}) -> bool:
	if bool(action.get("destination_requires_light", false)) and not engine._light_source_covers_tile(state, tile):
		return false
	var adjacent_to: Array = action.get("destination_adjacent_to", []) as Array
	if not adjacent_to.is_empty() and not _tile_next_to(engine, state, tile, adjacent_to, lookup):
		return false
	return true

static func _tile_next_to(engine: RefCounted, state: Dictionary, tile: Vector2i, kinds: Array, lookup: Dictionary) -> bool:
	var neighbors: Dictionary = {}
	for direction_var: Variant in DIRECTIONS:
		neighbors[tile + (direction_var as Vector2i)] = true
	if kinds.has("enemy"):
		for raw_enemy: Dictionary in engine._live_enemies(state):
			var enemy: Dictionary = engine._normalized_enemy(raw_enemy)
			if not engine.is_enemy_visible_to_player(state, enemy, lookup):
				continue
			for footprint_tile: Vector2i in engine._enemy_footprint_tiles(enemy):
				if neighbors.has(footprint_tile):
					return true
	if kinds.has("terrain"):
		for terrain: Dictionary in engine._live_terrain(state):
			if neighbors.has(terrain.get("pos", INVALID)):
				return true
	return false

static func after_player_blink(engine: RefCounted, state: Dictionary, action: Dictionary, origin: Vector2i) -> Dictionary:
	var illusion_health: int = int(action.get("illusion_at_origin", 0))
	if illusion_health > 0 and origin != INVALID:
		state = engine._create_illusion(state, origin, Data.fixed_point_amount(illusion_health))
	var rewards: Variant = action.get("if_no_adjacent_enemies", null)
	if typeof(rewards) == TYPE_ARRAY and not (rewards as Array).is_empty():
		var player_pos: Vector2i = (state.get("player", {}) as Dictionary).get("pos", INVALID)
		if not _tile_next_to(engine, state, player_pos, ["enemy"], engine.umbra_visible_tile_lookup(state)):
			state = engine._apply_relic_rewards(state, rewards, {"source_name": engine._action_card_name(action)})
	return state

# ------------------------------------------------------------------ presentation and analytics

## One short line for the action banner beat of targetless family-B actions.
static func presentation_text(before_state: Dictionary, after_state: Dictionary, action: Dictionary) -> String:
	var before_player: Dictionary = before_state.get("player", {}) as Dictionary
	var after_player: Dictionary = after_state.get("player", {}) as Dictionary
	match str(action.get("type", "")):
		"self_flag":
			return flag_label(str(action.get("flag", "")))
		"cleanse":
			var removed: Array = []
			for event: Dictionary in _events_since(before_state, after_state):
				if str(event.get("kind", "")) == CLEANSE_EVENT:
					for status_var: Variant in event.get("statuses", []):
						removed.append(str(CLEANSE_LABELS.get(str(status_var), str(status_var))))
			return "Cleansed %s" % _joined(removed) if not removed.is_empty() else "Nothing to cleanse"
		"convert_block_to_stoneskin":
			var gained: int = int(after_player.get("stoneskin", 0)) - int(before_player.get("stoneskin", 0))
			return "+%d S" % gained if gained > 0 else "No Block"
		"mantle":
			return "Mantle +%d" % maxi(0, int(after_player.get(MANTLE_FIELD, 0)) - int(before_player.get(MANTLE_FIELD, 0)))
		"petrify":
			return "Petrified"
	return ""

static func _events_since(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sequence: int = int(before_state.get("surface_event_sequence", 0))
	for event_var: Variant in after_state.get("surface_events", []):
		if typeof(event_var) == TYPE_DICTIONARY and int((event_var as Dictionary).get("sequence", 0)) > sequence:
			result.append(event_var as Dictionary)
	return result

## Additive `card_played` analytics fields (spec/analytics.md).
static func analytics_fields(before_state: Dictionary, after_state: Dictionary) -> Dictionary:
	var gained_flags: Array = []
	var before_flags: Dictionary = flags(before_state)
	for flag_var: Variant in flags(after_state).keys():
		if not before_flags.has(flag_var):
			gained_flags.append(str(flag_var))
	var cleansed: Array = []
	var petrified: Array = []
	var swapped_with: Variant = null
	var forced: int = 0
	for event: Dictionary in _events_since(before_state, after_state):
		match str(event.get("kind", "")):
			CLEANSE_EVENT:
				cleansed.append_array(event.get("statuses", []) as Array)
			PETRIFY_EVENT:
				petrified.append(int(event.get("enemy_id", -1)))
			SWAP_EVENT:
				swapped_with = str(event.get("other_kind", ""))
			FORCE_AREA_EVENT:
				for moved_var: Variant in event.get("enemies", []):
					var moved: Dictionary = moved_var as Dictionary
					if moved.get("from", INVALID) != moved.get("to", INVALID):
						forced += 1
	var mantle_gained: int = maxi(0, int((after_state.get("player", {}) as Dictionary).get(MANTLE_FIELD, 0)) - int((before_state.get("player", {}) as Dictionary).get(MANTLE_FIELD, 0)))
	return {
		"self_flags_gained": gained_flags,
		"statuses_cleansed": cleansed,
		"mantle_gained": mantle_gained,
		"petrified_enemy_ids": petrified,
		"swapped_with": swapped_with,
		"force_area_displaced": forced
	}
