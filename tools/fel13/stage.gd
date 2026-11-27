extends RefCounted
## Start with production fights saved by their original setup. Change only the
## test board and player-turn state, then write through the checkpoint store.

const Store = preload("res://scripts/progression_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Pathing = preload("res://scripts/path_utils.gd")
const Game = preload("res://scripts/game_data.gd")
const NORMAL := "02-s0-seed12-0-1_3-t7"
const NORMAL_ALT := "04-s0-seed8-0--3_2-t5"
const DRAGON := "01-s0-seed1-0-4_0-t9"
const OBJECTIVE := "03-s2-seed8-2-11_-9-t64"
const CASES := {"P1": NORMAL, "P2": NORMAL, "P3": NORMAL, "P4": NORMAL_ALT,
	"P5": DRAGON, "P6": OBJECTIVE, "P7": DRAGON, "P8": NORMAL_ALT}
const TRAP_TILE := Vector2i(2, 2)
const CRATE_TILE := Vector2i(4, 4)
const RECLAIMABLE_EMBERS := 6

func run(session: SceneTree) -> void:
	var requested: String = OS.get_environment("FEL13_FIXTURE")
	var staged: int = 0
	for id: String in CASES:
		if not requested.is_empty() and id not in requested.split(","): continue
		if not await session.open_fixture(CASES[id]):
			session.quit(1)
			return
		var file := FileAccess.open(session.run_path, FileAccess.READ)
		var run_state: Dictionary = file.get_var(false)
		file.close()
		var state: Dictionary = run_state["combat_state"]
		var hover: Vector2i = _edit(id, state, session.board)
		if not _valid_board(state):
			session.fail(id + " has illegal board occupancy")
			return
		var destination: String = session.fixture_root.path_join(id)
		if DirAccess.make_dir_recursive_absolute(destination) != OK:
			session.fail("cannot create fixture " + id)
			return
		Store.flush_pending_run_saves()
		Store.set_run_storage_path(destination.path_join("run.save"))
		if not Store.save_run_state(run_state):
			session.fail("cannot save " + id)
			return
		if DirAccess.copy_absolute(session.fixture_root.path_join(CASES[id]).path_join("progression.json"), destination.path_join("progression.json")) != OK:
			session.fail("cannot stage profile for " + id)
			return
		var score := FileAccess.open(destination.path_join("score.json"), FileAccess.WRITE)
		score.store_string(JSON.stringify({"focus": {"tile": [hover.x, hover.y]}}) + "\n")
		score.close()
		await session.close_fixture()
		if not await session.open_fixture(id):
			session.quit(1)
			return
		if not _valid_board(session.scene.get("_combat_state")):
			session.fail(id + " changed to invalid occupancy after Continue")
			return
		print("FEL13 STAGED ", id, " from ", CASES[id], " hover=", hover)
		await session.close_fixture()
		staged += 1
	print("FEL13 STAGE PASS fixtures=", staged)
	session.quit()

func _edit(id: String, state: Dictionary, _board: Control) -> Vector2i:
	var grid: Array = state["grid"]
	var enemies: Array = state["enemies"]
	if id != "P7":
		state["traps"].clear()
		state["loot"].clear()
		state["surfaces"].clear()
	if id != "P6" and id != "P7":
		state["terrain"].clear()
		for row: Array in grid:
			for x: int in row.size():
				if row[x] == "pillar": row[x] = "stone"
	match id:
		"P1":
			_pillar(grid, Vector2i(3, 3))
			_trap(state, TRAP_TILE)
			state["player"]["pos"] = Vector2i(1, 4)
			return TRAP_TILE
		"P2":
			# The ground item paints behind the crate on this tile. The
			# authored crate is too short to hide this item one diagonal back.
			_crate(state, CRATE_TILE)
			state["loot"].append({"id": "fel13_loot", "pos": CRATE_TILE, "kind": "dropped_embers", "amount": RECLAIMABLE_EMBERS})
			state["player"]["pos"] = Vector2i(3, 5)
			return CRATE_TILE
		"P3":
			for x: int in range(2, 5):
				_pillar(grid, Vector2i(x + 1, 3))
				_surface(state, Vector2i(x, 2), "fire")
			state["player"]["pos"] = Vector2i(2, 2)
			enemies[0]["pos"] = Vector2i(6, 2)
			enemies[3]["pos"] = Vector2i(6, 3)
			return Vector2i(2, 2)
		"P4":
			state["player"]["pos"] = Vector2i(3, 3)
			enemies[0]["pos"] = Vector2i(5, 3)
			enemies[3]["pos"] = Vector2i(6, 6)
			_trap(state, TRAP_TILE)
			_loot(state, Vector2i(4, 2))
			_surface(state, Vector2i(5, 5), "ice")
			return TRAP_TILE
		"P5":
			state["player"]["pos"] = Vector2i(4, 1)
			enemies[0]["pos"] = Vector2i(4, 5)
			_set_intent(enemies[0], "worldspine_claw")
			enemies[1]["pos"] = Vector2i(3, 4)
			enemies[1]["hp"] = enemies[1]["max_hp"]
			enemies[1]["burrowed"] = false
			enemies[2]["pos"] = Vector2i(7, 3)
			_loot(state, Vector2i(4, 4))
			_trap(state, Vector2i(3, 3))
			_surface(state, Vector2i(3, 5), "electrified")
			return Vector2i(4, 4)
		"P6":
			# Preserve the open Snare objective, including the approach to its door.
			var exit: Vector2i = state["objective"]["exits"][0]["target_tile"]
			_crate(state, exit + Vector2i.ONE)
			_surface(state, exit, "rubble")
			return exit
		"P7":
			# Use the production fixed Faultline declaration from the checkpoint.
			state["player"]["pos"] = Vector2i(6, 6)
			state["terrain"] = state["terrain"].filter(func(row: Dictionary) -> bool: return row["pos"] not in [Vector2i(3, 4), Vector2i(4, 4), Vector2i(6, 6)])
			for tile: Vector2i in [Vector2i(3, 4), Vector2i(4, 4)]:
				_pillar(grid, tile)
				state["surfaces"].erase(Surface.tile_key(tile))
				for collection: String in ["traps", "loot"]:
					state[collection] = state[collection].filter(func(row: Dictionary) -> bool: return row["pos"] != tile)
			enemies[2]["pos"] = Vector2i(7, 3)
			return Vector2i(3, 3)
		"P8":
			_pillar(grid, Vector2i(2, 2))
			_crate(state, Vector2i(3, 2))
			_trap(state, Vector2i(1, 1))
			_loot(state, Vector2i(2, 1))
			_surface(state, Vector2i(1, 2), "fire")
			state["player"]["pos"] = Vector2i(1, 1)
			enemies[0]["pos"] = Vector2i(1, 3)
			_set_intent(enemies[0], "arc_jab")
			enemies[1]["pos"] = Vector2i(4, 2)
			enemies[3]["pos"] = Vector2i(6, 5)
			enemies[4]["pos"] = Vector2i(4, 1)
			_set_intent(enemies[4], "dust_advance")
			return Vector2i(1, 1)
	return TRAP_TILE

func _set_intent(enemy: Dictionary, intent_id: String) -> void:
	for intent: Dictionary in Game.enemy_property(str(enemy["type"]), "intents", []):
		if intent["id"] != intent_id: continue
		enemy["intent"] = intent.duplicate(true)
		return

func _pillar(grid: Array, tile: Vector2i) -> void:
	grid[tile.y][tile.x] = "pillar"

func _trap(state: Dictionary, tile: Vector2i) -> void:
	state["traps"].append({"id": "fel13_trap", "pos": tile, "element": "fire", "damage": 8, "base_damage": 8})

func _loot(state: Dictionary, tile: Vector2i) -> void:
	state["loot"].append({"id": "fel13_loot", "pos": tile, "kind": "item", "card_id": "nail_bomb"})

func _crate(state: Dictionary, tile: Vector2i) -> void:
	state["terrain"].append({"id": "fel13_crate", "kind": "wooden_crate", "pos": tile, "hp": 3, "max_hp": 3})

func _surface(state: Dictionary, tile: Vector2i, kind: String) -> void:
	state["surfaces"][Surface.tile_key(tile)] = {"rubble": true} if kind == "rubble" else {"elemental": kind}

func _valid_board(state: Dictionary) -> bool:
	var grid: Array = state["grid"]
	var occupied: Dictionary = {}
	var actors: Array = [state["player"]]
	for kind: String in ["enemies", "illusions", "summons"]: actors.append_array(state.get(kind, []))
	for actor: Dictionary in actors:
		if int(actor.get("hp", 0)) <= 0: continue
		for tile: Vector2i in Surface.footprint_tiles(actor):
			if not Pathing.is_passable(grid, tile) or occupied.has(tile):
				printerr("FEL13 illegal actor ", actor.get("type", "player"), " at ", tile)
				return false
			occupied[tile] = true
	for terrain: Dictionary in state["terrain"]:
		if not Surface.terrain_is_live(terrain): continue
		if occupied.has(terrain["pos"]) or not Pathing.is_passable(grid, terrain["pos"]):
			printerr("FEL13 illegal terrain ", terrain)
			return false
	for kind: String in ["traps", "loot"]:
		for subject: Dictionary in state[kind]:
			if not Pathing.is_passable(grid, subject["pos"]):
				printerr("FEL13 illegal ", kind, " at ", subject["pos"])
				return false
	for key: String in state["surfaces"]:
		if not Pathing.is_passable(grid, Surface.tile_from_key(key)):
			printerr("FEL13 illegal surface at ", key)
			return false
	return true
