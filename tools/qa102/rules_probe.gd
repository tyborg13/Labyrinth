extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Schedule = preload("res://scripts/pass_forecast_red_tiles.gd")
const Unseen = preload("res://scripts/pass_forecast_unseen_ground.gd")
const Fixtures = preload("res://tools/ptf07/fixtures.gd")
const Rows = preload("res://tools/ptf08/row_tests.gd")
const SnareFixtures = preload("res://tests/suites/snare_pressure_suite.gd")
const Surfaces = preload("res://scripts/board_surface_rules.gd")
const SPLIT_FOE_TILE := Vector2i(3, 4)
const SPLIT_FOE_HP: int = 1
const WORLDHEART_BLOCK: int = 2
const LONG_WAIT: int = 30
const LATE_TIME: int = 10000
const FROSTBITE_FOE_TILE := Vector2i(6, 2)
var failures: int
var expected_disclosure: bool

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	expected_disclosure = args[1] == "yes"
	var file := FileAccess.open(args[0], FileAccess.READ)
	if file == null:
		push_error("QA102 rules save not found")
		quit(1)
		return
	var engine := Combat.new()
	var scene: Node = preload("res://scripts/run_scene.gd").new()
	var run: Dictionary = file.get_var(false)
	file.close()
	var source: Dictionary = run["combat_state"]
	var scheduled: Dictionary = Schedule.schedule(engine, source)
	var hunter: Dictionary = scheduled["enemies"].back()
	check(hunter.get("snare_hunter", false) and engine._enemy_index_for_id(source, int(hunter["id"])) == -1, "saved source schedules a new hunter")
	var visible: Dictionary = engine.umbra_visible_tile_lookup(source)
	check(visible.has(hunter["pos"]), "repro hunter spawn is visible")
	for sight: String in ["visible", "hidden"]:
		var input: Dictionary = source.duplicate(true)
		input[Unseen.VISIBLE_KEY] = visible.duplicate()
		if sight == "hidden": input[Unseen.VISIBLE_KEY].erase(hunter["pos"])
		var scheduled_input: Dictionary = Schedule.schedule(engine, input)
		check(Unseen.arrival_visible(engine, scheduled_input, hunter) == (sight == "visible"), "spawn visibility matches " + sight)
		verify(engine, scene, input, scheduled_input, sight, 1)
	if args.size() > 2:
		var hidden_run: Dictionary = run.duplicate(true)
		var hidden_state: Dictionary = hidden_run["combat_state"]
		hidden_state["umbra"] = {"stage": engine.UMBRA_STAGE_ECLIPSE}
		check(not engine.is_tile_visible_to_player(hidden_state, hunter["pos"]), "Eclipse fixture hides the spawn")
		var hidden_file := FileAccess.open(args[2], FileAccess.WRITE)
		if hidden_file != null:
			hidden_file.store_var(hidden_run)
			hidden_file.close()
		else:
			check(false, "write Eclipse fixture")
	var late: Dictionary = scheduled.duplicate(true)
	for entry: Dictionary in late["turn_queue"]:
		if int(entry.get("enemy_id", -1)) == int(hunter["id"]): entry["time"] = LATE_TIME
	verify(engine, scene, source, late, "hunter-after-hero", 0)
	var split: Dictionary = Fixtures._pass_preview_chip_state("danger")
	split["relics"] = ["worldheart"]
	split["player"]["block"] = WORLDHEART_BLOCK
	split["player_turn_time_spent"] = LONG_WAIT
	split["enemies"][0].merge({"type": "cinder_ooze", "pos": SPLIT_FOE_TILE, "hp": SPLIT_FOE_HP}, true)
	verify(engine, scene, split, Schedule.schedule(engine, split), "worldheart-split", 2)
	var frostbite: Dictionary = SnareFixtures.battle("ice")
	frostbite["player_turn_time_spent"] = LONG_WAIT
	frostbite["enemies"][0].merge({"type": "cinder_ooze", "pos": FROSTBITE_FOE_TILE, "hp": SPLIT_FOE_HP, "block": 0, "stoneskin": 0, "summoned": false}, true)
	frostbite["enemies"][0].erase("snare_sealbinder")
	Surfaces.place(frostbite, FROSTBITE_FOE_TILE, "ice")
	var frostbite_scheduled: Dictionary = Schedule.schedule(engine, frostbite)
	verify(engine, scene, frostbite, frostbite_scheduled, "snare-frostbite-split", 2)
	scene.free()
	print("QA102 RULES: %d failures" % failures)
	quit(0 if failures == 0 else 1)

func verify(engine: RefCounted, scene: Node, source: Dictionary, scheduled: Dictionary, label: String, expected_count: int) -> void:
	var snapshot: Dictionary = scheduled.duplicate(true)
	var phase: Dictionary = engine.preview_revealed_enemy_actions_before_player_turn_with_steps(scheduled, true)
	var result: Dictionary = scene._pass_preview_summary_for_phase_result(source, phase)
	var actual: Dictionary = engine.advance_to_next_player_turn_with_steps(scheduled)
	var arrivals: Dictionary = {}
	for step: Dictionary in actual["steps"]:
		if step.get("kind") != "intent": continue
		var actor: String = str(step.get("actor_key", ""))
		if actor.begins_with("enemy_") and engine._enemy_index_for_id(source, int(actor.trim_prefix("enemy_"))) < 0:
			arrivals[actor] = true
	var flag: bool = result["new_arrival_before_player"]
	check(arrivals.size() == expected_count, label + ": live arrival count")
	check(flag == (expected_disclosure and expected_count > 0), label + ": turn-clock flag")
	check(Rows.text(scene, result).contains("turn_clock:?") == flag, label + ": turn-clock row")
	check(snapshot == scheduled, label + ": cursor preserves scheduled input")
	print("QA102 RULES case=%s arrivals=%s clock=%s health=%d actual_net_loss=%d" % [
		label, arrivals.keys(), flag, result["non_fatigue_hp_loss"], int(source["player"]["hp"]) - int(actual["state"]["player"]["hp"]),
	])

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		print("FAIL: " + message)
