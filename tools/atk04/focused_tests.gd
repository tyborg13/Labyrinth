extends "res://tests/run_tests.gd"
## atk-04 focused proof (not in the default groups): the atk-03 forecast set, the
## Umbra information-boundary scene tests the forecast source touches, and the
## atk-04 wording rules (unseen ground, new foes, dead foes' stale entries).
const Source = preload("res://scripts/pass_forecast_action_source.gd")
const Fixtures = preload("res://tools/ptf07/forecast_cases.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")

func _initialize() -> void:
	_initialize_test_storage()
	preload("res://tests/suites/turn_clock_wait_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/enemy_intent_preview_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/lethal_preview_suite.gd").run(Callable(self, "_assert"))
	preload("res://tests/suites/bos01_feedback2_suite.gd").run(Callable(self, "_assert"))
	InitiativeOrderSuite.run(Callable(self, "_assert"))
	_test_umbra_hides_targets_intents_and_turn_order_identity()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	preload("res://tests/suites/turn_clock_hud_suite.gd")._test_forecasts(scene, Callable(self, "_assert"))
	preload("res://tests/suites/turn_clock_hud_review_suite.gd")._test_forecast_copy(scene, Callable(self, "_assert"))
	preload("res://tools/ptf08/row_tests.gd").run(scene, Callable(self, "_assert"))
	_atk04_rows(scene)
	_atk04_new_arrivals(scene)
	_atk04_dead_queue()
	scene.free()
	await _test_run_scene_pass_preview_chip_updates()
	await _test_run_scene_umbra_move_shortcuts_do_not_reveal_hidden_targets()
	await _test_run_scene_umbra_preview_effects_do_not_reveal_hidden_state()
	await _test_run_scene_umbra_aoe_centers_allow_hidden_pattern_occupants()
	for message: String in _failures:
		print("FAIL: " + message)
	print("ATK04 FOCUSED RESULT: %s (%d assertions, %d failures)" % ["PASS" if _failures.is_empty() else "FAIL", _assertion_count, _failures.size()])
	quit(0 if _failures.is_empty() else 1)

# Decisions 2 and 3: never Safe with unseen ground; losses stay, then one Umbra "?".
func _atk04_rows(scene: Node) -> void:
	_assert(Rows.text(scene, {"unseen_ground_crossed": true}) == "umbra:?", "Unseen ground replaces Safe with the Umbra '?' row")
	_assert(Rows.text(scene, {"unseen_ground_crossed": true, "hp_loss": 5, "block_loss": 2}) == "block:−2 health:−5\numbra:?", "Unseen ground keeps the known losses, then the Umbra '?'")
	_assert(Rows.text(scene, {"unseen_ground_crossed": true, "umbra_unknown_before_player": true}) == "umbra:?", "Unseen ground and hidden foes share one Umbra '?' row")
	# Round 2 (director): "Safe" never sits beside any "?" row.
	_assert(Rows.text(scene, {"umbra_unknown_before_player": true}) == "umbra:?", "Hidden foes: the Umbra '?' alone, no Safe")
	_assert(Rows.text(scene, {"new_arrival_before_player": true, "forecast_limit_reached": true}) == "turn_clock:?", "A new foe and the forecast limit share one turn-clock '?' row, no Safe")
	_assert(Rows.text(scene, {"forecast_limit_reached": true}) == "turn_clock:?", "The forecast limit alone: no Safe")
	var portraits: Array[Dictionary]
	portraits.append({"actor_key": "enemy:a", "path": "res://assets/art/portraits/tunnel_crawler.png", "aspect": 4.0 / 3.0})
	_assert(Rows.text(scene, {}, portraits) == "portrait:enemy:a :×2 :?", "An unknown repeat ('×2 ?') alone: no Safe")
	var counted: Array[Dictionary]
	counted.append({"actor_key": "enemy:a", "path": "res://assets/art/portraits/tunnel_crawler.png", "aspect": 4.0 / 3.0, "counted": true, "count": 2})
	_assert(Rows.text(scene, {}, counted) == ":Safe\nportrait:enemy:a :×2", "A counted repeat that loses nothing stays Safe (no '?')")

# Decision 4: a visible summon or split is a new foe, not the Umbra.
func _atk04_new_arrivals(scene: Node) -> void:
	var engine: RefCounted = preload("res://scripts/combat_engine.gd").new()
	for kind: String in ["death_spawn", "reinforcements", "reinforcements_after", "umbra", "missing_intent"]:
		var source: Dictionary = Fixtures.fixture(kind)
		var forecast: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(engine.finish_player_activation(source), true)
		var summary: Dictionary = scene.call("_pass_preview_summary_for_phase_result", source, forecast)
		var rows: String = Rows.text(scene, summary)
		var tooltip: String = str(scene.call("_pass_preview_tooltip", summary))
		var lit: bool = engine.effective_umbra_radius(source) >= engine.UMBRA_UNLIMITED_RADIUS
		if kind in ["death_spawn", "reinforcements", "reinforcements_after"]:
			_assert(lit and bool(summary.get("new_arrival_before_player", false)) and bool(summary.get("unrevealed_before_player", false)), kind + ": a visible new foe is flagged as new and still unknown")
			_assert(rows.contains("turn_clock:?") and not rows.contains("umbra:?"), kind + ": the turn-clock '?' row, not the Umbra row: " + rows)
			_assert(tooltip.contains("A new foe acts before you.") and not tooltip.contains("Foes hidden in the Umbra"), kind + ": new-foe line only: " + tooltip)
			_assert(str(summary.get("tone", "")) != "safe", kind + ": a new foe never reads safe")
		else:
			_assert(not bool(summary.get("new_arrival_before_player", false)) and bool(summary.get("umbra_unknown_before_player", false)) and rows.contains("umbra:?"), kind + ": a hidden or already-present unplanned foe keeps the Umbra '?': " + rows)

# Decision 5: a dead foe's stale entry is not a hidden foe.
func _atk04_dead_queue() -> void:
	var boundary: Dictionary = {"initial_state": {"turn_queue": [{"kind": "player", "time": 20, "seq": 9}]}}
	var stale: Dictionary = {"_pass_forecast_limited": true, "_pass_forecast_hidden_queue": [{"time": 5, "seq": 1, "alive": false}]}
	_assert(not Source.hidden_horizon(stale, boundary), "A dead foe's stale queue entry raises no Umbra '?'")
	var living: Dictionary = {"_pass_forecast_limited": true, "_pass_forecast_hidden_queue": [{"time": 5, "seq": 1, "alive": false}, {"time": 7, "seq": 2, "alive": true}]}
	_assert(Source.hidden_horizon(living, boundary), "A living hidden foe before you still raises the Umbra '?'")
