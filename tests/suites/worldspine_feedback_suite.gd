extends RefCounted

const Combat = preload("res://scripts/hero_facing_combat.gd")
const Scene = preload("res://scripts/run_scene.gd")
const Cards = preload("res://scripts/game_data.gd")
const Rites = preload("res://scripts/rite_rules.gd")
const Terrain = preload("res://scripts/combat_terrain_rules.gd")
const TerrainCards = preload("res://scripts/terrain_card_rules.gd")
const Store = preload("res://scripts/progression_store.gd")
const Fixture = preload("res://tests/suites/illusion_terrain_suite.gd")
const PassSource = preload("res://scripts/pass_forecast_action_source.gd")
const PassForecast = preload("res://scripts/pass_forecast_red_tiles.gd")
const PulseView = preload("res://scripts/worldspine_pulse_view.gd")
const Live = preload("res://scripts/battlefield_rules/committed.gd")

const HERO := Vector2i(4, 4)
const TICK := Vector2i(5, 5)
const OUTCROP := Vector2i(6, 5)
const METEOR_VICTIM := Vector2i(4, 3)
const VISIBLE_OUTCROP := Vector2i(5, 4)
const HIDDEN_VICTIM := Vector2i(7, 5)
const LEGACY_SAVE: String = "user://trn-01-feedback-legacy.save"

static func run(expect: Callable) -> void:
	var scene := Scene.new()
	var engine: RefCounted = scene._combat_engine
	_test_unseen(engine, scene, expect)
	_test_order(engine, scene, expect)
	_test_flying(engine, expect)
	_test_checkpoint(engine, expect)
	_test_playback(engine, scene, expect)
	scene.free()

static func _fixture(engine: RefCounted, enemies: Array) -> Dictionary:
	var state: Dictionary = Fixture._state(engine, enemies)
	state["player"]["pos"] = HERO
	state["player"]["hp"] = 2
	state["draw_per_turn"] = 0
	state["defiance_capacity"] = 0
	state["defiance_remaining"] = 0
	return state

static func _tick_fixture(engine: RefCounted) -> Dictionary:
	var tick: Dictionary = Fixture._enemy(1, TICK, 3)
	tick["type"] = "ember_tick"
	var state: Dictionary = _fixture(engine, [tick, Fixture._enemy(2, Vector2i(8, 7))])
	state["turn_queue"] = [{"kind": "enemy", "enemy_id": 1, "time": 20, "seq": 1}]
	Terrain.raise_outcrop(engine, state, OUTCROP, 4, {"actor_kind": "player"})
	return state

static func _start(state: Dictionary, card_id: String) -> void:
	Rites.start(state, card_id, Cards.card_def(card_id))

static func _forecast(engine: RefCounted, scene: Node, state: Dictionary) -> Dictionary:
	scene._combat_state = state
	var known: Dictionary = PassSource.rest_source(scene, state)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(PassForecast.schedule(engine, known), true)
	return {"phase": phase, "summary": scene._pass_preview_summary_for_phase_result(known, phase)}

static func _test_unseen(engine: RefCounted, scene: Node, expect: Callable) -> void:
	var state: Dictionary = _tick_fixture(engine)
	state["player"]["hp"] = 4
	state["umbra"] = {"stage": "heart"}
	_start(state, "worldspine")
	expect.call(engine.effective_umbra_radius(state) == 2 and engine.is_enemy_visible_to_player(state, state["enemies"][0]) and not engine.is_tile_visible_to_player(state, OUTCROP), "FB1.1 fixture has a visible Ember Tick and an unseen player Outcrop")
	var live: Dictionary = Live.advance_to_player(engine, engine.finish_player_activation(state))["state"]
	var forecast: Dictionary = _forecast(engine, scene, state)
	var plates: Array = forecast["summary"]["entries"]
	expect.call(live["player"]["hp"] == 0 and Fixture._hp(live, 1) == 0, "FB1.1 live pulse kills the Tick and its burst deals 4 to the hero")
	expect.call(forecast["summary"]["defeat"] and forecast["summary"]["projected_hp"] == 0 and forecast["summary"]["hp_loss"] == 4 and Fixture._hp(forecast["phase"]["state"], 1) == 0 and plates.any(func(plate: Dictionary) -> bool: return plate.get("name") == "PassPreviewHpLoss" and plate.get("text") == "−4"), "FB1.1 Pass reports the same lethal burst, loss and final plate Health")

static func _test_order(engine: RefCounted, scene: Node, expect: Callable) -> void:
	for order: Array in [["worldspine", "rite_of_the_mountain"], ["rite_of_the_mountain", "worldspine"]]:
		var state: Dictionary = _tick_fixture(engine)
		for card_id: String in order: _start(state, card_id)
		var live: Dictionary = Live.advance_to_player(engine, engine.finish_player_activation(state))["state"]
		var forecast: Dictionary = _forecast(engine, scene, state)
		expect.call(live["player"]["hp"] == 1 and forecast["summary"]["projected_hp"] == 1 and Fixture._hp(live, 1) == 0, "FB1.2 Mountain grants Stoneskin before either cast order pulses: %s" % str(order))

static func _test_flying(engine: RefCounted, expect: Callable) -> void:
	var shrike: Dictionary = Fixture._enemy(1, TICK, 2)
	shrike["type"] = "gust_shrike"
	shrike["block"] = 1
	var state: Dictionary = _fixture(engine, [shrike, Fixture._enemy(2, Vector2i(8, 7))])
	state["enemies"][0]["block"] = 1
	Terrain.raise_outcrop(engine, state, OUTCROP, 4, {"actor_kind": "player"})
	_start(state, "worldspine")
	var after: Dictionary = engine.prepare_next_player_turn(state)
	var pulses: Array[Dictionary] = Fixture._events(state, after, TerrainCards.PULSE_EVENT)
	var deaths: Array[Dictionary] = Fixture._events(state, after, "actor_death")
	expect.call(Fixture._hp(after, 1) == 0 and after["enemies"][0]["block"] == 0 and pulses.size() == 1 and pulses[0]["damage_by_enemy"] == {1: 3} and deaths.size() == 1 and deaths[0]["source"]["causal_owner"] == "player" and not deaths[0]["player_card"], "FB1.3 Flying takes the recorded Block and Health loss with non-card player credit")

static func _test_checkpoint(engine: RefCounted, expect: Callable) -> void:
	var state: Dictionary = _tick_fixture(engine)
	state["terrain"][0]["kind"] = "worldspine"
	state["terrain"][0]["pulse_damage"] = 3
	var later: Dictionary = state.duplicate(true)
	later["terrain"].clear()
	var other: Dictionary = later.duplicate(true)
	other["fight_seed"] += 1
	var run: Dictionary = {"combat_state": state, "pending_combat_checkpoints": [{"state": later}, {"state": other}]}
	expect.call(Store._save_run_state_at(LEGACY_SAVE, run), "FB1.4 legacy checkpoint fixture saves")
	var loaded: Dictionary = Store._load_run_dictionary(LEGACY_SAVE)
	var resumed: Dictionary = loaded["pending_combat_checkpoints"][0]["state"]
	Terrain.raise_outcrop(engine, resumed, OUTCROP, 3, {"actor_kind": "player"})
	var after: Dictionary = engine.prepare_next_player_turn(resumed)
	expect.call(Rites.active_rites(resumed).size() == 1 and Fixture._hp(after, 1) == 0 and Rites.active_rites(loaded["pending_combat_checkpoints"][1]["state"]).is_empty(), "FB1.4 the checkpoint carries one Rite into later Outcrops in the same fight only")
	expect.call(Store._save_run_state_at(LEGACY_SAVE, loaded) and Rites.active_rites(Store._load_run_dictionary(LEGACY_SAVE)["pending_combat_checkpoints"][0]["state"]).size() == 1, "FB1.4 migrated checkpoint survives a second load without duplication")

static func _test_playback(engine: RefCounted, scene: Node, expect: Callable) -> void:
	var state: Dictionary = _fixture(engine, [Fixture._enemy(1, METEOR_VICTIM), Fixture._enemy(2, TICK), Fixture._enemy(3, HIDDEN_VICTIM, 2)])
	state["turn_queue"] = []
	state["umbra"] = {"stage": "heart"}
	state["meteor_marks"] = [{"tiles": [METEOR_VICTIM], "damage": 5, "element": "fire", "surface": "fire"}]
	Terrain.raise_outcrop(engine, state, OUTCROP, 4, {"actor_kind": "player"})
	Terrain.raise_outcrop(engine, state, VISIBLE_OUTCROP, 4, {"actor_kind": "player"})
	_start(state, "worldspine")
	var phase: Dictionary = engine.advance_one_activation_with_steps(engine.finish_player_activation(state))
	var beats: Array = (phase["steps"] as Array).filter(func(step: Dictionary) -> bool: return step.get("trigger") in ["meteor_marks", TerrainCards.PULSE_EVENT])
	expect.call(beats.size() == 2, "FB1.5 Meteorfall and Worldspine have distinct playback steps")
	var meteor: Dictionary = beats[0] if not beats.is_empty() else {}
	var animated: Dictionary = state.duplicate(true)
	if not meteor.is_empty(): scene._apply_animation_step(animated, meteor)
	expect.call(Fixture._hp(animated, 1) == 15 and Fixture._hp(animated, 2) == 20 and Fixture._hp(animated, 3) == 2, "FB1.5 Meteorfall updates only its victim's plate")
	if beats.size() != 2:
		return
	var pulse: Dictionary = beats[1]
	var ticks: Array[Dictionary] = preload("res://scripts/enemy_action_analytics.gd").status_events(phase, {})
	expect.call(ticks.size() == 1 and ticks[0]["payload"]["trigger"] == "meteor_marks", "FB1.5 the pulse step does not add an enemy status analytics event")
	var before: Dictionary = state.merged(pulse["pulse_before"], true)
	var after: Dictionary = state.merged(pulse["pulse_after"], true)
	expect.call(Fixture._hp(before, 2) == 20 and Fixture._hp(after, 1) == 15 and Fixture._hp(after, 2) == 17 and Fixture._hp(after, 3) == 0 and pulse["pulse_event"]["damage_by_enemy"][3] == 2, "FB1.5 both pulse victims' Health changes at the pulse beat")
	var shown: Dictionary = PulseView.feedback(scene, before, after, pulse["pulse_event"])
	var actors: Array = shown["floating_texts"].map(func(entry: Dictionary) -> String: return str(entry.get("reaction_actor_key", "")))
	var events: Array = shown["surface_feedback_events"]
	var defeat_view: Dictionary = scene._death_hold_presentation(scene._visible_turn_start_defeat_source(before), after, {})
	expect.call(actors == ["enemy_2"] and events.size() == 1 and events[0]["tiles"] == [VISIBLE_OUTCROP] and not defeat_view.has("death_animation_units"), "FB1.5 Umbra hides the concealed enemy's popup and dissolve and the unseen Outcrop's pulse effect")
