extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/en01_enemies_suite.gd")
const Live = preload("res://tests/suites/movement_undo_suite.gd")
const Playback = preload("res://tests/helpers/brs02_playback_scene.gd")
# Invisible test defaults: surviving hero, two adjacent Burst victims.
const HERO_HP: int = 60
const SOURCE := Vector2i(3, 3)
const HERO := Vector2i(4, 4)
const BLEED: int = 3
const CHAIN_HP: int = 4
const TRIGGER_DAMAGE: int = 6
const WITNESS := Vector2i(5, 4)
const DIRECTOR_SEED: int = 83
const FORCE_WITNESS := Vector2i(5, 3)
const ERUPT_ORIGIN := Vector2i(2, 3)
const ERUPT_CENTER := Vector2i(3, 3)
const RETALIATE_TICK := Vector2i(3, 4)
const RETALIATE_FIRE := Vector2i(2, 4)
const PROJECTION_SAMPLE_FRAMES: int = 3
const MOTION_PART_ALL: int = -1
const MOTION_PART_NORMAL: int = 0
const MOTION_PART_REDUCED: int = 1
var _motion_part: int = MOTION_PART_ALL
var failures: Array[String]
var checks: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if OS.get_cmdline_user_args().has("--motion-part-0"): _motion_part = MOTION_PART_NORMAL
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = root.size
	_run.call_deferred()

func _run() -> void:
	Live.prepare_storage()
	var raw: Control = load("res://scenes/run_scene.tscn").instantiate()
	raw.set_script(Playback)
	var scene := raw as Playback
	root.add_child(scene)
	await Live.settle(self)
	_configure_scene(scene)
	if _motion_part != MOTION_PART_REDUCED: _projection_cost_guard()
	process_frame.connect(scene.sample_frame)
	for reduced: bool in [false, true]:
		# Every route installs its own combat. Each motion partition still uses
		# the real pacing/playback clocks and samples every submitted state.
		if _motion_part != MOTION_PART_ALL and int(reduced) != _motion_part: continue
		Live.set_reduced_motion(scene, reduced)
		if not OS.get_cmdline_user_args().has("--feedback-only"):
			await _bleed(scene, reduced)
			await _director_pass(scene, reduced)
			for route: String in ["fire", "retaliate", "hidden_bleed", "player_card"]:
				await _route(scene, route, reduced)
			await _hidden_cascades(scene, reduced)
			await _trap_cascade(scene, reduced)
		for route: String in ["room_wind", "enemy_wind", "push", "pull", "force_area_push", "force_area_pull", "swap", "retaliate_push", "erupt_push", "upheaval_push"]:
			await _forced_movement(scene, route, reduced)
		await _identical_fights(scene, reduced)
	process_frame.disconnect(scene.sample_frame)
	await _finish_proof(scene)
	scene.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("BRS02 FOCUSED RESULT: %s (%d checks; %d failures)" % ["PASS" if failures.is_empty() else "FAIL", checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _configure_scene(_scene: Playback) -> void:
	pass

func _finish_proof(_scene: Playback) -> void:
	pass

func _bleed(scene: Playback, reduced: bool) -> void:
	var before: Dictionary = Fixture.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	before["player"]["hp"] = HERO_HP
	before["player"]["max_hp"] = HERO_HP
	before["player"]["pos"] = HERO
	for index: int in range(3):
		before["enemies"][index]["pos"] = SOURCE + Vector2i(index, 0)
		before["enemies"][index]["hp"] = 1
		before["enemies"][index]["bleed"] = BLEED
	before["enemies"][3]["pos"] = Vector2i(5, 4)
	var phase: Dictionary = Combat.new().resolve_enemy_turn_with_steps(before, 0)
	var after: Dictionary = phase["state"]
	Live.install(scene, before.duplicate(true))
	scene.set("_animation_lock", true)
	scene.begin_recording("bleed reduced=%s" % reduced)
	scene._render_board_state(before, {})
	var animated: Dictionary = before.duplicate(true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_enemies()
	await scene._animate_enemy_phase_steps(animated, phase["steps"])
	await pacing.finish_enemies()
	scene._render_board_state(after, {})
	scene.recording = false
	_check_path(scene.samples, before, after, "bleed reduced=%s" % reduced)

func _director_pass(scene: Playback, reduced: bool) -> void:
	var engine := preload("res://scripts/run_engine.gd").new()
	var run: Dictionary = preload("res://tools/hoarder_inspection.gd").build(engine, Combat.new(), engine.create_new_run(DIRECTOR_SEED, preload("res://scripts/progression_store.gd").default_data()), {"hoarder_biome": "fire", "hoarder_tier": 2, "hoarder_case": "encounter", "seed": DIRECTOR_SEED})
	var before: Dictionary = run["combat_state"]
	before["player"]["hp"] = HERO_HP
	before["player"]["max_hp"] = HERO_HP
	var hero: Vector2i = before["player"]["pos"]
	var index: int = 0
	var spots: Array[Vector2i]
	spots.assign([hero + Vector2i(1, 0), hero + Vector2i(2, 0), hero + Vector2i(1, -1)])
	for enemy: Dictionary in before["enemies"]:
		if str(enemy["type"]) != "ember_tick": continue
		enemy["pos"] = spots[index]
		before["grid"][spots[index].y][spots[index].x] = "stone"
		enemy["hp"] = 1
		enemy["bleed"] = BLEED
		enemy["bleed_stacks"] = BLEED
		index += 1
	scene._load_run_state(run)
	scene.set("_animation_lock", false)
	if bool(scene.get("_dialogue_active")): scene._close_dialogue()
	await Live.settle(self)
	scene.begin_recording("director_pass reduced=%s" % reduced)
	scene._render_board_state(before, {})
	var headless_boundary: Callable = func() -> void: RenderingServer.frame_post_draw.emit()
	if DisplayServer.get_name() == "headless": process_frame.connect(headless_boundary)
	await scene._on_pass_turn_pressed()
	if process_frame.is_connected(headless_boundary): process_frame.disconnect(headless_boundary)
	scene.sample_frame()
	var after: Dictionary = scene.get("_combat_state")
	scene.recording = false
	_expect(int(after["player"]["hp"]) == 52, "Director pass retains the true 52 Health result")
	_check_path(scene.samples, before, after, "director_pass reduced=%s" % reduced)

func _route(scene: Playback, route: String, reduced: bool) -> void:
	var before: Dictionary = Fixture.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	before["player"]["hp"] = HERO_HP
	before["player"]["max_hp"] = HERO_HP
	for index: int in range(3):
		before["enemies"][index]["pos"] = SOURCE + Vector2i(index, 0)
		before["enemies"][index]["hp"] = CHAIN_HP if index > 0 else 1
	before["enemies"][3]["pos"] = WITNESS
	match route:
		"fire": preload("res://scripts/board_surface_rules.gd").place(before, SOURCE, "fire")
		"retaliate": before["retaliate"] = {"amount": TRIGGER_DAMAGE}
		"hidden_bleed":
			before["enemies"][0]["bleed"] = BLEED
			before["umbra"] = {"stage": "eclipse"}
	var original: Dictionary = before.duplicate(true)
	var action: Dictionary = {"type": "ranged", "range": 5, "damage": TRIGGER_DAMAGE}
	var engine := Combat.new()
	var phase: Dictionary = engine.resolve_enemy_turn_with_steps(before, 0) if route != "player_card" else {"state": engine.apply_player_action(before, action, SOURCE)}
	var after: Dictionary = phase["state"]
	var label: String = "%s reduced=%s" % [route, reduced]
	_expect(after.get("death_burst_events", []).size() == 3, label + " resolves all three real Bursts")
	Live.install(scene, before.duplicate(true))
	scene.set("_animation_lock", true)
	scene.begin_recording(label)
	scene._render_board_state(before, {})
	var pacing: Node = scene.get("_combat_pacing")
	if route == "player_card":
		pacing.begin_card()
		await scene._animate_player_action_step(before, after, "quick_stab", action, SOURCE)
		pacing.end_scope()
	else:
		pacing.begin_enemies()
		var animated: Dictionary = before.duplicate(true)
		await scene._animate_enemy_phase_steps(animated, phase["steps"])
		await pacing.finish_enemies()
		_expect(animated["player"] == after["player"] and animated["enemies"] == after["enemies"], label + " playback settles the true actors")
	scene._render_board_state(after, {})
	scene.recording = false
	_expect(before == original, label + " leaves rule input unchanged")
	_check_path(scene.samples, before, after, label)

func _hidden_cascades(scene: Playback, reduced: bool) -> void:
	var original: Dictionary = Fixture.fixture(["ember_tick", "ember_tick", "ember_tick", "crawler"])
	original["player"]["hp"] = HERO_HP
	original["player"]["max_hp"] = HERO_HP
	original["umbra"] = {"stage": "eclipse"}
	for index: int in range(3):
		original["enemies"][index]["pos"] = SOURCE + Vector2i(index, 0)
		original["enemies"][index]["hp"] = CHAIN_HP
	original["enemies"][3]["pos"] = WITNESS
	var engine := Combat.new()
	var trace: Dictionary = {"capture_reactions": true}
	engine._surface_death_trace = trace
	var after: Dictionary = engine._damage_enemy(original.duplicate(true), 0, TRIGGER_DAMAGE)
	engine._surface_death_trace = {}
	# Start at the genuine first FIFO boundary; its initiating kill is already
	# paid. Convert the resolver's trace with the production cascade adapter.
	var before: Dictionary = original.duplicate(true)
	before.merge(after["death_burst_events"][0]["before"], true)
	var steps: Array[Dictionary] = preload("res://scripts/enemy_mechanics/reaction_loss_ownership.gd").presentation_steps(engine, before, after, {"reaction_trace": trace})
	for index: int in range(steps.size()):
		steps[index] = engine._umbra_marked_enemy_status_step(before, after, steps[index], int(steps[index]["cascade"]["id"]))
	var label: String = "hidden_cascade reduced=%s" % reduced
	_expect(steps.any(func(step: Dictionary) -> bool: return bool(step.get("hidden_by_umbra", false))), label + " uses real concealed cascade dispatch")
	Live.install(scene, before.duplicate(true))
	scene.set("_animation_lock", true)
	scene.begin_recording(label)
	scene._render_board_state(before, {})
	var animated: Dictionary = before.duplicate(true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_enemies()
	await scene._animate_enemy_phase_steps(animated, steps)
	await pacing.finish_enemies()
	scene._render_board_state(after, {})
	scene.recording = false
	_expect(animated["player"] == after["player"], label + " settles the real visible victim")
	_check_path(scene.samples, before, after, label)

func _health(state: Dictionary) -> Dictionary:
	var result: Dictionary = {"player": int(state["player"]["hp"])}
	for enemy: Dictionary in state["enemies"]: result["enemy_%d" % int(enemy["id"])] = int(enemy["hp"])
	return result

func _enter_fight(scene: Playback, before: Dictionary) -> void:
	# Normal travel clears combat before the next encounter is installed. Use
	# the production sync boundary, never a test-only playback-cache reset.
	var room: Dictionary = scene.get("_run_state").duplicate(true)
	room["mode"] = "room"
	room["combat_state"] = {}
	scene.set("_run_state", room)
	scene._sync_combat_state_from_run()
	Live.install(scene, before.duplicate(true))
	scene.set("_animation_lock", true)

func _projection_cost_guard() -> void:
	var before: Dictionary = Fixture.fixture(["ember_tick", "crawler"])
	before["enemies"][0]["pos"] = SOURCE
	before["enemies"][1]["pos"] = SOURCE + Vector2i.RIGHT
	var after: Dictionary = Combat.new()._damage_enemy(before.duplicate(true), 0, TRIGGER_DAMAGE)
	var playback := preload("res://scripts/enemy_mechanics/burst_playback.gd").new()
	_expect(is_same(playback.display_state(after, {}), after), "No pending Burst returns the original state without projection work")
	playback.prepare(before, after)
	var projected: Dictionary = playback.display_state(after, {})
	var witness: Dictionary = after["enemies"][1]
	var held: Dictionary = projected["enemies"][1]
	_expect(not is_same(held, witness) and int(held["hp"]) == int(before["enemies"][1]["hp"]), "Pending projection copies only changed durability")
	_expect(is_same(held["intent"], witness["intent"]), "Pending projection preserves nested actor references instead of deep-copying intents")
	_expect(is_same(projected["enemies"][0], after["enemies"][0]), "Unchanged actor reuses its original dictionary")
	var lookup: Dictionary = playback._snapshot_enemies_by_id
	for frame: int in range(PROJECTION_SAMPLE_FRAMES):
		playback.display_state(after, {})
		_expect(is_same(lookup, playback._snapshot_enemies_by_id), "Repeated pending frames reuse the snapshot id lookup")
	var deaths: Array[Dictionary]
	deaths.append({"id": int(after["enemies"][0]["id"]), "role": "enemy"})
	deaths.append({"id": int(witness["id"]), "role": "enemy"})
	var shown: Dictionary = {"death_animation_units": deaths}
	_expect(playback.hold_pending_deaths(projected, shown)["death_animation_units"].size() == 1, "Death filtering uses projected Health for each id")
	playback.display_state(after, {"burst_playback_count": after["death_burst_events"].size()})
	_expect(is_same(playback.display_state(after, {}), after) and is_same(playback.hold_pending_deaths(after, shown), shown), "Completed Burst returns original state and presentation without matching or actor copies")
	_expect(int(witness["hp"]) == int(after["death_burst_events"].back()["after"]["enemies"][1]["hp"]), "Projection never mutates the resolved actor")
	print("BRS02 PENDING COST: PASS (id lookup reused; shallow changed actors; inactive state/presentation reused)")

func _identical_fights(scene: Playback, reduced: bool) -> void:
	var before: Dictionary = Fixture.fixture(["ember_tick", "ember_tick"])
	before["player"]["hp"] = HERO_HP
	before["player"]["max_hp"] = HERO_HP
	before["enemies"][0].merge({"pos": SOURCE, "hp": 1}, true)
	before["enemies"][1].merge({"pos": SOURCE + Vector2i.RIGHT, "hp": CHAIN_HP}, true)
	var action: Dictionary = {"type": "ranged", "range": 5, "damage": TRIGGER_DAMAGE}
	var after: Dictionary = Combat.new().apply_player_action(before, action, SOURCE)
	for fight: int in range(3):
		if fight < 2: _enter_fight(scene, before)
		else:
			# Inspection/debug installs also replace the canonical journal, while
			# retaining the same room coordinates and identical combat values.
			Live.install(scene, before.duplicate(true))
			scene.set("_animation_lock", true)
		var label: String = "identical_fight_%d reduced=%s" % [fight + 1, reduced]
		scene.begin_recording(label)
		scene._render_board_state(before, {})
		var pacing: Node = scene.get("_combat_pacing")
		pacing.begin_card()
		await scene._animate_player_action_step(before, after, "quick_stab", action, SOURCE)
		pacing.end_scope()
		scene._render_board_state(after, {})
		scene.recording = false
		_check_path(scene.samples, before, after, label)

func _forced_movement(scene: Playback, route: String, reduced: bool) -> void:
	var before: Dictionary = Fixture.fixture(["ember_tick", "crawler"])
	before["player"]["hp"] = HERO_HP
	before["player"]["max_hp"] = HERO_HP
	before["player"]["pos"] = HERO
	before["enemies"][0].merge({"pos": SOURCE, "hp": 1}, true)
	before["enemies"][1].merge({"pos": FORCE_WITNESS, "anchored": true}, true)
	var fire: Vector2i = SOURCE + Vector2i.RIGHT
	var action: Dictionary = {"type": route, "range": 5, "damage": 0, "amount": 1}
	var engine := Combat.new()
	if route in ["push", "force_area_push"]: before["player"]["pos"] = SOURCE - Vector2i.RIGHT
	if route in ["pull", "force_area_pull"]: before["player"]["pos"] = FORCE_WITNESS + Vector2i.DOWN
	if route.begins_with("force_area_"):
		action = {"type": "force_area", "center": "self", "radius": 3, "push" if route.ends_with("push") else "pull": 1}
	if route == "swap": before["player"]["pos"] = fire
	if route == "room_wind":
		before["snare_entry"] = Vector2i((before["grid"][0] as Array).size() - 2, HERO.y)
		preload("res://scripts/enemy_mechanics/wind.gd").install_headwind(engine, before, Vector2i.RIGHT, 1)
	if route == "enemy_wind":
		before["enemies"].append(before["enemies"][1].duplicate(true))
		before["enemies"][2]["id"] = 3
		before["enemies"][1].merge({"type": "gale_herald", "pos": Vector2i.ONE, "anchored": true}, true)
		before["wind"] = {"source_id": 2, "direction": Vector2i.RIGHT, "rounds_left": 1, "push": 1}
	if route == "retaliate_push":
		before["enemies"][0]["pos"] = RETALIATE_TICK
		before["enemies"][1]["pos"] = RETALIATE_FIRE + Vector2i.UP
		before["retaliate"] = {"amount": 0, "push": 1}
		fire = RETALIATE_FIRE
	if route == "erupt_push":
		before["enemies"].push_front(Fixture.fixture(["burrow_grub"])["enemies"][0].duplicate(true))
		for index: int in range(before["enemies"].size()): before["enemies"][index]["id"] = index + 1
		before["enemies"][0].merge({"pos": ERUPT_ORIGIN, "burrowed": true, "erupt_tile": ERUPT_CENTER}, true)
		for intent: Dictionary in preload("res://scripts/game_data.gd").enemy_def("burrow_grub")["intents"]:
			if str(intent["id"]) == "erupt": before["enemies"][0]["intent"] = intent.duplicate(true)
		before["enemies"][1]["pos"] = ERUPT_CENTER + Vector2i.RIGHT
		before["enemies"][2]["pos"] = FORCE_WITNESS + Vector2i.DOWN
		fire = FORCE_WITNESS
	if route == "upheaval_push":
		before["enemies"].push_front(preload("res://tests/suites/battlefield_rules_suite.gd").battle(engine)["enemies"][0].duplicate(true))
		for index: int in range(before["enemies"].size()): before["enemies"][index]["id"] = index + 1
		before["enemies"][0]["pos"] = SOURCE - Vector2i.RIGHT * 2
		var rule: Dictionary = preload("res://tests/suites/battlefield_rules_suite.gd").rule("upheaval", {"pattern": "line_between", "length": 3, "health": 3}, true)
		preload("res://scripts/battlefield_rules/dispatcher.gd").install(engine, before, rule)
		preload("res://tests/suites/battlefield_rules_suite.gd").mature_fuel(before)
	preload("res://scripts/board_surface_rules.gd").place(before, fire, "fire")
	var original: Dictionary = before.duplicate(true)
	var phase: Dictionary = {}
	var after: Dictionary
	if route == "room_wind": after = engine.finish_player_activation(before)
	elif route == "enemy_wind":
		var steps: Array[Dictionary]
		after = preload("res://scripts/enemy_mechanics/wind.gd").end_turn(engine, before.duplicate(true), steps)
		phase["steps"] = steps
	elif route in ["retaliate_push", "erupt_push", "upheaval_push"]:
		phase = engine.resolve_enemy_turn_with_steps(before, 0)
		after = phase["state"]
	else: after = engine.apply_player_action(before, action, SOURCE)
	var label: String = "%s reduced=%s" % [route, reduced]
	_expect(after.get("death_burst_events", []).size() == 1, label + " forced arrival resolves exactly one real Burst")
	var resolved: Dictionary = after.duplicate(true)
	var raw_steps: Array = (phase.get("steps", []) as Array).duplicate(true)
	_enter_fight(scene, before)
	scene.begin_recording(label)
	scene._render_board_state(before, {})
	var pacing: Node = scene.get("_combat_pacing")
	if route == "room_wind":
		pacing.begin_enemies()
		_expect(await preload("res://scripts/enemy_mechanics/wind_view.gd").animate_room_completion(scene, before, after), label + " uses production room completion")
		await pacing.finish_enemies()
	elif not phase.is_empty():
		pacing.begin_enemies()
		var animated: Dictionary = before.duplicate(true)
		await scene._animate_enemy_phase_steps(animated, phase["steps"], after)
		await pacing.finish_enemies()
		_expect(animated["player"] == after["player"] and animated["enemies"] == after["enemies"], label + " settles real actors")
	else:
		pacing.begin_card()
		await scene._animate_player_action_step(before, after, "quick_stab", action, SOURCE)
		pacing.end_scope()
	scene._render_board_state(after, {})
	scene.recording = false
	_expect(before == original, label + " preserves rule input")
	_expect(after == resolved and phase.get("steps", []) == raw_steps, label + " preserves resolved state and analytics payloads")
	_check_path(scene.samples, before, after, label)

func _trap_cascade(scene: Playback, reduced: bool) -> void:
	var before: Dictionary = preload("res://tests/suites/fix_14_suite.gd").legacy_state()
	var phase: Dictionary = Combat.new().resolve_enemy_turn_with_steps(before, 0)
	var after: Dictionary = phase["state"]
	var label: String = "trap_cascade reduced=%s" % reduced
	var raw_steps: Array = phase["steps"].duplicate(true)
	_expect(after.get("death_burst_events", []).size() == 1, label + " real trap death resolves a Burst")
	Live.install(scene, before.duplicate(true))
	scene.set("_animation_lock", true)
	scene.begin_recording(label)
	scene._render_board_state(before, {})
	var animated: Dictionary = before.duplicate(true)
	var pacing: Node = scene.get("_combat_pacing")
	pacing.begin_enemies()
	await scene._animate_enemy_phase_steps(animated, phase["steps"], after)
	await pacing.finish_enemies()
	scene._render_board_state(after, {})
	scene.recording = false
	_expect(phase["steps"] == raw_steps, label + " preserves resolver/analytics payloads")
	_expect(animated["player"] == after["player"] and animated["enemies"] == after["enemies"], label + " playback settles the true actors")
	_check_path(scene.samples, before, after, label)

func _check_path(samples: Array[Dictionary], before: Dictionary, after: Dictionary, label: String) -> void:
	var path: Array[Dictionary]
	path.append(_health(before))
	var events: Array = after.get("death_burst_events", [])
	for event: Dictionary in events.slice((before.get("death_burst_events", []) as Array).size()):
		path.append(_health(event["before"]))
		path.append(_health(event["after"]))
	path.append(_health(after))
	for key: String in path[0]:
		var expected: Array[int]
		for health: Dictionary in path:
			if expected.is_empty() or expected.back() != int(health[key]): expected.append(int(health[key]))
		var actual: Array[int]
		for sample: Dictionary in samples:
			var hp: int = int(sample["health"][key])
			if actual.is_empty() or actual.back() != hp: actual.append(hp)
		_expect(actual == expected, "%s %s Health path expected=%s actual=%s" % [label, key, expected, actual])
		var damage: Array[int]
		var engine := Combat.new()
		for event: Dictionary in events.slice((before.get("death_burst_events", []) as Array).size()):
			var hp_loss: int = int(_health(event["before"])[key]) - int(_health(event["after"])[key])
			var visible: Dictionary = before.duplicate(true)
			visible.merge(event["after"], true)
			var unit: Dictionary = visible["player"]
			for enemy: Dictionary in visible["enemies"]:
				if key == "enemy_%d" % int(enemy["id"]): unit = enemy
			if hp_loss > 0 and engine.is_tile_visible_to_player(visible, unit["pos"]): damage.append(hp_loss)
		var popups: Dictionary = {}
		for sample: Dictionary in samples:
			for text: Dictionary in sample["shown"].get("floating_texts", []):
				if str(text.get("reaction_actor_key", "")) != key or str(text.get("reaction", "")) != "hit": continue
				popups[str(text.get("screen_layout_key", ""))] = absi(str(text.get("text", "0")).to_int())
		var actual_damage: Array[int]
		for amount: int in popups.values(): actual_damage.append(amount)
		# The initiating card/Bleed/attack has its existing feedback owner.
		# Check only Bursts here; a missing unrelated legacy trigger popup is
		# outside this regression. A duplicate trigger still remains and fails.
		if path.size() > 2:
			var primary_loss: int = int(path[0][key]) - int(path[1][key])
			if primary_loss > 0: actual_damage.erase(primary_loss)
		damage.sort()
		actual_damage.sort()
		_expect(actual_damage == damage, "%s %s damage popups expected=%s actual=%s" % [label, key, damage, actual_damage])
	print("BRS02 HEALTH PATH: %s; frames=%d; hero=%s" % [label, samples.size(), _hero_path(samples)])

func _hero_path(samples: Array[Dictionary]) -> Array[int]:
	var result: Array[int]
	for sample: Dictionary in samples:
		var hp: int = int(sample["health"]["player"])
		if result.is_empty() or result.back() != hp: result.append(hp)
	return result

func _expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok: failures.append(message)
