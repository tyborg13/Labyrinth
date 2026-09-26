extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Run = preload("res://scripts/run_engine.gd")
const Factory = preload("res://tools/dragon_boss_inspection.gd")
const Store = preload("res://scripts/progression_store.gd")
const Settings = preload("res://scripts/settings_store.gd")
const OUTPUT: String = "user://probes/banked_play_meter"
var failures: int = 0

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	call_deferred("_run")

func _run() -> void:
	Store.set_storage_path("user://banked_meter_profile.json")
	Store.set_run_storage_path("user://banked_meter_run.save")
	Settings.set_storage_path("user://banked_meter_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["display_mode"] = "windowed"
	settings["reduced_motion"] = true
	Settings.save_settings(settings)
	Settings.apply_settings(settings, root, false)
	var canvas := SubViewport.new()
	canvas.size = Vector2i(1920, 1080)
	canvas.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(canvas)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	canvas.add_child(scene)
	await process_frame
	var engine := Run.new()
	var combat := Combat.new()
	var options := {"dragon_id":"zekarion", "dragon_depth":20}
	var state: Dictionary = Factory.build(engine, combat, engine.create_new_run(Factory.seed_for_options(options), Store.default_data()), options)
	Store.save_data(state["progression"])
	Store.save_run_state(state)
	scene.set("_progression", state["progression"])
	scene.call("_load_run_state", state)
	await process_frame
	if bool(scene.get("_dialogue_active")): scene.call("_close_dialogue")
	var battle: Dictionary = (scene.get("_combat_state") as Dictionary).duplicate(true)
	battle["banked_play_active"] = 1
	battle["banked_play_spent_this_activation"] = 0
	battle["cards_played_this_turn"] = 0
	battle["cards_per_turn"] = 2
	battle["death_bonus_card_plays_this_turn"] = 0
	battle["card_play_bonus_this_turn"] = 0
	battle["deck"]["hand"] = ["brace"]
	scene.set("_combat_state", battle)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _capture(canvas, "ordinary_and_banked")
	_expect((scene.get("_play_meter_count") as Label).text == "3 card plays", "Total includes the available banked play")
	_expect((scene.get("_play_meter_banked_label") as Label).text == "1 BANKED", "Badge identifies the included banked play without adding it twice")
	battle["cards_played_this_turn"] = 2
	scene.set("_combat_state", battle)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	await _capture(canvas, "banked_only")
	_expect((scene.get("_play_meter_count") as Label).text == "1 card play", "A usable banked play must not look like an exhausted turn")
	await scene.call("_on_card_pressed", 0)
	await process_frame
	await scene.call("_on_card_pressed", 0)
	for _frame: int in range(90):
		await process_frame
		if not bool(scene.get("_animation_lock")): break
	var after: Dictionary = scene.get("_combat_state")
	_expect(int(after.get("banked_play_spent_this_activation", 0)) == 1, "The indicated banked play can actually pay for a card now")
	_expect(combat.cards_remaining_this_turn(after) == 0, "Spending the indicated last play exhausts the turn")
	await _capture(canvas, "banked_spent")
	canvas.queue_free()
	await process_frame
	print("BANKED PLAY METER: ", "PASS" if failures == 0 else "FAIL")
	quit(0 if failures == 0 else 1)

func _capture(canvas: SubViewport, label: String) -> void:
	await process_frame
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	var path: String = OUTPUT.path_join(label + ".png")
	_expect(canvas.get_texture().get_image().save_png(path) == OK, "Save " + label)
	print("SCREENSHOT: ", ProjectSettings.globalize_path(path))

func _expect(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)
