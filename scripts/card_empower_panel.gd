extends RefCounted

const Keywords = preload("res://scripts/card_keyword_rules.gd")
const PanelText = preload("res://scripts/card_panel_text.gd")

# Authored Empower clauses, with numbers supplied by the same actions as play.
const BONUSES: Dictionary = {
	"bloody_lunge": "+{damage} damage",
	"blood_price": "+{damage} damage and Pierce",
	"cinder_bloom": "the larger area shown",
	"shatterline": "the longer area shown",
	"chain_bolt": "Chain {chain}",
	"royal_bramble": "Expose {expose}",
	"earthen_rampart": "{pattern_count} tiles",
	"hurl_spear": "+{damage} damage and Immobilize",
	"mirror_image": "{health} Health for the Illusion",
	"overclock": "Draw {amount} cards instead",
	"overhead_smash": "Stagger {stagger}",
	"tremor": "Stagger {stagger} instead",
	"wind_shear": "Push each target {push} instead",
	"immolation": "each Fire tile within {pattern_radius} instead",
}

static func projected_spec(card: Dictionary, spec: Dictionary, project: Callable, follow_up: bool) -> Dictionary:
	if not project.is_valid() or (spec.get("mods", []) as Array).is_empty():
		return spec
	var ordinary: Array = project.call(Keywords.actions_with_modifiers(card, {"follow_up": follow_up}))
	var empowered: Array = project.call(Keywords.actions_with_modifiers(card, {"follow_up": follow_up, "empowered": true}))
	var result: Dictionary = spec.duplicate(true)
	for mod: Dictionary in result["mods"]:
		var index: int = int(mod.get("action", -1))
		if index < 0 or index >= ordinary.size():
			continue
		for field: String in mod.get("set", {}):
			mod["set"][field] = empowered[index].get(field, mod["set"][field])
		for field: String in mod.get("add", {}):
			mod["add"][field] = int(empowered[index].get(field, 0)) - int(ordinary[index].get(field, 0))
	return result

static func bonus_copy(card: Dictionary, spec: Dictionary) -> String:
	var printed_id: String = str(card.get("base_card_id", card.get("id", str(card.get("name", "")).to_snake_case())))
	var template: String = str(BONUSES.get(printed_id, ""))
	if template.is_empty():
		return ""
	var values: Dictionary = {}
	for mod: Dictionary in spec.get("mods", []):
		values.merge(mod.get("add", {}), true)
		values.merge(mod.get("set", {}), true)
	for field: String in values:
		if values[field] is float: values[field] = int(values[field])
	if values.has("pattern"):
		var pattern: Array = values["pattern"]
		var radius: int = 0
		for offset: Variant in pattern:
			radius = maxi(radius, absi(int(offset[0])) + absi(int(offset[1])))
		values["pattern_count"] = pattern.size()
		values["pattern_radius"] = PanelText.tiles(radius)
	if values.has("push"):
		values["push"] = PanelText.tiles(int(values["push"]))
	return template.format(values)
