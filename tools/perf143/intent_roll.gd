extends SceneTree
## Matched boss declarations on seeded boards. Receipt serialization is untimed.

const Combat = preload("res://scripts/combat_engine.gd")
const Boards = preload("res://tools/hitch_census/fixtures.gd")
const Dragons = preload("res://scripts/dragon_boss_library.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const ROLLS: int = 1000
const SEED: int = 143
const BOARDS_PER_BOSS: int = 4
const DEPTH: int = 4
const COVER_HP: int = 4
const TRAP_DAMAGE: int = 2
const FIRST_TERRAIN_ID: int = 100
const HELPER_HERO := Vector2i(4, 4)
const HELPER_START := Vector2i(0, -1)
const HELPER_OPEN_ANCHOR := Vector2i(1, 0)
const HELPER_ALLY := Vector2i(-2, -2)
const HELPER_HP: int = 9

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() != 1:
		push_error("Expected one argument, the output JSON path.")
		quit(1)
		return
	var file := FileAccess.open(args[0], FileAccess.WRITE)
	if file == null:
		push_error("Could not write " + args[0])
		quit(1)
		return
	var engine := Combat.new()
	var fixture := Boards.new()
	var boards: Dictionary = {}
	for dragon: String in Dragons.BOSS_ELEMENTS:
		for guardian: bool in [false, true]:
			var boss: String = str(Guardians.DEFINITIONS[dragon]["id"]) if guardian else dragon
			var depth: int = DEPTH if dragon != Dragons.SHADOW_BOSS_ID else Dragons.DEPTHS_PER_SEQUENCE * (Dragons.FINAL_BOSS_SEQUENCE_INDEX + 1)
			var variants: Array[Dictionary]
			for variant: int in range(BOARDS_PER_BOSS):
				var board_seed: int = SEED + variant
				seed(board_seed)
				var run: Dictionary = fixture.make("guardian", board_seed, {"guardian_id": boss, "guardian_case": "encounter"}) if guardian else fixture.make("dragon", board_seed, {"dragon_id": boss, "dragon_depth": depth, "dragon_case": "encounter", "dragon_build": "balanced"})
				if run.is_empty():
					fixture.free()
					push_error("%s: %s" % [boss, fixture.census_error])
					quit(1)
					return
				var state: Dictionary = run["combat_state"]
				var index: int = _boss_index(state, boss)
				if index < 0:
					fixture.free()
					push_error("Missing boss " + boss)
					quit(1)
					return
				variants.append({"state": state, "index": index})
			boards[boss] = variants
	fixture.free()
	var rng := RandomNumberGenerator.new()
	var variations := RandomNumberGenerator.new()
	var records: Array[Dictionary]
	var times: Dictionary = {}
	var boss_ids: Array = boards.keys()
	var cycles: Dictionary = {}
	var helper_cases: int = 0
	for roll: int in range(ROLLS):
		var boss: String = boss_ids[roll % boss_ids.size()]
		var iteration: int = roll / boss_ids.size()
		var entry: Dictionary = boards[boss][(iteration + iteration / BOARDS_PER_BOSS) % BOARDS_PER_BOSS]
		var state: Dictionary = (entry["state"] as Dictionary).duplicate(true)
		var index: int = entry["index"]
		var boss_actor: Dictionary = state["enemies"][index]
		rng.seed = SEED + roll
		variations.seed = SEED + roll
		state["rng_state"] = rng.state
		var cycle_key: String = "dragon_cycle" if Dragons.is_dragon_boss_id(boss) else "guardian_cycle"
		var positions: Array[Vector2i] = engine._all_passable_tiles(state)
		var occupied: Dictionary = engine._occupied_actor_tiles(state)
		for trap: Dictionary in state.get("traps", []): occupied[trap["pos"]] = true
		if iteration != 0:
			# Vary route/LOS while preserving legal hero placement. On alternating
			# boards, ordinary cover and living dragon stone exercise both LOS modes.
			var offset: int = variations.randi_range(0, positions.size() - 1)
			for step: int in range(positions.size()):
				var tile: Vector2i = positions[(offset + step) % positions.size()]
				if occupied.has(tile): continue
				state["player"]["pos"] = tile
				occupied[tile] = true
				break
			if (iteration / BOARDS_PER_BOSS) % 2 == 0:
				_stage_geometry(state, boss_actor, positions, occupied, variations)
		boss_actor[cycle_key] = iteration - 1
		if cycle_key == "dragon_cycle":
			boss_actor["dragon_cycle_order"] = engine.GameData.enemy_def(boss).get("cycle_order", [])
		var started: int = Time.get_ticks_usec()
		engine._assign_enemy_intent(state, index, rng)
		var usec: int = Time.get_ticks_usec() - started
		var intent: Dictionary = state["enemies"][index]["intent"]
		var id: String = str(intent.get("id", ""))
		if id.is_empty():
			push_error("Empty intent for %s at roll %d" % [boss, roll])
			quit(1)
			return
		var declared: Array = []
		for action: Dictionary in intent.get("actions", []):
			declared.append([action.get("declared_tiles", []), Areas.shown(action)])
		declared.append(Areas.announced_tiles(state["enemies"][index]))
		var name: String = boss + "/" + id
		if not times.has(name): times[name] = []
		times[name].append(usec)
		cycles[name] = int(cycles.get(name, 0)) + 1
		var receipt: Dictionary = {"boss": boss, "id": id, "intent": _digest(intent), "rng": _digest(rng.state), "areas": _digest(declared)}
		if cycle_key == "guardian_cycle":
			var rotation: int = variations.randi_range(0, 3)
			var reserve_both: bool = variations.randi_range(0, 1) == 1
			var helper: Dictionary = guardian_helper_case(engine, rotation, reserve_both)
			if not bool(helper["tied_hazards"]) or not bool(helper["expected_route"]):
				push_error("Guardian helper fixture did not keep release's route at roll %d: %s" % [roll, helper])
				quit(1)
				return
			receipt["guardian_helper"] = _digest(helper)
			helper_cases += 1
		records.append(receipt)
	var profile: Dictionary = engine.call("boss_intent_profile_snapshot") if engine.has_method("boss_intent_profile_snapshot") else {}
	file.store_string(JSON.stringify({"rolls": records, "sha256": _digest(records), "timings_usec": times, "profile": profile, "cycles": cycles, "guardian_helper_cases": helper_cases}, "\t") + "\n")
	print("PERF-143 SWEEP: %d rolls, %d bosses, %d intent variants, SHA-256 %s" % [records.size(), boards.size(), cycles.size(), _digest(records)])
	print("PERF-143 GUARDIAN HELPERS: %d equal-hazard reservation fixtures" % helper_cases)
	quit()

func _boss_index(state: Dictionary, boss: String) -> int:
	for index: int in range((state["enemies"] as Array).size()):
		if state["enemies"][index]["type"] == boss: return index
	return -1

func _stage_geometry(state: Dictionary, boss: Dictionary, positions: Array[Vector2i], occupied: Dictionary, rng: RandomNumberGenerator) -> void:
	var offset: int = rng.randi_range(0, positions.size() - 1)
	var placed: int = 0
	for step: int in range(positions.size()):
		var tile: Vector2i = positions[(offset + step) % positions.size()]
		if occupied.has(tile): continue
		match placed:
			0, 1:
				var stone: bool = placed == 1 and boss["type"] == "tharokh"
				state["terrain"].append({"pos": tile, "kind": "crag_outcrop" if stone else "raised_cover",
					"owner_kind": "enemy", "owner_id": boss["id"], "id": FIRST_TERRAIN_ID + placed, "hp": COVER_HP})
			2: Surfaces.place(state, tile, "fire")
			3: Surfaces.place(state, tile, "rubble")
			4: state["traps"].append({"pos": tile, "damage": TRAP_DAMAGE})
		placed += 1
		if placed == 5: break

# Both safe Dive routes reach the player. Reserving the shorter route gives
# the longer route priority. Reserving both restores the ordinary cost tie-break.
static func guardian_helper_case(engine: Combat, rotation: int, reserve_both: bool) -> Dictionary:
	var start: Vector2i = HELPER_HERO + _rotated(HELPER_START, rotation)
	var open_anchor: Vector2i = HELPER_HERO + _rotated(HELPER_OPEN_ANCHOR, rotation)
	var reserved: Array[Vector2i]
	reserved.append(start)
	if reserve_both: reserved.append(open_anchor)
	var grid: Array = Fixtures._simple_grid()
	for offset: Vector2i in [Vector2i.LEFT, Vector2i.DOWN]:
		var wall: Vector2i = HELPER_HERO + _rotated(offset, rotation)
		grid[wall.y][wall.x] = "wall"
	var helper: Dictionary = {"type": "gust_shrike", "pos": start, "id": 1, "hp": HELPER_HP, "guardian_helper": true}
	var ally: Dictionary = {"type": "gallows_roc", "pos": HELPER_HERO + _rotated(HELPER_ALLY, rotation), "id": 2, "hp": HELPER_HP,
		"intent": {"committed_plan": {"path": reserved}}}
	var state: Dictionary = {"grid": grid, "player": {"pos": HELPER_HERO, "hp": HELPER_HP}, "enemies": [helper, ally], "guardian_id": "gallows_roc"}
	var intent: Dictionary = engine._intent_by_id(engine.GameData.enemy_def("gust_shrike")["intents"], "dive")
	var attack: Dictionary = intent["actions"][1]
	var allowance: int = int(intent["actions"][0]["range"])
	var records: Array[Dictionary] = engine._enemy_actual_path_records(state, helper, allowance)
	var arrivals: Dictionary = {}
	var target: Dictionary = engine._actor_targets(state)[0]
	for record: Dictionary in records:
		var tile: Vector2i = record["tile"]
		if tile != start and tile != open_anchor: continue
		var aimed: Dictionary = helper.duplicate()
		aimed["pos"] = tile
		if engine._enemy_action_reaches_target(state, aimed, attack, target):
			var arrival: Dictionary = engine._enemy_attack_route_prediction(state, helper, record, allowance)
			if bool(arrival["survives"]) and arrival["destination"] == tile:
				arrivals[tile] = arrival["hazard_cost"]
	var chosen: Dictionary = engine._best_enemy_direct_attack_candidate(state, helper, attack, records, "move_toward", allowance)
	var expected: Vector2i = start if reserve_both else open_anchor
	return {"rotation": rotation, "reserved": reserved, "tied_hazards": arrivals.size() == 2 and arrivals[start] == arrivals[open_anchor],
		"expected_route": chosen.get("destination") == expected, "expected": expected, "chosen": chosen}

static func _rotated(offset: Vector2i, rotation: int) -> Vector2i:
	for turn: int in range(rotation):
		offset = Vector2i(-offset.y, offset.x)
	return offset

func _digest(value: Variant) -> String:
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes(value))
	return context.finish().hex_encode()
