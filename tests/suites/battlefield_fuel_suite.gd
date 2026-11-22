extends RefCounted
## area-02: hero and foe ground changes feed live beats.
const Combat = preload("res://scripts/combat_engine.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Base = preload("res://tests/suites/battlefield_rules_suite.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/battlefield_rules/analytics.gd")
const SAVE_PATH: String = "user://area02-live-rule.save"
const PROOF_DAMAGE: int = 2
const PROOF_RESUMED_BEATS: int = 3
const OLD_TILE := Vector2i(5, 5)
const NEW_TILE := Vector2i(6, 5)

static func run(expect: Callable) -> void:
	for rule: String in ["lightning_storm", "frostbite", "wildfire"]: _geometry(expect, rule)
	_occupants_and_walls(expect)
	_gust_and_marks(expect)
	_presentation(expect)
	_save_and_analytics(expect)
	_saved_storms(expect)
	_catalog(expect)
	preload("res://tests/suites/battlefield_snapshot_feedback_suite.gd").run(expect)
	print("BATTLEFIELD LIVE RULES: fuel, present red, occupants, saves, analytics and storm data checked")

static func fixture(rule: String) -> Dictionary:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	var dials: Dictionary = {"lightning_storm": {"damage": PROOF_DAMAGE}, "frostbite": {"damage": 0}, "wildfire": {"spread": "all"}}[rule]
	var instance: Dictionary = Base.rule(rule, dials, true)
	Rules.install(engine, state, instance)
	return state

static func _geometry(expect: Callable, rule: String) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture(rule)
	var element: String = {"lightning_storm": "electrified", "frostbite": "ice", "wildfire": "fire"}[rule]
	var bucket: String = {"lightning_storm": "strike", "frostbite": "freeze", "wildfire": "catch"}[rule]
	expect.call(Rules.forecast(engine, state)["tiles"][bucket].is_empty(), rule + " has no footprint without fuel")
	Surface.place(state, OLD_TILE, element, {"actor_kind": "player"})
	var added: Array = Rules.forecast(engine, state)["tiles"][bucket]
	expect.call(not added.is_empty(), rule + " player-laid fuel updates red immediately")
	Surface.remove(state, OLD_TILE, element, "expend")
	expect.call(Rules.forecast(engine, state)["tiles"][bucket].is_empty(), rule + " player Expend removes red immediately")
	Surface.place(state, OLD_TILE, element, {"actor_kind": "player"})
	state = engine.finish_player_activation(state)
	Surface.remove(state, OLD_TILE, element, "expend")
	Surface.place(state, NEW_TILE, element, {"actor_kind": "enemy"})
	state["enemies"][0]["pos"] = NEW_TILE
	var present: Array = Rules.forecast(engine, state)["tiles"][bucket]
	expect.call(not present.is_empty() and present != added, rule + " foe placement and removal retarget the beat")
	var steps: Array[Dictionary]
	var after: Dictionary = Rules.fire(engine, state.duplicate(true), steps)
	if rule == "lightning_storm":
		expect.call(after["player"]["hp"] == state["player"]["hp"] and after["enemies"][0]["hp"] == state["enemies"][0]["hp"] - PROOF_DAMAGE, "Storm hits the foe on fresh Electrified and leaves the former tile safe")
		expect.call(steps[0]["tiles"] == [NEW_TILE] and not steps[0]["chain_hits"].any(func(hit: Dictionary) -> bool: return hit.get("from") != hit.get("to")), "Storm playback shows the live strike without Chain")
	elif rule == "frostbite":
		expect.call(after["player"]["freeze"] == 0 and after["enemies"][0]["freeze"] == 1, "Frostbite Freezes the occupant of fresh Ice")
	else:
		for tile: Vector2i in present: expect.call(Surface.element_at(after, tile) == "fire", "Wildfire spreads from fresh Fire")
		expect.call(Surface.element_at(after, Vector2i(4, 5)).is_empty(), "Removed fuel does not spread")

static func _occupants_and_walls(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture("lightning_storm")
	Surface.place(state, OLD_TILE, "electrified")
	state = engine.finish_player_activation(state)
	state["player"]["pos"] = NEW_TILE
	state["enemies"][0]["pos"] = OLD_TILE
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	expect.call(after["player"]["hp"] == state["player"]["hp"] and after["enemies"][0]["hp"] == state["enemies"][0]["hp"] - PROOF_DAMAGE, "Beat targets whoever occupies the live Electrified tile")
	state["grid"][OLD_TILE.y][OLD_TILE.x] = "wall"
	after = Rules.fire(engine, state.duplicate(true))
	expect.call(after["enemies"][0]["hp"] == state["enemies"][0]["hp"], "An impassable tile strikes nothing")
	state["grid"][OLD_TILE.y][OLD_TILE.x] = "floor"
	state["terrain"].append({"pos": OLD_TILE, "hp": 3, "max_hp": 3, "kind": "crag_outcrop"})
	after = Rules.fire(engine, state.duplicate(true))
	expect.call(after["terrain"] == state["terrain"] and after["enemies"][0]["hp"] == state["enemies"][0]["hp"], "New impassable terrain blocks the beat without being damaged")

static func _gust_and_marks(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = Base.battle(engine)
	Rules.install(engine, state, Base.rule("gust", {"tiles": 1, "direction": "fixed:right"}, true))
	state = engine.finish_player_activation(state)
	state["battlefield_rule"]["dials"]["direction"] = "fixed:left"
	var after: Dictionary = Rules.fire(engine, state.duplicate(true))
	expect.call(after["player"]["pos"] == OLD_TILE + Vector2i.LEFT and Rules.forecast(engine, state)["direction"] == Vector2i.LEFT, "Gust resolution and forecast use its current direction")
	state = Base.battle(engine)
	Rules.install(engine, state, Base.rule("upheaval", {"pattern": "line_between", "length": 3, "health": 2}, true))
	var marks: Array = state["battlefield_rule"]["marks"].duplicate()
	state = engine.finish_player_activation(state)
	state["player"]["pos"] = Vector2i(7, 5)
	after = Rules.fire(engine, state.duplicate(true))
	for terrain: Dictionary in after["terrain"]: expect.call(marks.has(terrain["pos"]), "Upheaval rises only on its announced marks")
	expect.call(not after["terrain"].is_empty(), "Upheaval retains a nonempty held-mark witness")

static func _presentation(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture("lightning_storm")
	state["battlefield_rule"]["cadence"]["every"] = 2
	Surface.place(state, OLD_TILE, "electrified")
	var view: Script = preload("res://scripts/battlefield_rule_view.gd")
	var live: Dictionary = view.presentation_for(state, {})
	expect.call(live["threats_at_rest"]["threats"][0]["tiles"] == [OLD_TILE], "Rule red stays drawn all turn even when the next beat is not due")
	state = engine.finish_player_activation(state)
	state["current_actor"] = {"kind": "enemy", "enemy_id": 1}
	Surface.place(state, NEW_TILE, "electrified")
	var during: Dictionary = view.presentation_for(state, {"effect": {"kind": "ranged"}})
	expect.call(during["threats_at_rest"]["threats"][0]["tiles"] == [OLD_TILE, NEW_TILE], "Foe action red includes new Electrified ground")
	var board: Control = preload("res://scripts/combat_board_view.gd").new()
	var submitted: Dictionary = board.call("_battlefield_rule_presentation_for", state, {"effect": {"kind": "ranged"}})
	expect.call(submitted["threats_at_rest"]["threats"][0]["tiles"] == [OLD_TILE, NEW_TILE], "Board submission refreshes rule red during foes' animation")
	board.free()
	state["grid"][OLD_TILE.y][OLD_TILE.x] = "wall"
	expect.call(view.presentation_for(state, {})["threats_at_rest"]["threats"][0]["tiles"] == [NEW_TILE], "A new wall immediately clears its rule red")
	Surface.remove(state, NEW_TILE, "electrified", "expend")
	expect.call(view.presentation_for(state, {}).is_empty(), "Removing the last legal conductor clears its red")

static func _save_and_analytics(expect: Callable) -> void:
	var engine := Combat.new()
	var state: Dictionary = fixture("lightning_storm")
	for foes_turn: bool in [false, true]:
		var draft: Dictionary = state.duplicate(true)
		if foes_turn: draft = engine.finish_player_activation(draft)
		draft["battlefield_rule"]["beat_snapshot"] = {"tiles": [NEW_TILE], "frozen_at": 17}
		draft["battlefield_rule"]["awaiting_pass"] = true
		draft["pending_gust_snapshots"] = {1: {}}
		Surface.place(draft, OLD_TILE, "electrified")
		var resumed: Dictionary = engine.normalize_player_movement_pool(roundtrip(draft))
		expect.call(not resumed.has("pending_gust_snapshots") and not resumed["battlefield_rule"].has("beat_snapshot") and not resumed["battlefield_rule"].has("awaiting_pass"), "Draft hero and foes-turn saves discard retired Pass state")
		var after: Dictionary = Rules.fire(engine, resumed)
		expect.call(after["player"]["hp"] == draft["player"]["hp"] - PROOF_DAMAGE, "Draft save resumes with live fuel")
		var event: Dictionary = after["surface_events"].back()
		expect.call(event["kind"] == "battlefield_rule_fired" and not event.has("beat_tiles_frozen_at") and not Analytics.record(event, {}, "test")["payload"].has("beat_tiles_frozen_at"), "Committed and JSONL beats omit the retired clock")

static func _saved_storms(expect: Callable) -> void:
	var engine := Combat.new()
	var catalog: Dictionary = Rules.data()["instances"]
	for fixture: Array in [["storm_cantor", false, 3, 2], ["zekarion", false, 5, 1], ["zekarion", true, 5, 2]]:
		var id: String = fixture[0]
		var switched: bool = fixture[1]
		var state: Dictionary = Base.battle(engine)
		state["enemies"][0]["type"] = id
		var instance: Dictionary = Rules.instance_for(id, int(state["enemies"][0]["id"]))
		instance.merge({"dials": {"damage": fixture[2], "chain": fixture[3]}, "sentence": "Legacy storm.", "beats_fired": PROOF_RESUMED_BEATS}, true)
		if id == "zekarion": instance["at_half_health"] = {"dials": {"chain": 2}, "sentence": "Legacy half-Health storm."}
		if switched: instance["half_health_switched"] = true
		state["battlefield_rule"] = instance
		var resumed: Dictionary = engine.normalize_player_movement_pool(roundtrip(state))
		var actual: Dictionary = resumed["battlefield_rule"]
		var authored: Dictionary = catalog[id].duplicate(true)
		if switched: Rules.HalfHealth.replace_values(authored, authored["at_half_health"])
		expect.call(actual["dials"] == authored["dials"] and actual["sentence"] == authored["sentence"], id + " resumes with the approved live dials and sentence")
		expect.call(actual.get("at_half_health", {}) == authored.get("at_half_health", {}), id + " resumes with the approved switch")
		expect.call(actual["beats_fired"] == PROOF_RESUMED_BEATS and actual.get("half_health_switched", false) == switched, id + " preserves beat count and half-Health latch")
		expect.call(resumed["surface_events"] == state["surface_events"], id + " preserves saved analytics")
	DirAccess.remove_absolute(SAVE_PATH)

static func roundtrip(state: Dictionary) -> Dictionary:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	file.store_var({"combat_state": state}); file.close()
	return Store._load_run_dictionary(SAVE_PATH)["combat_state"]

static func _catalog(expect: Callable) -> void:
	for id: String in ["storm_cantor", "zekarion", "dynamo", "snare_lightning"]:
		var instance: Dictionary = Rules.instance_for(id, 1)
		expect.call(not instance["dials"].has("chain"), id + " has no Chain dial")
		if instance.has("at_half_health"):
			Rules.HalfHealth.replace_values(instance, instance["at_half_health"])
			expect.call(not instance["dials"].has("chain") and instance["dials"]["damage"] == 7, "Half-Health Zekarion merges Damage 7 and no Chain dial")
