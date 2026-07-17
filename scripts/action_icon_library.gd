extends RefCounted
class_name ActionIconLibrary

const AssetLoader = preload("res://scripts/asset_loader.gd")
const ElementData = preload("res://scripts/element_data.gd")

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
	"pierce": {
		"label": "Pierce",
		"description": "Deals damage straight through block and stoneskin.",
		"path": "%s/pierce.png" % ICON_ROOT
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
	"card_play": {
		"label": "Card Play",
		"description": "Adds card plays for this turn.",
		"path": "%s/card_play.png" % ICON_ROOT
	},
	"flurry": {
		"label": "Flurry",
		"description": "Spends all current card plays. Repeats printed actions and health cost once per play spent; pays Time once.",
		"path": "%s/flurry.png" % ICON_ROOT
	},
	"time": {
		"label": "Time",
		"description": "Adds to the initiative delay before your next turn.",
		"path": "%s/time.png" % ICON_ROOT
	},
	"illusion": {
		"label": "Illusion",
		"description": "Creates a stationary copy that enemies can target.",
		"path": "%s/illusion.png" % ICON_ROOT
	},
	"illuminate": {
		"label": "Illuminate",
		"description": "Creates a light that reveals nearby Umbra tiles.",
		"path": "%s/illuminate.png" % ICON_ROOT
	},
	"vision": {
		"label": "Vision",
		"description": "Expands the light centered on you.",
		"path": "%s/vision.png" % ICON_ROOT
	},
	"truesight": {
		"label": "Truesight",
		"description": "Reveals and permits targeting enemies through the Umbra.",
		"path": "%s/truesight.png" % ICON_ROOT
	},
	"dispel_umbra": {
		"label": "Dispel Umbra",
		"description": "Reduces this combat's Umbra stage.",
		"path": "%s/dispel_umbra.png" % ICON_ROOT
	},
	"eclipse": {
		"label": "Eclipse",
		"description": "Forces the arena into absolute Umbra. Radiance and light offer protection.",
		"path": "%s/eclipse.svg" % ICON_ROOT
	},
	"burn": {
		"label": "Burn",
		"description": "Fire damage over time. Ticks at the start of turn, then decays.",
		"path": "%s/burn.png" % ICON_ROOT
	},
	"bleed": {
		"label": "Bleed",
		"description": "Physical wound damage. Triggers before actual move or attack actions, then clears after the next turn.",
		"path": "%s/bleed.png" % ICON_ROOT
	},
	"expose": {
		"label": "Expose",
		"description": "The next hit against this target deals extra damage.",
		"path": "%s/expose.png" % ICON_ROOT
	},
	"sunder": {
		"label": "Sunder",
		"description": "Breaks block and stoneskin before damage lands.",
		"path": "%s/sunder.png" % ICON_ROOT
	},
	"exhaust": {
		"label": "Exhaust",
		"description": "Removes this card from the deck for the rest of combat.",
		"path": "%s/exhaust.png" % ICON_ROOT
	},
	"consume": {
		"label": "Consume",
		"description": "Uses this item card once, then removes it from the run.",
		"path": "%s/consume.png" % ICON_ROOT
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
	"immobilize": {
		"label": "Immobilize",
		"description": "Stops movement for the rest of the turn.",
		"path": "%s/immobilize.png" % ICON_ROOT
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
	},
	"element_fire": {
		"label": "Fire Intensity",
		"description": "Room-wide Fire power. Some Fire card effects need this value.",
		"path": "%s/intensity_fire.png" % ICON_ROOT
	},
	"element_ice": {
		"label": "Ice Intensity",
		"description": "Room-wide Ice power. Some Ice card effects need this value.",
		"path": "%s/intensity_ice.png" % ICON_ROOT
	},
	"element_lightning": {
		"label": "Lightning Intensity",
		"description": "Room-wide Lightning power. Some Lightning card effects need this value.",
		"path": "%s/intensity_lightning.png" % ICON_ROOT
	},
	"element_air": {
		"label": "Air Intensity",
		"description": "Room-wide Air power. Some Air card effects need this value.",
		"path": "%s/intensity_air.png" % ICON_ROOT
	},
	"element_earth": {
		"label": "Earth Intensity",
		"description": "Room-wide Earth power. Some Earth card effects need this value.",
		"path": "%s/intensity_earth.png" % ICON_ROOT
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
	var text: String = str(token.get("tooltip", tooltip(str(token.get("icon", "")))))
	var modifier_lines: PackedStringArray = _modifier_tooltip_lines(token)
	if modifier_lines.is_empty():
		return text
	return "%s\nModified by:\n%s" % [text, "\n".join(modifier_lines)]

static func token_value_text(token: Dictionary) -> String:
	if not token.has("value"):
		return ""
	var value: Variant = token.get("value", "")
	if value == null:
		return ""
	return str(value)

static func token_for(icon_key: String, value: Variant = null, tone: String = "neutral", tooltip_override: String = "", modifiers: Array = [], base_value: Variant = null) -> Dictionary:
	var token: Dictionary = {
		"icon": icon_key,
		"tone": tone
	}
	if value != null:
		token["value"] = value
	if not tooltip_override.is_empty():
		token["tooltip"] = tooltip_override
	if not modifiers.is_empty():
		token["modifiers"] = modifiers.duplicate(true)
		token["modified"] = true
		if base_value != null:
			token["base_value"] = base_value
	return token

static func text_token(text: String, tone: String = "neutral", tooltip_override: String = "") -> Dictionary:
	var token: Dictionary = {
		"kind": "text",
		"value": text,
		"tone": tone
	}
	if not tooltip_override.is_empty():
		token["tooltip"] = tooltip_override
	return token

static func element_icon_key(element_id: String) -> String:
	return "element_%s" % str(element_id)

static func token_is_modified(token: Dictionary) -> bool:
	return bool(token.get("modified", false)) or not (token.get("modifiers", []) as Array).is_empty()

static func _token_for_action_field(action: Dictionary, icon_key: String, field: String, value: Variant = null, tone: String = "neutral", tooltip_override: String = "", base_value: Variant = null, extra_modifiers: Array = []) -> Dictionary:
	var modifiers: Array = _action_modifiers_for_field(action, field)
	for modifier_var: Variant in extra_modifiers:
		if typeof(modifier_var) == TYPE_DICTIONARY:
			modifiers.append((modifier_var as Dictionary).duplicate(true))
	var resolved_base_value: Variant = base_value
	if resolved_base_value == null and value != null and not modifiers.is_empty() and typeof(value) in [TYPE_INT, TYPE_FLOAT]:
		resolved_base_value = int(value) - _modifier_amount_total(modifiers)
	var resolved_tone: String = tone
	if resolved_tone == "neutral" and resolved_base_value != null and value != null and typeof(value) in [TYPE_INT, TYPE_FLOAT] and typeof(resolved_base_value) in [TYPE_INT, TYPE_FLOAT]:
		resolved_tone = _value_tone(int(value), int(resolved_base_value))
	var token: Dictionary = token_for(icon_key, value, resolved_tone, tooltip_override, modifiers, resolved_base_value)
	if not field.is_empty():
		token["field"] = field
	return token

static func _action_modifiers_for_field(action: Dictionary, field: String) -> Array:
	var modifiers: Array = []
	if typeof(action.get("_modifiers", {})) != TYPE_DICTIONARY:
		return modifiers
	var modifiers_by_field: Dictionary = action.get("_modifiers", {}) as Dictionary
	var modifier_keys: Array = ["_action"]
	if field != "_action":
		modifier_keys.append(field)
	for key: String in modifier_keys:
		if key.is_empty():
			continue
		if typeof(modifiers_by_field.get(key, [])) != TYPE_ARRAY:
			continue
		for modifier_var: Variant in modifiers_by_field.get(key, []):
			if typeof(modifier_var) == TYPE_DICTIONARY:
				modifiers.append((modifier_var as Dictionary).duplicate(true))
	return modifiers

static func _option_modifiers_for_field(options: Dictionary, field: String) -> Array:
	var modifiers: Array = []
	var field_key: String = "%s_modifiers" % field
	if typeof(options.get(field_key, [])) == TYPE_ARRAY:
		for modifier_var: Variant in options.get(field_key, []):
			if typeof(modifier_var) == TYPE_DICTIONARY:
				modifiers.append((modifier_var as Dictionary).duplicate(true))
	if typeof(options.get("modifiers_by_field", {})) == TYPE_DICTIONARY:
		var by_field: Dictionary = options.get("modifiers_by_field", {}) as Dictionary
		if typeof(by_field.get(field, [])) == TYPE_ARRAY:
			for modifier_var: Variant in by_field.get(field, []):
				if typeof(modifier_var) == TYPE_DICTIONARY:
					modifiers.append((modifier_var as Dictionary).duplicate(true))
	return modifiers

static func _modifier_amount_total(modifiers: Array) -> int:
	var total: int = 0
	for modifier_var: Variant in modifiers:
		if typeof(modifier_var) != TYPE_DICTIONARY:
			continue
		total += int((modifier_var as Dictionary).get("amount", 0))
	return total

static func _modifier_tooltip_lines(token: Dictionary) -> PackedStringArray:
	var lines: PackedStringArray = []
	for modifier_var: Variant in token.get("modifiers", []):
		if typeof(modifier_var) != TYPE_DICTIONARY:
			continue
		var modifier: Dictionary = modifier_var
		var source: String = str(modifier.get("source", "Modifier"))
		var label_text: String = str(modifier.get("label", ""))
		if label_text.is_empty() and int(modifier.get("amount", 0)) != 0:
			label_text = "%+d" % int(modifier.get("amount", 0))
		var detail: String = str(modifier.get("detail", ""))
		var line: String = source
		if not label_text.is_empty():
			line = "%s %s" % [line, label_text]
		if not detail.is_empty():
			line = "%s  %s" % [line, detail]
		lines.append(line)
	return lines

static func rows_for_actions(actions: Array, options_by_index: Array = []) -> Array:
	var rows: Array = []
	var previous_action_row_index: int = -1
	for index: int in range(actions.size()):
		if typeof(actions[index]) != TYPE_DICTIONARY:
			continue
		var action: Dictionary = actions[index] as Dictionary
		var options: Dictionary = {}
		if index < options_by_index.size() and typeof(options_by_index[index]) == TYPE_DICTIONARY:
			options = options_by_index[index]
		var row: Array = tokens_for_action(action, options)
		previous_action_row_index = append_action_row(rows, action, row, previous_action_row_index)
		var bonus_row: Array = tokens_for_intensity_bonus(action)
		if not bonus_row.is_empty():
			rows.append(bonus_row)
	return rows

static func append_action_row(rows: Array, action: Dictionary, row: Array, previous_action_row_index: int = -1) -> int:
	if row.is_empty():
		return previous_action_row_index
	if bool(action.get("reuse_previous_target", false)) and previous_action_row_index >= 0 and previous_action_row_index < rows.size():
		var shared_row: Array = (rows[previous_action_row_index] as Array).duplicate(true)
		for token_var: Variant in row:
			if typeof(token_var) == TYPE_DICTIONARY and _duplicates_shared_range(shared_row, token_var as Dictionary):
				continue
			shared_row.append(token_var)
		for token_index: int in range(shared_row.size()):
			if typeof(shared_row[token_index]) != TYPE_DICTIONARY:
				continue
			var token: Dictionary = (shared_row[token_index] as Dictionary).duplicate(true)
			token["keep_row_together"] = true
			shared_row[token_index] = token
		rows[previous_action_row_index] = shared_row
		return previous_action_row_index
	rows.append(row)
	return rows.size() - 1

static func _duplicates_shared_range(row: Array, candidate: Dictionary) -> bool:
	if str(candidate.get("icon", "")) != "range":
		return false
	for existing_var: Variant in row:
		if typeof(existing_var) != TYPE_DICTIONARY:
			continue
		var existing: Dictionary = existing_var
		if str(existing.get("icon", "")) == "range" and existing.get("value", null) == candidate.get("value", null):
			return true
	return false

static func rows_for_card(card: Dictionary, options_by_index: Array = []) -> Array:
	var rows: Array = cost_rows_for_card(card)
	rows.append_array(rows_for_actions(card.get("actions", []), options_by_index))
	return rows

static func cost_rows_for_card(card: Dictionary) -> Array:
	var row: Array = []
	if bool(card.get("burn", false)):
		row.append(token_for("exhaust"))
	if bool(card.get("consume_on_play", false)):
		row.append(token_for("consume"))
	if bool(card.get("flurry", false)):
		row.append(token_for("flurry"))
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
		"consume":
			tokens.append(token_for("consume"))
		"health_cost":
			var health_cost: int = int(action.get("amount", action.get("health", 0)))
			if health_cost > 0:
				tokens.append(token_for("health_cost", "-%d" % health_cost))
		"move", "move_toward":
			tokens.append(_token_for_action_field(action, "move", "range", int(action.get("range", 0))))
		"move_away":
			tokens.append(_token_for_action_field(action, "retreat", "range", int(action.get("range", 0))))
		"blink":
			tokens.append(_token_for_action_field(action, "blink", "range", int(action.get("range", 0))))
		"melee":
			_append_damage_token(tokens, _damage_icon_for_action(action, "melee"), action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"ranged":
			_append_damage_token(tokens, _damage_icon_for_action(action, "ranged"), action, options)
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
		"aoe":
			_append_damage_token(tokens, _damage_icon_for_action(action, "ranged" if int(action.get("range", 0)) > 0 else "melee"), action, options)
			if int(action.get("range", 0)) > 0:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			tokens.append(_aoe_pattern_token(action))
			_append_keyword_tokens(tokens, action)
		"push":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0))))
		"pull":
			_append_optional_hit_token(tokens, action, options)
			if int(action.get("range", 0)) > 1:
				tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0))))
			_append_keyword_tokens(tokens, action)
			tokens.append(_token_for_action_field(action, "pull", "amount", int(action.get("amount", 0))))
		"block", "guard_ally":
			tokens.append(_token_for_action_field(action, "block", "amount", int(action.get("amount", 0))))
		"stoneskin":
			tokens.append(_token_for_action_field(action, "stoneskin", "amount", int(action.get("amount", 0))))
		"heal", "heal_self", "heal_ally":
			tokens.append(_token_for_action_field(action, "heal", "amount", int(action.get("amount", 0))))
		"draw":
			tokens.append(_token_for_action_field(action, "draw", "amount", int(action.get("amount", 0))))
		"card_play":
			tokens.append(_token_for_action_field(action, "card_play", "amount", int(action.get("amount", 0))))
		"intensity":
			var intensity_element: String = _action_element(action)
			var intensity_amount: int = int(action.get("amount", 0))
			var intensity_token: Dictionary = token_for(
				element_icon_key(intensity_element),
				"+%d" % intensity_amount,
				"neutral",
				"%s Intensity\nRaise %s intensity in this room by %d." % [
					ElementData.name(intensity_element),
					ElementData.name(intensity_element),
					intensity_amount
				]
			)
			intensity_token["kind"] = "elemental_intensity"
			intensity_token["element"] = intensity_element
			tokens.append(intensity_token)
		"illusion":
			tokens.append(_token_for_action_field(action, "illusion", "health", int(action.get("health", action.get("amount", 0)))))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Illusion placement range."))
		"illuminate":
			tokens.append(_token_for_action_field(action, "illuminate", "radius", int(action.get("radius", action.get("amount", 1))), "neutral", "Light radius in tiles."))
			tokens.append(_token_for_action_field(action, "range", "range", int(action.get("range", 0)), "neutral", "Light placement range."))
			var light_duration: int = int(action.get("duration", 1))
			tokens.append(token_for("time", "∞" if light_duration < 0 else light_duration, "neutral", "Player activations this light remains."))
		"vision":
			tokens.append(_token_for_action_field(action, "vision", "amount", int(action.get("amount", 0))))
			var vision_duration: int = int(action.get("duration", 1))
			tokens.append(token_for("time", "∞" if vision_duration < 0 else vision_duration, "neutral", "Player activations this vision remains."))
		"truesight":
			var truesight_duration: int = int(action.get("duration", action.get("amount", 1)))
			tokens.append(token_for("truesight", "∞" if truesight_duration < 0 else truesight_duration))
		"dispel_umbra":
			tokens.append(_token_for_action_field(action, "dispel_umbra", "amount", int(action.get("amount", 1))))
		"lightning_strikes":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "shock", "count", int(action.get("count", 0)), "neutral", "Random lightning strikes."))
			_append_keyword_tokens(tokens, action)
		"summon_minions":
			tokens.append(_token_for_action_field(action, "shock", "count", int(action.get("count", 0)), "neutral", "Summons lightning wisps."))
		"raise_terrain":
			tokens.append(_token_for_action_field(action, "stoneskin", "count", int(action.get("count", 0)), "neutral", "Raises attackable Worldspines around the arena."))
			tokens.append(_token_for_action_field(action, "health", "health", int(action.get("health", 0)), "neutral", "Health of each Worldspine."))
		"terrain_burst":
			_append_damage_token(tokens, "melee", action, options)
			tokens.append(text_token("Spire burst", "warning", "Every surviving Worldspine ruptures nearby tiles, then breaks."))
		"cinder_marks":
			tokens.append(_token_for_action_field(action, "burn", "count", int(action.get("count", 0)), "neutral", "Places attackable cinder marks; surviving marks detonate on the dragon's next activation."))
			_append_damage_token(tokens, "ranged", action, options)
			_append_keyword_tokens(tokens, action)
		"detonate_cinders":
			tokens.append(token_for("burn", null, "warning", "Detonates every surviving cinder mark in a blast around it."))
		"gale_force":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "push", "amount", int(action.get("amount", 0)), "neutral", "Pushes the player away from the dragon through arena hazards."))
		"frost_armor":
			tokens.append(_token_for_action_field(action, "freeze", "amount", int(action.get("amount", 0)), "neutral", "Forms crystal armor. Each damaging hit breaks one layer instead of dealing damage."))
		"umbra_eclipse":
			_append_damage_token(tokens, "ranged", action, options)
			tokens.append(_token_for_action_field(action, "eclipse", "duration", int(action.get("duration", 0)), "neutral", "Forces Eclipse for this many player activations. Radiance and light protect affected tiles."))
	var requirement: Dictionary = intensity_requirement_for_action(action)
	if not requirement.is_empty() and not tokens.is_empty():
		tokens.push_front(intensity_requirement_token(requirement))
	return tokens

static func intensity_bonus_for_action(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("intensity_bonus", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var bonus: Dictionary = (raw as Dictionary).duplicate(true)
	var element_id: String = str(bonus.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(bonus.get("threshold", bonus.get("amount", bonus.get("requires", 0))))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	bonus["element"] = element_id
	bonus["threshold"] = threshold
	return bonus

static func tokens_for_intensity_bonus(action: Dictionary) -> Array:
	var bonus: Dictionary = intensity_bonus_for_action(action)
	if bonus.is_empty():
		return []
	var element_id: String = str(bonus.get("element", ElementData.NONE))
	var tokens: Array = [intensity_requirement_token({
		"element": element_id,
		"amount": int(bonus.get("threshold", 0))
	})]
	var action_type: String = str(action.get("type", ""))
	if int(bonus.get("damage", 0)) > 0:
		tokens.append(_bonus_token(
			_damage_icon_for_action(action, _damage_bonus_fallback_icon(action)),
			int(bonus.get("damage", 0)),
			"Extra damage when %s intensity is high enough." % ElementData.name(element_id)
		))
	if int(bonus.get("amount", 0)) > 0 and action_type in ["push", "pull"]:
		tokens.append(_bonus_token(
			action_type,
			int(bonus.get("amount", 0)),
			"Extra forced movement when %s intensity is high enough." % ElementData.name(element_id)
		))
	for status_key: String in ["burn", "bleed", "expose", "sunder", "freeze", "shock", "poison", "chain", "push", "pull"]:
		if int(bonus.get(status_key, 0)) <= 0:
			continue
		tokens.append(_bonus_token(
			status_key,
			int(bonus.get(status_key, 0)),
			"Extra %s when %s intensity is high enough." % [label(status_key).to_lower(), ElementData.name(element_id)]
		))
	if bool(bonus.get("immobilize", false)):
		tokens.append(token_for(
			"immobilize",
			"+",
			"neutral",
			"Immobilizes when %s intensity is high enough." % ElementData.name(element_id)
		))
	if bool(bonus.get("pierce", false)):
		tokens.append(token_for(
			"pierce",
			"+",
			"neutral",
			"Pierces defense when %s intensity is high enough." % ElementData.name(element_id)
		))
	if tokens.size() <= 1:
		return []
	return tokens

static func intensity_requirement_for_action(action: Dictionary) -> Dictionary:
	var raw: Variant = action.get("requires_intensity", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return {}
	var requirement: Dictionary = raw as Dictionary
	var element_id: String = str(requirement.get("element", action.get("element", action.get("_card_element", ElementData.NONE))))
	var threshold: int = int(requirement.get("amount", requirement.get("threshold", 0)))
	if not ElementData.is_elemental(element_id) or threshold <= 0:
		return {}
	return {
		"element": element_id,
		"amount": threshold
	}

static func intensity_requirement_token(requirement: Dictionary) -> Dictionary:
	var element_id: String = str(requirement.get("element", ElementData.NONE))
	var threshold: int = int(requirement.get("amount", 0))
	var token: Dictionary = token_for(
		element_icon_key(element_id),
		"%d+:" % threshold,
		"neutral",
		"%s Intensity %d+\nThis effect is active when this room's %s intensity is at least %d." % [
			ElementData.name(element_id),
			threshold,
			ElementData.name(element_id),
			threshold
		]
	)
	token["kind"] = "intensity_requirement"
	token["element"] = element_id
	token["threshold"] = threshold
	return token

static func _bonus_token(icon_key: String, amount: int, tooltip_text: String) -> Dictionary:
	return token_for(icon_key, "+%d" % amount, "neutral", tooltip_text)

static func _damage_bonus_fallback_icon(action: Dictionary) -> String:
	match str(action.get("type", "")):
		"ranged":
			return "ranged"
		"aoe":
			return "ranged" if int(action.get("range", 0)) > 0 else "melee"
		_:
			return "melee"

static func plain_text_for_tokens(tokens: Array) -> String:
	var parts: PackedStringArray = []
	for token_var: Variant in tokens:
		if typeof(token_var) != TYPE_DICTIONARY:
			continue
		var token: Dictionary = token_var
		if str(token.get("kind", "")) == "aoe_pattern":
			parts.append("Area")
			continue
		if str(token.get("kind", "")) == "intensity_requirement":
			parts.append("%s %s" % [ElementData.name(str(token.get("element", ElementData.NONE))), token_value_text(token)])
			continue
		if str(token.get("kind", "")) == "text":
			parts.append(token_value_text(token))
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
	var tone_base_damage: int = int(options.get("tone_base_damage", base_damage))
	tokens.append(_token_for_action_field(
		action,
		icon_key,
		"damage",
		final_damage,
		_damage_tone(final_damage, tone_base_damage),
		"",
		tone_base_damage,
		_option_modifiers_for_field(options, "damage")
	))

static func _damage_icon_for_action(action: Dictionary, fallback_icon: String) -> String:
	return "pierce" if bool(action.get("pierce", false)) else fallback_icon

static func _append_optional_hit_token(tokens: Array, action: Dictionary, options: Dictionary) -> void:
	if int(action.get("damage", 0)) <= 0:
		return
	var base_damage: int = int(action.get("damage", 0))
	var final_damage: int = int(options.get("final_damage", base_damage))
	var tone_base_damage: int = int(options.get("tone_base_damage", base_damage))
	tokens.append(_token_for_action_field(
		action,
		_damage_icon_for_action(action, "melee"),
		"damage",
		final_damage,
		_damage_tone(final_damage, tone_base_damage),
		"",
		tone_base_damage,
		_option_modifiers_for_field(options, "damage")
	))

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
		tokens.append(_token_for_action_field(action, "burn", "burn", int(action.get("burn", 0))))
	if int(action.get("bleed", 0)) > 0:
		tokens.append(_token_for_action_field(action, "bleed", "bleed", int(action.get("bleed", 0))))
	if int(action.get("expose", 0)) > 0:
		tokens.append(_token_for_action_field(action, "expose", "expose", int(action.get("expose", 0))))
	if int(action.get("sunder", 0)) > 0:
		tokens.append(_token_for_action_field(action, "sunder", "sunder", int(action.get("sunder", 0))))
	if int(action.get("freeze", 0)) > 0:
		tokens.append(_token_for_action_field(action, "freeze", "freeze", int(action.get("freeze", 0))))
	if int(action.get("shock", 0)) > 0:
		tokens.append(_token_for_action_field(action, "shock", "shock", int(action.get("shock", 0))))
	if bool(action.get("immobilize", false)):
		tokens.append(_token_for_action_field(action, "immobilize", "immobilize"))
	if int(action.get("chain", 0)) > 0:
		tokens.append(_token_for_action_field(action, "chain", "chain", int(action.get("chain", 0))))
	if int(action.get("poison", 0)) > 0:
		tokens.append(_token_for_action_field(action, "poison", "poison", int(action.get("poison", 0))))
	if int(action.get("push", 0)) > 0:
		tokens.append(_token_for_action_field(action, "push", "push", int(action.get("push", 0))))
	if int(action.get("pull", 0)) > 0:
		tokens.append(_token_for_action_field(action, "pull", "pull", int(action.get("pull", 0))))

static func _action_element(action: Dictionary) -> String:
	var element_id: String = str(action.get("element", action.get("_card_element", ElementData.NONE)))
	return element_id if ElementData.is_elemental(element_id) else ElementData.NONE

static func _damage_tone(final_damage: int, base_damage: int) -> String:
	return _value_tone(final_damage, base_damage)

static func _value_tone(final_value: int, base_value: int) -> String:
	if final_value > base_value:
		return "bonus"
	if final_value < base_value:
		return "penalty"
	return "neutral"
