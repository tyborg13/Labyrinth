extends SceneTree
const Fixtures = preload("res://tests/fixtures/bos01_rule_fights.gd")
const Rules = preload("res://scripts/battlefield_rules/dispatcher.gd")
const Core = preload("res://tests/suites/bos01_rules_suite.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const AUDIO_TEARDOWN_SETTLE_SECONDS: float = 0.1
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	var engine := preload("res://scripts/combat_engine.gd").new()
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	for case_name: String in Fixtures.CASES:
		var state: Dictionary = Fixtures.battle(engine, case_name)
		scene.call("_load_run_state", Fixtures.run_state(state))
		scene.call("_close_dialogue")
		await process_frame
		var hud: Control = scene.get("_battlefield_rule_hud")
		_expect(hud.find_child("RuleSentence", true, false).text == state["battlefield_rule"]["sentence"], "BOS01 real HUD uses instance sentence")
		if case_name != "half_health":
			scene.call("_render_board_state", state, {})
			var ghosts: Array[Dictionary] = WindView.landing_ghosts(scene.get("board_view"))
			_expect(not ghosts.is_empty(), "BOS01 new Gust dial has existing landing ghosts: " + case_name)
			continue
		var banner: Control = scene.get("_turn_banner")
		banner.hide()
		var hypothetical: Dictionary = engine._damage_enemy(state.duplicate(true), 0, ceili(float(state["enemies"][0]["max_hp"]) / 2.0), false)
		scene.call("_refresh_battlefield_rule_hud", hypothetical)
		_expect(not banner.visible, "BOS01 hypothetical preview never plays a switch banner")
		state = Core.committed_damage(engine, state, 0, ceili(float(state["enemies"][0]["max_hp"]) / 2.0), false)
		scene.get("_run_state")["combat_state"] = state
		scene.set("_combat_state", state)
		scene.call("_render_board_state", state, {})
		_expect(hud.find_child("RuleSentence", true, false).text == Fixtures.HALF_HEALTH_SENTENCE, "BOS01 half Health refreshes the actual rule panel")
		_expect(banner.visible and banner.get("_label").text == "VAELORYX GROWS FIERCER", "BOS01 actual TurnBanner displays the switch with the short name")
		var rail_beats: Array = scene.get("_turn_order_all_entries").filter(func(entry: Dictionary) -> bool: return entry.get("kind", "") == "beat")
		_expect(not rail_beats.is_empty() and rail_beats[0]["sentence"] == Fixtures.HALF_HEALTH_SENTENCE, "BOS01 actual turn clock redraws the switched rule")
		var tween: Tween = banner.get("_tween")
		scene.call("_refresh_battlefield_rule_hud", state)
		_expect(banner.get("_tween") == tween, "BOS01 repeat HUD refresh never repeats the switch banner")
		scene.call("_load_run_state", Fixtures.run_state(state))
		_expect(not banner.visible and banner.get("_tween")==null, "BOS04 Continue clears a still-showing half-Health banner and tween before its first frame")
		_expect(not tween.is_valid(), "BOS04 reset kills the retained half-Health Tween, rather than only dropping its reference")
		scene.call("_refresh_battlefield_rule_hud", state)
		_expect(not banner.visible, "BOS01 Continue keeps the switched sentence without replaying its banner")
		_check_analytics_callers(scene, state)
	_test_consecutive_fights(scene, engine)
	preload("res://tests/suites/bos01_feedback2_suite.gd").scene_previews(scene, _expect)
	await _test_fresh_continue(engine)
	for frame: int in range(6): await process_frame
	scene.queue_free()
	await process_frame
	await create_timer(AUDIO_TEARDOWN_SETTLE_SECONDS).timeout
	for failure: String in failures: push_error(failure)
	print("BOS01 RULE SCENE RESULT: %s (%d checks, %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _test_fresh_continue(engine: RefCounted) -> void:
	var state: Dictionary = Fixtures.battle(engine, "half_health")
	state = Core.committed_damage(engine, state, 0, 29, false)
	var path: String = "user://bos01-fresh-continue.save"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_var(Fixtures.run_state(state)); file.close()
	var loaded: Dictionary = preload("res://scripts/progression_store.gd")._load_run_dictionary(path)
	_expect(bool(loaded["combat_state"]["battlefield_rule"].get("half_health_switched", false)) and loaded["combat_state"]["surface_event_sequence"] > 0, "BOS01 F2 fresh Continue fixture contains the saved switch")
	var fresh: Control = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	var banner: Control = fresh.get("_turn_banner")
	banner.hide()
	fresh.call("_load_run_state", loaded)
	fresh.call("_refresh_battlefield_rule_hud", fresh.get("_combat_state"))
	_expect(not banner.visible, "BOS01 F2 fresh Continue baselines the saved switch before any observation")
	_expect(fresh.get("_battlefield_rule_hud").find_child("RuleSentence", true, false).text == Fixtures.HALF_HEALTH_SENTENCE, "BOS01 F2 fresh Continue preserves the switched sentence")
	for frame: int in range(6): await process_frame
	fresh.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _enter_normal_fight(scene: Control, state: Dictionary) -> Dictionary:
	var previous: Dictionary = scene.get("_run_state").duplicate(true)
	previous["mode"] = "room"
	scene.set("_run_state", Fixtures.run_state(state))
	# Exercise the actual entry boundary, rather than Continue's _load_run_state.
	scene.call("_analytics_log_combat_transition", previous, "bos01_feedback1", state)
	var entered: Dictionary = scene.get("_combat_state")
	scene.call("_refresh_battlefield_rule_hud", entered)
	return entered

func _test_consecutive_fights(scene: Control, engine: RefCounted) -> void:
	var banner: Control = scene.get("_turn_banner")
	var first: Dictionary = Fixtures.battle(engine, "half_health")
	first["surface_event_sequence"] = 20
	first["surface_events"] = [{"kind": "bos01_cursor_fixture", "sequence": 20}]
	first = _enter_normal_fight(scene, first)
	banner.hide()
	first = Core.committed_damage(engine, first, 0, 29, false)
	scene.set("_combat_state", first)
	scene.get("_run_state")["combat_state"] = first
	scene.call("_refresh_battlefield_rule_hud", first)
	_expect(banner.visible and first["surface_event_sequence"] == 21, "BOS01 F1 first live fight shows its switch above sequence 20")
	var second: Dictionary = _enter_normal_fight(scene, Fixtures.battle(engine, "half_health"))
	_expect(not banner.visible and banner.get("_tween")==null, "BOS04 new fight clears the prior fight's live half-Health banner and tween")
	second = Core.committed_damage(engine, second, 0, 29, false)
	scene.set("_combat_state", second)
	scene.get("_run_state")["combat_state"] = second
	scene.call("_refresh_battlefield_rule_hud", second)
	_expect(banner.visible and second["surface_event_sequence"] == 1, "BOS01 F1 second live fight shows its sequence-one switch banner")
	banner.hide()
	scene.call("_load_run_state", scene.get("_run_state").duplicate(true))
	scene.call("_refresh_battlefield_rule_hud", scene.get("_combat_state"))
	_expect(not banner.visible, "BOS01 F1 Continue after the second fight does not replay its banner")
	# Re-observe the committed event to hold a banner across a real end boundary.
	scene.get("_battlefield_rule_switch").baseline({"surface_event_sequence":0})
	scene.call("_refresh_battlefield_rule_hud", second)
	_expect(banner.visible, "BOS04 end-boundary regression begins with a showing banner")
	var previous: Dictionary = scene.get("_run_state").duplicate(true)
	var defeated: Dictionary = second.duplicate(true)
	defeated["enemies"][0]["hp"] = 0
	scene.get("_run_state")["mode"] = "room"
	scene.call("_analytics_log_combat_transition", previous, "bos04_fight_end", defeated)
	_expect(not banner.visible and banner.get("_tween")==null, "BOS04 fight end clears its half-Health banner and tween immediately")
	scene.call("_refresh_battlefield_rule_hud", defeated)
	_expect(not banner.visible, "BOS04 a retained outcome board never replays the ended fight's banner")

func _check_analytics_callers(scene: Control, state: Dictionary) -> void:
	var store: GDScript = preload("res://scripts/analytics_store.gd")
	var previous: String = store.storage_dir()
	store.set_storage_dir("user://bos01-analytics")
	state["analytics"] = {"combat_id": "bos01-scene"}
	var run: Dictionary = Fixtures.run_state(state)
	for caller: String in ["UI", "console"]:
		store.clear_storage()
		var host = scene if caller == "UI" else preload("res://tools/headless_playtest.gd").new()
		host.set("_analytics_store", store.new())
		host.set("_progression", run["progression"].duplicate(true))
		host.set("_run_state", run)
		for retry: int in range(2):
			if caller == "UI": host.call("_analytics_flush_surface_events", state)
			else: host.call("_log_combat_transition", run, "bos01_fixture", state)
		var switches: Array = store.load_all_events().filter(func(event: Dictionary) -> bool: return str(event["event_type"]) == "battlefield_rule_switched")
		_expect(switches.size() == 1 and switches[0]["payload"]["source_type"] == "vaeloryx", "BOS01 switch JSONL is committed and retry-safe in " + caller)
		if caller == "console": host.free()
	store.clear_storage()
	store.set_storage_dir(previous)

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
