extends RefCounted

const HERO := Vector2i(4, 4)
const NEAR := Vector2i(4, 3)
const FAR := Vector2i(4, 2)
const MIRROR := Vector2i(4, 1)
const DRAGON := Vector2i(4, 2)
const PROOF_HP := 30
const FULL_BLOCK := 20
const TRAP_DAMAGE := 4
const RAKE_TILES: Array[Vector2i] = [HERO, Vector2i(3, 4), Vector2i(5, 4)]
const STORM_TILES: Array[Vector2i] = [HERO, Vector2i(3, 4), NEAR]
const PLAYER: Dictionary = {
	"frostbolt": ["frostbolt", "crawler", "skitter_strike", FAR, FAR],
	"sunlance": ["sunlance", "crawler", "skitter_strike", FAR, FAR],
	"hurl_spear": ["hurl_spear", "crawler", "skitter_strike", FAR, FAR],
	"snake_eyes": ["snake_eyes", "crawler", "skitter_strike", FAR, FAR],
	"reflect_spear": ["hurl_spear", "glacial_mirror", "refraction", MIRROR, MIRROR],
	"reflect_frostbolt": ["frostbolt", "glacial_mirror", "refraction", MIRROR, MIRROR],
	"trap_area": ["immolation", "crawler", "skitter_strike", NEAR, HERO],
	"recording": ["frostbolt", "glacial_mirror", "refraction", MIRROR, MIRROR],
}
const ENEMY: Dictionary = {
	"bite": ["vyraketh", "cinder_maw", DRAGON, "melee"],
	"bite_blocked": ["vyraketh", "cinder_maw", DRAGON, "melee"],
	"rake": ["tharokh", "worldspine_claw", DRAGON, "aoe"],
	"veilbound": ["veilbound_acolyte", "closing_shade", NEAR, "melee"],
	"refraction": ["glacial_mirror", "refraction", MIRROR, "aoe"],
	"refraction_cancelled": ["glacial_mirror", "refraction", MIRROR, "aoe"],
	"refraction_fog": ["glacial_mirror", "refraction", MIRROR, "aoe"],
	"refraction_fallback": ["glacial_mirror", "refraction", MIRROR, "aoe"],
	"dust_bolt": ["acolyte", "dust_bolt", FAR, "ranged"],
	"skybreak": ["zekarion", "skybreak", DRAGON, "lightning_strikes"],
}
const EXTRA: Dictionary = {"meteorfall": "meteorfall", "icefall": "icefall", "board_lightning": "board_rule"}
const SPELLS: Array[String] = ["cinder_breath", "crownfire"]
const NATIVE: Array[String] = ["frostbolt", "bite", "rake", "veilbound", "refraction", "reflect_spear", "hurl_spear", "skybreak"]
const MATRIX: Array[String] = [
	"frostbolt", "sunlance", "hurl_spear", "snake_eyes", "dust_bolt", "skybreak", "board_lightning", "meteorfall", "icefall",
	"cinder_breath", "crownfire", "trap_area", "bite", "bite_blocked", "rake", "veilbound", "refraction",
	"refraction_cancelled", "refraction_fog", "refraction_fallback", "reflect_spear", "reflect_frostbolt", "recording",
]
const LARGE_CROP: Array[String] = ["bite", "bite_blocked", "rake", "refraction", "refraction_cancelled", "skybreak"]

static func configure(case_id: String, combat: RefCounted, state: Dictionary) -> void:
	state.erase("battlefield_rule")
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	var foe: Dictionary = state["enemies"][0]
	if case_id == "bite_blocked": state["player"]["block"] = GameData.fixed_point_amount(FULL_BLOCK)
	if case_id in ["rake", "skybreak"]:
		var action_type: String = ENEMY[case_id][3]
		for action: Dictionary in foe["intent"]["actions"]:
			if action["type"] == action_type:
				action["declared_tiles"] = RAKE_TILES.duplicate() if case_id == "rake" else STORM_TILES.duplicate()
				action.erase("area_fixed_tiles")
		for tile: Vector2i in RAKE_TILES: state["grid"][tile.y][tile.x] = "stone"
		preload("res://scripts/boss_area_rules.gd").freeze(combat, state, foe, foe["intent"])
	if case_id == "refraction_fog":
		state["umbra"]["stage"] = "eclipse"
		state["umbra"]["stage_reduction"] = 0
	if case_id == "trap_area":
		# The actual Immolation Detonate action triggers this trap in its area.
		BoardSurfaceRules.place(state, NEAR, "fire")
		state["traps"] = [{"id": "fx20_trap", "pos": NEAR, "element": "ice", "damage": GameData.fixed_point_amount(TRAP_DAMAGE), "armed": true}]
	for y: int in range(1, 7):
		state["grid"][y][HERO.x] = "stone"

static func enemy_step(combat: RefCounted, state: Dictionary, action_type: String, cancelled: bool) -> Dictionary:
	for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
		if action["type"] != action_type: continue
		var context: Dictionary = {}
		var after: Dictionary = state.duplicate(true)
		var events: Array[Dictionary]
		if cancelled:
			context["refraction_started"] = false
		else:
			after = combat._resolve_enemy_action(after, 0, action, null, {}, events, context)
		var step: Dictionary = combat._enemy_action_step(state, after, 0, action, context)
		if not step.is_empty() and not combat.is_enemy_visible_to_player(state, state["enemies"][0]):
			step["hidden_by_umbra"] = true
		return step
	return {}

static func coords(tile: Vector2i) -> String:
	return "%d:%d" % [tile.x, tile.y]
