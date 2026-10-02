extends RefCounted

## Automatic common-relic rules. Forecasts execute these same hooks on a copy.
## Limits live in the ordinary saved payment/turn state, never on this helper.
const Data = preload("res://scripts/game_data.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")

static func start_combat(engine: RefCounted, state: Dictionary) -> Dictionary:
	# Light comes first: the illusion chooses among enemies visible at creation.
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) == "start_combat_light":
			state = engine._create_umbra_light_source(state, state["player"]["pos"], effect)
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) != "start_combat_adjacent_illusion":
			continue
		var occupied: Dictionary = engine._occupied_actor_tiles(state)
		var candidates: Dictionary = {}
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = state["player"]["pos"] + direction
			if Surface.can_place(state, tile) and not occupied.has(tile):
				candidates[tile] = true
		var chosen: Vector2i = engine.INVALID_TILE
		var best: int = 2147483647
		for tile: Vector2i in engine._sorted_tiles_from_lookup(candidates):
			var distance: int = 2147483647
			for enemy: Dictionary in engine._live_enemies(state):
				if engine.is_enemy_visible_to_player(state, enemy):
					distance = mini(distance, engine._enemy_distance_to_tile(enemy, tile))
			if distance < best:
				chosen = tile
				best = distance
		if chosen != engine.INVALID_TILE:
			state = engine._create_illusion(state, chosen, Data.fixed_point_amount(int(effect.get("health", 2))))
	return turn_start(engine, state)

static func retained_block(effects: Array, previous: int) -> int:
	var cap: int = 0
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) == "retain_turn_block":
			cap += Data.fixed_point_amount(int(effect.get("amount", 0)))
	return mini(previous, cap)

static func turn_start(engine: RefCounted, state: Dictionary) -> Dictionary:
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) == "turn_start_surface_stoneskin" and Surface.unit_on(state, state["player"], str(effect.get("surface", ""))):
			var amount: int = Data.fixed_point_amount(int(effect.get("amount", 0)))
			state["player"]["stoneskin"] = int(state["player"].get("stoneskin", 0)) + amount
			state = engine._trigger_stoneskin_relics(state, amount)
	return state

static func block_from_card(engine: RefCounted, state: Dictionary, action: Dictionary) -> void:
	if int(action.get("amount", 0)) <= 0 or str(action.get("_card_id", "")).is_empty():
		return
	var payment: Dictionary = state.get("pending_card_payment", {}) as Dictionary
	if bool(payment.get("block_retaliate_used", false)):
		return
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) == "card_block_retaliate":
			Retaliate.gain(state, {"amount": Data.fixed_point_amount(int(effect.get("amount", 0)))}, Data._relic_effect_source_name(effect))
			payment["block_retaliate_used"] = true
	state["pending_card_payment"] = payment

static func moved_damage(state: Dictionary, action: Dictionary, effect: Dictionary) -> int:
	var types: Array = action.get("_card_action_types", []) as Array
	var matches: bool = false
	for type: String in effect.get("requires_any_action_types", []):
		matches = matches or types.has(type)
	return Data.fixed_point_amount(mini(Tempo.tiles_moved(state) * int(effect.get("amount", 0)), int(effect.get("max", 0)))) if matches else 0

## Pay before conduction plans are built: a tile spent by Flint cannot also
## bridge a Lightning network. Target-dependent Chain was read at attack start.
static func consume_melee_target(engine: RefCounted, state: Dictionary, action: Dictionary, tile: Vector2i, player_attack: bool) -> Dictionary:
	if not player_attack or str(action.get("type", "")) != "melee":
		return {}
	var index: int = engine._enemy_index_at_tile(state, tile)
	if index < 0 or not engine.is_enemy_visible_to_player(state, state["enemies"][index]):
		return {}
	var surface: String = Surface.element_at(state, tile)
	if surface.is_empty():
		return {}
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) != "melee_consume_elemental_damage":
			continue
		var amount: int = Data.fixed_point_amount(int(effect.get("amount", 0)))
		Surface.remove(state, tile, "elemental", "consume")
		Surface.sync_chilled(state)
		var tiles: Array[Vector2i]
		tiles.append(tile)
		Surface.record_event(state, {"kind": "attack_consumed_surface", "surface": surface, "tiles": tiles, "bonus_damage": amount, "source": engine._surface_source(state, action)})
		return {"tile": tile, "surface": surface, "amount": amount}
	return {}

static func before_melee_hit(action: Dictionary, hit: Dictionary, fuel: Dictionary) -> Dictionary:
	if fuel.is_empty() or str(hit.get("kind_trace", "")) != "actor" or hit["from"] != hit["to"] or hit["to"] != fuel["tile"]:
		return action
	var result: Dictionary = action.duplicate(true)
	result["damage"] = int(result.get("damage", 0)) + int(fuel["amount"])
	result["_skip_surface_freeze"] = str(fuel["surface"]) == "ice"
	return result

static func blocked_attack(engine: RefCounted, state: Dictionary, attacker_id: int, health_loss: int, block_loss: int) -> Dictionary:
	if health_loss > 0 or block_loss < 1:
		return state
	var index: int = engine._enemy_index_for_id(state, attacker_id)
	if index < 0:
		return state
	for effect: Dictionary in engine._relic_effects(state):
		if str(effect.get("type", "")) == "fully_blocked_attack_status":
			var rider: Dictionary = {"type": "relic"}
			rider[str(effect.get("status", "bleed"))] = Data.fixed_point_amount(int(effect.get("amount", 0)))
			state = engine._apply_action_keywords_to_enemy(state, index, rider, state["player"]["pos"])
	return state
