extends RefCounted
const Combat = preload("res://scripts/combat_engine.gd")
const Areas = preload("res://scripts/boss_area_rules.gd")
const Data = preload("res://scripts/game_data.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const PROOF_NULL_SAVE_PATH: String = "user://area01-null-combat.save"
const PROOF_PARTIAL_SAVE_PATH: String = "user://area01-partial-plan.save"
const PROOF_WALL_SAVE_PATH: String = "user://area05-pending-thornwall.save"
const Badges = preload("res://scripts/intent_badges.gd")
const PROOF_SOURCE := Vector2i(5, 3)
const PROOF_HERO := Vector2i(2, 4)
const PROOF_DISPLACEMENT := Vector2i(0, 1)
const PROOF_HEALTH: int = 2000

static func fixture(id: String) -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	state["battlefield_rule"] = {}
	state["terrain"] = []
	state["surfaces"] = {}
	state["traps"] = []
	state["player"]["pos"] = PROOF_HERO
	state["player"]["hp"] = PROOF_HEALTH
	state["player"]["max_hp"] = PROOF_HEALTH
	var enemy: Dictionary = state["enemies"][0]
	enemy["type"] = id
	enemy["pos"] = PROOF_SOURCE
	enemy["hp"] = PROOF_HEALTH
	enemy["max_hp"] = PROOF_HEALTH
	enemy["intent"] = {}
	state["enemies"] = [enemy]
	return state

static func declare(engine: RefCounted, state: Dictionary, move: String) -> void:
	var enemy: Dictionary = state["enemies"][0]
	var intent: Dictionary = engine._intent_by_id(Data.enemy_def(str(enemy["type"]))["intents"], move).duplicate(true)
	for action: Dictionary in intent["actions"]:
		if str(action["type"]) == "cinder_marks": action["declared_tiles"] = engine.DragonCombatRules.meteor_tiles(engine, state, enemy, int(action["count"]))
		if str(action["type"]) == "lightning_strikes": action["declared_tiles"] = engine.DragonCombatRules.storm_tiles(engine, state, enemy, int(action["count"]))
	enemy["intent"] = Guardians.commit(engine, state, 0, intent) if str(enemy["type"]) != "briar_weaver" else Areas.freeze(engine, state, enemy, intent)

static func same(a: Array, b: Array) -> bool:
	return a.size() == b.size() and a.all(func(tile: Vector2i) -> bool: return b.has(tile))

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	for id: String in Areas.MOVES:
		for move: String in Areas.MOVES[id]:
			var state: Dictionary = fixture(id)
			declare(engine, state, move)
			var raw: Dictionary = engine._intent_by_id(Data.enemy_def(id)["intents"],move)
			var rows: Array = preload("res://scripts/pre_battle_inspection_view.gd").move_rows(raw, {"type": id})
			var raw_marked: bool = false
			for row: Array in rows:
				if row.any(func(token: Dictionary) -> bool: return str(token.get("icon", "")) == "marked"): raw_marked = true
			expect.call(raw_marked == (Areas.kind_for(id,move) == Areas.FIXED_KIND), id+"/"+move+" raw pre-battle row shares its targeting keyword")
			var intent: Dictionary = state["enemies"][0]["intent"]
			expect.call(Areas.has_held(intent), id+"/"+move+" freezes its area at declaration")
			var serialized: Dictionary = bytes_to_var(var_to_bytes(state))
			Areas.migrate_combat(serialized)
			expect.call(serialized == state, id+"/"+move+" current save migration is idempotent")
			state["enemies"][0]["pos"] += PROOF_DISPLACEMENT
			state["player"]["pos"] += Vector2i.RIGHT
			for action: Dictionary in intent["actions"]:
				if not Areas.held(action): continue
				var shown: Array[Vector2i] = Areas.at_anchor(action, state["enemies"][0]["pos"])
				shown = engine._vector2i_values(shown.filter(func(tile: Vector2i) -> bool: return engine._tile_is_passable(state, tile)))
				expect.call(same(Areas.strike_tiles(engine, state, action), shown), id+"/"+move+" preserves its held stamp and targeting kind")
				if shown.is_empty(): continue
				var blocked: Dictionary = state.duplicate(true)
				blocked["grid"][shown[0].y][shown[0].x] = "wall"
				var remaining: Array[Vector2i] = Areas.strike_tiles(engine, blocked, action)
				expect.call(remaining.size() == shown.size()-1 and not remaining.has(shown[0]), id+"/"+move+" only the newly impassable mark becomes inert")
				var legacy: Dictionary = state.duplicate(true)
				for held: Dictionary in legacy["enemies"][0]["intent"]["actions"]:
					if not Areas.held(held): continue
					held["declared_tiles"] = Areas.shown(held)
					held.erase(Areas.FIELD)
				Areas.migrate_combat(legacy)
				expect.call(same(Areas.pending_tiles(legacy["enemies"][0]["intent"]), Areas.pending_tiles(intent)), id+"/"+move+" old save uses stored marks after displacement")
	_detonations(engine, expect)
	_skybreak(engine, expect)
	_burrow(engine, expect)
	_followup(engine, expect)
	_rest_before_due(engine, expect)
	_pending_wall(engine, expect)
	_inert_wall_mark(engine, expect)
	_nullable_combat_save(expect)
	_stamp_saves(engine, expect)
	_planless_save(engine, expect)
	_marked_identity(engine, expect)
	_resolved_forecast_stamp(engine, expect)

static func _detonations(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("vyraketh")
	var fuel := Vector2i(3, 4)
	state["enemies"][0]["cinder_tiles"] = engine._vector2i_values([fuel])
	Ground.place(state, fuel, "fire", {"actor_kind":"enemy","actor_id":1})
	declare(engine, state, "crownfire")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var shown: Array[Vector2i] = Areas.shown(action)
	Ground.place(state, fuel, "ice", {"actor_kind":"player"})
	Ground.place(state, Vector2i(6, 5), "fire", {"actor_kind":"player"})
	var hp: int = state["player"]["hp"]
	state = engine._resolve_enemy_action(state, 0, action)
	expect.call(shown.has(state["player"]["pos"]) and state["player"]["hp"] == hp-int(action["damage"]), "Crownfire strikes its original union even after all fuel is removed")
	expect.call(Ground.has_surface(state, fuel, "ice") and Ground.has_surface(state, Vector2i(6,5), "fire"), "Crownfire preserves replacements and later Fire")
	state = fixture("tharokh")
	state["terrain"].append({"id":"original", "kind":"crag_outcrop", "owner_kind":"enemy", "owner_id":1, "pos":fuel, "hp":4})
	declare(engine, state, "faultline")
	action = state["enemies"][0]["intent"]["actions"][0]
	state["terrain"].clear()
	state["terrain"].append({"id":"later", "kind":"crag_outcrop", "owner_kind":"enemy", "owner_id":1, "pos":Vector2i(6,5), "hp":4})
	hp = state["player"]["hp"]
	state = engine._resolve_enemy_action(state, 0, action)
	expect.call(state["player"]["hp"] == hp-int(action["damage"]) and state["terrain"][0]["hp"] == 4, "Faultline keeps its blast and leaves later rock for the next announcement")

static func _skybreak(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("zekarion")
	declare(engine, state, "skybreak")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	action[Areas.FIELD] = engine._vector2i_values([Vector2i(3,4)])
	for tile: Vector2i in [Vector2i(2,4),Vector2i(3,4)]: Ground.place(state, tile, "electrified")
	var hp: int = state["player"]["hp"]
	state = engine._resolve_enemy_action(state, 0, action)
	expect.call(state["player"]["hp"] == hp, "Skybreak never conducts to an unmarked neighbor")

static func _burrow(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("burrow_grub")
	state["enemies"][0]["burrowed"] = true
	state["enemies"][0]["erupt_tile"] = state["player"]["pos"]
	state["terrain"].append({"pos":state["player"]["pos"],"hp":4})
	var action: Dictionary = Data.enemy_def("burrow_grub")["intents"][1]["actions"][0]
	var hp: int = state["player"]["hp"]
	state = engine._resolve_enemy_action(state, 0, action)
	expect.call(state["player"]["hp"] == hp-int(action["damage"]), "A blocked Grub still hits its marked occupant")
	expect.call(state["enemies"][0]["pos"] != state["player"]["pos"], "A blocked Grub can relocate its surfacing body")
	expect.call(state["player"]["pos"] == Vector2i(3,4), "A relocated Grub preserves its existing adjacent push on the marked victim")

static func _followup(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("vyraketh")
	declare(engine, state, "kindle_ground")
	var actions: Array = state["enemies"][0]["intent"]["actions"]
	expect.call(actions.size() == 2 and Areas.held(actions[0]) and not Areas.held(actions[1]), "Meteorfall retains the separate live ranged row")
	var hero: Vector2i = state["player"]["pos"]
	for destination: Vector2i in [hero, hero+Vector2i.UP, hero+Vector2i.DOWN]:
		var trial: Dictionary = state.duplicate(true)
		trial["player"]["pos"] = destination
		var expected: Array[Vector2i] = engine._enemy_direct_attack_threat_tiles(trial, 0, actions[1], {})
		var hp: int = trial["player"]["hp"]
		trial = engine._resolve_enemy_action(trial, 0, actions[1])
		expect.call(expected.has(destination) == (trial["player"]["hp"] < hp), "Meteorfall's separate shot uses the live hovered hero tile")

static func _rest_before_due(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("tharokh")
	declare(engine, state, "worldspine_claw")
	for actor: Dictionary in state["turn_queue"]:
		if actor.get("kind") == "enemy": actor["time"] = 1000
	var intent: Dictionary = state["enemies"][0]["intent"]
	var preview: Dictionary = state.duplicate(true)
	preview["player"]["pos"] += Vector2i.UP
	var display: Dictionary = Badges.build(engine, state, preview)
	var red: Array[Vector2i]
	for threat: Dictionary in display["threats"]:
		if bool(threat.get("area_announced", false)): red.assign(threat["tiles"])
	expect.call(same(red, Areas.announced_tiles(preview["enemies"][0], engine, preview)), "Held red survives a hovered destination before the source is due")

static func _pending_wall(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("briar_weaver")
	declare(engine, state, "thornwall")
	var enemy: Dictionary = state["enemies"][0]
	var marks: Array[Vector2i] = Areas.pending_tiles(enemy["intent"])
	state = engine._resolve_enemy_action(state,0,enemy["intent"]["actions"][0])
	enemy = state["enemies"][0]
	enemy["intent"] = engine._intent_by_id(Data.enemy_def("briar_weaver")["intents"],"lash_of_thorns")
	expect.call(same(Areas.announced_tiles(enemy), marks), "Thornwall keeps red while its delayed ground waits through a different intent")
	preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(state)
	state["player"]["pos"] = Vector2i(1,1)
	enemy["pos"] = Vector2i(6,6)
	_pending_wall_save(engine, state, marks, expect)
	state = engine.BrambleRules.begin_turn(engine,state,0)
	var raised: Array[Vector2i]
	for terrain: Dictionary in state["terrain"]: raised.append(terrain["pos"])
	expect.call(same(raised, marks) and not state["enemies"][0].has("upheaval_pending"), "Thornwall raises only its marked ground after both actors move")

static func _pending_wall_save(engine: RefCounted, state: Dictionary, marks: Array[Vector2i], expect: Callable) -> void:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path(PROOF_WALL_SAVE_PATH)
	for legacy: bool in [false, true]:
		var trial: Dictionary = state.duplicate(true)
		var label: String = "Legacy pending Thornwall" if legacy else "Current pending Thornwall"
		if legacy: trial["enemies"][0]["upheaval_pending"].erase("area_fixed")
		var saved: Dictionary = {"combat_state": trial}
		expect.call(Store.save_run_state(saved), label + " saves through the production store")
		var loaded: Dictionary = Store.load_saved_run()
		expect.call(loaded == saved, label + " loads with its original state")
		expect.call(Store.save_run_state(loaded) and Store.load_saved_run() == saved, label + " remains equal after re-saving")
		if not loaded.has("combat_state"): continue
		var resumed: Dictionary = loaded["combat_state"]
		var weaver: Dictionary = resumed["enemies"][0]
		var badges: Array[Vector2i] = preload("res://scripts/boss_area_marks.gd").tiles(resumed, weaver)
		expect.call(not marks.is_empty() and badges == marks and Areas.announced_tiles(weaver) == marks, label + " warns on the original marked tiles after both actors moved")
		resumed = engine.BrambleRules.begin_turn(engine, resumed, 0)
		expect.call(resumed == engine.BrambleRules.begin_turn(engine, trial, 0), label + " resumes identically to uninterrupted combat")
		var raised: Array[Vector2i]
		for terrain: Dictionary in resumed["terrain"]: raised.append(terrain["pos"])
		expect.call(raised == marks, label + " raises outcrops only on the original marked tiles")
	Store.clear_saved_run()
	Store.set_run_storage_path(previous)

static func _inert_wall_mark(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("briar_weaver")
	declare(engine,state,"thornwall")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var marks: Array[Vector2i] = Areas.shown(action)
	expect.call(not marks.is_empty(), "Wall proof has announced marks")
	if marks.is_empty(): return
	state["grid"][marks[0].y][marks[0].x] = "wall"
	var before: Dictionary = state.duplicate(true)
	state = engine._resolve_enemy_action(state,0,action)
	var effect: Dictionary = engine._enemy_action_step(before,state,0,action)
	expect.call((effect["tiles"] as Array).size() == marks.size()-1 and not (effect["tiles"] as Array).has(marks[0]), "Thornwall's real mark receipt excludes its newly impassable tile")

static func _nullable_combat_save(expect: Callable) -> void:
	var previous: String = Store._run_storage_path
	Store.set_run_storage_path(PROOF_NULL_SAVE_PATH)
	var saved: Dictionary = {"mode":"room", "combat_units_schema":1, "surface_rules_version":5, "combat_state":null}
	expect.call(Store.save_run_state(saved), "Legacy nullable combat checkpoint saves through the production store")
	var loaded: Dictionary = Store.load_saved_run()
	expect.call(str(loaded.get("mode", "")) == "room" and loaded.has("combat_state") and loaded["combat_state"] == null, "A non-combat legacy checkpoint remains loadable without inventing a fight")
	Store.set_run_storage_path(previous)

static func _stamp_saves(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("tharokh")
	declare(engine, state, "bedrock_breath")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][0]
	var original: Array[Vector2i] = Areas.shown(action)
	for field: String in ["area_targeting", "area_source_id", "area_announcement_origin", "area_planned_origin", "area_origin_basis"]: action.erase(field)
	state["enemies"][0]["pos"] += PROOF_DISPLACEMENT
	Areas.migrate_combat(state)
	expect.call(action["area_origin_basis"] == "stored_announcement" and Areas.relative(action), "Round-0 save rebuilds relative stamp from stored origin")
	expect.call(Areas.at_anchor(action, action["area_planned_origin"]) == original, "Stored relative footprint remains exactly its announced shape")
	for field: String in ["area_targeting", "area_source_id", "area_announcement_origin", "area_planned_origin", "area_origin_basis", "declared_origin"]: action.erase(field)
	action["declared_origin"] = null
	state["enemies"][0]["intent"].erase("committed_plan")
	Areas.migrate_combat(state)
	expect.call(action["area_origin_basis"] == "current_position_fallback" and action["area_planned_origin"] == state["enemies"][0]["pos"], "Originless save treats stored tiles as announced from current source")
	var translated: Array[Vector2i] = Areas.at_anchor(action, state["enemies"][0]["pos"] + PROOF_DISPLACEMENT)
	expect.call(translated == engine._vector2i_values(original.map(func(tile: Vector2i) -> Vector2i: return tile + PROOF_DISPLACEMENT)), "Originless resumed stamp translates without reshaping")
	var originless: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)
	expect.call(not originless["state"].is_empty(),"A legacy nullable origin resumes through actual combat after fallback planning")
	state = fixture("tharokh")
	declare(engine,state,"worldspine_claw")
	state["enemies"][0]["pos"] += PROOF_DISPLACEMENT
	state["enemies"][0]["intent"]["committed_plan"].erase("path")
	action = state["enemies"][0]["intent"]["actions"][1]
	for field: String in ["area_targeting","area_source_id","area_announcement_origin","area_planned_origin","area_origin_basis"]: action.erase(field)
	original = Areas.shown(action)
	var file := FileAccess.open(PROOF_PARTIAL_SAVE_PATH,FileAccess.WRITE)
	file.store_var({"mode":"combat","combat_units_schema":1,"surface_rules_version":5,"combat_state":state})
	file.close()
	state = Store._load_run_dictionary(PROOF_PARTIAL_SAVE_PATH)["combat_state"]
	action = state["enemies"][0]["intent"]["actions"][1]
	expect.call(action["area_origin_basis"] == "current_position_fallback" and action["area_planned_origin"] == state["enemies"][0]["pos"], "A moving legacy intent without its start path cannot invent an announcement position from its destination")
	var resumed: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)
	var claw: Array = resumed["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("intent_id","")) == "worldspine_claw" and str(step.get("action_type","")) == "aoe")
	expect.call(claw.size()==1 and same(claw[0]["tiles"],original),"Partial legacy plan resumes and strikes its stored stamp from the fallback origin")

static func _planless_save(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture("tharokh")
	declare(engine,state,"worldspine_claw")
	var action: Dictionary = state["enemies"][0]["intent"]["actions"][1]
	var original: Array[Vector2i] = Areas.shown(action)
	var direction: Vector2i = action["declared_direction"]
	for field: String in ["area_targeting","area_source_id","area_announcement_origin","area_planned_origin","area_origin_basis"]: action.erase(field)
	state["enemies"][0]["pos"] += PROOF_DISPLACEMENT
	state["enemies"][0]["intent"].erase("committed_plan")
	var file := FileAccess.open(PROOF_PARTIAL_SAVE_PATH,FileAccess.WRITE)
	file.store_var({"mode":"combat","combat_units_schema":1,"surface_rules_version":5,"combat_state":state})
	file.close()
	state = Store._load_run_dictionary(PROOF_PARTIAL_SAVE_PATH)["combat_state"]
	var enemy: Dictionary = state["enemies"][0]
	expect.call(enemy["intent"].has("committed_plan"),"Planless legacy relative move seals a saved-board movement offset before resumed input")
	action = enemy["intent"]["actions"][1]
	var path: Array[Vector2i] = engine._vector2i_values(enemy["intent"]["committed_plan"]["path"])
	expect.call(action["area_origin_basis"] == "current_position_fallback" and action["area_announcement_origin"] == enemy["pos"],"Planless legacy move records the explicit current-position fallback")
	expect.call(same(Areas.announced_tiles(enemy,engine,state),original) and action["declared_direction"] == direction,"Rebuilt movement preserves the saved tiles and direction rather than rebuilding their geometry")
	var hovered: Dictionary = state.duplicate(true)
	hovered["player"]["pos"] += Vector2i.RIGHT
	var forecast: Dictionary = engine.enemy_intent_plan(hovered,0)
	var projected: Array[Vector2i] = engine._vector2i_values(forecast["path"])
	expect.call(projected == engine._vector2i_values(path.slice(0,projected.size())),"A resumed hover can block the stored route but cannot re-aim it")
	var resumed: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)
	var effects: Array = resumed["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("intent_id","")) == "worldspine_claw" and str(step.get("action_type","")) == "aoe")
	expect.call(effects.size()==1 and same(effects[0]["tiles"],original),"Planless legacy fight resumes through its newly sealed move and strikes its stored stamp")

static func _marked_identity(engine: RefCounted, expect: Callable) -> void:
	var icons = preload("res://scripts/action_icon_library.gd")
	var marks = preload("res://scripts/boss_area_marks.gd")
	for id: String in Areas.MOVES:
		for move: String in Areas.MOVES[id]:
			var state: Dictionary = fixture(id)
			declare(engine, state, move)
			for action: Dictionary in state["enemies"][0]["intent"]["actions"]:
				if not Areas.held(action): continue
				var row: Array = icons.tokens_for_action(action)
				var labeled: bool = row.any(func(token: Dictionary) -> bool: return str(token.get("icon", "")) == "marked")
				expect.call(labeled == Areas.fixed(action), id+"/"+move+" Marked keyword identifies only fixed action rows")
				if Areas.fixed(action): expect.call(preload("res://scripts/grimoire_library.gd").entry_ids_for_actions([action]).has("keyword:marked"), id+"/"+move+" discovers the same existing Marked glossary entry")
			var enemy: Dictionary = state["enemies"][0]
			var badges: Array[Vector2i] = marks.tiles(state, enemy)
			expect.call(badges.is_empty() == (Areas.RELATIVE.get(id, []) as Array).has(move) or Areas.pending_tiles(enemy["intent"]).is_empty(), id+"/"+move+" only fixed areas carry tile badges")
			state["meteor_marks"] = [{"tiles": badges.duplicate()}]
			expect.call(marks.tiles(state, enemy).is_empty(), "Existing meteor badges are never doubled")
	var sky: Dictionary = fixture("zekarion")
	declare(engine,sky,"skybreak")
	var board := preload("res://scripts/combat_board_view.gd").new()
	board.combat_state = sky
	var details: Dictionary = preload("res://scripts/board_tile_tooltip.gd").mark_entries(board)
	for tile: Vector2i in marks.tiles(sky,sky["enemies"][0]):
		expect.call(details.has(tile) and var_to_str(details[tile]).contains(preload("res://scripts/glossary.gd").definition("marked")), "Pointer and controller tile detail share the existing Marked definition")
	board.free()

static func _resolved_forecast_stamp(engine: RefCounted, expect: Callable) -> void:
	var red = preload("res://scripts/pass_forecast_red_tiles.gd")
	var discs = preload("res://scripts/pass_forecast_discs.gd")
	var state: Dictionary = fixture("ashen_reaver")
	declare(engine,state,"hooked_sweep")
	var intent: Dictionary = state["enemies"][0]["intent"]
	var path: Array = intent["committed_plan"]["path"]
	expect.call(path.size()>1,"Resolved-stamp proof has an announced approach")
	if path.size()<2: return
	var rest: Dictionary = Badges.build(engine,state,state)
	var future: Dictionary = state.duplicate(true)
	future["terrain"].append({"id":"area01_forecast_cover","pos":path[1],"hp":PROOF_HEALTH,"max_hp":PROOF_HEALTH})
	for actor: Dictionary in future["turn_queue"]:
		if str(actor.get("kind","")) == "enemy": actor["time"] = int(future.get("initiative_clock",0))
	var unchanged: Dictionary = future.duplicate(true)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(red.schedule(engine,future),true)
	var summary: Dictionary = red.summary_fields(phase)
	summary.merge(preload("res://scripts/pass_forecast_repeats.gd").summary_fields(phase))
	var key: String = "enemy_%d" % int(future["enemies"][0]["id"])
	var receipt: Dictionary = summary.get("relative_red_areas",{}).get(key,{})
	expect.call(not receipt.is_empty(),"Production loss cursor retains the resolved relative stamp")
	if receipt.is_empty(): return
	expect.call(receipt["anchor"] == future["enemies"][0]["pos"],"Known future cover stops the body at its real source position")
	var revision: int = int(state.get("activation_seq",0))
	var adjusted: Dictionary = discs.apply(rest,discs.record(summary,revision),revision,true)
	var shown: Array[Vector2i]
	var original: Array[Vector2i]
	for threat: Dictionary in adjusted["threats"]:
		if bool(threat.get("area_announced",false)) and str(threat["key"]) == key: shown.assign(threat["tiles"])
	for threat: Dictionary in rest["threats"]:
		if bool(threat.get("area_announced",false)) and str(threat["key"]) == key: original.assign(threat["tiles"])
	expect.call(same(shown,receipt["tiles"]) and not same(shown,original),"Rest/hover disc codec slides red to the resolved arrival rather than its earlier plan")
	expect.call(future == unchanged and not future.has(Areas.FORECAST_RECEIPT),"Forecast receipts never mutate the live source or save state")
	var actual: Dictionary = engine.resolve_enemy_turn_with_steps(future,0)
	expect.call(not actual["state"].has(Areas.FORECAST_RECEIPT),"Actual combat never acquires a forecast-only receipt")
	var effects: Array = actual["steps"].filter(func(step: Dictionary) -> bool: return str(step.get("intent_id","")) == "hooked_sweep" and str(step.get("action_type","")) == "aoe")
	expect.call(effects.size()==1 and same(effects[0]["tiles"],receipt["struck_tiles"]),"Recorded forecast contact equals the actual stopped-body strike")
