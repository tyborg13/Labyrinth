extends "res://tools/atk13/audit.gd"
## Same real-scene rest/PASS/every-destination matrix as atk-13, generalized
## to natural boss rooms. No substituted intents, tuning or synthetic roster.
const AreaObserver = preload("res://tools/atk13/area01/observed_engine.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
var area_target: String = OS.get_environment("AREA01_TARGET")
var area_at_start: Dictionary = {}
func _initialize() -> void:
	oracle = AreaObserver.new()
	super._initialize()
func _enter_cantor(run: Dictionary) -> void:
	var selected: Dictionary = {}
	var run_engine: RefCounted = scene.get("_run_engine")
	# Same natural standard-room sampling convention as encounter_sweep.layout:
	# a prior cleared combat prevents the guided first fight replacing the roster.
	if area_target in ["burrow_grub", "briar_weaver"]:
		run = run_engine.create_new_run(hunt_seed, Store.default_data())
		if hunt_health > 0:
			run["player_max_hp"] = hunt_health
			run["player_hp"] = hunt_health
		for prior: Dictionary in run["rooms"].values():
			if str(prior.get("type", "")) == "combat": prior["cleared"] = true; break
	for room: Dictionary in run["rooms"].values():
		if area_target in ["burrow_grub", "briar_weaver"]: Graph.resolve_mystery(run,room)
		if str(room.get("guardian_id", "")) == area_target or (str(room.get("type", "")) == "boss" and str(room.get("boss_id", "")) == area_target):
			selected = room
			break
		if area_target in ["burrow_grub", "briar_weaver"] and str(room.get("type", "")) == "combat" and not bool(room.get("cleared", false)):
			preload("res://scripts/encounter_tables.gd").record_room_entry(run,room)
			var layout: Dictionary = run_engine._combat_layout_for_room(room, PROOF_ENTRY_DIRECTION, run)
			for enemy: Dictionary in layout.get("enemies", []):
				if str(enemy["type"]) == area_target: selected = room
			if not selected.is_empty(): break
	if selected.is_empty():
		_finish("target_unavailable")
		return
	var prepared: Dictionary = run.duplicate(true)
	var room: Dictionary = Graph.room(prepared, selected["coord"])
	room["cleared"] = false
	room["revealed"] = true
	room["visited"] = true
	room["sealed"] = false
	prepared["current_room"] = room["coord"]
	prepared["current_room_layout"] = run_engine._display_layout_for_room(int(run["seed"]), room, PROOF_ENTRY_DIRECTION)
	prepared["mode"] = "pre_battle"
	prepared["pre_battle_pending"] = true
	prepared["pre_battle_travel_dir"] = PROOF_ENTRY_DIRECTION
	prepared["combat_state"] = {}
	Graph.refresh_knowledge(prepared)
	prepared = run_engine.begin_pre_battle_combat(prepared)
	scene.call("_load_run_state", prepared)
	_apply_hunt_health()
	entered = true
	settle_frames = SETTLE_FRAMES
	samples.store_line(JSON.stringify({"kind":"area01_encounter", "target":area_target,"seed":hunt_seed,"depth":room["depth"],"coord":str(room["coord"])}))
func _check(engine: RefCounted, committed: Dictionary, mode: String, tile: Vector2i, point_id: String) -> Dictionary:
	var result: Dictionary = super._check(engine, committed, mode, tile, point_id)
	var announcements: Dictionary = {}
	for enemy: Dictionary in committed.get("enemies", []):
		var key: String = "enemy_%d" % int(enemy["id"])
		var plan: Dictionary = engine.enemy_intent_plan(committed, engine._enemy_index_for_id(committed, int(enemy["id"])))
		var displayed: Dictionary = area_at_start.get(key,{})
		announcements[key] = {"intent": str(enemy.get("intent", {}).get("id", "")), "areas":displayed.get("tiles",Areas.announced_tiles(enemy, engine, committed)), "original":Areas.pending_tiles(enemy.get("intent", {})), "rest_red": point_rest.keys(), "anchor": displayed.get("area_forecast_anchor",plan.get("destination", enemy["pos"]))}
	result["area01_announcements"] = announcements
	return result

func _audit_decision_point() -> void:
	scene.set("_hovered_board_tile",INVALID)
	scene.call("_pass_preview_summary")
	scene.call("_refresh_stage_view")
	area_at_start.clear()
	for threat: Dictionary in scene.get("board_view").get("presentation").get("threats_at_rest",{}).get("threats",[]):
		if bool(threat.get("area_announced",false)): area_at_start[str(threat["key"])] = threat.duplicate(true)
	super._audit_decision_point()

# atk-13's baseline reader excludes all unseen tiles. area-01 additionally
# paints already-announced marks in darkness, through the production selector.
func _board_red(board: Control) -> Dictionary:
	var result: Dictionary = super._board_red(board)
	var rest: Dictionary = board.get("presentation").get("threats_at_rest", {})
	for threat: Dictionary in rest.get("threats", []):
		if not bool(threat.get("area_announced", threat.get("area_fixed", false))): continue
		for tile: Vector2i in threat.get("tiles", []):
			if not preload("res://scripts/threat_tiles.gd").visible_at(board, tile): continue
			var owners: Array = result.get(tile, [])
			if not owners.has(threat["key"]): owners.append(threat["key"])
			result[tile] = owners
	var preview: Dictionary = scene.call("_enemy_intent_preview_state", scene.call("_board_display_state"))
	var badges: Dictionary = scene.get("_intent_badges").presentation_for_state(scene.get("_combat_engine"),
		scene.get("_combat_state"), preview, "", Callable(scene, "_surface_preview_information_state").bind(preview))
	var committed: Dictionary = scene.get("_combat_state")
	var marks: Dictionary = scene.get("_rest_pass_disc_marks") if is_same(committed, preview) else scene.call("_hover_red_forecast")
	var allowed: Dictionary = {}
	for threat: Dictionary in badges.get("threats", []):
		var owner: String = str(threat["key"])
		if not allowed.has(owner): allowed[owner] = []
		var resolved: Dictionary = marks.get("relative_red_areas", {}).get(owner, {})
		var signature: Array = threat.get("area_signature", [])
		var tiles: Array = resolved["tiles"] if not signature.is_empty() and resolved.get("signature", []) == signature else threat["tiles"]
		allowed[owner].append_array(tiles)
	var excess: Array[Dictionary]
	for tile: Vector2i in result:
		for owner: String in result[tile]:
			if owner == "battlefield_rule" or owner.begins_with("lob:"): continue
			if not allowed.get(owner, []).has(tile): excess.append({"owner": owner, "tile": tile})
	samples.store_line(JSON.stringify({"kind": "announced_red_sample", "unannounced_red": excess}))

	return result
