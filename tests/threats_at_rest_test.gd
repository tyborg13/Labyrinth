extends SceneTree

const Suite = preload("res://tests/suites/threats_at_rest_suite.gd")
const CompassSuite = preload("res://tests/suites/enemy_intent_compass_suite.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const Callouts = preload("res://scripts/intent_callouts.gd")
const Badges = preload("res://scripts/intent_badges.gd")
const Tiles = preload("res://scripts/threat_tiles.gd")
const VIEWPORT_SIZE := Vector2i(1920, 1080)
const OUTPUT_DIR: String = "user://probes/threats_at_rest"
const SETTLE_FRAMES: int = 8
const CANCELLED_CAPTURE_SECONDS: float = 0.20
var _canvas: SubViewport
var _visual_proof: bool = false
var _failures: Array[String]
var _assertions: int = 0

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Suite.run(_expect)
	CompassSuite.run(_expect)
	await _test_live_stage()
	if _failures.is_empty():
		print("THREATS AT REST %s RESULT: PASS (%d assertions; includes compass suite)" % ["PROBE" if _visual_proof else "TEST", _assertions])
		quit(0)
		return
	for failure: String in _failures: push_error(failure)
	print("THREATS AT REST TEST RESULT: FAIL (%d failures / %d assertions)" % [_failures.size(), _assertions])
	quit(1)

func _test_live_stage() -> void:
	root.size = VIEWPORT_SIZE
	root.content_scale_size = VIEWPORT_SIZE
	root.content_scale_factor = 1.0
	if _visual_proof:
		DisplayServer.window_set_size(VIEWPORT_SIZE)
		_expect(DisplayServer.get_name() != "headless", "Visual proof requires a real renderer")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	ProgressionStore.set_storage_path("user://threats_at_rest_progression.json")
	ProgressionStore.set_run_storage_path("user://threats_at_rest_run.save")
	ProgressionStore.clear_saved_run()
	_canvas = SubViewport.new()
	_canvas.size = VIEWPORT_SIZE
	_canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_canvas.msaa_2d = root.msaa_2d
	root.add_child(_canvas)
	_expect(_canvas.size == VIEWPORT_SIZE and _canvas.render_target_update_mode == SubViewport.UPDATE_ALWAYS, "Proof renders into a fixed 1920x1080 always-updating SubViewport")
	var scene: Node = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	_canvas.add_child(scene)
	await _settle()
	scene.call("_load_run_state", RunEngine.new().create_new_run(Suite.FIXTURE_SEED, ProgressionStore.default_data()))
	await _settle()
	var combat := Suite.Combat.new()
	var state: Dictionary = Suite.staged_state(combat)
	await _install(scene, state)
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard") as Control
	var presentation: Dictionary = board.get("presentation") as Dictionary
	var rest: Dictionary = presentation.get("threats_at_rest", {}) as Dictionary
	_expect((rest.get("badges", []) as Array).size() == 4, "Live rest view has all four mockup pills")
	_expect((presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Rest has no detailed arcs/names/movement wash")
	_expect(not bool(scene.get("_show_all_enemy_intents")), "Details defaults off")
	_expect(board.get("_rest_threat_tile_alphas") == Tiles.tile_alphas(rest.get("threats", [])), "Board consumes live attack-only tile data")
	var overlay: Control = board.get("_overlay_render_layer") as Control
	if overlay != null: _expect(overlay.get("_rest_threat_tile_alphas") == board.get("_rest_threat_tile_alphas"), "Retained floor layer receives fresh threat data")
	await _capture("01_rest_1920x1080")
	scene.call("_on_board_tile_hovered", (state["enemies"][0] as Dictionary)["pos"])
	await _settle()
	presentation = board.get("presentation") as Dictionary
	_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 1, "Pointer hover retains the detailed single-enemy view")
	for badge: Dictionary in (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []):
		_expect(is_equal_approx(float(badge["alpha"]), 1.0 if badge["key"] == "enemy_1" else 0.4), "Live hover dims other pills")
	await _capture("02_hover_isolation_1920x1080")
	scene.set("_focused_intent_enemy_id", 2)
	scene.call("_on_board_tile_hovered", Vector2i(-1, -1))
	scene.call("_refresh_stage_view")
	await _settle()
	presentation = board.get("presentation") as Dictionary
	for badge: Dictionary in (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []):
		_expect(is_equal_approx(float(badge["alpha"]), 1.0 if badge["key"] == "enemy_2" else 0.4), "Pinned/controller focus isolates the same layer")
	await _capture("03_focus_isolation_1920x1080")
	scene.set("_focused_intent_enemy_id", -1)
	scene.call("_set_show_all_enemy_intents", true)
	await _settle()
	presentation = board.get("presentation") as Dictionary
	_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 4, "Details adds every existing full plan")
	var toggle: Button = scene.get("_enemy_intent_toggle_button") as Button
	_expect(toggle.tooltip_text == "Hide full plans [I]", "Details on tooltip matches the brief")
	_expect((toggle.find_child("IntentTitle", true, false) as Label).text == "Details", "Custom HUD label reads Details")
	await _capture("04_details_1920x1080")
	scene.call("_set_show_all_enemy_intents", false)
	_expect(toggle.tooltip_text == "Show every enemy's full plan [I]", "Details off tooltip matches the brief")
	# Existing Crosswind/Rotate input re-aims a ranged plan from illusion to hero.
	state["illusions"] = [{"id": 1, "pos": Vector2i(1, 3), "hp": 10, "max_hp": 10, "block": 0, "stoneskin": 0}]
	(state["deck"] as Dictionary)["hand"] = ["crosswind"]
	state["cards_played_this_turn"] = 1
	await _install(scene, state)
	scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", Vector2i(1, 4))
	var options: Array = scene.call("_force_aim_options")
	_expect(options.has(Vector2i.RIGHT), "Crosswind proof has the existing sideways Rotate path")
	if options.has(Vector2i.RIGHT):
		scene.set("_force_aim_index", options.find(Vector2i.RIGHT))
		scene.call("_mark_force_aim_changed")
		scene.call("_refresh_stage_view")
	await _settle()
	var preview: Dictionary = scene.call("_enemy_intent_preview_state", state)
	_expect((preview["enemies"][3] as Dictionary)["pos"] != (state["enemies"][3] as Dictionary)["pos"], "Hovered Crosswind actually displaces the preview enemy")
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	var expected: Dictionary = Badges.build(combat, state, preview, "", scene.call("_surface_preview_information_state", preview))
	_expect(rest == expected, "Live push pills/tiles match the same preview source as full plans and Pass")
	var before_plan: Dictionary = combat.enemy_threat_tiles(state, 3)
	var after_plan: Dictionary = combat.enemy_threat_tiles(preview, 3)
	_expect(before_plan.get("projected_attack_target") != after_plan.get("projected_attack_target"), "Push re-aims the existing intent from illusion to hero")
	_expect(Tiles.tile_alphas(rest.get("threats", [])) != Tiles.tile_alphas(Badges.build(combat, state, state).get("threats", [])), "Live push updates imminent attack tiles")
	await _capture("05_push_preview_1920x1080")
	# Capture the actual synthetic step while production resolution plays it.
	state = Suite.staged_state(combat)
	(state["enemies"][0] as Dictionary)["pos"] = Suite.FIXTURE_HERO + Vector2i.RIGHT
	(state["enemies"][0] as Dictionary)["intent"] = {"actions": [{"type": "melee", "damage": 4, "range": 1}]}
	await _install(scene, state)
	(scene.get("_intent_callouts") as RefCounted).set("_announced", {})
	(scene.get("_intent_callouts") as RefCounted).observe(combat, state)
	(state["enemies"][0] as Dictionary)["shock"] = 1
	var phase: Dictionary = combat.resolve_enemy_turn_with_steps(state, 0, false)
	var annotated: Array[Dictionary] = (scene.get("_intent_callouts") as RefCounted).decorate_steps(combat, state, phase["steps"])
	var entry: Dictionary = {}
	for step: Dictionary in annotated:
		if str(step.get("kind", "")) == "intent_callout": entry = step
	_expect(str(entry.get("text", "")) == "Cancelled", "Production skipped action generates the captured Cancelled step")
	var completed: Dictionary = {"done": false}
	_play_callout(scene, state, entry, completed)
	await create_timer(CANCELLED_CAPTURE_SECONDS).timeout
	_expect(not ((board.get("presentation") as Dictionary).get("intent_callouts", []) as Array).is_empty(), "Callout is live during its 0.9-second interval")
	await _capture("06_cancelled_1920x1080")
	while not bool(completed["done"]): await process_frame
	_expect(((board.get("presentation") as Dictionary).get("intent_callouts", []) as Array).is_empty(), "Expired callout clears")
	state = Suite.staged_state(combat)
	state["umbra"] = {"stage": "heart", "light_sources": []}
	(state["enemies"][1] as Dictionary)["pos"] = Vector2i(7, 1)
	await _install(scene, state)
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_expect(not combat.visible_enemy_ids(state).has(2), "Umbra proof contains a hidden enemy")
	for badge: Dictionary in rest.get("badges", []): _expect(badge["key"] != "enemy_2", "Hidden enemy has no live pill/order")
	for threat: Dictionary in rest.get("threats", []): _expect(threat["key"] != "enemy_2", "Hidden enemy has no live threats")
	await _capture("07_umbra_hidden_1920x1080")
	state = Suite.staged_state(combat)
	await _install(scene, state)
	var settings: Dictionary = (scene.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = true
	scene.set("_settings", settings)
	scene.call("_refresh_stage_view")
	await _settle()
	_expect(bool((board.get("presentation") as Dictionary).get("reduced_motion", false)), "Live reduced motion reaches threat rendering")
	await _capture("08_reduced_motion_1920x1080")
	_canvas.queue_free()
	await process_frame
	if _visual_proof: print(ProjectSettings.globalize_path(OUTPUT_DIR))

func _play_callout(scene: Node, state: Dictionary, entry: Dictionary, completed: Dictionary) -> void:
	await scene.call("_animate_enemy_phase_steps", state, [entry])
	completed["done"] = true

func _install(scene: Node, state: Dictionary) -> void:
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = Vector2i(1, 0)
	run["current_room_layout"] = Suite.staged_layout()
	run["combat_state"] = state.duplicate(true)
	scene.set("_run_state", run)
	scene.set("_combat_state", state.duplicate(true))
	scene.set("_animation_lock", false)
	scene.set("_show_all_enemy_intents", false)
	scene.set("_focused_intent_enemy_id", -1)
	scene.set("_hovered_board_tile", Vector2i(-1, -1))
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	await _settle()

func _settle() -> void:
	for _frame: int in range(SETTLE_FRAMES): await process_frame

func _capture(name: String) -> void:
	if not _visual_proof: return
	_expect(is_equal_approx(root.content_scale_factor, 1.0), "Visual proof uses 100% UI scale")
	await RenderingServer.frame_post_draw
	var image: Image = _canvas.get_texture().get_image()
	_expect(image != null and image.get_size() == VIEWPORT_SIZE, "Capture must be native 1920x1080, without resizing")
	if image != null: _expect(image.save_png("%s/%s.png" % [OUTPUT_DIR, name]) == OK, "Save %s" % name)

func _expect(condition: bool, message: String) -> void:
	_assertions += 1
	if not condition: _failures.append(message)
