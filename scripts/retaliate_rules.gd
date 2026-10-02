extends RefCounted
class_name RetaliateRules

## Retaliate: until the start of the player's next turn, an enemy whose melee
## attack (melee action, or any attack from an adjacent tile) hits the player
## takes the Retaliate amount as non-direct damage (Block/Stoneskin absorb; no
## Chill/Freeze multiplier or Expose) and the riders (Bleed adds, Shock and
## Push). Rite `thorns` effects are a permanent Retaliate that stacks with it.
## Triggers once per enemy attack. Kills pay death rewards but no card play.
## See spec/card_keywords_wave3.md.

const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const DefenseRelicRules = preload("res://scripts/defense_relic_rules.gd")
const RiteRules = preload("res://scripts/rite_rules.gd")

const STATE_KEY: String = "retaliate"
const EVENT_KIND: String = "retaliate_triggered"

static func gain(state: Dictionary, action: Dictionary, source_name: String = "") -> void:
	var current: Dictionary = (state.get(STATE_KEY, {}) as Dictionary).duplicate(true) if typeof(state.get(STATE_KEY, null)) == TYPE_DICTIONARY else {}
	# Combat units are natural whole numbers (GameData.FIXED_POINT_SCALE == 1).
	current["amount"] = int(current.get("amount", 0)) + maxi(0, int(action.get("amount", 0)))
	current["bleed"] = int(current.get("bleed", 0)) + maxi(0, int(action.get("bleed", 0)))
	current["shock"] = maxi(int(current.get("shock", 0)), maxi(0, int(action.get("shock", 0))))
	current["push"] = maxi(int(current.get("push", 0)), maxi(0, int(action.get("push", 0))))
	var sources: Array = (current.get("sources", []) as Array).duplicate()
	if not source_name.is_empty() and not sources.has(source_name):
		sources.append(source_name)
	current["sources"] = sources
	state[STATE_KEY] = current

static func clear(state: Dictionary) -> void:
	if not DefenseRelicRules.has_effect(Data.relic_effects_for_state(state), "persistent_retaliate"):
		state.erase(STATE_KEY)

static func totals(state: Dictionary, effects: Array) -> Dictionary:
	var current: Dictionary = state.get(STATE_KEY, {}) as Dictionary if typeof(state.get(STATE_KEY, null)) == TYPE_DICTIONARY else {}
	var total: Dictionary = {
		"amount": maxi(0, int(current.get("amount", 0))),
		"bleed": maxi(0, int(current.get("bleed", 0))),
		"shock": maxi(0, int(current.get("shock", 0))),
		"push": maxi(0, int(current.get("push", 0))),
		"sources": (current.get("sources", []) as Array).duplicate(),
		"thorns": 0
	}
	for effect: Dictionary in RiteRules.effects_of_type(effects, "thorns"):
		total["amount"] = int(total["amount"]) + maxi(0, int(effect.get("damage", effect.get("amount", 0))))
		total["thorns"] = int(total["thorns"]) + maxi(0, int(effect.get("damage", effect.get("amount", 0))))
		total["bleed"] = int(total["bleed"]) + maxi(0, int(effect.get("bleed", 0)))
		total["shock"] = maxi(int(total["shock"]), maxi(0, int(effect.get("shock", 0))))
		total["push"] = maxi(int(total["push"]), maxi(0, int(effect.get("push", 0))))
		var name: String = str(effect.get("source_name", ""))
		if not name.is_empty() and not (total["sources"] as Array).has(name):
			(total["sources"] as Array).append(name)
	total["active"] = int(total["amount"]) > 0 or int(total["bleed"]) > 0 or int(total["shock"]) > 0 or int(total["push"]) > 0
	return total

static func is_melee_hit(engine: RefCounted, state: Dictionary, attacker: Dictionary, action: Dictionary, struck_tile: Vector2i = Vector2i(-999999, -999999)) -> bool:
	if str(action.get("type", "")) == "melee":
		return true
	var player_pos: Vector2i = struck_tile if struck_tile != Vector2i(-999999, -999999) else (state.get("player", {}) as Dictionary).get("pos", Vector2i(-999, -999))
	var origin: Vector2i = action.get("_origin_tile", attacker.get("pos", Vector2i(-999, -999)))
	for tile: Vector2i in engine._enemy_footprint_tiles(attacker):
		if Paths.manhattan(tile, player_pos) <= 1:
			return true
	return Paths.manhattan(origin, player_pos) <= 1

## Hooked after the enemy->player hit loop in CombatEngine._resolve_board_attack,
## inside its damage batch so deaths flush with this context.
static func after_enemy_hit(engine: RefCounted, state: Dictionary, attacker_id: int, action: Dictionary, struck_tile: Vector2i = Vector2i(-999999, -999999)) -> Dictionary:
	var player: Dictionary = state.get("player", {}) as Dictionary
	if int(player.get("hp", 0)) <= 0:
		return state
	var total: Dictionary = totals(state, engine._relic_effects(state))
	if not bool(total.get("active", false)):
		return state
	var index: int = engine._enemy_index_for_id(state, attacker_id)
	if index < 0:
		return state
	var before: Dictionary = engine._normalized_enemy((state.get("enemies", []) as Array)[index])
	if int(before.get("hp", 0)) <= 0 or not is_melee_hit(engine, state, before, action, struck_tile):
		return state
	var previous_context: Dictionary = (state.get("damage_context", {}) as Dictionary).duplicate(true)
	var context: Dictionary = {"actor_kind": "player", "actor_id": -1, "source_kind": "retaliate", "player_card": false, "causal_owner": "player", "target_enemy_id": attacker_id}
	state["damage_context"] = context
	var amount: int = int(total["amount"])
	if amount > 0:
		state = engine._damage_enemy(state, index, amount, false, false)
	var retaliate_hp_loss: int = maxi(0, int(before.get("hp", 0)) - int(engine._surface_actor(state, "enemy", attacker_id).get("hp", 0)))
	state = DefenseRelicRules.after_retaliate(engine, state, retaliate_hp_loss)
	for effect: Dictionary in DefenseRelicRules.effects_of_type(engine._relic_effects(state), "persistent_retaliate"):
		gain(state, {"amount": int(effect.get("growth", 1))}, engine._relic_effect_source_name(effect))
	var rider: Dictionary = {"type": "retaliate", "bleed": int(total["bleed"]), "shock": int(total["shock"]), "push": int(total["push"])}
	var player_pos: Vector2i = player.get("pos", Vector2i.ZERO)
	if int(rider["push"]) > 0:
		# Straight away from the player, like any directed push; the engine's
		# normal forced-movement entry point owns blocking and collisions.
		rider["force_direction"] = engine._cardinal_direction(engine._closest_enemy_tile_to(before, player_pos) - player_pos)
	if int(rider["bleed"]) > 0 or int(rider["shock"]) > 0 or int(rider["push"]) > 0:
		state = engine._apply_action_keywords_to_enemy(state, index, rider, player_pos, true)
	var after: Dictionary = engine._surface_actor(state, "enemy", attacker_id)
	Surfaces.record_event(state, {
		"kind": EVENT_KIND,
		"enemy_id": attacker_id,
		"actor_key": engine._enemy_key(before),
		"attack_type": str(action.get("type", "")),
		"damage": amount,
		"thorns": int(total.get("thorns", 0)),
		"hp_loss": maxi(0, int(before.get("hp", 0)) - int(after.get("hp", 0))),
		"block_loss": maxi(0, int(before.get("block", 0)) - int(after.get("block", 0))),
		"stoneskin_loss": maxi(0, int(before.get("stoneskin", 0)) - int(after.get("stoneskin", 0))),
		"bleed": int(rider["bleed"]),
		"shock": int(rider["shock"]),
		"push": int(rider["push"]),
		"from": before.get("pos", Vector2i.ZERO),
		"to": after.get("pos", before.get("pos", Vector2i.ZERO)),
		"killed": int(after.get("hp", 0)) <= 0,
		"attacker_before": {"pos": before.get("pos", Vector2i.ZERO), "hp": int(before.get("hp", 0)), "block": int(before.get("block", 0)), "stoneskin": int(before.get("stoneskin", 0))},
		"sources": (total.get("sources", []) as Array).duplicate(),
		"source": context.duplicate(true)
	})
	state["damage_context"] = previous_context
	return state

static func events_between(before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var sequence: int = int(before_state.get("surface_event_sequence", 0))
	for event_var: Variant in after_state.get("surface_events", []):
		if typeof(event_var) != TYPE_DICTIONARY:
			continue
		var event: Dictionary = event_var as Dictionary
		if int(event.get("sequence", 0)) > sequence and str(event.get("kind", "")) == EVENT_KIND:
			result.append(event)
	return result

## The enemy's own attack step starts where the attacker stood when it struck.
static func decorate_attack_step(before_state: Dictionary, after_state: Dictionary, step: Dictionary) -> Dictionary:
	if step.is_empty():
		return step
	var events: Array[Dictionary] = events_between(before_state, after_state)
	if events.is_empty():
		return step
	var result: Dictionary = step.duplicate(true)
	var attacker_before: Dictionary = events[0].get("attacker_before", {}) as Dictionary
	if result.has("from") and attacker_before.has("pos"):
		result["from"] = attacker_before["pos"]
	result["retaliated"] = true
	return result

## One "status_damage" presentation step per Retaliate so the attacker's loss
## animates (floating text on the attacker) after its strike lands.
static func presentation_steps(engine: RefCounted, before_state: Dictionary, after_state: Dictionary) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	for event: Dictionary in events_between(before_state, after_state):
		var enemy_id: int = int(event.get("enemy_id", -1))
		var after_enemy: Dictionary = engine._surface_actor(after_state, "enemy", enemy_id)
		var before_values: Dictionary = event.get("attacker_before", {}) as Dictionary
		var hp_loss: int = int(event.get("hp_loss", 0))
		var block_loss: int = int(event.get("block_loss", 0))
		var stoneskin_loss: int = int(event.get("stoneskin_loss", 0))
		var losses: Array[Dictionary] = []
		if hp_loss > 0 or block_loss > 0 or stoneskin_loss > 0:
			losses.append({"key": str(event.get("actor_key", "")), "kind": "enemy", "id": enemy_id, "tile": after_enemy.get("pos", before_values.get("pos", Vector2i.ZERO)), "hp_loss": hp_loss, "block_loss": block_loss, "stoneskin_loss": stoneskin_loss, "amount": hp_loss + block_loss + stoneskin_loss})
		if losses.is_empty():
			# Riders only (e.g. a zero-damage Retaliate that pushes): a status
			# step names the effect and applies the moved/afflicted attacker.
			steps.append({
				"kind": "status",
				"label": "Retaliate",
				"text": "Retaliate",
				"trigger": "retaliate",
				"action_type": "retaliate",
				"actor_key": str(event.get("actor_key", "")),
				"actor_name": str(Data.enemy_def(str(after_enemy.get("type", ""))).get("name", "Enemy")) if not after_enemy.is_empty() else "Enemy",
				"tile": after_enemy.get("pos", before_values.get("pos", Vector2i.ZERO)),
				"enemy_after": after_enemy.duplicate(true),
				"retaliate": event.duplicate(true)
			})
			continue
		steps.append({
			"kind": "status_damage",
			"label": "Retaliate",
			"text": "Retaliate",
			"trigger": "retaliate",
			"action_type": "retaliate",
			"actor_key": str(event.get("actor_key", "")),
			"actor_name": str(Data.enemy_def(str(after_enemy.get("type", ""))).get("name", "Enemy")) if not after_enemy.is_empty() else "Enemy",
			"tile": after_enemy.get("pos", before_values.get("pos", Vector2i.ZERO)),
			"amount": int(event.get("damage", 0)),
			"enemy_losses": losses,
			"impact_actor_keys": [str(event.get("actor_key", ""))] if not losses.is_empty() else [],
			"enemies_after": (after_state.get("enemies", []) as Array).duplicate(true),
			"player_after": (after_state.get("player", {}) as Dictionary).duplicate(true),
			"surfaces_after": (after_state.get("surfaces", {}) as Dictionary).duplicate(true),
			"retaliate": event.duplicate(true)
		})
	return steps

## Player HUD badge: icon `retaliate`, amount, tooltip listing riders.
static func player_badges(state: Dictionary, effects: Array) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	var total: Dictionary = totals(state, effects)
	if not bool(total.get("active", false)):
		return badges
	var riders: PackedStringArray = []
	if int(total["bleed"]) > 0:
		riders.append("Bleed %d" % int(total["bleed"]))
	if int(total["shock"]) > 0:
		riders.append("Shock")
	if int(total["push"]) > 0:
		riders.append("Push %d" % int(total["push"]))
	var lines: PackedStringArray = ["Retaliate %d" % int(total["amount"]) if int(total["amount"]) > 0 else "Retaliate"]
	var effect_text: String = "Enemies that hit you in melee"
	if int(total["amount"]) > 0:
		effect_text += " take %d" % int(total["amount"])
		if not riders.is_empty():
			effect_text += " and"
	if not riders.is_empty():
		effect_text += " suffer %s" % ", ".join(riders)
	lines.append(effect_text + ".")
	var has_card_retaliate: bool = typeof(state.get(STATE_KEY, null)) == TYPE_DICTIONARY and not (state[STATE_KEY] as Dictionary).is_empty()
	var has_thorns: bool = not RiteRules.effects_of_type(effects, "thorns").is_empty()
	if DefenseRelicRules.has_effect(effects, "persistent_retaliate"):
		lines.append("Lasts for this combat; grows after every trigger.")
	elif has_card_retaliate and has_thorns:
		lines.append("Rite thorns last for this combat; card Retaliate lasts until your next turn.")
	elif has_thorns:
		lines.append("Rite: lasts for the rest of this combat.")
	else:
		lines.append("Lasts until your next turn.")
	var sources: Array = total.get("sources", []) as Array
	if not sources.is_empty():
		lines.append("From: %s" % ", ".join(PackedStringArray(sources)))
	var badge: Dictionary = {
		"icon": "retaliate",
		"fill": Color("4a3222"),
		"border": Color("f0c27a"),
		"icon_tint": Color.WHITE,
		"tooltip": "\n".join(lines)
	}
	if int(total["amount"]) > 0:
		badge["count"] = int(total["amount"])
	badges.append(badge)
	return badges
