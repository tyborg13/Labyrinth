extends RefCounted
class_name DepthRules

const Bosses = preload("res://scripts/dragon_boss_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const DATA_PATH: String = "res://data/depths.json"
const MAX_DEPTH: int = 20
const STATE_KEY: String = "umbra_depth"
# Director-approved exceptions; other heterogeneous rosters use their first
# authored helper type.
const EXTRA_HELPER_TYPES: Dictionary = {"rimejaw": "rime_whelp", "storm_cantor": "bell_tender"}
static var _data: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if parsed is Dictionary: _data = parsed
	return _data

static func depth(state: Dictionary) -> int:
	return clampi(int(state.get(STATE_KEY, 0)), 0, MAX_DEPTH)

static func levels(selected: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for level: Dictionary in data().get("levels", []):
		if int(level["depth"]) <= clampi(selected, 0, MAX_DEPTH): result.append(level.duplicate(true))
	return result

static func modifier(state: Dictionary, type: String, enemy_class: String = "") -> Dictionary:
	if depth(state) == 0: return {}
	for level: Dictionary in data().get("levels", []):
		if int(level["depth"]) > depth(state): break
		var rule: Dictionary = level["modifier"]
		if str(rule["type"]) == type and (enemy_class.is_empty() or str(rule.get("class", "")) == enemy_class): return rule
	return {}

static func amount(state: Dictionary, type: String, fallback: int = 0, enemy_class: String = "") -> int:
	return int(modifier(state, type, enemy_class).get("amount", fallback))

static func guardian_weight(state: Dictionary, base: int) -> int:
	return roundi(float(base) * float(modifier(state, "map_guardian_weight").get("multiplier", 1.0)))

static func enemy_class(enemy: Dictionary) -> String:
	var type: String = str(enemy.get("type", ""))
	if bool(enemy.get("guardian_helper", false)) or not Guardians.for_guardian(type).is_empty(): return "guardian"
	if Bosses.is_dragon_boss_id(type): return "dragon"
	return "" if bool(enemy.get("summoned", false)) else "regular"

static func enemy_hp(state: Dictionary, enemy: Dictionary, base: int) -> int:
	if depth(state) == 0: return base
	var category: String = enemy_class(enemy)
	var hp: int = base
	if not category.is_empty(): hp = ceili(float(hp) * amount(state, "enemy_hp_percent", 100, category) / 100.0)
	var enrage: Dictionary = modifier(state, "boss_enrage")
	if str(enemy.get("type", "")) == str(enrage.get("boss", "")) and not enrage.is_empty():
		hp = ceili(float(hp) * int(enrage["hp_percent"]) / 100.0)
	return hp

static func damage_bonus(state: Dictionary, enemy: Dictionary) -> int:
	var category: String = enemy_class(enemy)
	var bonus: int = amount(state, "enemy_damage_bonus", 0, category) if not category.is_empty() else 0
	var enrage: Dictionary = modifier(state, "boss_enrage")
	if not enrage.is_empty() and str(enemy.get("type", "")) == str(enrage["boss"]): bonus += int(enrage["damage_bonus"])
	return bonus

static func damaging_action(state: Dictionary, enemy: Dictionary, action: Dictionary) -> Dictionary:
	if depth(state) == 0: return action
	# The caller owns a freshly scaled action, so previews and committed plans
	# receive one bonus without changing catalog data or loaded held intents.
	if action.has("damage") and int(action["damage"]) > 0:
		action["damage"] = int(action["damage"]) + damage_bonus(state, enemy)
	return action

static func enemy_initiative(state: Dictionary, enemy: Dictionary, base: int) -> int:
	if depth(state) == 0: return base
	if enemy_class(enemy) != "regular": return base
	var rule: Dictionary = modifier(state, "enemy_initiative_delta", "regular")
	return maxi(3, base + int(rule["amount"])) if not rule.is_empty() else base

static func sight_radius(state: Dictionary, stage: String, section: int, base: int) -> int:
	var rule: Dictionary = modifier(state, "umbra_sight_delta")
	if rule.is_empty() or stage in ["clear", "eclipse"] or section < int(rule["from_section"]): return base
	return maxi(1, base + int(rule["amount"]))

static func start_max_hp(state: Dictionary, base: int) -> int:
	return base + amount(state, "max_hp_delta")

static func start_hp(state: Dictionary, max_hp: int) -> int:
	return ceili(float(max_hp) * amount(state, "start_hp_percent", 100) / 100.0)

static func hearth_heal(state: Dictionary, base: int) -> int:
	return maxi(1, base + amount(state, "hearth_heal_delta"))

static func rarity_weight(state: Dictionary, rarity: String, base: int) -> int:
	return int((modifier(state, "card_reward_rarity_weights").get("weights", {}) as Dictionary).get(rarity, base))

static func round_half_up_percent(base: int, percent: int) -> int:
	return floori(float(base) * float(percent) / 100.0 + 0.5)

static func dragon_embers(state: Dictionary, base: int) -> int:
	return round_half_up_percent(base, amount(state, "dragon_ember_percent", 100))

static func dragon_victory_embers(state: Dictionary, enemy_reward: int, victory_bonus: int) -> int:
	# Death rewards are presented immediately. Pay the remaining part at victory
	# so the combined dragon amount is rounded once, including active omens.
	return dragon_embers(state, enemy_reward + victory_bonus) - dragon_embers(state, enemy_reward)

static func cost_percent(base: int, percent: int) -> int:
	return ceili(float(base) * percent / 500.0) * 5

static func shop_price(state: Dictionary, base: int) -> int:
	var rule: Dictionary = modifier(state, "shop_price_percent")
	return cost_percent(base, int(rule["amount"])) if not rule.is_empty() else base

static func event_value(state: Dictionary, type: String, value: int) -> int:
	var rule: Dictionary = modifier(state, "event_costs")
	if value >= 0 or rule.is_empty(): return value
	match type:
		"hp": return value - int(rule["hp_delta"])
		"max_hp": return value - int(rule["max_hp_delta"])
		"embers": return -cost_percent(-value, int(rule["ember_cost_percent"]))
	return value

static func event_requirement(state: Dictionary, type: String, value: int) -> int:
	match type:
		"hp_above": return -event_value(state, "hp", -value)
		"max_hp_above": return -event_value(state, "max_hp", -value)
		"embers_at_least": return -event_value(state, "embers", -value)
	return value

static func extra_helper_type(guardian_id: String) -> String:
	if EXTRA_HELPER_TYPES.has(guardian_id): return str(EXTRA_HELPER_TYPES[guardian_id])
	var helpers: Array = Guardians.for_guardian(guardian_id).get("helpers", [])
	return str(helpers[0]) if not helpers.is_empty() else ""

static func score_percent(state: Dictionary) -> int:
	return depth(state) * int(data().get("score_bonus_percent_per_depth", 5))

static func score_bonus(state: Dictionary, total: int) -> int:
	return round_half_up_percent(total, score_percent(state))
