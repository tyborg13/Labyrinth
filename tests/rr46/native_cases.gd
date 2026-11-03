extends RefCounted

const Sweep = preload("depth_sweep.gd")
const Paths = preload("res://scripts/path_utils.gd")
const Primitives = preload("paint_primitives.gd")
const Composite = preload("paint_composite.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const MOTION_BOUNDS_PADDING_TILES: float = 1.0
const PROP_BEHIND_FROM := Vector2i(3,3)
const PROP_BEHIND_TO := Vector2i(2,4)
const CORNER_FROM := Vector2i(3,5)
const CORNER_TO := Vector2i(2,6)
const INVENTORY_PATH: String = "res://tests/rr46/native_inventory.json"
const EXEMPT_REASONS := ["no_kind_on_board","no_legal_ground_side","no_projected_bounds_on_side","production_culls_kind"]

static func boards() -> Array[Dictionary]:
	var result: Array[Dictionary]
	# Director's final native scope. Production boundary walls are culled on
	# both boards; earth's tier-3/revision-7 interior props supplement fire.
	for choice: Dictionary in [{"biome":"fire","tier":1,"revision":6},{"biome":"earth","tier":3,"revision":7}]:
		var spec: Dictionary = Sweep.Fixture.room_spec(choice["biome"],choice["tier"])
		spec["section_map_layout_revision"] = choice["revision"]
		var layout: Dictionary = Sweep.Rooms.new().generate_room(Sweep.Fixture.FIXTURE_SEED,spec,Vector2i.UP)
		var battle: Dictionary = Sweep.Combat.new().create_combat(Sweep.Fixture.FIXTURE_SEED,layout,{"hp":Sweep.PROOF_PLAYER_HP,"max_hp":Sweep.PROOF_PLAYER_HP})
		result.append({"label":"%s_t%d_r%d"%[choice["biome"],choice["tier"],choice["revision"]],"battle":battle,"scene_props":layout.get("scene_props",[])})
	return result

static func origins(battle: Dictionary) -> Array[Vector2i]:
	var result: Array[Vector2i]
	var grid: Array = battle["grid"]
	for y: int in range(grid.size()):
		for x: int in range(grid[y].size()):
			var tile := Vector2i(x,y)
			if Paths.is_passable(grid,tile) and str(grid[y][x])!="void": result.append(tile)
	return result

static func _route(id: String, clip: String, from: Vector2i, to: Vector2i, mandatory: bool) -> Dictionary:
	return {"id":id,"clip":clip,"from":from,"to":to,"direction":to-from,"mandatory":mandatory}

static func routes(battle: Dictionary) -> Array[Dictionary]:
	var result: Array[Dictionary]
	var grid: Array = battle["grid"]
	var legal: Array[Vector2i] = origins(battle)
	var chosen: Dictionary = {}
	# Required facings remain small. The exhaustive legal search below supplies
	# additional routes until every inventory-required painted class overlaps.
	for direction: Vector2i in Sweep.DIRECTIONS:
		for origin: Vector2i in legal:
			if Paths.is_passable(grid,origin+direction):
				var id: String = "move_%d_%d_%d_%d"%[origin.x,origin.y,direction.x,direction.y]
				result.append(_route(id,"move",origin,origin+direction,true))
				chosen[id]=true
				break
	# The diagonal midpoint sits one ground row in front of the rear pillar,
	# on its projected X. This targets stone/body overlap rather than torch glow.
	if Paths.is_passable(grid,PROP_BEHIND_FROM) and Paths.is_passable(grid,PROP_BEHIND_TO):
		var witness: String = "move_%d_%d_%d_%d"%[PROP_BEHIND_FROM.x,PROP_BEHIND_FROM.y,PROP_BEHIND_TO.x-PROP_BEHIND_FROM.x,PROP_BEHIND_TO.y-PROP_BEHIND_FROM.y]
		result.append(_route(witness,"move",PROP_BEHIND_FROM,PROP_BEHIND_TO,true))
		chosen[witness]=true
	# Review regression: the equal-depth diagonal must never acquire the
	# off-segment pillar host (3,6), including Mimic frame 23/48.
	if Paths.is_passable(grid,CORNER_FROM) and Paths.is_passable(grid,CORNER_TO):
		var witness: String = "move_3_5_-1_1"
		result.append(_route(witness,"move",CORNER_FROM,CORNER_TO,true))
		chosen[witness]=true
	var staged: Dictionary = battle.duplicate(true)
	staged["enemies"][0]["type"] = "slag_mortar"
	if Sweep.Fixture.stage_keep_distance(staged):
		var path: Array[Vector2i] = Sweep.Rules.retreat_path(Sweep.Combat.new(),staged,staged["enemies"][0])
		for index: int in range(1,path.size()): result.append(_route("retreat_%d"%index,"keep_distance",path[index-1],path[index],true))
	result.append(_route("death_%d_%d"%[legal[0].x,legal[0].y],"death",legal[0],legal[0],true))
	for origin: Vector2i in legal:
		for direction: Vector2i in Sweep.DIRECTIONS:
			if not Paths.is_passable(grid,origin+direction): continue
			var id: String = "move_%d_%d_%d_%d"%[origin.x,origin.y,direction.x,direction.y]
			if not chosen.has(id): result.append(_route(id,"move",origin,origin+direction,false))
		if origin!=legal[0]: result.append(_route("death_%d_%d"%[origin.x,origin.y],"death",origin,origin,false))
	return result

static func decorate_frame(battle: Dictionary, shown: Dictionary, actor: Dictionary, route: Dictionary, start: Vector2, end: Vector2, frame: int, phase: float) -> void:
	if route["clip"]=="death":
		actor.merge({"death_animation":true,"death_frame":frame,"death_progress":phase},true)
		shown["death_animation_units"]=[actor]
		battle["enemies"]=[]
		# Same presentation boundary RunScene uses before submitting the board.
		preload("res://scripts/cutout_context.gd").apply_to_presentation(battle,shown)
	else:
		shown.merge({"unit_draw_tiles":{"enemy_1":route["to"]},"unit_footprint_world_positions":{"enemy_1":start.lerp(end,phase)}},true)
		Sweep.Action.movement_frame(shown,actor["type"],"enemy_1",start,end,route["direction"],phase,false)

static func displayed_ground(board: Control, unit: Dictionary, shown: Dictionary) -> Vector2:
	# Independent of production's depth/routing helper. Project the protected
	# forward track onto the route, never the artwork's nearest-facing axis.
	var type: String = unit["type"]
	var motion: Dictionary = shown.get(type+"_motion",{}).get("enemy_1",{})
	if motion.get("clip","")!="move" or not shown.get("unit_texture_origins",{}).has("enemy_1"):
		return board.world_position_for_unit_origin(unit,unit["pos"])
	var view: Dictionary = preload("res://scripts/enemy_cutout_facing.gd").direction_for_delta(motion["direction"])
	var data: Dictionary = Sweep.Action.data_for(type)
	var forward: float = 0.0
	for track: Dictionary in data["view_tracks"][view["facing"]]["move"]:
		if track["bone"]=="root" and track["channel"]=="forward_px":
			forward=Sweep.Action.Motion.value_at(track["keys"],motion["phase"])
			if track["forward_mode"]=="fraction_of_step": forward*=motion["step_distance_px"]
	var origin: Vector2 = shown["unit_texture_origins"]["enemy_1"]
	var path: Vector2 = board._tile_step_offset(motion["direction"])
	return origin+path.normalized()*forward

static func class_requirements(board: Control, unit: Dictionary, objects: Array[Dictionary], candidates: Array[Dictionary]) -> Dictionary:
	var result: Dictionary = {}
	var center: Vector2 = board.world_position_for_tile(unit["pos"])
	var relative: Rect2 = board._unit_texture_draw_rect(unit,center)
	relative.position -= center
	relative = relative.grow(board._tile_width()*MOTION_BOUNDS_PADDING_TILES)
	for kind: String in ["floor","wall","prop"]:
		var matching: Array[Dictionary]
		for object: Dictionary in objects:
			if object["kind"]==kind: matching.append(object)
		for side: String in ["front","behind"]:
			var possible_side: bool = false
			var possible_bounds: bool = false
			for route: Dictionary in candidates:
				if matching.is_empty() or possible_bounds: break
				var start: Vector2 = board.world_position_for_tile(route["from"])
				var end: Vector2 = board.world_position_for_tile(route["to"])
				var swept := Rect2(start+relative.position,relative.size).merge(Rect2(end+relative.position,relative.size))
				for object: Dictionary in matching:
					if possible_bounds: break
					for point: Vector2 in [start,end]:
						var actor: Dictionary = {"id":"actor","kind":"actor","tie_rank":4,"ground_x":point.x,"ground_y":point.y}
						if Composite.front(object,actor)!=(side=="front"): continue
						possible_side = true
						if swept.intersects(object["bounds"]): possible_bounds = true
			var reason: String = "" if possible_bounds else ("no_kind_on_board" if matching.is_empty() else ("no_legal_ground_side" if not possible_side else "no_projected_bounds_on_side"))
			if kind=="wall" and matching.is_empty() and not board.OUTER_WALL_RENDERING_ENABLED:
				for row: Array in board.combat_state["grid"]:
					if row.has("wall"): reason="production_culls_kind"
			result[kind+"_"+side] = {"required":possible_bounds,"reason":reason,"kind_count":matching.size(),"detail":"OUTER_WALL_RENDERING_ENABLED=false; boundary wall tiles excluded by _should_render_tile" if reason=="production_culls_kind" else ""}
	return result

static func export_inventory(owner: Node) -> Dictionary:
	var board := Sweep.Board.new()
	board.size = Vector2(1920,1080)
	owner.add_child(board)
	board.set_process(false)
	var result: Dictionary = {"schema":3,"sampling":{"move_stride":2,"move_midpoint_radius_frames":1,"death_stride":1,"retain_every":10,"max_seconds":300,"max_bytes":250000000},"boards":{},"actors":{},"source_hashes":{},"exempt_reasons":EXEMPT_REASONS}
	for type: String in Sweep.Types.TYPES:
		result["actors"][type] = {"move_frames":Sweep.Action.frames_for(type,"move"),"death_frames":Death.frames(type),"death_timing":{"clip_seconds":Death.authored_clip_seconds(type),"dissolve_seconds":Death.authored_dissolve_seconds(type)},"scaled_death_timing":{"clip_seconds":Death.clip_seconds(type),"dissolve_seconds":Death.dissolve_seconds(type),"total_seconds":Death.total_seconds(type),"scale":Death.duration_scale(type),"frame_seconds":Death.frame_seconds(type)}}
	for item: Dictionary in boards():
		var candidates: Array[Dictionary] = routes(item["battle"])
		var exported_routes: Dictionary = {}
		for route: Dictionary in candidates:
			exported_routes[route["id"]] = {"clip":route["clip"],"from":[route["from"].x,route["from"].y],"to":[route["to"].x,route["to"].y],"direction":[route["direction"].x,route["direction"].y],"mandatory":route["mandatory"]}
		var record: Dictionary = {"routes":exported_routes,"requirements":{},"drawn_primitives":[],"culled_tiles":[],"selection_reason":"Required fire props/floor board" if item["label"]=="fire_t1_r6" else "Earth tier-3 revision-7 prop sprites and opposing ground-Y routes; real boundary walls are unavailable because production culls them"}
		for type: String in Sweep.Types.TYPES:
			var battle: Dictionary = item["battle"].duplicate(true)
			var unit: Dictionary = {"key":"enemy_1","id":1,"type":type,"role":"enemy","pos":candidates[0]["from"],"hp":10,"max_hp":10}
			battle["enemies"] = [unit]
			battle["umbra"]["vision_bonus"] = Sweep.Combat.UMBRA_UNLIMITED_RADIUS
			board.set_combat_state(battle,[],[],Vector2i(-1,-1),"","",{},{},{"board_framing_mode":"combat","ambient_time_seconds":0.0,"scene_props":item["scene_props"]})
			record["requirements"][type] = class_requirements(board,unit,Primitives.catalog(board),candidates)
		if not candidates.is_empty():
			for object: Dictionary in Primitives.catalog(board):
				record["drawn_primitives"].append({"id":object["id"],"kind":object["kind"],"plane":object["plane"],"ground_x":object["ground_x"],"ground_y":object["ground_y"],"tie_rank":object["tie_rank"]})
			var grid: Array = item["battle"]["grid"]
			for y: int in range(grid.size()):
				for x: int in range(grid[y].size()):
					var tile := Vector2i(x,y)
					if not board._should_render_tile(board._display_tile_id(str(grid[y][x]),tile),tile,grid): record["culled_tiles"].append({"tile":[x,y],"kind":str(grid[y][x]),"reason":"OUTER_WALL_RENDERING_ENABLED=false"})
		result["boards"][item["label"]] = record
	board.free()
	var sources: Array[String]
	sources.assign(["tests/rr46/depth_proof_contract.json","tests/rr46/id_pass.gd","tests/rr46/native_archive.gd","tests/rr46/native_cases.gd","tests/rr46/paint_primitives.gd","tests/rr46/paint_composite.gd","tests/rr46/paint_checks.gd","tests/rr46/paint_board.gd","tests/rr46/depth_probe.gd","scripts/combat_board_view.gd","scripts/room_generator.gd","scripts/special_encounter_library.gd","scripts/path_utils.gd","scripts/warband_combat_rules.gd","scripts/maquette_cutout_runtime/action.gd","scripts/maquette_cutout_runtime/death.gd","tools/warband_inspection.gd"])
	sources.append_array(["scripts/maquette_cutout_runtime/board_depth.gd","tests/rr47/route_probe.gd","tests/rr47/route_proof_contract.json","tests/rr47/verify_route.py"])
	for type: String in Sweep.Types.TYPES:
		sources.append("assets/units/"+type+"_cutout/integration.json")
		sources.append(Sweep.Action.Presentation.asset_directory(type).path_join("compiled_motion.json").trim_prefix("res://"))
	for path: String in sources: result["source_hashes"][path] = FileAccess.get_sha256("res://"+path)
	return result
