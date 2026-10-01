extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const BossSuite = preload("res://tests/suites/dragon_boss_suite.gd")
const Shapes = preload("res://scripts/committed_pattern_shapes.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")

var failed: int = 0

func _initialize() -> void:
	_test_kindle_holds_ground()
	_test_kindle_pressure_and_counterplay()
	_test_edge_shapes()
	_test_cinder_breath_corner_pressure()
	_test_held_approach_and_damage()
	_test_footprint_trap_prediction()
	_test_worldspine_choices()
	_test_worldspine_pressure_order()
	_test_worldspine_approach_flank()
	var opening: Dictionary = BossSuite._boss_combat_state("tharokh", 4)
	expect(int(opening["turn_queue"][0]["time"]) == 12, "Stonewake must resolve after the first ordinary two-card turn")
	_test_air_evade_and_displacement()
	_test_ice_ground_budget()
	_test_storm_marks_conduction_and_cap()
	_test_summoned_wisp_activation()
	_test_eclipse_refuges()
	_test_saved_eclipse_warning()
	_test_saved_night_coil_warning()
	BossSuite.run(expect)
	if failed == 0: print("Dragon committed patterns passed.")
	quit(1 if failed else 0)

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)

func _test_kindle_holds_ground() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("vyraketh")
	_declare(state, 0)
	var declared: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].duplicate()
	state["player"]["pos"] = Vector2i(7, 7)
	expect(_same_tiles(state["enemies"][0]["intent"]["actions"][0]["declared_tiles"], declared), "Meteorfall marks must not retarget when the player moves; the separate shot remains live")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state, "fire"), declared), "Meteorfall must ignite its displayed cells")
	expect(state["enemies"][0]["intent"]["id"] == "cinderfall", "Breath must challenge routes while Meteorfall Fire remains")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state, "fire"), declared), "The breath must retain the previous Fire as secondary pressure")
	for tile: Vector2i in declared: Surface.place(state, tile, "ice")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"] == "cinder_maw", "Denied Crownfire must advance to pursuit, not restart setup")
	for tile: Vector2i in declared: expect(Surface.has_surface(state, tile, "ice"), "Crownfire must preserve replacement Ice")

func _test_kindle_pressure_and_counterplay() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("vyraketh")
	_declare(state, 0)
	var marked: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	expect(marked.size() == 7 and marked.has(state["player"]["pos"]), "Meteorfall must mark seven cells, including the player's declared position")
	expect(marked.has(Vector2i(1,3)) and marked.has(Vector2i(1,5)), "Meteorfall must connect its marks across the declared approach")
	var hp: int = state["player"]["hp"]
	state = BossSuite._resolve_boss_turn(state)
	expect(int(state["player"]["hp"]) == hp - 8, "Remaining on a declared Meteorfall cell in shot range must take both advertised hits")
	# Isolate the known approach Fire to prove the shared self-damage tradeoff.
	for tile: Vector2i in Surface.tiles(state, "fire"): Surface.remove(state,tile,"fire","test_counterplay")
	for tile: Vector2i in [Vector2i(3,3),Vector2i(3,4)]: Surface.place(state,tile,"fire")
	state["enemies"][0]["cinder_tiles"] = [Vector2i(3,3),Vector2i(3,4)]
	_declare(state, 2)
	var boss_hp: int = state["enemies"][0]["hp"]
	var unpushed: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
	expect(int(unpushed["enemies"][0]["hp"]) == boss_hp - 8, "Holding the dragon beside its Fire must reward Crownfire self-damage")
	state["enemies"][0]["pos"] += Vector2i.RIGHT
	var pushed: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(int(pushed["enemies"][0]["hp"]) == boss_hp, "Pushing away from preserved approach Fire must buy space at the cost of self-damage")

func _test_edge_shapes() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("vyraketh")
	state["terrain"] = []
	var action := {"committed_shape":"crescent", "pattern_footprint":[2,2], "range":2}
	var affected: Array[Vector2i] = Shapes.footprint_shape(combat, state, Vector2i(4,3), Vector2i.LEFT, action)
	var expected: Array[Vector2i] = []
	for x: int in [2,3]:
		for y: int in [2,3,4,5]: expected.append(Vector2i(x,y))
	for x: int in [4,5]:
		for y: int in [2,5]: expected.append(Vector2i(x,y))
	expect(_same_tiles(affected, expected), "Maw must cover both front rows and side edges symmetrically")
	expect(not affected.has(Vector2i(6,3)) and not affected.has(Vector2i(6,4)), "Maw must leave a rear melee reward for reaching the far side")
	action["committed_shape"] = "fan"
	action["range"] = 3
	affected = Shapes.footprint_shape(combat, state, Vector2i(5,3), Vector2i.LEFT, action)
	expect(affected.size() == 12, "An unmodified or saved fan must retain its bounded 2/4/6 shape")
	expect(not affected.has(Vector2i(5,2)) and not affected.has(Vector2i(5,5)), "Cinderfall must leave close lateral flanks open")
	action["pattern_min_flank"] = 1
	affected = Shapes.footprint_shape(combat, state, Vector2i(5,3), Vector2i.LEFT, action)
	expect(affected.size() == 14 and affected.has(Vector2i(4,2)) and affected.has(Vector2i(4,5)), "Cinder Breath must cover both first-row shoulders in its bounded 4/4/6 fan")
	expect(not affected.has(Vector2i(5,2)) and not affected.has(Vector2i(5,5)), "Broader breath shoulders must preserve the close lateral escape route")

func _test_cinder_breath_corner_pressure() -> void:
	var combat := Combat.new()
	for corner: Vector2i in [Vector2i(2,2),Vector2i(5,2),Vector2i(2,5),Vector2i(5,5)]:
		var state: Dictionary = _empty_arena("vyraketh")
		state["enemies"][0]["pos"] = Vector2i(3,3)
		state["player"]["pos"] = corner
		_declare(state, 1)
		var plan: Dictionary = combat.enemy_intent_plan(state, 0)
		expect(plan["projected_attack"].has(corner), "Cinder Breath must threaten the stationary player at each close diagonal corner: %s" % corner)
		var hp: int = state["player"]["hp"]
		var hit: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
		expect(int(hit["player"]["hp"]) == hp - 8, "Remaining on a declared breath shoulder must take the displayed eight damage")
		state["player"]["pos"] = Vector2i(7,7)
		expect(_same_tiles(combat.enemy_intent_plan(state,0)["projected_attack"],plan["projected_attack"]), "The broadened breath must retain its declared direction when the player escapes")
		var escaped: Dictionary = BossSuite._resolve_boss_turn(state)
		expect(int(escaped["player"]["hp"]) == hp, "Leaving the declared breath must still avoid its damage")

func _test_held_approach_and_damage() -> void:
	var combat = Combat.new()
	var state: Dictionary = BossSuite._boss_combat_state("tharokh")
	state["terrain"] = []
	state["traps"] = []
	state["player"]["pos"] = Vector2i(1,4)
	state["enemies"][0]["dragon_cycle"] = 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 31
	combat._assign_enemy_intent(state, 0, rng)
	var plan: Dictionary = combat.enemy_intent_plan(state, 0)
	expect(not (plan["projected_attack"] as Array).is_empty(), "Worldspine Claw must present an actionable attack pattern")
	var safe: Dictionary = state.duplicate(true)
	safe["player"]["pos"] = Vector2i(7,6)
	var changed: Dictionary = combat.enemy_intent_plan(safe, 0)
	expect(_same_tiles(changed["projected_attack"], plan["projected_attack"]), "Moving away must not rotate the declared attack")
	expect(changed["path"] == plan["path"], "The declared approach must not chase the player's new position")
	var hp: int = safe["player"]["hp"]
	safe = BossSuite._resolve_boss_turn(safe)
	expect(int(safe["player"]["hp"]) == hp, "Escaping the declared Worldspine Claw must avoid its damage")
	var hit: Dictionary = BossSuite._boss_combat_state("tharokh")
	hit["terrain"] = []
	hit["traps"] = []
	hit["player"]["pos"] = Vector2i(3,3)
	hit["enemies"][0]["pos"] = Vector2i(4,3)
	hit["enemies"][0]["dragon_cycle"] = 0
	combat._assign_enemy_intent(hit,0,rng)
	expect((combat.enemy_intent_plan(hit,0)["projected_attack"] as Array).has(hit["player"]["pos"]), "A player who stays in front must be shown in Worldspine Claw's damage cells")
	var before: int = hit["player"]["hp"]
	hit = BossSuite._resolve_boss_turn(hit)
	expect(int(hit["player"]["hp"]) == before - 12, "Standing in the displayed Worldspine Claw must take its advertised 12 damage")
	var frozen: Dictionary = combat.enemy_intent_plan(state, 0, {}, true, true)
	expect((frozen["projected_attack"] as Array).is_empty(), "Disabling the dragon must remove its damage preview")

func _same_tiles(a: Array, b: Array) -> bool:
	if a.size() != b.size(): return false
	for tile: Variant in a:
		if not b.has(tile): return false
	return true

func _empty_arena(boss_id: String) -> Dictionary:
	var state: Dictionary = BossSuite._boss_combat_state(boss_id)
	state["terrain"] = []
	state["traps"] = []
	state["surfaces"] = {}
	state["player"]["pos"] = Vector2i(1,4)
	state["enemies"][0]["pos"] = Vector2i(4,3)
	return state

func _declare(state: Dictionary, cycle: int) -> void:
	state["enemies"][0]["dragon_cycle"] = cycle - 1
	var rng := RandomNumberGenerator.new()
	rng.seed = 93
	Combat.new()._assign_enemy_intent(state,0,rng)

func _test_worldspine_choices() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("tharokh")
	_declare(state,0)
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	expect(marks.size()==4, "Stonewake must mark four destructible obstacles in an open arena")
	var denied: Dictionary = state.duplicate(true)
	denied["player"]["pos"] = marks[0]
	denied = BossSuite._resolve_boss_turn(denied)
	expect(combat._terrain_index_at_tile(denied,marks[0])<0, "Occupying a Stonewake mark must deny its spire, never trap the player inside terrain")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).size()==4, "Stonewake must resolve its shown obstacle count")
	var blockers: Dictionary = combat._enemy_path_blockers(state,state["enemies"][0],true,false)
	var exits: int = 0
	for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
		if combat._enemy_can_occupy_anchor(state,state["enemies"][0],state["enemies"][0]["pos"]+direction,blockers): exits += 1
	expect(exits>=2,"Worldspines must leave two exits for the dragon's whole footprint")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).size()==4,"Repeated Stonewake must not exceed its live cap")
	_declare(state,3)
	var intact: Array = combat._terrain_burst_tiles(state,2)
	var spire: Dictionary = {}
	var smallest: int = intact.size()
	for candidate: Dictionary in combat._dragon_spires(state):
		var trial: Dictionary = state.duplicate(true)
		trial = combat._damage_terrain_indices(trial,[combat._terrain_index_at_tile(trial,candidate["pos"])],100)
		var size: int = combat._terrain_burst_tiles(trial,2).size()
		if size < smallest:
			smallest = size
			spire = candidate
	expect(not spire.is_empty(),"At least one deliberately selected Worldspine must open unique Faultline space")
	if spire.is_empty(): return
	state = combat._damage_terrain_indices(state,[combat._terrain_index_at_tile(state,spire["pos"])],100)
	var broken: Array = combat._terrain_burst_tiles(state,2)
	expect(broken.size()<intact.size(),"Breaking a Worldspine must immediately remove its unique Faultline cells")
	expect(Surface.has_surface(state,spire["pos"],"rubble"),"Destroyed Worldspines leave shared Rubble")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).is_empty(),"Faultline must break the surviving spires after resolving")

func _test_worldspine_pressure_order() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("tharokh")
	_declare(state,0)
	state["player"]["pos"] = Vector2i(7,7)
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"]=="worldspine_claw","Stonewake must lead into Claw while its spires remain")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"]=="bedrock_breath","Claw must lead into Bedrock before consuming the Worldspines")
	var spires_before: int = combat._dragon_spires(state).size()
	expect(spires_before>0,"Living Worldspines must constrain the Bedrock warning")
	var lane: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(not lane.is_empty(),"Bedrock must retain a visible lane alongside its spires")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"]=="faultline","Bedrock must lead directly into the rupture warning")
	expect(not combat._dragon_spires(state).is_empty(),"Bedrock must leave living Worldspines for Faultline counterplay")
	var rubble: Array = Surface.tiles(state,"rubble")
	expect(not rubble.is_empty(),"Bedrock Rubble must persist during the Faultline warning")
	var lane_rubble: bool = false
	for tile: Vector2i in lane:
		if rubble.has(tile): lane_rubble = true
	expect(lane_rubble,"Rubble in the announced lane must create movement friction before Faultline")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).is_empty() and state["enemies"][0]["intent"]["id"]=="stonewake","Faultline must consume the remaining spires and advance the full cycle")

func _tharokh_native_approach_layout(close: bool = false) -> Dictionary:
	var state: Dictionary = _empty_arena("tharokh")
	# Geometry from the depth-8 native cohort; no acquired damage or clock is
	# simulated here. The close state follows the first Claw clearing two crates.
	var terrain_tiles: Array[Vector2i]
	terrain_tiles.append_array([Vector2i(2,2), Vector2i(2,1)])
	if not close: terrain_tiles.append_array([Vector2i(5,5), Vector2i(4,5)])
	for tile: Vector2i in terrain_tiles:
		state["terrain"].append({"id":"native_crate_%d_%d" % [tile.x,tile.y],"kind":"wooden_crate","pos":tile,"hp":3,"max_hp":3})
	for tile: Vector2i in [Vector2i(5,1), Vector2i(6,4)]:
		state["traps"].append({"id":"native_trap_%d_%d" % [tile.x,tile.y],"pos":tile,"element":"earth","damage":6,"base_damage":6})
	if close:
		state["player"]["pos"] = Vector2i(2,3)
	else:
		state["traps"].append({"id":"native_trap_3_2","pos":Vector2i(3,2),"element":"earth","damage":6,"base_damage":6})
	return state

func _test_worldspine_approach_flank() -> void:
	var combat := Combat.new()
	var state: Dictionary = _tharokh_native_approach_layout()
	_declare(state,0)
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].duplicate()
	expect(marks.size()==4 and marks.has(Vector2i(2,3)),"The distant approach must reserve its legal flank in a full four-spire field")
	var pair_found: bool = false
	for index: int in range(marks.size()):
		for other: int in range(index+1,marks.size()):
			if preload("res://scripts/path_utils.gd").manhattan(marks[index],marks[other])==2: pair_found=true
	expect(pair_found,"Paired spires must overlap radius-one pressure instead of maximizing every separation")
	state = BossSuite._resolve_boss_turn(state)
	expect(combat._dragon_spires(state).size()==4,"Stonewake's own attack must preserve its declared four-spire field")
	state["player"]["pos"] = Vector2i(3,4)
	var boss_hp: int = int(state["enemies"][0]["hp"])
	# An inline self-centered ring strike: the live Cleaver Sweep became a
	# facing-aimed arc in the card pool overhaul and no longer targets the hero's tile.
	var sweep: Dictionary = {"type":"aoe","damage":6,"range":0,"pattern":[[0,-1],[1,0],[0,1],[-1,0]],"rotate":false,"element":"none"}
	state = combat.apply_player_action(state,sweep,state["player"]["pos"])
	expect(int(state["enemies"][0]["hp"])<boss_hp and not combat._dragon_spires(state).is_empty(),"One stationary boss Sweep must not incidentally clear the entire field")
	# Inspect actual field geometry apart from the independent live shot. A
	# selective break must remove its own fuel even if another pair overlaps it.
	var before: Array[Vector2i] = combat._terrain_burst_tiles(state,1)
	for spire: Dictionary in combat._dragon_spires(state).duplicate():
		var tile: Vector2i = spire["pos"]
		state = combat._damage_terrain_indices(state,[combat._terrain_index_at_tile(state,tile)],4)
	expect(combat._terrain_burst_tiles(state,1).is_empty() and not before.is_empty(),"Breaking the field must remove all pulse pressure while leaving the boss's independent attacks")
	var blocked: Dictionary = _tharokh_native_approach_layout()
	for tile: Vector2i in [Vector2i(2,3),Vector2i(2,5)]:
		blocked["terrain"].append({"id":"blocked_flank_%d_%d" % [tile.x,tile.y],"kind":"wooden_crate","pos":tile,"hp":3,"max_hp":3})
	_declare(blocked,0)
	var fallback: Array = blocked["enemies"][0]["intent"]["actions"][0]["declared_tiles"]
	expect(not fallback.is_empty() and not fallback.has(Vector2i(2,3)) and not fallback.has(Vector2i(2,5)),"Blocked approach flanks must fall back to legal paired floor")

func _test_air_evade_and_displacement() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("vaeloryx")
	_declare(state,0)
	var hook: Dictionary = combat.enemy_intent_plan(state,0)
	expect(hook["projected_attack"].has(state["player"]["pos"]),"Opening Skyhook must reach the player's current tile after its approach")
	var hp: int = state["player"]["hp"]
	var hooked: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
	expect(hooked["player"]["hp"]==hp-4,"Skyhook's live shot must apply its advertised hit")
	state["player"]["pos"] = Vector2i(3,4)
	_declare(state,2)
	var threatened: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(threatened.has(Vector2i(3,4)) and threatened.has(Vector2i(6,4)),"Gale must threaten the whole close perimeter, including the rear")
	var stayed: Dictionary = BossSuite._resolve_boss_turn(state.duplicate(true))
	expect(stayed["player"]["hp"]==hp-6 and stayed["player"]["pos"]==Vector2i(1,4),"Staying in Gale must take six damage and two tiles of displacement")
	state["player"]["pos"] = Vector2i(1,4)
	expect(not combat.enemy_threat_tiles(state,0)["attack"].has(Vector2i(1,4)),"Moving beyond the close perimeter must escape Gale")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==hp,"Escaping Gale must avoid its damage")
	state = _empty_arena("vaeloryx")
	state["player"]["pos"] = Vector2i(3,4)
	_declare(state,3)
	var eye: Dictionary = combat.enemy_intent_plan(state,0)
	var landed: Dictionary = state["enemies"][0].duplicate(true)
	landed["pos"] = eye["destination"]
	expect(eye["projected_attack"].has(state["player"]["pos"]),"Eye's retreat must leave a meaningful storm threat at the declared player position")
	for tile: Vector2i in eye["projected_attack"]:
		var distance: int = combat._enemy_distance_to_tile(landed,tile)
		expect(distance>=1 and distance<=5,"Eye warning must include the outer 2–5 ring and its separate weaker close strike")
	var eye_hp: int = state["player"]["hp"]
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==eye_hp-8,"Remaining in the announced storm ring must take eight damage")
	_test_swept_dive()

func _test_swept_dive() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("vaeloryx")
	_declare(state,1)
	var intent: Dictionary = state["enemies"][0]["intent"]
	intent["committed_plan"]["path"] = [Vector2i(4,3),Vector2i(3,3),Vector2i(2,3)]
	intent["committed_plan"]["destination"] = Vector2i(2,3)
	var preview: Dictionary = combat.enemy_intent_plan(state,0)
	expect(preview["projected_attack"].has(Vector2i(4,5)) and preview["projected_attack"].has(Vector2i(1,4)),"Dive must sweep the traveled perimeter and landing, not reuse a front crescent")
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(state,0)
	var attack_steps: Array = result["steps"].filter(func(step: Dictionary)->bool: return str(step.get("intent_id",""))=="razor_dive" and str(step.get("action_type",""))=="aoe")
	expect(attack_steps.size()==1 and _same_tiles(attack_steps[0]["tiles"],preview["projected_attack"]),"Dive's rendered impact cells must exactly match its predicted traveled route")
	expect(result["state"]["player"]["hp"]==state["player"]["hp"]-8,"Dive may hit a player only once across overlapping route cells")
	state["terrain"] = [{"id":"dive_blocker","pos":Vector2i(3,3),"hp":99,"max_hp":99}]
	preview = combat.enemy_intent_plan(state,0)
	expect(preview["destination"]==Vector2i(4,3) and not preview["projected_attack"].has(Vector2i(1,4)),"Blocking Dive's path must remove damage around its unreachable landing")
	result = combat.resolve_enemy_turn_with_steps(state,0)
	expect(result["state"]["player"]["hp"]==state["player"]["hp"],"A blocked Dive must not damage a player beyond its actual route")

func _test_ice_ground_budget() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("iskaldra")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	var hp: int = state["enemies"][0]["hp"]
	state = combat._damage_enemy(state,0,2,true)
	expect(state["enemies"][0]["hp"]==hp and state["enemies"][0]["frost_armor"]==1,"A low-damage hit must peel one Mantle layer without spending boss HP")
	state = combat._damage_enemy(state,0,2,true)
	state = combat._damage_enemy(state,0,9,true)
	expect(state["enemies"][0]["hp"]==hp-9,"A follow-up heavy hit must land after armor is peeled")
	_declare(state,2)
	var affected: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(affected.size()>2,"Lance should threaten a full multi-tile lane")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state,"ice"), affected),"Whiteout Lance must coat its entire declared damage lane")
	var preserved: Vector2i = affected[0]
	Surface.place(state,preserved,"fire")
	Surface.place(state,preserved,"ice",{"actor_kind":"player","actor_id":-1})
	state["player"]["pos"] = Vector2i(7,4)
	_declare(state,2)
	var next_lane: Array = combat.enemy_threat_tiles(state,0)["attack"]
	state = BossSuite._resolve_boss_turn(state)
	expect(Surface.has_surface(state,preserved,"ice"),"Replacing the old lane with player-owned Ice must preserve that new surface")
	for tile: Vector2i in affected:
		if tile != preserved and not next_lane.has(tile): expect(not Surface.has_surface(state,tile,"ice"),"A new Whiteout must retire the previous owned Ice lane")
	expect(Surface.tiles(state,"ice").size()<=next_lane.size()+1,"Repeated Whiteout must keep one authored trail rather than fill the arena permanently")
	state["player"]["pos"] = Vector2i(1,4)
	Surface.place(state,state["enemies"][0]["pos"],"ice")
	_declare(state,0)
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["frost_armor"]==3,"Ice fuel under Iskaldra must add one layer up to the cap of three")
	_declare(state,1)
	var intact: Array = combat.enemy_threat_tiles(state,0)["attack"]
	state = combat._damage_enemy(state,0,1,true)
	var peeled: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(peeled.size()<intact.size(),"Peeling Mantle during Shatterstorm must shrink the announced danger ring")
	state = combat._damage_enemy(state,0,1,true)
	var bare: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(bare.size()<peeled.size(),"The second Mantle hit must shrink the remaining Shatterstorm radius")
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["frost_armor"]==0,"Shatterstorm must spend all remaining Mantle layers")

func _test_storm_marks_conduction_and_cap() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("zekarion")
	# The opening minions remain part of the same two-Wisp cap.
	_declare(state,0)
	var marks: Array = state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].duplicate()
	state["player"]["pos"] = Vector2i(7,7)
	expect(_same_tiles(combat.enemy_threat_tiles(state,0)["attack"],marks),"Skybreak must hold its marks when the player moves")
	var connected: Dictionary = state.duplicate(true)
	for tile: Vector2i in [Vector2i(1,4),Vector2i(2,4),Vector2i(3,4)]: Surface.place(connected,tile,"electrified")
	connected["player"]["pos"] = Vector2i(3,4)
	expect(not marks.has(Vector2i(3,4)) and combat.enemy_threat_tiles(connected,0)["attack"].has(Vector2i(3,4)),"Skybreak must advertise conducted damage beyond its fixed marks")
	var marked_hp: int = connected["player"]["hp"]
	connected = BossSuite._resolve_boss_turn(connected)
	expect(connected["player"]["hp"]==marked_hp-6,"Skybreak's conducted warning must match its six damage")
	state = BossSuite._resolve_boss_turn(state)
	expect(_same_tiles(Surface.tiles(state,"electrified"),marks),"Skybreak must leave Electrified on its fixed strike cells")
	state["surfaces"] = {}
	for tile: Vector2i in [Vector2i(1,4),Vector2i(2,4),Vector2i(6,6)]: Surface.place(state,tile,"electrified")
	state["player"]["pos"] = Vector2i(1,4)
	# A persisted v2 warning retains its exact-cell, consuming contract.
	_declare(state,2)
	var legacy: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	legacy.erase("snapshot_radius")
	legacy["consume_surface"] = "electrified"
	state["enemies"][0]["intent"]["actions"] = [legacy]
	var snapshot: Array = combat.enemy_threat_tiles(state,0)["attack"]
	expect(snapshot.size()==3 and snapshot.has(Vector2i(6,6)),"Overload must announce all Electrified cells, including disconnected charges")
	Surface.place(state,Vector2i(3,4),"electrified")
	expect(not combat.enemy_threat_tiles(state,0)["attack"].has(Vector2i(3,4)),"Charges added after the Overload warning must not enlarge it through conduction")
	var broken: Dictionary = state.duplicate(true)
	Surface.place(broken,Vector2i(1,4),"fire")
	expect(not combat.enemy_threat_tiles(broken,0)["attack"].has(Vector2i(1,4)),"Replacing an announced charge must remove that Overload threat")
	var hp: int = state["player"]["hp"]
	var struck: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(struck["player"]["hp"]==hp-6,"Overload must hit an actor once for six damage")
	expect(Surface.tiles(struck,"electrified")==[Vector2i(3,4)],"Overload must consume only the surviving announced charges")
	broken = BossSuite._resolve_boss_turn(broken)
	expect(broken["player"]["hp"]==hp,"Replacing the player's charge must avoid the Overload hit")
	_declare(struck,3)
	expect((combat.enemy_threat_tiles(struck,0)["summon"] as Array).is_empty(),"A full Wisp cap must not preview another summon")
	struck = BossSuite._resolve_boss_turn(struck)
	expect(struck["enemies"].size()==3,"A full Wisp cap must not create a third helper")
	struck["enemies"][1]["hp"] = 0
	_declare(struck,3)
	struck = BossSuite._resolve_boss_turn(struck)
	var living: int = 0
	for enemy: Dictionary in struck["enemies"]:
		if enemy["type"]=="lightning_wisp" and enemy["hp"]>0: living += 1
	expect(living==2,"A later Call may replace one defeated Wisp without exceeding the cap")
	var summoned: Dictionary = struck["enemies"][-1]
	var embers: int = struck.get("room_embers",0)
	var plays: int = struck.get("death_bonus_card_plays_this_turn",0)
	struck = combat._damage_enemy(struck,struck["enemies"].size()-1,100)
	expect(bool(summoned.get("summoned",false)) and struck.get("room_embers",0)==embers and struck.get("death_bonus_card_plays_this_turn",0)==plays,"Replacement Wisp death must award neither Embers nor a card play")
	var claw: Dictionary = _empty_arena("zekarion")
	_declare(claw,1)
	claw = BossSuite._resolve_boss_turn(claw)
	expect(Surface.tiles(claw,"electrified").size()==1,"Storm Lash leaves a conductor on its struck target")

func _test_summoned_wisp_activation() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("zekarion")
	for enemy: Dictionary in state["enemies"]:
		if enemy["type"] == "lightning_wisp": enemy["hp"] = 0
	_declare(state, 3)
	state["turn_queue"] = [combat._enemy_actor_entry(state, state["enemies"][0], 20, 0)]
	state["current_actor"] = {"kind":"transition"}
	state = combat.advance_one_activation_with_steps(state)["state"]
	var summoned: Dictionary = state["enemies"][-1]
	expect(bool(summoned.get("summoned", false)), "Call Wisps activation must create a replacement helper")
	var entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(entries.size() == 1, "The newly summoned Wisp must enter the turn clock exactly once")
	if entries.size() != 1: return
	expect(int(entries[0]["time"]) > int(state["initiative_clock"]), "A summoned Wisp must wait its advertised initiative delay")
	state = bytes_to_var(var_to_bytes(state))
	var resumed_entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(resumed_entries == entries, "Saving and resuming must preserve the Wisp's single scheduled activation")
	# Stand beside the helper so either of its ordinary attacks can connect.
	var occupied: Dictionary = combat._enemy_blocking_tiles(state)
	for direction: Vector2i in [Vector2i.LEFT, Vector2i.UP, Vector2i.DOWN, Vector2i.RIGHT]:
		var neighbor: Vector2i = summoned["pos"] + direction
		if preload("res://scripts/path_utils.gd").is_passable(state["grid"], neighbor) and not occupied.has(neighbor):
			state["player"]["pos"] = neighbor
			break
	# Its first ordinary intent must execute through the same clock as the boss.
	var hp: int = int(state["player"]["hp"])
	var wisp_time: int = int(entries[0]["time"])
	state = combat.advance_one_activation_with_steps(state)["state"]
	expect(int(state["initiative_clock"]) == wisp_time, "The replacement Wisp must receive the next due activation")
	expect(int(state["player"]["hp"]) < hp, "The scheduled Wisp must actually attack, not only display an intent")
	var next_entries: Array = (state["turn_queue"] as Array).filter(func(entry: Dictionary) -> bool: return int(entry.get("enemy_id", -1)) == int(summoned["id"]))
	expect(next_entries.size() == 1 and int(next_entries[0]["time"]) > wisp_time, "The acting Wisp must reschedule once after its attack")

func _test_eclipse_refuges() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("noctyrax")
	_declare(state,0)
	var first: int = state["enemies"][0]["intent"]["actions"][0]["brazier_id"]
	var refuge: Vector2i
	var snuffed: Vector2i
	for brazier: Dictionary in state["guardian_braziers"]:
		if brazier["id"]==first: snuffed=brazier["pos"]
		else: refuge=brazier["pos"]
	state = BossSuite._resolve_boss_turn(state)
	expect(state["enemies"][0]["intent"]["id"]=="last_eclipse","Night Coil must reveal Eclipse after extinguishing its marked refuge")
	expect((state["guardian_braziers"] as Array).filter(func(b: Dictionary)->bool: return b["lit"]).size()==1,"Night Coil must extinguish exactly one refuge")
	state["player"]["pos"] = snuffed
	expect(combat.enemy_threat_tiles(state,0)["attack"].has(snuffed),"An unlit brazier must be inside the current Eclipse warning")
	state = combat.surface_actor_arrival(state,"player",-1,refuge)
	expect(combat.enemy_threat_tiles(state,0)["attack"].has(snuffed),"Relighting removes darkness, but the announced refuge sweep must remain")
	var hp: int = state["player"]["hp"]
	state["enemies"][1]["hp"] = 0
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==hp-5,"The relit refuge trades eight darkness damage for the weaker five-damage sweep")
	var living: int = 0
	for helper: Dictionary in state["enemies"]:
		if helper["type"]=="veilbound_acolyte" and helper["hp"]>0: living+=1
	expect(living==2 and bool(state["enemies"][-1].get("summoned",false)),"Eclipse must replace one defeated Acolyte while respecting the cap of two")
	state = bytes_to_var(var_to_bytes(state))
	_declare(state,0)
	var second: int = state["enemies"][0]["intent"]["actions"][0]["brazier_id"]
	expect(second==first,"Coil must snuff the currently used nearest refuge across serialization")
	state = BossSuite._resolve_boss_turn(state)
	expect((state["guardian_braziers"] as Array).filter(func(b: Dictionary)->bool: return b["lit"]).size()==1,"A new Coil must not restore a brazier automatically")
	for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
		for seed: int in [71,72,73]:
			var room: Dictionary = preload("res://scripts/room_generator.gd").new().generate_room(seed,BossSuite._boss_room_metadata("noctyrax",24),direction)
			for brazier: Dictionary in room["guardian_braziers"]:
				for key: String in ["terrain","traps","loot"]:
					for object: Dictionary in room[key]: expect(object["pos"]!=brazier["pos"],"Noctyrax refuge must remain readable and unobstructed for every entry")
				for enemy: Dictionary in room["enemies"]: expect(not Surface.footprint_tiles(enemy).has(brazier["pos"]),"Noctyrax refuge must not overlap an actor footprint")

func _test_footprint_trap_prediction() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("tharokh")
	_declare(state,1)
	var intent: Dictionary = state["enemies"][0]["intent"]
	# Hold this authored two-step approach, then change an off-anchor tile.
	intent["committed_plan"]["path"] = [Vector2i(4,3),Vector2i(3,3),Vector2i(2,3)]
	intent["committed_plan"]["destination"] = Vector2i(2,3)
	state["traps"] = [{"id":"off_anchor_earth","pos":Vector2i(3,4),"element":"earth","damage":0}]
	var plan: Dictionary = combat.enemy_intent_plan(state,0)
	var result: Dictionary = BossSuite._resolve_boss_turn(state)
	expect(plan["destination"]==Vector2i(3,3),"Preview must account for trap-created Rubble under the dragon's full footprint")
	expect(result["enemies"][0]["pos"]==plan["destination"],"The held charge must stop at the same anchor as its off-anchor trap preview")

func _test_saved_eclipse_warning() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("noctyrax")
	var brazier: Dictionary = state["guardian_braziers"][0]
	state["player"]["pos"] = brazier["pos"]
	state["enemies"][0]["intent"] = {"id":"last_eclipse","name":"Last Eclipse","time":6,"actions":[{"type":"umbra_eclipse","damage":8,"element":"shadow","duration":2,"snuff_brazier":true,"brazier_id":brazier["id"]}]}
	state = bytes_to_var(var_to_bytes(state))
	expect(combat.enemy_threat_tiles(state,0)["attack"].has(brazier["pos"]),"A saved legacy Eclipse must preserve its originally declared snuff warning")
	var hp: int = state["player"]["hp"]
	state = BossSuite._resolve_boss_turn(state)
	expect(state["player"]["hp"]==hp-8,"A saved legacy Eclipse must resolve the same warning after content revision")

func _test_saved_night_coil_warning() -> void:
	var combat := Combat.new()
	var state: Dictionary = _empty_arena("noctyrax")
	_declare(state,0)
	state["enemies"][0]["intent"]["restore_braziers"] = true
	for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
		action.erase("snuff_brazier")
		action.erase("brazier_id")
	for brazier: Dictionary in state["guardian_braziers"]: brazier["lit"] = false
	state = bytes_to_var(var_to_bytes(state))
	state = BossSuite._resolve_boss_turn(state)
	expect((state["guardian_braziers"] as Array).all(func(brazier: Dictionary)->bool: return bool(brazier["lit"])),"A saved legacy Night Coil must honor its already-announced relight once")
	_declare(state,0)
	expect(not bool(state["enemies"][0]["intent"].get("restore_braziers",false)),"The next newly declared Night Coil must use player-relight rules")
	state = BossSuite._resolve_boss_turn(state)
	expect((state["guardian_braziers"] as Array).any(func(brazier: Dictionary)->bool: return not bool(brazier["lit"])),"A newly declared Coil must leave its snuffed brazier for the player to relight")
