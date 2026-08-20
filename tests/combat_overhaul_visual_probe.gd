extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatTerrainRules = preload("res://scripts/combat_terrain_rules.gd")
const ContextualCombatTutorial = preload("res://scripts/contextual_combat_tutorial.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/combat_overhaul_v1"
const BOARD_PATH: String = "BoardUnderlay/CombatBoard"
const VIEWPORT_SIZE: Vector2i = Vector2i(1920, 1080)

var _failures: Array[String]


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://combat_overhaul_visual_probe_progression.json")
	ProgressionStore.set_run_storage_path("user://combat_overhaul_visual_probe_run.save")
	SettingsStore.set_storage_path("user://combat_overhaul_visual_probe_settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output()

	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Combat overhaul proof should load the real run scene")
	if packed != null:
		await _capture_combat(packed, settings)

	print("COMBAT OVERHAUL VISUAL PROBE DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("COMBAT OVERHAUL VISUAL PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("COMBAT OVERHAUL VISUAL PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_combat(packed: PackedScene, settings: Dictionary) -> void:
	var viewport := SubViewport.new()
	viewport.name = "CombatOverhaulProof"
	viewport.size = VIEWPORT_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.set("_settings", settings.duplicate(true))
	var progression: Dictionary = ProgressionStore.default_data()
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	var run_engine := RunEngine.new()
	instance.call("_load_run_state", run_engine.create_new_run(824031, progression))
	instance.call("_close_dialogue")
	await _settle()

	var fixture: Dictionary = _build_fixture()
	var layout: Dictionary = fixture.get("layout", {}) as Dictionary
	var combat_state: Dictionary = fixture.get("combat_state", {}) as Dictionary
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout.duplicate(true)
	run_state["combat_state"] = combat_state.duplicate(true)
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle()
	instance.call("_on_board_tile_hovered", Vector2i(6, 5))
	instance.set("_turn_order_hovered_enemy_key", "enemy_1")
	instance.call("_refresh_stage_view")
	await _settle()

	var board := instance.get_node(BOARD_PATH) as Control
	_expect(board != null, "Combat overhaul proof should find the real combat board")
	var free_move_button := instance.find_child("FreeMoveButton", true, false) as Button
	_expect(
		free_move_button != null
		and free_move_button.is_visible_in_tree()
		and not free_move_button.disabled
		and free_move_button.text == "MOVE 2",
		"Player activation should expose one enabled free MOVE 2 action"
	)
	_expect(instance.find_child("ElementalIntensityHud", true, false) == null, "Combat HUD should not retain elemental intensity")
	if board != null:
		_assert_board_state(board)
	await _save_screenshot(viewport, "%s/01_focused_committed_route.png" % OUTPUT_DIR)

	instance.call("_set_show_all_enemy_intents", true)
	instance.set("_hovered_board_tile", Vector2i(-999, -999))
	instance.call("_refresh_stage_view")
	await _settle()
	if board != null:
		var presentation: Dictionary = board.get("presentation") as Dictionary
		_expect(bool(presentation.get("show_all_enemy_intents", false)), "Intent toggle should reveal every committed enemy plan")
		_expect((presentation.get("enemy_threat_previews", []) as Array).size() == 3, "All-intents view should expose all three enemy plans")
	await _save_screenshot(viewport, "%s/02_all_intents_and_board_packages.png" % OUTPUT_DIR)

	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame


func _build_fixture() -> Dictionary:
	var layout: Dictionary = {
		"name": "The Fractured Causeway",
		"coord": Vector2i(2, 1),
		"depth": 3,
		"type": "combat",
		"element": "earth",
		"umbra_stage": "clear",
		"grid": _combat_grid(),
		"player_start": Vector2i(2, 5),
		"enemies": [
			{"id": 1, "type": "harrier", "name": "Corrupting Harrier", "pos": Vector2i(6, 5), "hp": 18, "max_hp": 18},
			{"id": 2, "type": "acolyte", "name": "Grave Acolyte", "pos": Vector2i(7, 2), "hp": 20, "max_hp": 20},
			{"id": 3, "type": "crawler", "name": "Tunnel Crawler", "pos": Vector2i(5, 2), "hp": 16, "max_hp": 16},
		],
		"terrain": [{"id": "interceptor", "kind": "wooden_crate", "pos": Vector2i(8, 4), "hp": 8, "max_hp": 8}],
		"traps": [],
		"loot": [],
	}
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(824032, layout, {
		"hp": 25,
		"max_hp": 30,
		"deck_cards": ["root_snare", "glacier_pin", "spark_focus", "wildfire_halo", "vacuum_line"],
		"relics": [],
		"hand_size": 5,
		"heal_bonus": 0,
	})
	combat_state["player"] = {"pos": Vector2i(2, 5), "hp": 25, "max_hp": 30, "block": 4, "stoneskin": 0}
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	combat_state["initiative_clock"] = 12
	combat_state["free_move_available"] = true
	combat_state["cards_played_this_turn"] = 0
	combat_state["card_play_bonus_this_turn"] = 0
	combat_state["death_bonus_card_plays_this_turn"] = 0
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["root_snare", "glacier_pin", "spark_focus", "wildfire_halo", "vacuum_line"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck

	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	enemies[0]["intent"] = {
		"name": "Corrupting Rush",
		"actions": [
			{"type": "move_toward", "range": 3, "field_kind": "corruption", "field_mode": "route", "field_duration": 22},
			{"type": "melee", "damage": 6, "range": 1},
		],
	}
	enemies[1]["intent"] = {
		"name": "Mend the Line",
		"actions": [
			{"type": "heal_ally", "amount": 4, "range": 5},
			{"type": "block_ally", "amount": 3, "range": 5},
		],
	}
	enemies[2]["intent"] = {
		"name": "Raking Cross",
		"actions": [{"type": "aoe", "damage": 4, "range": 5, "pattern": [[0, 0], [1, 0], [-1, 0], [0, 1], [0, -1]], "rotate": false, "field_kind": "corruption", "field_mode": "affected"}],
	}
	combat_state["enemies"] = enemies

	CombatTerrainRules.place_field(combat_state, [Vector2i(7, 4), Vector2i(8, 4)], CombatTerrainRules.FIELD_CORRUPTION, 34)
	CombatTerrainRules.place_field(combat_state, [Vector2i(2, 2), Vector2i(3, 2)], CombatTerrainRules.FIELD_RADIANCE, 38)
	CombatTerrainRules.place_surface(combat_state, [Vector2i(2, 3)], CombatTerrainRules.SURFACE_BRAMBLE, 30)
	CombatTerrainRules.place_surface(combat_state, [Vector2i(3, 3)], CombatTerrainRules.SURFACE_POISON, 31)
	CombatTerrainRules.place_surface(combat_state, [Vector2i(4, 3), Vector2i(5, 3)], CombatTerrainRules.SURFACE_ICE, 32)
	CombatTerrainRules.place_surface(combat_state, [Vector2i(6, 3)], CombatTerrainRules.SURFACE_SNOWDRIFT, 33)
	CombatTerrainRules.place_surface(combat_state, [Vector2i(7, 3)], CombatTerrainRules.SURFACE_ELECTRIFIED, 34)
	for enemy_index: int in range(enemies.size()):
		combat.call("_commit_enemy_intent_plan", combat_state, enemy_index)
	return {"layout": layout, "combat_state": combat_state}


func _assert_board_state(board: Control) -> void:
	var board_state: Dictionary = board.get("combat_state") as Dictionary
	var effect_textures: Dictionary = board.get("_effect_textures") as Dictionary
	_expect(effect_textures.get("board_effects_atlas", null) is Texture2D, "Board effects should use the production material atlas")
	var tile_effects: Dictionary = board_state.get("tile_effects", {}) as Dictionary
	_expect((tile_effects.get("fields", []) as Array).size() == 4, "Board should show two Corruption and two Radiance tiles")
	_expect((tile_effects.get("surfaces", []) as Array).size() == 6, "Board should show every elemental surface package")
	var presentation: Dictionary = board.get("presentation") as Dictionary
	_expect((presentation.get("path_tiles", []) as Array).size() >= 2, "Focused enemy should show its committed movement route")
	_expect(not (presentation.get("projected_attack_tiles", []) as Array).is_empty(), "Focused enemy should show the tiles its committed attack will hit")
	_expect(not (presentation.get("projected_field_tiles", []) as Array).is_empty(), "Focused enemy should show which route tiles will become Corrupted")


func _combat_grid() -> Array:
	var grid: Array = []
	for y: int in range(8):
		var row: Array = []
		for x: int in range(10):
			row.append("wall" if x == 0 or x == 9 or y == 0 or y == 7 else "stone")
		grid.append(row)
	return grid


func _save_screenshot(viewport: SubViewport, path: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == VIEWPORT_SIZE, "%s should render at 1920x1080" % path)
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)


func _clear_probe_output() -> void:
	var directory := DirAccess.open(OUTPUT_DIR)
	if directory == null:
		return
	for filename: String in directory.get_files():
		directory.remove(filename)


func _settle() -> void:
	for _frame: int in range(8):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
