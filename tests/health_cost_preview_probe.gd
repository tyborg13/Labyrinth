extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const OUTPUT: String = "user://probes/card_health_cost"
var scene: Node
var canvas: SubViewport
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://health_cost_profile.json")
	Store.set_run_storage_path("user://health_cost_run.save")
	Settings.set_storage_path("user://health_cost_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	canvas = SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	for config: Dictionary in [
		{"name":"chilled_fatigue", "hp":20, "chilled":true, "fatigue":true, "defiance":0, "expected":15},
		{"name":"ordinary_fatigue", "hp":20, "chilled":false, "fatigue":true, "defiance":0, "expected":17},
		{"name":"umbra_chilled_fatigue", "hp":20, "chilled":true, "fatigue":true, "defiance":0, "expected":15, "umbra":true},
		{"name":"lethal_payment", "hp":1, "chilled":false, "fatigue":false, "defiance":0, "expected":0},
		{"name":"defiance_payment", "hp":1, "chilled":false, "fatigue":false, "defiance":1, "expected":6},
		{"name":"umbra_defiance_payment", "hp":1, "chilled":false, "fatigue":false, "defiance":1, "expected":6, "umbra":true},
	]:
		await _check_case(config)
	canvas.queue_free()
	await process_frame
	print("CARD HEALTH COST PREVIEW: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _check_case(config: Dictionary) -> void:
	var engine := Run.new()
	var combat := Combat.new()
	var options := {"dragon_id":"iskaldra", "dragon_depth":12}
	var state: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
	var battle: Dictionary = state["combat_state"]
	battle["player"]["hp"] = config["hp"]
	battle["player"]["max_hp"] = 24
	battle["player"]["chilled"] = config["chilled"]
	battle["player"]["block"] = 0
	battle["player"]["stoneskin"] = 0
	battle["relics"] = []
	battle["defiance_capacity"] = config["defiance"]
	battle["defiance_remaining"] = config["defiance"]
	battle["deck"]["hand"] = ["reprise", "brace"]
	battle["deck"]["draw"] = [] if config["fatigue"] else ["quick_stab", "brace", "quick_stab", "brace"]
	battle["deck"]["discard"] = ["quick_stab", "brace", "quick_stab", "brace"] if config["fatigue"] else []
	battle["deck"]["cycles"] = 0
	battle["deck"]["fatigue_base"] = 2
	# Hold enemy turns beyond this card; the witness measures payment itself.
	for entry: Dictionary in battle["turn_queue"]: entry["time"] = 100
	if config["chilled"]: Surface.place(battle, battle["player"]["pos"], "ice")
	if bool(config.get("umbra", false)):
		battle["umbra"]["stage"] = "eclipse"
		battle["umbra"]["stage_reduction"] = 0
		var hidden: Dictionary = combat._spawned_enemy_entry(battle, "crawler", 999, Vector2i(7,7), false)
		hidden["intent"] = {"id":"claw", "name":"Claw", "time":4, "actions":[{"type":"melee", "range":1, "damage":5}]}
		battle["enemies"].append(hidden)
		combat._schedule_actor(battle, combat._enemy_actor_entry(battle, hidden, 2, 0))
	state["player_hp"] = config["hp"]
	state["progression"]["level"] = 4 if int(config["defiance"]) > 0 else 1
	state["defiance_capacity"] = config["defiance"]
	state["defiance_remaining"] = config["defiance"]
	state["relics"] = []
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	await process_frame
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	var before: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	await scene.call("_on_card_pressed", 0)
	await process_frame
	expect(bool(scene.call("_pending_card_requires_confirmation")), "%s waits for confirmation" % config["name"])
	var forecast: Dictionary = scene.call("_pending_card_forecast_state")
	var display: Dictionary = scene.call("_board_display_state")
	var pass_source: Dictionary = scene.call("_pass_preview_source_state")
	expect(int(forecast["player"]["hp"]) == int(config["expected"]), "%s includes the exact completed HP payment" % config["name"])
	expect(int(display["player"]["hp"]) == int(config["expected"]), "%s board displays the completed HP result" % config["name"])
	expect(int(pass_source["player"]["hp"]) == int(config["expected"]), "%s Pass begins from paid HP" % config["name"])
	expect(int(pass_source.get("player_turn_time_spent", 0)) == 6, "%s Pass includes Reprise's six Time" % config["name"])
	if bool(config.get("umbra", false)):
		expect((pass_source["enemies"] as Array).any(func(enemy: Dictionary) -> bool: return int(enemy["id"]) == 999), "Pass retains its hidden actor roster")
		var unknown: Dictionary = scene.call("_pass_preview_summary")
		expect(bool(unknown.get("umbra_unknown_before_player", false)), "Known Reprise HP does not erase the hidden enemy warning")
	if int(config["defiance"]) > 0:
		expect(int(forecast["defiance_remaining"]) == 0, "A lethal payment forecasts its spent Defiance")
		var risk: Label = null
		# The choice overlay becomes visible after its deferred layout pass.
		for _frame: int in range(30):
			risk = scene.find_child("PassActionLabel", true, false) as Label
			if risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE -1": break
			await process_frame
		expect(risk != null and risk.is_visible_in_tree() and risk.text == "CARD COST\nDEFIANCE -1", "The visible confirmation risk discloses the payment's spent Defiance")
		if risk != null: expect(risk.get_line_count() == 2 and risk.get_minimum_size().y <= risk.size.y, "The Defiance warning fits the forecast panel")
	elif int(config["hp"]) > 1:
		var board: Control = scene.get("board_view")
		var damage: Dictionary = (board.get("presentation") as Dictionary).get("damage_preview", {})
		expect(int((damage.get("player", {}) as Dictionary).get("hp", -1)) == int(config["expected"]), "%s durability overlay matches the completed payment" % config["name"])
	scene.call("_refresh_stage_view")
	scene.call("_refresh_stage_view")
	expect(scene.get("_combat_state") == before, "%s repeated forecasting preserves live HP, piles, RNG and charges" % config["name"])
	await _capture(config["name"])
	await scene.call("_on_cancel_requested")
	expect(scene.get("_combat_state") == before, "%s cancellation is side-effect free" % config["name"])
	await scene.call("_on_card_pressed", 0)
	await scene.call("_on_confirm_card_play_pressed")
	var committed: Dictionary = scene.get("_combat_state")
	var committed_run: Dictionary = scene.get("_run_state")
	var committed_hp: int = int((committed.get("player", {}) as Dictionary).get("hp", committed_run.get("player_hp", -1)))
	expect(committed_hp == int(config["expected"]), "%s actual confirmation pays once and matches the preview" % config["name"])
	if int(config["expected"]) == 0:
		expect(str(committed_run.get("mode", "")) == "defeat", "Lethal payment commits defeat")
	else:
		expect(int(committed.get("cards_played_this_turn", 0)) == 1, "%s confirmation spends one card play" % config["name"])

func _capture(label: String) -> void:
	await create_timer(0.3).timeout
	await process_frame
	await RenderingServer.frame_post_draw
	var snapshot: Image = canvas.get_texture().get_image()
	expect(snapshot.get_size() == Vector2i(1920,1080), "Proof uses 1920x1080 at 100% UI scale")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = "%s/%s.png" % [OUTPUT, label]
	expect(snapshot.save_png(path) == OK, "Proof image saved")
	print(ProjectSettings.globalize_path(path))

func expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
