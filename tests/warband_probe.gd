extends SceneTree

const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const Fixture = preload("res://tools/warband_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const OUTPUT: String = "user://probes/spx03"
const SETTLE_SECONDS: float = 0.25
const READY_TIMEOUT_SECONDS: float = 20.0
const MOVE_SAMPLE_SECONDS: float = preload("res://scripts/combat_pacing.gd").ENEMY_TILE_SECONDS * 0.5
const BREAK_SAMPLE_FRACTION: float = 0.5
const CAPTURE_VISION_BONUS: int = Combat.UMBRA_UNLIMITED_RADIUS
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Warband visual proof requires the native renderer; use tools/visual_probe_runner.py --no-headless")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://spx03-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	canvas = SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	for variant: Dictionary in [{"biome": "air", "tier": 2}, {"biome": "lightning", "tier": 3}]:
		await _variant(variant)
	var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": PROOF_UI_SCALE, "seed": Fixture.FIXTURE_SEED, "capture_vision_bonus": CAPTURE_VISION_BONUS, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Warband native proof: %d captures, %d failures" % [captures.size(), failures.size()])
	print("Warband captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _variant(variant: Dictionary) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Fixture.build(engine, combat, engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"warband_biome": variant["biome"], "warband_tier": variant["tier"]})
	state["combat_state"]["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(RenderProof.DrawCheckedBoard)
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await _await_units_drawn(scene.get("board_view"), state["combat_state"])
	await create_timer(SETTLE_SECONDS).timeout
	# The native preview uses the production factory contract. This also works
	# before spx-02 supplies special-room map entry, without changing that unit.
	var pre: Dictionary = state.duplicate(true)
	pre["mode"] = "pre_battle"
	pre["pre_battle_pending"] = true
	pre["pre_battle_travel_dir"] = Vector2i.UP
	pre["combat_state"] = {}
	scene.set("_run_state", pre)
	var prepared: Dictionary = Fixture.prepared(engine, combat, pre)
	prepared["combat_state"]["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	scene.set("_prepared_pre_battle_factory", prepared)
	_expect(bool(scene.call("_show_pre_battle_preview")), "Warband pre-battle opens")
	await create_timer(SETTLE_SECONDS).timeout
	await _capture(variant, "pre_battle", {"title": state["combat_state"]["enemies"][0]["display_name"]})
	scene.call("_close_pre_battle_preview")
	scene.call("_load_run_state", state)
	await create_timer(SETTLE_SECONDS).timeout
	await _await_units_drawn(scene.get("board_view"), state["combat_state"])
	scene.call("_set_show_all_enemy_intents", true)
	var battle: Dictionary = state["combat_state"]
	var command_followers: Array[int]
	for enemy: Dictionary in battle["enemies"]:
		if (Rules.intent(battle, enemy, enemy.get("intent", {})).get("actions", []) as Array).any(func(action: Dictionary) -> bool: return int(action.get("_warband_command_bonus", 0)) > 0): command_followers.append(int(enemy["id"]))
	_expect(not command_followers.is_empty(), "Opening proof includes a follower within Command")
	await _capture(variant, "first_player_turn", {"command_followers": command_followers, "captain": battle["enemies"][0]["pos"], "command_radius": battle["objective"]["command"]["radius"]})

	scene.set("_animation_lock", true)
	scene.call("_refresh_animation_lock_ui")
	var close: Dictionary = battle.duplicate(true)
	Fixture.stage_keep_distance(close)
	scene.set("_combat_state", close)
	(scene.get("_run_state") as Dictionary)["combat_state"] = close
	scene.call("_render_board_state", close, {})
	var phase: Dictionary = combat.resolve_enemy_turn_with_steps(close, 0)
	var retreat_step: Dictionary = {}
	for step: Dictionary in phase["steps"]:
		if step.get("kind", "") == "move" and step.get("actor_key", "") == "enemy_1": retreat_step = step; break
	if bool(preload("res://scripts/game_data.gd").enemy_def(str(close["enemies"][0]["type"])).get("immobile", false)):
		_expect(Rules.retreat_path(combat, close, close["enemies"][0]).is_empty(), "Dynamo is immobile")
		await _capture(variant, "keep_distance", {"skipped_immobile": true, "captain": close["enemies"][0]["pos"]})
	else:
		_expect(not retreat_step.is_empty(), "Stormcaller has a keep-distance step")
		var done: Dictionary = {"done": false}
		_move(scene, close, retreat_step, done)
		await _await_motion(scene, done)
		await create_timer(MOVE_SAMPLE_SECONDS).timeout
		await _capture(variant, "keep_distance", {"from": retreat_step.get("from"), "to": retreat_step.get("to"), "path": retreat_step.get("path")})
		while not bool(done["done"]): await process_frame

	var before_break: Dictionary = battle.duplicate(true)
	before_break["enemies"][0]["stoneskin"] = 0
	var broken: Dictionary = combat._damage_enemy(before_break.duplicate(true), 0, int(before_break["enemies"][0]["hp"]), false, true)
	scene.set("_combat_state", before_break)
	(scene.get("_run_state") as Dictionary)["combat_state"] = before_break
	var done_break: Dictionary = {"done": false}
	_break(scene, before_break, broken, done_break)
	await _await_motion(scene, done_break)
	await create_timer(preload("res://scripts/warband_view.gd").TODO_DESIGN_WARBAND_BREAK_BEAT_SECONDS * BREAK_SAMPLE_FRACTION).timeout
	await _capture(variant, "warband_breaks", {"line": broken["objective"]["break_line"], "followers": broken["objective"]["followers_cleared"], "outcome": combat.combat_outcome(broken)})
	_expect((scene.get("action_banner") as Label).text == broken["objective"]["break_line"], "Break announcement uses the combat banner")
	while not bool(done_break["done"]): await process_frame
	scene.queue_free()
	await process_frame

func _move(scene: Node, state: Dictionary, step: Dictionary, done: Dictionary) -> void:
	await scene.call("_animate_move_step", state.duplicate(true), step)
	done["done"] = true

func _break(scene: Node, before: Dictionary, after: Dictionary, done: Dictionary) -> void:
	await scene.call("_animate_defeats_and_terrain_destruction", before, after)
	done["done"] = true

func _await_motion(scene: Node, done: Dictionary) -> void:
	var started: int = Time.get_ticks_msec()
	while not bool(done["done"]) and Time.get_ticks_msec() - started < READY_TIMEOUT_SECONDS * 1000.0:
		await process_frame
		var presentation: Dictionary = scene.get("board_view").get("presentation")
		if not (presentation.get("unit_world_positions", {}) as Dictionary).is_empty(): return
	_expect(false, "Native proof observed a real movement frame")

func _capture(variant: Dictionary, name: String, facts: Dictionary) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == PROOF_SIZE, "Capture is exactly 1920x1080")
	var path: String = OUTPUT.path_join("%s_tier%d" % [variant["biome"], variant["tier"]]).path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	_expect(image.save_png(path) == OK, "Capture writes " + path)
	captures.append({"path": path, "biome": variant["biome"], "tier": variant["tier"], "facts": facts})
	print("Warband capture: " + ProjectSettings.globalize_path(path))

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)

func _await_units_drawn(board: Node, state: Dictionary) -> void:
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		errors = RenderProof.renderer_readiness_errors(board, state)
		if errors.is_empty():
			board.drawn_unit_keys.clear()
			board.call("_queue_dynamic_redraw")
			await RenderingServer.frame_post_draw
			await process_frame
			await RenderingServer.frame_post_draw
			var required: Array[String]
			required.append("player")
			for enemy: Dictionary in state["enemies"]:
				if int(enemy["hp"]) > 0: required.append("enemy_%d" % int(enemy["id"]))
			for key: String in required:
				if not board.drawn_unit_keys.has(key): errors.append(key + " body was not drawn")
			if errors.is_empty(): return
		await process_frame
	_expect(false, "Every native actor must be prepared and drawn: " + "; ".join(errors))
