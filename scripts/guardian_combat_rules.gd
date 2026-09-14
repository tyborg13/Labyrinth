extends RefCounted
class_name GuardianCombatRules

# Identity lives in data. These verbs commit world-space plans and use the
# ordinary combat engine for damage, contact, statuses, terrain and scheduling.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const INVALID := Vector2i(-1,-1)

static func tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	result.assign(values)
	return result

static func objects(state: Dictionary, kind: String, owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for object: Dictionary in state.get("terrain", []):
		if str(object.get("kind","")) == kind and int(object.get("owner_id",-1)) == owner and int(object.get("hp",0)) > 0:
			result.append(object)
	return result

static func quake_tiles(state: Dictionary, owner: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for object: Dictionary in objects(state,"crag_outcrop",owner):
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = object["pos"] + direction
			if Paths.is_passable(state["grid"],tile) and not result.has(tile): result.append(tile)
	return result

static func cleanup(state: Dictionary, enemy: Dictionary) -> void:
	if not bool((enemy.get("intent",{}) as Dictionary).get("restore_braziers",false)): return
	for brazier: Dictionary in state.get("guardian_braziers",[]): brazier["lit"] = true
	for helper: Dictionary in state.get("enemies",[]):
		if int(helper.get("outage_owner",-1)) == int(enemy.get("id",-2)) and int(helper.get("hp",0)) > 0:
			helper["hp"] = 0
			helper["departed"] = true
	Surfaces.record_event(state,{"kind":"guardian_light_restored","source":{"actor_kind":"enemy","actor_id":enemy["id"]}})

static func is_empty_floor(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	if tile == (state.get("player",{}) as Dictionary).get("pos",INVALID) or not Paths.is_passable(state.get("grid",[]),tile) or engine._occupied_actor_tiles(state).has(tile) or engine._terrain_index_at_tile(state,tile) >= 0 or engine._trap_index_at_tile(state,tile) >= 0: return false
	for object: Dictionary in state.get("guardian_braziers",[]):
		if object.get("pos",INVALID) == tile: return false
	return true

# Occupants are temporary; walls and living terrain define arena connectivity.
# Removing the proposed tile may shorten routes, but must not split any part of
# its current floor component away from the player or the other floor tiles.
static func preserves_routes(engine: RefCounted, state: Dictionary, blocked: Vector2i) -> bool:
	var adjacent: Array[Vector2i] = []
	for direction: Vector2i in Paths.DIRS_4:
		var tile: Vector2i = blocked + direction
		if Paths.is_passable(state["grid"],tile) and engine._terrain_index_at_tile(state,tile)<0: adjacent.append(tile)
	if adjacent.size()<2: return false
	var seen: Dictionary = {blocked:true, adjacent[0]:true}
	var queue: Array[Vector2i] = tiles([adjacent[0]])
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = current + direction
			if not seen.has(tile) and Paths.is_passable(state["grid"],tile) and engine._terrain_index_at_tile(state,tile)<0:
				seen[tile] = true
				queue.append(tile)
	for tile: Vector2i in adjacent:
		if not seen.has(tile): return false
	return true

static func candidates(engine: RefCounted, state: Dictionary, origin: Vector2i, toward: Vector2i, reach: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for tile: Vector2i in Paths.diamond_tiles(origin,reach,state["grid"]):
		if is_empty_floor(engine,state,tile): result.append(tile)
	result.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		var da: int = Paths.manhattan(a,toward)
		var db: int = Paths.manhattan(b,toward)
		if da != db: return da < db
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result

static func commit(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> Dictionary:
	var result: Dictionary = intent.duplicate(true)
	var enemy: Dictionary = state["enemies"][index]
	var plan: Dictionary = engine.enemy_intent_plan(state,index,result)
	var origin: Vector2i = plan.get("destination",enemy["pos"])
	var target: Vector2i = plan.get("target_tile",state["player"]["pos"])
	var direction: Vector2i = engine._cardinal_direction(target-origin)
	if direction == Vector2i.ZERO: direction = Vector2i.DOWN
	var all_tiles: Array[Vector2i] = []
	for action: Dictionary in result.get("actions",[]):
		var type: String = str(action.get("type",""))
		if type in ["move_toward","move_away","block","stoneskin"]: continue
		var affected: Array[Vector2i] = []
		var shape: String = str(action.get("guardian_shape",""))
		if shape in ["line","broken_line"]:
			for distance: int in range(1,int(action.get("range",1))+1):
				var tile: Vector2i = origin + direction*distance
				if not Paths.is_passable(state["grid"],tile): break
				if shape != "broken_line" or distance != 2: affected.append(tile)
				if engine._terrain_index_at_tile(state,tile)>=0: break
		elif shape == "sweep":
			var side := Vector2i(-direction.y,direction.x)
			for offset: int in [-1,0,1]:
				var tile: Vector2i = origin + direction + side*offset
				if Paths.is_passable(state["grid"],tile): affected.append(tile)
		elif type in ["raise_terrain","summon_minions"] or shape == "connector":
			var choices: Array[Vector2i] = candidates(engine,state,origin,target,3 if type != "surface" else int(action.get("range",2)))
			var count: int = int(action.get("count",action.get("guardian_count",1)))
			for offset: int in range(mini(count,choices.size())): affected.append(choices[offset])
		elif type == "terrain_burst":
			affected = quake_tiles(state,int(enemy["id"]))
		elif shape == "conductor":
			var conductors: Array[Vector2i] = []
			for tile: Vector2i in Surfaces.tiles(state):
				if Surfaces.is_conductive(state,tile) and Paths.manhattan(origin,tile)<=int(action.get("range",3)) and engine.combat_line_of_sight(state,origin,tile): conductors.append(tile)
			conductors.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
				var da: int = Paths.manhattan(a,target)
				var db: int = Paths.manhattan(b,target)
				return da<db if da!=db else (a.y<b.y if a.y!=b.y else a.x<b.x))
			if not conductors.is_empty(): affected.append(conductors[0])
		else:
			affected.assign(plan.get("projected_attack",[]))
		action["_guardian_committed"] = true
		action["declared_tiles"] = affected
		action["declared_origin"] = origin
		action["declared_direction"] = direction
		if bool(action.get("snuff_brazier",false)):
			var braziers: Array = state.get("guardian_braziers",[])
			if not braziers.is_empty():
				var brazier: Dictionary = braziers[posmod(int(enemy.get("guardian_cycle",0))/3,braziers.size())]
				action["brazier_id"] = int(brazier["id"])
				var spawn: Array[Vector2i] = candidates(engine,state,brazier["pos"],brazier["pos"],1)
				action["declared_tiles"] = tiles([spawn[0]]) if not spawn.is_empty() else tiles([])
		for tile: Vector2i in action["declared_tiles"]:
			if not all_tiles.has(tile): all_tiles.append(tile)
	plan["projected_attack"] = all_tiles
	plan["attack_action"] = {}
	for action: Dictionary in result.get("actions",[]):
		if bool(action.get("_guardian_committed",false)):
			plan["attack_action"] = action.duplicate(true)
			break
	plan["projected_attack_target"] = all_tiles[0] if not all_tiles.is_empty() else INVALID
	plan["committed"] = true
	result["committed_plan"] = plan
	return result

static func current_plan(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary, movement_disabled: bool, attack_disabled: bool) -> Dictionary:
	var plan: Dictionary = (intent["committed_plan"] as Dictionary).duplicate(true)
	var declared_path: Array[Vector2i] = tiles(plan.get("path",[]))
	var path: Array[Vector2i] = tiles([enemy["pos"]])
	if not movement_disabled and not declared_path.is_empty() and declared_path[0] == enemy["pos"]:
		var blocked: Dictionary = engine._enemy_path_blockers(state,enemy,true,false)
		var spent: int = 0
		var move_index: int = int(plan.get("movement_action_index", -1))
		var allowance: int = int(intent["actions"][move_index].get("range",0)) if move_index>=0 else 0
		for index: int in range(1,declared_path.size()):
			var tile: Vector2i = declared_path[index]
			if not engine._enemy_can_occupy_anchor(state,enemy,tile,blocked): break
			var cost: int = Surfaces.movement_step_cost(state,enemy,path[-1],tile)
			if index==1: cost=mini(cost,allowance)
			if spent+cost>allowance: break
			spent+=cost
			path.append(tile)
	plan["path"] = path
	plan["destination"] = path[-1]
	var projected: Array[Vector2i] = []
	if not attack_disabled:
		for action: Dictionary in intent.get("actions",[]):
			if not handles(action): continue
			if str(action.get("type","")) not in ["surface","raise_terrain","summon_minions","terrain_burst"] and path[-1] != action.get("declared_origin",INVALID): continue
			var impact: Array[Vector2i] = live_tiles(engine,state,enemy,action)
			for tile: Vector2i in impact:
				if not projected.has(tile): projected.append(tile)
			if str(action.get("guardian_shape","")) == "conductor" and not impact.is_empty():
				var discharge: Dictionary = engine._board_attack_plan(state,action,impact,"enemy")
				for tile: Vector2i in discharge.get("used_conductors",{}):
					if not projected.has(tile): projected.append(tile)

	plan["projected_attack"] = projected
	return plan

static func handles(action: Dictionary) -> bool:
	return bool(action.get("_guardian_committed",false))

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator, bleed_steps: Array[Dictionary]) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var type: String = str(action.get("type",""))
	var declared: Array[Vector2i] = live_tiles(engine,state,enemy,action)
	if type == "surface":
		for tile: Vector2i in declared: Surfaces.place(state,tile,str(action.get("surface","")),engine._surface_source(state,action))
	elif type == "raise_terrain":
		var existing: int = objects(state,"crag_outcrop",int(enemy["id"])).size()
		for tile: Vector2i in declared:
			if existing>=2: break
			if not is_empty_floor(engine,state,tile): continue
			if not preserves_routes(engine,state,tile): continue
			Surfaces.remove(state,tile,"all","terrain_created")
			state["terrain"].append({"id":"crag_%s_%s_%s"%[enemy["id"],enemy.get("guardian_cycle",0),existing],"owner_id":enemy["id"],"kind":"crag_outcrop","hp":int(action.get("health",3)),"max_hp":int(action.get("health",3)),"pos":tile,"surface_on_destroy":"rubble"})
			existing+=1
	elif type == "summon_minions":
		if action.has("brazier_id"):
			for brazier: Dictionary in state.get("guardian_braziers",[]):
				if int(brazier["id"]) == int(action["brazier_id"]): brazier["lit"] = false
			Surfaces.record_event(state,{"kind":"guardian_light_snuffed","brazier_id":action["brazier_id"],"source":engine._surface_source(state,action)})
		var living: int = 0
		var same_type: int = 0
		for helper: Dictionary in state.get("enemies",[]):
			if int(helper.get("hp",0))<=0 or not bool(helper.get("guardian_helper",false)): continue
			living+=1
			if str(helper["type"])==str(action["minion_type"]): same_type+=1
		if living>=2 or same_type>=int(action.get("guardian_cap",1)): return state
		for tile: Vector2i in declared:
			if not is_empty_floor(engine,state,tile): continue
			var helper: Dictionary = engine._spawned_enemy_entry(state,str(action["minion_type"]),engine._next_enemy_id(state),tile,true)
			helper["guardian_helper"] = true
			helper["reward_embers"] = 0
			if action.has("brazier_id"): helper["outage_owner"] = enemy["id"]
			state["enemies"].append(helper)
			var spawn_index: int = state["enemies"].size()-1
			var source_rng: RandomNumberGenerator = rng
			if source_rng == null:
				source_rng = RandomNumberGenerator.new()
				source_rng.state = int(state.get("rng_state",1))
			engine._assign_enemy_intent(state,spawn_index,source_rng)
			state = engine.surface_actor_arrival(state,"enemy",int(helper["id"]),INVALID)
			engine._schedule_enemy_after_spawn(state,state["enemies"][spawn_index],0)
			Surfaces.record_event(state,{"kind":"guardian_helper_summoned","enemy_id":helper["id"],"enemy_type":helper["type"],"source":engine._surface_source(state,action)})
			break
	else:
		state = engine._trigger_enemy_bleed_for_resolved_action(state,index,action,bleed_steps)
		if engine._enemy_cannot_continue_after_bleed(state,index): return state
		if enemy.get("pos",INVALID) != action.get("declared_origin",INVALID) and type != "terrain_burst":
			# Interrupting the approach prevents a distant hit from its old endpoint.
			declared.clear()
		if not declared.is_empty():
			state = engine._resolve_board_attack(state,action,declared[0],"enemy",int(enemy["id"]),{},declared)
			if action.has("terminal_surface"): Surfaces.place(state,declared[-1],str(action["terminal_surface"]),engine._surface_source(state,action))
		if int(action.get("self_expose",0))>0 and int(state["enemies"][index].get("hp",0))>0:
			state["enemies"][index]["expose"] = maxi(int(state["enemies"][index].get("expose",0)),int(action["self_expose"]))
	return state

static func live_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if str(action.get("type", "")) == "terrain_burst": return quake_tiles(state,int(enemy["id"]))
	var declared: Array[Vector2i] = tiles(action.get("declared_tiles",[]))
	if str(action.get("guardian_shape", "")) == "conductor":
		var valid: Array[Vector2i] = []
		for tile: Vector2i in declared:
			if Surfaces.is_conductive(state,tile) and engine.combat_line_of_sight(state,action["declared_origin"],tile): valid.append(tile)
		return valid
	if str(action.get("guardian_shape", "")) not in ["line", "broken_line"]: return declared
	var result: Array[Vector2i] = []
	var origin: Vector2i = action.get("declared_origin",enemy["pos"])
	var direction: Vector2i = action.get("declared_direction",Vector2i.ZERO)
	for distance: int in range(1,int(action.get("range",1))+1):
		var tile: Vector2i = origin + direction*distance
		if not Paths.is_passable(state["grid"],tile): break
		if declared.has(tile): result.append(tile)
		if engine._terrain_index_at_tile(state,tile)>=0: break
	return result

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	var type: String = str(action["type"])
	var affected: Array[Vector2i] = live_tiles(engine,before,enemy,action)
	var attack: bool = type not in ["surface","raise_terrain","summon_minions"]
	if attack and type != "terrain_burst" and enemy["pos"] != action.get("declared_origin",INVALID): affected.clear()
	var kind: String = "summon" if type == "summon_minions" else "surface" if not attack else "aoe" if affected.size()!=1 or type=="terrain_burst" else type
	var target: Vector2i = affected[0] if not affected.is_empty() else enemy["pos"]
	var losses: Array[Dictionary] = engine._actor_target_losses(before,after)
	var terrain_losses: Array[Dictionary] = engine._terrain_target_losses(before,after)
	var intent: Dictionary = enemy.get("intent", {})
	return {"kind":kind,"action_type":type,"enemy_type":enemy["type"],"guardian_mechanic":true,"declared_tiles":action.get("declared_tiles", []).duplicate(),"actor_key":engine._enemy_key(enemy),"actor_name":engine._enemy_display_name(enemy),
		"intent_id":str(intent.get("id","")),"label":str(intent.get("name",type.capitalize())),
		"from":enemy["pos"],"to":target,"tile":enemy["pos"],"center":target,"tiles":affected,
		"element":str(action.get("element",preload("res://scripts/game_data.gd").enemy_def(str(enemy["type"])).get("element","none"))),
		"range":int(action.get("range",0)),"amount":engine._target_loss_amount(losses),"target_losses":losses,"terrain_losses":terrain_losses,
		"impact_actor_keys":engine._target_loss_keys(losses),"triggered_traps":engine._triggered_traps_between(before,after),
		"guardian_state_after":after.duplicate(true),"surface":str(action.get("surface","rubble")),
		"spawned_enemies":after["enemies"].slice(before["enemies"].size()).duplicate(true)}
