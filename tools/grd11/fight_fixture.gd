extends RefCounted
## Real RunScene setup. All placement and scheduling here is capture-only.

const Run = preload("res://scenes/run_scene.tscn")
const Combat = preload("res://scripts/combat_engine.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const Objective = preload("res://scripts/combat_objective_rules.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const SEED: int = 261122
const ROOM := Vector2i(4, 3)
const ROOM_SIZE := Vector2i(10, 9)
const HERO := Vector2i(3, 4)
const CRAWLER := Vector2i(6, 2)
const HARRIER := Vector2i(4, 5)
const CRAGHIDE := Vector2i(6, 5)
const FIRE_REGION := Rect2i(2, 5, 1, 3)
const ELECTRIC_REGION := Rect2i(5, 1, 3, 1)
const STORM_REGION := Rect2i(6, 4, 2, 1)
const ICE_REGION := Rect2i(3, 2, 2, 2)
const RUBBLE_REGION := Rect2i(4, 7, 2, 1)
const WALK_START := Vector2i(3, 4)
const WALK_FIRE := Vector2i(4, 4)
const WALK_END := Vector2i(5, 4)
const HAND: Array = ["brace", "quick_stab", "sidestep_slash", "bone_dart", "patch_up"]

static func configure(scene: Control, walk: bool) -> void:
	var layout: Dictionary = _layout(walk)
	var combat := Combat.new()
	var state: Dictionary = combat.create_combat(SEED, layout, {
		"hp": 24, "max_hp": 24, "deck_cards": HAND.duplicate(), "relics": [],
		"hand_size": HAND.size(), "heal_bonus": 0,
	})
	state["deck"]["hand"] = HAND.duplicate()
	state["deck"]["draw"] = []
	state["deck"]["discard"] = []
	state["deck"]["burned"] = []
	state["current_actor"] = {"kind": "player", "key": "player"}
	state["cards_played_this_turn"] = 0
	if walk:
		Ground.place(state, WALK_FIRE, "fire")
	else:
		for tile: Vector2i in [HERO, CRAWLER, CRAGHIDE]:
			Ground.place(state, tile, "fire")
		Ground.place(state, HARRIER, "electrified")
		_place(state, FIRE_REGION, "fire")
		_place(state, ELECTRIC_REGION, "electrified")
		_place(state, STORM_REGION, "fire")
		_place(state, ICE_REGION, "ice")
		_place(state, RUBBLE_REGION, "rubble")
	var progress: Dictionary = scene.get("_progression")
	for prompt: String in Tutorial.prompt_ids():
		progress = Tutorial.resolve_progression(progress, prompt)
	var run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = ROOM
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = state
	run_state["progression"] = progress
	scene.set("_progression", progress)
	_present(scene, run_state)

static func enable_stormcoal(scene: Control) -> void:
	var run_state: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run_state["combat_state"]["surface_rule_overrides"]["conductive_fire"] = true
	_present(scene, run_state)

static func player_tile(scene: Control) -> Vector2i:
	return scene.get("_combat_state")["player"]["pos"]

static func _present(scene: Control, run_state: Dictionary) -> void:
	scene.set("_run_state", run_state)
	scene.call("_sync_combat_state_from_run")
	scene.set("_animation_lock", false)
	scene.call("_refresh_ui")

static func _layout(walk: bool) -> Dictionary:
	var grid: Array = []
	for y: int in ROOM_SIZE.y:
		var row: Array = []
		for x: int in ROOM_SIZE.x:
			var border: bool = x == 0 or y == 0 or x == ROOM_SIZE.x - 1 or y == ROOM_SIZE.y - 1
			row.append("wall" if border else "stone")
		grid.append(row)
	var enemies: Array[Dictionary]
	enemies.append(_enemy(1, "crawler", CRAWLER))
	if not walk:
		enemies.append(_enemy(2, "harrier", HARRIER))
		enemies.append(_enemy(3, "craghide", CRAGHIDE))
	return {"name": "Combat", "coord": ROOM, "type": "combat", "grid": grid,
		"player_start": WALK_START if walk else HERO, "enemies": enemies,
		"traps": [], "terrain": [], "element": "none", "objective": {"type": Objective.KILL_ALL}}

static func _enemy(id: int, type: String, tile: Vector2i) -> Dictionary:
	var hp: int = int(GameData.enemies()[type]["max_hp"])
	return {"id": id, "type": type, "pos": tile, "hp": hp, "max_hp": hp}

static func _place(state: Dictionary, area: Rect2i, kind: String) -> void:
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			Ground.place(state, Vector2i(x, y), kind)
