extends RefCounted

const Base = preload("res://tools/fx20/cases.gd")
const PushOrigin := Vector2i(4, 1)
const PullOrigin := Vector2i(4, 1)
const PullTarget := Vector2i(4, 5)
const TERRAIN_TILE := Vector2i(5, 3)
const TERRAIN_HP: int = 7
const TODO_DESIGN_SHALE_AOE_REPLACEMENT: String = ""
const TARGETED_SHALE := ["bile_bloomer", "spore_mark", Base.FAR, Base.HERO, "ranged"]
const CINDER := ["cinder_ooze", "cinder_bloom", Base.NEAR, Base.HERO, "aoe"]
const DIRECT_PULL := ["vaeloryx", "skyhook", PullOrigin, PullTarget, "pull"]
const CASES: Dictionary = {
	"shale_hit": TARGETED_SHALE,
	"shale_blocked": TARGETED_SHALE,
	"shale_aoe": ["bile_bloomer", "bile_burst", Base.NEAR, Base.HERO, "aoe"],
	"cinder_bloom": CINDER,
	"cinder_bloom_terrain": CINDER,
	"vaeloryx_push": ["vaeloryx", "hollow_gale", PushOrigin, Base.HERO, "push"],
	"vaeloryx_pull": DIRECT_PULL,
	"vaeloryx_pull_floor": DIRECT_PULL,
	"vaeloryx_pull_fog": DIRECT_PULL,
	"vaeloryx_skyhook": ["vaeloryx", "skyhook", PullOrigin, PullTarget, "ranged"],
}

static func configure(case_id: String, combat: RefCounted, state: Dictionary) -> void:
	Base.configure(case_id, combat, state)
	var config: Array = CASES[case_id]
	var foe: Dictionary = state["enemies"][0]
	# Some authored cases use compound transports. Exercise the raw resolver
	# push/pull or ranged variant in this fixture without changing live data.
	var wanted: String = {"push": "aoe", "pull": "ranged"}.get(config[4], config[4])
	var intent: Dictionary = foe["intent"]
	for authored: Dictionary in GameData.enemy_def(config[0])["intents"]:
		if authored["id"] == config[1]:
			intent = authored.duplicate(true)
			break
	var actions: Array[Dictionary]
	for action: Dictionary in intent["actions"]:
		if action["type"] != wanted: continue
		var kind: String = config[4]
		if kind in ["push", "pull"]:
			action["type"] = kind
			action["amount"] = action[kind]
			if case_id == "vaeloryx_push":
				intent["id"] = ""
				action.erase("committed_shape")
				action.erase("pattern_footprint")
			if case_id == "vaeloryx_pull_floor": action["damage"] = 0
		actions.append(action)
	intent["actions"] = actions
	if case_id in ["shale_hit", "shale_blocked"]: intent["id"] = "bile_burst"
	foe["intent"] = intent
	if case_id in ["shale_blocked", "vaeloryx_pull"]:
		state["player"]["block"] = GameData.fixed_point_amount(Base.FULL_BLOCK)
	if case_id == "vaeloryx_pull_fog":
		state["umbra"]["stage"] = "heart"
		state["umbra"]["stage_reduction"] = 0
	# Keep the fixture's named neighbouring tiles open and visible.
	if config[0] == "cinder_ooze" or case_id == "shale_aoe":
		for y: int in range(1, 6):
			for x: int in range(2, 7):
				state["grid"][y][x] = "stone"
	if case_id == "cinder_bloom_terrain":
		state["terrain"] = [{"id": "fx22_crag", "kind": "crag_outcrop", "pos": TERRAIN_TILE, "hp": TERRAIN_HP, "max_hp": TERRAIN_HP}]
	if config[0] == "vaeloryx":
		for y: int in range(1, 7): state["grid"][y][5] = "stone"

static func targets(case_id: String, step: Dictionary) -> Array[Vector2i]:
	if CASES[case_id][0] != "vaeloryx":
		return preload("res://scripts/dragon_presentation.gd").tiles(step)
	var front: Vector2i = CASES[case_id][2] + Vector2i.DOWN
	var target: Vector2i = step["player_from"]
	var result: Array[Vector2i]
	for y: int in range(front.y, target.y + 1): result.append(Vector2i(target.x, y))
	return result
