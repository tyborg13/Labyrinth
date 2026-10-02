extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Suite = preload("res://tests/suites/relic_u5_suite.gd")
const Data = preload("res://scripts/game_data.gd")
const Retaliate = preload("res://scripts/retaliate_rules.gd")
const Tempo = preload("res://scripts/tempo_rules.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/relic_u5/1920x1080"
var viewport: SubViewport
var scene: Node
var failed := false
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://relic_u5_probe_progression.json")
	Store.set_run_storage_path("user://relic_u5_probe_run.save")
	Store.clear_saved_run()
	Settings.set_storage_path("user://relic_u5_probe_settings.json")
	Settings.clear_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	call_deferred("run")
func run() -> void:
	Suite.install_fixtures()
	for id: String in ["u5_guard", "u5_blood", "u5_retaliate"]:
		(Data.cards()[id] as Dictionary)["art_path"] = Data.card_def("brace").get("art_path", "")
	(Data.cards()["u5_guard"] as Dictionary)["name"] = "Braced Guard"
	(Data.cards()["u5_blood"] as Dictionary)["name"] = "Blood Price"
	(Data.cards()["u5_strike"] as Dictionary)["name"] = "Quick Stab"
	(Data.cards()["u5_rite"] as Dictionary)["name"] = "Mountain Vow"
	(Data.cards()["u5_rite"] as Dictionary)["description"] = "Rite: gain 1 extra independent movement each turn."
	(Data.cards()["u5_rite"] as Dictionary)["art_path"] = Data.card_def("rite_of_the_mountain").get("art_path", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	await settle()
	var engine := CombatEngine.new()
	var s: Dictionary = Suite.state(engine, ["briar_throne"])
	Retaliate.gain(s, {"amount": 5}, "Bristle")
	s = Suite.retaliate_hit(engine, s)
	s = Suite.retaliate_hit(engine, s)
	await install(s)
	await select_and_hover_player(0)
	expect(Retaliate.player_badges(s, engine._relic_effects(s))[0]["count"] == 7, "Throne badge after two triggers is seven")
	expect(int((scene.call("_pending_card_forecast_state") as Dictionary)["player"]["block"]) == 0, "Hovered Block card forecasts no Block")
	save("01_briar_throne.png")
	s = Suite.state(engine, ["iron_lung"])
	(s["player"] as Dictionary)["stoneskin"] = 5
	await install(s)
	await select_and_hover_player(3)
	var paid: Dictionary = scene.call("_pending_card_forecast_state")
	expect(paid["player"]["hp"] == 29 and paid["player"]["stoneskin"] == 1, "Lung hover payment is four Stoneskin and one health")
	save("02_iron_lung.png")
	s = Suite.state(engine, ["bloodmoon_chalice"])
	s = engine._lose_player_health(s, 1, true, false, "card_health_cost")
	await install(s)
	expect(Tempo.player_badges(s)[0]["count"] == 2, "Chalice next-attack badge is two after one health")
	await scene.call("_on_card_pressed", 1)
	await hover_tile(Suite.TARGET)
	var forecast: Dictionary = scene.call("_preview_damage_for_action", scene.get("_preview_combat_state"), (scene.get("_pending_actions") as Array)[0], Suite.TARGET)
	expect(int((forecast.get("enemy_1", {}) as Dictionary).get("hp_loss", 0)) == 5, "Chalice attack hover shows five damage")
	save("03_bloodmoon_chalice.png")
	s = Suite.state(engine, ["liturgy_of_ash", "reliquary_box"])
	s["cards_played_this_turn"] = 2
	(s["deck"] as Dictionary)["hand"][4] = "u5_rite_fast"
	s["player_movement_remaining"] = 0
	await install(s)
	expect(bool((scene.call("_card_playability_for_index", 2) as Dictionary).get("printed_playable", false)), "Liturgy Rite selectable at zero plays")
	await scene.call("_on_card_pressed", 2)
	expect(int(scene.get("_selected_card_index")) == 2, "Pointer selection reaches a free Rite")
	await scene.call("_on_confirm_card_play_pressed")
	await settle()
	var committed: Dictionary = scene.get("_combat_state")
	expect(committed["cards_played_this_turn"] == 2 and committed["player_turn_time_spent"] == 3, "Liturgy UI commits discounted Time and zero plays")
	# Keep another free Rite available so the normal auto-pass does not move
	# away from the requested post-play counter inspection state.
	save("04_liturgy_of_ash.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("RELIC U5 PROBE TEST RESULT: FAIL" if failed else "RELIC U5 PROBE TEST RESULT: PASS")
	scene.queue_free()
	viewport.queue_free()
	await process_frame
	quit(1 if failed else 0)
func install(s: Dictionary) -> void:
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["current_room"] = Vector2i(2, 2)
	run["combat_state"] = s
	run["relics"] = s["relics"].duplicate()
	scene.set("_guided_tutorial_phase_id", "")
	scene.set("_run_state", run)
	scene.set("_combat_state", s)
	scene.set("_animation_lock", false)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	var log: Control = scene.get("log_overlay")
	if log != null: log.visible = false
	await settle()
func select_and_hover_player(index: int) -> void:
	scene.call("_on_card_hover_started", index)
	await scene.call("_on_card_pressed", index)
	await hover_tile((scene.get("_combat_state") as Dictionary)["player"]["pos"])
func hover_tile(tile: Vector2i) -> void:
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_refresh_board_hover_presentation")
	var board: Control = scene.get("board_view")
	scene.call("_sync_click_targeting_arrow", board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", tile) as Vector2))
	await settle()
func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.2).timeout
func save(file: String) -> void:
	RenderingServer.force_draw()
	var img: Image = viewport.get_texture().get_image()
	expect(img.get_size() == SIZE, "Exact capture size")
	img.save_png(OUTPUT + "/" + file)
func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
