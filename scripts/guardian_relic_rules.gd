extends RefCounted
class_name GuardianRelicRules

const Data = preload("res://scripts/game_data.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const GuardianRules = preload("res://scripts/guardian_combat_rules.gd")
const INVALID := Vector2i(-1,-1)

static func amount(state: Dictionary, effect_type: String) -> int:
	var result: int = 0
	for effect: Dictionary in Data.relic_effects_for_ids(state.get("relics",[])):
		if str(effect.get("type","")) == effect_type: result += int(effect.get("amount",1))
	return result

static func boosted(base: int, count: int, percent: int) -> int:
	return floori(float(base)*(1.0 + float(maxi(0,count)*percent)/100.0)+0.5)

static func fire_component(state: Dictionary, origin: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if not Surfaces.has_surface(state,origin,"fire"): return result
	result.append(origin)
	var cursor: int = 0
	while cursor < result.size():
		var at: Vector2i = result[cursor]
		cursor+=1
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = at+direction
			if not result.has(tile) and Surfaces.has_surface(state,tile,"fire"): result.append(tile)
	return result

static func overlap(unit: Dictionary, crosses: Dictionary) -> int:
	var result: int = 1
	for tile: Vector2i in Surfaces.footprint_tiles(unit): result = maxi(result,int(crosses.get(tile,0)))
	return result

static func ice_step_cost(state: Dictionary, unit: Dictionary, from: Vector2i, to: Vector2i, previous_direction: Vector2i) -> int:
	var cost: int = Surfaces.movement_step_cost(state,unit,from,to)
	if not unit.has("id") and amount(state,"ice_stride")>0 and previous_direction==to-from and Surfaces.has_surface(state,from,"ice") and Surfaces.has_surface(state,to,"ice"):
		cost-=1
	return maxi(0,cost)

static func ice_navigation(state: Dictionary, unit: Dictionary, budget: int, blocked: Dictionary, hazard_cost: Callable, minimum: bool, pickup_score: Callable, stop: Callable) -> Dictionary:
	var start: Vector2i = unit["pos"]
	var paths: Dictionary = {start:GuardianRules.tiles([start])}
	var costs: Dictionary = {start:0}
	var hazards: Dictionary = {start:0}
	var pickups: Dictionary = {start:0}
	var queue: Array[Dictionary] = []
	queue.append({"tile":start,"cost":0,"harm":0,"pickup":0,"direction":Vector2i.ZERO,"path":paths[start]})
	var best: Dictionary = {}
	var cursor: int = 0
	while cursor<queue.size():
		var current: Dictionary = queue[cursor]
		cursor+=1
		for direction: Vector2i in Paths.DIRS_4:
			var tile: Vector2i = current["tile"]+direction
			if not Paths.is_passable(state["grid"],tile) or blocked.has(tile) or current["path"].has(tile): continue
			var entry: int = ice_step_cost(state,unit,current["tile"],tile,current["direction"])
			if current["path"].size()==1 and minimum and budget>0: entry=mini(entry,budget)
			var spent: int = int(current["cost"])+entry
			if spent>budget: continue
			var harm: int = int(current["harm"])+int(hazard_cost.call(tile))
			var pickup: int = int(current["pickup"])+int(pickup_score.call(tile))
			var key: String = "%s:%s:%d"%[tile,direction,spent]
			if best.has(key):
				var prior: Dictionary = best[key]
				if int(prior["harm"])<harm or (int(prior["harm"])==harm and int(prior["pickup"])>=pickup): continue
			best[key]={"harm":harm,"pickup":pickup}
			var path: Array[Vector2i] = GuardianRules.tiles(current["path"])
			path.append(tile)
			if not paths.has(tile) or harm<int(hazards[tile]) or (harm==int(hazards[tile]) and (pickup>int(pickups[tile]) or (pickup==int(pickups[tile]) and spent<int(costs[tile])))):
				paths[tile]=path
				costs[tile]=spent
				hazards[tile]=harm
				pickups[tile]=pickup
			if stop.is_valid() and bool(stop.call(tile)): return {"paths":paths,"costs":costs,"hazards":hazards}
			# At the budget boundary a straight Ice continuation can still be free.
			queue.append({"tile":tile,"direction":direction,"cost":spent,"harm":harm,"pickup":pickup,"path":path})
	return {"paths":paths,"costs":costs,"hazards":hazards}

static func force_group(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, source: Vector2i) -> Dictionary:
	var target: Dictionary = state["enemies"][index]
	# Defeated targets cannot move or reserve their surviving neighbors.
	if int(target.get("hp",0))<=0: return state
	var context: Dictionary = action.get("_group_force_context", {})
	var moved_ids: Dictionary = context.get("moved_ids", {})
	if moved_ids.has(int(target["id"])): return state
	var pushing: bool = int(action.get("push",0))>0
	var distance: int = int(action.get("push",0)) if pushing else int(action.get("pull",0))
	var direction: Vector2i = engine._action_force_direction(action)
	if direction==Vector2i.ZERO:
		direction = engine._cardinal_direction(target["pos"]-source) * (1 if pushing else -1)
	if direction==Vector2i.ZERO or distance<=0: return state
	var target_distance: int = engine._enemy_distance_to_tile(target,source)
	var projected: Dictionary = target.duplicate(true)
	projected["pos"] += direction
	var next_distance: int = engine._enemy_distance_to_tile(projected,source)
	if not bool(action.get("_allow_sideways_force",false)) and ((pushing and next_distance<=target_distance) or (not pushing and next_distance>=target_distance)): return state
	var group: Array[int] = []
	group.append(index)
	var anchors: Dictionary = {target["pos"]:index}
	for member_index: int in range(state["enemies"].size()):
		var member: Dictionary = state["enemies"][member_index]
		if int(member.get("hp",0))>0: anchors[member["pos"]]=member_index
	# Include touching full footprints only when their anchors share the force axis.
	var changed: bool = true
	while changed:
		changed=false
		for member_index: int in range(state["enemies"].size()):
			if group.has(member_index): continue
			var member: Dictionary = state["enemies"][member_index]
			if int(member.get("hp",0))<=0: continue
			var delta: Vector2i = member["pos"]-target["pos"]
			if (direction.x!=0 and delta.y!=0) or (direction.y!=0 and delta.x!=0): continue
			for prior_index: int in group:
				var prior: Dictionary = state["enemies"][prior_index]
				var touches: bool = false
				for tile: Vector2i in Surfaces.footprint_tiles(prior):
					for member_tile: Vector2i in Surfaces.footprint_tiles(member):
						if member_tile==tile+direction or member_tile==tile-direction: touches=true
				if touches:
					group.append(member_index)
					changed=true
					break
	group.sort()
	for member_index: int in group: moved_ids[int(state["enemies"][member_index]["id"])] = true
	for step: int in range(distance):
		var blocked: Dictionary = engine._occupied_actor_tiles(state)
		blocked[state["player"]["pos"]] = true
		for member_index: int in group:
			for tile: Vector2i in Surfaces.footprint_tiles(state["enemies"][member_index]): blocked.erase(tile)
		for tile: Vector2i in engine._occupied_terrain_tiles(state): blocked[tile]=true
		var origins: Dictionary = {}
		for member_index: int in group:
			var member: Dictionary = state["enemies"][member_index]
			if int(member.get("hp",0))<=0: return state
			origins[member_index]=member["pos"]
			for tile: Vector2i in Surfaces.footprint_tiles(member,member["pos"]+direction):
				if not Paths.is_passable(state["grid"],tile) or blocked.has(tile): return state
		# Translate atomically, then resolve ordinary contacts in stable actor order.
		for member_index: int in group: state["enemies"][member_index]["pos"] += direction
		for member_index: int in group:
			state = engine.surface_actor_arrival(state,"enemy",int(state["enemies"][member_index]["id"]),origins[member_index])
		for member_index: int in group:
			var member: Dictionary = state["enemies"][member_index]
			Surfaces.record_event(state,{"kind":"guardian_line_step","enemy_id":member["id"],"from":origins[member_index],"to":member["pos"],"source":{"actor_kind":"player","relic_id":"galehook_talon"}})
		for member_index: int in group:
			var member: Dictionary = state["enemies"][member_index]
			if int(member.get("hp",0))<=0 or member["pos"]!=origins[member_index]+direction: return state
	return state

static func command_targets(engine: RefCounted, state: Dictionary, command: String) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if amount(state,"recoverable_cover")<=0 or not engine.is_player_turn(state) or engine.player_movement_remaining(state)<1 or engine.combat_outcome(state)!="": return result
	if bool((state.get("player_turn_restrictions",{}) as Dictionary).get("frozen",false)): return result
	var player: Dictionary = state["player"]
	if command=="raise_cover" and int(player.get("stoneskin",0))>0:
		for tile: Vector2i in Paths.diamond_tiles(player["pos"],2,state["grid"]):
			if engine.is_tile_visible_to_player(state,tile) and GuardianRules.is_empty_floor(engine,state,tile): result.append(tile)
	elif command=="reclaim_cover":
		for cover: Dictionary in state.get("terrain",[]):
			if str(cover.get("kind",""))=="raised_cover" and str(cover.get("owner_kind",""))=="player" and int(cover.get("hp",0))>0 and Paths.manhattan(player["pos"],cover["pos"])==1: result.append(cover["pos"])
	return result

static func use_command(engine: RefCounted, state: Dictionary, command: String, target: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	if not command_targets(engine,state,command).has(target): return next
	var player: Dictionary = next["player"]
	var armor: int = 0
	if command=="raise_cover":
		armor=int(player["stoneskin"])
		player["stoneskin"]=0
		Surfaces.remove(next,target,"all","terrain_created")
		next["terrain"].append({"id":"cover_%s"%next.get("surface_event_sequence",0),"kind":"raised_cover","owner_kind":"player","pos":target,"hp":armor,"max_hp":armor,"surface_on_destroy":"rubble"})
	else:
		var cover_index: int = engine._terrain_index_at_tile(next,target)
		armor=int(next["terrain"][cover_index]["hp"])
		player["stoneskin"]=int(player.get("stoneskin",0))+armor
		next["terrain"].remove_at(cover_index)
	next["player_movement_remaining"] = engine.player_movement_remaining(state)-1
	Surfaces.record_event(next,{"kind":"guardian_relic_command","command":command,"tile":target,"armor":armor,"movement_spent":1,"source":{"actor_kind":"player","relic_id":"cragbound_gauntlet"}})
	return next

static func illusion_navigation(engine: RefCounted, state: Dictionary, illusion_id: int) -> Dictionary:
	if amount(state,"illusion_movement")<=0 or not engine.is_player_turn(state) or engine.player_movement_remaining(state)<=0 or engine.combat_outcome(state)!="": return {}
	if bool((state.get("player_turn_restrictions",{}) as Dictionary).get("frozen",false)): return {}
	var unit: Dictionary = engine._surface_actor(state,"illusion",illusion_id)
	if unit.is_empty() or int(unit.get("hp",0))<=0: return {}
	var blocked: Dictionary = engine._known_actor_tiles_for_player(state)
	for other: Dictionary in state.get("illusions",[]):
		if int(other.get("hp",0))>0: blocked[other["pos"]] = true
	blocked.erase(unit["pos"])
	blocked[state["player"]["pos"]]=true
	return engine._unit_movement_navigation(state,unit,engine.player_movement_remaining(state),blocked,engine.player_movement_remaining(state)==engine.player_movement_capacity(state))

static func move_illusion(engine: RefCounted, state: Dictionary, illusion_id: int, target: Vector2i) -> Dictionary:
	var next: Dictionary = state.duplicate(true)
	var plan: Dictionary = illusion_navigation(engine,state,illusion_id)
	var path: Array[Vector2i] = GuardianRules.tiles((plan.get("paths",{}) as Dictionary).get(target,[]))
	if path.size()<2: return next
	var spent: int = 0
	var traversed: Array[Vector2i] = GuardianRules.tiles([path[0]])
	for step: int in range(1,path.size()):
		var unit: Dictionary = engine._surface_actor(next,"illusion",illusion_id)
		if int(unit.get("hp",0))<=0 or unit.get("pos",INVALID)!=path[step-1]: break
		var blockers: Dictionary = engine._occupied_actor_tiles(next,-1,illusion_id)
		if blockers.has(path[step]) or path[step] == next["player"]["pos"]: break
		var cost: int = Surfaces.movement_step_cost(next,unit,path[step-1],path[step])
		if step==1 and engine.player_movement_remaining(state)==engine.player_movement_capacity(state): cost=mini(cost,engine.player_movement_remaining(state))
		if spent+cost>engine.player_movement_remaining(state): break
		spent+=cost
		next=engine._surface_move_illusion(next,illusion_id,path[step]-path[step-1])
		traversed.append(path[step])
	next["player_movement_remaining"]=engine.player_movement_remaining(state)-spent
	next["last_illusion_movement"]={"illusion_id":illusion_id,"target":target,"path":traversed,"spent":spent,"resolved":true}
	Surfaces.record_event(next,{"kind":"illusion_moved","illusion_id":illusion_id,"path":traversed,"movement_spent":spent,"source":{"actor_kind":"player","relic_id":"procession_lantern"}})
	return next
