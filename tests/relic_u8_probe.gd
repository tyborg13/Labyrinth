extends SceneTree
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Suite = preload("res://tests/suites/relic_u8_suite.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const SIZE := Vector2i(1920, 1080)
const OUTPUT := "user://probes/relic_u8/1920x1080"
var viewport: SubViewport
var scene: Node
var failed := false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Store.set_storage_path("user://relic_u8_probe_progression.json")
	Store.set_run_storage_path("user://relic_u8_probe_run.save")
	Store.clear_saved_run()
	Settings.set_storage_path("user://relic_u8_probe_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	call_deferred("run")

func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	viewport = SubViewport.new()
	viewport.size = SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	scene = (load("res://scenes/run_scene.tscn") as PackedScene).instantiate()
	viewport.add_child(scene)
	await settle()
	var progression: Dictionary = scene.get("_progression")
	for prompt: String in Tutorials.prompt_ids():
		progression = Tutorials.resolve_progression(progression, prompt)
	scene.set("_progression", progression)
	var engine := Combat.new()
	var s: Dictionary = Suite.state(engine, Suite.ALL_RELICS, ["powder_keg", "throwing_net", "quick_stab", "brace", "pale_spark"])
	s["room_name"] = "Item relic proof"
	await install(s)
	var hand_box: Control = scene.get("hand_box")
	expect(hand_box.get_child_count() == 5, "Five real hand card faces are rendered")
	var keg_widget: Control = scene.call("_hand_card_control", 0)
	var net_widget: Control = scene.call("_hand_card_control", 1)
	expect(int(keg_widget.get("_time_badge").get("value")) == 4, "Keg Time badge includes Bandolier")
	expect(int(net_widget.get("_time_badge").get("value")) == 5, "Net Time badge includes Bandolier")
	save("01_item_card_faces.png")
	await scene.call("_on_card_pressed", 1)
	scene.call("_on_board_tile_hovered", Suite.TARGET)
	scene.call("_refresh_board_hover_presentation")
	await settle()
	var forecast: Dictionary = scene.call("_pass_preview_source_state")
	expect(not forecast.is_empty() and forecast["cards_played_this_turn"] == 0 and forecast["player_turn_time_spent"] == 5, "Net hover forecasts zero plays and five Time")
	await scene.call("_on_board_tile_clicked", Suite.TARGET)
	await settle()
	var after: Dictionary = scene.get("_combat_state")
	expect(after["cards_played_this_turn"] == 0 and engine.cards_remaining_this_turn(after) == 2, "Card-play counter retains both plays after the Net")
	expect(after["player_turn_time_spent"] == 5 and after["deck"]["burned"] == ["throwing_net"], "Live Net commit pays Time and leaves play for the combat")
	expect(forecast["deck"] == after["deck"] and forecast["enemies"] == after["enemies"], "Net hover forecast equals live commit")
	expect(after["enemies"][0]["hp"] == 40 and after["enemies"][0].get("immobilize", false), "Live Net remains zero damage and Immobilizes")
	save("02_net_card_play_counter.png")
	print(ProjectSettings.globalize_path(OUTPUT))
	print("RELIC U8 PROBE TEST RESULT: FAIL" if failed else "RELIC U8 PROBE TEST RESULT: PASS")
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
	run["current_room_layout"] = {"coord": Vector2i(2, 2), "type": "combat", "name": s["room_name"], "grid": s["grid"], "props": []}
	for room: Dictionary in (run.get("rooms", {}) as Dictionary).values():
		if room.get("coord", Vector2i(-1, -1)) == Vector2i(2, 2):
			room["type"] = "combat"
	run["combat_state"] = s
	run["relics"] = s["relics"].duplicate()
	scene.set("_guided_tutorial_phase_id", "")
	scene.set("_run_state", run)
	scene.set("_combat_state", s)
	scene.set("_animation_lock", false)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	var log: Control = scene.get("log_overlay")
	if log != null:
		log.visible = false
	await settle()

func settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.3).timeout

func save(file: String) -> void:
	RenderingServer.force_draw()
	var img: Image = viewport.get_texture().get_image()
	expect(img.get_size() == SIZE, "Exact capture size")
	expect(img.save_png(OUTPUT.path_join(file)) == OK, "Screenshot saved: " + file)

func expect(condition: bool, message: String) -> void:
	if not condition:
		failed = true
		push_error(message)
