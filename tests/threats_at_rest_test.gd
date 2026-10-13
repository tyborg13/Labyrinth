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
const OUTPUT_DIR: String = "user://probes/threats_at_rest_v2"
const SETTLE_FRAMES: int = 8
const CANCELLED_CAPTURE_SECONDS: float = 0.20
const PROOF_PULSE_PEAK_SECONDS: float = 0.55
const PROOF_MOVE_OFFSET := Vector2i.UP
const PROOF_AUDIO_DRAIN_SECONDS: float = 0.10
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
	_expect((rest.get("badges", []) as Array).size() == 4, "Live rest view has all four approved feet chips")
	_expect((presentation.get("enemy_threat_previews", []) as Array).is_empty(), "Rest has no detailed arcs/names/movement wash")
	_expect(not bool(scene.get("_show_all_enemy_intents")), "Details defaults off")
	_expect(board.get("_rest_threat_tile_alphas") == Tiles.tile_alphas(rest.get("threats", [])), "Board consumes live attack-only tile data")
	var overlay: Control = board.get("_overlay_render_layer") as Control
	if overlay != null: _expect(overlay.get("_rest_threat_tile_alphas") == board.get("_rest_threat_tile_alphas"), "Retained floor layer receives fresh threat data")
	_assert_feet_layout(board, rest)
	await _capture("01_rest_1920x1080")
	scene.call("_on_board_tile_hovered", (state["enemies"][0] as Dictionary)["pos"])
	await _settle()
	presentation = board.get("presentation") as Dictionary
	_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 1, "Pointer hover retains the detailed single-enemy view")
	for badge: Dictionary in (presentation.get("threats_at_rest", {}) as Dictionary).get("badges", []):
		_expect(is_equal_approx(float(badge["alpha"]), 1.0 if badge["key"] == "enemy_1" else 0.4), "Live hover dims other discs and chips")
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
	_expect(rest == expected, "Live push chips/tags/tiles match the same preview source as full plans and Pass")
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
	for badge: Dictionary in rest.get("badges", []): _expect(badge["key"] != "enemy_2", "Hidden enemy has no live chip/order")
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
	_expect(is_equal_approx(Badges.halo_alpha(PROOF_PULSE_PEAK_SECONDS, true), 0.55), "Reduced-motion chip halo is steady 55%")
	await _capture("08_reduced_motion_1920x1080")
	settings["reduced_motion"] = false
	scene.set("_settings", settings)
	state = Suite.crowded_state(combat)
	await _install(scene, state)
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_assert_feet_layout(board, rest)
	_expect((state["enemies"][3] as Dictionary)["pos"] == Suite.FIXTURE_HERO + Vector2i(3, 1), "Crowded harrier is in front of crawler at the approved tile")
	_expect(not (board.call("_foreground_obstruction_candidates") as Array).is_empty(), "Crowded chip placement consumes actual terrain-prop bounds")
	await _capture("09_crowded_1920x1080")
	state = Suite.staged_state(combat)
	await _install(scene, state)
	var peak: Dictionary = (board.get("presentation") as Dictionary).duplicate(true)
	peak["threats_proof_seconds"] = PROOF_PULSE_PEAK_SECONDS
	_submit_presentation(board, peak)
	await _settle()
	_expect(is_equal_approx(Badges.halo_alpha(PROOF_PULSE_PEAK_SECONDS, false), 0.75), "Peak capture fixes the chip halo at 75%")
	_expect(bool(((board.get("_hud_render_layer") as Control).get("presentation") as Dictionary).has("threats_proof_seconds")), "Retained HUD receives the deterministic proof clock")
	await _capture("10_danger_peak_1920x1080")
	# Exercise the production independent-movement input and forecast, without
	# committing a move or fabricating a combat presentation snapshot.
	(state["enemies"][0] as Dictionary)["pos"] = Suite.FIXTURE_HERO + Vector2i.RIGHT
	(state["enemies"][0] as Dictionary)["intent"] = {"actions": [{"type": "melee", "damage": 4, "range": 1}]}
	await _install(scene, state)
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_expect(bool(Suite._badge(rest, "enemy_1")["danger"]), "Move proof starts with adjacent melee danger")
	scene.call("_begin_player_movement_selection")
	var move_target: Vector2i = Suite.FIXTURE_HERO + PROOF_MOVE_OFFSET
	_expect((scene.get("_player_movement_target_tiles") as Array).has(move_target), "Move proof destination is legal")
	scene.call("_on_board_tile_hovered", move_target)
	await _settle()
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_expect(rest["hero_tile"] == move_target and not bool(Suite._badge(rest, "enemy_1")["danger"]), "Live independent-move preview removes adjacent melee danger")
	_assert_feet_layout(board, rest)
	await _capture("11_move_removes_danger_1920x1080")
	scene.call("_cancel_player_movement_selection")
	await _settle()
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_expect(bool(Suite._badge(rest, "enemy_1")["danger"]), "Cancelling movement preview restores danger")
	(state["deck"] as Dictionary)["hand"] = ["guarded_step"]
	state["cards_played_this_turn"] = 1
	await _install(scene, state)
	scene.call("_on_card_pressed", 0)
	scene.call("_on_board_tile_hovered", move_target)
	await _settle()
	rest = (board.get("presentation") as Dictionary).get("threats_at_rest", {}) as Dictionary
	_expect(rest["hero_tile"] == move_target and not bool(Suite._badge(rest, "enemy_1")["danger"]), "Live card-move preview removes adjacent melee danger")
	await _capture("12_card_removes_danger_1920x1080")
	scene.call("_cancel_card_selection")
	for player: Node in scene.find_children("*", "AudioStreamPlayer", true, false):
		player.call("stop")
	await create_timer(PROOF_AUDIO_DRAIN_SECONDS).timeout
	await _settle()
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
	scene.call("_cancel_player_movement_selection", false)
	scene.call("_reset_card_resolution")
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _settle()

func _assert_feet_layout(board: Control, rest: Dictionary) -> void:
	var layouts: Array[Dictionary] = Badges.layouts(board, rest.get("badges", []))
	_expect(layouts.size() == (rest.get("badges", []) as Array).size(), "Every visible known intent has a feet chip layout")
	for layout: Dictionary in layouts:
		var unit: Dictionary = {}
		for candidate: Dictionary in board.call("_visible_units"):
			if candidate["key"] == layout["key"]: unit = candidate
		var anchor: Vector2 = board.call("_unit_center", unit)
		_expect(is_equal_approx((layout["center"] as Vector2).y, anchor.y + 4.0), "Live chip stays at the enemy feet")
		_expect(str(layout["placement"]) in ["lower_left", "lower_right"], "Live chip uses only the authored feet placements")
		var health: Rect2 = Badges.health_rect(board, unit)
		_expect((layout["order_rect"] as Rect2).get_center() == Vector2(health.position.x - 14.0, health.get_center().y), "Live order disc follows health frame")

func _submit_presentation(board: Control, presentation: Dictionary) -> void:
	board.call("set_combat_state", board.get("combat_state"), board.get("move_tiles"), board.get("attack_tiles"), board.get("selected_tile"), board.get("status_label"), board.get("status_detail"), board.get("exit_tiles"), board.get("exit_icon_ids"), presentation)

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
