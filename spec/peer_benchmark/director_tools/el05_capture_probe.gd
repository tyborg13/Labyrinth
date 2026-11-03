extends SceneTree

# Director captures for el-05: the due beat's move ghosts (Upheaval throw, Shadowstep Blink) at 1920x1080, 100% UI scale.
# Copy to tests/_el05_capture_probe.gd and run through tools/visual_probe_runner.py --no-headless.
const Fixture = preload("res://tools/warband_inspection.gd")
const SnareFixture = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT: String = "user://el05-captures"
const ELEMENTS: Array = ["earth", "shadow"]
const BattlefieldRules = preload("res://scripts/battlefield_rules/dispatcher.gd")
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://el05-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = SIZE
	root.content_scale_size = SIZE
	canvas = SubViewport.new()
	canvas.size = SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var only: String = ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--only="): only = arg.trim_prefix("--only=")
	for element: String in ELEMENTS:
		for kind: String in ["warband", "snare"]:
			var name: String = "%s_%s" % [kind, element]
			if not only.is_empty() and not name.contains(only): continue
			await _capture(name, _warband(element) if kind == "warband" else _snare(element))
	print("EL05 captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit()

func _capture(name: String, state: Dictionary) -> void:
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await create_timer(2.5).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png(OUTPUT.path_join(name + ".png"))
	# Hover a card: the landing strip lists the beat with the actors ahead of you.
	scene.call("_on_card_hover_started", 2)
	for _frame: int in range(4): await process_frame
	await create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	canvas.get_texture().get_image().save_png(OUTPUT.path_join(name + "_hover.png"))
	scene.queue_free()
	await process_frame
	await process_frame

func _warband(element: String) -> Dictionary:
	var engine := Run.new()
	var run: Dictionary = Fixture.build(engine, Combat.new(), engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": element, "warband_tier": 2})
	# --due primes the rule one source turn short, so its next beat lands before the hero acts again.
	var rule: Dictionary = run["combat_state"].get("battlefield_rule", {})
	if str(rule.get("cadence", {}).get("anchor", "")) == "after_source_turn":
		rule["counter"] = int(rule["cadence"]["every"]) - 1
	return _occupy_rise(run)

func _snare(element: String) -> Dictionary:
	var engine := Run.new()
	return _occupy_rise(SnareFixture.build(engine, Combat.new(), engine.create_new_run(SnareFixture.FIXTURE_SEED, Store.default_data()), {"snare_biome": element, "snare_tier": 2, "snare_case": "first_turn"}))

# Upheaval only throws an occupant: stand the first single-tile enemy on the first marked tile.
func _occupy_rise(run: Dictionary) -> Dictionary:
	var state: Dictionary = run["combat_state"]
	var rise: Array = BattlefieldRules.forecast(Combat.new(), state).get("tiles", {}).get("rise", [])
	if rise.is_empty(): return run
	for enemy: Dictionary in state.get("enemies", []):
		if int(enemy.get("hp", 0)) > 0 and enemy.get("footprint", Vector2i.ONE) == Vector2i.ONE:
			enemy["pos"] = rise[0]
			break
	return run
