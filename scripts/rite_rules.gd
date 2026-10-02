extends RefCounted
class_name RiteRules

## Rites are burn:true cards carrying {"rite": {"effects": [...]}}. Playing one
## Exhausts it and appends its effects to the combat-scoped `active_rites` list.
## Every relic-effect reader sees them through GameData.relic_effects_for_state,
## so a Rite is a relic for the rest of this combat and never reaches the run.
## This module must not preload GameData: GameData preloads it for card costs.
## See spec/card_keywords_wave3.md.

const Surfaces = preload("res://scripts/board_surface_rules.gd")

const ACTIVE_KEY: String = "active_rites"
const SIGNATURE_KEY: String = "active_rites_signature"
const RELIC_ID_PREFIX: String = "rite:"
const ATTACK_ACTION_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull", "detonate"]
const TARGET_STATE_CONDITIONS: Array = ["target_in_light", "target_surface", "target_status"]

static func card_rite(card: Dictionary) -> Dictionary:
	var rite: Variant = card.get("rite", {})
	return rite as Dictionary if typeof(rite) == TYPE_DICTIONARY else {}

static func is_rite_card(card: Dictionary) -> bool:
	return not card_rite(card).is_empty()

static func active_rites(state: Dictionary) -> Array:
	var rites: Variant = state.get(ACTIVE_KEY, [])
	return rites as Array if typeof(rites) == TYPE_ARRAY else []

static func start(state: Dictionary, card_id: String, card: Dictionary) -> bool:
	var rite: Dictionary = card_rite(card)
	if rite.is_empty():
		return false
	var rites: Array = active_rites(state).duplicate(true)
	rites.append({
		"card_id": card_id,
		"name": str(card.get("name", card_id)),
		"description": str(card.get("description", "")),
		"effects": (rite.get("effects", []) as Array).duplicate(true)
	})
	state[ACTIVE_KEY] = rites
	state[SIGNATURE_KEY] = _computed_signature(rites)
	return true

## Cheap identity for relic-effect caches. Rite effects derive from the ordered
## card ids, so the joined ids identify them without a deep comparison.
static func signature(state: Dictionary) -> String:
	if not state.has(ACTIVE_KEY):
		return ""
	if state.has(SIGNATURE_KEY):
		return str(state[SIGNATURE_KEY])
	return _computed_signature(active_rites(state))

static func _computed_signature(rites: Array) -> String:
	var ids: PackedStringArray = []
	for rite_var: Variant in rites:
		if typeof(rite_var) == TYPE_DICTIONARY:
			ids.append(str((rite_var as Dictionary).get("card_id", "")))
	return "|".join(ids)

## Relic-shaped effects for every active Rite. `relic_id` is unique and stable
## per authored effect (rite:<card_id>:<n>), so once/counter flags never collide
## between two Rites or two copies of the same Rite.
static func effects(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var serial: int = 0
	for rite_var: Variant in active_rites(state):
		if typeof(rite_var) != TYPE_DICTIONARY:
			continue
		var rite: Dictionary = rite_var as Dictionary
		var card_id: String = str(rite.get("card_id", ""))
		for effect_var: Variant in rite.get("effects", []):
			if typeof(effect_var) != TYPE_DICTIONARY:
				continue
			var relic_id: String = "%s%s:%d" % [RELIC_ID_PREFIX, card_id, serial]
			serial += 1
			for normalized: Dictionary in _normalized_effects(effect_var as Dictionary):
				normalized["relic_id"] = relic_id
				normalized["rite_card_id"] = card_id
				normalized["source_name"] = str(rite.get("name", card_id))
				result.append(normalized)
	return result

static func is_rite_relic_id(relic_id: String) -> bool:
	return relic_id.begins_with(RELIC_ID_PREFIX)

static func card_id_for_relic_id(relic_id: String) -> String:
	if not is_rite_relic_id(relic_id):
		return ""
	return relic_id.substr(RELIC_ID_PREFIX.length()).get_slice(":", 0)

# Authored Rite vocabulary maps onto existing relic effect types when one
# already does the job, so every existing reader applies it unchanged.
static func _normalized_effects(effect: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	match str(effect.get("type", "")):
		"independent_movement_bonus":
			result.append({"type": "movement_pool_bonus", "value": int(effect.get("amount", effect.get("value", 1)))})
		"forced_movement_bonus":
			# Same mechanism as Tailwind Fletching, but for every element: the
			# standalone Push/Pull distance and the Push/Pull keyword riders.
			var amount: int = int(effect.get("amount", 1))
			result.append({"type": "card_action_mod", "action_types": ["push", "pull"], "field": "amount", "amount": amount})
			result.append({"type": "card_action_mod", "requires_field": "push", "field": "push", "amount": amount})
			result.append({"type": "card_action_mod", "requires_field": "pull", "field": "pull", "amount": amount})
		"target_state_action_mod":
			if typeof(effect.get("add", null)) != TYPE_DICTIONARY:
				result.append(effect.duplicate(true))
				return result
			var conditions: Dictionary = effect.get("conditions", {}) as Dictionary if typeof(effect.get("conditions", null)) == TYPE_DICTIONARY else {}
			var additions: Dictionary = effect["add"] as Dictionary
			for field_var: Variant in additions.keys():
				var normalized: Dictionary = {
					"type": "target_state_action_mod",
					"action_types": (effect.get("action_types", ATTACK_ACTION_TYPES) as Array).duplicate(),
					"field": str(field_var),
					"amount": int(additions[field_var])
				}
				for condition: String in TARGET_STATE_CONDITIONS:
					if conditions.has(condition):
						normalized[condition] = conditions[condition]
				result.append(normalized)
		_:
			result.append(effect.duplicate(true))
	return result

static func effects_of_type(effects: Array, effect_type: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for effect_var: Variant in effects:
		if typeof(effect_var) == TYPE_DICTIONARY and str((effect_var as Dictionary).get("type", "")) == effect_type:
			result.append(effect_var as Dictionary)
	return result

## Fire-tile damage after Rite modifiers. `surface_immunity` protects only the
## player; signed `surface_damage_bonus` adjusts entry and turn-start damage.
## Optional `actor_kind` restricts the recipient, and `owner: player` restricts
## the creator. Damage never falls below zero.
static func surface_tile_damage(effects: Array, surface: String, actor_kind: String, amount: int, surface_source: Dictionary = {}, scale: int = 1) -> int:
	if amount <= 0:
		return amount
	if actor_kind == "player" and player_immune_to_surface(effects, surface):
		return 0
	var result: int = amount
	for effect: Dictionary in effects_of_type(effects, "surface_damage_bonus"):
		if str(effect.get("surface", "")) != surface:
			continue
		if effect.has("actor_kind") and str(effect["actor_kind"]) != actor_kind:
			continue
		var owner: String = str(effect.get("owner", ""))
		if not owner.is_empty() and owner != str(surface_source.get("causal_owner", surface_source.get("actor_kind", ""))):
			continue
		result += int(effect.get("amount", 0)) * scale
	return maxi(0, result)

# The three queries below run on hot rules paths (light coverage per tile, card
# definitions per preview); iterate in place rather than allocating filters.
static func player_immune_to_surface(effects: Array, surface: String) -> bool:
	for effect_var: Variant in effects:
		var effect: Dictionary = effect_var as Dictionary
		if str(effect.get("type", "")) == "surface_immunity" and str(effect.get("surface", "")) == surface:
			return true
	return false

static func player_light_radius(effects: Array) -> int:
	var radius: int = 0
	for effect_var: Variant in effects:
		var effect: Dictionary = effect_var as Dictionary
		if str(effect.get("type", "")) == "player_light_aura":
			radius += maxi(0, int(effect.get("radius", 0)))
	return radius

static func card_time_discount(effects: Array, card: Dictionary = {}) -> int:
	var total: int = 0
	for effect_var: Variant in effects:
		var effect: Dictionary = effect_var as Dictionary
		if str(effect.get("type", "")) == "card_time_discount" and (not bool(effect.get("rite_only", false)) or is_rite_card(card)):
			total += maxi(0, int(effect.get("amount", 0)))
	return total

## Player turn start, after the ordinary draw: Rite rewards and Electrified
## pulses. Pulse damage is player-credited but is not a card hit.
static func apply_player_turn_start(engine: RefCounted, state: Dictionary) -> Dictionary:
	var next_state: Dictionary = state
	for effect: Dictionary in engine._relic_effects(next_state):
		if int((next_state.get("player", {}) as Dictionary).get("hp", 0)) <= 0:
			break
		match str(effect.get("type", "")):
			"turn_start_reward":
				next_state = engine._apply_relic_rewards(next_state, effect.get("rewards", []), effect)
			"turn_start_on_surface":
				if Surfaces.unit_on(next_state, next_state.get("player", {}) as Dictionary, str(effect.get("surface", ""))):
					next_state = engine._apply_relic_rewards(next_state, effect.get("rewards", []), effect)
			"turn_start_surface_pulse":
				next_state = _surface_pulse(engine, next_state, effect)
	return next_state

static func _surface_pulse(engine: RefCounted, state: Dictionary, effect: Dictionary) -> Dictionary:
	var surface: String = str(effect.get("surface", "electrified"))
	var tiles: Array[Vector2i] = Surfaces.tiles(state, surface)
	# Combat units are natural whole numbers (GameData.FIXED_POINT_SCALE == 1).
	var amount: int = int(effect.get("damage", 0))
	if tiles.is_empty() or amount <= 0:
		return state
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = {
		"actor_kind": "player",
		"actor_id": -1,
		"source_kind": "rite_pulse",
		"player_card": false,
		"causal_owner": "player",
		"relic_id": str(effect.get("relic_id", "")),
		"element": str(effect.get("element", ""))
	}
	state["damage_context"] = context
	var previous_batch: bool = bool(state.get("_surface_damage_batch", false))
	state["_surface_damage_batch"] = true
	var hit_ids: Array[int] = []
	for actor: Dictionary in engine._surface_actor_records(state, "enemies"):
		if not engine._surface_unit_intersects(actor["unit"] as Dictionary, tiles):
			continue
		hit_ids.append(int(actor["id"]))
		state = engine._surface_damage_actor(state, "enemy", int(actor["id"]), amount, false)
	Surfaces.record_event(state, {"kind": "rite_surface_pulse", "surface": surface, "element": context["element"], "damage": amount, "enemy_ids": hit_ids, "relic_id": context["relic_id"], "source": context.duplicate(true)})
	state["_surface_damage_batch"] = previous_batch
	if not previous_batch:
		state = engine._flush_surface_deaths(state)
	state["damage_context"] = previous_context
	return state

## HUD entries for active Rites (icon `rite`, tooltip = card name + rules text).
static func hud_entries(state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for rite_var: Variant in active_rites(state):
		if typeof(rite_var) != TYPE_DICTIONARY:
			continue
		var rite: Dictionary = rite_var as Dictionary
		result.append({
			"card_id": str(rite.get("card_id", "")),
			"icon": "rite",
			"tooltip": "%s\n%s\nRite: Exhaust. Lasts for the rest of this combat." % [str(rite.get("name", "")), str(rite.get("description", ""))]
		})
	return result
