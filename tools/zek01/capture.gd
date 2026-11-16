extends SceneTree
## Production dragon fixture, resolver and playback. Direct boss activations
## stage the requested beats; this is visual coverage, not a played encounter.
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Data = preload("res://scripts/game_data.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Analytics = preload("res://scripts/analytics_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const SOURCE_PATHS: Array = ["data/enemies.json", "scripts/dragon_scatter_pattern.gd", "scripts/dragon_combat_rules.gd", "scripts/combat_engine.gd", "scripts/board_surface_rules.gd", "scripts/battlefield_rules/dispatcher.gd", "scripts/battlefield_rules/lightning_storm.gd", "scripts/run_scene.gd", "scripts/dragon_presentation.gd", "scripts/zekarion_cutout/action.gd", "tools/dragon_boss_inspection.gd", "tools/zek01/capture.gd", "cel_look_variants/manifest.json"]
const SIZE := Vector2i(1920,1080)
const OUTPUT: String = "user://probes/zek01"
const FIXTURE_SEED: int = 7262026
const FIXTURE_DEPTH: int = 4
const SETTLE_FRAMES: int = 12
const RESOLUTION_PROTECTION_HP: int = 999
const CONTACT_PROGRESS: float = 0.55
var scene: Node
var canvas: SubViewport
var combat := Combat.new()
var witnesses: Array[Dictionary]
var failures: Array[String]
func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_run.call_deferred()
func _fixture(baseline: bool) -> Dictionary:
	var current: Dictionary = Data.enemies()["zekarion"].duplicate(true)
	if baseline:
		var old: Dictionary = current.duplicate(true)
		old["max_hp"] = 50
		old.erase("cycle_order")
		old["intents"][0]["actions"][0]["placement"] = "band"
		old["intents"][0]["actions"][0]["count"] = 7
		Data.enemies()["zekarion"] = old
	var options: Dictionary = {"seed":FIXTURE_SEED, "dragon_id":"zekarion", "dragon_depth":FIXTURE_DEPTH, "dragon_build":"balanced"}
	var engine := Run.new()
	var seed: int = Factory.seed_for_options(options)
	var run: Dictionary = Factory.build(engine, combat, engine.create_new_run(seed, Store.default_data()), options)
	Data.enemies()["zekarion"] = current
	return run
func _run() -> void:
	var hashes: Dictionary = _source_hashes()
	var run: Dictionary = _fixture(false)
	var state: Dictionary = run["combat_state"]
	_check(state["enemies"][0]["intent"]["actions"][0]["declared_tiles"].size() == 9, "Opening fixture has nine scatter marks")
	if OS.get_cmdline_user_args().has("--check-fixture"):
		for phase: int in range(5):
			_check(str(state["enemies"][0]["intent"]["id"]) == ["skybreak","storm_claw","call_wisps","skybreak","tempest_breath"][phase], "Fixture cycle slot %d" % phase)
			if phase == 3: _check(_wisps(state) == 2, "Second Skybreak has two living Wisps")
			state = _resolve(state)["state"]
		print("ZEK01 CAPTURE FIXTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
		quit(0 if failures.is_empty() else 1)
		return
	_check(DisplayServer.get_name() != "headless", "Windowed real renderer required")
	if not failures.is_empty():
		quit(1)
		return
	Store.set_storage_path("user://zek01_profile.json")
	Store.set_run_storage_path("user://zek01_run.save")
	Analytics.set_storage_dir("user://zek01_analytics")
	Settings.set_storage_path("user://zek01_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["dialogue_speed"] = Settings.DIALOGUE_INSTANT
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	root.content_scale_factor = 1.0
	DisplayServer.window_set_size(SIZE)
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var baseline: Dictionary = _fixture(true)
	await _install(baseline)
	await _capture("01_opening_before", baseline["combat_state"])
	var baseline_result: Dictionary = _resolve(baseline["combat_state"])
	var baseline_timing: Dictionary = await _playback(baseline["combat_state"], baseline_result, "")
	witnesses.append({"variant":"baseline_band7", "timing":baseline_timing})
	await _install(run)
	await _capture("02_opening_after", state)
	for phase: int in range(5):
		run["combat_state"] = state.duplicate(true)
		await _install(run)
		if phase == 3:
			_check(_wisps(state) == 2, "Wisps remain alive at second Skybreak")
			await _capture("04_second_skybreak_wisps", state)
		if phase == 4: await _capture("06_overload_warning", state)
		var result: Dictionary = _resolve(state)
		var contact_name: String = {0:"03_opening_strikes",3:"05_second_strikes",4:"07_overload_firing"}.get(phase, "")
		var timing: Dictionary = await _playback(state, result, contact_name)
		if phase == 4:
			var beats: Array = result["state"].get("surface_events", []).filter(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "battlefield_rule_fired" and int(event.get("sequence", 0)) > int(state.get("surface_event_sequence", 0)))
			_check(not beats.is_empty(), "Overload fired the existing Lightning Storm instance")
		witnesses.append({"phase":phase,"timing":timing,"resolver_steps":result["steps"],"state_after":result["state"]})
		state = result["state"]
		if phase == 4:
			run["combat_state"] = state
			await _install(run)
			await _capture("08_overload_result", state)
	_check(hashes == _source_hashes(), "Proof sources remained unchanged")
	var summary: Dictionary = {"source_sha256":hashes,"kind":"staged_production_dragon_fixture", "viewport":[1920,1080], "ui_scale":1.0, "cel_look":OS.get_environment("LABYRINTH_CEL_LOOK"), "seed_search_start":FIXTURE_SEED, "depth":FIXTURE_DEPTH, "witnesses":witnesses, "failures":failures, "limitations":["Boss turns staged directly; helpers do not act independently.","Resolution temporarily protects hero Health, then restores entry Health for presentation; no balance claim.","Overload capture shows existing production playback; no new field VFX is fabricated.","Frame timings include PNG readback on captured beats; baseline timing has no PNG readback."]}
	var file := FileAccess.open(OUTPUT.path_join("witnesses.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(Analytics._sanitize_variant(summary), "  "))
	file.close()
	print(ProjectSettings.globalize_path(OUTPUT.path_join("witnesses.json")))
	print("ZEK01 CAPTURE: %s" % ("PASS" if failures.is_empty() else "FAIL"))
	quit(0 if failures.is_empty() else 1)
func _playback(state: Dictionary, result: Dictionary, contact_name: String) -> Dictionary:
	var done: Dictionary = {"finished":false}
	var started: int = Time.get_ticks_usec()
	_play(state.duplicate(true), result, done)
	var captured_contact: bool = false
	var samples: Array[float]
	var last_frame: int = Time.get_ticks_usec()
	while not bool(done["finished"]):
		await process_frame
		var now: int = Time.get_ticks_usec()
		samples.append(float(now-last_frame)/1000.0)
		last_frame = now
		var shown: Dictionary = scene.get("board_view").get("presentation")
		var effect: Dictionary = shown.get("effect", {})
		if not contact_name.is_empty() and not captured_contact and str(effect.get("intent_id", "")) == str(state["enemies"][0]["intent"]["id"]) and float(shown.get("effect_progress", 0.0)) >= CONTACT_PROGRESS:
			await _capture(contact_name, state)
			captured_contact = true
	if not contact_name.is_empty(): _check(captured_contact, "Playback contact captured: "+contact_name)
	return {"playback_ms":float(Time.get_ticks_usec()-started)/1000.0, "frame_ms":samples, "includes_png_readback":not contact_name.is_empty()}

func _source_hashes() -> Dictionary:
	var result: Dictionary = {}
	for path: String in SOURCE_PATHS:
		result[path] = FileAccess.get_sha256("res://"+path) if FileAccess.file_exists("res://"+path) else "missing"
	return result

func _resolve(state: Dictionary) -> Dictionary:
	var setup: Dictionary = state.duplicate(true)
	var player: Dictionary = state["player"].duplicate(true)
	setup["player"]["hp"] = RESOLUTION_PROTECTION_HP
	setup["player"]["max_hp"] = RESOLUTION_PROTECTION_HP
	# The next player activation makes prior marks eligible fuel, as in combat.
	setup["turn"] = int(setup["turn"]) + 1
	var result: Dictionary = combat.resolve_enemy_turn_with_steps(setup, 0)
	result["state"]["player"]["hp"] = player["hp"]
	result["state"]["player"]["max_hp"] = player["max_hp"]
	return result
func _play(state: Dictionary, result: Dictionary, done: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, result["steps"], result["state"])
	done["finished"] = true
func _install(run: Dictionary) -> void:
	scene.set("_progression", run["progression"].duplicate(true))
	scene.call("_load_run_state", run.duplicate(true))
	scene.call("_close_dialogue")
	scene.call("_close_large_map")
	scene.call("_set_show_all_enemy_intents", true)
	for _frame: int in range(SETTLE_FRAMES): await process_frame
func _capture(name: String, state: Dictionary) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_check(image.get_size() == SIZE and is_equal_approx(root.content_scale_factor, 1.0), "Native 1920x1080 at 100%")
	var path: String = OUTPUT.path_join(name+".png")
	_check(image.save_png(path) == OK, "Saved "+name)
	witnesses.append({"image":name+".png", "intent":state["enemies"][0]["intent"], "living_wisps":_wisps(state), "electrified":Surface.tiles(state,"electrified")})
	print(ProjectSettings.globalize_path(path))
func _wisps(state: Dictionary) -> int:
	var count: int = 0
	for enemy: Dictionary in state["enemies"]:
		if str(enemy["type"]) == "lightning_wisp" and int(enemy["hp"]) > 0: count += 1
	return count
func _check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)
