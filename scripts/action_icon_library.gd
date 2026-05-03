extends RefCounted
class_name ActionIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")

const ICON_ROOT: String = "res://assets/art/icons"

const KEYWORDS: Dictionary = {
	"melee": {
		"label": "Melee",
		"description": "Deals damage up close.",
		"path": "%s/melee.png" % ICON_ROOT
	},
	"ranged": {
		"label": "Ranged",
		"description": "Deals damage from a distance.",
		"path": "%s/ranged.png" % ICON_ROOT
	},
	"move": {
		"label": "Move",
		"description": "Moves across board tiles.",
		"path": "%s/move.png" % ICON_ROOT
	},
	"retreat": {
		"label": "Retreat",
		"description": "Moves away from the target.",
		"path": "%s/retreat.png" % ICON_ROOT
	},
	"blink": {
		"label": "Blink",
		"description": "Teleports to another tile.",
		"path": "%s/blink.png" % ICON_ROOT
	},
	"range": {
		"label": "Range",
		"description": "Maximum target distance in tiles.",
		"path": "%s/range.png" % ICON_ROOT
	},
	"block": {
		"label": "Block",
		"description": "Absorbs incoming damage before health.",
		"path": "%s/block.png" % ICON_ROOT
	},
	"stoneskin": {
		"label": "Stoneskin",
		"description": "Persistent armor that absorbs damage across turns.",
		"path": "%s/stoneskin.png" % ICON_ROOT
	},
	"heal": {
		"label": "Heal",
		"description": "Restores health.",
		"path": "%s/heal.png" % ICON_ROOT
	},
	"draw": {
		"label": "Draw",
		"description": "Adds cards to your hand.",
		"path": "%s/draw.png" % ICON_ROOT
	},
	"burn": {
		"label": "Burn",
		"description": "Fire damage over time. Ticks at the start of turn, then decays.",
		"path": "%s/burn.png" % ICON_ROOT
	},
	"exhaust": {
		"label": "Exhaust",
		"description": "Removes this card from the deck for the rest of combat.",
		"path": "%s/exhaust.png" % ICON_ROOT
	},
	"freeze": {
		"label": "Freeze",
		"description": "Stops the affected unit from acting on its next turn.",
		"path": "%s/freeze.png" % ICON_ROOT
	},
	"shock": {
		"label": "Shock",
		"description": "Disrupts the affected unit's next action.",
		"path": "%s/shock.png" % ICON_ROOT
	},
	"stun": {
		"label": "Stun",
		"description": "Skips the affected unit's next action.",
		"path": "%s/shock.png" % ICON_ROOT
	},
	"poison": {
		"label": "Poison",
		"description": "Delayed damage that lands after its countdown.",
		"path": "%s/poison.png" % ICON_ROOT
	},
	"chain": {
		"label": "Chain",
		"description": "Jumps to additional nearby enemies.",
		"path": "%s/chain.png" % ICON_ROOT
	},
	"push": {
		"label": "Push",
		"description": "Forces the target away.",
		"path": "%s/push.png" % ICON_ROOT
	},
	"pull": {
		"label": "Pull",
		"description": "Forces the target closer.",
		"path": "%s/pull.png" % ICON_ROOT
	},
	"health": {
		"label": "Health",
		"description": "Health paid or restored.",
		"path": "%s/health.png" % ICON_ROOT
	},
	"health_cost": {
		"label": "Health Cost",
		"description": "Health paid to play this card.",
		"path": "%s/health.png" % ICON_ROOT
	}
}

static func all_icon_keys() -> Array:
	return KEYWORDS.keys()

static func icon_path(icon_key: String) -> String:
	return str((KEYWORDS.get(icon_key, {}) as Dictionary).get("path", ""))

static func icon_texture(icon_key: String) -> Texture2D:
	return AssetLoader.load_texture(icon_path(icon_key))

static func label(icon_key: String) -> String:
	return str((KEYWORDS.get(icon_key, {}) as Dictionary).get("label", icon_key.capitalize()))

static func description(icon_key: String) -> String:
	return str((KEYWORDS.get(icon_key, {}) as Dictionary).get("description", ""))

static func tooltip(icon_key: String) -> String:
	var text: String = label(icon_key)
	var detail: String = description(icon_key)
	if detail.is_empty():
		return text
	return "%s\n%s" % [text, detail]

static func token_tooltip(token: Dictionary) -> String:
	return str(token.get("tooltip", tooltip(str(token.get("icon", "")))))

static func token_value_text(token: Dictionary) -> String:
	if not token.has("value"):
		return ""
	var value: Variant = token.get("value", "")
	if value == null:
		return ""
	return str(value)

static func token_for(icon_key: String, value: Variant = null, tone: String = "neutral", tooltip_override: String = "") -> Dictionary:
	var token: Dictionary = {
		"icon": icon_key,
		"tone": tone
	}
	if value != null:
		token["value"] = value
	if not tooltip_override.is_empty():
		token["tooltip"] = tooltip_override
	return token

static func rows_for_actions(actions: Array, options_by_index: Array = []) -> Array:
	var rows: Array = []
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var options: Dictionary = {}
		if index < options_by_index.size() and typeof(options_by_index[index]) == TYPE_DICTIONARY:
			options = options_by_index[index]
		var row: Array = tokens_for_action(actions[index] as Dictionary, options)
		if not row.is_empty():
			rows.append(row)
	return rows

static func rows_for_card(card: Dictionary, options_by_index: Array = []) -> Array:
	var rows: Array = cost_rows_for_card(card)
	rows.append_array(rows_for_actions(card.get("actions", []), options_by_index))
	return rows

static func cost_rows_for_card(card: Dictionary) -> Array:
	var row: Array = []
	if bool(card.get("burn", false)):
		row.append(token_for("exhaust"))
	var health_cost: int = int(card.get("health_cost", 0))
	if health_cost > 0:
		row.append(token_for("health_cost", "-%d" % health_cost))
	return [row] if not row.is_empty() else []

static func tokens_for_action(action: Dictionary, options: Dictionary = {}) -> Array:
	var action_type: String = str(action.get("type", ""))
	var tokens: Array = []
	match action_type:
		"cost":
			if bool(action.get("exhaust", false)):
				tokens.append(token_for("exhaust"))
			var health_cost: int = int(action.get("health", action.get("health_cost", 0)))
			if health_cost > 0:
				tokens.append(token_for("health_cost", "-%d" % health_cost))
		"exhaust":
			tokens.append(token_for("exhaust"))
		"health_cost":
			var health_cost: int = int(action.get("amount", action.get("health", 0)))
			if health_cost > 0:
				tokens.append(token_for("health_cost", "-%d" % health_cost))
		"move", "move_toward":
			tokens.append(token_for("move", int(action.get("range", 0))))
		"move_away":
			tokens.append(token_for("retreat", int(action.get("range", 0))))
		"blink":
			tokens.append(token_for("blink", int(action.get("range", 0))))
		"melee":
			_append_damage_token(tokens, "melee", action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(token_for("range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"ranged":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(token_for("range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"aoe":
			_append_damage_token(tokens, "ranged" if int(action.get("range", 0)) > 0 else "melee", action, options)
			if int(action.get("range", 0)) > 0:
				tokens.append(token_for("range", int(action.get("range", 0))))
			tokens.append(_aoe_pattern_token(action))
			_append_keyword_tokens(tokens, action)
		"push":
			tokens.append(token_for("push", int(action.get("amount", 0))))
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(token_for("range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"pull":
			tokens.append(token_for("pull", int(action.get("amount", 0))))
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(token_for("range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"block":
			tokens.append(token_for("block", int(action.get("amount", 0))))
		"stoneskin":
			tokens.append(token_for("stoneskin", int(action.get("amount", 0))))
		"heal", "heal_self":
			tokens.append(token_for("heal", int(action.get("amount", 0))))
		"draw":
			tokens.append(token_for("draw", int(action.get("amount", 0))))
		"lightning_strikes":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(token_for("shock", int(action.get("count", 0)), "neutral", "Random lightning strikes."))
			_append_keyword_tokens(tokens, action)
		"summon_minions":
			tokens.append(token_for("shock", int(action.get("count", 0)), "neutral", "Summons lightning wisps."))
	return tokens

static func plain_text_for_tokens(tokens: Array) -> String:
	var parts: PackedStringArray = []
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			parts.append("Area")
			continue
		var value_text: String = token_value_text(token)
		if value_text.is_empty():
			parts.append(label(str(token.get("icon", ""))))
		else:
			parts.append("%s %s" % [label(str(token.get("icon", ""))), value_text])
	return "  ".join(parts)

static func plain_text_for_rows(rows: Array) -> String:
	var lines: PackedStringArray = []
	for row_var: Variant in rows:
		if typeof(row_var) != TYPE_ARRAY:
			continue
		lines.append(plain_text_for_tokens(row_var as Array))
	return "\n".join(lines)

static func _append_damage_token(tokens: Array, icon_key: String, action: Dictionary, options: Dictionary) -> void:
	var base_damage: int = int(action.get("damage", 0))
	var final_damage: int = int(options.get("final_damage", base_damage))
	tokens.append(token_for(icon_key, final_damage, _damage_tone(final_damage, base_damage)))

static func _append_optional_hit_token(tokens: Array, action: Dictionary, options: Dictionary) -> void:
	if int(action.get("damage", 0)) <= 0:
		return
	var base_damage: int = int(action.get("damage", 0))
	var final_damage: int = int(options.get("final_damage", base_damage))
	tokens.append(token_for("melee", final_damage, _damage_tone(final_damage, base_damage)))

static func _aoe_pattern_token(action: Dictionary) -> Dictionary:
	return {
		"kind": "aoe_pattern",
		"icon": "aoe_pattern",
		"pattern": action.get("pattern", []),
		"show_origin": int(action.get("range", 0)) <= 0,
		"tooltip": "Area pattern\nRed tiles are hit%s." % (" relative to you" if int(action.get("range", 0)) <= 0 else "")
	}

static func _append_keyword_tokens(tokens: Array, action: Dictionary) -> void:
	if int(action.get("burn", 0)) > 0:
		tokens.append(token_for("burn", int(action.get("burn", 0))))
	if int(action.get("freeze", 0)) > 0:
		tokens.append(token_for("freeze", int(action.get("freeze", 0))))
	if int(action.get("shock", 0)) > 0:
		tokens.append(token_for("shock", int(action.get("shock", 0))))
	if int(action.get("stun", 0)) > 0:
		tokens.append(token_for("stun", int(action.get("stun", 0))))
	if int(action.get("chain", 0)) > 0:
		tokens.append(token_for("chain", int(action.get("chain", 0))))
	if int(action.get("push", 0)) > 0:
		tokens.append(token_for("push", int(action.get("push", 0))))
	if int(action.get("pull", 0)) > 0:
		tokens.append(token_for("pull", int(action.get("pull", 0))))
	if int(action.get("poison", 0)) > 0:
		tokens.append(token_for("poison", int(action.get("poison", 0))))

static func _damage_tone(final_damage: int, base_damage: int) -> String:
	if final_damage > base_damage:
		return "bonus"
	if final_damage < base_damage:
		return "penalty"
	return "neutral"
