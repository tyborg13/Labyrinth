extends SceneTree
const Suite = preload("res://tests/suites/encounter_tables_suite.gd")
const PROOF_CONTRACT_PATH: String = "/private/tmp/labyrinth-inspection-manifests/enc-01-visual-contract.json"
const PROOF_SIZE: Vector2i = Vector2i(1920, 1080)
const PROOF_OUTPUT: String = "user://probes/encounter_tables"
const PROOF_SETTLE_SECONDS: float = 0.25
const PROOF_READY_TIMEOUT_SECONDS: float = 15.0
# Capture-only visibility exposes every committed unit, including Shadow groups.
const PROOF_VISION_BONUS: int = preload("res://scripts/combat_engine.gd").UMBRA_UNLIMITED_RADIUS
var failures: Array[String]

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	_write_visual_contract()
	if OS.get_cmdline_user_args().has("--proof-contract-only"):
		quit(0 if failures.is_empty() else 1)
		return
	if DisplayServer.get_name() != "headless" or OS.get_cmdline_user_args().has("--visual-proof"):
		call_deferred("_visual_proof")
		return
	if OS.get_cmdline_user_args().has("--renderers-only"):
		call_deferred("_headless_renderer_proof")
		return
	if OS.get_cmdline_user_args().has("--weights-only"):
		Suite._test_weights(_expect)
		_finish("Encounter weights suite")
		return
	if OS.get_cmdline_user_args().has("--analytics-only"):
		_test_analytics()
		_finish("Encounter analytics suite")
		return
	if OS.get_cmdline_user_args().has("--integrations-only"):
		preload("res://tests/suites/section_map_v2_suite.gd").run(_expect)
		preload("res://tests/suites/dragon_boss_suite.gd").run(_expect)
		preload("res://tests/suites/guardian_suite.gd").run(_expect)
		preload("res://tests/suites/biome_suite.gd").run(_expect)
		preload("res://tests/suites/combat_objective_suite.gd").run(_expect)
		preload("res://tests/suites/reach_rebalance_suite.gd").run(_expect)
		preload("res://tests/suites/terrain_connectivity_equivalence_suite.gd").run(_expect)
		_finish("Encounter affected integration suites")
		return
	Suite.run(_expect)
	_test_analytics()
	call_deferred("_headless_renderer_proof", "Encounter tables suite")

func _expect(ok: bool, message: String) -> void:
	if not ok and not failures.has(message): failures.append(message)

func _finish(label: String) -> void:
	for failure: String in failures: push_error(failure)
	print("%s: %d failures" % [label, failures.size()])
	quit(0 if failures.is_empty() else 1)

func _write_visual_contract() -> void:
	var images: Array[Dictionary]
	for biome: String in Suite.Tables.BIOMES:
		images.append({"pattern": "*" + biome + "_encounter.png", "width": PROOF_SIZE.x, "height": PROOF_SIZE.y, "regions": [{"rect": [300, 120, 1300, 700], "min_luma_range": 8, "min_luma_stdev": 2}]})
	DirAccess.make_dir_recursive_absolute(PROOF_CONTRACT_PATH.get_base_dir())
	var file := FileAccess.open(PROOF_CONTRACT_PATH, FileAccess.WRITE)
	_expect(file != null, "Visual proof contract writes successfully")
	if file == null: return
	file.store_string(JSON.stringify({"min_images": images.size(), "expected_sizes": ["1920x1080"], "required_images": images}, "\t"))
	print("Encounter visual proof contract: " + PROOF_CONTRACT_PATH)

func _visual_proof() -> void:
	var Settings = preload("res://scripts/settings_store.gd")
	Settings.set_storage_path("user://enc_01_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	var canvas := SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var engine := Suite.RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(Suite.FIXTURE_SEED, Suite.Progression.default_data())
	var metadata: Array[Dictionary]
	for section_index: int in range(6):
		# Pick a real deepest regular room, with its actual element and dragon.
		var room: Dictionary = {}
		for candidate: Dictionary in state["rooms"].values():
			if candidate["type"] == "combat" and int(candidate["section_index"]) == section_index and int(candidate["depth"]) >= int(room.get("depth", 0)): room = candidate
		_expect(not room.is_empty(), "Each biome has a real regular room to capture")
		if room.is_empty(): continue
		var run: Dictionary = state.duplicate(true)
		run["current_room"] = room["coord"]
		run["mode"] = "pre_battle"
		run["pre_battle_pending"] = true
		run["pre_battle_travel_dir"] = Vector2i.ZERO
		var prepared: Dictionary = engine.prepare_pre_battle_combat(run)
		run = engine.begin_pre_battle_combat(run, prepared)
		var stored: Dictionary = Suite.Graph.room(run, room["coord"])
		_expect(not str(stored.get("encounter_id", "")).is_empty(), "Native proof is a table encounter")
		run["combat_state"]["umbra"]["vision_bonus"] = PROOF_VISION_BONUS
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		scene.get_node("BoardUnderlay/CombatBoard").set_script(Suite.DrawCheckedBoard)
		canvas.add_child(scene)
		await process_frame
		scene.call("_load_run_state", run)
		await process_frame
		if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
		await create_timer(PROOF_SETTLE_SECONDS).timeout
		scene.call("_set_show_all_enemy_intents", true)
		await process_frame
		var board: Node = scene.get("board_view")
		if not await _await_units_drawn(board, run["combat_state"]):
			scene.queue_free()
			await process_frame
			continue
		await RenderingServer.frame_post_draw
		var image: Image = canvas.get_texture().get_image()
		_expect(image.get_size() == PROOF_SIZE, "Native capture is 1920x1080")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(PROOF_OUTPUT))
		var path: String = PROOF_OUTPUT.path_join(str(stored["biome"]) + "_encounter.png")
		_expect(image.save_png(path) == OK, "Encounter capture writes: " + path)
		metadata.append({"image": path, "encounter_id": stored["encounter_id"], "biome": stored["biome"], "element": room["element"], "units": run["combat_state"]["enemies"].size(), "drawn_unit_keys": board.drawn_unit_keys.keys(), "capture_vision_bonus": PROOF_VISION_BONUS})
		scene.queue_free()
		await process_frame
	var file := FileAccess.open(PROOF_OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": 1.0, "captures": metadata, "errors": failures}, "\t"))
	_finish("Encounter native visual proof")

# Exercise the production emitter without attaching a scene or requesting a
# renderer. The empty tracker suppresses unrelated hand/playability logging.
func _test_analytics() -> void:
	var Analytics = preload("res://scripts/analytics_store.gd")
	Analytics.set_storage_dir("user://enc_01_analytics")
	Analytics.clear_storage()
	var engine := Suite.RunEngineScript.new()
	var state: Dictionary = engine.create_new_run(Suite.FIXTURE_SEED, Suite.Progression.default_data())
	var destination: Vector2i = Suite.Graph.room(state, Vector2i.ZERO)["connections"][0]["coord"]
	state = engine.move_to_room(state, destination)
	var scene: Node = load("res://scripts/run_scene.gd").new()
	scene.set("_run_state", state)
	scene.set("_combat_state", state["combat_state"])
	scene.call("_analytics_log_combat_started", "enc_01_test")
	var legacy: Dictionary = engine.create_new_run(Suite.FIXTURE_SEED, Suite.Progression.default_data(), false)
	legacy = engine.move_to_room(legacy, legacy["rooms"]["0,0"]["connections"][0]["coord"])
	scene.set("_run_state", legacy)
	scene.set("_combat_state", legacy["combat_state"])
	scene.call("_analytics_log_combat_started", "enc_01_legacy_test")
	var starts: Array[Dictionary]
	for event: Dictionary in Analytics.load_all_events():
		if event["event_type"] == "combat_started": starts.append(event)
	_expect(starts.size() == 2, "Production emitter appends both combat-start events")
	if starts.size() == 2:
		var stored: Dictionary = Suite.Graph.room(state, destination)
		_expect(starts[0]["payload"]["encounter_id"] == stored["encounter_id"] and starts[0]["payload"]["biome"] == stored["biome"], "Combat-start payload includes the persisted encounter id and biome")
		_expect(starts[0]["payload"].has("objective_type") and starts[0]["payload"].has("deck_cards") and starts[0]["schema_version"] == 1, "Encounter analytics retain existing payload and schema")
		_expect(starts[1]["payload"]["encounter_id"] == "" and starts[1]["payload"]["biome"] == "", "Legacy combat-start emits empty additive identity fields")
	scene.free()
	Analytics.set_storage_dir("")
	print("Encounter combat-start analytics: %d events checked" % starts.size())

func _headless_renderer_proof(label: String = "Encounter regular renderer suite") -> void:
	await Suite.run_renderer_preparation(self, _expect)
	_finish(label)

func _await_units_drawn(board: Node, state: Dictionary) -> bool:
	var deadline: int = Time.get_ticks_msec() + int(PROOF_READY_TIMEOUT_SECONDS * 1000.0)
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		errors = Suite.renderer_readiness_errors(board, state)
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
			for unit: Dictionary in board.call("_visible_units"):
				if not required.has(str(unit["key"])): continue
				var texture: Texture2D = board.call("_texture_for_unit", unit)
				var source: Image = texture.get_image() if texture != null else null
				if source == null or source.is_empty() or not source.get_used_rect().has_area(): errors.append(str(unit["key"]) + " source rendered empty")
			if errors.is_empty():
				_expect(board.drawn_unit_keys.has("player"), "Capture includes the drawn hero")
				print("Encounter native actors drawn: ", required)
				return true
		await process_frame
	_expect(false, "Capture blocked until every unit is prepared and drawn: " + "; ".join(errors))
	return false
