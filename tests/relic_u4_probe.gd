extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const CombatEngine = preload("res://scripts/combat_engine.gd")
const Suite = preload("res://tests/suites/relic_u4_suite.gd")
const GameData = preload("res://scripts/game_data.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/relic_u4/1920x1080"
var viewport: SubViewport
var scene: Node
var failed := false
func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://relic_u4_probe_progression.json")
	Store.set_run_storage_path("user://relic_u4_probe_run.save")
	Store.clear_saved_run()
	Settings.set_storage_path("user://relic_u4_probe_settings.json")
	Settings.clear_storage()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	Settings.save_settings(settings)
	Suite.install_fixtures()
	(GameData.cards()["u4_strike"] as Dictionary)["name"] = "Quick Stab"
	(GameData.cards()["u4_guard"] as Dictionary)["name"] = "Braced Guard"
	(GameData.cards()["u4_guard"] as Dictionary)["art_path"] = GameData.card_def("brace").get("art_path", "")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	await settle()
	var engine := CombatEngine.new()
	var s: Dictionary = Suite.state(engine, ["toll_late_bell"])
	s["cards_played_this_turn"] = 1
	s["player_turn_time_spent"] = 3
	(s["turn_queue"][0] as Dictionary)["time"] = 11
	engine._apply_stagger_to_enemy(s, 1, 6)
	await install(s)
	await scene.call("_on_card_pressed", 0)
	await hover_target()
	save("01_late_bell.png")
	expect(int((scene.call("_preview_damage_for_action", scene.get("_preview_combat_state"), (scene.get("_pending_actions") as Array)[0], Suite.TARGET) as Dictionary).get("enemy_1", {}).get("hp_loss", 0)) == 6, "Late Bell forecast shows six damage")
	await scene.call("_cancel_card_selection")
	s = Suite.state(engine, ["pocket_sundial"])
	var prepared: Dictionary = engine.prepare_player_card(s, 2)
	prepared = engine.apply_player_action(prepared, engine.card_play_actions("u4_guard", prepared)[0])
	s = engine.finish_player_card(prepared, 2)
	await install(s)
	expect(Suite.hero_projection(engine, s) == 11, "Sundial moves next portrait to Time 11")
	save("02_pocket_sundial.png")
	s = Suite.state(engine, ["whirling_sash"])
	s["cards_played_this_turn"] = 2
	s["player_turn_time_spent"] = 6
	await install(s)
	scene.call("_on_card_hover_started", 2)
	await settle()
	save("03_whirling_sash.png")
	scene.call("_on_card_hover_ended", 2)
	s = Suite.state(engine, ["crown_of_surplus"])
	await install(s)
	await scene.call("_on_card_pressed", 0)
	await scene.call("_toggle_pending_empower")
	await hover_target()
	expect(bool(scene.call("_selected_card_empowered")), "Crown toggled Empower on")
	var forecast: Dictionary = scene.call("_preview_damage_for_action", scene.get("_preview_combat_state"), (scene.get("_pending_actions") as Array)[0], Suite.TARGET)
	expect(int((forecast.get("enemy_1", {}) as Dictionary).get("hp_loss", 0)) == 6, "Crown hover includes repeated first attack")
	save("04_crown_of_surplus.png")
	await scene.call("_cancel_card_selection")
	s = Suite.state(engine, ["borrowed_hourglass"])
	s = engine.finish_player_activation(s)
	s = (engine.advance_one_activation_with_steps(s)["state"] as Dictionary)
	(s["deck"] as Dictionary)["hand"] = ["u4_strike", "u4_heavy", "u4_guard", "u4_follow", "u4_guard"]
	await install(s)
	var grid: Node = scene.get("_relic_icon_grid")
	var badge: Control = grid.get_child(0) as Control
	expect(badge.tooltip_text.ends_with("Used this combat."), "Borrowed tooltip discloses spent state")
	# Open the ordinary shared tooltip at the badge, using viewport mouse input.
	var motion := InputEventMouseMotion.new()
	motion.position = badge.get_global_rect().get_center()
	motion.global_position = motion.position
	viewport.push_input(motion, true)
	await create_timer(1.0).timeout
	await settle()
	var tooltip: Control = badge.call("_make_custom_tooltip", badge.tooltip_text) as Control
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	scene.add_child(overlay)
	overlay.add_child(tooltip)
	tooltip.position = badge.get_global_rect().position + Vector2(badge.size.x + 12, 0)
	tooltip.z_index = 100
	await settle()
	expect(tooltip.visible, "Borrowed shared tooltip is open")
	save("05_borrowed_hourglass_spent.png")
	overlay.queue_free()
	print(ProjectSettings.globalize_path(OUTPUT))
	print("RELIC U4 PROBE TEST RESULT: FAIL" if failed else "RELIC U4 PROBE TEST RESULT: PASS")
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
func hover_target() -> void:
	scene.call("_on_board_tile_hovered", Suite.TARGET)
	scene.call("_refresh_board_hover_presentation")
	var board: Control = scene.get("board_view")
	scene.call("_sync_click_targeting_arrow", board.get_global_transform_with_canvas() * (board.call("world_position_for_tile", Suite.TARGET) as Vector2))
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
