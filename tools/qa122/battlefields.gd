extends RefCounted
## Capture the HUD sentence and drive positive/negative production beats.

const Fx = preload("res://tools/qa122/fixture.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Half = preload("res://scripts/battlefield_rules/half_health.gd")
const Hud = preload("res://scripts/battlefield_rule_hud.gd")
const Gust = preload("res://scripts/battlefield_rules/gust.gd")
const Hoarder = preload("res://scripts/hoarder_room_rules.gd")
const Surface = Fx.Surface
const WarbandTypes: Dictionary = {"stormcaller": "gale_herald", "slagmaster": "slag_mortar",
	"oracle": "hoarfrost_seer", "dynamo": "storm_capacitor", "thornmother": "briar_weaver", "prior": "hollow_mimic"}
const Source := Vector2i(7, 5)
const Hidden := Vector2i(8, 5)
const HiddenHelper := Vector2i(6, 5)
const FuelTile := Vector2i(4, 7)
const Entry := Vector2i(1, 5)
const Exit := Vector2i(9, 5)

static func catalog(engine: RefCounted, filter: String) -> Array:
	var result: Array = []
	var hud := Hud.new()
	for id: String in Rules.data()["instances"]:
		if not filter.is_empty() and id != filter: continue
		var instance: Dictionary = Rules.instance_for(id, 1)
		result.append(_probe(engine, hud, id, instance, false))
		if instance.has("at_half_health"): result.append(_probe(engine, hud, id, instance, true))
	if filter.is_empty() or filter == "ember_hoarder":
		for tier: int in [1, 2, 3]: result.append(_hoarder(engine, hud, tier))
	hud.free()
	return result

static func _setup(engine: RefCounted, id: String, instance: Dictionary) -> Dictionary:
	var type: String = str(WarbandTypes.get(id, id if Fx.Data.enemies().has(id) else "crawler"))
	var state: Dictionary = Fx.state(engine, Source, type)
	state["entry"] = Entry
	state["objective"] = {"type": "reach_exit", "exit_tile": Exit,
		"exits": [{"target_tile": Exit, "door_tile": Exit + Vector2i.RIGHT}]}
	state["enemies"].append(Fx.enemy(Fx.Hero + Vector2i.DOWN, 2, "crawler"))
	var helper: Vector2i = HiddenHelper if instance["rule"] == "shadowstep" else Hidden
	state["enemies"].append(Fx.enemy(helper, 3, "wick_shade"))
	state["enemies"].append(Fx.enemy(helper + Vector2i.UP, 4, "veilbound_acolyte"))
	if id == "snare_earth":
		state["objective"].merge({"special_type": "umbral_snare", "special_variant": "earth"})
	var ground: String = str({"wildfire": "fire", "frostbite": "ice", "lightning_storm": "electrified"}.get(instance["rule"], ""))
	if not ground.is_empty():
		for tile: Vector2i in [Fx.Hero, FuelTile, state["enemies"][1]["pos"]]:
			Surface.place(state, tile, ground, {"actor_kind": "player", "actor_id": -1})
		if ground == "ice":
			state["player"]["chilled"] = true
			state["enemies"][1]["chilled"] = true
			if id == "iskaldra": Surface.place(state, Source, "ice")
	if instance["rule"] == "shadowstep":
		state["umbra"]["stage"] = "eclipse"
	return state

static func _probe(engine: RefCounted, hud: Control, id: String, instance: Dictionary, half: bool) -> Dictionary:
	var state: Dictionary = _setup(engine, id, instance)
	if str(instance["dials"].get("direction", "")) == "aimed":
		instance["locked_direction"] = Gust.direction(engine, state, state["enemies"][0])
	Rules.install(engine, state, instance)
	if half:
		state["enemies"][0]["hp"] = int(state["enemies"][0]["max_hp"]) >> 1
		Half.check(state)
	hud.set_combat_state(state, engine)
	var shown: String = hud.find_child("RuleSentence", true, false).text
	var authored: String = str(Rules.panel(state)["sentence"])
	var live: Dictionary = Rules.active(state)
	var cadence: Dictionary = live["cadence"]
	var anchor: String = str(cadence["anchor"])
	var actor: int = int(live["source"].get("id", -1))
	var intent: String = str(cadence.get("intent", ""))
	var wrong: Dictionary = Rules.dispatch(engine, state.duplicate(true), anchor, actor + 100, "qa122_wrong",
		preload("res://scripts/typed_arrays.gd").dictionaries([]), 1) if anchor != "after_player_turn" else Rules.dispatch(engine, state.duplicate(true), "on_intent")
	var before: Dictionary = Fx.receipt(state)
	var beat_counts: Array = []
	for index: int in range(int(cadence.get("every", 1))):
		state = Rules.dispatch(engine, state, anchor, actor, intent, preload("res://scripts/typed_arrays.gd").dictionaries([]), index + 1)
		beat_counts.append(int(Rules.active(state).get("beats_fired", 0)))
	return {"id": id, "half": half, "text": shown, "authored": authored, "rule": live["rule"], "cadence": cadence,
		"wrong_trigger_beats": int(Rules.active(wrong).get("beats_fired", 0)), "beats": beat_counts,
		"before": before, "delta": Fx.delta(before, Fx.receipt(state))}

static func _hoarder(engine: RefCounted, hud: Control, tier: int) -> Dictionary:
	var state: Dictionary = Fx.state(engine, Source, "ember_hoarder")
	state["objective"] = Hoarder.objective({"special_variant": "qa122"}, tier)
	state["objective"]["type"] = "kill_leader"
	state["objective"]["leader_id"] = 1
	state["enemies"].append(Fx.enemy(Fx.Foe, 2, "ember_tick"))
	hud.set_combat_state(state, engine)
	var panel: Dictionary = Hoarder.panel(state)
	var turns: Array = []
	for index: int in range(Hoarder.escape_turn(tier)):
		state["turn"] = index + 1
		Hoarder.begin_round(engine, state)
		Hoarder.end_round(state)
		turns.append(state["objective"].get("hoarder_escaped", false))
	return {"id": "ember_hoarder", "tier": tier, "text": panel.get("sentence", ""), "kicker": panel.get("kicker", ""),
		"escape": turns, "objective": state["objective"]}
