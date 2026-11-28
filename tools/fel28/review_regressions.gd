extends "probe.gd"

const RunScene := preload("res://scenes/run_scene.tscn")
const CRAWLER_KEY := "enemy_1"
const METEOR_DAMAGE := 50
const LATE_ENEMY_TIME := 100
const CONTINUE_DEADLINE_MS := 6000

class RailObserver extends "res://scripts/run_scene.gd":
	var defeat_reflows: int = 0
	var removal_reflows: int = 0

	func _animate_turn_order_transition(before: Array[Dictionary], after: Array[Dictionary], defeated: Dictionary = {}) -> void:
		if not _suppress_final_kill_rail and not _post_combat_victory_overlay.visible:
			if defeated.has("enemy:enemy_1"): defeat_reflows += 1
			if before.any(_is_victim_entry) and not after.any(_is_victim_entry): removal_reflows += 1
		await super._animate_turn_order_transition(before, after, defeated)

	func _is_victim_entry(entry: Dictionary) -> bool:
		return entry.get("actor_key") == "enemy_1"

func _run() -> void:
	inputs = load(tool_root.path_join("fel20/input_driver.gd")).new(root)
	fixtures = load(tool_root.path_join("fel28/fixtures.gd"))
	var case: String = OS.get_environment("FEL28_REVIEW_CASE")
	if not case in ["ooze_split", "turn_start_final", "crawler_rigs", "continue_intro"]:
		_fail("set FEL28_REVIEW_CASE")
		return
	if output.is_empty() or DirAccess.make_dir_recursive_absolute(output) != OK:
		_fail("set FEL28_OUTPUT")
		return
	var scene: Node = await _setup("shadow", output)
	if scene == null:
		_fail("could not open review fixture")
		return
	var passed: bool
	match case:
		"ooze_split", "turn_start_final": passed = await _meteorfall(scene, case == "ooze_split")
		"crawler_rigs": passed = await _crawler_rigs(scene)
		"continue_intro": passed = await _continue_intro(scene)
	quit(0 if passed else 1)

func _resume(scene: Node, observer: bool = false) -> Node:
	scene.queue_free()
	await process_frame
	var next: Node = RunScene.instantiate()
	if observer:
		var script_source := RailObserver.new()
		next.set_script(script_source.get_script())
		script_source.free()
	root.set_meta("labyrinth_resume_saved_run", true)
	root.add_child(next)
	current_scene = next
	return next

func _meteorfall(scene: Node, split: bool) -> bool:
	var watched: RailObserver = await _resume(scene, true)
	fixtures.stage(watched, "inventory", "cinder_ooze" if split else "crawler")
	var state: Dictionary = watched._combat_state
	for entry: Dictionary in state.get("turn_queue", []):
		if entry.get("kind") == "enemy": entry["time"] = int(state.get("initiative_clock", 0)) + LATE_ENEMY_TIME
	state["meteor_marks"] = [{"tiles": [fixtures.EAST], "damage": METEOR_DAMAGE, "element": "fire", "surface": "fire", "card_id": "meteorfall"}]
	watched._refresh_stage_view()
	await RenderingServer.frame_post_draw
	inputs.send(inputs.key(KEY_P))
	var deadline: int = Time.get_ticks_msec() + DEADLINE_MS
	while Time.get_ticks_msec() < deadline and watched._animation_lock:
		await RenderingServer.frame_post_draw
	var living_droplets: int = watched._combat_state.get("enemies", []).filter(
		func(unit: Dictionary) -> bool: return unit.get("type") == "cinder_droplet" and int(unit.get("hp", 0)) > 0).size()
	var settled: bool = not watched._animation_lock and (watched._run_state.get("mode") == "combat" and living_droplets > 0 if split else watched._run_state.get("mode") == "reward")
	if not settled:
		print("FEL28 REVIEW FIXTURE mode=", watched._run_state.get("mode"), " droplets=", living_droplets, " lock=", watched._animation_lock)
	var passed: bool = settled and (watched.defeat_reflows > 0 if split else watched.removal_reflows == 0)
	var line: String = "OOZE_SPLIT rail_held=%s" % str(watched.defeat_reflows == 0) if split else "TURN_START_FINAL rail_reflow=%d" % watched.removal_reflows
	_report(line, passed)
	return passed

func _crawler_rigs(scene: Node) -> bool:
	fixtures.stage(scene, "inventory", "crawler")
	var board: Node = scene.board_view
	var before: Dictionary = scene._combat_state
	var after: Dictionary = before.duplicate(true)
	after["enemies"][0]["hp"] = 0
	await process_frame
	var rig: Node = board._crawler_renderers.get(CRAWLER_KEY)
	scene._animation_lock = true
	scene._combat_pacing.begin_enemies()
	var shown: Dictionary = {"combat_feel_owner": scene._combat_pacing}
	_submit_board(board, after, shown)
	var waiting: bool = is_instance_valid(rig) and board._crawler_renderers.get(CRAWLER_KEY) == rig
	var deaths: Array[Dictionary] = scene._defeated_enemy_units_between_states(before, after)
	deaths[0]["death_progress"] = 0.5
	_submit_board(board, after, {"combat_feel_owner": scene._combat_pacing, "death_animation_units": deaths})
	var reused: bool = board._crawler_renderers.get(CRAWLER_KEY) == rig
	_submit_board(board, after, shown)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var freed: bool = not board._crawler_renderers.has(CRAWLER_KEY) and not is_instance_valid(rig)
	var passed: bool = waiting and reused and freed and scene._combat_pacing.enemies_active
	if not passed:
		print("FEL28 CRAWLER_RIGS observed waiting=", waiting, " reused=", reused,
			" registered=", board._crawler_renderers.has(CRAWLER_KEY), " valid=", is_instance_valid(rig),
			" pacing_active=", scene._combat_pacing.enemies_active)
	_report("CRAWLER_RIGS " + ("freed_after_dissolve" if freed else "retained_after_dissolve"), passed)
	_submit_board(board, before, shown)
	var unused: Node = board._crawler_renderers.get(CRAWLER_KEY)
	_submit_board(board, after, shown)
	var unused_retained: bool = is_instance_valid(unused) and board._crawler_renderers.get(CRAWLER_KEY) == unused
	await scene._combat_pacing.finish_enemies()
	if board.has_method("release_waiting_crawler_rigs"): board.release_waiting_crawler_rigs()
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var unused_released: bool = unused_retained and not is_instance_valid(unused) and not board._crawler_renderers.has(CRAWLER_KEY)
	_report("CRAWLER_RIGS unused_freed_at_scope_end=%s" % str(unused_released), unused_released)
	return passed and unused_released

func _submit_board(board: Node, state: Dictionary, presentation: Dictionary) -> void:
	board.set_combat_state(state, [], [], Vector2i(-1, -1), "", "", {}, {}, presentation)

func _continue_intro(scene: Node) -> bool:
	var combat: Dictionary = scene._combat_state.duplicate(true)
	for enemy: Dictionary in combat["enemies"]: enemy["hp"] = 0
	var won: Dictionary = scene._run_state_for_combat_checkpoint(scene._run_state, combat)
	if not won.get("pending_reward", {}).get("intro_pending", false) or not Store.save_run_state(won):
		_fail("could not save unfinished reward fixture")
		return false
	process_frame.disconnect(_draw_boundary.call_deferred)
	var resumed: Node = await _resume(scene)
	var deadline: int = Time.get_ticks_msec() + CONTINUE_DEADLINE_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if resumed._run_state.get("mode") == "reward" and not resumed._reward_intro_pending() and not resumed._animation_lock:
			_report("CONTINUE_INTRO headless completes", true)
			return true
	_report("CONTINUE_INTRO headless hangs", false)
	return false

func _report(line: String, passed: bool) -> void:
	print("FEL28 %s %s" % [line, "PASS" if passed else "FAIL"])
