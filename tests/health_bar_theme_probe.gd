extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const SegmentedHealthBar = preload("res://scripts/segmented_health_bar.gd")

const OUTPUT_DIR: String = "user://probes/health_bar_theme_v1"
const PROGRESSION_PATH: String = "user://health_bar_theme_probe_progression.json"
const RUN_PATH: String = "user://health_bar_theme_probe_run.save"
const SETTINGS_PATH: String = "user://health_bar_theme_probe_settings.json"
const PROBE_SIZE: Vector2i = Vector2i(1920, 1080)

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_output()
	var viewport := SubViewport.new()
	viewport.name = "HealthBarTheme1920x1080"
	viewport.size = PROBE_SIZE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Health-bar proof should load the run scene")
	if packed != null:
		var instance: Node = packed.instantiate()
		viewport.add_child(instance)
		await _settle()
		instance.set("_settings", settings.duplicate(true))
		_install_combat_fixture(instance, false)
		await _settle()
		_hide_log(instance)
		_assert_themed_units(instance, 2, true)
		await _save_screenshot(viewport, "%s/health_bars_normal_1920x1080.png" % OUTPUT_DIR)
		var committed_state: Dictionary = (instance.get("_combat_state") as Dictionary).duplicate(true)
		await instance.call("_on_card_pressed", 0)
		instance.call("_on_board_tile_hovered", Vector2i(4, 3))
		await _settle()
		_assert_damage_preview(instance, committed_state)
		_hide_log(instance)
		await _save_screenshot(viewport, "%s/health_bars_damage_preview_1920x1080.png" % OUTPUT_DIR)
		_install_combat_fixture(instance, true)
		await _settle()
		_hide_log(instance)
		_assert_themed_units(instance, 5, false)
		_assert_health_rects_do_not_overlap(instance)
		await _save_screenshot(viewport, "%s/health_bars_dense_1920x1080.png" % OUTPUT_DIR)
		instance.queue_free()
		await process_frame
	viewport.queue_free()
	await process_frame
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("HEALTH BAR THEME PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("HEALTH BAR THEME PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)

func _install_combat_fixture(instance: Node, dense: bool) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout(dense)
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(
		92841,
		layout,
		{
			"hp": 16,
			"max_hp": 24,
			"deck_cards": ["quick_stab", "brace"],
			"relics": [],
			"hand_size": 2,
			"heal_bonus": 0,
		}
	)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 16
	player["max_hp"] = 24
	combat_state["player"] = player
	var enemies: Array = (combat_state.get("enemies", []) as Array).duplicate(true)
	for enemy_index: int in range(enemies.size()):
		var enemy: Dictionary = (enemies[enemy_index] as Dictionary).duplicate(true)
		enemy["hp"] = 14 if enemy_index != 1 else 12
		enemy["max_hp"] = 14
		enemies[enemy_index] = enemy
	combat_state["enemies"] = enemies
	combat_state["illusions"] = [] if dense else [{
		"id": 71,
		"pos": Vector2i(2, 4),
		"hp": 5,
		"max_hp": 8,
	}]
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")

func _combat_layout(dense: bool) -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	var enemies: Array = [
		_enemy(1, Vector2i(4, 3)),
		_enemy(2, Vector2i(6, 3)),
	]
	var player_start := Vector2i(3, 3)
	if dense:
		player_start = Vector2i(4, 4)
		enemies = [
			_enemy(1, Vector2i(2, 2)),
			_enemy(2, Vector2i(4, 2)),
			_enemy(3, Vector2i(6, 2)),
			_enemy(4, Vector2i(2, 4)),
			_enemy(5, Vector2i(6, 4)),
		]
	return {
		"name": "Lantern Verge",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "earth",
		"grid": grid,
		"player_start": player_start,
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": [],
	}

func _enemy(id: int, pos: Vector2i) -> Dictionary:
	return {
		"id": id,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"pos": pos,
		"hp": 14,
		"max_hp": 14,
		"block": 0,
		"stoneskin": 0,
		"base_initiative": 9,
	}

func _assert_themed_units(instance: Node, expected_enemy_count: int, expected_illusion: bool) -> void:
	var board: Control = instance.get("board_view") as Control
	_expect(board != null, "Health-bar proof should expose the combat board")
	if board == null:
		return
	var frame_textures: Dictionary = board.get("_health_bar_frame_textures") as Dictionary
	_expect(
		frame_textures.get(CombatBoardView.HEALTH_BAR_STYLE_LIGHT, null) is Texture2D,
		"Live board should load the authored lantern-frame texture"
	)
	_expect(
		frame_textures.get(CombatBoardView.HEALTH_BAR_STYLE_UMBRA, null) is Texture2D,
		"Live board should load the authored Umbra-frame texture"
	)
	var player_seen: bool = false
	var illusion_seen: bool = false
	var enemy_count: int = 0
	for unit_var: Variant in board.call("_build_visible_units"):
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var as Dictionary
		var role: String = str(unit.get("role", ""))
		if role == "player":
			player_seen = true
			_expect(
				board.call("_health_bar_visual_style", unit) == CombatBoardView.HEALTH_BAR_STYLE_LIGHT,
				"Live player health should use the lantern/light silhouette"
			)
		elif role == "enemy":
			enemy_count += 1
			_expect(
				board.call("_health_bar_visual_style", unit) == CombatBoardView.HEALTH_BAR_STYLE_UMBRA,
				"Live enemy health should use the Umbra silhouette"
			)
		elif role == "illusion":
			illusion_seen = true
			_expect(
				board.call("_health_bar_visual_style", unit) == CombatBoardView.HEALTH_BAR_STYLE_LIGHT,
				"Live illusion health should reuse the player's lantern silhouette"
			)
	_expect(player_seen, "The normal proof should include the player health bar")
	_expect(illusion_seen == expected_illusion, "The proof should include the expected damaged illusion health bar state")
	_expect(enemy_count == expected_enemy_count, "The proof should include %d enemy health bars" % expected_enemy_count)
	_assert_turn_order_health_bars(instance)

func _assert_turn_order_health_bars(instance: Node) -> void:
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	_expect(turn_order_bar != null, "Health-bar proof should expose the turn-order rail")
	if turn_order_bar == null:
		return
	var portrait_bar_count: int = 0
	var depleted_bar_count: int = 0
	for child: Node in turn_order_bar.get_children():
		var portrait_health: SegmentedHealthBar = child.find_child("TurnOrderHealthBar", true, false) as SegmentedHealthBar
		if portrait_health == null:
			continue
		portrait_bar_count += 1
		_expect(portrait_health.max_value > 0.0, "Turn-order portrait health bars should have a positive maximum")
		if portrait_health.value < portrait_health.max_value:
			depleted_bar_count += 1
	_expect(portrait_bar_count >= 3, "The turn order should show health bars for the player and visible enemies")
	_expect(depleted_bar_count >= 2, "The proof fixture should show visibly depleted player and enemy portrait health")

func _assert_health_rects_do_not_overlap(instance: Node) -> void:
	var board: Control = instance.get("board_view") as Control
	if board == null:
		return
	board.call("_rebuild_hud_health_rects_cache")
	var rect_map: Dictionary = board.get("_hud_health_rects_cache") as Dictionary
	_expect(rect_map.size() >= 6, "Dense proof should lay out player plus five enemy health bars")
	var keys: Array = rect_map.keys()
	for first_index: int in range(keys.size()):
		var first_rect: Rect2 = rect_map.get(keys[first_index], Rect2()) as Rect2
		for second_index: int in range(first_index + 1, keys.size()):
			var second_rect: Rect2 = rect_map.get(keys[second_index], Rect2()) as Rect2
			_expect(
				not first_rect.intersects(second_rect, false),
				"Dense proof health bars should not overlap: %s and %s" % [keys[first_index], keys[second_index]]
			)

func _assert_damage_preview(instance: Node, committed_state: Dictionary) -> void:
	_expect(
		(instance.get("_combat_state") as Dictionary) == committed_state,
		"Health-bar preview should not mutate committed combat state"
	)
	var board: Control = instance.get("board_view") as Control
	if board == null:
		return
	var preview: Dictionary = board.call("_damage_preview_map") as Dictionary
	var enemy_preview: Dictionary = preview.get("enemy_1", {}) as Dictionary
	_expect(not enemy_preview.is_empty(), "Damage-preview proof should project the adjacent enemy's health")
	_expect(
		int(enemy_preview.get("hp", 14)) < 14 and not bool(enemy_preview.get("lethal", true)),
		"Damage-preview proof should show a nonlethal projected-health band"
	)

func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false

func _save_screenshot(viewport: SubViewport, path: String) -> void:
	await _settle()
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == PROBE_SIZE, "%s should be exactly 1920x1080" % path)
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)

func _clear_output() -> void:
	var absolute_dir: String = ProjectSettings.globalize_path(OUTPUT_DIR)
	var directory := DirAccess.open(absolute_dir)
	if directory == null:
		return
	for file_name: String in directory.get_files():
		if file_name.ends_with(".png"):
			directory.remove(file_name)

func _settle() -> void:
	for _frame: int in range(6):
		await process_frame
	RenderingServer.force_draw(true)
	await process_frame

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
