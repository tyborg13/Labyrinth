extends RefCounted
## bos-03 integration contracts use actual Guardian layouts and production beats.
const Combat = preload("res://scripts/combat_engine.gd")
const Guardians = preload("res://scripts/guardian_library.gd")
const Fixtures = preload("res://tests/suites/guardian_suite.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const BeatTests = preload("res://tests/suites/battlefield_rules_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/battlefield_rules/analytics.gd")
const Measurement = preload("res://tools/guardian_rules_measurement_engine.gd")
const SAVE_PATH: String = "user://bos-03-legacy.save"
const TEST_FIRE_TILE := Vector2i(4,5)
const TEST_SHADOW_HERO_TILE := Vector2i(4,5)
const TEST_SHADOW_SOURCE_TILE := Vector2i(4,1)
const TEST_HIDDEN_SHADE_TILE := Vector2i(1,5)
const TEST_CHOIR_SOURCE_TILE := Vector2i(1,1)
const TEST_CHOIR_HERO_TILE := Vector2i(7,7)
const COMMITTED_ACTOR_FIXTURE: Dictionary = {
	"positions":[Vector2i(7,7),Vector2i(4,2),Vector2i(7,6)],
	"player_pos":Vector2i(4,5),"third_charge":2,"kill_damage":1000,
	"intent":{"id":"qa18_committed_actor","time":5,"actions":[{"type":"move_toward","range":2},{"type":"melee","range":1,"damage":3,"committed_shape":"line","range_status":"charge"}]}
}

static func acceptance() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/bos04_guardian_acceptance.json"))

static func run(expect: Callable) -> void:
	committed_actor_after_removal(expect)
	var engine := Combat.new()
	var fixture := Fixtures.new()
	for info: Dictionary in Guardians.DEFINITIONS.values():
		var id: String = info["id"]
		var state: Dictionary = fixture.guardian_fixture(id)
		var instance: Dictionary = state.get("battlefield_rule",{})
		for key: String in ["rule","cadence","dials","sentence"]:
			expect.call(instance.get(key) == acceptance()[id][key],id+" pinned acceptance "+key)
		expect.call(instance.get("rule","") == Rules.instance_for(id)["rule"] and int(instance.get("source",{}).get("id",-1))==int(state["enemies"][0]["id"]),id+" installs its enemy-owned instance from data")
		expect.call(Rules.error_for(state,instance).is_empty() and not instance.has("at_half_health"),id+" has valid flat Guardian dials")
		for travel: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
			var opening: Dictionary = fixture.guardian_fixture(id,2,travel)
			for index: int in range(info["helpers"].size()):
				var expected: Vector2i = Guardians.oriented_tile({"player_start":opening["player"]["pos"]},Vector2i(2 if index==0 else 6,3))
				expect.call(opening["enemies"][index+1]["type"]==info["helpers"][index] and opening["enemies"][index+1]["pos"]==expected,id+" helper starts in its oriented authored slot")
		# Populate each beat with its ordinary fuel before comparing public output.
		match id:
			"ashen_reaver": Surfaces.place(state,TEST_FIRE_TILE,"fire",{"actor_kind":"enemy","actor_id":1})
			"rimejaw":
				for index: int in [-1,1]:
					var unit: Dictionary = state["player"] if index < 0 else state["enemies"][index]
					Surfaces.place(state,unit["pos"],"ice")
					state = engine._surface_contact(state,"player" if index < 0 else "enemy",-1 if index < 0 else int(unit["id"]),engine.INVALID_TILE,true)
			"storm_cantor": Surfaces.place(state,state["player"]["pos"],"electrified")
			"last_lamplighter":
				state["guardian_braziers"] = []
				state["umbra"] = {"stage":"heart","vision_bonus":0,"stage_reduction":0}
				state["player"]["pos"] = TEST_SHADOW_HERO_TILE
				state["enemies"][0]["pos"] = TEST_SHADOW_SOURCE_TILE
				state["enemies"][1]["pos"] = TEST_HIDDEN_SHADE_TILE
		var after: Dictionary = BeatTests.resolve_and_compare(engine,state,expect)
		# Adapter consumes the same saved fired records as append-only analytics.
		var adapter := Measurement.new()
		after[Measurement.METRICS] = {"helper_kills":0,"summons":0,"beats_fired":0,"beat_damage_to_hero":0,"beat_damage_to_enemies":0,"sequence":0}
		adapter.combat_outcome(after)
		expect.call(int(adapter.final_metrics["beats_fired"])==1,id+" measurement counts only one committed beat")
		if id=="rimejaw":
			expect.call(int(after["player"]["freeze"])==1 and int(after["enemies"][1]["freeze"])==1,"Rimejaw zero-damage beat Freezes Chilled hero and helper")
			expect.call(after["player"]["hp"]==state["player"]["hp"] and after["enemies"][1]["hp"]==state["enemies"][1]["hp"],"Rimejaw zero-damage beat loses no HP")
		if id=="gallows_roc": expect.call(after["enemies"][0]["pos"]==state["enemies"][0]["pos"] and engine._force_actor_anchored(state,"enemy",1),"Roc holds Anchored in its own wind")
		if id=="last_lamplighter":
			expect.call(after["enemies"][0]["pos"]==state["enemies"][0]["pos"],"Lamplighter never Shadowsteps")
			expect.call(after["enemies"][1]["pos"]!=state["enemies"][1]["pos"],"Hidden Wick Shade steps one tile toward the hero")
		if id=="craghide": _groundsplit(engine,fixture,after,expect)
		_cadence(engine,fixture,id,expect)
		_legacy_save(engine,fixture,id,expect)
	_initiative(fixture,expect)
	_renames(engine,fixture,expect)
	_authored_summons(engine,fixture,expect)
	_choir(engine,fixture,expect)

static func _choir(engine: RefCounted, fixture: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture.fixture("",[TEST_CHOIR_SOURCE_TILE])
	state["enemies"][0]["type"]="storm_cantor"
	state["player"]["pos"]=TEST_CHOIR_HERO_TILE
	var intent: Dictionary = Data.enemy_def("storm_cantor")["intents"][0].duplicate(true)
	intent["actions"].pop_front()
	var icons = preload("res://scripts/action_icon_library.gd")
	expect.call(icons.plain_text_for_rows([icons.tokens_for_guardian_rule(intent["actions"][0])]).contains("%d linked tiles" % int(intent["actions"][0]["guardian_count"])),"Choir badge text reads the authored linked-tile count")
	state["enemies"][0]["intent"]=preload("res://scripts/guardian_combat_rules.gd").commit(engine,state,0,intent)
	var shown: Array = engine.enemy_intent_plan(state,0)["projected_attack"]
	expect.call(shown.size()==int(intent["actions"][0]["guardian_count"]),"Lay the Choir forecasts its authored charged-tile count on open ground")
	var result: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)
	for tile: Vector2i in shown: expect.call(Surfaces.has_surface(result["state"],tile,"electrified"),"Every shown Choir tile becomes Electrified")
	for step: Dictionary in result["steps"]:
		if bool(step.get("guardian_mechanic",false)) and str(step.get("surface",""))=="electrified":
			expect.call(step["tiles"]==shown,"Choir playback uses the exact announced tiles")
	# The distant empty fixture above missed the short-path bug: in actual
	# arenas the connector reaches the hero after only two or three new tiles.
	for travel: Vector2i in [Vector2i.ZERO,Vector2i.LEFT,Vector2i.RIGHT,Vector2i.DOWN]:
		var live: Dictionary = fixture.guardian_fixture("storm_cantor",2,travel)
		var forecast: Array = engine.enemy_intent_plan(live,0)["projected_attack"]
		var old_tiles: Array[Vector2i] = Surfaces.tiles(live,"electrified")
		var resolved: Dictionary = engine.resolve_enemy_turn_with_steps(live,0)
		var new_tiles: Array[Vector2i] = Surfaces.tiles(resolved["state"],"electrified")
		expect.call(forecast.size()==6 and new_tiles.size()-old_tiles.size()==6,"Choir charges six fresh tiles in real arena orientation "+str(travel))
		for tile: Vector2i in forecast:
			expect.call(not old_tiles.has(tile) and new_tiles.has(tile),"Choir's full-count forecast is fresh and resolves exactly")
		for step: Dictionary in resolved["steps"]:
			if bool(step.get("guardian_mechanic",false)) and str(step.get("surface",""))=="electrified":
				expect.call(step["tiles"]==forecast,"Full-count Choir playback matches the announced footprint")
	# Exhausted legal ground terminates below the budget without duplicates.
	var paths = preload("res://scripts/path_utils.gd")
	for tile: Vector2i in paths.diamond_tiles(TEST_CHOIR_SOURCE_TILE,20,state["grid"]):
		if paths.is_passable(state["grid"],tile): Surfaces.place(state,tile,"electrified")
	var exhausted: Array[Vector2i] = preload("res://scripts/guardian_combat_rules.gd").connector_tiles(engine,state,TEST_CHOIR_SOURCE_TILE,TEST_CHOIR_HERO_TILE,intent["actions"][0])
	expect.call(exhausted.is_empty(),"Choir does not repaint conductive ground when no fresh legal tile remains")

static func _groundsplit(engine: RefCounted, fixture: RefCounted, state: Dictionary, expect: Callable) -> void:
	var outcrops: Array[Dictionary] = preload("res://scripts/guardian_combat_rules.gd").objects(state,"crag_outcrop",1)
	expect.call(not outcrops.is_empty(),"Craghide's beat raises source-owned crag_outcrop terrain")
	for outcrop: Dictionary in outcrops: expect.call(int(outcrop["max_hp"])==2,"Craghide Outcrop health is two")
	fixture.set_cycle(engine,state,1)
	var quake: Array = engine.enemy_intent_plan(state,0)["projected_attack"]
	expect.call(not quake.is_empty(),"Groundsplit counts the rule's owned Outcrops")

static func _cadence(engine: RefCounted, fixture: RefCounted, id: String, expect: Callable) -> void:
	var state: Dictionary = fixture.guardian_fixture(id)
	var instance: Dictionary = state["battlefield_rule"]
	var pinned: Dictionary = acceptance()[id]["cadence"]
	var anchor: String = pinned["anchor"]
	var steps: Array[Dictionary]
	var count: int = int(pinned.get("every",1))
	for index: int in range(count):
		state = Rules.dispatch(engine,state,anchor,1,"peal" if id=="storm_cantor" else "",steps,index+1)
		expect.call(int(state["battlefield_rule"]["beats_fired"])==int(index==count-1),id+" fires on exactly its authored cadence")

static func _initiative(fixture: RefCounted, expect: Callable) -> void:
	for id: String in ["storm_cantor","gallows_roc"]:
		var state: Dictionary = fixture.guardian_fixture(id)
		var expected: Array = [11,19,12] if id=="storm_cantor" else [9,12,12]
		for index: int in range(3):
			expect.call(Combat.new()._enemy_base_initiative(state,state["enemies"][index])==int(expected[index]),id+" restores authored initiative for actor "+str(index))

static func _renames(engine: RefCounted, fixture: RefCounted, expect: Callable) -> void:
	var board := preload("res://scripts/combat_board_view.gd").new()
	for row: Array in [["rimejaw",2,"frostbite","Rime Bite"],["craghide",0,"upheaval","Crag Heave"]]:
		var state: Dictionary = fixture.guardian_fixture(row[0])
		state["umbra"]["vision_bonus"]=12
		fixture.set_cycle(engine,state,row[1])
		var intent: Dictionary = state["enemies"][0]["intent"]
		expect.call(intent["id"]==row[2] and intent["name"]==row[3],row[0]+" display rename preserves the saved and analytics id")
		expect.call(board._intent_display_name(intent)==row[3],row[0]+" badge/expanded tooltip title uses the renamed intent")
		expect.call(engine._enemy_intent_step_for_player(state,state["enemies"][0],intent)["intent_name"]==row[3],row[0]+" callout uses the renamed intent")
		# Grimoire discovery resolves the authored definition; no separate copied
		# Guardian intent-name catalogue exists to drift from this identity.
		preload("res://scripts/grimoire_library.gd").entry_ids_for_enemy_def(Data.enemy_def(row[0]))
		expect.call(Data.enemy_def(row[0])["intents"][row[1]]["name"]==row[3],row[0]+" Grimoire source definition uses the renamed intent")
	board.free()

static func _authored_summons(engine: RefCounted, fixture: RefCounted, expect: Callable) -> void:
	var state: Dictionary = fixture.guardian_fixture("storm_cantor")
	# A dead Tender must not rewrite Call the Spark into a Bell Tender summon.
	state["enemies"][1]["hp"]=0
	state["enemies"][2]["hp"]=0
	fixture.set_cycle(engine,state,3)
	var after: Dictionary = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	expect.call(after["enemies"].size()==4 and after["enemies"][3]["type"]=="lightning_wisp","Call the Spark returns only a Wisp, never the finite Tender")
	expect.call(int(after.get("pending_summon_card_plays",0))==1,"Authored Call the Spark still pays one Card Play")
	var wisp_cap: int = int(Data.enemy_def("storm_cantor")["intents"][3]["actions"][0]["guardian_cap"])
	for count: int in range(1,wisp_cap):
		fixture.set_cycle(engine,after,3)
		after = engine.resolve_enemy_turn_with_steps(after,0)["state"]
		expect.call(after["enemies"].size()==4+count and int(after.get("pending_summon_card_plays",0))==count+1,"Call the Spark fills its authored Wisp cap and pays per arrival")
	var size_at_cap: int = after["enemies"].size()
	fixture.set_cycle(engine,after,3)
	after = engine.resolve_enemy_turn_with_steps(after,0)["state"]
	expect.call(after["enemies"].size()==size_at_cap and int(after.get("pending_summon_card_plays",0))==wisp_cap,"Call the Spark neither summons nor pays at its authored cap")
	state = fixture.guardian_fixture("last_lamplighter")
	# Clear the initial helper so Snuff must arrive at either director cap.
	state["enemies"][1]["hp"]=0
	after = engine.resolve_enemy_turn_with_steps(state,0)["state"]
	expect.call(after["enemies"].size()==3 and int(after.get("pending_summon_card_plays",0))==1,"Snuff replaces a missing Shade and pays one Card Play")
	var shade_cap: int = int(Data.enemy_def("last_lamplighter")["intents"][0]["actions"][0]["guardian_cap"])
	for count: int in range(1,shade_cap):
		fixture.set_cycle(engine,after,0)
		after = engine.resolve_enemy_turn_with_steps(after,0)["state"]
		expect.call(after["enemies"].size()==3+count,"Snuff fills its authored Shade cap")
	size_at_cap = after["enemies"].size()
	fixture.set_cycle(engine,after,0)
	after = engine.resolve_enemy_turn_with_steps(after,0)["state"]
	expect.call(after["enemies"].size()==size_at_cap and int(after.get("pending_summon_card_plays",0))==shade_cap,"Snuff neither summons nor pays at its authored cap")

static func _legacy_save(engine: RefCounted, fixture: RefCounted, id: String, expect: Callable) -> void:
	var state: Dictionary = fixture.guardian_fixture(id)
	state.erase("battlefield_rule")
	var enemy: Dictionary = state["enemies"][0]
	if id=="rimejaw":
		fixture.set_cycle(engine,state,2)
		enemy = state["enemies"][0]
		enemy["intent"]["name"]="Frostbite"
	if id=="craghide":
		fixture.set_cycle(engine,state,0)
		enemy = state["enemies"][0]
		enemy["intent"]["name"]="Upheaval"
		enemy["intent"]["actions"].append({"type":"raise_terrain","count":2,"health":3,"guardian_kind":"crag_outcrop","range":4})
	if id=="storm_cantor":
		fixture.set_cycle(engine,state,1)
		enemy = state["enemies"][0]
		enemy["intent"]["actions"].append({"type":"ranged","range":4,"damage":6,"element":"lightning","guardian_shape":"conductor"})
	enemy["intent"]["actions"].append({"type":"summon_minions","minion_type":str(state["enemies"][1]["type"]),"guardian_reinforcement":true,"summon_origin":"guardian_replacement"})
	var intent_id: String = enemy["intent"]["id"]
	var held: Dictionary = enemy["intent"].get("committed_plan",{}).duplicate(true)
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	file.store_var({"combat_state":state}); file.close()
	var loaded: Dictionary = Store._load_run_dictionary(SAVE_PATH)["combat_state"]
	expect.call(loaded["enemies"][0]["intent"]["id"]==intent_id and not loaded.get("battlefield_rule",{}).is_empty(),id+" old mid-fight save loads with the same intent id and installed rule")
	expect.call(not str(loaded["enemies"][0]["intent"]).contains("guardian_reinforcement"),id+" old save drops automatic replacement payloads")
	if preload("res://scripts/guardian_combat_rules.gd").has_authored_actions(loaded["enemies"][0]["intent"]):
		expect.call(loaded["enemies"][0]["intent"].get("committed_plan",{})==held,id+" Continue preserves already announced held geometry")
	expect.call(not engine.resolve_enemy_turn_with_steps(loaded,0).is_empty(),id+" loaded fight resumes through the production resolver")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))

# Different bodies expose an in-range stale index as well as an invalid access.
# The unfiltered state is the live-turn control (dead enemies remain in combat).
static func committed_actor_after_removal(expect: Callable) -> void:
	var engine := Combat.new()
	var guardian = preload("res://scripts/guardian_combat_rules.gd")
	for live_body: bool in [false, true]:
		var state: Dictionary = Fixtures.new().fixture("",COMMITTED_ACTOR_FIXTURE["positions"])
		state["player"]["pos"] = COMMITTED_ACTOR_FIXTURE["player_pos"]
		state["enemies"][2]["charge"] = COMMITTED_ACTOR_FIXTURE["third_charge"]
		var intent: Dictionary = COMMITTED_ACTOR_FIXTURE["intent"].duplicate(true)
		intent["live_body"] = live_body
		for index: int in range(state["enemies"].size()):
			var committed: Dictionary = guardian.commit(engine,state,index,intent)
			expect.call(not committed["committed_plan"].has("enemy_index"),"new saved plans do not retain snapshot array positions")
			# Exercise old saves too: their stale positions must be ignored.
			committed["committed_plan"]["enemy_index"] = index
			state["enemies"][index]["intent"] = committed
		state = engine._damage_enemy(state,0,COMMITTED_ACTOR_FIXTURE["kill_damage"])
		var control: Dictionary = engine.enemy_intent_plan(state,1)
		var control_turn: Dictionary = engine.resolve_enemy_turn_with_steps(state,1,false,false)["state"]
		var filtered: Dictionary = state.duplicate(true)
		filtered["enemies"].remove_at(0)
		var actual: Dictionary = engine.enemy_intent_plan(filtered,0)
		expect.call(actual.get("path")==control.get("path"),"removed first enemy preserves second committed approach (live_body=%s)" % live_body)
		expect.call(actual.get("projected_attack")==control.get("projected_attack"),"in-range stale plan cannot borrow third enemy's body or range (live_body=%s)" % live_body)
		expect.call(actual.get("enemy_index",-1)==0,"returned committed plan has the current actor index")
		var actual_turn: Dictionary = engine.resolve_enemy_turn_with_steps(filtered,0,false,false)["state"]
		expect.call(actual_turn["player"]["hp"]==control_turn["player"]["hp"] and actual_turn["enemies"][0]["pos"]==control_turn["enemies"][1]["pos"],"real resolution after removal preserves second enemy movement and damage (live_body=%s)" % live_body)
		expect.call(engine.enemy_intent_plan(state,0).is_empty(),"dead enemy has no committed plan")
		expect.call(guardian.current_plan(engine,filtered,state["enemies"][0],state["enemies"][0]["intent"],false,false).is_empty(),"removed enemy cannot lend its plan to a living body")
		expect.call(not engine.enemy_threat_tiles(filtered,1).get("projected_attack",[]).is_empty(),"last shifted enemy retains its threat without an invalid access")
		print("QA18 COMMITTED ACTOR live_body=%s control_tiles=%s actual_tiles=%s control_pos=%s actual_pos=%s control_hp=%d actual_hp=%d" % [live_body,control.get("projected_attack",[]),actual.get("projected_attack",[]),control_turn["enemies"][1]["pos"],actual_turn["enemies"][0]["pos"],control_turn["player"]["hp"],actual_turn["player"]["hp"]])
