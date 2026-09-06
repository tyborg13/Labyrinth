extends SceneTree

const Combat = preload("res://scripts/combat_engine.gd")
const Fixture = preload("res://tests/suites/chain_attack_suite.gd")
const Relics = preload("res://scripts/surface_relic_rules.gd")
const Ground = preload("res://scripts/board_surface_rules.gd")
const Settings = preload("res://scripts/settings_store.gd")
const Progression = preload("res://scripts/progression_store.gd")
const Tutorials = preload("res://scripts/contextual_combat_tutorial.gd")
const OUTPUT := "user://probes/board_surfaces"
var view: SubViewport
var scene: Node
var state: Dictionary
var animation_done: bool = false
var ground_loop_only: bool = false

func _initialize() -> void:
	preload("res://scripts/parallel_runtime.gd").apply_from_environment()
	Progression.set_storage_path("user://surface_progression.json")
	Progression.set_run_storage_path("user://surface_run.save")
	Progression.clear_saved_run()
	Settings.set_storage_path("user://surface_settings.json")
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["music_volume"] = 0.0
	settings["sfx_volume"] = 0.0
	Settings.save_settings(settings)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT))
	view = SubViewport.new()
	view.size = Vector2i(1920, 1080)
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	view.msaa_2d = Viewport.MSAA_4X
	root.add_child(view)
	scene = load("res://scenes/run_scene.tscn").instantiate()
	view.add_child(scene)
	await create_timer(0.2).timeout
	var progression: Dictionary = scene.get("_progression") as Dictionary
	for prompt: String in Tutorials.prompt_ids(): progression = Tutorials.resolve_progression(progression, prompt)
	scene.set("_progression", progression)
	var combat := Combat.new()
	state = Fixture.fixture(combat)
	(state["deck"] as Dictionary)["hand"] = ["chain_bolt", "guiding_flare", "frostbolt", "thorn_skewer", "updraft"]
	state["skill_ids"] = ["prismatic_instinct", "confluence"]
	state["surface_rule_overrides"] = {"conductive_fire": true}
	Ground.place(state, Vector2i(3, 3), "fire")
	Ground.place(state, Vector2i(3, 4), "fire")
	Ground.place(state, Vector2i(3, 4), "rubble")
	Ground.place(state, Vector2i(4, 4), "ice")
	Ground.place(state, Vector2i(5, 3), "ice")
	(state["enemies"][1] as Dictionary)["chilled"] = true
	Ground.place(state, Vector2i(6, 4), "electrified")
	Ground.place(state, Vector2i(6, 5), "electrified")
	Ground.place(state, Vector2i(7, 5), "electrified")
	Ground.place(state, Vector2i(4, 5), "rubble")
	Ground.place(state, Vector2i(5, 5), "rubble")
	Ground.place(state, Vector2i(2, 4), "rubble")
	var run: Dictionary = (scene.get("_run_state") as Dictionary).duplicate(true)
	run["mode"] = "combat"
	run["combat_state"] = state
	run["current_room"] = state.get("room_coord")
	run["current_room_layout"] = {"grid": state.get("grid"), "coord": state.get("room_coord"), "type": "combat", "name": "Board surface proof"}
	scene.set("_run_state", run)
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	await _capture("01_mixed_ground")
	if ground_loop_only:
		scene.queue_free()
		await process_frame
		quit()
		return
	scene.call("_begin_surface_skill_selection", "prismatic_instinct")
	await _capture("02_prismatic_aim")
	scene.call("_choose_surface_skill_kind", "ice")
	assert(not (scene.get("_surface_skill_tiles") as Array).is_empty(), "Prismatic needs real legal targets")
	scene.call("_cancel_surface_skill_selection")
	scene.call("_begin_surface_skill_selection", "confluence")
	scene.call("_commit_surface_skill_tile", Vector2i(3, 4))
	await _capture("03_confluence_destination")
	assert((scene.get("_surface_aim") as RefCounted).get("origin") == Vector2i(3, 4))
	scene.call("_cancel_surface_skill_selection")
	scene.call("_on_card_pressed", 2)
	scene.set("_hovered_board_tile", Vector2i(5, 3))
	scene.call("_refresh_stage_view")
	await _capture("04_freeze_preview")
	scene.call("_reset_card_resolution")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "controller", "xbox")
	scene.call("_begin_surface_skill_selection", "prismatic_instinct")
	for settle: int in range(4): await process_frame
	var choice_row: Control = scene.get("_surface_skill_choice_row") as Control
	var ice_button: Control = choice_row.get_child(1) as Control
	scene.call("_controller_set_focus_candidate", scene.call("_controller_candidate_for_control", ice_button), true)
	await scene.call("_controller_activate_current")
	assert(str((scene.get("_surface_aim") as RefCounted).get("kind")) == "ice", "Controller selects ground through original button")
	await _capture("05_controller_ground_choice")
	scene.call("_cancel_surface_skill_selection")
	scene.call("_begin_surface_skill_selection", "confluence")
	scene.call("_controller_set_board_tile", Vector2i(3, 4))
	await scene.call("_controller_activate_current")
	assert(str(scene.get("_controller_region")) == "board", "Controller stays on board after choosing source")
	await _capture("06_controller_relocate")
	scene.call("_cancel_surface_skill_selection")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	state["relics"] = ["thunder_relay", "thornmail_brooch", "worldroot_idol", "rimecatcher_vial", "updraft_bottle", "basalt_calendar", "coalheart_crucible", "briar_winch"]
	(state["player"] as Dictionary)["stoneskin"] = 8
	(state["player"] as Dictionary)["pos"] = Vector2i(3, 4)
	Ground.place(state, Vector2i(3, 5), "rubble")
	Ground.place(state, Vector2i(4, 4), "rubble")
	(state["deck"] as Dictionary)["hand"] = ["updraft", "cold_grasp", "chain_bolt", "rekindle_edge", "frostbolt"]
	scene.set("_combat_state", state)
	scene.call("_mark_combat_preview_state_changed")
	var relic_run: Dictionary = scene.get("_run_state") as Dictionary
	relic_run["combat_state"] = state
	relic_run["relics"] = state["relics"]
	scene.set("_run_state", relic_run)
	scene.call("_reset_card_resolution")
	scene.call("_refresh_ui")
	for card_index: int in range(5):
		scene.call("_reset_card_resolution")
		await scene.call("_on_card_pressed", card_index)
		var board: Node = scene.get("board_view") as Node
		var pointer: Vector2 = scene.call("_controller_board_point", Vector2i(4, 4))
		scene.call("_sync_click_targeting_arrow", pointer)
		scene.set("_hovered_board_tile", Vector2i(4, 4))
		scene.call("_refresh_stage_view")
		await _capture("07_relic_modes_%d" % card_index)
		var commands: Control = scene.get("_action_context_command_bar") as Control
		assert(commands.get_child_count() >= 2, "Card aiming exposes its transformative ground modes")
		if card_index == 1:
			# Exercise the original aiming flow, including mutually exclusive geometry.
			var current: Dictionary = (scene.get("_pending_actions") as Array)[0] as Dictionary
			for option: Dictionary in Relics.action_variants(state, current):
				if str(option.get("_surface_relic_label", "")) == "Spend 4 Stoneskin · cross":
					scene.call("_select_surface_relic_variant", option)
			current = (scene.get("_pending_actions") as Array)[0] as Dictionary
			assert(Relics.mode_enabled(current, "cross"))
			for option: Dictionary in Relics.action_variants(state, current):
				if str(option.get("_surface_relic_label", "")) == "Strike through Worldroot":
					scene.call("_select_surface_relic_variant", option)
			current = (scene.get("_pending_actions") as Array)[0] as Dictionary
			assert(Relics.mode_enabled(current, "remote") and not Relics.mode_enabled(current, "cross"))
			assert(bool(scene.get("_surface_relic_origin_pending")))
			scene.call("_select_surface_relic_origin", Vector2i(4, 5))
			assert(not bool(scene.get("_surface_relic_origin_pending")))
			await _capture("07_worldroot_selected")
		if card_index == 3:
			var found_crush: bool = false
			for command: Node in commands.get_children():
				if command is Button and "Crush" in (command as Button).text:
					found_crush = true
					(command as Button).pressed.emit()
			assert(found_crush, "Previous-impact Detonate mode must be selectable before the first attack")
			var shown: Dictionary = {}
			scene.call("_append_surface_action_preview", shown, scene.call("_active_card_preview"))
			assert((shown.get("surface_preview_events", []) as Array).any(func(event: Dictionary) -> bool: return str(event.get("kind", "")) == "detonate"), "The first click previews its automatic prior-impact Detonate")
			await _capture("07_crush_preview")
	scene.call("_reset_card_resolution")
	scene.call("_sync_click_targeting_arrow")
	scene.set("_animation_lock", true)
	var electrical: Dictionary = state.duplicate(true)
	(electrical["enemies"][0] as Dictionary)["pos"] = Vector2i(4, 4)
	(electrical["enemies"][1] as Dictionary)["pos"] = Vector2i(6, 4)
	(electrical["enemies"][2] as Dictionary)["pos"] = Vector2i(7, 5)
	for tile: Vector2i in [Vector2i(4, 4), Vector2i(5, 4), Vector2i(6, 4), Vector2i(6, 5), Vector2i(7, 5)]: Ground.place(electrical, tile, "electrified")
	var lightning: Dictionary = {"type": "ranged", "damage": 3, "range": 6, "element": "lightning"}
	var resolved: Dictionary = combat.resolve_player_action_for_presentation(electrical, lightning, Vector2i(4, 4))
	_play_lightning(electrical, resolved, lightning)
	await _wait_for_chain_beat(false)
	await _capture("08_conduction_contact", 0)
	while not animation_done: await process_frame
	await _capture("09_conduction_consumed")
	# A distant enemy is reached through an empty-floor relay, with a distinct hop.
	var relay: Dictionary = Fixture.fixture(combat)
	relay["enemies"] = (relay["enemies"] as Array).slice(0, 2)
	(relay["enemies"][1] as Dictionary)["pos"] = Vector2i(7, 4)
	Ground.place(relay, Vector2i(5, 4), "electrified")
	var chained: Dictionary = {"type": "ranged", "damage": 3, "range": 6, "chain": 2, "element": "lightning"}
	var relay_result: Dictionary = combat.resolve_player_action_for_presentation(relay, chained, Vector2i(4, 4))
	assert((relay_result["chain_hits"] as Array).any(func(hit: Dictionary) -> bool: return str(hit.get("kind", "")) == "relay"))
	_play_lightning(relay, relay_result, chained)
	await _wait_for_chain_beat(true)
	await _capture("10_chain_relay", 0)
	while not animation_done: await process_frame
	var fiery: Dictionary = Fixture.fixture(combat)
	Ground.place(fiery, Vector2i(4, 4), "fire")
	Ground.place(fiery, Vector2i(5, 3), "fire")
	var detonate: Dictionary = {"type": "detonate", "range": 6, "damage": 6, "pattern": [[0, 0], [1, 0], [1, -1]]}
	var detonated: Dictionary = combat.apply_player_action(fiery, detonate, Vector2i(4, 4))
	assert(Ground.element_at(detonated, Vector2i(4, 4)).is_empty())
	_play_lightning(fiery, {"state": detonated, "chain_hits": []}, detonate)
	await create_timer(0.26).timeout
	await _capture("11_detonate_contact", 0)
	while not animation_done: await process_frame
	await _capture("12_detonate_consumed")
	router.call("clear_forced_state_for_test")
	print("BOARD SURFACE VISUAL PROBE: PASS")
	print(ProjectSettings.globalize_path(OUTPUT))
	scene.queue_free()
	await process_frame
	quit()

func _capture(name: String, settle_frames: int = 8) -> void:
	for i: int in range(settle_frames): await process_frame
	if int(scene.get("_selected_card_index")) >= 0:
		var target: Vector2i = scene.get("_hovered_board_tile")
		if target.x >= 0: scene.call("_sync_click_targeting_arrow", scene.call("_controller_board_point", target))
	await RenderingServer.frame_post_draw
	var screenshot: Image = view.get_texture().get_image()
	assert(screenshot.get_size() == Vector2i(1920, 1080))
	assert(screenshot.save_png(ProjectSettings.globalize_path(OUTPUT.path_join(name + ".png"))) == OK)

func _play_lightning(before: Dictionary, result: Dictionary, action: Dictionary) -> void:
	animation_done = false
	await scene.call("_animate_player_action_step", before, result["state"], "chain_bolt", action, Vector2i(4, 4), result["chain_hits"])
	animation_done = true

func _wait_for_chain_beat(relay: bool) -> void:
	for frame: int in range(180):
		await process_frame
		var board: Control = scene.get("board_view") as Control
		var presentation: Dictionary = board.get("presentation") as Dictionary
		var effect: Dictionary = presentation.get("effect", {}) as Dictionary
		if str(effect.get("kind", "")) == "chain" and bool(effect.get("relay", false)) == relay and float(presentation.get("effect_progress", 0.0)) >= 0.25:
			return
	assert(false, "The resolver route must have a visible relay or conduction beat")
