extends RefCounted

const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Rules = preload("res://scripts/summon_card_play_rules.gd")
const Icons = preload("res://scripts/action_icon_library.gd")
const Board = preload("res://scripts/combat_board_view.gd")
const RunScene = preload("res://scripts/run_scene.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Guardians = preload("res://scripts/guardian_combat_rules.gd")
const GuardianFixtures = preload("res://tests/suites/guardian_suite.gd")
const Selection = preload("res://tests/helpers/sum01_proof_fixture.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Fixtures = preload("res://tests/suites/en03_enemies_suite.gd")
const TEST_SEED: int = 61027
const TEST_SUMMONER_TILE := Vector2i(2, 2)
const TEST_HERO_TILE := Vector2i(6, 6)
const TEST_SAVE_PATH: String = "user://sum01_pending.save"
const SUMMONERS = ["noctyrax", "zekarion", "storm_cantor", "last_lamplighter"]

class SilentRouter:
	extends RefCounted
	func begin_enemy_action(_state: Dictionary, _step: Dictionary, _actor: Dictionary) -> void: pass
	func request(_cue: String) -> void: pass

class FloatDispatchScene:
	extends "res://scripts/run_scene.gd"
	# Keep the production step dispatcher and summon application. Replace only
	# renderer/audio endpoints and authored animation waits for headless proof.
	var dispatched: Array[Dictionary]
	var sound_ids: Array[String]
	func _ensure_sfx_bank() -> void:
		if _sfx_router == null: _sfx_router = SilentRouter.new()
	func _render_board_state(_state: Dictionary, _presentation: Dictionary, _stable: bool = false) -> void: pass
	func _set_action_banner(_text: String) -> void: pass
	func _animate_guardian_utility(_state: Dictionary, _step: Dictionary, _actor_key: String) -> void: pass
	func _animate_dragon_utility(_state: Dictionary, _step: Dictionary) -> void: pass
	func _play_timed_animation_frames(frame_count: int, _frame_seconds: float, render_frame: Callable) -> void:
		# Authored guardians now dispatch through their real contact callbacks.
		# Run every callback without a SceneTree or wall-clock wait in this host.
		for frame: int in range(1, frame_count + 1): render_frame.call(frame)
	func _animate_floating_text_presentation(_state: Dictionary, presentation: Dictionary, _elapsed: float = 0.0, _overlap: bool = false, _companion: Dictionary = {}) -> void:
		# Contact playback may submit an empty hold; it contains no reward float.
		if not (presentation.get("floating_texts", []) as Array).is_empty(): dispatched.append(presentation.duplicate(true))
	func _play_sfx(entry: Dictionary) -> float:
		sound_ids.append(str(entry.get("id", "")))
		return 0.0

static func fixture(type: String = "zekarion", count: int = 1) -> Dictionary:
	var state: Dictionary = Fixtures.state([Fixtures.enemy(type, 1, TEST_SUMMONER_TILE)], TEST_HERO_TILE)
	Selection.select_summon(Combat.new(), state)
	# Count/cap variants are test actions only; authored production data is untouched.
	var summon: Dictionary = action(state)
	summon["count"] = count
	if count == 2 and summon.has("guardian_cap"): summon.erase("guardian_cap")
	return state

static func action(state: Dictionary) -> Dictionary:
	for value: Dictionary in state["enemies"][0]["intent"]["actions"]:
		if str(value.get("type", "")) == "summon_minions": return value
	return {}

static func resolved(state: Dictionary) -> Dictionary:
	var engine := Combat.new()
	return engine._resolve_enemy_action(state.duplicate(true), 0, action(state))

static func run(expect: Callable) -> void:
	var engine := Combat.new()
	var scene := RunScene.new()
	var board := Board.new()
	for type: String in SUMMONERS:
		for count: int in [1, 2]:
			var before: Dictionary = fixture(type, count)
			var after: Dictionary = resolved(before)
			var label: String = "%s/%d" % [type, count]
			expect.call(after["enemies"].size() - before["enemies"].size() == count, label + " actually brings the requested enemies onto the board")
			expect.call(int(after.get(Rules.PENDING_FIELD, 0)) == 1 and int(after.get("card_play_bonus_this_turn", 0)) == 0, label + " banks exactly one play, never an immediate or per-enemy play")
			var started: Dictionary = engine.prepare_next_player_turn(after)
			expect.call(started[Rules.PENDING_FIELD] == 0 and engine.cards_remaining_this_turn(started) == engine.cards_remaining_this_turn(before) + 1, label + " consumes one next-turn bonus")
			expect.call(engine.prepare_next_player_turn(started)["card_play_bonus_this_turn"] == 0, label + " bonus expires after one turn")
			var step: Dictionary = engine._enemy_action_step(before, after, 0, action(before))
			expect.call(bool(step.get("granted_card_play", false)), label + " records a granted action")
			var events: Array = scene._analytics_enemy_action_events({"steps": [step]}, {})
			expect.call(events.size() == 1 and events[0]["payload"]["granted_card_play"] == true, label + " analytics grants exactly once")
			var options: Dictionary = Rules.forecast_options(engine, before, before["enemies"][0], action(before))
			expect.call(bool(options.get("granted_card_play", false)), label + " forecast agrees with resolution")
			board.combat_state = before
			expect.call(summon_tooltip(board, before).ends_with(Rules.TOOLTIP), label + " real intent tooltip includes the exact line")
			expect.call(Icons.tokens_for_action(action(before), options).size() == Icons.tokens_for_action(action(before)).size(), label + " keeps the intent signals unchanged")
			var feedback: Dictionary = Rules.presentation(scene, after, step)
			var heal: Array = scene._floating_texts_for_step({"kind": "heal", "amount": 1, "tile": after["player"]["pos"]})
			expect.call(feedback["floating_texts"][0]["text"] == "+1 Card Play" and feedback["floating_texts"][0]["color"] == heal[0]["color"] and feedback["floating_texts"][0]["tile"] == after["player"]["pos"], label + " uses exact positive floating text over the hero")
			expect.call((after.get("log", []) as Array).has(Rules.LOG_LINE), label + " logs exact next-turn copy")
	_stacking_and_save(engine, scene, expect)
	_blocked(engine, scene, board, expect)
	_exclusions(engine, scene, expect)
	_production_intents(engine, scene, board, expect)
	_forecast_preparation(engine, board, expect)
	board.free()
	scene.free()

static func _stacking_and_save(engine: RefCounted, scene: Control, expect: Callable) -> void:
	var before: Dictionary = fixture()
	var hidden_after: Dictionary = resolved(before)
	engine._anonymize_hidden_enemy_action_logs(before, hidden_after, 1, action(before), true)
	expect.call(hidden_after["log"].has(Rules.LOG_LINE) and not str(hidden_after["log"].back()).contains("Zekarion"), "Hidden summons preserve exact reward log without revealing their actor")
	var after: Dictionary = resolved(resolved(before))
	expect.call(after[Rules.PENDING_FIELD] == 2, "Two summon moves bank +2")
	after["pending_relic_card_plays"] = 3
	var run: Dictionary = Run.new().create_new_run(TEST_SEED, Store.default_data())
	run["mode"] = "combat"
	run["combat_state"] = after
	var old_path: String = Store._run_storage_path
	Store.set_run_storage_path(TEST_SAVE_PATH)
	expect.call(Store.save_run_state(run), "Pending summon Continue fixture saves through the real store")
	var resumed: Dictionary = Run.new().repair_loaded_run_state(Store.load_saved_run()).get("combat_state", {})
	expect.call(int(resumed.get(Rules.PENDING_FIELD, 0)) == 2, "Continue preserves the separate pending field")
	var started: Dictionary = engine.prepare_next_player_turn(resumed)
	expect.call(started["card_play_bonus_this_turn"] == 5 and started[Rules.PENDING_FIELD] == 0 and started["pending_relic_card_plays"] == 0, "Continue consumes stacked summon and relic bonuses through the shared path")
	var previous_analytics_path: String = Analytics.storage_dir()
	Analytics.set_storage_dir("user://sum01_analytics")
	Analytics.clear_storage()
	scene._run_state = run
	scene._combat_state = started
	scene._analytics_log_enemy_phase_events({"state": started, "player_turn_before_state": resumed, "steps": [engine._enemy_action_step(before, resolved(before), 0, action(before))]})
	expect.call(Analytics.flush_pending_events(true), "Production phase analytics flushes to local JSONL")
	var written: Array = Analytics.load_all_events()
	expect.call(written.size() == 2 and written[0]["payload"]["granted_card_play"] and written[1]["event_type"] == "player_turn_started" and written[1]["payload"]["summon_card_plays"] == 2, "Production JSONL records the grant and turn-start source separately")
	Analytics.clear_storage()
	Analytics.set_storage_dir(previous_analytics_path)
	var events: Array = Rules.turn_start_events({"state": started, "player_turn_before_state": resumed}, {})
	expect.call(events.size() == 1 and events[0]["event_type"] == "player_turn_started" and events[0]["payload"]["summon_card_plays"] == 2, "Turn-start analytics separates summon plays from relic plays")
	resumed["player"]["freeze"] = 1
	var frozen: Dictionary = engine.prepare_next_player_turn(resumed)
	expect.call(frozen["player_turn_restrictions"]["frozen"] and engine.cards_remaining_this_turn(frozen) == 0 and frozen[Rules.PENDING_FIELD] == 0, "Frozen forfeits all summon/relic plays and consumes pending credit")
	expect.call(Rules.turn_start_events({"state": frozen, "player_turn_before_state": resumed}, {})[0]["payload"]["summon_card_plays"] == 2, "Frozen start still reports the consumed summon source")
	var empty_start: Dictionary = engine.prepare_next_player_turn(before)
	expect.call(Rules.turn_start_events({"state": empty_start, "player_turn_before_state": before}, {})[0]["payload"]["summon_card_plays"] == 0, "Ordinary start records zero summon plays")
	var legacy: Dictionary = before.duplicate(true)
	legacy.erase(Rules.PENDING_FIELD)
	expect.call(engine.prepare_next_player_turn(legacy)["card_play_bonus_this_turn"] == 0, "Legacy saves default missing summon plays to zero")
	Store.clear_saved_run()
	Store.set_run_storage_path(old_path)

static func _blocked(engine: RefCounted, scene: Control, board: Control, expect: Callable) -> void:
	for no_tile: bool in [false, true]:
		var before: Dictionary = fixture()
		if no_tile:
			for y: int in range(before["grid"].size()):
				for x: int in range(before["grid"][y].size()): before["grid"][y][x] = "wall"
		else: action(before)["summon_cap"] = 0
		var after: Dictionary = resolved(before)
		expect.call(after["enemies"].size() == before["enemies"].size() and int(after.get(Rules.PENDING_FIELD, 0)) == 0, "Blocked summon gives zero (no tile=%s)" % no_tile)
		board.combat_state = before
		expect.call(not summon_tooltip(board, before).contains(Rules.TOOLTIP), "Blocked summon omits forecast line")
		var step: Dictionary = engine._enemy_action_step(before, after, 0, action(before))
		var events: Array = scene._analytics_enemy_action_events({"steps": [step]}, {})
		expect.call(events.size() == 1 and events[0]["payload"]["granted_card_play"] == false and Rules.presentation(scene, after, step).is_empty(), "Blocked action records false with no reward presentation")
		# No turn-start when a phase never handed control to the player.
		expect.call(Rules.turn_start_events({"state": after}, {}).is_empty(), "No fabricated player start on an incomplete phase")

static func _exclusions(engine: RefCounted, scene: Control, expect: Callable) -> void:
	var death: Dictionary = Fixtures.state([Fixtures.enemy("cinder_ooze", 1, TEST_SUMMONER_TILE)], TEST_HERO_TILE)
	death["enemies"][0]["hp"] = 0
	var split: Dictionary = engine._trigger_enemy_death_spawn(death, death["enemies"][0])
	expect.call(split["enemies"].size() > 1 and int(split.get(Rules.PENDING_FIELD, 0)) == 0, "Death spawns actually enter and grant zero")
	var waves: Dictionary = fixture()
	waves["objective"] = {"type": "survive", "target_clock": 46, "reinforcement_interval": 8, "next_reinforcement_clock": 8, "reinforcement_pool": ["crawler"]}
	waves["initiative_clock"] = 8
	var wave_steps: Array = engine._spawn_due_survival_reinforcements(waves)
	expect.call(wave_steps.size() == 1 and waves["enemies"].size() == 2 and int(waves.get(Rules.PENDING_FIELD, 0)) == 0, "Survive waves actually enter and grant zero")
	for type: String in ["storm_cantor", "last_lamplighter"]:
		var before: Dictionary = GuardianFixtures.new().guardian_fixture(type)
		before["enemies"] = [before["enemies"][0]]
		GuardianFixtures.new().set_cycle(engine,before,2)
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(before,0,true,false)
		expect.call(result["state"]["enemies"].size()==1 and int(result["state"].get(Rules.PENDING_FIELD,0))==0,type+" no automatic replacement remains to grant a play")

static func summon_tooltip(board: Control, state: Dictionary) -> String:
	board.combat_state = state
	for row: Array in board._intent_rows_for_unit(state["enemies"][0], state["enemies"][0]["intent"]):
		for token: Dictionary in row:
			if str(token.get("icon", "")) == "summon_minions": return str(token.get("tooltip", ""))
	return ""

static func _production_intents(engine: RefCounted, scene: Control, board: Control, expect: Callable) -> void:
	for type: String in SUMMONERS:
		var before: Dictionary = GuardianFixtures.new().guardian_fixture(type) if type in ["storm_cantor", "last_lamplighter"] else Fixtures.state([Fixtures.enemy(type, 1, TEST_SUMMONER_TILE)], TEST_HERO_TILE)
		before["enemies"] = [before["enemies"][0]]
		Selection.select_summon(engine, before)
		expect.call((before["enemies"][0]["intent"]["actions"] as Array).any(func(value: Dictionary) -> bool: return str(value.get("type", "")) == "summon_minions"), type + " chooses its authored summon through _assign_enemy_intent")
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0, true, false)
		var after: Dictionary = result["state"]
		var summons: Array = (result["steps"] as Array).filter(func(step: Dictionary) -> bool: return step.get("kind", "") == "summon" and step.get("actor_key", "") == "enemy_1")
		expect.call(after["enemies"].size() == 2 and after.get(Rules.PENDING_FIELD, 0) == 1 and summons.size() == 1 and summons[0]["granted_card_play"], type + " production selected summon actually arrives and pays once")
		expect.call(summon_tooltip(board, before).ends_with(Rules.TOOLTIP), type + " production selected forecast agrees")
		var events: Array = scene._analytics_enemy_action_events(result, {})
		var grants: Array = events.filter(func(event: Dictionary) -> bool: return bool(event["payload"].get("granted_card_play", false)))
		expect.call(grants.size() == 1, type + " production selected analytics grants once")

static func _forecast_preparation(engine: RefCounted, board: Control, expect: Callable) -> void:
	# Reviewer's regression: Fire kills the 1-HP Zekarion before Call Wisps.
	var fire: Dictionary = fixture()
	fire["enemies"].append(Fixtures.enemy("crawler", 2, Vector2i(7, 7)))
	fire["enemies"][0]["hp"] = 1
	Surface.place(fire, TEST_SUMMONER_TILE, "fire", {})
	var snapshot: Dictionary = fire.duplicate(true)
	expect.call(not summon_tooltip(board, fire).contains(Rules.TOOLTIP), "Activation-start Fire death omits the summon reward forecast")
	var after_fire: Dictionary = engine.resolve_enemy_turn_with_steps(fire, 0, true, false)["state"]
	expect.call(after_fire["enemies"][0]["hp"] == 0 and after_fire["enemies"].size() == fire["enemies"].size() and after_fire.get(Rules.PENDING_FIELD, 0) == 0, "Fire regression really kills Zekarion before zero arrivals/credit")
	expect.call(fire == snapshot, "Fire forecast leaves the entire source state, RNG and logs unchanged")
	for status: String in ["freeze", "shock", "petrify"]:
		var held: Dictionary = fixture("storm_cantor")
		held["enemies"][0][status] = 1
		var original: Dictionary = held.duplicate(true)
		expect.call(not summon_tooltip(board, held).contains(Rules.TOOLTIP), "Forecast respects activation status: " + status)
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(held, 0, true, false)
		expect.call(result["state"]["enemies"].size() == held["enemies"].size() and result["state"].get(Rules.PENDING_FIELD, 0) == 0, "Status really prevents summon: " + status)
		expect.call(held == original, "Forecast does not consume source status: " + status)
	var immobile: Dictionary = fixture("storm_cantor")
	immobile["enemies"][0]["immobilize"] = true
	expect.call(summon_tooltip(board, immobile).ends_with(Rules.TOOLTIP), "Immobilized still permits the summon action")
	var immune: Dictionary = fixture()
	immune["enemies"][0]["shock"] = 1
	expect.call(summon_tooltip(board, immune).ends_with(Rules.TOOLTIP), "Forecast normalizes Zekarion's Shock immunity like production")
	var gated: Dictionary = fixture()
	action(gated)["requires_surface"] = {"subject": "player", "surface": "ice"}
	expect.call(not summon_tooltip(board, gated).contains(Rules.TOOLTIP), "Forecast respects the summon action's surface gate")
	var successive: Dictionary = fixture()
	var first: Dictionary = action(successive).duplicate(true)
	first["summon_cap"] = 1
	var second: Dictionary = first.duplicate(true)
	successive["enemies"][0]["intent"]["actions"] = [first, second]
	expect.call(Rules.forecast_options(engine, successive, successive["enemies"][0], first, 0).get("granted_card_play", false), "First identical summon forecasts a real arrival")
	expect.call(not Rules.forecast_options(engine, successive, successive["enemies"][0], second, 1).get("granted_card_play", false), "Second identical summon rechecks the cap after preceding action")

static func run_dispatch(expect: Callable) -> void:
	var engine := Combat.new()
	for type: String in SUMMONERS:
		var before: Dictionary = fixture(type)
		var result: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0, true, false)
		var summons: Array = (result["steps"] as Array).filter(func(step: Dictionary) -> bool: return step.get("kind", "") == "summon")
		expect.call(summons.size() == 1, type + " dispatch fixture uses the resolved production summon step")
		var host := FloatDispatchScene.new()
		host._combat_state = before.duplicate(true)
		await host._animate_enemy_phase_steps(before.duplicate(true), summons)
		var floats: Array[Dictionary]
		for feedback: Dictionary in host.dispatched:
			for entry: Dictionary in feedback.get("floating_texts", []): floats.append(entry)
		expect.call(floats.size() == 1 and floats[0].get("text", "") == "+1 Card Play" and floats[0].get("tile") == before["player"]["pos"], type + " production dispatcher submits exactly one +1 Card Play over the hero")
		expect.call(host.sound_ids.is_empty(), type + " reward dispatch adds no sound")
		host.dispatched.clear()
		var unpaid: Dictionary = summons[0].duplicate(true)
		unpaid["granted_card_play"] = false
		await host._animate_enemy_phase_steps(before.duplicate(true), [unpaid])
		expect.call(host.dispatched.is_empty(), type + " unpaid summon dispatch has no reward float")
		host.free()
