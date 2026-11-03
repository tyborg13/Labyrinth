extends SceneTree

const Sweep = preload("depth_sweep.gd")
const Cases = preload("native_cases.gd")
const Primitives = preload("paint_primitives.gd")
const Composite = preload("paint_composite.gd")
const PaintBoard = preload("paint_board.gd")
const Checks = preload("paint_checks.gd")
const IDs = preload("id_pass.gd")
const Archive = preload("native_archive.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const OUTPUT: String = "user://probes/rr46-depth"
const SETTLE_FRAMES: int = 2
const PROOF_ACTOR_HP: int = 10
const OCCLUDER_BATCH_SIZE: int = 8
const MAX_ROUTES: int = 16
var output: String = OUTPUT
var boards: Dictionary = {}
var targets: Dictionary = {}
var slots: Array[Dictionary]
var primitives: Array[Dictionary]
var inventory: Dictionary
var report: Dictionary
var archive: RefCounted
var run_started: int = Time.get_ticks_usec()
var jobs_started: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func option(args: PackedStringArray, key: String) -> String:
	return args[args.find(key)+1] if args.has(key) else ""

func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--output"): output = option(args,"--output")
	if args.has("--list-only"):
		inventory = Cases.export_inventory(root)
		var path: String = output if args.has("--output") else "user://rr46/native_inventory.json"
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		FileAccess.open(path,FileAccess.WRITE).store_string(JSON.stringify(inventory,"\t"))
		print("RR46 NATIVE CASE INVENTORY: 2 boards; 20 jobs; 20 deaths; stride 2 move/retreat plus every midpoint neighbour, stride 1 death; "+path)
		quit(); return
	if DisplayServer.get_name()=="headless":
		printerr("RR46 ID occlusion requires the windowed visual probe runner"); quit(1); return
	inventory = JSON.parse_string(FileAccess.get_file_as_string(Cases.INVENTORY_PATH))
	for path: String in inventory["source_hashes"]:
		if FileAccess.get_sha256("res://"+path)!=inventory["source_hashes"][path]:
			printerr("Stale native inventory: "+path); quit(1); return
	var settings: Dictionary = preload("res://scripts/settings_store.gd").default_settings()
	settings["ui_scale"]=1.0; settings["display_mode"]="windowed"
	preload("res://scripts/settings_store.gd").apply_settings(settings,root,false)
	root.size=Checks.LOGICAL_SIZE; root.content_scale_size=Checks.LOGICAL_SIZE
	for mode: String in ["production","production_id","actor_mask"]:
		var target: Dictionary = _target(mode)
		boards[mode]=target["board"]; targets[mode]=target["target"]
	for _index: int in range(OCCLUDER_BATCH_SIZE): slots.append(_target("occluder_mask"))
	var preview := TextureRect.new()
	preview.texture=targets["production"].get_texture(); preview.size=Vector2(Checks.LOGICAL_SIZE)
	root.add_child(preview)
	var jobs: int = 0
	var failed: bool = false
	var base: String = output
	for item: Dictionary in Cases.boards():
		if args.has("--board") and item["label"]!=option(args,"--board"): continue
		for type: String in Sweep.Types.TYPES:
			if args.has("--actor") and type!=option(args,"--actor"): continue
			output=base if args.has("--board") and args.has("--actor") else base.path_join(item["label"]).path_join(type)
			if DirAccess.dir_exists_absolute(output) and not DirAccess.get_files_at(output).is_empty():
				printerr("Refusing to overwrite native evidence: "+output); quit(1); return
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
			await _job(item,type)
			jobs+=1; failed=failed or not report["errors"].is_empty()
	print("RR46 NATIVE ID DEPTH: %s (%d jobs)"%["FAIL" if failed or jobs==0 else "PASS",jobs])
	quit(1 if failed or jobs==0 else 0)

func _target(mode: String) -> Dictionary:
	var target := SubViewport.new()
	target.size=Checks.LOGICAL_SIZE; target.size_2d_override=Checks.LOGICAL_SIZE
	target.size_2d_override_stretch=true; target.transparent_bg=true
	target.canvas_item_default_texture_filter=root.canvas_item_default_texture_filter
	target.render_target_update_mode=SubViewport.UPDATE_DISABLED
	root.add_child(target)
	var board := PaintBoard.new()
	board.proof_mode=mode; board.size=Vector2(Checks.LOGICAL_SIZE)
	target.add_child(board); board.set_process(false)
	return {"board":board,"target":target}

func _submit(board: Control, target: SubViewport, battle: Dictionary, shown: Dictionary) -> void:
	board._idle_elapsed=0.0
	board.set_combat_state(battle,[],[],Vector2i(-1,-1),"","",{},{},shown)
	board.queue_redraw(); target.render_target_update_mode=SubViewport.UPDATE_ALWAYS

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await RenderingServer.frame_post_draw

func _base(item: Dictionary) -> Dictionary:
	return {"board_framing_mode":"combat","ambient_time_seconds":0.0,"idle_time_seconds":0.0,"scene_props":item["scene_props"]}

func _battle(item: Dictionary, type: String, pos: Vector2i) -> Dictionary:
	var battle: Dictionary = item["battle"].duplicate(true)
	battle["enemies"]=[{"key":"enemy_1","id":1,"role":"enemy","type":type,"pos":pos,"hp":PROOF_ACTOR_HP,"max_hp":PROOF_ACTOR_HP}]
	battle["umbra"]["vision_bonus"]=Sweep.Combat.UMBRA_UNLIMITED_RADIUS
	return battle

func _job(item: Dictionary, type: String) -> void:
	report={"schema":4,"native":true,"board":item["label"],"actor":type,"inventory_sha256":FileAccess.get_sha256(Cases.INVENTORY_PATH),"requirements":inventory["boards"][item["label"]]["requirements"][type],"selected_routes":[],"captures":[],"errors":[],"coverage":{},"primitives":[]}
	archive=Archive.new(output,report)
	if jobs_started==0: archive.started=run_started
	jobs_started+=1
	var candidates: Array[Dictionary] = Cases.routes(item["battle"])
	var battle: Dictionary = _battle(item,type,candidates[0]["from"])
	await _cache_primitives(battle,_base(item))
	if not archive.within_budget():
		report["errors"].append("Native proof budget exceeded during static cache")
		archive.write_report(); return
	# The first captured frame has the actor alone on its production layer.
	# This checks the actual ID render/readback path before any order assertions.
	await _sample(item,type,candidates[0],0,true)
	if not report["calibration"]["passed"]:
		report["errors"].append("ID calibration failed before sweep; inspect calibration ID maps")
		archive.write_report(); return
	for route: Dictionary in candidates:
		if not route["mandatory"]: continue
		if not archive.within_budget(): break
		await _capture_case(item,type,route)
	while not _coverage_complete() and archive.within_budget() and report["selected_routes"].size()<MAX_ROUTES:
		var best: Dictionary = _best_candidate(candidates)
		if best.is_empty(): break
		await _capture_case(item,type,best)
	for category: String in report["requirements"]:
		if report["requirements"][category]["required"] and int(report["coverage"].get(category,0))==0: report["errors"].append("No painted overlap for required class: "+category)
	archive.write_report()
	print("RR46 NATIVE JOB: %s/%s %s (%d samples; %.3f seconds; %d bytes)"%[item["label"],type,"PASS" if report["errors"].is_empty() else "FAIL",report["captures"].size(),report["cost"]["elapsed_seconds"],report["cost"]["bytes"]])

func _cache_primitives(battle: Dictionary, shown: Dictionary) -> void:
	for mode: String in boards: _submit(boards[mode],targets[mode],battle,shown)
	await _settle()
	for target: SubViewport in targets.values(): target.render_target_update_mode=SubViewport.UPDATE_DISABLED
	primitives=Primitives.catalog(boards["production"])
	var ids: Dictionary = {}
	for first: int in range(0,primitives.size(),OCCLUDER_BATCH_SIZE):
		if not archive.within_budget(): return
		var used: int = mini(OCCLUDER_BATCH_SIZE,primitives.size()-first)
		for index: int in range(used):
			slots[index]["board"].proof_occluder=primitives[first+index]
			_submit(slots[index]["board"],slots[index]["target"],battle,shown)
		await _settle()
		for index: int in range(used):
			var object: Dictionary = primitives[first+index]
			var source: Image = slots[index]["target"].get_texture().get_image()
			slots[index]["target"].render_target_update_mode=SubViewport.UPDATE_DISABLED
			var rect: Rect2i = source.get_used_rect()
			if not rect.has_area():
				object["image"]=Image.create(1,1,false,Image.FORMAT_RGBA8); object["offset"]=Vector2i.ZERO
			else:
				object["image"]=IDs.encode(source.get_region(rect),first+index+2); object["offset"]=rect.position
			object["texture"]=ImageTexture.create_from_image(object["image"])
			ids[object["id"]]=object
			report["primitives"].append({"id":object["id"],"kind":object["kind"],"plane":object["plane"],"ground_x":object["ground_x"],"ground_y":object["ground_y"],"tie_rank":object["tie_rank"],"offset":[object["offset"].x,object["offset"].y],"image":archive.save(object["image"],"primitive_"+object["id"]+".png")})
	boards["production_id"].proof_ids=ids

func _coverage_complete() -> bool:
	for category: String in report["requirements"]:
		if report["requirements"][category]["required"] and int(report["coverage"].get(category,0))==0: return false
	return true

func _best_candidate(candidates: Array[Dictionary]) -> Dictionary:
	var best: Dictionary = {}
	var score: float = 0.0
	var board: Control = boards["production"]
	for route: Dictionary in candidates:
		if route["clip"]=="death" or report["selected_routes"].has(route["id"]): continue
		var point: Vector2 = board.world_position_for_tile(route["from"]).lerp(board.world_position_for_tile(route["to"]),0.5)
		var trial: float = 0.0
		for object: Dictionary in primitives:
			var category: String = object["kind"]+("_front" if object["ground_y"]>point.y else "_behind")
			if not report["requirements"][category]["required"] or int(report["coverage"].get(category,0))>0: continue
			var actor_bounds: Rect2 = board._unit_texture_draw_rect({"type":report["actor"],"key":"enemy_1"},point)
			var overlap: Rect2 = actor_bounds.intersection(Rect2(object["offset"],object["image"].get_size()))
			trial+=overlap.get_area()
		if trial>score: score=trial; best=route
	return best

func _capture_case(item: Dictionary, type: String, route: Dictionary) -> void:
	report["selected_routes"].append(route["id"])
	var death: bool = route["clip"]=="death"
	var count: int = inventory["actors"][type]["death_frames" if death else "move_frames"]
	for frame: int in IDs.indices(count,death):
		if not archive.within_budget(): report["errors"].append("Native proof budget exceeded"); return
		await _sample(item,type,route,frame,false)
	archive.write_report()

func _sample(item: Dictionary, type: String, route: Dictionary, frame: int, calibration: bool) -> void:
	var death: bool = route["clip"]=="death"
	var contract: Dictionary = inventory["actors"][type]
	var count: int = contract["death_frames" if death else "move_frames"]
	var phase: float = float(frame)/maxi(1,count-1) if death else float(frame+1)/count
	var battle: Dictionary = _battle(item,type,route["from"])
	var unit: Dictionary = battle["enemies"][0].duplicate(true)
	var shown: Dictionary = _base(item)
	var primary: Control = boards["production"]
	# Submit the new board before querying its layout-dependent endpoints.
	_submit(primary,targets["production"],battle,shown)
	var start: Vector2 = primary.world_position_for_tile(route["from"])
	var end: Vector2 = primary.world_position_for_tile(route["to"])
	Cases.decorate_frame(battle,shown,unit,route,start,end,frame,phase)
	for mode: String in ["production","actor_mask"]: _submit(boards[mode],targets[mode],battle,shown)
	await _settle()
	for mode: String in ["production","actor_mask"]: targets[mode].render_target_update_mode=SubViewport.UPDATE_DISABLED
	var colour: Image = targets["production"].get_texture().get_image()
	var own_full: Image = targets["actor_mask"].get_texture().get_image()
	var local: Rect2 = primary._unit_texture_draw_rect(unit,primary._unit_center(unit))
	# Dissolve wisps can leave the source sprite's rectangle; include their full
	# authored effect canvas, never a pixel-derived endpoint.
	if death:
		for effect: Control in boards["actor_mask"]._enemy_shadow_dissolve_effects_by_key.values(): local=local.merge(effect.expanded_rect())
	var crop: Rect2i = Checks.capture_rect(local,primary.get_global_transform_with_canvas(),Vector2(Checks.LOGICAL_SIZE),colour.get_size()).intersection(Rect2i(Vector2i.ZERO,colour.get_size()))
	if colour.get_size()!=Checks.LOGICAL_SIZE or not crop.has_area():
		report["errors"].append("Invalid logical frame size or empty transformed actor bounds")
		if calibration: report["calibration"]={"passed":false,"row":{}}
		return
	var actor_image: Image = IDs.encode(own_full.get_region(crop),IDs.ACTOR_CODE)
	var point: Vector2 = Cases.displayed_ground(primary,unit,shown)
	var actor: Dictionary = {"id":"actor","kind":"actor","plane":1,"tie_rank":4,"ground_x":point.x,"ground_y":point.y,"offset":crop.position,"image":actor_image,"texture":ImageTexture.create_from_image(actor_image)}
	boards["production_id"].proof_ids["actor"]=actor
	boards["production_id"].proof_calibration=calibration
	_submit(boards["production_id"],targets["production_id"],battle,shown)
	# Cached commands on every retained ID layer must see the new actor texture.
	for layer: Control in boards["production_id"]._scene_render_layers: layer.queue_redraw()
	await _settle()
	var actual: Image = targets["production_id"].get_texture().get_image()
	targets["production_id"].render_target_update_mode=SubViewport.UPDATE_DISABLED
	var layers: Array[Dictionary]
	var masks: Dictionary = {}
	for category: String in Checks.CATEGORIES: masks[category]=Image.create(Checks.LOGICAL_SIZE.x,Checks.LOGICAL_SIZE.y,false,Image.FORMAT_RGBA8)
	if not calibration:
		for object: Dictionary in primitives:
			layers.append(object)
			var category: String = object["kind"]+("_front" if Composite.front(object,actor) else "_behind")
			masks[category].blit_rect_mask(object["image"],object["image"],Rect2i(Vector2i.ZERO,object["image"].get_size()),object["offset"])
	layers.append(actor)
	var expected: Image = Composite.compose(Checks.LOGICAL_SIZE,Color.TRANSPARENT,layers,"encoded_straight",crop)
	var timing: Dictionary = contract["death_timing"] if death else {}
	var checked: Dictionary = Checks.inspect(actual,expected,own_full,masks,crop,timing,phase,0)
	var row: Dictionary = {"route_id":route["id"],"clip":route["clip"],"frame":frame,"phase":phase,"direction":[route["direction"].x,route["direction"].y],"terminal_absence":Checks.fully_dissolved(timing,phase),"capture_size":[colour.get_width(),colour.get_height()],"crop_rect":[crop.position.x,crop.position.y,crop.size.x,crop.size.y],"painted":checked,"calibration":calibration,"actor_ground":[point.x,point.y],"composite_order":[],"clock":{}}
	for layer: Dictionary in Composite.ordered(layers): row["composite_order"].append(layer["id"])
	if death: row["clock"]={"authored":contract["death_timing"],"scaled":contract["scaled_death_timing"],"progress":phase,"clip_phase":Death.clip_phase(type,phase),"dissolve_phase":Death.dissolve_phase(type,phase),"scaled_elapsed_seconds":phase*Death.total_seconds(type),"presentation_elapsed_seconds":frame*roundi(Death.frame_seconds(type)*1000000.0)/1000000.0,"hold_seconds":Death.frames(type)*roundi(Death.frame_seconds(type)*1000000.0)/1000000.0,"authored_elapsed_seconds":phase*(Death.authored_clip_seconds(type)+Death.authored_dissolve_seconds(type))}
	var failed: bool = not checked["errors"].is_empty()
	var name: String = "%s_%s_%s_f%03d"%[item["label"],type,"calibration" if calibration else route["id"],frame]
	var first_last: bool = frame==0 or frame==count-1 or (not death and absf(float(frame+1)-float(count)*0.5)<=1.0)
	var evidence: bool = calibration or failed or report["captures"].size()%IDs.RETAIN_EVERY==0 or first_last
	row["evidence"]=evidence; row["frame_required"]=calibration or failed or first_last
	row["frame_file"]=archive.save(colour,name+"_frame.png") if row["frame_required"] else ""
	for field: String in ["crop","actual_id","expected_id","actor_mask"]: row[field]=""
	if evidence:
		row["crop"]=archive.save(colour.get_region(crop),name+"_crop.png")
		row["actual_id"]=archive.save(actual.get_region(crop),name+"_actual_id.png")
		row["expected_id"]=archive.save(expected.get_region(crop),name+"_expected_id.png")
		row["actor_mask"]=archive.save(own_full.get_region(crop),name+"_actor_mask.png")
	if calibration:
		report["calibration"]={"passed":not failed and checked["painted_errors"]==0,"row":row}
	else:
		report["captures"].append(row)
		for error: String in checked["errors"]: report["errors"].append(name+": "+error)
		for category: String in checked["occluders"]: report["coverage"][category]=int(report["coverage"].get(category,0))+checked["occluders"][category]["overlap_pixels"]
