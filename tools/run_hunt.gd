extends SceneTree
## One seeded whole-run exercise of the production scene. No fixture installation.
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const RecentEvents = preload("res://scripts/recent_event_store.gd")
const Runtime = preload("res://scripts/parallel_runtime.gd")
const Policy = preload("res://tools/run_hunt_policy.gd")
const DemoRules = preload("res://scripts/demo_rules.gd")
const DemoBuild = preload("res://scripts/demo_build.gd")
const HUNT_HEALTH: int = 9999
const HEADLESS_TIME_SCALE: float = 8.0
const SAMPLE_FPS: int = 120
const SETTLE_FRAMES: int = 8
const NO_DECISION_SECONDS: float = 20.0
const FIGHT_DECISION_LIMIT: int = 400
const UNCHANGED_FIGHT_DECISIONS: int = 50
const SCREEN_DECISION_LIMIT: int = 120
const SIDE_CHANCE: float = 0.10
const SIDE_ACTIONS: Array = ["hover_hand", "deck", "map", "settings", "heirloom", "resume", "escape", "reduced_motion"]

var demo: bool = false
var hunt_health: int = HUNT_HEALTH
# Two natural runs share a profile to exercise one-time links suppression.
const DEMO_PROFILE_RUNS: int = 2
const DEMO_PANEL_SAMPLE_SECONDS: float = 3.0
const POST_HEARTH_HEALTH: int = 1
var profile_runs: int = DEMO_PROFILE_RUNS
var defeat_after_hearth: bool = false
var hearth_defeat_armed: bool = false
var panel_sample_elapsed: float = -1.0
var panel_samples: Array[Dictionary]
var panel_press_decision: int = 0
var demo_runs: Array[Dictionary]
var demo_resumes: Array[Dictionary]
var demo_mid_resumed: bool = false
var demo_links_run_id: String = ""
var demo_room_start: int = 0
var demo_map_findings: Dictionary = {}

var scene: Node
var policy: RefCounted
var rng := RandomNumberGenerator.new()
var hunt_seed: int = 1
var output: String = "user://run_hunt"
var no_embrace: bool = false
var unchanged_fight_decisions: int = 0
var previous_fight_state: Dictionary = {}
var awaiting_fight_change: bool = false
var stop_after: int = 0
var decision: int = 0
var history: Array[Dictionary]
var room_key: String = ""
var screen_key: String = ""
var fight_key: String = ""
var screen_decisions: int = 0
var fight_decisions: int = 0
var sides: Dictionary = {}
var room_samples: Array[Dictionary]
var findings: Array[Dictionary]
var visited: Dictionary = {}
var sections: Dictionary = {}
var action_counts: Dictionary = {}
var transcript: FileAccess
var idle_seconds: float = 0.0
var lock_seconds: float = 0.0
var settle_frames: int = SETTLE_FRAMES
var finished: bool = false
var busy: bool = false
var leak_checked: bool = false

func _initialize() -> void:
	Runtime.apply_from_environment()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for index: int in range(0, args.size(), 2):
		if index + 1 >= args.size():
			push_error("run_hunt: option requires a value: " + args[index])
			quit(2)
			return
		match args[index]:
			"--demo": demo = args[index + 1] == "true"
			"--profile-runs": profile_runs = int(args[index + 1])
			"--defeat-after-hearth": defeat_after_hearth = args[index + 1] == "true"
			"--health": hunt_health = int(args[index + 1])
			"--seed": hunt_seed = int(args[index + 1])
			"--output-dir": output = args[index + 1]
			"--no-embrace": no_embrace = args[index + 1] == "true"
			"--stop-after": stop_after = int(args[index + 1])
			_:
				push_error("run_hunt: unknown option " + args[index])
				quit(2)
				return
	if DisplayServer.get_name() != "headless":
		push_error("run_hunt is headless only")
		quit(2)
		return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
	transcript = FileAccess.open(output.path_join("trace.jsonl"), FileAccess.WRITE)
	if transcript == null:
		push_error("run_hunt: cannot write transcript")
		quit(2)
		return
	Store.set_storage_path(output.path_join("progression.json"))
	Store.set_run_storage_path(output.path_join("run.save"))
	Settings.set_storage_path(output.path_join("settings.json"))
	Analytics.set_storage_dir(output.path_join("analytics"))
	RecentEvents.set_storage_path(output.path_join("recent_events.json"))
	var settings: Dictionary = Settings.default_settings()
	settings["combat_speed"] = Settings.COMBAT_FASTEST
	Settings.save_settings(settings)
	rng.seed = hunt_seed
	# Production New Run reads this existing deterministic probe hook.
	root.set_meta("labyrinth_performance_probe_seed", hunt_seed)
	root.size = Vector2i(1920, 1080)
	root.content_scale_size = Vector2i(1920, 1080)
	Engine.max_fps = SAMPLE_FPS
	Engine.time_scale = HEADLESS_TIME_SCALE
	OS.low_processor_usage_mode = false
	process_frame.connect(_headless_draw_boundary)
	call_deferred("_start")

func _start() -> void:
	_emit("startup", {"seed": hunt_seed})
	_enter_scene(false)
	if finished: return
	if demo and not DemoBuild.is_demo():
		_finding("script error", "Demo requested but editor demo feature is inactive")
		_finish("demo_unavailable")
		return
	_apply_hunt_health()
	policy = Policy.new()
	policy.rng = rng
	policy.no_embrace = no_embrace
	while not finished:
		await process_frame
		if demo: _sample_demo_panel()
		_tick()

func _apply_hunt_health() -> void:
	# Zero preserves the production starting Health, including profile modifiers.
	if hunt_health == 0: return
	var run: Dictionary = scene.get("_run_state")
	run["player_max_hp"] = hunt_health
	run["player_hp"] = hunt_health
	scene.call("_save_run_progress")

func _enter_scene(resume: bool) -> void:
	if resume: root.set_meta("labyrinth_resume_saved_run", true)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if demo and scene.get_script() == null:
		scene.free()
		scene = null
		_finding("script error", "Production RunScene failed to load; demo end panel is unreachable")
		_finish("scene_load_failure")
		return
	root.add_child(scene)
	current_scene = scene
	settle_frames = SETTLE_FRAMES

func _tick() -> void:
	if finished or busy or not is_instance_valid(scene): return
	var delta: float = scene.get_process_delta_time()
	if bool(scene.get("_animation_lock")):
		idle_seconds = 0.0
		lock_seconds += delta
		return
	lock_seconds = 0.0
	if settle_frames > 0:
		settle_frames -= 1
		return
	var run: Dictionary = scene.get("_run_state")
	var context: Dictionary = _context()
	var next_room_key: String = "%s:%s" % [context["section"], context["room"]]
	if room_key != next_room_key:
		room_key = next_room_key
		sides.clear()
		var sample: Dictionary = context.duplicate(true)
		sample.merge({"nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "tree_nodes": _tree_count(root)})
		room_samples.append(sample)
		visited[context["room_kind"]] = int(visited.get(context["room_kind"], 0)) + 1
		sections[str(context["section"])] = true
		_emit("room", sample)
		_check_room_leaks(sample)
		if demo and int(context["section"]) > DemoRules.last_section_index():
			_finding("script error", "Demo entered a room past the Section I cutoff")
	var mode: String = str(run.get("mode", ""))
	# End prompts (including leaving an heirloom) remain real UI decisions.
	if mode in ["victory", "defeat", "embrace"] and not bool(scene.get("_dialogue_active")) and not scene.get("_opening_boon_flow").active():
		if demo:
			busy = true
			_demo_end(mode)
		else:
			_finish(mode)
		return
	var next_screen: String = "%s:%s:%s" % [room_key, mode, str(run.get("event_state", {}).get("page", ""))]
	if screen_key != next_screen:
		screen_key = next_screen
		screen_decisions = 0
	if mode == "combat" and fight_key != room_key:
		fight_key = room_key
		fight_decisions = 0
		unchanged_fight_decisions = 0
		previous_fight_state = {}
		awaiting_fight_change = false
	if awaiting_fight_change and mode == "combat":
		var current: Dictionary = scene.get("_combat_state")
		unchanged_fight_decisions = unchanged_fight_decisions + 1 if current == previous_fight_state else 0
		awaiting_fight_change = false
		if unchanged_fight_decisions >= UNCHANGED_FIGHT_DECISIONS:
			_finding("softlock", "Fight state unchanged for 50 consecutive decisions")
			_finish("softlock")
			return
	if fight_decisions >= FIGHT_DECISION_LIMIT and mode == "combat":
		_finding("warning", "Fight exploration budget reached 400 decisions")
		_finish("fight_limit")
		return
	if screen_decisions > SCREEN_DECISION_LIMIT and mode != "combat":
		_finding("softlock", "Screen exceeded 120 decisions")
		_finish("softlock")
		return
	if stop_after > 0 and decision >= stop_after:
		_finish("replay_point")
		return
	if demo:
		_check_demo_map()
		_arm_hearth_defeat()
		if not demo_mid_resumed and room_samples.size() - demo_room_start > 1 and mode in ["room", "pre_battle", "campfire"] and policy.side_actions_available(scene):
			demo_mid_resumed = true
			busy = true
			_demo_mid_resume()
			return
	if _side_action(): return
	var offers: Array = policy.offers(scene)
	if demo: offers = offers.filter(_demo_safe_offer)
	if offers.is_empty():
		idle_seconds += delta
		if idle_seconds >= NO_DECISION_SECONDS:
			_finding("softlock", "No legal decision and no animation lock for 20 scene seconds")
			_finish("softlock")
		return
	idle_seconds = 0.0
	var chosen: Dictionary = policy.choose(scene, offers)
	if demo and hearth_defeat_armed and mode == "combat" and not policy.browsing(scene):
		for offer: Dictionary in offers:
			if str(offer.get("kind", "")) == "pass": chosen = offer
	_record(chosen)
	screen_decisions += 1
	if mode == "combat" and not policy.browsing(scene):
		fight_decisions += 1
		previous_fight_state = (scene.get("_combat_state") as Dictionary).duplicate(true)
		awaiting_fight_change = true
	policy.dispatch(scene, chosen)
	if demo and str(chosen.get("path", "")).ends_with("/DragonRewardContinue"):
		panel_sample_elapsed = 0.0
		panel_press_decision = decision
		panel_samples.clear()
		_sample_demo_panel(false)
	settle_frames = SETTLE_FRAMES

func _record(action: Dictionary) -> void:
	decision += 1
	var logged: Dictionary = action.duplicate(false)
	logged.erase("control")
	logged.erase("object")
	logged["decision"] = decision
	logged["context"] = _context()
	history.append(logged)
	if history.size() > 20: history.pop_front()
	var kind: String = str(action.get("kind", ""))
	action_counts[kind] = int(action_counts.get(kind, 0)) + 1
	_emit("decision", logged)

func _side_action() -> bool:
	if not policy.side_actions_available(scene): return false
	for kind: String in SIDE_ACTIONS:
		if demo and kind == "resume": continue # The demo has a guaranteed mid-run reload.
		if sides.has(kind) or not policy.side_available(scene, kind): continue
		sides[kind] = true
		if rng.randf() >= SIDE_CHANCE: continue
		_record({"kind": "side_" + kind})
		if kind == "resume":
			busy = true
			_resume()
		else:
			busy = true
			_run_side(kind)
		settle_frames = SETTLE_FRAMES
		return true
	return false

func _run_side(kind: String) -> void:
	if demo and kind == "map":
		scene.call("_open_large_map", true)
		await process_frame
		_check_demo_map()
		scene.call("_close_large_map")
	else:
		await policy.side_action(scene, kind)
	busy = false

func _resume() -> void:
	scene.call("_save_run_progress")
	var before: Dictionary = scene.call("_committed_run_state")
	var saved: Dictionary = Store.load_saved_run()
	if saved.is_empty() or int(saved.get("seed", -1)) != hunt_seed:
		_finding("script error", "Save/resume did not produce this seed's saved run")
		busy = false
		return
	var previous_room: Variant = before.get("current_room")
	scene.queue_free()
	current_scene = null
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_enter_scene(true)
	if (scene.get("_run_state") as Dictionary).get("current_room") != previous_room:
		_finding("script error", "Real resume path changed the current room")
	_emit("resume", _context())
	busy = false

# Demo-only paths never enumerate end-panel links or dispatch external actions.
func _demo_safe_offer(offer: Dictionary) -> bool:
	var control: Node = offer.get("control")
	if not is_instance_valid(control): return true
	# Includes Settings links as well as recap links; never dispatch a URL.
	return str(control.name) not in ["WishlistButton", "DemoWishlistLink", "DemoDiscordLink", "DemoFeedbackLink"]

func _demo_panel_kind() -> String:
	var recap: Control = scene.get("_run_end_recap")
	if not is_instance_valid(recap) or not recap.is_visible_in_tree(): return "none"
	var panel: Node = recap.find_child("DemoEndPanel", true, false)
	return str(panel.get("kind")) if is_instance_valid(panel) and panel.is_visible_in_tree() else "none"

func _demo_panel_state() -> Dictionary:
	var recap: Control = scene.get("_run_end_recap")
	var panel: Control = recap.find_child("DemoEndPanel", true, false) if is_instance_valid(recap) else null
	return {"scene_seconds": snappedf(maxf(panel_sample_elapsed, 0.0), 0.001), "press_decision": panel_press_decision, "decision": decision, "kind": _demo_panel_kind(), "recap_visible": is_instance_valid(recap) and recap.is_visible_in_tree(), "panel_exists": is_instance_valid(panel), "panel_visible": is_instance_valid(panel) and panel.is_visible_in_tree(), "mode": (scene.get("_run_state") as Dictionary).get("mode"), "animation_lock": scene.get("_animation_lock"), "claim_in_progress": scene.get("_relic_claim_in_progress"), "delivery_phase": scene.get("_relic_delivery_phase"), "reduced_motion": scene.call("_reduced_motion_enabled"), "dialogue": scene.get("_dialogue_active"), "boon_active": scene.get("_opening_boon_flow").active()}

func _sample_demo_panel(advance: bool = true) -> void:
	if panel_sample_elapsed < 0.0 or not is_instance_valid(scene): return
	if advance: panel_sample_elapsed += scene.get_process_delta_time()
	panel_samples.append(_demo_panel_state())
	if panel_sample_elapsed >= DEMO_PANEL_SAMPLE_SECONDS:
		_emit("demo_panel_samples", {"press_decision": panel_press_decision, "samples": panel_samples})
		panel_sample_elapsed = -1.0

func _arm_hearth_defeat() -> void:
	if not defeat_after_hearth or hearth_defeat_armed: return
	var run: Dictionary = scene.get("_run_state")
	if str(run.get("mode", "")) != "combat" or not DemoRules.reached_hearth(run): return
	var combat: Dictionary = scene.get("_combat_state")
	run["player_hp"] = POST_HEARTH_HEALTH
	combat["player"]["hp"] = POST_HEARTH_HEALTH
	hearth_defeat_armed = true
	scene.call("_save_run_progress")
	_emit("demo_hearth_defeat_armed", {"context": _context(), "run_hp": run["player_hp"], "combat_hp": combat["player"]["hp"]})

func _check_demo_map() -> void:
	var run: Dictionary = scene.get("_run_state")
	var destinations: Array = []
	var map: Control = scene.get("_large_map_view")
	var map_nodes: Array = []
	if is_instance_valid(map) and map.is_visible_in_tree():
		# Read actual native node controls plus the production activation gate.
		for coord: Vector2i in (map.get("node_buttons") as Dictionary):
			var button: Control = map.get("node_buttons")[coord]
			if button.is_visible_in_tree() and map.can_activate_room(coord):
				destinations.append(coord)
				map_nodes.append(str(coord))
	var doors: Array = []
	if str(run.get("mode", "")) == "room" and not bool(scene.get("_animation_lock")):
		var board: Control = scene.get("board_view")
		var rendered: Array = board.call("controller_navigable_tiles", true)
		for tile: Vector2i in (scene.get("_exit_destinations_by_tile") as Dictionary):
			if not rendered.has(tile): continue
			var coord: Vector2i = scene.get("_exit_destinations_by_tile")[tile]
			destinations.append(coord)
			doors.append({"tile": str(tile), "destination": str(coord)})
	for tile: Vector2i in destinations:
		var metadata: Dictionary = scene.get("_run_engine").room_metadata(run, tile)
		if int(metadata.get("section_index", 0)) > DemoRules.last_section_index() and not demo_map_findings.has(tile):
			demo_map_findings[tile] = true
			_finding("script error", "Demo UI offers a node past the Section I cutoff: " + str(tile))
	# Reward/terminal snapshots explain why outward metadata is not an offer.
	var key: String = "%s:%s:%s" % [room_key, run.get("mode"), str(map_nodes)]
	if str(_context().get("room_kind")) == "boss" and not demo_map_findings.has(key):
		demo_map_findings[key] = true
		_emit("demo_navigation", {"context": _context(), "map_visible": is_instance_valid(map) and map.is_visible_in_tree(), "selectable_map_nodes": map_nodes, "board_doors": doors, "raw_available_moves": str(scene.get("_run_engine").available_moves(run))})

func _demo_mid_resume() -> void:
	await _demo_reload("mid_run")
	busy = false

func _demo_reload(stage: String) -> void:
	var before: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	scene.call("_save_run_progress")
	var has_save: bool = Store.has_saved_run()
	scene.queue_free()
	current_scene = null
	for frame: int in range(SETTLE_FRAMES): await process_frame
	_enter_scene(true)
	if finished: return
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var after: Dictionary = scene.get("_run_state")
	var same_run: bool = int(before.get("run_index", -1)) == int(after.get("run_index", -2)) and int(before.get("seed", -1)) == int(after.get("seed", -2))
	var preserved: bool = has_save and same_run and before.get("current_room") == after.get("current_room") and before.get("mode") == after.get("mode")
	var cutoff_ok: bool = not DemoRules.is_past_cutoff(after)
	var check: Dictionary = {"stage": stage, "saved_run_present": has_save, "preserved": preserved, "cutoff_ok": cutoff_ok, "before_mode": before.get("mode"), "after_mode": after.get("mode"), "panel_after": _demo_panel_kind()}
	demo_resumes.append(check)
	_emit("demo_resume", check)
	if not preserved: _finding("script error", "Demo resume lost state at " + stage)
	if not cutoff_ok: _finding("script error", "Demo resume landed past the Section I cutoff at " + stage)

func _demo_terminal_reload(run_id: String, ended: Dictionary) -> Dictionary:
	# Successful terminal persistence retains profile and Chronicle, clears the
	# resumable run, and must never continue the dead/completed descent.
	scene.call("_save_run_progress")
	var profile: Dictionary = Store.load_data().duplicate(true)
	var no_terminal_save: bool = not Store.has_saved_run()
	var receipts: Array = profile.get(Store.CHRONICLE_RECEIPTS_KEY, [])
	var records: Array = Store.chronicle_records(profile)
	var record_count: int = 0
	for record: Dictionary in records:
		if str(record.get("run_id", "")) == run_id: record_count += 1
	var check: Dictionary = {"stage": "end_panel", "terminal_save_absent": no_terminal_save, "chronicle_receipt": receipts.has(run_id), "chronicle_record_count": record_count, "links_receipt": profile.get(DemoRules.LINKS_PROMPT_RUN_KEY, "")}
	scene.queue_free()
	current_scene = null
	for frame: int in range(SETTLE_FRAMES): await process_frame
	check["profile_preserved"] = Store.load_data() == profile
	_enter_scene(true)
	for frame: int in range(SETTLE_FRAMES): await process_frame
	var next: Dictionary = scene.get("_run_state")
	check["new_run"] = int(next.get("run_index", 0)) > int(ended.get("run_index", 0)) and str(next.get("mode")) not in ["victory", "defeat", "embrace"]
	check["cutoff_ok"] = not DemoRules.is_past_cutoff(next)
	check["next_section"] = _context()["section"]
	var after: Dictionary = Store.load_data()
	check["chronicle_preserved"] = Store.chronicle_records(after) == records and after.get(Store.CHRONICLE_RECEIPTS_KEY, []) == receipts
	check["links_receipt_preserved"] = after.get(DemoRules.LINKS_PROMPT_RUN_KEY, "") == check["links_receipt"]
	check["preserved"] = no_terminal_save and check["profile_preserved"] and check["chronicle_receipt"] and record_count == 1 and check["new_run"] and check["cutoff_ok"] and check["chronicle_preserved"] and check["links_receipt_preserved"]
	_emit("demo_resume", check)
	if not check["preserved"]: _finding("script error", "Demo terminal persistence contract failed")
	return check

func _demo_end_interaction_pending() -> bool:
	return bool(scene.get("_dialogue_active")) or scene.get("_opening_boon_flow").active()

func _demo_end(outcome: String) -> void:
	# Sample the COMPLETE ASCENT delivery before deciding whether the recap is
	# absent. Do not press anything during this observation window.
	while panel_sample_elapsed >= 0.0: await process_frame
	# Delivery can open the mandatory heirloom prompt after the terminal mode
	# was committed. Let the policy finish real inputs before judging the recap.
	if _demo_end_interaction_pending():
		_emit("demo_panel_deferred_for_input", _demo_panel_state())
		busy = false
		return
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	var profile: Dictionary = (scene.get("_progression") as Dictionary).duplicate(true)
	var expected: String = DemoRules.end_panel_kind(run, outcome, profile)
	var shown: String = _demo_panel_kind()
	_emit("demo_panel_state", _demo_panel_state())
	if shown != expected: _finding("script error", "Demo end panel mismatch: shown %s expected %s" % [shown, expected])
	var run_id: String = "run:%d:seed:%d" % [int(run.get("run_index", 0)), int(run.get("seed", 0))]
	if shown == "links":
		if not demo_links_run_id.is_empty() and demo_links_run_id != run_id:
			_finding("script error", "Demo links row shown twice on one profile")
		demo_links_run_id = run_id
	if defeat_after_hearth and (outcome != "defeat" or not DemoRules.reached_hearth(run) or shown != ("links" if demo_runs.is_empty() else "none")):
		_finding("script error", "Post-Hearth defeat did not show links exactly once on this profile")
	var row: Dictionary = {"outcome": outcome, "run_id": run_id, "section": _context()["section"], "rooms": room_samples.size() - demo_room_start, "hearth": DemoRules.reached_hearth(run), "shown": shown, "expected": expected, "panel_samples": panel_samples.duplicate(true)}
	_emit("demo_end", row)
	# Store real engine state for replay diagnosis without installing a fixture.
	var snapshot := FileAccess.open(output.path_join("terminal-%d.json" % (demo_runs.size() + 1)), FileAccess.WRITE)
	snapshot.store_string(JSON.stringify({"run": run, "profile": profile}, "\t"))
	snapshot.close()
	if demo_runs.is_empty():
		demo_resumes.append(await _demo_terminal_reload(run_id, run))
		row["exit"] = "quit_and_reload"
	else:
		var button: BaseButton = scene.get("_run_end_recap").find_child("NewRunButton", true, false)
		if is_instance_valid(button) and button.is_visible_in_tree():
			_record({"kind": "demo_rise_again"})
			button.emit_signal("pressed")
			row["exit"] = "rise_again"
		else:
			_finding("softlock", "Demo end panel has no visible Rise Again control")
			row["exit"] = "missing_rise_again"
		for frame: int in range(SETTLE_FRAMES): await process_frame
	row["resumes"] = demo_resumes.duplicate(true)
	row["restart_section"] = _context()["section"]
	row["restart_mode"] = _context()["mode"]
	if int(row["restart_section"]) != 0 or str(row["restart_mode"]) in ["victory", "defeat", "embrace"]:
		_finding("script error", "Demo exit did not start a new run in Section I")
	demo_runs.append(row)
	_emit("demo_run", row)
	if demo_runs.size() >= profile_runs:
		_finish(str(demo_runs[0]["outcome"]))
		return
	_apply_hunt_health()
	demo_room_start = room_samples.size()
	demo_resumes.clear()
	demo_mid_resumed = false
	hearth_defeat_armed = false
	panel_samples.clear()
	room_key = ""
	screen_key = ""
	fight_key = ""
	busy = false

func _context() -> Dictionary:
	if not is_instance_valid(scene): return {"seed": hunt_seed, "section": -1, "room": "startup", "room_kind": "startup", "mode": "startup", "decision": decision}
	var run: Dictionary = scene.get("_run_state")
	var room: Dictionary = scene.get("_run_engine").room_metadata(run, run.get("current_room", Vector2i.ZERO))
	var kind: String = str(room.get("type", "unknown"))
	if not str(room.get("special_type", "")).is_empty(): kind = str(room["special_type"])
	elif kind == "mystery": kind = str(room.get("mystery_type", kind))
	return {"seed": hunt_seed, "section": int(room.get("section_index", 0)), "room": str(run.get("current_room", Vector2i.ZERO)), "room_kind": kind, "room_metadata": room, "mode": str(run.get("mode", "")), "decision": decision}

func _finding(severity: String, message: String) -> void:
	var stack: Array = get_stack()
	var location: String = "res://tools/run_hunt.gd:%d" % int(stack[0].get("line", 0)) if not stack.is_empty() else "res://tools/run_hunt.gd:0"
	var row: Dictionary = {"severity": severity, "error": message, "location": location, "context": _context(), "last_20_decisions": history.duplicate(true)}
	findings.append(row)
	_emit("finding", row)

func _check_room_leaks(sample: Dictionary) -> void:
	if leak_checked or int(sample["section"]) != 5: return
	leak_checked = true
	for baseline: Dictionary in room_samples:
		if int(baseline["section"]) != 0: continue
		for metric: String in ["tree_nodes", "orphans"]:
			if float(sample[metric]) > float(baseline[metric]) * 1.25:
				_finding("leak", "%s grew more than 25%% from section 0 to section 5 (%d -> %d)" % [metric, int(baseline[metric]), int(sample[metric])])
		break

func _finish(outcome: String) -> void:
	finished = true
	var summary: Dictionary = {"seed": hunt_seed, "outcome": outcome, "decisions": decision, "sections": sections.keys(), "room_kinds": visited, "room_samples": room_samples, "action_counts": action_counts, "findings": findings, "context": _context(), "last_20_decisions": history}
	if demo: summary["demo_runs"] = demo_runs
	var file := FileAccess.open(output.path_join("summary.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(summary, "\t"))
	file.close()
	_emit("finish", summary)
	print("RUN HUNT: seed=%d outcome=%s decisions=%d" % [hunt_seed, outcome, decision])
	if is_instance_valid(scene): scene.queue_free()
	for frame: int in range(SETTLE_FRAMES): await process_frame
	quit()

func _emit(event: String, data: Dictionary) -> void:
	var row: Dictionary = {"event": event, "data": data}
	var line: String = JSON.stringify(row)
	transcript.store_line(line)
	transcript.flush()
	print("RUN_HUNT_EVENT " + line)

func _tree_count(node: Node) -> int:
	var count: int = 1
	for child: Node in node.get_children(true): count += _tree_count(child)
	return count

func _headless_draw_boundary() -> void:
	RenderingServer.frame_post_draw.emit()
