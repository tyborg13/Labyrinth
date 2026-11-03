extends SceneTree

const Scene = preload("death_clock_scene.gd")
const Pacing = preload("death_clock_pacing.gd")
const Fixture = preload("res://tests/suites/en06_enemies_suite.gd")
const Death = preload("res://scripts/maquette_cutout_runtime/death.gd")
const Action = preload("res://scripts/maquette_cutout_runtime/action.gd")
const SPEEDS := ["normal", "fast", "fastest"]
const MIXED_RIGS := ["hoarfrost_seer", "chainbound_gaoler"]
const FRAME_USEC: int = 16667
const CLOCK_ROUNDING_SECONDS: float = 0.0001
const PHASE_ROUNDING_EPSILON: float = 0.000001
var errors: Array[String]
var cases: int = 0
var event_crossings: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()

func _run() -> void:
	for speed: String in SPEEDS:
		for type: String in MIXED_RIGS:
			for overlap: bool in [false, true]: await _case(type, speed, overlap)
	for error: String in errors: printerr(error)
	print("RR46 MIXED DEATH CLOCKS: %s (%d blocking/overlap cases; three speeds; %d authored event crossings)" % ["PASS" if errors.is_empty() else "FAIL", cases, event_crossings])
	quit(0 if errors.is_empty() else 1)

func check(ok: bool, text: String) -> void:
	if not ok: errors.append(text)

func _case(type: String, speed: String, overlap: bool) -> void:
	cases += 1
	var label: String = type + "/" + speed + ("/overlap" if overlap else "/blocking")
	var scene: Control = load("res://scenes/run_scene.tscn").instantiate()
	scene.set_script(Scene)
	scene._combat_pacing.free()
	var pacing := Pacing.new()
	scene._combat_pacing = pacing
	pacing.install(scene)
	root.add_child(scene)
	scene._settings = {"combat_speed":speed}
	scene._run_state = {"mode":"combat"}
	scene._animation_lock = true
	var units: Array[Dictionary]
	for actor: String in [type, "ember_tick", "ash_hound"]:
		units.append(Fixture.enemy(actor, units.size()+1, Vector2i(units.size()+2, 3)))
	var before: Dictionary = Fixture.state(units)
	var after: Dictionary = before.duplicate(true)
	for unit: Dictionary in after["enemies"]: unit["hp"] = 0
	if overlap:
		pacing.begin_enemies()
		pacing._set_enemy_action_active(true)
	else: pacing.begin_card()
	var scale: float = preload("res://scripts/settings_store.gd").combat_speed_scale(scene._settings) * (pacing.ENEMY_ACTION_SPEED_SCALE if overlap else 1.0)
	check(is_equal_approx(Engine.time_scale, scale), label+": production speed scope")
	var hold: int = 0
	if overlap:
		check(pacing.overlap_defeats(before, after, true), label+": overlap route")
		var entry: Dictionary = pacing._deaths[0]
		scene.sequence = entry.get("sequence", {})
		hold = int(entry["duration"])
		var origin: int = pacing.presentation_usec()
		var wall: int = pacing.wall_usec
		while not pacing._deaths.is_empty() and pacing.presentation_usec()-origin <= hold + FRAME_USEC:
			var shown: Dictionary = {}
			pacing.decorate(after, shown)
			scene.rows.append({"usec":pacing.presentation_usec()-origin, "units":shown.get("death_animation_units", []).duplicate(true)})
			if not pacing._deaths.is_empty(): await process_frame
		scene.held_wall_usec = pacing.wall_usec-wall
		check(pacing._deaths.is_empty(), label+": overlapping death retired")
	else:
		await scene._animate_defeats_and_terrain_destruction(before, after, {}, true)
		hold = int(scene.sequence.get("hold_end_usec", 0))
		check(not scene.used_shared_clock, label+": independent blocking route")
	check(scene.sequence.get("unit_clocks", {}).size()==3, label+": independent unit clocks")
	check(absf(hold/1000000.0-Death.total_seconds(type))<CLOCK_ROUNDING_SECONDS, label+": humanoid clip then dissolve total")
	check(absf(scene.held_wall_usec*scale-hold)<=FRAME_USEC*scale, label+": speed scales real production runner hold")
	var crossed: Dictionary = {}
	for row: Dictionary in scene.rows:
		for unit: Dictionary in row["units"]:
			var actor: String = unit["type"]
			var count: int = scene._enemy_death_frame_count_for_unit(unit)
			var seconds: float = scene._enemy_death_frame_seconds_for_unit(unit)
			var elapsed: int = row["usec"]
			var progress: float = clampf(float(elapsed)/int(maxi(scene.ENEMY_DEATH_MIN_FRAMES,count)*minf(scene.ENEMY_DEATH_FALLBACK_FRAME_SECONDS,seconds)*1000000.0),0,1) if overlap else float(clampi(floori(float(elapsed)/roundi(seconds*1000000.0)),0,count-1))/maxi(1,count-1)
			check(is_equal_approx(unit["death_progress"], progress), label+": independent phase "+actor+" at "+str(elapsed))
			if actor==type:
				var collapse: float = Death.clip_phase(type, unit["death_progress"])
				var expected: float = clampf(progress*Death.total_seconds(type)/Death.clip_seconds(type),0,1)
				check(is_equal_approx(collapse,expected), label+": authored collapse phase")
				if type=="chainbound_gaoler":
					var drop: Dictionary = Action.data_for(type)["view_held_drops"]["front"]["death"]["chain"]
					for event: String in ["start", "land"]:
						if collapse>=float(drop[event]) and not crossed.has(event):
							var progress_step: float = float(Pacing.WALL_STEP_USEC)*scale/hold if overlap else 1.0/maxi(1,count-1)
							var phase_step: float = progress_step*Death.total_seconds(type)/Death.clip_seconds(type)
							check(absf(collapse-float(drop[event]))<=phase_step+PHASE_ROUNDING_EPSILON, label+": chain "+event+" at authored phase")
							crossed[event]=true
	if type=="chainbound_gaoler":
		check(crossed.size()==2,label+": release and floor landing observed")
		event_crossings += crossed.size()
	pacing.end_scope()
	scene.free()
