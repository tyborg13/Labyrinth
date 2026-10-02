extends SceneTree

const Suite = preload("res://tests/suites/relic_u2_suite.gd")
const Combat = preload("res://scripts/combat_engine.gd")
const Surface = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Store = preload("res://scripts/progression_store.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const Tutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT: String = "res://output/relic-u2-probe"
var _viewport: SubViewport
var _failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	Settings.set_storage_path("user://relic_u2_probe_settings.json")
	Store.set_storage_path("user://relic_u2_probe_profile.json")
	Store.set_run_storage_path("user://relic_u2_probe_run.save")
	_run.call_deferred()

func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(1920, 1080)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	var scene: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(scene)
	await _settle()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	scene.set("_settings", settings)
	var progression: Dictionary = scene.get("_progression") as Dictionary
	for id: String in Tutorial.prompt_ids():
		progression = Tutorial.resolve_progression(progression, id)
	scene.set("_progression", progression)
	var engine := Combat.new()
	var layout: Dictionary = Suite.room()
	layout["umbra_stage"] = "eclipse"
	layout["enemies"][0]["pos"] = Vector2i(4, 4)
	var opening: Dictionary = engine.create_combat(2202, layout, {"hp": 24, "max_hp": 24, "deck_cards": ["quick_stab", "brace", "iron_wheel"], "hand_size": 3, "relics": ["tallow_candle", "grave_dirt", "waxen_effigy"]})
	await _install(scene, opening)
	_expect(int(opening["player"]["stoneskin"]) == 4 and opening["illusions"][0]["pos"] == Vector2i(3, 4), "Opening probe contains Stoneskin, Light and the forward illusion")
	await _capture("01_combat_start.png")
	var fencer: Dictionary = Suite.state(engine, ["fencers_gloves"], ["brace", "quick_stab", "overhead_smash", "sidestep_slash", "kindle"])
	fencer = engine.apply_player_action(fencer, engine.card_play_actions("brace", fencer)[0])
	fencer = engine.finish_player_card(fencer, 0)
	await _install(scene, fencer)
	for id: String in fencer["deck"]["hand"]:
		_expect(engine.card_time_cost(id, fencer) == maxi(1, engine.card_time_cost(id, {}) - 1), "Fencer probe discounts each remaining hand Time badge")
	await _capture("02_fencers_gloves.png")
	var flint: Dictionary = Suite.state(engine, ["flint_edge"], ["quick_stab", "brace", "iron_wheel"])
	Surface.place(flint, Vector2i(3, 4), "fire", {"actor_kind": "player"})
	await _install(scene, flint)
	await _arm(scene)
	_hover(scene, Vector2i(3, 4))
	await _settle()
	var board: Control = scene.get_node("BoardUnderlay/CombatBoard")
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_expect(not (presentation.get("damage_preview", {}) as Dictionary).is_empty(), "Flint probe shows damage forecast")
	var removed: bool = false
	for event: Dictionary in presentation.get("surface_preview_events", []):
		removed = removed or str(event.get("kind", "")) == "surface_removed"
	_expect(removed, "Flint probe shows surface consumption")
	await _capture("03_flint_edge.png")
	var duelist: Dictionary = Suite.state(engine, ["duelist_whetstone"], ["dust_glide", "sidestep_slash", "brace", "quick_stab"])
	duelist["player"]["pos"] = Vector2i(2, 7)
	duelist["enemies"][0]["pos"] = Vector2i(3, 3)
	duelist["cards_per_turn"] = 2
	for action: Dictionary in engine.card_play_actions("dust_glide", duelist):
		duelist = engine.apply_player_action(duelist, action, Vector2i(2, 4))
	duelist = engine.finish_player_card(duelist, 0)
	_expect(int(duelist["turn_flags"].get("tiles_moved", 0)) == 3, "Duelist probe actually moves three tiles")
	await _install(scene, duelist)
	await _arm(scene)
	_hover(scene, Vector2i(3, 3))
	await _settle()
	presentation = board.get("presentation") as Dictionary
	_expect(not ((presentation.get("effect", {}) as Dictionary).get("damage_preview", {}) as Dictionary).is_empty(), "Duelist probe shows move-and-strike damage forecast")
	await _capture("04_duelist_whetstone.png")
	scene.queue_free()
	await process_frame
	_viewport.queue_free()
	for failure: String in _failures:
		push_error(failure)
	print("RELIC U2 PROBE TEST RESULT: PASS" if _failures.is_empty() else "RELIC U2 PROBE TEST RESULT: FAIL (%d failures)" % _failures.size())
	print(ProjectSettings.globalize_path(OUTPUT))
	quit(0 if _failures.is_empty() else 1)

func _install(scene: Node, value: Dictionary) -> void:
	value["cards_per_turn"] = 2
	scene.call("_cancel_drag_play")
	scene.call("_reset_card_resolution")
	var run_state: Dictionary = scene.get("_run_state") as Dictionary
	run_state["mode"] = "combat"
	run_state["current_room"] = value.get("room_coord", Vector2i(1, 0))
	run_state["current_room_layout"] = Suite.room()
	run_state["combat_state"] = value
	run_state["relics"] = value["relics"]
	scene.set("_run_state", run_state)
	scene.set("_combat_state", value)
	scene.set("_animation_lock", false)
	scene.set("_card_play_count_override", -1)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_refresh_ui")
	scene.call("_refresh_contextual_combat_tutorial")
	await _settle()

func _arm(scene: Node) -> void:
	await scene.call("_on_card_pressed", 0)
	await _settle()
	if int(scene.get("_card_action_choice_index")) == 0:
		await scene.call("_on_card_action_choice_pressed", "play")
		await _settle()

func _hover(scene: Node, tile: Vector2i) -> void:
	scene.call("_on_board_tile_hovered", tile)
	scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", tile))

func _capture(name: String) -> void:
	RenderingServer.force_draw()
	await process_frame
	var picture: Image = _viewport.get_texture().get_image()
	_expect(picture.get_size() == Vector2i(1920, 1080), "Probe must render at 1920x1080")
	_expect(picture.save_png("%s/%s" % [OUTPUT, name]) == OK, "Probe should save %s" % name)

func _settle() -> void:
	for frame: int in range(12):
		await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
