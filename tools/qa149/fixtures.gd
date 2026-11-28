extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Map = preload("res://scripts/section_map_graph.gd")
const Chronicle = preload("res://scripts/chronicle_rules.gd")

const CARD_SEED := 144201
const DEMO_SEED := 144101
const HERO := Vector2i(4, 4)
const ENEMY := Vector2i(5, 4)
const ENEMY_HEALTH := 1
const HERO_HEALTH := 24
const BOARD_WIDTH := 9
const UMBRA_RADIUS := 99
const CARD := "whirlwind_slash"

# Adapted from qa144/fixture.gd. Only the position before the card input is set up.
static func install_card_fight(scene: Node) -> void:
	var run: Dictionary = scene._run_state.duplicate(true)
	var room: Dictionary = Map.room(run, run["current_room"])
	room["type"] = "combat"
	room["cleared"] = false
	var grid: Array = []
	for y: int in range(BOARD_WIDTH):
		var row: Array = []
		for x: int in range(BOARD_WIDTH):
			row.append("wall" if x in [0, BOARD_WIDTH - 1] or y in [0, BOARD_WIDTH - 1] else "stone")
		grid.append(row)
	var layout := {"grid": grid, "player_start": HERO, "terrain": [], "loot": [], "traps": [],
		"enemies": [{"id": 1, "type": "crawler", "pos": ENEMY, "hp": ENEMY_HEALTH, "max_hp": ENEMY_HEALTH, "block": 0}]}
	var hand: Array[String]
	hand.append(CARD)
	var combat: Dictionary = Combat.new().create_combat(CARD_SEED, layout,
		{"hp": HERO_HEALTH, "max_hp": HERO_HEALTH, "deck_cards": hand, "hand_size": hand.size(), "relics": []})
	combat["deck"]["hand"] = hand
	combat["deck"]["draw"] = []
	combat["deck"]["discard"] = []
	combat["umbra"]["radius"] = UMBRA_RADIUS
	run["mode"] = "combat"
	run["combat_state"] = combat
	run["current_room_layout"] = layout
	run["player_hp"] = HERO_HEALTH
	run["player_max_hp"] = HERO_HEALTH
	install(scene, run)

# Start with a genuine cutoff-dragon reward. Complete Ascent, the recap and
# Rise Again all run through the live scene (the whole combat is unnecessary).
static func install_demo_reward(scene: Node) -> void:
	var engine: RefCounted = scene._run_engine
	var run: Dictionary = scene._run_state.duplicate(true)
	var coord: Vector2i = Map.section(run, 0)["boss"]
	run["current_room"] = coord
	var room: Dictionary = Map.room(run, coord)
	room["visited"] = true
	room["revealed"] = true
	run["mode"] = "combat"
	Chronicle.enter_room(run, room)
	var layout: Dictionary = engine._combat_layout_for_room(room, Vector2i.RIGHT, run)
	run["current_room_layout"] = layout
	var combat: Dictionary = Combat.new().create_combat(DEMO_SEED, layout, engine._player_snapshot(run))
	for enemy: Dictionary in combat["enemies"]:
		enemy["hp"] = 0
	run["combat_state"] = combat
	install(scene, engine.finish_combat(run, combat))

static func install(scene: Node, run: Dictionary) -> void:
	scene._load_run_state(run)
	scene._close_dialogue()
	scene._save_run_progress()
