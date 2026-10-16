extends RefCounted

const Sources = preload("res://tests/sfx_sync_sources.gd")
const Pacing = preload("res://tests/sfx_sync_pacing.gd")
const MovieClock = preload("res://tools/demo_clips/clock.gd")

static func install(clock: RefCounted) -> Node:
	MovieClock.current = clock
	var source: String = FileAccess.get_file_as_string("res://scripts/run_scene.gd")
	source = source.replace("Time.get_ticks_usec()", "_demo_clock.usec").replace("Time.get_ticks_msec()", "int(_demo_clock.usec / 1000)")
	source = source.replace("IntentCallouts.play(", "_demo_callouts.play(")
	source = source.replace('const SfxBankScript = preload("res://scripts/sfx_bank.gd")', 'var SfxBankScript: Script')
	source = source.replace("\tboard_view.present_sound_snapshot(display_state, presentation)", "\t_demo_clock.render(display_state, presentation); board_view.present_sound_snapshot(display_state, presentation)")
	source += "\nvar _demo_clock: RefCounted\nvar _demo_callouts: GDScript\n"
	var script: GDScript = Sources.compile_script("scripts/run_scene.gd", source)
	assert(script != null, "Demo clock instrumentation must compile")
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get("_combat_pacing").free()
	scene.set_script(script)
	scene.set("_demo_clock", clock)
	var callouts: String = FileAccess.get_file_as_string("res://scripts/intent_callouts.gd")
	callouts = callouts.replace("Time.get_ticks_usec()", 'int(scene.get("_demo_clock").usec)')
	scene.set("_demo_callouts", Sources.compile_script("scripts/intent_callouts.gd", callouts))
	# The harness seeds registered cues; lazy legacy cues need the same seed.
	var bank_source: String = FileAccess.get_file_as_string("res://scripts/sfx_bank.gd")
	bank_source = bank_source.replace("seed_value: int = -1", "seed_value: int = 410")
	bank_source = bank_source.replace("_compile(cue_id, compiled, -1)", "_compile(cue_id, compiled, 410)")
	scene.set("SfxBankScript", Sources.compile_script("scripts/sfx_bank.gd", bank_source))
	scene.get("_sfx_pitch_rng").seed = 410
	# Surface pulses, creature idle frames and shake use board-local wall reads.
	# Its retained render layers instantiate get_script(), sharing this exact
	# adapter and the same movie clock without changing their production logic.
	var board_source: String = FileAccess.get_file_as_string("res://scripts/combat_board_view.gd")
	board_source = board_source.replace("Time.get_ticks_usec()", "DemoClock.current.usec").replace("Time.get_ticks_msec()", "int(DemoClock.current.usec / 1000)")
	board_source = board_source.replace("IntentBadges.", "DemoClock.badges.")
	board_source += '\nconst DemoClock = preload("res://tools/demo_clips/clock.gd")\n'
	var badges: String = FileAccess.get_file_as_string("res://scripts/intent_badges.gd")
	badges = badges.replace("Time.get_ticks_msec()", "int(DemoClock.current.usec / 1000)")
	badges += '\nconst DemoClock = preload("res://tools/demo_clips/clock.gd")\n'
	MovieClock.badges = Sources.compile_script("scripts/intent_badges.gd", badges)
	scene.get_node("BoardUnderlay/CombatBoard").set_script(Sources.compile_script("scripts/combat_board_view.gd", board_source))
	scene.get("_combat_pacing").free()
	var pacing := Pacing.new()
	pacing.sync_clock = clock
	scene.set("_combat_pacing", pacing)
	pacing.install(scene)
	# Hit-stop must expire in movie time too; retaining wall time here produces
	# different frame counts on a slow encoder and a fast headless machine.
	var stop_source: String = FileAccess.get_file_as_string("res://scripts/combat_hit_stop.gd")
	stop_source = stop_source.replace("Time.get_ticks_usec()", "_demo_clock.usec")
	stop_source += "\nvar _demo_clock: RefCounted\n"
	pacing.hit_stop.set_script(Sources.compile_script("scripts/combat_hit_stop.gd", stop_source))
	pacing.hit_stop.set("_demo_clock", clock)
	pacing.hit_stop.restore_scale = Callable(pacing, "current_scale")
	return scene
