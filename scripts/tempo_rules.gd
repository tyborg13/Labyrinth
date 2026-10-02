extends RefCounted
class_name TempoRules

## Activation-scoped tempo keywords: Quicken (the next card costs less Time),
## next-attack buffs, and the per-activation tiles-moved counter. All state
## lives in combat `turn_flags`, which prepare_next_player_turn replaces, and
## is also expired explicitly when the player's activation ends.
## This module must not preload GameData: GameData preloads it for card costs.
## See spec/card_keywords_wave3.md.

const RiteRules = preload("res://scripts/rite_rules.gd")

const QUICKEN_KEY: String = "quicken_pending"
const NEXT_ATTACK_KEY: String = "next_attack_buffs"
const NEXT_ATTACK_SEQ_KEY: String = "next_attack_seq"
const TILES_MOVED_KEY: String = "tiles_moved"
const LAST_CARD_KEY: String = "last_card_tempo"
const APPLIED_KEY: String = "_next_attack_bonus"
const PAYMENT_QUICKEN_KEY: String = "quicken"
const PAYMENT_BONUS_KEY: String = "next_attack_bonus_used"
const ATTACK_ACTION_TYPES: Array = ["melee", "ranged", "aoe", "push", "pull", "detonate"]

static func _flags(state: Dictionary) -> Dictionary:
	var flags: Variant = state.get("turn_flags", {})
	return flags as Dictionary if typeof(flags) == TYPE_DICTIONARY else {}

static func _set_flag(state: Dictionary, key: String, value: Variant) -> void:
	var flags: Dictionary = _flags(state).duplicate(true)
	if typeof(value) == TYPE_NIL:
		flags.erase(key)
	else:
		flags[key] = value
	state["turn_flags"] = flags

# --------------------------------------------------------------------- Quicken

static func quicken_pending(state: Dictionary) -> int:
	return maxi(0, int(_flags(state).get(QUICKEN_KEY, 0)))

static func gain_quicken(state: Dictionary, action: Dictionary) -> void:
	var amount: int = maxi(0, int(action.get("amount", 0)))
	if amount > 0:
		_set_flag(state, QUICKEN_KEY, quicken_pending(state) + amount)

## Applied in GameData.card_def_for_progression before the Hourglass reserve.
## Rite discounts apply to every card; ordinal relic discounts count finished
## cards (Flurry is one); Quicken applies to the next card. Each clamps at 1
## and stamps the base for the existing Time badge.
static func card_with_time_discount(card: Dictionary, state: Dictionary, effects: Array) -> Dictionary:
	if card.is_empty() or not card.has("time"):
		return card
	var quicken: int = quicken_pending(state)
	var rite_discount: int = RiteRules.card_time_discount(effects, card)
	var relic_discount: int = 0
	for effect: Dictionary in effects:
		if str(effect.get("type", "")) == "nth_card_time_discount" and int(_flags(state).get("cards_finished", 0)) + 1 == int(effect.get("card_number", 2)):
			relic_discount += maxi(0, int(effect.get("amount", 0)))
	if quicken + rite_discount + relic_discount <= 0:
		return card
	var base: int = maxi(1, int(card.get("time", 5)))
	var after_rite: int = maxi(1, base - rite_discount)
	var after_relic: int = maxi(1, after_rite - relic_discount)
	var after: int = maxi(1, after_relic - quicken)
	if after >= base:
		return card
	var result: Dictionary = card.duplicate(false)
	result["_time_discount_base"] = base
	result["_relic_time_discount"] = after_rite - after_relic
	result["_quicken_discount"] = after_relic - after
	result["_rite_time_discount"] = base - after_rite
	result["time"] = after
	return result

## The state a finished card is priced from: pending Quicken as it stood when
## the card began (its payment snapshot), so a Quicken card never pays itself.
static func pricing_state(state: Dictionary) -> Dictionary:
	var snapshot: Dictionary = state.get("pending_card_payment", {}) as Dictionary
	if not snapshot.has(PAYMENT_QUICKEN_KEY):
		return state
	var priced: Dictionary = state.duplicate(false)
	var flags: Dictionary = _flags(state).duplicate(false)
	flags[QUICKEN_KEY] = maxi(0, int(snapshot[PAYMENT_QUICKEN_KEY]))
	priced["turn_flags"] = flags
	return priced

## Consume the Quicken the finished card was priced with. Quicken the card
## itself granted remains pending for the next card.
static func finish_card(state: Dictionary, card_id: String, card: Dictionary, payment_snapshot: Dictionary, rite_started: bool) -> void:
	var buffs: Array = []
	for buff: Dictionary in next_attack_buffs(state):
		if not bool(buff.get("card_scoped", false)) or int(buff.get("granted_at", 0)) >= int(state.get("cards_played_this_turn", 0)) - 1:
			buffs.append(buff)
	_set_flag(state, NEXT_ATTACK_KEY, buffs if not buffs.is_empty() else null)
	var priced_pool: int = maxi(0, int(payment_snapshot.get(PAYMENT_QUICKEN_KEY, quicken_pending(state))))
	var remaining: int = maxi(0, quicken_pending(state) - priced_pool)
	_set_flag(state, QUICKEN_KEY, remaining if remaining > 0 else null)
	var bonus: Variant = payment_snapshot.get(PAYMENT_BONUS_KEY, null)
	state[LAST_CARD_KEY] = {
		"card_id": card_id,
		"quicken_spent": maxi(0, int(card.get("_quicken_discount", 0))),
		"next_attack_bonus_used": (bonus as Dictionary).duplicate(true) if typeof(bonus) == TYPE_DICTIONARY else null,
		"rite_started": card_id if rite_started else null
	}

static func expire_activation(state: Dictionary) -> void:
	var flags: Dictionary = _flags(state)
	if not flags.has(QUICKEN_KEY) and not flags.has(NEXT_ATTACK_KEY):
		return
	var next_flags: Dictionary = flags.duplicate(true)
	next_flags.erase(QUICKEN_KEY)
	next_flags.erase(NEXT_ATTACK_KEY)
	state["turn_flags"] = next_flags

## Additive card_played analytics fields, read from the post-commit state.
static func analytics_fields(resolved_state: Dictionary, card_id: String) -> Dictionary:
	var record: Dictionary = resolved_state.get(LAST_CARD_KEY, {}) as Dictionary if typeof(resolved_state.get(LAST_CARD_KEY, null)) == TYPE_DICTIONARY else {}
	if str(record.get("card_id", "")) != card_id:
		record = {}
	var bonus: Variant = record.get("next_attack_bonus_used", null)
	return {
		"quicken_spent": int(record.get("quicken_spent", 0)),
		"next_attack_bonus_used": (bonus as Dictionary).duplicate(true) if typeof(bonus) == TYPE_DICTIONARY else null,
		"rite_started": record.get("rite_started", null)
	}

# ---------------------------------------------------------------- Tiles moved

static func tiles_moved(state: Dictionary) -> int:
	return maxi(0, int(_flags(state).get(TILES_MOVED_KEY, 0)))

# The engine records movement once through CardKeywordRules.record_tiles_moved
# (same turn_flags key); this helper stays for tests that seed the counter.
static func add_tiles_moved(state: Dictionary, tiles: int) -> void:
	if tiles > 0:
		_set_flag(state, TILES_MOVED_KEY, tiles_moved(state) + tiles)

# ---------------------------------------------------------- Next-attack buffs

static func next_attack_buffs(state: Dictionary) -> Array:
	var buffs: Variant = _flags(state).get(NEXT_ATTACK_KEY, [])
	return buffs as Array if typeof(buffs) == TYPE_ARRAY else []

static func gain_next_attack(state: Dictionary, action: Dictionary, source_name: String = "") -> void:
	var seq: int = int(_flags(state).get(NEXT_ATTACK_SEQ_KEY, 0)) + 1
	var per_tile: Dictionary = action.get("per_tile_moved", {}) as Dictionary if typeof(action.get("per_tile_moved", null)) == TYPE_DICTIONARY else {}
	var buff: Dictionary = {
		"id": seq,
		"damage": maxi(0, int(action.get("damage", 0))),
		"pierce": bool(action.get("pierce", false)),
		"chain": maxi(0, int(action.get("chain", 0))),
		"element": str(action.get("element", "")),
		"per_tile_moved": per_tile.duplicate(true),
		# The granting card is still resolving; only a later card may use it.
		"granted_at": int(state.get("cards_played_this_turn", 0)),
		"immediate": bool(action.get("immediate", false)),
		"card_id": str(action.get("_card_id", "")),
		"source": source_name,
		"card_scoped": bool(action.get("card_scoped", false))
	}
	var buffs: Array = next_attack_buffs(state).duplicate(true)
	buffs.append(buff)
	var flags: Dictionary = _flags(state).duplicate(true)
	flags[NEXT_ATTACK_KEY] = buffs
	flags[NEXT_ATTACK_SEQ_KEY] = seq
	state["turn_flags"] = flags

static func _action_element(action: Dictionary) -> String:
	var element_id: String = str(action.get("element", action.get("_card_element", "none")))
	return element_id if not element_id.is_empty() else "none"

## A push/pull (or push/pull-only area) that deals no damage is forced
## movement, not an attack: it neither receives nor spends a next-attack buff,
## which waits for the card's later damaging hit (Sleet Squall's Ice hit) or
## the next card. Reads the resolver's copy, so surface bonuses that add
## damage still make it an attack.
static func is_forced_movement_only(action: Dictionary) -> bool:
	if int(action.get("damage", 0)) > 0:
		return false
	match str(action.get("type", "")):
		"push", "pull":
			return true
		"aoe":
			return int(action.get("push", 0)) > 0 or int(action.get("pull", 0)) > 0
	return false

static func eligible_buffs(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if action.has("_enemy_id") or bool(action.get("_movement_pool", false)):
		return result
	if str(action.get("type", "")) not in ATTACK_ACTION_TYPES or is_forced_movement_only(action):
		return result
	var played: int = int(state.get("cards_played_this_turn", 0))
	var element_id: String = _action_element(action)
	for buff_var: Variant in next_attack_buffs(state):
		if typeof(buff_var) != TYPE_DICTIONARY:
			continue
		var buff: Dictionary = buff_var as Dictionary
		if not bool(buff.get("immediate", false)) and played <= int(buff.get("granted_at", 0)):
			continue
		var wanted: String = str(buff.get("element", ""))
		if not wanted.is_empty() and wanted != element_id:
			continue
		result.append(buff)
	return result

static func buff_damage(state: Dictionary, buff: Dictionary) -> int:
	var damage: int = maxi(0, int(buff.get("damage", 0)))
	var per_tile: Dictionary = buff.get("per_tile_moved", {}) as Dictionary if typeof(buff.get("per_tile_moved", null)) == TYPE_DICTIONARY else {}
	if not per_tile.is_empty():
		var scaled: int = tiles_moved(state) * maxi(0, int(per_tile.get("damage", 1)))
		if per_tile.has("max"):
			scaled = mini(scaled, maxi(0, int(per_tile.get("max", scaled))))
		damage += scaled
	return damage

static func bonus_for_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var buffs: Array[Dictionary] = eligible_buffs(state, action)
	if buffs.is_empty():
		return {}
	var ids: Array = []
	var sources: Array = []
	var damage: int = 0
	var chain: int = 0
	var pierce: bool = false
	for buff: Dictionary in buffs:
		ids.append(int(buff.get("id", 0)))
		sources.append(str(buff.get("source", "")))
		damage += buff_damage(state, buff)
		chain += maxi(0, int(buff.get("chain", 0)))
		pierce = pierce or bool(buff.get("pierce", false))
	return {"ids": ids, "sources": sources, "damage": damage, "chain": chain, "pierce": pierce}

## Folded into CombatEngine._resolved_surface_action so final damage, previews,
## the hand display and resolution agree. Mutates the resolver-owned copy.
static func apply_next_attack_in_place(state: Dictionary, resolved: Dictionary) -> void:
	if resolved.has(APPLIED_KEY):
		return
	var bonus: Dictionary = bonus_for_action(state, resolved)
	if bonus.is_empty():
		return
	if int(bonus["damage"]) > 0:
		resolved["damage"] = int(resolved.get("damage", 0)) + int(bonus["damage"])
	if int(bonus["chain"]) > 0:
		resolved["chain"] = int(resolved.get("chain", 0)) + int(bonus["chain"])
	if bool(bonus["pierce"]):
		resolved["pierce"] = true
	resolved[APPLIED_KEY] = bonus

## Bleed is paid before a valid hit. The health-loss relic may change the
## pending pool after target validation but before its first consumption.
static func refresh_next_attack_in_place(state: Dictionary, resolved: Dictionary) -> void:
	var previous: Dictionary = resolved.get(APPLIED_KEY, {}) as Dictionary
	resolved["damage"] = int(resolved.get("damage", 0)) - int(previous.get("damage", 0))
	if int(previous.get("chain", 0)) > 0:
		resolved["chain"] = int(resolved.get("chain", 0)) - int(previous["chain"])
	resolved.erase(APPLIED_KEY)
	apply_next_attack_in_place(state, resolved)

## Called once when a buffed attack actually resolves.
static func consume_next_attack(state: Dictionary, action: Dictionary) -> void:
	var bonus: Dictionary = action.get(APPLIED_KEY, {}) as Dictionary if typeof(action.get(APPLIED_KEY, null)) == TYPE_DICTIONARY else {}
	if bonus.is_empty():
		return
	var used_ids: Array = bonus.get("ids", []) as Array
	var remaining: Array = []
	for buff_var: Variant in next_attack_buffs(state):
		if typeof(buff_var) == TYPE_DICTIONARY and (bool((buff_var as Dictionary).get("card_scoped", false)) or not used_ids.has(int((buff_var as Dictionary).get("id", 0)))):
			remaining.append(buff_var)
	_set_flag(state, NEXT_ATTACK_KEY, remaining if not remaining.is_empty() else null)
	if typeof(state.get("pending_card_payment", null)) == TYPE_DICTIONARY:
		var payment: Dictionary = (state["pending_card_payment"] as Dictionary).duplicate(true)
		if not payment.has(PAYMENT_BONUS_KEY):
			payment[PAYMENT_BONUS_KEY] = {
				"action_type": str(action.get("type", "")),
				"damage": int(bonus.get("damage", 0)),
				"chain": int(bonus.get("chain", 0)),
				"pierce": bool(bonus.get("pierce", false)),
				"sources": (bonus.get("sources", []) as Array).duplicate()
			}
		state["pending_card_payment"] = payment

## Display-only: mark eligible buffs spent on a simulation copy, so a second
## attack row on the same card does not show the bonus twice.
static func consume_for_preview(state: Dictionary, action: Dictionary) -> void:
	var bonus: Dictionary = bonus_for_action(state, action)
	if bonus.is_empty():
		return
	var remaining: Array = []
	for buff_var: Variant in next_attack_buffs(state):
		if typeof(buff_var) == TYPE_DICTIONARY and (bool((buff_var as Dictionary).get("card_scoped", false)) or not (bonus.get("ids", []) as Array).has(int((buff_var as Dictionary).get("id", 0)))):
			remaining.append(buff_var)
	var flags: Dictionary = _flags(state).duplicate(true)
	flags[NEXT_ATTACK_KEY] = remaining
	state["turn_flags"] = flags

static func damage_modifiers(state: Dictionary, action: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for buff: Dictionary in eligible_buffs(state, action):
		var damage: int = buff_damage(state, buff)
		if damage <= 0:
			continue
		result.append({
			"source": str(buff.get("source", "Next attack")) if not str(buff.get("source", "")).is_empty() else "Next attack",
			"kind": "next_attack",
			"amount": damage,
			"detail": "Next attack this turn"
		})
	return result

## Display copy of a hand action with next-attack Pierce/Chain folded in, so
## the card row shows the same keywords the attack will resolve with.
static func display_action(state: Dictionary, action: Dictionary) -> Dictionary:
	var bonus: Dictionary = bonus_for_action(state, action)
	if bonus.is_empty() or (int(bonus.get("chain", 0)) <= 0 and not bool(bonus.get("pierce", false))):
		return action
	var result: Dictionary = action.duplicate(true)
	var modifiers: Dictionary = (result.get("_modifiers", {}) as Dictionary).duplicate(true) if typeof(result.get("_modifiers", null)) == TYPE_DICTIONARY else {}
	var source: String = ", ".join(PackedStringArray(bonus.get("sources", []) as Array)).strip_edges()
	if source.is_empty():
		source = "Next attack"
	if int(bonus.get("chain", 0)) > 0:
		var before_chain: int = int(result.get("chain", 0))
		result["chain"] = before_chain + int(bonus["chain"])
		var chain_mods: Array = (modifiers.get("chain", []) as Array).duplicate(true)
		chain_mods.append({"source": source, "amount": int(bonus["chain"]), "label": "+%d chain" % int(bonus["chain"]), "field": "chain", "before": before_chain, "after": result["chain"]})
		modifiers["chain"] = chain_mods
	if bool(bonus.get("pierce", false)) and not bool(result.get("pierce", false)):
		result["pierce"] = true
		var pierce_mods: Array = (modifiers.get("pierce", []) as Array).duplicate(true)
		pierce_mods.append({"source": source, "amount": 0, "label": "adds Pierce", "field": "pierce", "before": false, "after": true})
		modifiers["pierce"] = pierce_mods
	result["_modifiers"] = modifiers
	return result

# --------------------------------------------------------------- HUD badges

static func player_badges(state: Dictionary) -> Array[Dictionary]:
	var badges: Array[Dictionary] = []
	var quicken: int = quicken_pending(state)
	if quicken > 0:
		badges.append({
			"icon": "quicken",
			"count": quicken,
			"fill": Color("27465a"),
			"border": Color("a8e4ff"),
			"icon_tint": Color.WHITE,
			"tooltip": "Quicken %d\nYour next card this turn costs %d less Time (minimum 1)." % [quicken, quicken]
		})
	var buffs: Array = next_attack_buffs(state)
	if buffs.is_empty():
		return badges
	var lines: PackedStringArray = []
	var total_damage: int = 0
	for buff_var: Variant in buffs:
		if typeof(buff_var) != TYPE_DICTIONARY:
			continue
		var buff: Dictionary = buff_var as Dictionary
		var damage: int = buff_damage(state, buff)
		total_damage += damage
		var parts: PackedStringArray = []
		if damage > 0:
			parts.append("+%d damage" % damage)
		if bool(buff.get("pierce", false)):
			parts.append("Pierce")
		if int(buff.get("chain", 0)) > 0:
			parts.append("Chain %d" % int(buff.get("chain", 0)))
		var element_id: String = str(buff.get("element", ""))
		var subject: String = "Next %s attack" % element_id.capitalize() if not element_id.is_empty() else "Next attack"
		if bool(buff.get("card_scoped", false)):
			subject = "Next card's attacks"
		var source: String = str(buff.get("source", ""))
		lines.append("%s: %s%s" % [subject, ", ".join(parts), (" (%s)" % source) if not source.is_empty() else ""])
	badges.append({
		"icon": "next_attack",
		"count": total_damage,
		"fill": Color("5a2621"),
		"border": Color("ffb08a"),
		"icon_tint": Color.WHITE,
		"tooltip": "Next attack\n%s\nExpires at the end of this turn." % "\n".join(lines)
	})
	return badges
