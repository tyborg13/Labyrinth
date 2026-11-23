extends RefCounted

const Cases20 = preload("res://tools/fx20/cases.gd")
const Typed = preload("res://scripts/typed_arrays.gd")
const BossArea = preload("res://scripts/boss_area_rules.gd")
const HERO := Cases20.HERO
const BOSS := Vector2i(3, 1)
const BOSS_MELEE := Vector2i(3, 2)
const AREA_TILES: Array[Vector2i] = [Vector2i(3, 4), HERO, Vector2i(5, 4)]
const REEL := "recording"
const NATIVE: Array[String] = ["area_ranged", "closing_shade", "veil_needle"]
# Echo and Shade Bolt publish at contact; flight is a follow-up unit.
# Enemy, authored intent, action type, source position. The area controls
# adapt Shade Bolt inside the fixture because both authored Shadow areas are dragons.
const CASES: Dictionary = {
	"closing_shade": ["veilbound_acolyte", "closing_shade", "melee", Cases20.NEAR],
	"ambush": ["gloam_stalker", "ambush", "melee", Cases20.FAR],
	"slash": ["gloam_stalker", "slash", "melee", Cases20.NEAR],
	"veil_needle": ["veilbound_acolyte", "veil_needle", "ranged", Cases20.FAR],
	"echo": ["hollow_mimic", "echo", "ranged", Cases20.FAR],
	"shade_bolt": ["hollow_mimic", "shade_bolt", "ranged", Cases20.FAR],
	"void_claw": ["noctyrax", "void_claw", "melee", BOSS_MELEE],
	"night_coil": ["noctyrax", "night_coil", "aoe", BOSS],
	"starless_breath": ["noctyrax", "starless_breath", "aoe", BOSS],
	"last_eclipse": ["noctyrax", "last_eclipse", "umbra_eclipse", BOSS],
	"area_ranged": ["hollow_mimic", "shade_bolt", "aoe", Cases20.FAR],
	"area_zero_blocked": ["hollow_mimic", "shade_bolt", "aoe", Cases20.NEAR],
	"area_umbra": ["hollow_mimic", "shade_bolt", "aoe", Cases20.NEAR],
	"area_terrain_hp": ["hollow_mimic", "shade_bolt", "aoe", Cases20.FAR],
	"terrain_burst": ["hollow_mimic", "shade_bolt", "terrain_burst", Cases20.FAR],
}

static func configure(id: String, state: Dictionary) -> void:
	state.erase("battlefield_rule")
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	# Keep the generated room and camera, clearing only the proof's local lanes.
	for y: int in range(1, 6):
		for x: int in range(3, 7):
			state["grid"][y][x] = "stone"
	if id == "area_zero_blocked":
		state["player"]["block"] = GameData.fixed_point_amount(Cases20.FULL_BLOCK)
	if id == "area_umbra":
		state["umbra"]["stage"] = "eclipse"
		state["umbra"]["stage_reduction"] = 0
		state["umbra"]["light_sources"] = []
	if id == "area_terrain_hp":
		var hp: int = GameData.fixed_point_amount(Cases20.FULL_BLOCK)
		state["terrain"] = [{"id": 1, "kind": "wooden_crate", "pos": AREA_TILES[0], "hp": hp, "max_hp": hp}]

static func step(id: String, combat: RefCounted, before: Dictionary, index: int = 0) -> Dictionary:
	var foe: Dictionary = before["enemies"][index]
	var kind: String = CASES[id][2]
	var authored: String = "ranged" if id.begins_with("area_") or id == "terrain_burst" else kind
	var intent: Dictionary = foe["intent"]
	for original: Dictionary in intent["actions"]:
		if original["type"] != authored: continue
		var action: Dictionary = original.duplicate(true)
		match id:
			"area_ranged", "area_terrain_hp":
				action.merge({"type": kind, "pattern": [[-1, 0], [0, 0], [1, 0]], "rotate": false}, true)
			"area_zero_blocked":
				action.merge({"type": kind, "range": 0, "pattern": [[-1, 1], [0, 1], [1, 1]], "rotate": false}, true)
			"area_umbra":
				action.merge({"type": kind, "range": 0, "pattern": [[0, 1], [1, 1], [2, 1]], "rotate": false}, true)
			"terrain_burst":
				action.merge({"type": kind, "range": 0, "consume_terrain": false, BossArea.FIELD: AREA_TILES}, true)
			"night_coil", "starless_breath":
				# Exercise the real committed action on a known three-tile declared strip.
				intent["actions"] = [action]
				action["declared_tiles"] = AREA_TILES
				action.erase(BossArea.FIELD)
				BossArea.freeze(combat, before, foe, intent)
		var context: Dictionary = {}
		var events: Array[Dictionary]
		var after: Dictionary = combat._resolve_enemy_action(before.duplicate(true), index, action, null, {}, events, context)
		var resolved: Dictionary = combat._enemy_action_step(before, after, index, action, context)
		if not resolved.is_empty() and not combat.is_enemy_visible_to_player(before, foe):
			resolved["hidden_by_umbra"] = true
		return {"step": resolved, "after": after}
	return {}

static func impact_step(step_data: Dictionary) -> Dictionary:
	return step_data.get("strike_step", step_data)

static func targets(step_data: Dictionary) -> Array[Vector2i]:
	var hit: Dictionary = impact_step(step_data)
	return Typed.vector2i([hit["to"]] if hit.get("kind") in ["melee", "ranged"] else hit.get("tiles", []))
