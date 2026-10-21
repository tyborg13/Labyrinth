extends SceneTree

# --check-only builds and checks every proof state without window-server access.
const Suite = preload("res://tests/suites/warband_orders_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Rules = preload("res://scripts/warband_combat_rules.gd")
const WindView = preload("res://scripts/enemy_mechanics/wind_view.gd")
const RenderProof = preload("res://tests/suites/encounter_tables_suite.gd")
const PROOF_SIZE := Vector2i(1920, 1080)
const PROOF_UI_SCALE: float = 1.0
const OUTPUT: String = "user://probes/spx04"
const PROOF_SEED: int = 83
const SETTLE_SECONDS: float = 0.25
const READY_TIMEOUT_SECONDS: float = 20.0
const EXPECTED_CASES: int = 7
var failures: Array[String]
var captures: Array[Dictionary]
var canvas: SubViewport

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	if OS.get_cmdline_user_args().has("--check-only"):
		call_deferred("_check_only")
		return
	if DisplayServer.get_name() == "headless":
		push_error("SPX04 native capture requires visual_probe_runner.py --no-headless; headless supports --check-only")
		quit(1)
		return
	call_deferred("_capture_cases")

func _check_only() -> void:
	var cases: Array[Dictionary] = _cases()
	for item: Dictionary in cases:
		var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
		root.add_child(scene)
		scene.hide() # Logic proof only: the dummy renderer cannot read GPU textures.
		await process_frame
		scene.call("_load_run_state", _run_for_case(item))
		if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
		scene.call("_set_show_all_enemy_intents", true)
		scene.call("_render_board_state", item["state"], {})
		scene.set("_pre_battle_preview_run_state", {"combat_state": item["state"]})
		var inspection: Control = scene.call("_build_pre_battle_enemy_inspection_panel", item["state"]["enemies"][0])
		scene.add_child(inspection) # Let one-shot portrait ready bindings release their captures.
		var order_label: Label = inspection.find_child("WarbandCaptainOrder", true, false)
		_expect(order_label != null and order_label.text == item["facts"]["order"], "Pre-battle captain inspection has exact order line")
		if item["biome"] == "lightning":
			var authored_ids: Array[String]
			for authored: Dictionary in Suite.Data.enemy_def("storm_capacitor")["intents"]:
				authored_ids.append(str(Rules.intent(item["state"], item["state"]["enemies"][0], authored)["id"]))
			_expect(authored_ids.has("charge") and authored_ids.has("discharge"), "Pre-battle Dynamo retains both authored known moves")
		inspection.free()
		var board: Node = scene.get("board_view")
		var units: Array = board.call("_visible_units")
		for id: int in item["facts"]["visible_enemy_ids"]:
			_expect(units.any(func(unit: Dictionary) -> bool: return str(unit.get("key", "")) == "enemy_%d" % id), "Live scene contains each revealed actor")
		if item["name"] == "shadow_telegraph":
			_expect(not units.any(func(unit: Dictionary) -> bool: return str(unit.get("key", "")) in ["enemy_2", "enemy_3"]), "Live scene hides Prior followers")
		if item["biome"] == "earth":
			item["facts"]["marked_tiles"] = _check_thornwall_preview(scene, item["state"])
			var trimmed: Dictionary = item["state"].duplicate(true)
			trimmed["grid"][Suite.FIXTURE_BRAMBLE_BLOCK.y][Suite.FIXTURE_BRAMBLE_BLOCK.x] = "wall"
			trimmed["enemies"][1]["pos"] = Suite.FIXTURE_WALL_CENTER + Vector2i.RIGHT
			var trimmed_tiles: Array = _check_thornwall_preview(scene, trimmed)
			_expect(trimmed_tiles.size() == item["facts"]["tiles"].size() - 2, "Board trims both blocked and occupied Thornwall tiles")
			trimmed["enemies"][1]["pos"] = Suite.FIXTURE_WALL_CENTER
			_check_thornwall_preview(scene, trimmed)
			trimmed["enemies"][0]["freeze"] = 1
			scene.call("_render_board_state", trimmed, {})
			_expect((board.get("_rest_threat_tile_alphas") as Dictionary).is_empty(), "Disabled Thornmother has no marked wall")
			trimmed["enemies"][0]["hp"] = 0
			scene.call("_render_board_state", trimmed, {})
			_expect((board.get("_rest_threat_tile_alphas") as Dictionary).is_empty(), "Dead Thornmother has no marked wall")
			if failures.is_empty(): print("SPX04 THORNWALL BOARD: full wall, legal trimming, center relocation and suppression PASS")
		if item["biome"] == "air": _check_wind_chip(scene, item["state"], true)
		scene.queue_free()
		await process_frame
	_expect(cases.size() == EXPECTED_CASES, "Every order plus Prior reveal is covered")
	for item: Dictionary in cases:
		_expect(not str(item["facts"]["order"]).is_empty(), "Proof records protected order copy")
		if item["biome"] in ["earth", "fire", "ice"]: _expect((item["facts"]["tiles"] as Array).size() >= 5, "Geometry proof has telegraph tiles")
	for failure: String in failures: push_error(failure)
	print("SPX04 PROBE CONTRACT: %s (%d states, 1920x1080, UI scale 100%%)" % ["PASS" if failures.is_empty() else "FAIL", cases.size()])
	quit(0 if failures.is_empty() else 1)

func _cases() -> Array[Dictionary]:
	var cases: Array[Dictionary]
	var engine := Combat.new()
	for biome: String in Suite.BIOMES:
		var state: Dictionary = Suite.battle(biome)
		state["umbra"] = {"stage": "clear"} # Production visibility presentation, with the full board lit.
		var verb: String = {"earth": "grow_bramble", "fire": "lob_mark", "air": "call_wind", "ice": "icefall_mark", "lightning": "gain_charge", "shadow": "ranged"}[biome]
		var intent: Dictionary = {}
		for candidate: Dictionary in Suite.Data.enemy_def(str(state["enemies"][0]["type"]))["intents"]:
			if str(candidate["actions"][0]["type"]) == verb: intent = candidate.duplicate(true); break
		if biome == "fire":
			var rng := RandomNumberGenerator.new()
			rng.seed = PROOF_SEED
			intent = Suite.Lob.declare(state, state["enemies"][0], intent, rng)
		state["enemies"][0]["intent"] = intent
		if biome in ["fire", "ice"]:
			state = engine._resolve_enemy_action(state, 0, intent["actions"][0])
			state["enemies"][0]["intent"] = Suite.authored(state, "slag_lands" if biome == "fire" else "icefall_land")
		if biome == "lightning": state["enemies"][0]["charge"] = 2
		if biome == "air": state = Suite.Wind.resolve(engine, state, 0, intent["actions"][0])
		var plan: Dictionary = engine.enemy_intent_plan(state, 0)
		var facts: Dictionary = {"order": Rules.order_line(state["objective"]), "tiles": plan.get("projected_attack", []), "visible_enemy_ids": engine.visible_enemy_ids(state)}
		if biome == "air":
			facts["slides"] = plan["wind_preview"]["displacement_paths"]
			_expect((facts["slides"] as Array).size() == 3, "Wind proof shows every movable follower and hero")
		if biome == "lightning":
			facts["threshold"] = Suite.Capacitor.threshold(state, state["enemies"][0])
			_expect(facts["threshold"] == 2 and not (plan["chain_hits"] as Array).is_empty(), "Dynamo proof shows two-Charge telegraphed Burst")
		if biome == "shadow": _expect((facts["visible_enemy_ids"] as Array).size() == 1, "Prior telegraph hides both distant followers")
		cases.append({"name": biome + "_telegraph", "biome": biome, "state": state, "facts": facts})
		if biome == "shadow":
			var after: Dictionary = engine._damage_enemy(state.duplicate(true), 0, Suite.FIXTURE_HP, false, true)
			var reveal: Dictionary = preload("res://scripts/warband_view.gd").flee_display_state(state, after)
			reveal["umbra"] = {"stage": "eclipse"}
			var visible: Array = engine.visible_enemy_ids(reveal)
			_expect(visible.size() == 2, "Prior followers reveal before the break movement")
			cases.append({"name": "shadow_reveal", "biome": biome, "state": reveal, "facts": {"order": facts["order"], "visible_enemy_ids": visible, "before_break_movement": true}})
	return cases

func _check_thornwall_preview(scene: Node, state: Dictionary) -> Array:
	scene.call("_render_board_state", state, {})
	var board: Node = scene.get("board_view")
	var marked: Array = (board.get("_rest_threat_tile_alphas") as Dictionary).keys()
	var grown: Array[Vector2i]
	var result: Dictionary = Combat.new()._resolve_enemy_action(state.duplicate(true), 0, state["enemies"][0]["intent"]["actions"][0])
	for terrain: Dictionary in result["terrain"]:
		if str(terrain.get("kind", "")) == "bramble": grown.append(terrain["pos"])
	_expect(not marked.is_empty() and Suite._same_tiles(marked, grown), "Live board marked-intent preview equals grown Thornwall tiles")
	for tile: Vector2i in marked:
		_expect(bool(board.call("_board_tile_is_visible_to_player", tile)), "Each marked Thornwall tile passes production visibility")
	return marked

func _check_wind_chip(scene: Node, state: Dictionary, check_transitions: bool = false) -> void:
	WindView.refresh_chip(scene, state)
	var chip: PanelContainer = (scene.get("ui_root") as Node).get_node("En02WindChip")
	var title: Label = chip.get_node("Contents/Title")
	var ordinary_tooltip: String = WindView.Icons.tooltip("wind") + "\n" + WindView.direction_name(state["wind"]["direction"]) + "."
	_expect(chip.visible and title.text == "Wind · held", "Live Stormcaller chip has approved held title")
	_expect(chip.tooltip_text == ordinary_tooltip + "\nHeld by the Stormcaller until it falls.", "Live Stormcaller chip appends approved held explanation")
	if not check_transitions: return
	var finite: Dictionary = state.duplicate(true)
	finite["objective"] = {"type": "kill_all"}
	WindView.refresh_chip(scene, finite)
	_expect(title.text == "Wind · %d" % int(finite["wind"]["rounds_left"]) and chip.tooltip_text == ordinary_tooltip, "Ordinary finite wind chip keeps countdown and original tooltip")
	var dead: Dictionary = state.duplicate(true)
	dead["enemies"][0]["hp"] = 0
	WindView.refresh_chip(scene, dead)
	_expect(not chip.visible, "Held wind chip disappears when Stormcaller falls")
	WindView.refresh_chip(scene, state)
	if failures.is_empty(): print("SPX04 WIND CHIP: held copy, finite countdown and source death PASS")

func _run_for_case(item: Dictionary) -> Dictionary:
	var engine := Run.new()
	var run: Dictionary = Suite.Warbands.Fixture.build(engine, Combat.new(), engine.create_new_run(PROOF_SEED, Store.default_data()), {"warband_biome": item["biome"], "warband_tier": 3})
	run["combat_state"] = item["state"]
	run["current_room_layout"]["grid"] = item["state"]["grid"]
	run["current_room_layout"]["enemies"] = item["state"]["enemies"]
	return run

func _capture_cases() -> void:
	Settings.set_storage_path("user://spx04-proof-settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = PROOF_UI_SCALE
	settings["display_mode"] = "windowed"
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	root.size = PROOF_SIZE
	root.content_scale_size = PROOF_SIZE
	canvas = SubViewport.new()
	canvas.size = PROOF_SIZE
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	for item: Dictionary in _cases(): await _capture_case(item)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var file := FileAccess.open(OUTPUT.path_join("captures.json"), FileAccess.WRITE)
	if file != null: file.store_string(JSON.stringify({"size": [1920, 1080], "ui_scale": PROOF_UI_SCALE, "captures": captures, "errors": failures}, "\t"))
	canvas.queue_free()
	await process_frame
	for failure: String in failures: push_error(failure)
	print("SPX04 NATIVE PROOF: %d captures, %d failures" % [captures.size(), failures.size()])
	quit(0 if failures.is_empty() else 1)

func _capture_case(item: Dictionary) -> void:
	var run: Dictionary = _run_for_case(item)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	scene.get_node("BoardUnderlay/CombatBoard").set_script(RenderProof.DrawCheckedBoard)
	canvas.add_child(scene)
	await process_frame
	scene.call("_load_run_state", run)
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	_expect(is_equal_approx(preload("res://scripts/ui_typography.gd").ui_scale(scene), PROOF_UI_SCALE), "Native proof uses 100% UI scale")
	scene.call("_set_show_all_enemy_intents", true)
	scene.call("_set_action_banner", item["facts"]["order"])
	scene.call("_render_board_state", item["state"], {})
	var board: Node = scene.get("board_view")
	if item["biome"] == "earth": item["facts"]["marked_tiles"] = _check_thornwall_preview(scene, item["state"])
	if item["biome"] == "air": _check_wind_chip(scene, item["state"])
	var deadline: int = Time.get_ticks_msec() + int(READY_TIMEOUT_SECONDS * 1000.0)
	var readiness_state: Dictionary = item["state"].duplicate(false)
	var visible_enemies: Array[Dictionary]
	for enemy: Dictionary in item["state"]["enemies"]:
		if (item["facts"]["visible_enemy_ids"] as Array).has(int(enemy["id"])): visible_enemies.append(enemy)
	readiness_state["enemies"] = visible_enemies
	var errors: Array[String]
	while Time.get_ticks_msec() < deadline:
		errors = RenderProof.renderer_readiness_errors(board, readiness_state)
		if errors.is_empty(): break
		await process_frame
	_expect(errors.is_empty(), "Every actor renderer is ready: " + item["name"])
	await create_timer(SETTLE_SECONDS).timeout
	board.drawn_unit_keys.clear()
	board.call("_queue_dynamic_redraw")
	await RenderingServer.frame_post_draw
	await process_frame
	await RenderingServer.frame_post_draw
	for id: int in item["facts"]["visible_enemy_ids"]: _expect(board.drawn_unit_keys.has("enemy_%d" % id), "Visible proof actor was really drawn")
	var image: Image = canvas.get_texture().get_image()
	var path: String = OUTPUT.path_join(item["name"] + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_expect(image.get_size() == PROOF_SIZE and image.save_png(path) == OK, "Capture writes exact 1920x1080 PNG")
	captures.append({"path": path, "facts": item["facts"]})
	print("SPX04 CAPTURE: " + ProjectSettings.globalize_path(path))
	scene.queue_free()
	await process_frame

func _expect(ok: bool, message: String) -> void:
	if not ok: failures.append(message)
