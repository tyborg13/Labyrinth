extends "res://tests/combat_feel_probe.gd"
## Reuse the pace-01 staging and Movie Maker viewport for matched hurry runs.

const TestClock = preload("res://tests/helpers/presentation_test_clock.gd")
const Pacing = preload("res://scripts/combat_pacing.gd")
const OUTPUT_PREFIX: String = "hurry_round_"
const FRAME_SECONDS: float = TestClock.STEP_SECONDS
const CLOCK_COMPARISON_EPSILON_SECONDS: float = 0.00001

var _callout_windows: Array[Dictionary]

func _instantiate_run_scene() -> Node:
	var instance: Node = super._instantiate_run_scene()
	if not _timeline_only: return instance
	# The redirect callout uses wall time even at Fastest. Give it the same
	# fixed unscaled frame source as hit-stop in the headless comparison.
	var script := GDScript.new()
	var callouts: Script = TestClock.clocked_script(preload("res://scripts/intent_callouts.gd"))
	var source: String = instance.get_script().source_code
	source = source.replace("await IntentCallouts.play(self, animated_state, step)", "await _hurry_probe_callout.call(animated_state, step)")
	script.source_code = source + "\nvar _hurry_probe_callout: Callable\n"
	if check(script.reload() == OK, "Compile the fixed-frame round scene"):
		instance.set_script(script)
		instance.set("_hurry_probe_callout", _play_clocked_callout.bind(callouts))
	return instance

func _play_clocked_callout(state: Dictionary, step: Dictionary, callouts: Script) -> void:
	var pacing: Node = run_scene.get("_combat_pacing")
	var origin: int = pacing.get("_round_started_usec")
	var started: float = float(TestClock.now_usec - origin) / 1000000.0
	await callouts.play(run_scene, state, step)
	_callout_windows.append({"start": started, "end": float(TestClock.now_usec - origin) / 1000000.0})

func _round(layout: Dictionary, initial: Dictionary, speed: String) -> void:
	var from_caption: bool = "--hurry-from-caption" in OS.get_cmdline_user_args()
	if not _timeline_only:
		var mode: String = "caption" if from_caption else "unheld"
		await _play_round(layout, initial, speed, mode, Pacing)
		return
	if from_caption:
		if speed == "normal": await _play_round(layout, initial, speed, "caption", Pacing)
		return
	if speed == "fast": return
	var release: Script = _release_pacing()
	if release == null: return
	var before: Dictionary = await _play_round(layout, initial, speed, "release", release)
	var unheld: Dictionary = await _play_round(layout, initial, speed, "unheld", Pacing)
	var held: Dictionary = await _play_round(layout, initial, speed, "banner", Pacing)
	check(before["timeline"] == unheld["timeline"], "Unheld %s timeline matches release frame for frame" % speed)
	check(before["state"] == unheld["state"] and held["state"] == unheld["state"], "Pacing preserves the %s round's resolver result" % speed)
	check(held["stops"] == unheld["stops"], "Held and unheld %s use identical real-time hit-stops" % speed)
	_compare_presentation(unheld, held, speed)

func _release_pacing() -> Script:
	var ref: String = ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--release-ref="): ref = argument.trim_prefix("--release-ref=")
	var contents: Array = []
	if not check(not ref.is_empty() and OS.execute("git", ["show", ref + ":scripts/combat_pacing.gd"], contents) == 0, "Read the requested release pacing reference"):
		return null
	var script := GDScript.new()
	var source: String = str(contents[0]).replace("class_name CombatPacing", "")
	if not source.contains("func observe_hurry_input("):
		source += "\nfunc observe_hurry_input(_event: InputEvent) -> void:\n\tpass\n"
	script.source_code = _with_legacy_number_contact_hooks(source)
	if not check(script.reload() == OK, "Compile the release pacing reference"): return null
	return script

func _play_round(layout: Dictionary, initial: Dictionary, speed: String, mode: String, script: Script) -> Dictionary:
	var settings: Dictionary = run_scene.get("_settings").duplicate(true)
	settings["combat_speed"] = speed
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	run_scene.set("_settings", settings)
	_apply_combat(layout, initial.duplicate(true))
	await _settle_frames(PROBE_SETTLE_FRAMES)
	await _play("rite_of_noon")
	await _play("tempest_form")
	var pacing: Node = run_scene.get("_combat_pacing")
	var stops: Array[float]
	if _timeline_only:
		pacing.free()
		var previous_clock: Node = run_scene.get_node_or_null("PresentationTestClock")
		if previous_clock != null: previous_clock.free()
		pacing = TestClock.install_pacing(run_scene, script)
		run_scene.set("_combat_pacing", pacing)
	pacing.hit_stop.stop_started.connect(func(duration: float) -> void: stops.append(duration))
	pacing.debug_timeline = true
	_callout_windows.clear()
	if not _timeline_only:
		await _capture("round_start.png")
		print("PACE ROUND CAPTURE START_FRAME=%d" % Engine.get_frames_drawn())

	# Drive the normal Pass path, then the real viewport input path.
	run_scene.call("_on_pass_turn_pressed")
	var holding: bool = mode == "banner"
	if holding: _send_space(true)
	var deadline: int = Time.get_ticks_msec() + ROUND_TIMEOUT_MS
	var saw_hurry: bool = false
	while bool(run_scene.get("_animation_lock")) and Time.get_ticks_msec() < deadline:
		if mode == "caption" and not holding and not str(pacing.get("_caption")).is_empty():
			holding = true
			_send_space(true)
		if holding and pacing.enemies_active:
			var expected: float = SettingsStore.combat_speed_scale(settings) * (1.6 if pacing.get("_enemy_action_active") else 2.0)
			saw_hurry = true
			check(is_equal_approx(pacing.current_scale(), expected), "Viewport hold doubles the %s enemy scale" % speed)
		await process_frame
	if holding: _send_space(false)
	check(not bool(run_scene.get("_animation_lock")), "%s %s round returns input" % [speed, mode])
	check(not holding or saw_hurry, "%s %s round observes an active hold" % [speed, mode])
	if not _timeline_only:
		print("PACE ROUND CAPTURE END_FRAME=%d" % Engine.get_frames_drawn())
		await _capture("round_end.png")

	var timeline: Array = pacing.timeline.duplicate(true)
	var actors: Dictionary = {}
	for row: Dictionary in timeline:
		if row["phase"] == "caption": actors[row["actor"]] = true
	check(actors.size() == 4, "%s %s presents all four staged enemies" % [speed, mode])
	var path: String = OUTPUT_DIR.path_join(OUTPUT_PREFIX + speed + "_" + mode + ".json")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"mode": mode, "speed": speed, "stops_ms": stops, "callouts": _callout_windows, "timeline": timeline}, "\t"))
	var elapsed: float = float(timeline.back()["end"]) if not timeline.is_empty() else -1.0
	print("ENEMY HURRY ROUND %s %s: scope=%.3fs, hit_stop_ms=%s, timeline=%s" % [speed, mode, elapsed, stops, ProjectSettings.globalize_path(path)])
	return {"timeline": timeline, "stops": stops, "callouts": _callout_windows.duplicate(), "state": run_scene.get("_combat_state").duplicate(true)}

func _send_space(pressed: bool) -> void:
	var space := InputEventKey.new()
	space.keycode = KEY_SPACE
	space.physical_keycode = KEY_SPACE
	space.pressed = pressed
	run_scene.get_viewport().push_input(space)

func _compare_presentation(unheld: Dictionary, held: Dictionary, speed: String) -> void:
	var normal_phases: Dictionary = _scaled_phases(unheld, speed, 1.0)
	var hurried_phases: Dictionary = _scaled_phases(held, speed, 2.0)
	check(normal_phases.keys() == hurried_phases.keys(), "The %s hold preserves the phase sequence" % speed)
	var unheld_clocked: float = 0.0
	var held_clocked: float = 0.0
	for phase: String in normal_phases:
		var normal: float = normal_phases[phase]
		var hurried: float = hurried_phases.get(phase, 0.0)
		check(absf(hurried - normal * 0.5) <= FRAME_SECONDS + CLOCK_COMPARISON_EPSILON_SECONDS, "%s %s halves within one frame (%.4f s vs %.4f s)" % [speed, phase, normal, hurried])
		unheld_clocked += normal
		held_clocked += hurried
	var tolerance: float = FRAME_SECONDS * normal_phases.size()
	check(absf(held_clocked - unheld_clocked * 0.5) <= tolerance, "Held %s presentation halves within the frame budget across phases" % speed)
	print("ENEMY HURRY PRESENTATION %s: %.3fs unheld, %.3fs held" % [speed, unheld_clocked, held_clocked])

func _scaled_phases(round: Dictionary, speed: String, hurry: float) -> Dictionary:
	var phases: Dictionary = {}
	for row: Dictionary in round["timeline"]:
		var key: String = "%s/%s" % [row["actor"], row["phase"]]
		# Pass lock/cache frames share the first caption lead's fixed deadline.
		if row["phase"] == "banner" or key == "enemy_1/pre-action delay": key = "first banner and lead"
		var duration: float = _clocked_seconds(row, speed, hurry)
		for callout: Dictionary in round["callouts"]:
			duration -= maxf(0.0, minf(row["end"], callout["end"]) - maxf(row["start"], callout["start"]))
		phases[key] = float(phases.get(key, 0.0)) + maxf(0.0, duration)
	return phases

func _clocked_seconds(phase: Dictionary, speed: String, hurry: float) -> float:
	var scale: float = SettingsStore.combat_speed_scale({"combat_speed": speed})
	if str(phase["phase"]) in ["wind-up", "impact", "hit reaction / damage number", "number contact wait"]:
		scale *= 0.8
	return (float(phase["clock_end"]) - float(phase["clock_start"])) / (scale * hurry)
