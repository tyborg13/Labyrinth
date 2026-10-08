# Frozen calculation paths; typed local initializers adapted for Windows compatibility.
extends RefCounted

# Identity lives in data. These verbs commit oriented plans and use the
# ordinary combat engine for damage, contact, statuses, terrain and scheduling.
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const INVALID := Vector2i(-1,-1)
const Library = preload("res://scripts/guardian_library.gd")
const Patterns = preload("res://scripts/committed_pattern_shapes.gd")
const Fields = preload("res://scripts/dragon_pressure_fields.gd")
const DIRECTIONAL_SHAPES = ["line", "broken_line", "sweep", "crescent", "fan"]
const GEOMETRIC_SHAPES = ["line", "broken_line", "sweep", "crescent", "fan", "ring", "swept_path", "cross"]

static func shape(action: Dictionary) -> String:
	return str(action.get("committed_shape", action.get("guardian_shape", "")))

static func tiles(values: Array) -> Array[Vector2i]:
	var result: Array[Vector2i]
	result.assign(values)
	return result

static func objects(state: Dictionary, kind: String, owner: int) -> Array[Dictionary]:
	var result: Array[Dictionary]
	for object: Dictionary in state.get("terrain", []):
		if str(object.get("kind","")) == kind and int(object.get("owner_id",-1)) == owner and int(object.get("hp",0)) > 0:
			result.append(object)
	return result

static func quake_tiles(state: Dictionary, owner: int, reach: int = 1) -> Array[Vector2i]:
	var result: Array[Vector2i]
	for object: Dictionary in objects(state,"crag_outcrop",owner):
		for tile: Vector2i in Paths.diamond_tiles(object["pos"],reach,state["grid"]):
			if tile!=object["pos"] and Paths.is_passable(state["grid"],tile) and not result.has(tile): result.append(tile)
	return result

static func cleanup(state: Dictionary, enemy: Dictionary) -> void:
	if not bool((enemy.get("intent",{}) as Dictionary).get("restore_braziers",false)): return
	var relit: Array[Vector2i]
	for brazier: Dictionary in state.get("guardian_braziers",[]):
		if not bool(brazier.get("lit",true)): relit.append(brazier["pos"])
		brazier["lit"] = true
	for helper: Dictionary in state.get("enemies",[]):
		if int(helper.get("outage_owner",-1)) == int(enemy.get("id",-2)) and int(helper.get("hp",0)) > 0:
			helper["hp"] = 0
			helper["departed"] = true
	Surfaces.record_event(state,{"kind":"guardian_light_restored","tiles":relit,"trigger_intent":str(enemy.get("intent",{}).get("id","")),"source":{"actor_kind":"enemy","actor_id":enemy["id"]}})

static func is_empty_floor(engine: RefCounted, state: Dictionary, tile: Vector2i) -> bool:
	return Terrain.is_empty_floor(engine, state, tile)

# Occupants are temporary; walls and living terrain define arena connectivity.
# Removing the proposed tile may shorten routes, but must not split any part of
# its current floor component away from the player or the other floor tiles.
static func preserves_routes(engine: RefCounted, state: Dictionary, blocked: Vector2i) -> bool:
	var adjacent: Array[Vector2i]
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
	var result: Array[Vector2i]
	for tile: Vector2i in Paths.diamond_tiles(origin,reach,state["grid"]):
		if is_empty_floor(engine,state,tile): result.append(tile)
	result.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
		var da: int = Paths.manhattan(a,toward)+(20 if Surfaces.has_surface(state,a,"fire") else 0)
		var db: int = Paths.manhattan(b,toward)+(20 if Surfaces.has_surface(state,b,"fire") else 0)
		if da != db: return da < db
		return a.y < b.y if a.y != b.y else a.x < b.x)
	return result

static func commit(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary) -> Dictionary:
	var result: Dictionary = intent.duplicate(true)
	result.erase("committed_plan")
	if not has_authored_actions(result): return result
	var enemy: Dictionary = state["enemies"][index]
	var plan: Dictionary = pattern_approach(engine,state,index,result,engine.enemy_intent_plan(state,index,result))
	var origin: Vector2i = plan.get("destination",enemy["pos"])
	var target: Vector2i = plan.get("target_tile",state["player"]["pos"])
	if target==INVALID: target=engine._closest_enemy_target(state,enemy).get("pos",state["player"]["pos"])
	var direction: Vector2i = plan.get("declared_direction",engine._cardinal_direction(target-origin))
	if direction == Vector2i.ZERO: direction = Vector2i.DOWN
	var all_tiles: Array[Vector2i]
	var summon_tiles: Array[Vector2i]
	for action: Dictionary in result.get("actions",[]):
		var type: String = str(action.get("type",""))
		if not authored_action(action): continue
		var affected: Array[Vector2i]
		var shape_id: String = shape(action)
		if shape_id in GEOMETRIC_SHAPES:
			var geometry: Dictionary = action.duplicate(true)
			geometry["_resolved_path"] = plan.get("path",[origin])
			geometry = status_range(enemy,geometry)
			affected = shape_tiles(engine,state,origin,direction,geometry)
		elif shape_id == "surface_snapshot":
			affected = Fields.source_tiles(state,enemy,action)
		elif shape_id == "trail_snapshot":
			affected = tiles(enemy.get(str(action.get("snapshot_key","")),[]))
		elif shape_id == "refuge":
			affected = Fields.refuge_tiles(engine,state,action)
		elif shape_id == "connector":
			affected = connector_tiles(engine,state,origin,target,action)
		elif type in ["raise_terrain","summon_minions"]:
			var choices: Array[Vector2i] = candidates(engine,state,origin,target,int(action.get("range",3)))
			if type=="summon_minions":
				# The boss acts first: do not reserve its landing square or a tile
				# this same intent is about to strike or ignite.
				choices=choices.filter(func(tile: Vector2i)->bool: return tile!=origin and not all_tiles.has(tile))
			var count: int = int(action.get("count",1))
			for offset: int in range(mini(count,choices.size())): affected.append(choices[offset])
		elif type == "terrain_burst":
			affected = quake_tiles(state,int(enemy["id"]),int(action.get("range",1)))
		elif shape_id == "conductor":
			var conductors: Array[Vector2i]
			for tile: Vector2i in Surfaces.tiles(state):
				if Surfaces.is_conductive(state,tile) and Paths.manhattan(origin,tile)<=int(action.get("range",3)) and engine.combat_line_of_sight(state,origin,tile): conductors.append(tile)
			conductors.sort_custom(func(a: Vector2i,b: Vector2i)->bool:
				var da: int = component_distance(state,a,target)
				var db: int = component_distance(state,b,target)
				return da<db if da!=db else (a.y<b.y if a.y!=b.y else a.x<b.x))
			if not conductors.is_empty(): affected.append(conductors[0])
		else:
			affected.assign(plan.get("projected_attack",[]))
		action["_guardian_committed"] = true
		action["declared_tiles"] = affected
		action["declared_origin"] = origin
		action["declared_direction"] = direction
		if action.has("committed_shape"):
			if shape_id in DIRECTIONAL_SHAPES:
				if int(action.get("push",0)) > 0: action["force_direction"] = direction
				elif int(action.get("pull",0)) > 0: action["force_direction"] = -direction
		if type == "summon_minions" and bool(action.get("snuff_brazier",false)):
			var braziers: Array = state.get("guardian_braziers",[])
			if not braziers.is_empty():
				var brazier: Dictionary = braziers[posmod(int(enemy.get("guardian_cycle",0))/3,braziers.size())]
				action["brazier_id"] = int(brazier["id"])
				var spawn: Array[Vector2i] = candidates(engine,state,brazier["pos"],brazier["pos"],1)
				action["declared_tiles"] = tiles([spawn[0]]) if not spawn.is_empty() else tiles([])
		for tile: Vector2i in action["declared_tiles"]:
			if type == "summon_minions":
				if not summon_tiles.has(tile): summon_tiles.append(tile)
			elif not all_tiles.has(tile): all_tiles.append(tile)
	plan["projected_attack"] = all_tiles
	plan["projected_summon"] = summon_tiles
	plan["attack_action"] = {}
	for action: Dictionary in result.get("actions",[]):
		if bool(action.get("_guardian_committed",false)) and str(action.get("type","")) != "summon_minions":
			plan["attack_action"] = action.duplicate(true)
			break
	plan["projected_attack_target"] = all_tiles[0] if not all_tiles.is_empty() else INVALID
	plan["committed"] = true
	result["committed_plan"] = plan
	return result

static func current_plan(engine: RefCounted, state: Dictionary, enemy: Dictionary, intent: Dictionary, movement_disabled: bool, attack_disabled: bool) -> Dictionary:
	var plan: Dictionary = (intent["committed_plan"] as Dictionary).duplicate(true)
	var survives: bool = true
	if not holds_path(intent):
		var direct: Dictionary = intent.duplicate(true)
		direct.erase("committed_plan")
		plan = engine.enemy_intent_plan(state,int(plan.get("enemy_index",-1)),direct,movement_disabled,attack_disabled)
	else:
		var declared_path: Array[Vector2i] = tiles(plan.get("path",[]))
		var path: Array[Vector2i] = tiles([enemy["pos"]])
		var move_slot: int = int(plan.get("movement_action_index",-1))
		var budget: int = int(intent["actions"][move_slot].get("range",0)) if move_slot>=0 else 0
		if not movement_disabled and not declared_path.is_empty():
			var displacement: Vector2i = enemy["pos"]-declared_path[0]
			var blocked: Dictionary = engine._enemy_path_blockers(state,enemy,true,false)
			var spent: int = 0
			for index: int in range(1,declared_path.size()):
				var tile: Vector2i = declared_path[index]+displacement
				if not engine._enemy_can_occupy_anchor(state,enemy,tile,blocked): break
				var cost: int = Surfaces.movement_step_cost(state,enemy,path[-1],tile)
				if index==1: cost=mini(cost,budget)
				if spent+cost>budget: break
				spent+=cost
				path.append(tile)
		# Traps and surfaces can stop the approach. The announced orientation
		# stays fixed; its pattern originates at the actual surviving arrival.
		var hazardous: bool = false
		for anchor: Vector2i in path.slice(1):
			for tile: Vector2i in engine._enemy_footprint_tiles(enemy,anchor):
				if Surfaces.element_at(state,tile) in ["fire","ice"] or engine._trap_index_at_tile(state,tile)>=0:
					hazardous = true
					break
			if hazardous: break
		var route_record: Dictionary = {"tile":path[-1],"path":path,"trap_cost":1 if hazardous else 0}
		var arrival: Dictionary = engine._enemy_attack_route_prediction(state,enemy,route_record,budget) if path.size()>1 else {"destination":path[-1],"survives":true}
		var arrived: Vector2i = arrival.get("destination",path[-1])
		if path.has(arrived): path.resize(path.find(arrived)+1)
		plan["path"] = path
		plan["destination"] = path[-1]
		survives = bool(arrival.get("survives",true))
	var preview_state: Dictionary = state.duplicate(true)
	var preview_enemy: Dictionary = preview_state["enemies"][int(plan.get("enemy_index",-1))]
	preview_enemy["pos"] = plan.get("destination",enemy["pos"])
	preview_state["current_actor"] = engine._enemy_actor_entry(preview_state,preview_enemy,int(state.get("initiative_clock",0)),int(state.get("activation_seq",0)))
	var projected: Array[Vector2i]
	var summons: Array[Vector2i]
	if not attack_disabled and survives:
		var actions: Array = intent.get("actions", [])
		var preview_rng := RandomNumberGenerator.new()
		preview_rng.state = int(state.get("rng_state", 0))
		for action_index: int in range(actions.size()):
			var action: Dictionary = actions[action_index]
			if str(action.get("type","")) in ["summon_minions", "move_toward", "move_away"]: continue
			if int(preview_enemy.get("hp", 0)) <= 0: break
			var geometry: Dictionary = action.duplicate(true)
			geometry["_resolved_path"] = plan.get("path",[preview_enemy["pos"]])
			var context: Dictionary = plan.duplicate(true)
			context["action_index"] = action_index
			context["resolved_path"] = geometry["_resolved_path"]
			if not handles(action):
				# Direct shots use the board left by earlier pressure, including
				# an illusion killed by the first half of a compound attack.
				var secondary_tiles: Array[Vector2i]
				if str(action.get("type","")) in ["melee","ranged","aoe","push","pull"]:
					secondary_tiles = engine._enemy_direct_attack_threat_tiles(preview_state,int(plan["enemy_index"]),action,context)
				else:
					var secondary: Dictionary = engine.enemy_intent_plan(preview_state,int(plan["enemy_index"]),{"actions":[action]},true,false)
					secondary_tiles = tiles(secondary.get("projected_attack",[]))
				for tile: Vector2i in secondary_tiles:
					if not projected.has(tile): projected.append(tile)
			else:
				var impact: Array[Vector2i] = live_tiles(engine,preview_state,preview_enemy,geometry)
				for tile: Vector2i in impact:
					if not projected.has(tile): projected.append(tile)
				if (engine._action_element(action) == "lightning" or int(action.get("chain",0)) > 0) and not impact.is_empty():
					var discharge: Dictionary = engine._board_attack_plan(preview_state,action,impact,"enemy")
					for tile: Vector2i in discharge.get("used_conductors",{}):
						if not projected.has(tile): projected.append(tile)
					for hit: Dictionary in discharge.get("hits",[]):
						if not projected.has(hit["to"]): projected.append(hit["to"])
			# Resolve on the private copy in action order so damage, cleared
			# surfaces and displacement can alter the next warning. Reuse the
			# real resolver; a parallel damage model would drift from combat.
			var bleed_steps: Array[Dictionary]
			preview_state = engine._resolve_enemy_action(preview_state,int(plan["enemy_index"]),geometry,preview_rng,{},bleed_steps,context)
			preview_enemy = preview_state["enemies"][int(plan["enemy_index"])]
		for action: Dictionary in intent.get("actions",[]):
			if str(action.get("type", "")) == "summon_minions":
				for tile: Vector2i in (engine._summon_tiles_for_enemy(preview_state,preview_enemy,engine._available_summon_count(preview_state,action)) if action.has("summon_cap") else available_summon_tiles(engine,preview_state,preview_enemy,action)):
					if not summons.has(tile): summons.append(tile)
	plan["projected_attack"] = projected
	plan["projected_attack_target"] = projected[0] if not projected.is_empty() else INVALID
	plan["projected_summon"] = summons
	return plan

static func handles(action: Dictionary) -> bool:
	return bool(action.get("_guardian_committed",false)) and authored_action(action)

static func available_summon_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	var living: int = 0
	var same_type: int = 0
	for helper: Dictionary in state.get("enemies", []):
		if int(helper.get("hp", 0)) <= 0 or not bool(helper.get("guardian_helper", false)): continue
		living += 1
		if str(helper["type"]) == str(action.get("minion_type", "")): same_type += 1
	var available: int = mini(int(action.get("count", 1)), mini(2-living, int(action.get("guardian_cap", 1))-same_type))
	var result: Array[Vector2i]
	if available<=0: return result
	var origin: Vector2i = enemy["pos"]
	var reach: int = int(action.get("range",3))
	if action.has("brazier_id"):
		for brazier: Dictionary in state.get("guardian_braziers",[]):
			if int(brazier["id"])==int(action["brazier_id"]): origin=brazier["pos"];reach=1
	var choices: Array[Vector2i] = tiles(action.get("declared_tiles",[]))
	for tile: Vector2i in candidates(engine,state,origin,state["player"]["pos"],reach):
		if not choices.has(tile): choices.append(tile)
	var unsafe: Array[Vector2i]
	for prior: Dictionary in (enemy.get("intent",{}) as Dictionary).get("actions",[]):
		if prior==action: break
		if handles(prior) and str(prior.get("type",""))!="summon_minions":
			unsafe.append_array(live_tiles(engine,state,enemy,prior))
	for tile: Vector2i in choices:
		if result.size() >= available: break
		if Paths.manhattan(origin,tile)>reach or unsafe.has(tile): continue
		if is_empty_floor(engine,state,tile): result.append(tile)
	return result

static func resolve(engine: RefCounted, state: Dictionary, index: int, action: Dictionary, rng: RandomNumberGenerator, bleed_steps: Array[Dictionary]) -> Dictionary:
	var enemy: Dictionary = state["enemies"][index]
	var type: String = str(action.get("type",""))
	var declared: Array[Vector2i] = live_tiles(engine,state,enemy,action)
	if shape(action) == "ring":
		action = action.duplicate(true)
		action["radial_force"] = true
	if type == "surface":
		for tile: Vector2i in declared: Surfaces.place(state,tile,str(action.get("surface","")),engine._surface_source(state,action))
	elif type == "raise_terrain":
		var existing: int = objects(state,"crag_outcrop",int(enemy["id"])).size()
		for tile: Vector2i in declared:
			if existing>=2: break
			if not is_empty_floor(engine,state,tile): continue
			if not preserves_routes(engine,state,tile): continue
			if Terrain.raise_outcrop(engine, state, tile, int(action.get("health",3)), engine._surface_source(state,action)):
				existing += 1
	elif type == "summon_minions":
		if action.has("brazier_id"):
			for brazier: Dictionary in state.get("guardian_braziers",[]):
				if int(brazier["id"]) == int(action["brazier_id"]): brazier["lit"] = false
			Surfaces.record_event(state,{"kind":"guardian_light_snuffed","brazier_id":action["brazier_id"],"source":engine._surface_source(state,action)})
		for tile: Vector2i in available_summon_tiles(engine,state,enemy,action):
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
		if not declared.is_empty():
			if bool(action.get("replace_previous_trail",false)):
				for tile: Vector2i in tiles(enemy.get("authored_trail",[])):
					var owner: Dictionary = Surfaces.surface_at(state,tile).get("elemental_source",{})
					if str(owner.get("actor_kind","")) == "enemy" and int(owner.get("actor_id",-1)) == int(enemy["id"]):
						Surfaces.remove(state,tile,str(action.get("surface","")),"replaced_trail")
			state = engine._resolve_board_attack(state,action,declared[0],"enemy",int(enemy["id"]),{},declared)
			if bool(action.get("replace_previous_trail",false)): state["enemies"][index]["authored_trail"] = declared.duplicate()
			if action.has("record_trail"):
				state["enemies"][index][str(action["record_trail"])] = declared.duplicate()
			if bool(action.get("consume_trail",false)):
				state["enemies"][index][str(action.get("snapshot_key",""))] = tiles([])
			if action.has("consume_surface"):
				for tile: Vector2i in declared: Surfaces.remove(state,tile,str(action["consume_surface"]),"overload")
			if action.has("terminal_surface"): Surfaces.place(state,declared[-1],str(action["terminal_surface"]),engine._surface_source(state,action))
		if action.has("consume_status"):
			var status: String = str(action["consume_status"])
			var layers: int = int(state["enemies"][index].get(status,0))
			state["enemies"][index][status] = 0
			Surfaces.record_event(state,{"kind":"dragon_status_consumed","enemy_id":enemy["id"],"status":status,"amount":layers,"source":engine._surface_source(state,action)})
		if bool(action.get("snuff_brazier",false)):
			for brazier: Dictionary in state.get("guardian_braziers",[]):
				if int(brazier["id"]) == int(action.get("brazier_id",-1)):
					brazier["lit"] = false
					Surfaces.record_event(state,{"kind":"dragon_light_snuffed","brazier_id":brazier["id"],"tile":brazier["pos"],"source":engine._surface_source(state,action)})
		if int(action.get("self_expose",0))>0 and int(state["enemies"][index].get("hp",0))>0:
			state["enemies"][index]["expose"] = maxi(int(state["enemies"][index].get("expose",0)),int(action["self_expose"]))
	return state

static func live_tiles(engine: RefCounted, state: Dictionary, enemy: Dictionary, action: Dictionary) -> Array[Vector2i]:
	if str(action.get("type", "")) == "terrain_burst": return quake_tiles(state,int(enemy["id"]),int(action.get("range",1)))
	var declared: Array[Vector2i] = tiles(action.get("declared_tiles",[]))
	var shape_id: String = shape(action)
	var origin: Vector2i = enemy["pos"]
	if shape_id == "conductor":
		var valid: Array[Vector2i]
		for tile: Vector2i in declared:
			if Surfaces.is_conductive(state,tile) and Paths.manhattan(origin,tile)<=int(action.get("range",3)) and engine.combat_line_of_sight(state,origin,tile): valid.append(tile)
		return valid
	if shape_id == "surface_snapshot":
		var centers: Array[Vector2i] = tiles(declared.filter(func(tile: Vector2i)->bool: return Surfaces.has_surface(state,tile,str(action.get("snapshot_surface","electrified")))))
		return Fields.neighborhood(engine,state,centers,int(action.get("snapshot_radius",0)))
	if shape_id in ["trail_snapshot","refuge"]:
		return tiles(declared.filter(func(tile: Vector2i)->bool: return Paths.is_passable(state["grid"],tile)))
	if shape_id in GEOMETRIC_SHAPES:
		return shape_tiles(engine,state,origin,action.get("declared_direction",Vector2i.ZERO),status_range(enemy,action))
	if str(action.get("type","")) == "summon_minions": return declared
	var result: Array[Vector2i]
	var displacement: Vector2i = origin-action.get("declared_origin",origin)
	for tile: Vector2i in declared:
		var moved: Vector2i = tile+displacement
		if Paths.is_passable(state["grid"],moved) and engine.combat_line_of_sight(state,origin,moved): result.append(moved)
	return result

static func animation_step(engine: RefCounted, before: Dictionary, after: Dictionary, index: int, action: Dictionary) -> Dictionary:
	var enemy: Dictionary = before["enemies"][index]
	var type: String = str(action["type"])
	var affected: Array[Vector2i] = live_tiles(engine,before,enemy,action)
	var attack: bool = type not in ["surface","raise_terrain","summon_minions"]
	var spawned: Array = after["enemies"].slice(before["enemies"].size()).duplicate(true)
	var interrupted: bool = affected.is_empty() and type!="summon_minions"
	if (engine._action_element(action) == "lightning" or int(action.get("chain",0)) > 0) and not affected.is_empty():
		var network: Dictionary = engine._board_attack_plan(before,action,affected,"enemy")
		for tile: Vector2i in network.get("used_conductors",{}):
			if not affected.has(tile): affected.append(tile)
		for hit: Dictionary in network.get("hits",[]):
			if not affected.has(hit["to"]): affected.append(hit["to"])
	var kind: String = "status" if interrupted else "summon" if type == "summon_minions" else "surface" if not attack else "aoe" if affected.size()!=1 or type=="terrain_burst" else type
	var target: Vector2i = affected[0] if not affected.is_empty() else enemy["pos"]
	var losses: Array[Dictionary] = engine._actor_target_losses(before,after)
	var terrain_losses: Array[Dictionary] = engine._terrain_target_losses(before,after)
	var intent: Dictionary = enemy.get("intent", {})
	var label: String = str(intent.get("name",type.capitalize()))
	if interrupted: label="Interrupted"
	elif type=="summon_minions":
		var helper_name: String = str(preload("res://scripts/game_data.gd").enemy_def(str(action.get("minion_type",""))).get("name","Helper"))
		label=("Snuff · " if action.has("brazier_id") else "Summon · ")+helper_name if not spawned.is_empty() else "Snuff · spawn blocked" if action.has("brazier_id") else "Summon blocked"
	var dragon: bool = preload("res://scripts/dragon_boss_library.gd").is_dragon_boss_id(str(enemy["type"]))
	return {"kind":kind,"action_type":type,"enemy_type":enemy["type"],"guardian_mechanic":not dragon,"boss_mechanic":dragon,"committed_direction":shape(action) in DIRECTIONAL_SHAPES,"declared_tiles":action.get("declared_tiles", []).duplicate(),"actor_key":engine._enemy_key(enemy),"actor_name":engine._enemy_display_name(enemy),
		"intent_id":str(intent.get("id","")),"label":label,"committed_shape":shape(action),"minimum_range":int(action.get("minimum_range",1)),
		"interrupted":interrupted,"action_direction":action.get("declared_direction",Vector2i.ZERO),
		"player_from":before["player"]["pos"],"player_to":after["player"]["pos"],
		"status_text":engine._player_status_step_text(before["player"],after["player"],action),
		"from":enemy["pos"],"to":target,"tile":enemy["pos"],"center":target,"tiles":affected,
		"element":str(action.get("element",preload("res://scripts/game_data.gd").enemy_def(str(enemy["type"])).get("element","none"))),
		"range":int(status_range(enemy,action).get("range",0)),"amount":engine._target_loss_amount(losses),"target_losses":losses,"terrain_losses":terrain_losses,
		"impact_actor_keys":engine._target_loss_keys(losses),"triggered_traps":engine._triggered_traps_between(before,after),
		"guardian_board_after":board_snapshot(after),"surface":str(action.get("surface","rubble")),
		"spawned_enemies":spawned}

# Only explicitly authored board effects hold tiles. A bite, pounce or ordinary
# shot must remain the same live-target action used by the existing roster.
# Checking the verb also repairs old saved intents with over-broad commit flags.
static func authored_action(action: Dictionary) -> bool:
	return not shape(action).is_empty() or str(action.get("guardian_kind",""))=="crag_outcrop" or (str(action.get("type",""))=="summon_minions" and action.has("guardian_cap"))

static func has_authored_actions(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions",[]):
		if authored_action(action): return true
	return false

static func has_held_actions(intent: Dictionary) -> bool:
	for action: Dictionary in intent.get("actions",[]):
		if handles(action): return true
	return false

static func holds_path(intent: Dictionary) -> bool:
	if bool(intent.get("live_body",false)): return false
	for action: Dictionary in intent.get("actions",[]):
		if authored_action(action) and str(action.get("type","")) != "summon_minions": return true
	return false

static func board_snapshot(state: Dictionary) -> Dictionary:
	var snapshot: Dictionary = {}
	for key: String in ["enemies","player","illusions","terrain","traps","surfaces","guardian_braziers","umbra","loot"]:
		if state.has(key): snapshot[key] = state[key].duplicate(true) if state[key] is Dictionary or state[key] is Array else state[key]
	return snapshot

static func living_helpers(state: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for helper: Dictionary in state.get("enemies",[]):
		if int(helper.get("hp",0))>0 and bool(helper.get("guardian_helper",false)):
			var id: String = str(helper["type"])
			result[id] = int(result.get(id,0))+1
	return result

static func missing_helpers(state: Dictionary, enemy: Dictionary) -> Array[String]:
	var definition: Dictionary = Library.for_guardian(str(enemy.get("type","")))
	var missing: Array[String]
	var living: Dictionary = living_helpers(state)
	for id: String in definition.get("helpers",[]):
		if int(living.get(id,0))>0: living[id]=int(living[id])-1
		else: missing.append(id)
	return missing

static func choose_intent(state: Dictionary, enemy: Dictionary, intents: Array, cycle: int) -> Dictionary:
	var choice: Dictionary = intents[posmod(cycle,intents.size())]
	if str(choice.get("id",""))=="call_the_spark" and missing_helpers(state,enemy).is_empty(): return intents[0]
	if str(choice.get("id",""))=="peal" and Surfaces.tiles(state,"electrified").is_empty(): return intents[0]
	if str(choice.get("id",""))=="upheaval" and objects(state,"crag_outcrop",int(enemy["id"])).size()>=2: return intents[1]
	return choice

static func with_reinforcements(state: Dictionary, enemy: Dictionary, intent: Dictionary) -> Dictionary:
	var missing: Array[String] = missing_helpers(state,enemy)
	var result: Dictionary = intent.duplicate(true)
	if missing.is_empty(): return result
	var id: String = missing[0]
	var cap: int = (Library.for_guardian(str(enemy["type"])).get("helpers",[]) as Array).count(id)
	for action: Dictionary in result.get("actions",[]):
		if str(action.get("type",""))=="summon_minions":
			if not bool(action.get("snuff_brazier",false)):
				action["minion_type"]=id
				action["guardian_cap"]=cap
				action["guardian_reinforcement"]=true
			return result
	# One replacement per revealed Guardian activation. A helper defeated after
	# this declaration buys a whole activation before a new summon is announced.
	result["actions"].append({"type":"summon_minions","minion_type":id,"count":1,"range":3,"guardian_cap":cap,"guardian_reinforcement":true})
	return result

static func status_range(enemy: Dictionary, action: Dictionary) -> Dictionary:
	if not action.has("range_status"): return action
	var adjusted: Dictionary = action.duplicate(true)
	adjusted["range"] = mini(int(action.get("maximum_range",99)),int(action.get("range",1))+int(enemy.get(str(action["range_status"]),0)))
	return adjusted

static func shape_tiles(engine: RefCounted, state: Dictionary, origin: Vector2i, direction: Vector2i, action: Dictionary) -> Array[Vector2i]:
	if shape(action) == "cross":
		var cross_tiles: Array[Vector2i]
		var lane: Dictionary = action.duplicate(true)
		lane["committed_shape"] = "line"
		for ray: Vector2i in Paths.DIRS_4:
			for tile: Vector2i in Patterns.footprint_shape(engine,state,origin,ray,lane):
				if not cross_tiles.has(tile): cross_tiles.append(tile)
		return cross_tiles
	if shape(action) == "ring": return Patterns.radial_shape(engine,state,origin,action)
	if shape(action) == "swept_path": return Patterns.swept_shape(engine,state,origin,action)
	if action.has("pattern_footprint"):
		return Patterns.footprint_shape(engine, state, origin, direction, action)
	var result: Array[Vector2i]
	var side := Vector2i(-direction.y,direction.x)
	var shape_id: String = shape(action)
	var width: int = int(action.get("guardian_width",3 if shape_id=="sweep" else 1))
	var reach: int = int(action.get("guardian_length",action.get("range",1)))
	for lane: int in range(-width/2,width/2+1):
		for distance: int in range(1,reach+1):
			var tile: Vector2i = origin+direction*distance+side*lane
			if not Paths.is_passable(state["grid"],tile): break
			if not engine.combat_line_of_sight(state,origin,tile): break
			if shape_id!="broken_line" or distance!=2: result.append(tile)
			if engine._terrain_index_at_tile(state,tile)>=0: break
	return result

static func pattern_approach(engine: RefCounted, state: Dictionary, index: int, intent: Dictionary, fallback: Dictionary) -> Dictionary:
	var pattern: Dictionary = {}
	var move_range: int = 0
	var retreat: bool = false
	for action: Dictionary in intent.get("actions",[]):
		if shape(action) in GEOMETRIC_SHAPES and pattern.is_empty(): pattern=action
		if str(action.get("type","")) in ["move_toward","move_away"]:
			move_range=int(action.get("range",0))
			retreat=str(action["type"])=="move_away"
	if pattern.is_empty(): return fallback
	var enemy: Dictionary = state["enemies"][index]
	var target: Dictionary = engine._closest_enemy_target(state,enemy)
	var target_tile: Vector2i = target.get("pos",state["player"]["pos"])
	var best_score: int = -999999
	var best: Dictionary = fallback.duplicate(true)
	for record: Dictionary in engine._enemy_actual_path_records(state,enemy,move_range):
		var arrival: Dictionary = engine._enemy_attack_route_prediction(state,enemy,record,move_range)
		if not bool(arrival.get("survives",true)) or arrival.get("destination",record["tile"])!=record["tile"]: continue
		var origin: Vector2i = record["tile"]
		for direction: Vector2i in Paths.DIRS_4:
			var geometry: Dictionary = status_range(enemy,pattern)
			geometry["_resolved_path"] = record["path"]
			var shape: Array[Vector2i] = shape_tiles(engine,state,origin,direction,geometry)
			var nearest: int = 99
			var score: int = -int(record.get("trap_cost",0))*60-int(record.get("steps",0))*3
			for tile: Vector2i in shape:
				var distance: int = Paths.manhattan(tile,target_tile)
				nearest=mini(nearest,distance)
				if distance==0: score+=1000
				elif distance<=2: score+=35-10*distance
				if str(pattern.get("type",""))=="surface" and not Surfaces.has_surface(state,tile,str(pattern.get("surface",""))): score+=3
				for ally: Dictionary in state["enemies"]:
					if int(ally.get("hp",0))>0 and int(ally["id"])!=int(enemy["id"]) and ally["pos"]==tile: score-=30
			score-=nearest*20
			score+=(1 if retreat else -1)*Paths.manhattan(origin,target_tile)*4
			if score<=best_score: continue
			best_score=score
			best["path"]=tiles(record["path"])
			best["destination"]=origin
			best["target"]=target
			best["target_key"]=str(target.get("key",""))
			best["target_tile"]=target_tile
			best["declared_direction"]=direction
	return best

static func component_distance(state: Dictionary, origin: Vector2i, target: Vector2i) -> int:
	var nearest: int = 999
	for tile: Vector2i in Surfaces.connected_component(state,origin): nearest=mini(nearest,Paths.manhattan(tile,target))
	return nearest

static func connector_tiles(engine: RefCounted, state: Dictionary, origin: Vector2i, target: Vector2i, action: Dictionary) -> Array[Vector2i]:
	var reach: int = int(action.get("range",3))
	var count: int = int(action.get("guardian_count",1))
	var seeds: Array[Vector2i]
	for tile: Vector2i in Surfaces.tiles(state,"electrified"):
		if Paths.manhattan(origin,tile)<=reach and engine.combat_line_of_sight(state,origin,tile): seeds.append(tile)
	if seeds.is_empty(): seeds.append(origin)
	var best: Array[Vector2i]
	var best_score: int = -999999
	var goals: Array[Vector2i] = tiles([target])
	for direction: Vector2i in Paths.DIRS_4: goals.append(target+direction)
	for seed: Vector2i in seeds:
		for goal: Vector2i in goals:
			var path: Array[Vector2i] = Paths.find_path(state["grid"],seed,goal,engine._occupied_terrain_tiles(state),true)
			if path.is_empty(): continue
			var new_tiles: Array[Vector2i]
			var endpoint: Vector2i = seed
			for tile: Vector2i in path:
				if Paths.manhattan(origin,tile)>reach or not engine.combat_line_of_sight(state,origin,tile): break
				if not Surfaces.is_conductive(state,tile):
					if new_tiles.size()>=count: break
					new_tiles.append(tile)
				endpoint=tile
			if new_tiles.is_empty(): continue
			var score: int = -Paths.manhattan(endpoint,target)*30+new_tiles.size()*2
			if endpoint==target: score+=100
			if Surfaces.is_conductive(state,seed): score+=10
			if score>best_score:
				best_score=score
				best=new_tiles
	return best

static func coordination_score(engine: RefCounted, state: Dictionary, enemy: Dictionary, destination: Vector2i, target: Vector2i) -> int:
	if str(state.get("guardian_id","")).is_empty() or not bool(enemy.get("guardian_helper",false)): return 0
	var covered: Dictionary = {}
	var reserved: Dictionary = {}
	for ally: Dictionary in state.get("enemies",[]):
		if int(ally.get("hp",0))<=0 or int(ally["id"])==int(enemy["id"]): continue
		var plan: Dictionary = (ally.get("intent",{}) as Dictionary).get("committed_plan",{})
		for tile: Vector2i in plan.get("path",[]): reserved[tile]=true
		for tile: Vector2i in plan.get("projected_attack",[]): covered[tile]=true
		for direction: Vector2i in Paths.DIRS_4: covered[Vector2i(ally["pos"])+direction]=true
	var score: int = -80 if reserved.has(destination) else 0
	for direction: Vector2i in Paths.DIRS_4:
		var escape: Vector2i = target+direction
		if Paths.is_passable(state["grid"],escape) and not covered.has(escape) and Paths.manhattan(destination,escape)<=1: score+=12
	# A second helper approaches from another side of the target instead of
	# stacking behind its sibling and leaving the opposite escape lane empty.
	for ally: Dictionary in state.get("enemies",[]):
		if int(ally.get("hp",0))<=0 or not bool(ally.get("guardian_helper",false)) or int(ally["id"])==int(enemy["id"]): continue
		var mine: Vector2i = destination-target
		var theirs: Vector2i = Vector2i(ally["pos"])-target
		if mine.x*theirs.x+mine.y*theirs.y<0: score+=8
	return score
