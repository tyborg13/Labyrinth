extends RefCounted
## All state changes are resolved by the production combat and surface rules.

const Base = preload("res://tools/fx20/cases.gd")
const GROUND := Vector2i(4, 3)
const STOP := Vector2i(4, 4)
const WALL := Vector2i(4, 5)
const BURST_TARGET := Vector2i(3, 3)
const TRAP_DAMAGE: int = 4
const PUSH_DAMAGE: int = 4
const PUSH_DISTANCE: int = 1
const BURST_FUEL_HP: int = 3
const FLOOR_COLLISION_DAMAGE: int = 0
const FLOOR_COLLISION_BLOCK_GAIN: int = 0
const SURFACES: Dictionary = {"ice_melt": "ice", "rubble_clear": "rubble", "fire_out": "fire", "electrified_end": "electrified"}
const ENEMIES: Dictionary = {
	"push_wall": ["crawler", "skitter_strike", Base.NEAR, "push"],
	"veil_needle": ["veilbound_acolyte", "veil_needle", Base.FAR, "ranged"],
	"veil_melee": ["veilbound_acolyte", "closing_shade", Base.NEAR, "melee"],
	"ooze_melee": ["cinder_ooze", "smolder_slide", Base.NEAR, "melee"],
	"droplet_melee": ["cinder_droplet", "spatter", Base.NEAR, "melee"],
	"shale_aoe": ["bile_bloomer", "bile_burst", Base.NEAR, "aoe"],
}
const CARDS: Dictionary = {
	"targeted_fire": ["cinder_bloom", 0, Base.FAR],
	"targeted_fog": ["cinder_bloom", 0, Base.FAR],
	"ground_burst": ["immolation", 1, Base.HERO],
	"terrain_burst": ["worldbreak", 0, GROUND],
	"illusion_burst": ["shattered_reflection", 0, GROUND],
	"steel_melee": ["quick_stab", 0, Base.NEAR],
}
const CASES: Array[String] = [
	"ice_melt", "rubble_clear", "fire_out", "electrified_end", "collision_hit", "collision_floor",
	"veil_needle", "veil_melee", "ooze_melee", "droplet_melee", "shale_aoe", "targeted_fire",
	"targeted_fog", "ground_burst", "terrain_burst", "illusion_burst", "steel_melee", "fire_entry", "surface_paint",
	"trap_unmapped", "push_wall", "ice_trap", "elementless_trap",
]
const REDUCED: Array[String] = ["ice_melt", "collision_floor", "veil_needle", "targeted_fire"]
const TRAP_ELEMENTS: Dictionary = {"trap_unmapped": "shadow", "ice_trap": "ice", "elementless_trap": "none"}

class NoDamageCollision extends CombatEngine:
	func _relic_effects(state: Dictionary) -> Array[Dictionary]:
		var effects: Array[Dictionary] = super._relic_effects(state).duplicate()
		effects.append({"type": "collision_player_defense", "damage_per_tile": FLOOR_COLLISION_DAMAGE, "block": FLOOR_COLLISION_BLOCK_GAIN})
		return effects

static func configure(id: String, engine: RefCounted, state: Dictionary) -> void:
	Base.configure(id, engine, state)
	for y: int in range(1, 7):
		for x: int in range(2, 7):
			state["grid"][y][x] = "stone"
	if SURFACES.has(id):
		BoardSurfaceRules.place(state, GROUND, SURFACES[id])
	if TRAP_ELEMENTS.has(id):
		state["traps"] = [{"id": "fx24_trap", "pos": STOP, "element": TRAP_ELEMENTS[id], "damage": GameData.fixed_point_amount(TRAP_DAMAGE), "armed": true}]
	match id:
		"collision_hit", "collision_floor", "push_wall":
			state["grid"][WALL.y][WALL.x] = "wall"
			if id == "push_wall":
				state["enemies"][0]["intent"]["actions"] = [{"type": "push", "range": 1, "amount": PUSH_DISTANCE,
					"damage": GameData.fixed_point_amount(PUSH_DAMAGE), "element": "none"}]
		"fire_entry":
			BoardSurfaceRules.place(state, STOP, "fire")
			state["player"]["pos"] = GROUND
		"ground_burst":
			state["enemies"][0]["pos"] = Base.NEAR
			BoardSurfaceRules.place(state, Base.NEAR, "fire")
		"terrain_burst":
			state["enemies"][0]["pos"] = BURST_TARGET
			state["terrain"] = [{"id": "fx24_outcrop", "kind": "crag_outcrop", "pos": GROUND,
				"hp": BURST_FUEL_HP, "max_hp": BURST_FUEL_HP, "owner_kind": "player"}]
		"illusion_burst":
			state["enemies"][0]["pos"] = BURST_TARGET
			engine._create_illusion(state, GROUND, BURST_FUEL_HP)
		"targeted_fog":
			state["umbra"]["stage"] = "heart"
			state["umbra"]["stage_reduction"] = 0

static func ground_step(id: String, engine: RefCounted, state: Dictionary) -> Dictionary:
	if SURFACES.has(id):
		return BoardSurfaceRules.remove(state, GROUND, SURFACES[id], "clear")
	if TRAP_ELEMENTS.has(id):
		return engine._trigger_trap_at_index(state, 0)
	match id:
		"collision_hit", "collision_floor":
			var resolver: RefCounted = NoDamageCollision.new() if id == "collision_floor" else engine
			return resolver._force_move_actor(state, "player", -1, Vector2i.DOWN, 1, {}, true)
		"fire_entry":
			return engine._force_move_actor(state, "player", -1, Vector2i.DOWN, 1, {}, true)
		"surface_paint":
			return BoardSurfaceRules.place(state, GROUND, "ice")
	return {}

static func event_kind(id: String) -> String:
	if SURFACES.has(id): return "surface_removed"
	if TRAP_ELEMENTS.has(id): return "trap_triggered"
	match id:
		"collision_hit", "collision_floor": return "force_collision"
		"fire_entry": return "surface_damage"
		"surface_paint": return "surface_created"
	return ""
