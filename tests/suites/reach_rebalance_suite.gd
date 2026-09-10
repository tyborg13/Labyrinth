extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Run = preload("res://scripts/run_engine.gd")
const Base = preload("res://tests/suites/enemy_tactical_ai_suite.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")

static func run(expect: Callable) -> void:
	_test_reach_contract(expect)
	_test_approach_cadence_and_commitment(expect)
	_test_support_approach(expect)
	_test_player_reach_and_cover(expect)
	_test_saved_commitment(expect)

static func _test_reach_contract(expect: Callable) -> void:
	var cards: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/cards.json"))
	for card_id: String in cards:
		if bool(cards[card_id].get("retired", false)): continue
		for action: Dictionary in cards[card_id]["actions"]:
			if str(action["type"]) in ["ranged", "push", "pull", "aoe", "surface", "illusion", "detonate"]:
				var ceiling: int = 4 if card_id in ["stormstring_shot", "hush_of_winter"] else 3
				expect.call(int(action.get("range", 0)) <= ceiling, "%s keeps ordinary reach short except the two named long shots" % card_id)
			if str(action["type"]) == "move":
				expect.call(int(action["range"]) <= 3, "%s walking cannot cross most of a room" % card_id)

	for enemy_type: String in ["crawler", "acolyte", "harrier", "warden", "cinder_ooze", "bile_bloomer", "chainbound_gaoler", "grave_surgeon", "frostglass_lancer", "lightning_wisp", "veilbound_acolyte", "cinder_droplet"]:
		for intent: Dictionary in Data.enemy_def(enemy_type)["intents"]:
			var advance: int = 0
			for action: Dictionary in intent["actions"]:
				if str(action["type"]) == "move_toward":
					advance += int(action["range"])
				if str(action["type"]) in ["melee", "ranged", "aoe", "pull", "push"]:
					var extent: int = int(action.get("range", 0))
					var pattern_extent: int = 0
					for offset: Array in action.get("pattern", []):
						pattern_extent = maxi(pattern_extent, absi(int(offset[0])) + absi(int(offset[1])))
					expect.call(advance + extent + pattern_extent <= 4, "%s/%s must fit its direct four-tile envelope, including pattern extent" % [enemy_type, intent["id"]])
					if str(intent.get("purpose", "")) == "approach":
						expect.call(str(action["type"]) == "melee" and int(action["range"]) == 1 and int(action["damage"]) <= 3 and str(action.get("element", "none")) == "none", "Long approaches carry only weak neutral melee")
						for rider: String in ["bleed", "surface", "surface_bonus", "immobilize", "chain", "push", "pull", "expose", "sunder"]:
							expect.call(not action.has(rider), "Long approaches cannot carry %s" % rider)

static func _test_approach_cadence_and_commitment(expect: Callable) -> void:
	var combat := Combat.new()
	for enemy_type: String in ["crawler", "acolyte", "harrier", "frostglass_lancer", "lightning_wisp"]:
		var state: Dictionary = Base._state(Vector2i(1, 4), [Base._enemy(enemy_type, 1, Vector2i(6, 4))])
		var options: Array[Dictionary] = combat.enemy_tactical_intent_options(state, 0)
		expect.call(not options.is_empty(), "%s should have a useful distant approach" % enemy_type)
		for option: Dictionary in options:
			var intent: Dictionary = option["intent"]
			expect.call(str(intent.get("purpose", "")) == "approach", "%s must reliably approach rather than wait on unavailable shots" % enemy_type)
			var path: Array[Vector2i] = Base._tiles(option["path"])
			expect.call(path.size() == 4 and not bool(option["attack_available"]), "%s should move three even when its melee cannot reach" % enemy_type)
			state["enemies"][0]["intent"] = intent.duplicate(true)
			state["player"]["pos"] = Vector2i(2, 4)
			var after: Dictionary = combat._resolve_enemy_intent(state.duplicate(true), 0, intent)
			expect.call(int(after["player"]["hp"]) == 24 - int(intent["actions"][1]["damage"]), "A revealed approach must resolve only its committed weak hit")
			state["enemies"][0]["pos"] = Vector2i(4, 4)
			state["player"]["pos"] = Vector2i(1, 4)
			for positioned: Dictionary in combat.enemy_tactical_intent_options(state, 0):
				expect.call(str(positioned["intent"].get("purpose", "")) != "approach", "%s should prefer a connecting signature attack" % enemy_type)
	for enemy_type: String in ["cinder_ooze", "bile_bloomer", "chainbound_gaoler"]:
		var state: Dictionary = Base._state(Vector2i(1, 4), [Base._enemy(enemy_type, 1, Vector2i(6, 4))])
		for option: Dictionary in combat.enemy_tactical_intent_options(state, 0):
			expect.call(str(option["intent"].get("purpose", "")) == "approach" and Base._tiles(option["path"]).size() == 3, "%s should have a purposeful two-tile anchor reposition" % enemy_type)
	# A neutral Wisp approach cannot discharge even prepared ground.
	var wired: Dictionary = Base._state(Vector2i(2, 4), [Base._enemy("lightning_wisp", 1, Vector2i(6, 4))])
	Ground.place(wired, Vector2i(2, 4), "electrified")
	Ground.place(wired, Vector2i(2, 3), "electrified")
	wired = combat._resolve_enemy_intent(wired, 0, Base._intent("lightning_wisp", "spark_dart"))
	for event: Dictionary in wired.get("surface_events", []):
		expect.call(str(event.get("kind", "")) != "surface_conducted", "Wisp approach must not discharge a prepared network")

static func _test_support_approach(expect: Callable) -> void:
	var combat := Combat.new()
	var ally: Dictionary = Base._enemy("crawler", 2, Vector2i(1, 4))
	ally["hp"] = 1
	var state: Dictionary = Base._state(Vector2i(1, 1), [Base._enemy("grave_surgeon", 1, Vector2i(6, 4)), ally])
	for step: int in range(2):
		var options: Array[Dictionary] = combat.enemy_tactical_intent_options(state, 0)
		expect.call(Base._option_ids(options) == Base._string_array(["triage_suture"]), "An injured ally outside support range should prompt healing approach instead of self-guard")
		state = combat._resolve_enemy_intent(state, 0, Base._intent("grave_surgeon", "triage_suture"))
	expect.call(state["enemies"][0]["pos"] == Vector2i(4, 4) and int(state["enemies"][1]["hp"]) > 1, "Surgeon should close only far enough to heal the separated ally")
	var solo: Dictionary = Base._state(Vector2i(1, 4), [Base._enemy("grave_surgeon", 1, Vector2i(6, 4))])
	expect.call(Base._option_ids(combat.enemy_tactical_intent_options(solo, 0)) == Base._string_array(["saw_jab"]), "A healthy last Surgeon must pursue instead of guarding itself forever")
	var plan: Dictionary = combat.enemy_intent_plan(state, 0, Base._intent("grave_surgeon", "triage_suture"))
	expect.call(Base._tiles(plan["path"]).size() == 1, "Once in support range, Surgeon should hold its ally position")

static func _test_player_reach_and_cover(expect: Callable) -> void:
	var combat := Combat.new()
	var state: Dictionary = Base._state(Vector2i(1, 4), [Base._enemy("crawler", 1, Vector2i(4, 4))])
	var poke: Dictionary = Data.card_def("pale_spark")["actions"][0]
	var shot: Dictionary = Data.card_def("dull_bolt")["actions"][0]
	expect.call(not combat.valid_targets_for_player_action(state, poke).has(Vector2i(4, 4)), "Range-two starter poke cannot hit three away")
	expect.call(combat.valid_targets_for_player_action(state, shot).has(Vector2i(4, 4)), "Dedicated range-three starter has a distinct legal target")
	state["terrain"] = [{"id": "crate", "pos": Vector2i(2, 4), "hp": 3, "max_hp": 3}]
	expect.call(combat.valid_targets_for_player_action(state, shot).has(Vector2i(4, 4)), "Crates still block movement but do not block shots")
	state["grid"][4][2] = "pillar"
	expect.call(not combat.valid_targets_for_player_action(state, shot).has(Vector2i(4, 4)), "Pillars still block short shots")
	expect.call(combat.player_movement_capacity(state) == 2, "The independent movement pool remains two")

static func _test_saved_commitment(expect: Callable) -> void:
	var run := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Base._state(Vector2i(1, 4), [Base._enemy("acolyte", 1, Vector2i(6, 4))])
	var old_intent: Dictionary = {"id": "dust_bolt", "time": 4, "actions": [{"type": "move_toward", "range": 2}, {"type": "ranged", "damage": 5, "range": 5}], "_surface_fuel_paid": true}
	state["enemies"][0]["intent"] = old_intent.duplicate(true)
	state["initiative_clock"] = 27
	state["deck"] = {"hand": ["pale_spark"], "draw": ["dull_bolt"], "discard": ["brace"]}
	var before: Dictionary = state.duplicate(true)
	var saved: Dictionary = run.create_new_run(91, Progression.default_data())
	saved["mode"] = "combat"
	saved["combat_state"] = state.duplicate(true)
	saved["pending_combat_checkpoints"] = [{"boundary": "paid_action", "state": state.duplicate(true)}]
	var repaired: Dictionary = run.repair_loaded_run_state(saved)
	var checkpoint: Dictionary = repaired["pending_combat_checkpoints"][0]["state"]
	expect.call(repaired["combat_state"]["enemies"][0]["intent"] == old_intent and checkpoint["enemies"][0]["intent"] == old_intent, "The real load path preserves active and paid-checkpoint intents")
	expect.call(repaired["combat_state"]["balance_revision"] == Data.BALANCE_REVISION and checkpoint["balance_revision"] == Data.BALANCE_REVISION, "The real load path records both active and continuation transitions")
	state = run._mark_balance_transition(state)
	expect.call(state["enemies"] == before["enemies"] and state["deck"] == before["deck"] and state["initiative_clock"] == 27, "Balance transition preserves saved commitments, paid riders, piles and clock")
	expect.call(str(state.get("balance_revision", "")) == Data.BALANCE_REVISION and bool(state["balance_transition"]["saved_intents_preserved"]), "Legacy boundary is explicitly recorded")
	expect.call(run._mark_balance_transition(state.duplicate(true)) == state, "Balance transition is idempotent")
	var store := Analytics.new()
	var event: Dictionary = store._event_record("combat_resumed", {"balance_transition": state["balance_transition"]}, {}, "")
	expect.call(event["balance_revision"] == Data.BALANCE_REVISION and event["balance_transition"] == state["balance_transition"], "Analytics identifies a transitional encounter without rewriting history")
	var rng := RandomNumberGenerator.new()
	rng.seed = 91
	combat._assign_enemy_intent(state, 0, rng)
	expect.call(str(state["enemies"][0]["intent"].get("purpose", "")) == "approach", "The next selection after an old saved commitment uses current short-range definitions")
