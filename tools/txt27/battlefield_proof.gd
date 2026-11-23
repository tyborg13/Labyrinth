extends RefCounted

const F = preload("res://tools/txt27/fixture.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Warband = preload("res://scripts/warband_combat_rules.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const LastLight = preload("res://scripts/last_light_rules.gd")
const Paths = preload("res://scripts/path_utils.gd")

const WILDFIRE_SOURCE: Vector2i = Vector2i(2, 4)
const WILDFIRE_FUEL: Vector2i = Vector2i(4, 4)
const ROC_HELPER: Vector2i = Vector2i(6, 4)
const SHADOW_DIAGONAL: Vector2i = Vector2i(5, 3)
const LAST_LIGHT_EDGE: Vector2i = Vector2i(7, 4)
const SNARE_EDGE: Vector2i = Vector2i(6, 4)
const SNARE_BLOCKER: Vector2i = Vector2i(4, 4)
const LAST_LIGHT_BLOCKER: Vector2i = Vector2i(5, 4)
const SHADOW_SOURCE: Vector2i = Vector2i(7, 6)

static func run(engine: RefCounted, record: Callable) -> void:
	_wildfire(engine, record)
	_roc(engine, record)
	_shadowstep(engine, record)
	_storm_ground(engine, record)
	_dynamo(engine, record)

static func _wildfire(engine: RefCounted, record: Callable) -> void:
	for case: Array in [["ashen_reaver", "ashen_reaver"], ["slagmaster", "slag_mortar"]]:
		var state: Dictionary = F.fight(engine, case[1])
		state["enemies"][0]["pos"] = WILDFIRE_SOURCE
		Surface.place(state, WILDFIRE_FUEL, "fire", {"actor_kind": "player"})
		Rules.install(engine, state, Rules.instance_for(case[0], 0))
		var sentence: String = Rules.panel(state)["sentence"]
		var order: String = ""
		if case[0] == "slagmaster":
			state["objective"] = {"special_type": "warband", "special_variant": "fire"}
			state["enemies"][0]["is_leader"] = true
			order = Warband.order_line(state["objective"])
		var result: Dictionary = Rules.fire(engine, state)
		var tiles: Array = Surface.tiles(result, "fire")
		record.call(case[0] + "_wildfire_axis", tiles.has(WILDFIRE_FUEL + Vector2i.RIGHT) and sentence.contains("in the direction from the %s to you." % ("Reaver" if case[0] == "ashen_reaver" else "Slagmaster")),
			"Player=%s, source=%s, initial Fire=%s, Fire after beat=%s. %s" % [F.PLAYER, WILDFIRE_SOURCE, WILDFIRE_FUEL, tiles, sentence])
		if not order.is_empty():
			record.call("slagmaster_order_fire", order.contains("each Fire tile spreads 1 tile in the direction from the Slagmaster to you.") and tiles.has(WILDFIRE_FUEL + Vector2i.RIGHT),
				"%s Player-owned Fire at %s produced a new tile at %s." % [order, WILDFIRE_FUEL, WILDFIRE_FUEL + Vector2i.RIGHT])

static func _roc(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "gallows_roc")
	state["enemies"].append(F.unit("roc_fledgling", 1, ROC_HELPER))
	Rules.install(engine, state, Rules.instance_for("gallows_roc", 0))
	var sentence: String = Rules.panel(state)["sentence"]
	var result: Dictionary = Rules.after_player_turn(engine, state)
	var helper: Vector2i = result["enemies"][1]["pos"]
	record.call("gallows_roc_axis", helper == ROC_HELPER + Vector2i.RIGHT and sentence.contains("in the direction from you to the Roc."),
		"Roc=%s, Fledgling %s -> %s. %s" % [result["enemies"][0]["pos"], ROC_HELPER, helper, sentence])

static func _shadowstep(engine: RefCounted, record: Callable) -> void:
	var cases: Array = [["prior", "hollow_mimic", "veilbound_acolyte"],
		["snare_shadow", "crawler", "veilbound_acolyte"], ["last_light", "crawler", "wick_shade"],
		["noctyrax", "noctyrax", "veilbound_acolyte"]]
	for case: Array in cases:
		var state: Dictionary = F.fight(engine, case[1])
		state["enemies"][0]["pos"] = SHADOW_SOURCE
		var start: Vector2i = F.ENEMY
		state["umbra"]["stage"] = "eclipse"
		if case[0] in ["prior", "noctyrax"]:
			start = SHADOW_DIAGONAL
		if case[0] == "prior": state["umbra"]["stage"] = "heart"
		if case[0] == "snare_shadow":
			start = SNARE_EDGE
			state["umbra"]["stage"] = "heart"
			state["grid"][SNARE_BLOCKER.y][SNARE_BLOCKER.x] = "pillar"
		if case[0] == "last_light":
			start = LAST_LIGHT_EDGE
			state["umbra"]["stage"] = LastLight.umbra_stage()
			state["grid"][LAST_LIGHT_BLOCKER.y][LAST_LIGHT_BLOCKER.x] = "pillar"
		state["enemies"].append(F.unit(case[2], 1, start))
		var hidden: bool = not engine.is_enemy_visible_to_player(state, state["enemies"][1])
		var instance: Dictionary = Rules.instance_for(case[0], 0)
		Rules.install(engine, state, instance)
		var sentence: String = Rules.panel(state)["sentence"]
		var result: Dictionary = Rules.fire(engine, state)
		var destination: Vector2i = result["enemies"][1]["pos"]
		var distance: int = Paths.manhattan(start, destination)
		record.call(case[0] + "_shadowstep_distance", hidden and distance > 0 and distance < int(instance["dials"]["blink"]) and sentence.contains("Blinks up to %d tiles" % int(instance["dials"]["blink"])),
			"%s Target %s -> %s, actual distance=%d." % [sentence, start, destination, distance])

static func _storm_ground(engine: RefCounted, record: Callable) -> void:
	for case: Array in [["dynamo", "storm_capacitor", "discharge"], ["storm_cantor", "storm_cantor", "peal"], ["zekarion", "zekarion", "tempest_breath"]]:
		var state: Dictionary = F.fight(engine, case[1])
		state["enemies"][0]["intent"] = F.intent(case[1], case[2])
		var instance: Dictionary = Rules.instance_for(case[0], 0)
		Rules.install(engine, state, instance)
		Surface.place(state, F.PLAYER, "electrified")
		var ground: Dictionary = state["surfaces"].duplicate(true)
		var board := Board.new()
		board.combat_state = state
		var tooltip: String = F.text(board.enemy_intent_tooltip("enemy_0"))
		board.free()
		var hp: int = state["player"]["hp"]
		var result: Dictionary = Rules.fire(engine, state)
		var loss: int = hp - int(result["player"]["hp"])
		record.call(case[0] + "_storm_ground", ground == result["surfaces"] and loss == int(instance["dials"]["damage"]) and tooltip.contains(instance["sentence"]) and not tooltip.contains("then leaves Electrified"),
			"Damage=%d; ground unchanged=%s. Intent tooltip=%s" % [loss, ground == result["surfaces"], tooltip.replace("\n", " / ")])

static func _dynamo(engine: RefCounted, record: Callable) -> void:
	var state: Dictionary = F.fight(engine, "storm_capacitor")
	state["objective"] = {"special_type": "warband", "special_variant": "lightning"}
	state["enemies"][0]["is_leader"] = true
	var intent: Dictionary = F.intent("storm_capacitor", "discharge")
	Rules.install(engine, state, Rules.instance_for("dynamo", 0))
	var sentence: String = Rules.panel(state)["sentence"]
	var legacy: Dictionary = state.duplicate(true)
	legacy["battlefield_rule"]["sentence"] = sentence.replace("uses Arc Lash", "uses Discharge")
	Rules.repair_saved_rule(engine, legacy)
	record.call("dynamo_saved_sentence", legacy == state, "Repair restored the encounter sentence and preserved installed dials and cadence.")
	Surface.place(state, F.PLAYER, "electrified")
	var result: Dictionary = Rules.dispatch(engine, state, "on_intent", 0, str(intent["id"]))
	record.call("dynamo_intent_name", intent["name"] == "Arc Lash" and sentence.contains("uses Arc Lash") and result["battlefield_rule"]["beats_fired"] == 1,
		"%s Committed intent name=%s; beats fired=%d." % [sentence, intent["name"], result["battlefield_rule"]["beats_fired"]])
