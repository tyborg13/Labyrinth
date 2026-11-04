extends RefCounted

## Bind each authored numeral to its face token, in prose order. These are
## semantic bindings, not replacement copy or values. Equal base numbers can
## mean different things (Vision amount versus duration, damage versus range).
## An empty binding is a fixed geometric fact with no numeric face token.
const Icons = preload("res://scripts/action_icon_library.gd")
const NUMBER_TOKENS: Dictionary = {
	"crimson_draught": ["heal"],
	"mossglass_elixir": ["heal", "stoneskin"],
	"nail_bomb": ["ranged", "range", "sunder"],
	"pitch_firebomb": ["ranged", "range"],
	"frost_snare": ["ranged", "range"],
	"storm_jar": ["ranged", "chain", "range"],
	"smoke_bomb": ["blink", "block"],
	"jaw_trap": ["range", "ranged"],
	"bone_ward_charm": ["stoneskin", "block"],
	"grave_dust_satchel": ["pierce", "range"],
	"bitter_tonic": ["draw", "card_play"],
	"caltrops": ["range", "bleed"],
	"glacier_salts": ["range"],
	"lamp_oil": ["range"],
	"mirror_charm": ["illusion", "range"],
	"seers_candle": ["vision", "time"],
	"hourglass_sand": ["quicken", "quicken", "draw"],
	"throwing_net": ["range", "stagger"],
	"whetstone": ["next_attack"],
	"bottled_gale": ["push"],
	"flash_powder": ["illuminate", "range", "time", "", "expose"],
	"powder_keg": ["raise_terrain", "range", "detonate"],
	"smelling_salts": ["move"],
	"thunderstone": ["ranged", "stagger"],
}
const DAMAGE_ICONS: Array = ["ranged", "melee", "pierce", "aoe"]
static var _numbers: RegEx

static func numbers() -> RegEx:
	if _numbers == null:
		_numbers = RegEx.new()
		_numbers.compile("[0-9]+")
	return _numbers

static func token_number(rows: Array, icon: String) -> String:
	for row: Array in rows:
		for token: Dictionary in row:
			if str(token.get("icon", "")) != icon: continue
			var value: String = Icons.token_value_text(token)
			var match_value: RegExMatch = numbers().search(value)
			if match_value != null: return match_value.get_string()
	return ""

static func resolve(card_id: String, text: String, rows: Array) -> String:
	var bindings: Array = NUMBER_TOKENS.get(card_id, [])
	var matches: Array[RegExMatch] = numbers().search_all(text)
	# New authored items must add their bindings and pass the catalog regression.
	if bindings.size() != matches.size(): return text
	for index: int in range(matches.size() - 1, -1, -1):
		var icon: String = str(bindings[index])
		if icon.is_empty(): continue
		var value: String = token_number(rows, icon)
		# Pierce can replace a normal damage icon without changing its meaning.
		if value.is_empty() and DAMAGE_ICONS.has(icon):
			for damage_icon: String in DAMAGE_ICONS:
				value = token_number(rows, damage_icon)
				if not value.is_empty(): break
		if value.is_empty(): continue
		var span: RegExMatch = matches[index]
		text = text.substr(0, span.get_start()) + value + text.substr(span.get_end())
	return text
