extends RefCounted
## Small combat setup adapted from qa-144's fixture.gd. The run graph,
## persistence, card resolution, reward creation and Continue are production.
const Combat = preload("res://scripts/combat_engine.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Map = preload("res://scripts/section_map_graph.gd")

const HERO := Vector2i(4, 4)
const ENEMY := Vector2i(5, 4)
const BURST_TARGET := Vector2i(6, 4)
const ENEMY_HEALTH := 1
const HERO_HEALTH := 24
const METEOR_DAMAGE := 50
const LATE_ENEMY_TIME := 100
const BOARD_WIDTH := 9
const CARD := "whirlwind_slash"
const DRAGON := "tharokh"
const GUARDIAN := "craghide"

static func install(scene: Node, seed: int, kind: String) -> Dictionary:
	var run: Dictionary = scene._run_state.duplicate(true)
	var coord: Vector2i = run.get("current_room", Vector2i.ZERO)
	var room: Dictionary = Map.room(run, coord)
	room["type"] = "combat"
	room["cleared"] = false
	var grid: Array = []
	for y: int in range(BOARD_WIDTH):
		var row: Array = []
		for x: int in range(BOARD_WIDTH):
			row.append("wall" if x in [0, BOARD_WIDTH - 1] or y in [0, BOARD_WIDTH - 1] else "stone")
		grid.append(row)
	var enemy: String = "ember_tick" if kind == "burst" else "crawler"
	if kind == "guardian":
		room.merge({"type": "guardian", "boss_id": DRAGON, "guardian_id": GUARDIAN}, true)
		enemy = GUARDIAN
	elif kind in ["dragon", "final_dragon"]:
		room.merge({"type": "boss", "boss_id": DRAGON}, true)
		if kind == "final_dragon": room["section_index"] = DemoRules.last_section_index()
		enemy = DRAGON
	var layout := {"grid": grid, "player_start": HERO, "terrain": [], "loot": [], "traps": [],
		"enemies": [{"id": 1, "type": enemy, "pos": ENEMY, "hp": ENEMY_HEALTH, "max_hp": ENEMY_HEALTH, "block": 0}]}
	if kind == "burst":
		layout["enemies"].append({"id": 2, "type": "crawler", "pos": BURST_TARGET,
			"hp": ENEMY_HEALTH, "max_hp": ENEMY_HEALTH, "block": 0})
	var hand: Array[String]
	hand.append(CARD)
	var combat: Dictionary = Combat.new().create_combat(seed, layout,
		{"hp": HERO_HEALTH, "max_hp": HERO_HEALTH, "deck_cards": hand, "hand_size": hand.size(), "relics": []})
	combat["deck"]["hand"] = hand
	combat["deck"]["draw"] = []
	combat["deck"]["discard"] = []
	combat["umbra"]["radius"] = 99
	if kind in ["fire", "burst"]:
		Surfaces.place(combat, ENEMY, "fire", {"actor_kind": "player"})
	if kind in ["burst", "turn_start"]:
		for entry: Dictionary in combat["turn_queue"]:
			if entry.get("kind") == "enemy" and (kind == "turn_start" or entry.get("enemy_id") == 2):
				entry["time"] = int(combat.get("initiative_clock", 0)) + LATE_ENEMY_TIME
	if kind == "turn_start":
		combat["meteor_marks"] = [{"tiles": [ENEMY], "damage": METEOR_DAMAGE, "element": "fire", "surface": "fire", "card_id": "meteorfall"}]
	run["mode"] = "combat"
	run["combat_state"] = combat
	run["current_room_layout"] = layout
	run["player_hp"] = HERO_HEALTH
	run["player_max_hp"] = HERO_HEALTH
	scene._load_run_state(run)
	scene._close_dialogue()
	scene._save_run_progress()
	return run
