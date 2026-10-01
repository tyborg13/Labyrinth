extends SceneTree
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/dragon_trophy_rules.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixtures = preload("res://tests/suites/surface_relic_suite.gd")
const Base = preload("res://tests/suites/board_surface_suite.gd")
var failed: int = 0
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_test_time()
	_test_relay()
	_test_relay_force_chain()
	print("DRAGON TROPHY FEEDBACK: ", "PASS" if failed == 0 else "FAIL")
	quit(1 if failed else 0)
func _test_time() -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixtures.fixture(engine,["winters_hour"])
	state["deck"]["hand"] = ["rime_shard","rime_shard","pale_spark","brace","quick_stab"]
	state = engine.finish_player_card(state,0)
	expect(Rules.reserve(state,"winters_hour") == 3 and int(state["player_turn_time_spent"]) == 3, "First Ice card pays its own Time then banks three")
	var before: Dictionary = state.duplicate(true)
	var displayed: Dictionary = engine.card_def("pale_spark",state)
	expect(int(displayed["time"]) == 1 and state == before, "Card-definition preview discounts without spending")
	state = engine.finish_player_card(state,0)
	expect(Rules.reserve(state,"winters_hour") == 3, "Second Ice card cannot increase or spend reserve")
	var time_before: int = int(state["player_turn_time_spent"])
	state = engine.finish_player_card(state,0)
	expect(int(state["player_turn_time_spent"]) - time_before == int(displayed["time"]) and Rules.reserve(state,"winters_hour") == 1, "Committed non-Ice cost equals preview and retains unused reserve")
	state = engine.finish_player_card(state,0)
	expect(Rules.reserve(state,"winters_hour") == 1, "Time-one card never wastes reserve or becomes free")
	state = engine.finish_player_card(state,0)
	expect(Rules.reserve(state,"winters_hour") == 0 and int(engine.card_def("pale_spark",state)["time"]) == 3, "After spending the last point, previews restore printed cost")
	state = engine.prepare_next_player_turn(state)
	state["deck"]["hand"] = ["rime_shard"]
	state = engine.finish_player_card(state,0)
	expect(Rules.reserve(state,"winters_hour") == 3, "New activation restores only the first-Ice trigger")
	state = engine.prepare_next_player_turn(state)
	expect(Rules.reserve(state,"winters_hour") == 3, "Unused Time survives activation boundaries")
	Store.set_run_storage_path("user://dragon_time_state.save")
	Store.save_run_state({"combat_state":state})
	var loaded: Dictionary = Store.load_saved_run()["combat_state"]
	expect(Rules.reserve(loaded,"winters_hour") == 3 and engine.card_def("pale_spark",loaded) == engine.card_def("pale_spark",state), "Save/reload retains reserve and exact cost preview")
	state["skill_ids"] = ["borrowed_time"]
	state["banked_play_active"] = 1
	state["cards_played_this_turn"] = 2
	state["deck"]["hand"] = ["pale_spark"]
	time_before = int(state["player_turn_time_spent"])
	state = engine.finish_player_card(state,0)
	expect(int(state["player_turn_time_spent"]) == time_before and Rules.reserve(state,"winters_hour") == 3, "Borrowed Time's free card preserves reserve")
	var event: Dictionary = {}
	for candidate: Dictionary in state.get("surface_events",[]):
		if str(candidate.get("kind","")) == "relic_time_reserve": event = candidate
	expect(str(event.get("relic_id","")) == "winters_hour" and not str(event.get("card_id","")).is_empty() and str(event.get("source",{}).get("actor_kind","")) == "player", "Reserve events retain card and relic source")
	state = Fixtures.fixture(engine,["winters_hour"])
	state["deck"]["hand"] = ["rime_shard"]
	state = engine.finish_player_card(state,0,1,{"play_mode":"discard"})
	expect(Rules.reserve(state,"winters_hour") == 0, "Discard fallback is not an Ice-card play trigger")
func _test_relay() -> void:
	var engine := Combat.new()
	var state: Dictionary = Fixtures.fixture(engine,["stormroad_coil"])
	state["enemies"][0]["pos"] = Vector2i(6,3)
	Surface.place(state,Vector2i(4,3),"electrified")
	var action := {"type":"ranged","range":2,"damage":3,"_card_id":"pale_spark"}
	var before: Dictionary = state.duplicate(true)
	expect(engine.valid_targets_for_player_action(state,action).has(Vector2i(6,3)), "Ranged attack reaches target through one surface relay")
	var preview: Dictionary = engine.surface_preview_for_player_action(state,action,Vector2i(6,3))
	var actual: Dictionary = engine.apply_player_action(state,action,Vector2i(6,3))
	expect(state == before and preview["state"] == actual, "Preview and commit use identical deterministic relay outcomes without mutating source")
	expect(int(actual["enemies"][0]["hp"]) == 997 and Surface.has_surface(actual,Vector2i(4,3),"electrified"), "Relay adds reach without damage or consuming ground")
	var trace: Array = preview["chain_hits"]
	expect(trace.size() == 2 and trace[0]["from"] == Vector2i(2,3) and trace[0]["to"] == Vector2i(4,3) and trace[1]["from"] == Vector2i(4,3) and trace[1]["to"] == Vector2i(6,3), "Preview/animation trace explicitly includes both legs")
	var event: Dictionary = {}
	for candidate: Dictionary in actual.get("surface_events",[]):
		if str(candidate.get("kind","")) == "relic_ranged_relay": event = candidate
	expect(event.get("relay") == Vector2i(4,3) and str(event.get("source",{}).get("card_id","")) == "pale_spark", "Relay analytics preserve actual route and original card")
	state["enemies"][0]["pos"] = Vector2i(4,3)
	expect(not Rules.route_for_target(engine,state,action,Vector2i(4,3)).has("relay"), "Direct legal route is always preferred")
	state["enemies"][0]["pos"] = Vector2i(7,3)
	Surface.place(state,Vector2i(5,3),"electrified")
	expect(not engine.valid_targets_for_player_action(state,action).has(Vector2i(7,3)), "A chain of tiles cannot extend beyond one relay")
	state["enemies"][0]["pos"] = Vector2i(6,3)
	state["grid"][3][3] = "wall"
	expect(not engine.valid_targets_for_player_action(state,action).has(Vector2i(6,3)), "Blocked first leg is illegal")
	state["grid"][3][3] = "stone"
	state["grid"][3][5] = "wall"
	expect(not engine.valid_targets_for_player_action(state,action).has(Vector2i(6,3)), "Blocked second leg is illegal")
	state["grid"][3][5] = "stone"
	state["terrain"] = [{"id":89,"pos":Vector2i(5,3),"kind":"crag_outcrop","hp":3,"blocks_sight":true}]
	expect(not engine.valid_targets_for_player_action(state,action).has(Vector2i(6,3)), "A sight-blocking outcrop blocks relay leg")
	state["terrain"] = []
	state["relics"] = []
	expect(not engine.valid_targets_for_player_action(state,action).has(Vector2i(6,3)), "No ownership means no extra reach")
	state["relics"] = ["stormroad_coil"]
	var melee: Dictionary = action.duplicate(true)
	melee["type"] = "melee"
	expect(not engine.valid_targets_for_player_action(state,melee).has(Vector2i(6,3)), "Melee does not gain ranged relays")
	# A large actor remains targetable on any square once one contact is legal.
	state["enemies"][0]["footprint"] = Vector2i(2,2)
	expect(engine.valid_targets_for_player_action(state,action).has(Vector2i(7,4)), "Large body click uses a reachable footprint edge")
	actual = engine.apply_player_action(state,action,Vector2i(7,4))
	expect(int(actual["enemies"][0]["hp"]) == 997, "Outermost large-body click resolves one hit via legal relay contact")
	# Enemy and targetless/broad attacks retain their ordinary range.
	var enemy_action: Dictionary = action.duplicate(true)
	enemy_action["_enemy_id"] = 1
	expect(Rules.relay_effect(engine,state,enemy_action).is_empty(), "Player relic never extends an enemy action")
	# Worldroot's paid origin and a range relay are separate resources. A stacked
	# Electrified relay keeps its Rubble; only the selected remote origin pays.
	state = Fixtures.fixture(engine,["worldroot_idol","stormroad_coil"])
	state["enemies"][0]["pos"] = Vector2i(7,3)
	for tile: Vector2i in [Vector2i(2,3),Vector2i(3,3),Vector2i(5,3)]:
		Surface.place(state,tile,"rubble")
	Surface.place(state,Vector2i(3,3),"electrified")
	Surface.place(state,Vector2i(5,3),"electrified")
	var remote: Dictionary = action.duplicate(true)
	remote["_surface_relic_modes"] = ["remote"]
	remote["_origin_tile"] = Vector2i(3,3)
	before = state.duplicate(true)
	preview = engine.surface_preview_for_player_action(state,remote,Vector2i(7,3))
	actual = engine.apply_player_action(state,remote,Vector2i(7,3))
	expect(state == before and preview["state"] == actual,"Remote payment plus relay preview equals commit without mutating source")
	expect(not Surface.has_rubble(actual,Vector2i(3,3)) and Surface.has_rubble(actual,Vector2i(5,3)),"Worldroot spends original remote Rubble, never relay Rubble")
	expect(Surface.has_surface(actual,Vector2i(3,3),"electrified") and Surface.has_surface(actual,Vector2i(5,3),"electrified") and int(actual["enemies"][0]["hp"]) == 997,"Paid remote relay preserves elemental ground and resolves one ordinary hit")
	var aoe: Dictionary = action.duplicate(true)
	aoe["type"] = "aoe"
	expect(Rules.relay_effect(engine,state,aoe).is_empty(), "AOE centers retain printed reach")
func _test_relay_force_chain() -> void:
	var engine := Combat.new()
	# Razor Gale supplies Push; Brightglass Lens supplies Chain on the lit
	# primary. This bent Stormroad route has a different Push direction from
	# the player's direct origin, so preview equality alone is insufficient:
	# from the relay (4,1) the primary is pushed straight down to (4,4), while a
	# push from the player at (2,1) (an exact diagonal) would default to (5,3).
	# Chain 1 from the displaced primary: (4,5) is in reach only from (4,4);
	# (5,3) would be in reach only from the primary's original tile.
	for followup: Vector2i in [Vector2i(5,3), Vector2i(4,5)]:
		var state: Dictionary = Fixtures.fixture(engine,["stormroad_coil","ember_lens"])
		state["player"]["pos"] = Vector2i(2,1)
		state["enemies"].append(Base.enemy(2,followup))
		Surface.place(state,Vector2i(4,1),"electrified")
		state = engine._create_umbra_light_source(state,Vector2i(4,3),{"radius":1,"duration":2})
		var action: Dictionary = (engine.card_def("razor_gale",state)["actions"][0] as Dictionary).duplicate(true)
		var damage: int = int(action["damage"])
		var before: Dictionary = state.duplicate(true)
		var preview: Dictionary = engine.surface_preview_for_player_action(state,action,Vector2i(4,3))
		var actual: Dictionary = engine.apply_player_action(state,action,Vector2i(4,3))
		var legal_followup: bool = followup == Vector2i(4,5)
		expect(state == before and preview["state"] == actual,"Bent relay Push plus Chain preview equals commit without mutating source")
		var player_line: Vector2i = engine.resolved_force_direction_for_player_action(state,{"type":"push","amount":1,"damage":0,"range":4},Vector2i(4,3))
		if legal_followup:
			# With the lane at (5,3) open, the player's diagonal default is horizontal.
			expect(player_line == Vector2i(1,0),"A push from the player's own tile would take a different line: %s" % str(player_line))
		expect(actual["enemies"][0]["pos"] == Vector2i(4,4) and int(actual["enemies"][0]["hp"]) == 1000-damage,"Bent relay pushes primary away from delivery tile, not player")
		expect(int(actual["enemies"][1]["hp"]) == 1000-(damage if legal_followup else 0),"Chain hits only enemies within reach of the actual pushed primary")
		var trace: Array = preview["chain_hits"]
		expect(trace.size() == (3 if legal_followup else 2),"Bent relay route contains exactly the legal actor hops")
		if legal_followup and trace.size() == 3:
			expect(trace[2]["from"] == Vector2i(4,4) and trace[2]["to"] == Vector2i(4,5),"Chain animation begins at primary's actual displaced position")
	# A directly reachable target ignores available relays and preserves the
	# existing player-origin Push and Chain result, with or without ownership.
	var direct_reference: Dictionary = {}
	for has_coil: bool in [false,true]:
		var state: Dictionary = Fixtures.fixture(engine,["ember_lens"])
		if has_coil: state["relics"].append("stormroad_coil")
		# The player's straight push from (2,3) moves the primary to (5,3); the
		# follow-up at (6,3) is in Chain reach only from there.
		state["enemies"].append(Base.enemy(2,Vector2i(6,3)))
		Surface.place(state,Vector2i(2,2),"electrified")
		state = engine._create_umbra_light_source(state,Vector2i(4,3),{"radius":1,"duration":2})
		var action: Dictionary = (engine.card_def("razor_gale",state)["actions"][0] as Dictionary).duplicate(true)
		var preview: Dictionary = engine.surface_preview_for_player_action(state,action,Vector2i(4,3))
		var actual: Dictionary = engine.apply_player_action(state,action,Vector2i(4,3))
		expect(preview["state"] == actual and actual["enemies"][0]["pos"] == Vector2i(5,3),"Direct Push and Chain retain player-origin preview/commit parity")
		expect(int(actual["enemies"][1]["hp"]) == 1000-int(action["damage"]),"Direct Push still chains from its displaced primary")
		var used_relay: bool = false
		for event: Dictionary in actual.get("surface_events",[]):
			used_relay = used_relay or str(event.get("kind","")) == "relic_ranged_relay"
		expect(not used_relay and preview["chain_hits"].size() == 2,"Direct legal route never inserts or records a range relay")
		if has_coil:
			expect(actual["enemies"] == direct_reference["enemies"] and preview["chain_hits"] == direct_reference["chain_hits"],"Coil ownership leaves direct fallback actors and route unchanged")
		else:
			direct_reference = {"enemies":actual["enemies"],"chain_hits":preview["chain_hits"]}

func expect(ok: bool, message: String) -> void:
	if not ok:
		failed += 1
		push_error(message)
