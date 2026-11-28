extends RefCounted

const EngineRules = preload("res://scripts/combat_engine.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const FIXTURE_SEED := 94301
const HERO := Vector2i(4, 4)
const EAST := Vector2i(5, 4)
const SOUTH := Vector2i(4, 5)
const NORTH := Vector2i(4, 3)
const WEST := Vector2i(3, 4)
const TEST_HEALTH := 24
const TEST_ENEMY_HEALTH := 1
const CASES := ["shadow", "humanoid", "multi", "burst", "terrain", "enemy_turn", "midfight", "reduced"]
const DESTRUCTIBLES := ["wooden_box", "wooden_crate", "powder_keg", "bramble", "crag_outcrop", "dragon_spire", "ice_pillar", "raised_cover"]

static func stage(scene: Node, test_case: String, subject: String = "") -> void:
	var run: Dictionary = scene._run_state.duplicate(true)
	var layout: Dictionary = run["current_room_layout"].duplicate(true)
	var grid: Array = []
	for y: int in range(9):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x in [0, 8] or y in [0, 8] else "stone")
		grid.append(row)
	layout["grid"] = grid
	layout["player_start"] = HERO
	layout["terrain"] = []
	layout["loot"] = []
	layout["traps"] = []
	layout.erase("objective")
	layout.erase("battlefield_rules")
	layout["enemies"] = []
	var kind: String = "arc_thrall" if test_case == "humanoid" else "ember_tick" if test_case == "burst" else "crawler"
	if not subject.is_empty() and not subject in DESTRUCTIBLES: kind = subject
	layout["enemies"].append(unit(1, kind, EAST))
	if test_case == "multi": layout["enemies"].append(unit(2, "crawler", SOUTH))
	if test_case == "burst": layout["enemies"].append(unit(2, "ember_tick", EAST + Vector2i.RIGHT))
	if test_case == "midfight": layout["enemies"].append(unit(2, "crawler", Vector2i(7, 7)))
	if test_case == "terrain" or subject in DESTRUCTIBLES:
		layout["terrain"].append({"id": "fel28_prop", "kind": subject if subject in DESTRUCTIBLES else "wooden_crate",
			"pos": NORTH, "hp": TEST_ENEMY_HEALTH, "max_hp": TEST_ENEMY_HEALTH})
	var combat: Dictionary = EngineRules.new().create_combat(FIXTURE_SEED, layout, {
		"hp": TEST_HEALTH, "max_hp": TEST_HEALTH, "deck_cards": ["whirlwind_slash"], "hand_size": 1, "relics": [],
	})
	combat["deck"]["hand"] = ["whirlwind_slash"]
	combat["deck"]["draw"] = []
	combat["deck"]["discard"] = []
	combat["umbra"]["radius"] = 99
	if test_case == "enemy_turn":
		Surfaces.place(combat, EAST, "fire", {"actor_kind": "player"})
	run["combat_state"] = combat
	run["current_room_layout"] = layout
	run["player_hp"] = TEST_HEALTH
	run["player_max_hp"] = TEST_HEALTH
	scene._load_run_state(run)
	scene._close_dialogue()

static func unit(id: int, kind: String, at: Vector2i) -> Dictionary:
	return {"id": id, "type": kind, "pos": at, "hp": TEST_ENEMY_HEALTH, "max_hp": TEST_ENEMY_HEALTH, "block": 0}
