extends "res://tests/run_tests.gd"
## atk-07 proof (not a test; never in the default groups): the PASS forecast
## plays through a hero turn Freeze skips on its own copy and matches the live
## committed path over the whole span; a turn that is already Frozen keeps its
## old forecast; the live state is never touched; the panel header row and the
## Umbra horizon follow the span.
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const Committed = preload("res://scripts/battlefield_rules/committed.gd")
const ForecastRows = preload("res://scripts/pass_forecast_focus_tooltip.gd")
const Source = preload("res://scripts/pass_forecast_action_source.gd")
const Palette = preload("res://scripts/ui_palette.gd")
const HeroFacingCombat = preload("res://scripts/hero_facing_combat.gd")

func _initialize() -> void:
	_initialize_test_storage()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	# Production's engine (the full turn-start path) and the plain engine (the
	# compact draw-only subset) both forecast the span.
	for engine: RefCounted in [scene.get("_combat_engine"), CombatEngine.new()]:
		_freezing_hit(scene, engine)
		_already_frozen(scene, engine)
	scene.free()
	_rows_and_horizon()
	for message: String in _failures:
		print("FAIL: " + message)
	print("ATK07 PROOF RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

# A hero carrying Freeze into the enemy phase (as a Frostbite beat leaves it)
# beside a crawler: the crawler hits, the next hero turn is skipped, and the
# crawler acts again before the hero can. Real-fight freezes (Rimejaw, Iskaldra)
# are covered by the atk-07 audit and native captures.
func _fixture() -> Dictionary:
	var state: Dictionary = Fixtures._pass_preview_chip_state("default")
	state["player"]["freeze"] = 1
	state["player"]["hp"] = 60
	state["player"]["max_hp"] = 60
	return state

func _live_span(engine: RefCounted, state: Dictionary) -> Dictionary:
	var phase: Dictionary = state.duplicate(true)
	var skipped: int = 0
	var safety: int = 0
	var first_hp: int = -1
	while engine.combat_outcome(phase).is_empty() and engine.is_player_turn(phase) and safety < 200:
		phase = Committed.finish_player_activation(engine, phase)
		while engine.combat_outcome(phase).is_empty() and safety < 200:
			safety += 1
			var slice: Dictionary = Committed.advance_one_activation(engine, phase, false)
			phase = slice.get("state", phase)
			if bool(slice.get("complete", false)): break
		if first_hp < 0: first_hp = int(phase["player"]["hp"])
		if not bool((phase.get("player_turn_restrictions", {}) as Dictionary).get("frozen", false)) or not engine.combat_outcome(phase).is_empty(): break
		skipped += 1
	return {"state": phase, "skipped": skipped, "first_hp": first_hp}

func _forecast(scene: Node, engine: RefCounted, state: Dictionary) -> Dictionary:
	var phase_result: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(engine.finish_player_activation(state), true)
	scene.set("_combat_engine", engine)
	return {"phase": phase_result, "summary": scene.call("_pass_preview_summary_for_phase_result", state, phase_result)}

func _freezing_hit(scene: Node, engine: RefCounted) -> void:
	var label: String = engine.get_script().resource_path.get_file()
	var state: Dictionary = _fixture()
	var untouched: Dictionary = state.duplicate(true)
	var live: Dictionary = _live_span(engine, state)
	var live_state: Dictionary = live["state"]
	_assert(int(live["skipped"]) == 1, label + ": live play skips the hero turn after the freezing Claw")
	var forecast: Dictionary = _forecast(scene, engine, state)
	var summary: Dictionary = forecast["summary"]
	var phase: Dictionary = forecast["phase"]
	_assert(state == untouched, label + ": the forecast never touches the live state")
	_assert(int(summary.get("skipped_turns", 0)) == 1, label + ": the forecast covers the skipped turn")
	var lost: int = int(state["player"]["hp"]) - int(live_state["player"]["hp"])
	var first_round: int = int(state["player"]["hp"]) - int(live["first_hp"])
	print("ATK07 PROOF %s: forecast %d, live span %d, live up to the frozen turn %d" % [label, int(summary.get("hp_loss", -1)), lost, first_round])
	_assert(int(summary.get("hp_loss", -1)) == lost, label + ": the forecast's Health loss is the whole span (%d forecast, %d live)" % [int(summary.get("hp_loss", -1)), lost])
	_assert(lost > first_round, label + ": the round after the skipped turn hurts too (the case the old forecast missed)")
	_assert((phase["state"] as Dictionary)["player"]["pos"] == live_state["player"]["pos"] and int((phase["state"] as Dictionary).get("turn", 0)) == int(live_state.get("turn", 0)), label + ": the forecast ends at the turn the hero can act")
	# Production prepares every forecast turn in full; the plain engine's compact
	# draw-only result keeps the skipped turn's restriction fields (never committed).
	if engine is HeroFacingCombat:
		_assert(not bool(((phase["state"] as Dictionary).get("player_turn_restrictions", {}) as Dictionary).get("frozen", false)), label + ": the forecast's last hero entry is playable")
	print("ATK07 PROOF %s: activations %s hits %s counted %s" % [label, str(summary.get("enemy_activations", {})), str(summary.get("enemy_hits", {})), str(summary.get("counted_repeats", []))])
	_assert(int((summary.get("enemy_activations", {}) as Dictionary).get("enemy_1", 0)) >= 2 and (summary.get("enemy_hits", {}) as Dictionary).has("enemy_1"), label + ": the crawler's activations on both sides of the skipped turn and its hits cover the span")
	_assert(str(summary.get("tone", "")) == "danger", label + ": the span's loss sets the danger tone")

# A turn that is already Frozen: its PASS forecast is unchanged (no skip).
func _already_frozen(scene: Node, engine: RefCounted) -> void:
	var label: String = engine.get_script().resource_path.get_file()
	var state: Dictionary = Fixtures._pass_preview_chip_state("default")
	state["player_turn_restrictions"] = {"frozen": true, "shocked": false, "immobilized": false}
	state["cards_played_this_turn"] = int(state.get("cards_per_turn", 2))
	state["plays_forfeited_this_turn"] = int(state.get("cards_per_turn", 2))
	var live: Dictionary = _live_span(engine, state)
	var summary: Dictionary = _forecast(scene, engine, state)["summary"]
	_assert(int(live["skipped"]) == 0 and int(summary.get("skipped_turns", -1)) == 0, label + ": a Frozen turn's PASS forecast has no skipped turn")
	_assert(int(summary.get("hp_loss", -1)) == int(state["player"]["hp"]) - int((live["state"] as Dictionary)["player"]["hp"]), label + ": a Frozen turn's PASS forecast matches live play")

func _rows_and_horizon() -> void:
	var one: Dictionary = ForecastRows.turn_skipped_row(1)
	var two: Dictionary = ForecastRows.turn_skipped_row(2)
	var ends: Dictionary = ForecastRows.ends_turn_row()
	_assert(one["parts"][0]["icon"] == "freeze" and one["parts"][0]["text"] == "Turn skipped" and one["parts"][0]["color"] == Palette.GOLD_BRIGHT, "one skipped turn: the Freeze icon and 'Turn skipped' in gold")
	_assert(two["parts"][0]["text"] == "Turn skipped ×2", "two skipped turns read 'Turn skipped ×2'")
	_assert(ends["parts"][0]["color"] == one["parts"][0]["color"] and ends["parts"].size() == one["parts"].size(), "the header rows share the Ends turn row's style")
	# A hidden foe due after the first hero entry but before the span's end acts in the span.
	var source: Dictionary = {"_pass_forecast_limited": true, "_pass_forecast_hidden_queue": [{"time": 15, "seq": 3, "alive": true}]}
	var phase: Dictionary = {"initial_state": {"turn_queue": [{"kind": "player", "time": 10, "seq": 1}]}}
	_assert(not Source.hidden_horizon(source, phase), "without a skipped turn the hidden foe acts after the hero")
	phase["span_boundary"] = {"time": 20, "seq": 5}
	_assert(Source.hidden_horizon(source, phase), "through a skipped turn the hidden foe acts inside the span (Umbra '?')")
