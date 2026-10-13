extends SceneTree
## b_enemy_turn staging is reproduced from the approved director source.
## Headless --timeline-only verifies scheduling/state; captures require a renderer.
const Suite = preload("res://tests/suites/combat_feel_suite.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const GameDataScript = preload("res://scripts/game_data.gd")
const RoomGeneratorScript = preload("res://scripts/room_generator.gd")
const GrimoireLibrary = preload("res://scripts/grimoire_library.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const FloatingText = preload("res://scripts/floating_combat_text.gd")
const OUTPUT_DIR: String = "user://probes/combat_feel"
const ROUND_TIMEOUT_MS: int = 18000
const HEAVY_PROOF_DAMAGE: int = 12
const HEAVY_PROOF_RANGE: int = 10
const PROBE_SETTLE_FRAMES: int = 30
const SLOW_DRAW_REGRESSION_FPS: int = 5
const HEAVY_CAPTURE_TIMEOUT_MS: int = 3000
const PEAK_OPACITY_TOLERANCE: float = 0.025

# Dummy-renderer boundary after normal animation and hit-stop node processing.
# Unlike process_frame/call_deferred, this ordering exposes late release peaks.
class HeadlessPostProcessDraw:
	extends Node
	const DRAW_PROCESS_PRIORITY: int = 100000
	var draw: Callable
	func _ready() -> void:
		process_priority = DRAW_PROCESS_PRIORITY
		process_mode = Node.PROCESS_MODE_ALWAYS
	func _process(_delta: float) -> void:
		draw.call()

var seed: int = 126065
var run_engine = RunEngine.new()
var combat_engine = CombatEngine.new()
var run_scene: Node
var _failures: Array[String]
var _heavy_timing_only: bool = false
var _timeline_only: bool = false
var _baseline: bool = false
var _capture_reduced: bool = false
var _heavy_frame: int = -1
var _capture_heavy: bool = false
var _last_frame: Image
var _peak_pending: bool = false
var _peak_captured: bool = false
var _heavy_images: Dictionary = {}
var _heavy_offsets: Array[int]
var _heavy_trace: Array[Dictionary]
var _heavy_events: Array[Dictionary]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	ProgressionStore.set_storage_path("user://feel_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://feel_probe_run.save")
	SettingsStore.set_storage_path("user://feel_probe_settings.json")
	preload("res://scripts/analytics_store.gd").set_storage_dir("user://feel_probe_analytics")
	SettingsStore.save_settings(SettingsStore.default_settings())
	_heavy_timing_only = "--heavy-timing-only" in OS.get_cmdline_user_args()
	_timeline_only = "--timeline-only" in OS.get_cmdline_user_args() or _heavy_timing_only
	if _heavy_timing_only: Engine.max_fps = SLOW_DRAW_REGRESSION_FPS
	_baseline = "--baseline" in OS.get_cmdline_user_args()
	if DisplayServer.get_name() == "headless" and not _timeline_only:
		push_error("COMBAT FEEL PROBE needs a windowed renderer, or --timeline-only for scheduling proof")
		quit(1)
		return
	if _timeline_only:
		if _heavy_timing_only:
			var draw_boundary := HeadlessPostProcessDraw.new()
			draw_boundary.draw = _headless_draw_tick
			root.add_child(draw_boundary)
		else:
			process_frame.connect(_headless_draw_tick)
	root.size = Vector2i(1920,1080)
	root.content_scale_factor = 1.0
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	Suite.write_proof_contract()
	run_scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	if _baseline and not _install_baseline_script():
		_finish()
		return
	root.add_child(run_scene)
	if _baseline: run_scene.get("_combat_pacing").debug_baseline = true
	await _settle_frames(PROBE_SETTLE_FRAMES)
	if _heavy_timing_only:
		await _heavy_hit(false)
		await _heavy_hit(true)
		_finish()
		return
	var generated: Dictionary = _enter_generated_combat()
	if not check(not generated.is_empty(),"Approved generated fire room exists"):
		_finish()
		return
	run_scene.call("_load_run_state",generated)
	run_scene.call("_close_dialogue")
	await _settle_frames(PROBE_SETTLE_FRAMES)
	var staging = ApprovedStaging.new(self)
	var layout: Dictionary = (generated["current_room_layout"] as Dictionary).duplicate(true)
	layout["enemies"] = []
	layout["traps"] = []
	staging.normalize_room(layout)
	var free: Array = [Vector2i(0,0),Vector2i(1,0),Vector2i(2,0),Vector2i(0,-1),Vector2i(0,-2),Vector2i(0,-3),Vector2i(-1,0),Vector2i(-2,0),Vector2i(-3,0),Vector2i(0,1),Vector2i(0,2),Vector2i(0,3)]
	var anchor: Vector2i = staging.place(layout,free)
	if not check(anchor != Vector2i(-1,-1),"Approved round has a valid placement"):
		_finish()
		return
	layout["player_start"] = anchor
	var foes: Array = [[1,"crawler",Vector2i(2,0),"skitter_strike"],[2,"acolyte",Vector2i(0,-3),"dust_bolt"],[3,"frostglass_lancer",Vector2i(0,3),"glass_lunge"],[4,"harrier",Vector2i(-3,0),"pelt"]]
	var enemies: Array = []
	var intents: Dictionary = {}
	for foe: Array in foes:
		enemies.append(staging.foe(int(foe[0]),str(foe[1]),staging.at(anchor,foe[2]),layout))
		intents[int(foe[0])] = str(foe[3])
	layout["enemies"] = enemies
	var initial: Dictionary = staging.stage_intents(_showcase_combat(layout),intents)
	var speeds: Array[String]
	speeds.assign(["normal"])
	if not _baseline: speeds.assign(["normal","fast","fastest"])
	for speed: String in speeds:
		await _round(layout,initial,speed)
	if not _timeline_only:
		await _heavy_hit(false)
		await _heavy_hit(true)
		await _settings_capture()
	_finish()

func _install_baseline_script() -> bool:
	var output: Array = []
	if not check(OS.execute("git",["show","HEAD:scripts/run_scene.gd"],output)==0,"Read original HEAD for before timeline"): return false
	var source: String = str(output[0])
	source = source.replace("var _defer_initial_run_presentation:","var _combat_pacing = preload(\"res://scripts/combat_pacing.gd\").new()\nvar _defer_initial_run_presentation:")
	source = source.replace("\nfunc _ready() -> void:\n","\nfunc _ready() -> void:\n\t_combat_pacing.install(self)\n")
	source = source.replace("\nfunc _exit_tree() -> void:\n","\nfunc _exit_tree() -> void:\n\t_combat_pacing.end_scope()\n")
	var start: int = source.find("func _resolve_enemy_round(")
	var end: int = source.find("func _animate_enemy_phase_steps",start)
	var phase: String = source.substr(start,end-start)
	phase = phase.replace("\t_animation_lock = true","\t_animation_lock = true\n\t_combat_pacing.begin_enemies()")
	phase = phase.replace("\tif phase_slice_safety >= 100:","\t_combat_pacing.end_scope()\n\tif phase_slice_safety >= 100:")
	source = source.substr(0,start)+phase+source.substr(end)
	start = source.find("func _animate_enemy_phase_steps(")
	end = source.find("func _tharokh_action_direction",start)
	phase = source.substr(start,end-start)
	phase = phase.replace("\t\tvar step_actor_key:","\t\tawait _combat_pacing.before_step(step)\n\t\tvar step_actor_key:")
	phase = phase.strip_edges(false,true)+"\n\t\t_combat_pacing.after_step(step)\n\n"
	source = source.substr(0,start)+phase+source.substr(end)
	source = source.replace("\t\tvar segment_frames: int = segment_frame_counts[path_index]","\t\tif _combat_pacing.enemies_active: _combat_pacing.walk_tile(path_index)\n\t\tvar segment_frames: int = segment_frame_counts[path_index]")
	start = source.find("func _animate_move_step(")
	end = source.find("func _resolved_movement_animation_path",start)
	phase = source.substr(start,end-start).replace("\tvar before_move_state:","\t_combat_pacing.walk_finished()\n\tvar before_move_state:")
	source = source.substr(0,start)+phase+source.substr(end)
	source = source.replace("\tpreload(\"res://scripts/cutout_context.gd\").apply_to_presentation(display_state, rendered_presentation)","\t_combat_pacing.observe_baseline(display_state, rendered_presentation)\n\tpreload(\"res://scripts/cutout_context.gd\").apply_to_presentation(display_state, rendered_presentation)")
	var path: String = Suite.PROOF_DIR+"/before_run_scene.gd"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	file.store_string(source)
	file.close()
	var script: Script = load(path) as Script
	if script != null:
		run_scene.get("_combat_pacing").free()
		run_scene.set_script(script)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	return check(script != null,"Load instrumented original HEAD without changing its timings")

func _round(layout: Dictionary, initial: Dictionary, speed: String) -> void:
	var settings: Dictionary = (run_scene.get("_settings") as Dictionary).duplicate(true)
	settings["combat_speed"] = speed
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	run_scene.set("_settings",settings)
	_apply_combat(layout,initial.duplicate(true))
	await _settle_frames(PROBE_SETTLE_FRAMES)
	await _play("rite_of_noon")
	await _play("tempest_form")
	var before: Dictionary = (run_scene.get("_combat_state") as Dictionary).duplicate(true)
	var scheduled: Dictionary = combat_engine.finish_player_activation(before)
	var expected: Dictionary = scheduled
	var complete: bool = false
	while not complete and combat_engine.combat_outcome(expected) == "":
		var slice: Dictionary = combat_engine.advance_one_activation_with_steps(expected,false)
		expected = slice["state"]
		complete = bool(slice.get("complete",false))
	var pacing: Node = run_scene.get("_combat_pacing")
	pacing.debug_timeline = true
	var started: int = Time.get_ticks_usec()
	run_scene.call("_on_pass_turn_pressed")
	var hero_banner_usec: int = 0
	var saw_enemy_banner: bool = false
	var deadline: int = Time.get_ticks_msec()+ROUND_TIMEOUT_MS
	while bool(run_scene.get("_animation_lock")) and Time.get_ticks_msec()<deadline:
		var banner: Node = run_scene.get("_turn_banner")
		var label: Label = banner.get("_label") as Label
		if banner.visible and label.text == "ENEMY TURN": saw_enemy_banner = true
		if saw_enemy_banner and banner.visible and label.text == "YOUR TURN" and hero_banner_usec == 0:
			hero_banner_usec = Time.get_ticks_usec()
		if not _baseline and pacing.enemies_active and not str(pacing.get("_caption")).is_empty():
			var action_text: String = str((run_scene.get("action_banner") as Label).text)
			if action_text.begins_with(str(pacing.get("_caption_prefix"))+": "):
				check(action_text == str(pacing.get("_caption")),"Rendered action text retains the approved intent caption")
		await process_frame
	var banner: Node = run_scene.get("_turn_banner")
	if saw_enemy_banner and banner.visible and (banner.get("_label") as Label).text == "YOUR TURN" and hero_banner_usec == 0:
		hero_banner_usec = Time.get_ticks_usec()
	check(hero_banner_usec > 0,"Hero turn banner observed after Pass at %s" % speed)
	var elapsed: float = float(hero_banner_usec-started)/1000000.0 if hero_banner_usec>0 else -1.0
	print("COMBAT FEEL ROUND %s%s (%s): pass_to_hero_banner=%.3fs" % ["before_" if _baseline else "",speed,"headless scheduling" if _timeline_only else "real renderer",elapsed])
	pacing.print_timeline()
	check(not bool(run_scene.get("_animation_lock")),"Round returns input at %s" % speed)
	check(run_scene.get("_combat_state") == expected,"Enemy phase preserves exact resolver state/RNG at %s" % speed)
	if speed == "normal" and not _baseline:
		check(elapsed > 0.0 and elapsed <= 6.0,"Normal staged round meets the 6.0 s budget")
		_validate_timeline(pacing.timeline)
	var file: FileAccess = FileAccess.open(OUTPUT_DIR+"/timeline_"+("before_" if _baseline else "")+speed+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"speed":speed,"renderer":not _timeline_only,"pass_to_hero_banner_seconds":elapsed,"timeline":pacing.timeline},"\t"))
	await _settle_frames(PROBE_SETTLE_FRAMES)

func _validate_timeline(rows: Array) -> void:
	var captions: Array[Dictionary]
	var actor_ends: Dictionary = {}
	for row: Dictionary in rows:
		if row["phase"] == "caption": captions.append(row)
		if row["phase"] == "hand-off gap": actor_ends[row["actor"]] = row["end"]
	check(captions.size() == 4,"All four approved actors are instrumented")
	for row: Dictionary in captions:
		check(float(actor_ends.get(row["actor"],row["start"]))-float(row["start"])<=1.4,"%s walk + attack <= 1.4 s" % row["actor"])
	for row: Dictionary in rows:
		var duration: float = float(row["end"])-float(row["start"])
		if str(row["phase"]) == "hand-off gap": check(duration <= 0.12,"Hand-off gap <= 0.12 s")
		if str(row["phase"]) == "post-action settle": check(duration <= 0.25,"Post-action settle <= 0.25 s")
		if str(row["phase"]) == "pre-action delay": check(duration <= 0.10,"Pre-action <= 0.10 s")
		if str(row["phase"]).begins_with("walk (tile"): check(duration <= 0.20,"Walk tile <= 0.20 s")

func _play(card_id: String) -> void:
	var state: Dictionary = run_scene.get("_combat_state") as Dictionary
	var hand: Array = (state["deck"] as Dictionary)["hand"]
	var index: int = hand.find(card_id)
	if not check(index>=0,"Approved preparatory card %s exists" % card_id): return
	run_scene.call("_on_card_pressed",index)
	if not bool(run_scene.get("_animation_lock")):
		run_scene.call("_on_board_tile_clicked",(state["player"] as Dictionary)["pos"])
	var deadline: int = Time.get_ticks_msec()+ROUND_TIMEOUT_MS
	while bool(run_scene.get("_animation_lock")) and Time.get_ticks_msec()<deadline: await process_frame
	check(not bool(run_scene.get("_animation_lock")),"Preparatory card resolves")
	await _settle_frames(PROBE_SETTLE_FRAMES)

func _apply_combat(layout: Dictionary, state: Dictionary) -> void:
	var next: Dictionary = (run_scene.get("_run_state") as Dictionary).duplicate(true)
	next["mode"] = "combat"
	next["current_room"] = layout["coord"]
	next["current_room_layout"] = layout.duplicate(true)
	next["combat_state"] = state
	run_scene.set("_run_state",next)
	run_scene.call("_sync_combat_state_from_run")
	run_scene.call("_reset_card_resolution")
	run_scene.set("_animation_lock",false)
	run_scene.set("_card_play_count_override",-1)
	run_scene.call("_refresh_ui")

func _showcase_combat(layout: Dictionary) -> Dictionary:
	var hand: Array[String]
	hand.assign(["rite_of_noon","tempest_form","brace","kestrel_dive","joust"])
	var state: Dictionary = combat_engine.create_combat(seed,layout,{"hp":21,"max_hp":24,"deck_cards":hand,"relics":[],"hand_size":hand.size(),"cards_per_turn":2,"draw_per_turn":2,"heal_bonus":0})
	var deck: Dictionary = (state["deck"] as Dictionary).duplicate(true)
	deck["hand"] = hand.duplicate()
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	deck["consumed"] = []
	state["deck"] = deck
	state["current_actor"] = {"kind":"player","key":"player"}
	state["cards_played_this_turn"] = 0
	state["death_bonus_card_plays_this_turn"] = 0
	state["card_play_bonus_this_turn"] = 0
	state.erase("player_turn_restrictions")
	return state

func _progression() -> Dictionary:
	var data: Dictionary = ProgressionStore.default_data()
	data["embers"] = 22
	data["run_counter"] = 3
	data["card_upgrades_unlocked"] = true
	data["level"] = 1
	var known: Array[String]
	for entry: Dictionary in GrimoireLibrary.entries():
		if not str(entry.get("id","")).is_empty(): known.append(str(entry["id"]))
	data[GrimoireLibrary.UNLOCKED_KEY] = known
	data[GrimoireLibrary.UNREAD_KEY] = []
	data[GrimoireLibrary.NOTICE_KEY] = ""
	return ContextualCombatTutorial.dismiss_tutorial(data)

func _enter_generated_combat() -> Dictionary:
	for offset: int in range(64):
		var state: Dictionary = run_engine.repair_loaded_run_state(run_engine.create_new_run(seed+offset,_progression()))
		var found: Dictionary = _search_combat_room(state,"fire",2)
		if found.is_empty(): continue
		var entered: Dictionary = run_engine.move_to_room(found["origin"],found["destination"])
		if str(entered.get("mode","")) == "combat":
			print("COMBAT FEEL FIXTURE: seed=%d room=%s" % [seed+offset,found["destination"]])
			return entered
	return {}

func _search_combat_room(initial: Dictionary, element: String, min_depth: int) -> Dictionary:
	var queue: Array = [{"state":initial}]
	var visited: Dictionary = {"0,0":true}
	var safety: int = 0
	while not queue.is_empty() and safety<160:
		safety += 1
		var state: Dictionary = (queue.pop_front() as Dictionary)["state"]
		for destination: Vector2i in run_engine.available_moves(state):
			var room: Dictionary = run_engine.room_metadata(state,destination)
			if str(room.get("type","")) == "combat" and int(room.get("depth",0))>=min_depth and str(room.get("element",""))==element:
				return {"origin":state,"destination":destination}
		for destination: Vector2i in run_engine.available_moves(state):
			var key: String = "%d,%d" % [destination.x,destination.y]
			if visited.has(key) or int(run_engine.room_metadata(state,destination).get("depth",0))>min_depth+1: continue
			visited[key] = true
			var traversed: Dictionary = _resolve_room(run_engine.move_to_room(state,destination))
			if str(traversed.get("mode","")) == "room": queue.append({"state":traversed})
	return {}

func _resolve_room(state: Dictionary) -> Dictionary:
	match str(state.get("mode","")):
		"combat":
			var battle: Dictionary = (state["combat_state"] as Dictionary).duplicate(true)
			for enemy_unit: Dictionary in battle.get("enemies",[]): enemy_unit["hp"] = 0
			var reward: Dictionary = run_engine.finish_combat(state,battle)
			return run_engine.skip_reward_for_heal(reward) if str(reward.get("mode",""))=="reward" else reward
		"treasure":
			var relics: Array = state.get("pending_relics",[])
			return run_engine.claim_relic(state,str(relics[0])) if not relics.is_empty() else state
		"campfire": return run_engine.leave_campfire(state)
	return state

func tile_screen_position(tile: Vector2i) -> Vector2:
	var view: Control = board()
	return view.get_global_transform() * view.world_position_for_tile(tile)

func board() -> Control:
	return run_scene.get("board_view") as Control

func enemy(id: int, type: String, pos: Vector2i, depth: int=1, element: String="") -> Dictionary:
	var hp: int = int(RoomGeneratorScript.new().call("_scaled_enemy_max_hp",type,depth))
	if hp<=0: hp = int(GameDataScript.enemy_def(type).get("max_hp",1))
	var result: Dictionary = {"id":id,"type":type,"pos":pos,"hp":hp,"max_hp":hp,"block":0,"stoneskin":0}
	if not element.is_empty(): result["element"] = element
	return result

func check(condition: bool, message: String) -> bool:
	if not condition: _failures.append(message)
	return condition

func _headless_draw_tick() -> void:
	# Heavy-hit scheduling uses a late-process boundary; round timing retains the
	# existing turn-clock suite's explicit dummy-renderer completion signal.
	RenderingServer.frame_post_draw.emit()

func _settle_frames(count: int) -> void:
	for _frame: int in range(count): await process_frame

func _heavy_hit(reduced: bool) -> void:
	preload("res://tests/suites/combat_motion_timing_suite.gd")._install_fixture(run_scene,reduced)
	var settings: Dictionary = run_scene.get("_settings") as Dictionary
	settings["combat_speed"] = "normal"
	var before: Dictionary = (run_scene.get("_combat_state") as Dictionary).duplicate(true)
	var action: Dictionary = {"type":"ranged","damage":HEAVY_PROOF_DAMAGE,"range":HEAVY_PROOF_RANGE,"element":"none"}
	var target: Vector2i = (before["enemies"] as Array)[0]["pos"]
	var after: Dictionary = combat_engine.resolve_player_action_for_presentation(before,action,target)["state"]
	run_scene.set("_animation_lock",true)
	var pacing: Node = run_scene.get("_combat_pacing")
	pacing.begin_card()
	await _settle_frames(PROBE_SETTLE_FRAMES)
	_capture_heavy = not reduced
	_capture_reduced = reduced
	_heavy_frame = -1
	_peak_pending = false
	_peak_captured = false
	_heavy_images.clear()
	_heavy_offsets.clear()
	_heavy_trace.clear()
	_heavy_events.clear()
	_last_frame = await _image()
	var stop: Node = pacing.hit_stop
	if not stop.stop_started.is_connected(_impact_started): stop.stop_started.connect(_impact_started)
	if not stop.stop_ended.is_connected(_impact_ended): stop.stop_ended.connect(_impact_ended)
	RenderingServer.frame_post_draw.connect(_heavy_draw)
	var done: Dictionary = {"done":false}
	_present_heavy(before,after,action,target,done)
	var action_deadline: int = Time.get_ticks_msec() + ROUND_TIMEOUT_MS
	while not done["done"] and Time.get_ticks_msec() < action_deadline: await process_frame
	check(done["done"], "Heavy action completes within its watchdog")
	var action_done_offset: int = _heavy_frame
	# Animation completion is measured in elapsed time; proof offsets are measured
	# in rendered frames. Readback/slow rendering can finish the action before +8.
	# Retain the fixture/scope until every requested draw has actually occurred.
	var capture_deadline: int = Time.get_ticks_msec() + HEAVY_CAPTURE_TIMEOUT_MS
	while (_heavy_frame <= 8 if not reduced else not _peak_captured) and Time.get_ticks_msec() < capture_deadline:
		await process_frame
	RenderingServer.frame_post_draw.disconnect(_heavy_draw)
	check(not reduced or _peak_captured,"Reduced-motion impact captured after its half-duration stop")
	check(reduced or (_heavy_frame>8 and _peak_captured),"Heavy-hit frame offsets and post-stop peak captured")
	if not reduced:
		check(_heavy_offsets == [0, 1, 4, 8], "All exact heavy-hit offsets observed in order")
	for filename: String in _heavy_images:
		check((_heavy_images[filename] as Image).save_png(OUTPUT_DIR + "/" + filename) == OK, "Heavy capture writes: " + filename)
	var trace: Dictionary = {"renderer": DisplayServer.get_name(), "headless_scheduling": _timeline_only, "reduced_motion": reduced, "action_done_offset": action_done_offset, "captured_offsets": _heavy_offsets, "events": _heavy_events, "draws": _heavy_trace}
	var trace_path: String = OUTPUT_DIR + ("/reduced_hit_trace.json" if reduced else "/heavy_hit_trace.json")
	var file: FileAccess = FileAccess.open(trace_path, FileAccess.WRITE)
	check(file != null, "Heavy frame trace writes")
	if file != null: file.store_string(JSON.stringify(trace, "\t"))
	print("COMBAT FEEL HEAVY: reduced=%s action_done_offset=%d final_offset=%d offsets=%s peak=%s" % [reduced, action_done_offset, _heavy_frame, _heavy_offsets, _peak_captured])
	run_scene.set("_animation_lock",false)
	pacing.end_scope()
	_capture_heavy = false
	_capture_reduced = false

func _present_heavy(before: Dictionary, after: Dictionary, action: Dictionary, target: Vector2i, done: Dictionary) -> void:
	await run_scene.call("_animate_player_action_step",before,after,"lantern_shot",action,target,[])
	done["done"] = true

func _impact_started(duration: float) -> void:
	_heavy_events.append({"kind": "stop_started", "duration_ms": duration, "usec": Time.get_ticks_usec(), "process_frame": Engine.get_process_frames(), "scale": Engine.time_scale})
	if _capture_heavy:
		if _last_frame != null: _heavy_images["heavy_hit_minus_1.png"] = _last_frame
		_heavy_frame = 0

func _impact_ended() -> void:
	_heavy_events.append({"kind": "stop_ended", "usec": Time.get_ticks_usec(), "process_frame": Engine.get_process_frames(), "scale": Engine.time_scale})
	if _capture_heavy or _capture_reduced: _peak_pending = true

func _heavy_draw() -> void:
	var pacing: Node = run_scene.get("_combat_pacing")
	var flash: Dictionary = (board().get("presentation") as Dictionary).get("combat_feel_flash", {})
	var sample: Dictionary = {"offset": _heavy_frame, "usec": Time.get_ticks_usec(), "process_frame": Engine.get_process_frames(), "stop_active": pacing.hit_stop.active, "scale": Engine.time_scale, "flash": flash.duplicate()}
	if _heavy_frame >= 0 or _peak_pending: _heavy_trace.append(sample)
	# Keep the preceding frame until impact; afterwards read back only requested
	# samples. PNG encoding happens after disconnect, outside the timing callback.
	var needs_image: bool = _heavy_frame < 0 or _heavy_frame in [0, 1, 4, 8] or _peak_pending
	var current: Image = root.get_texture().get_image() if needs_image and not _timeline_only else null
	if _capture_heavy and _heavy_frame >= 0:
		if _heavy_frame in [0, 1, 4, 8]:
			_heavy_offsets.append(_heavy_frame)
			if current != null:
				_heavy_images["heavy_hit_%s.png" % ("0" if _heavy_frame == 0 else "plus_%d" % _heavy_frame)] = current
		_heavy_frame += 1
	if (_capture_heavy or _capture_reduced) and _peak_pending:
		check(not pacing.hit_stop.active and Engine.time_scale > 0.0, "Post-stop capture has restored positive time scale")
		var maximum: float = 0.0
		for opacity: float in flash.values(): maximum = maxf(maximum, opacity)
		check(absf(maximum - preload("res://scripts/combat_pacing.gd").flash_opacity(0.0)) <= PEAK_OPACITY_TOLERANCE, "First post-stop draw contains the approved enemy white peak")
		if current != null:
			_heavy_images["reduced_motion_hit.png" if _capture_reduced else "heavy_hit_post_stop_peak.png"] = current
		_peak_pending = false
		_peak_captured = true
	if current != null: _last_frame = current

func _settings_capture() -> void:
	run_scene.call("_open_menu_overlay")
	run_scene.call("_open_settings_overlay")
	await _settle_frames(PROBE_SETTLE_FRAMES)
	var option: OptionButton = (run_scene.get("_settings_panel") as Node).find_child("CombatSpeedOption",true,false) as OptionButton
	if option != null:
		option.grab_focus()
		var parent: Node = option.get_parent()
		while parent != null and not parent is ScrollContainer: parent = parent.get_parent()
		if parent is ScrollContainer: parent.ensure_control_visible(option)
	await _capture("combat_speed_settings.png")

func _image() -> Image:
	await RenderingServer.frame_post_draw
	return null if _timeline_only else root.get_texture().get_image()

func _capture(filename: String) -> void:
	var current: Image = await _image()
	current.save_png(OUTPUT_DIR+"/"+filename)

func _finish() -> void:
	for failure: String in _failures: push_error(failure)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("COMBAT FEEL PROBE TEST RESULT: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

class ApprovedStaging:
	extends RefCounted
	## Shared staging and input helpers for the Group B (tactics) trailer shots.
	##
	## Everything here stages fixtures (room choice, positions, HP, intents,
	## surfaces) or drives the production RunScene input handlers. Outcomes always
	## come from the real rules through the real UI flow.

	const PathUtils = preload("res://scripts/path_utils.gd")
	const GameDataScript = preload("res://scripts/game_data.gd")
	const BoardSurfaceRules = preload("res://scripts/board_surface_rules.gd")
	const CombatObjectiveRules = preload("res://scripts/combat_objective_rules.gd")

	const INVALID := Vector2i(-1, -1)
	## Authored-layout point the action should gravitate to: board centre, a little
	## high so the hand never overlaps the play.
	const FOCUS := Vector2(960.0, 440.0)

	var d
	var _xf: int = 0
	var _pointer := Vector2(-1.0, -1.0)


	func _init(director) -> void:
		d = director


	# --- Placement -------------------------------------------------------------

	## Offset under one of the eight grid symmetries.
	static func transform_offset(offset: Vector2i, xf: int) -> Vector2i:
		var o: Vector2i = offset
		if xf >= 4:
			o = Vector2i(o.y, o.x)
		match xf % 4:
			1:
				o = Vector2i(-o.y, o.x)
			2:
				o = Vector2i(-o.x, -o.y)
			3:
				o = Vector2i(o.y, -o.x)
		return o


	func at(anchor: Vector2i, offset: Vector2i) -> Vector2i:
		return anchor + transform_offset(offset, _xf)


	func dir(offset: Vector2i) -> Vector2i:
		return transform_offset(offset, _xf)


	func occupied(layout: Dictionary) -> Dictionary:
		var result: Dictionary = {}
		for key: String in ["terrain", "loot", "npcs"]:
			for entry: Variant in layout.get(key, []):
				if typeof(entry) == TYPE_DICTIONARY:
					result[(entry as Dictionary).get("pos", INVALID)] = key
		return result


	func is_floor(layout: Dictionary, tile: Vector2i) -> bool:
		var grid: Array = layout.get("grid", []) as Array
		if tile.x < 1 or tile.y < 1 or tile.y >= grid.size() - 1 or tile.x >= (grid[0] as Array).size() - 1:
			return false
		return PathUtils.is_passable(grid, tile)


	func is_interior(layout: Dictionary, tile: Vector2i) -> bool:
		var grid: Array = layout.get("grid", []) as Array
		return tile.x >= 1 and tile.y >= 1 and tile.y < grid.size() - 1 and tile.x < (grid[0] as Array).size() - 1


	## Tactics shots want full sight and the plain Defeat All objective (no exit
	## thresholds or leader markers competing with the mechanic on screen).
	func normalize_room(layout: Dictionary, umbra_stage: String = "clear") -> void:
		layout["umbra_stage"] = umbra_stage
		layout["objective"] = {
			"type": CombatObjectiveRules.KILL_ALL,
			"name": CombatObjectiveRules.display_name(CombatObjectiveRules.KILL_ALL),
			"description": CombatObjectiveRules.description(CombatObjectiveRules.KILL_ALL),
			"icon_path": CombatObjectiveRules.icon_path(CombatObjectiveRules.KILL_ALL),
		}


	## Removes every furniture piece and loot pickup for an uncluttered arena.
	func clear_furniture(layout: Dictionary, keep_if: Callable = Callable()) -> void:
		for key: String in ["terrain", "loot"]:
			var kept: Array = []
			for entry: Variant in layout.get(key, []):
				if keep_if.is_valid() and bool(keep_if.call((entry as Dictionary).get("pos", INVALID))):
					kept.append(entry)
			layout[key] = kept


	func is_wall(layout: Dictionary, tile: Vector2i) -> bool:
		return not PathUtils.is_passable(layout.get("grid", []) as Array, tile)


	## Finds an anchor (and grid symmetry) where every `free` offset is interior
	## floor. Optional constraints: `walls` offsets must be wall/pillar/edge,
	## `xforms` limits symmetries, `focus` moves the scoring point, `keep_terrain`
	## penalises displacing furniture harder. Terrain and loot on `free` tiles are
	## removed from the layout. Returns the anchor; `at()`/`dir()` then map offsets.
	func place(layout: Dictionary, free: Array, opts: Dictionary = {}) -> Vector2i:
		var grid: Array = layout.get("grid", []) as Array
		var occ: Dictionary = occupied(layout)
		var focus: Vector2 = opts.get("focus", FOCUS)
		var xforms: Array = opts.get("xforms", [0, 1, 2, 3, 4, 5, 6, 7])
		var walls: Array = opts.get("walls", [])
		var keep: Array = opts.get("keep", [])
		var penalty: float = float(opts.get("displace_penalty", 900.0))
		var occlusion: float = float(opts.get("occlusion_penalty", 14000.0))
		var best := INVALID
		var best_xf: int = 0
		var best_score: float = INF
		for xf_var: Variant in xforms:
			var xf: int = int(xf_var)
			for y: int in range(1, grid.size() - 1):
				for x: int in range(1, (grid[y] as Array).size() - 1):
					var anchor := Vector2i(x, y)
					var ok: bool = true
					var centroid := Vector2.ZERO
					var displaced: int = 0
					var spread: float = 0.0
					for offset_var: Variant in free:
						var tile: Vector2i = anchor + transform_offset(offset_var as Vector2i, xf)
						if not is_floor(layout, tile):
							ok = false
							break
						if occ.has(tile):
							displaced += 1
						centroid += d.tile_screen_position(tile)
						spread += (d.tile_screen_position(tile) as Vector2).distance_squared_to(focus)
					if not ok:
						continue
					for offset_var: Variant in walls:
						if not is_wall(layout, anchor + transform_offset(offset_var as Vector2i, xf)):
							ok = false
							break
					if not ok:
						continue
					for offset_var: Variant in keep:
						if not occ.has(anchor + transform_offset(offset_var as Vector2i, xf)):
							ok = false
							break
					if not ok:
						continue
					centroid /= float(free.size())
					var required_here: Dictionary = {}
					for offset_var: Variant in free:
						required_here[anchor + transform_offset(offset_var as Vector2i, xf)] = true
					var occluded: float = 0.0
					for offset_var: Variant in free:
						var tile: Vector2i = anchor + transform_offset(offset_var as Vector2i, xf)
						for front: Vector2i in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2), Vector2i(2, 2)]:
							var weight: float = 1.0 if front.x + front.y <= 2 else 0.4
							var blocker: Vector2i = tile + front
							if is_interior(layout, blocker) and is_wall(layout, blocker):
								occluded += weight
							elif occ.get(blocker, "") == "terrain" and not required_here.has(blocker) and front.x + front.y <= 2:
								occluded += 0.25
					var score: float = centroid.distance_squared_to(focus) + spread / float(free.size()) * 0.5 + displaced * penalty + occluded * occlusion
					if score < best_score:
						best_score = score
						best = anchor
						best_xf = xf
		if best == INVALID:
			return INVALID
		_xf = best_xf
		var required: Dictionary = {}
		for offset_var: Variant in free:
			required[best + transform_offset(offset_var as Vector2i, best_xf)] = true
		for key: String in ["terrain", "loot"]:
			var kept: Array = []
			for entry: Variant in layout.get(key, []):
				if not required.has((entry as Dictionary).get("pos", INVALID)):
					kept.append(entry)
			layout[key] = kept
		print("B_PLACE anchor=%s xf=%d score=%.0f room=%s" % [str(best), best_xf, best_score, str(layout.get("coord"))])
		return best


	func remove_furniture(layout: Dictionary, tiles: Array) -> void:
		var lookup: Dictionary = {}
		for tile: Variant in tiles:
			lookup[tile] = true
		for key: String in ["terrain", "loot"]:
			var kept: Array = []
			for entry: Variant in layout.get(key, []):
				if not lookup.has((entry as Dictionary).get("pos", INVALID)):
					kept.append(entry)
			layout[key] = kept


	func add_terrain(layout: Dictionary, tile: Vector2i, kind: String = "wooden_crate", hp: int = 3) -> void:
		remove_furniture(layout, [tile])
		var terrain: Array = layout.get("terrain", []) as Array
		terrain.append({"id": "terrain_%d_%d" % [tile.x, tile.y], "kind": kind, "pos": tile, "hp": hp, "max_hp": hp})
		layout["terrain"] = terrain


	func foe(id: int, type: String, tile: Vector2i, layout: Dictionary, hp: int = -1) -> Dictionary:
		var e: Dictionary = d.enemy(id, type, tile, int(layout.get("depth", 2)), str(layout.get("element", "")))
		if hp > 0:
			e["hp"] = mini(hp, int(e.get("max_hp", hp)))
		return e


	# --- Combat-state staging ---------------------------------------------------

	## Stages a specific printed intent on an enemy and rebuilds the opening
	## initiative queue so the rail and telegraphs match it.
	func stage_intents(state: Dictionary, intents_by_id: Dictionary) -> Dictionary:
		var ce = d.combat_engine
		var enemies: Array = state.get("enemies", []) as Array
		for index: int in range(enemies.size()):
			var enemy: Dictionary = enemies[index] as Dictionary
			var wanted: String = str(intents_by_id.get(int(enemy.get("id", -1)), ""))
			if wanted.is_empty():
				continue
			var defs: Array = ce.call("_scaled_enemy_intents", GameDataScript.enemy_def(str(enemy.get("type", ""))).get("intents", []), int(state.get("room_depth", 1)))
			var found: bool = false
			for intent_var: Variant in defs:
				var intent: Dictionary = intent_var as Dictionary
				if str(intent.get("id", "")) == wanted:
					enemy["intent"] = ce.call("_surface_prepare_enemy_intent", state, enemy, intent.duplicate(true))
					found = true
			d.check(found, "Enemy %s has no intent %s" % [str(enemy.get("type")), wanted])
			enemies[index] = enemy
		state["enemies"] = enemies
		state = ce.call("_initialize_initiative_queue", state)
		state["current_actor"] = {"kind": "player", "key": "player"}
		return state


