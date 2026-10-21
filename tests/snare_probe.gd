extends SceneTree
const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const Fixture = preload("res://tools/snare_inspection.gd")
const Run = preload("res://scripts/run_engine.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const OUTPUT: String = "user://probes/spx05/fire_tier2"
const SETTLE_SECONDS: float = 0.25
const READY_TIMEOUT_SECONDS: float = 20.0
const CAPTURE_VISION_BONUS: int = Combat.UMBRA_UNLIMITED_RADIUS
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if DisplayServer.get_name() == "headless":
		push_error("Snare visual proof requires the native renderer; use tools/visual_probe_runner.py --no-headless")
		quit(1)
		return
	call_deferred("_run")

func _run() -> void:
	Settings.set_storage_path("user://spx05-proof-settings.json")
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
	for study: String in ["first_turn", "first_seal", "kept_open", "escape"]: await _case(study)
	var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": PROOF_UI_SCALE, "seed": Fixture.FIXTURE_SEED, "capture_vision_bonus": CAPTURE_VISION_BONUS, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("Snare native proof: %d captures, %d failures" % [captures.size(), failures.size()])
	print("Snare captures: " + ProjectSettings.globalize_path(OUTPUT))
	quit(0 if failures.is_empty() else 1)

func _case(study: String) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var state: Dictionary = Fixture.build(engine, combat, engine.create_new_run(Fixture.FIXTURE_SEED, Store.default_data()), {"snare_biome": "fire", "snare_tier": 2, "snare_case": study})
	var battle: Dictionary = state["combat_state"]
	battle["umbra"]["vision_bonus"] = CAPTURE_VISION_BONUS
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(RenderProof.DrawCheckedBoard)
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", state)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	await _await_units_drawn(scene.get("board_view"), battle)
	await create_timer(SETTLE_SECONDS).timeout
	var chips: Node = scene.get("board_view").get_node_or_null("SnareSealChips")
	var labels: Array[String]
	if chips != null:
		for chip: Control in chips.get_children():
			if chip.visible: labels.append((chip.get_node("Title") as Label).text)
	var exits: Array = battle["objective"]["exits"]
	match study:
		"first_turn": _expect(labels == _strings(["Seals · 2", "Seals · 4"]), "Both opening chips")
		"first_seal": _expect(exits[1]["sealed"] and not exits[2]["sealed"] and labels == _strings(["Seals · 2"]), "First seal removes only its chip")
		"kept_open": _expect(exits[1]["kept_open"] and not exits[1]["sealed"] and labels == _strings(["Seals · 2"]), "Killed Sealbinder has no chip and its door remains open")
		"escape": _expect(combat.combat_outcome(battle) == "victory" and combat.snare_escape_context(battle)["doors_open_at_escape"] == 3, "Legal exit step and all-open bonus")
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = canvas.get_texture().get_image()
	_expect(image.get_size() == PROOF_SIZE, "Capture is exactly 1920x1080")
	var path: String = OUTPUT.path_join(study + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_expect(image.save_png(path) == OK, "Capture writes " + path)
	captures.append({"path": path, "case": study, "chips": labels, "exits": exits, "escape": combat.snare_escape_context(battle)})
	print("Snare capture: " + ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame

func _strings(values: Array) -> Array[String]:
	var result: Array[String]
	for value: String in values: result.append(value)
	return result

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
