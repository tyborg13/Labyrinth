extends RefCounted

## pla-01 trait chips. A rule exception that belongs to one unit is shown on
## that unit (a status-plate chip with its hover, and a row on its inspection
## panel), never as a caveat inside a keyword. Presentation only; each rule
## stays with its owner: Steadfast -> CardKeywordRules.stagger_delay (half,
## then the per-turn cap, which stays Grimoire-only), Immune -> enemies.json
## status_immunities, Anchored -> Gust.force_anchored (Push, Pull and Wind),
## Command -> WarbandCombatRules.command_bonus.
const Data = preload("res://scripts/game_data.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Glossary = preload("res://scripts/glossary.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const Maneuvers = preload("res://scripts/maneuver_rules.gd")
const STEADFAST: String = "Steadfast"
const IMMUNE: String = "Immune"
const COMMAND: String = "Command"
# Shown immunities, keyed by status. Iskaldra's Freeze immunity is left to the
# Freeze ledger unit. Icons reuse the status's own icon until purpose-built
# trait icons exist (pla-01 follow-up).
const IMMUNITY_ICONS: Dictionary = {"shock": "shock", "immobilize": "immobilize"}
const STEADFAST_ICON: String = "stagger"
const COMMAND_ICON: String = "melee"

static func steadfast_token(unit: Dictionary) -> Dictionary:
	if not Dragons.is_dragon_boss_id(str(unit.get("type", ""))): return {}
	return _token(STEADFAST_ICON, STEADFAST, "Takes half Stagger.", "steadfast")

static func tokens(unit: Dictionary, state: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var type: String = str(unit.get("type", ""))
	var definition: Dictionary = Data.enemies().get(type, {}) as Dictionary
	var steadfast: Dictionary = steadfast_token(unit)
	if not steadfast.is_empty():
		result.append(steadfast)
	for status_var: Variant in definition.get("status_immunities", []):
		var status: String = str(status_var)
		if IMMUNITY_ICONS.has(status):
			result.append(_token(str(IMMUNITY_ICONS[status]), IMMUNE, "This enemy is immune to %s." % Glossary.name_for(status), "immune_" + status))
	if bool(definition.get("anchored", false)):
		result.append(_token("anchored", Glossary.name_for("anchored"), Glossary.definition("anchored"), "anchored"))
	var command: Dictionary = command_values(unit, state)
	if not command.is_empty():
		var token: Dictionary = _token(COMMAND_ICON, COMMAND, "Followers within %d tiles of the captain deal +%d damage." % [int(command["radius"]), int(command["bonus"])], "command")
		token["display_tooltip"] = "@pattern(diamond:%d) Followers on these tiles deal +%d damage." % [int(command["radius"]), int(command["bonus"])]
		result.append(token)
	return result

## The live Warband captain's Command reach and bonus, or {} for anyone else.
static func command_values(unit: Dictionary, state: Dictionary) -> Dictionary:
	if not Warband.active(state) or not bool(unit.get("is_leader", false)): return {}
	var command: Dictionary = (state.get("objective", {}) as Dictionary).get("command", {}) as Dictionary
	if command.is_empty(): return {}
	return {"radius": int(command.get("radius", 0)), "bonus": Data.fixed_point_amount(int(command.get("damage_bonus", 0)))}

## Status-plate chips in the existing trait style; hover reads "Name\nsentence".
static func badges(unit: Dictionary, state: Dictionary = {}) -> Array[Dictionary]:
	var result: Array[Dictionary]
	if int(unit.get("hp", 0)) <= 0: return result
	for token: Dictionary in tokens(unit, state):
		var tooltip: String = str(token["value"]) + "\n" + str(token["tooltip"])
		if str(token["icon"]) == "anchored":
			# Same chip the Gale Herald always showed; only its sentence is now the keyword's.
			for badge: Dictionary in Maneuvers.player_badges({"self_flags": {"anchored": {}}}):
				badge["tooltip"] = tooltip
				badge["status_class"] = "trait"
				result.append(badge)
			continue
		var badge: Dictionary = {"status_class": "trait", "icon": str(token["icon"]), "count": 0, "fill": Palette.STEEL, "border": Palette.STEEL, "icon_tint": Color.WHITE, "tooltip": tooltip}
		if str(token.get("glossary_key", "")) == "command": badge["count_text"] = "+%d" % int(command_values(unit, state)["bonus"])
		result.append(badge)
	return result

static func _token(icon: String, title: String, sentence: String, id: String) -> Dictionary:
	var token: Dictionary = Icons.icon_text_token(icon, title, sentence)
	token["glossary_key"] = id
	token["unit_trait"] = id
	return token
