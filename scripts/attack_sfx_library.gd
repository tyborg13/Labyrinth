extends RefCounted
class_name AttackSfxLibrary

const MELEE_SFX_ID: String = "attack.melee"
const RANGED_SFX_ID: String = "attack.ranged"
const BLOCK_SFX_ID: String = "action.block"
const EMBER_COLLECT_SFX_ID: String = "reward.ember_collect"

const SFX: Dictionary = {
	MELEE_SFX_ID: {
		"path": "res://assets/audio/sfx/attack_melee_sword_first.wav",
		"duration": 0.68,
		"volume_db": -4.0
	},
	RANGED_SFX_ID: {
		"path": "res://assets/audio/sfx/attack_ranged_bow.wav",
		"duration": 0.72,
		"volume_db": -2.0
	},
	BLOCK_SFX_ID: {
		"path": "res://assets/audio/sfx/action_block.wav",
		"duration": 0.50,
		"volume_db": -3.0
	},
	EMBER_COLLECT_SFX_ID: {
		"path": "res://assets/audio/sfx/ember_collect.wav",
		"duration": 0.45,
		"volume_db": -5.0
	}
}

const CATEGORY_SFX: Dictionary = {
	"block": BLOCK_SFX_ID,
	"melee": MELEE_SFX_ID,
	"ranged": RANGED_SFX_ID
}

static func entry_for_player_action(card: Dictionary, action: Dictionary) -> Dictionary:
	var sfx_id: String = _explicit_sfx_id_for_player_action(card, action)
	if sfx_id.is_empty():
		var category: String = _explicit_sfx_category_for_player_action(card, action)
		if category.is_empty():
			category = category_for_action(action)
		sfx_id = str(CATEGORY_SFX.get(category, RANGED_SFX_ID))
	return entry(sfx_id)

static func entry_for_enemy_action(action: Dictionary) -> Dictionary:
	var sfx_id: String = str(action.get("sfx_id", action.get("attack_sfx_id", "")))
	if sfx_id.is_empty():
		var category: String = str(action.get("sfx_category", action.get("attack_sfx_category", "")))
		if category.is_empty():
			category = category_for_action(action)
		sfx_id = str(CATEGORY_SFX.get(category, RANGED_SFX_ID))
	return entry(sfx_id)

static func entry_for_enemy_step(step: Dictionary) -> Dictionary:
	var sfx_id: String = str(step.get("sfx_id", ""))
	if sfx_id.is_empty():
		var category: String = str(step.get("sfx_category", ""))
		if category.is_empty():
			category = category_for_kind(str(step.get("kind", "")), int(step.get("range", 0)))
		sfx_id = str(CATEGORY_SFX.get(category, RANGED_SFX_ID))
	return entry(sfx_id)

static func entry_for_block_action(card: Dictionary, action: Dictionary) -> Dictionary:
	var sfx_id: String = str(action.get("sfx_id", action.get("block_sfx_id", "")))
	if sfx_id.is_empty():
		sfx_id = str(card.get("block_sfx_id", ""))
	if sfx_id.is_empty():
		sfx_id = BLOCK_SFX_ID
	return entry(sfx_id)

static func entry_for_ember_collect() -> Dictionary:
	return entry(EMBER_COLLECT_SFX_ID)

static func entry(sfx_id: String) -> Dictionary:
	if not SFX.has(sfx_id):
		return {}
	var result: Dictionary = (SFX.get(sfx_id, {}) as Dictionary).duplicate(true)
	result["id"] = sfx_id
	return result

static func category_for_action(action: Dictionary) -> String:
	return category_for_kind(str(action.get("type", "")), int(action.get("range", 0)))

static func category_for_kind(kind: String, attack_range: int = 0) -> String:
	match kind:
		"melee":
			return "melee"
		"block":
			return "block"
		"aoe":
			return "ranged" if attack_range > 0 else "melee"
		"ranged", "push", "pull", "lightning_strikes":
			return "ranged"
		_:
			return ""

static func _explicit_sfx_id_for_player_action(card: Dictionary, action: Dictionary) -> String:
	var action_sfx_id: String = str(action.get("sfx_id", action.get("attack_sfx_id", "")))
	if not action_sfx_id.is_empty():
		return action_sfx_id
	var by_action: Dictionary = card.get("attack_sfx_by_action", {}) as Dictionary
	var action_type: String = str(action.get("type", ""))
	if by_action.has(action_type):
		return str(by_action.get(action_type, ""))
	return str(card.get("attack_sfx_id", ""))

static func _explicit_sfx_category_for_player_action(card: Dictionary, action: Dictionary) -> String:
	var action_category: String = str(action.get("sfx_category", action.get("attack_sfx_category", "")))
	if not action_category.is_empty():
		return action_category
	var by_action: Dictionary = card.get("attack_sfx_category_by_action", {}) as Dictionary
	var action_type: String = str(action.get("type", ""))
	if by_action.has(action_type):
		return str(by_action.get(action_type, ""))
	return str(card.get("attack_sfx_category", ""))
