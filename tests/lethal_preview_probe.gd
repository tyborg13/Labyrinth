extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const CombatBoardView = preload("res://scripts/combat_board_view.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/lethal_preview_v2"
const PROGRESSION_PATH: String = "user://lethal_preview_probe_progression.json"
const RUN_PATH: String = "user://lethal_preview_probe_run.save"
const SETTINGS_PATH: String = "user://lethal_preview_probe_settings.json"

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Lethal preview proof should load the run scene")
	if packed != null:
		for config: Dictionary in [
			{"size": Vector2i(1920, 1080), "scale": 1.0},
			{"size": Vector2i(1280, 720), "scale": 1.0},
			{"size": Vector2i(1280, 800), "scale": 1.25},
		]:
			await _capture_config(packed, config)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("LETHAL PREVIEW PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("LETHAL PREVIEW PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_config(packed: PackedScene, config: Dictionary) -> void:
	var screenshot_size: Vector2i = config.get("size", Vector2i(1920, 1080))
	var ui_scale: float = float(config.get("scale", 1.0))
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = false
	settings["ui_scale"] = ui_scale
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)

	var viewport := SubViewport.new()
	viewport.name = "LethalPreview_%dx%d_ui%d" % [
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
	]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = logical_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	var single_instance: Node = packed.instantiate()
	viewport.add_child(single_instance)
	await _settle()
	single_instance.set("_settings", settings.duplicate(true))
	_install_combat_fixture(single_instance, false)
	await _settle()
	_expect(
		single_instance.get_viewport().get_visible_rect().size == Vector2(logical_size),
		"%s @ %d%% should expose logical viewport %s" % [
			screenshot_size,
			roundi(ui_scale * 100.0),
			logical_size,
		]
	)
	var single_before: Dictionary = (single_instance.get("_combat_state") as Dictionary).duplicate(true)
	await single_instance.call("_on_card_pressed", 0)
	single_instance.call("_on_board_tile_hovered", Vector2i(4, 3))
	await _settle()
	_assert_single_target_preview(single_instance, single_before, screenshot_size)
	_hide_log(single_instance)
	await _set_lethal_marker_frame(
		single_instance,
		false,
		CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS * 0.25
	)
	await _save_screenshot(
		viewport,
		"%s/single_target_lethal.png" % output_dir,
		screenshot_size
	)
	if screenshot_size == Vector2i(1920, 1080):
		await _set_lethal_marker_frame(
			single_instance,
			false,
			CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS * 0.75
		)
		await _save_screenshot(
			viewport,
			"%s/single_target_pulse_trough.png" % output_dir,
			screenshot_size
		)
	single_instance.queue_free()
	await process_frame

	var aoe_instance: Node = packed.instantiate()
	viewport.add_child(aoe_instance)
	await _settle()
	aoe_instance.set("_settings", settings.duplicate(true))
	_install_combat_fixture(aoe_instance, true)
	await _settle()
	var aoe_before: Dictionary = (aoe_instance.get("_combat_state") as Dictionary).duplicate(true)
	await aoe_instance.call("_on_card_pressed", 0)
	await _settle()
	_assert_aoe_preview(aoe_instance, aoe_before, screenshot_size)
	_hide_log(aoe_instance)
	await _set_lethal_marker_frame(
		aoe_instance,
		false,
		CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS * 0.25
	)
	await _save_screenshot(
		viewport,
		"%s/aoe_lethal.png" % output_dir,
		screenshot_size
	)
	if screenshot_size == Vector2i(1280, 800):
		await _set_lethal_marker_frame(
			aoe_instance,
			true,
			CombatBoardView.LETHAL_DEATH_MARK_PULSE_SECONDS * 0.75
		)
		await _save_screenshot(
			viewport,
			"%s/aoe_reduced_motion.png" % output_dir,
			screenshot_size
		)
	aoe_instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame


func _set_lethal_marker_frame(
	instance: Node,
	reduced_motion: bool,
	time_seconds: float
) -> void:
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var board_presentation: Dictionary = (
		instance.get("_board_presentation") as Dictionary
	).duplicate(true)
	board_presentation["lethal_preview_time_seconds"] = time_seconds
	instance.set("_board_presentation", board_presentation)
	instance.call("_refresh_stage_view")
	await _settle()
	var board: Control = instance.get("board_view") as Control
	if board == null:
		_expect(false, "Lethal marker proof frame should expose the combat board")
		return
	var rendered_presentation: Dictionary = board.get("presentation") as Dictionary
	_expect(
		bool(rendered_presentation.get("reduced_motion", false)) == reduced_motion,
		"Lethal marker proof frame should propagate reduced-motion state"
	)
	var rendered_pulse: float = float(board.call("_lethal_death_mark_pulse", time_seconds))
	_expect(
		rendered_pulse >= 0.0 and rendered_pulse <= 1.0,
		"Lethal marker proof frame should keep pulse strength normalized"
	)
	if reduced_motion:
		_expect(
			is_equal_approx(rendered_pulse, 0.5),
			"Reduced motion should hold the lethal marker at its neutral frame"
		)


func _install_combat_fixture(instance: Node, aoe: bool) -> void:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout(aoe)
	var card_id: String = "whirlwind_slash" if aoe else "quick_stab"
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(
		81371 if aoe else 81370,
		layout,
		{
			"hp": 24,
			"max_hp": 24,
			"deck_cards": [card_id, "brace"],
			"relics": [],
			"hand_size": 2,
			"heal_bonus": 0,
		}
	)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = [card_id, "brace"]
	deck["draw"] = []
	deck["discard"] = []
	deck["burned"] = []
	combat_state["deck"] = deck
	combat_state["current_actor"] = {"kind": "player", "key": "player"}
	var run_state: Dictionary = (instance.get("_run_state") as Dictionary).duplicate(true)
	run_state["mode"] = "combat"
	run_state["current_room"] = layout.get("coord", Vector2i.ZERO)
	run_state["current_room_layout"] = layout
	run_state["combat_state"] = combat_state
	instance.set("_run_state", run_state)
	instance.set("_combat_state", combat_state)
	instance.set("_animation_lock", false)
	instance.call("_refresh_ui")


func _combat_layout(aoe: bool) -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	var enemies: Array = []
	var player_start := Vector2i(4, 3) if aoe else Vector2i(3, 3)
	if aoe:
		enemies = [
			_enemy(1, Vector2i(4, 2), 8),
			_enemy(2, Vector2i(5, 3), 9),
			_enemy(3, Vector2i(4, 4), 18),
		]
	else:
		enemies = [
			_enemy(1, Vector2i(4, 3), 8),
			_enemy(2, Vector2i(6, 3), 22),
		]
	return {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": player_start,
		"enemies": enemies,
		"traps": [],
		"terrain": [],
		"loot": [],
	}


func _enemy(id: int, pos: Vector2i, hp: int) -> Dictionary:
	return {
		"id": id,
		"type": "crawler",
		"name": "Tunnel Crawler",
		"pos": pos,
		"hp": hp,
		"max_hp": hp,
		"block": 0,
		"stoneskin": 0,
		"base_initiative": 9,
	}


func _assert_single_target_preview(
	instance: Node,
	committed_state: Dictionary,
	screenshot_size: Vector2i
) -> void:
	_expect(
		(instance.get("_combat_state") as Dictionary) == committed_state,
		"%s single-target selection should not mutate live combat" % screenshot_size
	)
	var board: Control = instance.get("board_view") as Control
	_expect(board != null, "%s should expose the combat board" % screenshot_size)
	if board == null:
		return
	var preview: Dictionary = board.call("_damage_preview_map") as Dictionary
	var lethal_preview: Dictionary = preview.get("enemy_1", {}) as Dictionary
	_expect(
		int(lethal_preview.get("hp", -1)) == 0 and bool(lethal_preview.get("lethal", false)),
		"%s single-target preview should mark the adjacent enemy lethal at zero HP" % screenshot_size
	)
	_assert_board_units(board, 2, 1, [8, 22], "%s single-target" % screenshot_size)


func _assert_aoe_preview(
	instance: Node,
	committed_state: Dictionary,
	screenshot_size: Vector2i
) -> void:
	_expect(
		(instance.get("_combat_state") as Dictionary) == committed_state,
		"%s AOE selection should not mutate live combat" % screenshot_size
	)
	_expect(
		int(instance.get("_pending_action_index")) >= (instance.get("_pending_actions") as Array).size(),
		"%s targetless AOE preview should finish pending confirmation" % screenshot_size
	)
	var board: Control = instance.get("board_view") as Control
	_expect(board != null, "%s should expose the AOE combat board" % screenshot_size)
	if board == null:
		return
	var preview: Dictionary = (board.get("presentation") as Dictionary).get("damage_preview", {}) as Dictionary
	for enemy_id: int in [1, 2]:
		var lethal_preview: Dictionary = preview.get("enemy_%d" % enemy_id, {}) as Dictionary
		_expect(
			int(lethal_preview.get("hp", -1)) == 0 and bool(lethal_preview.get("lethal", false)),
			"%s AOE preview should mark enemy %d lethal at zero HP" % [screenshot_size, enemy_id]
		)
	var survivor_preview: Dictionary = preview.get("enemy_3", {}) as Dictionary
	_expect(
		int(survivor_preview.get("hp", -1)) == 8 and not bool(survivor_preview.get("lethal", true)),
		"%s AOE preview should show the surviving enemy at 8 HP" % screenshot_size
	)
	_assert_board_units(board, 3, 2, [8, 9, 18], "%s AOE" % screenshot_size)


func _assert_board_units(
	board: Control,
	expected_enemy_count: int,
	expected_lethal_count: int,
	expected_hp: Array,
	label: String
) -> void:
	var visible_units: Array = board.call("_build_visible_units")
	var enemy_count: int = 0
	var lethal_count: int = 0
	var hp_values: Array[int] = []
	for unit_var: Variant in visible_units:
		if typeof(unit_var) != TYPE_DICTIONARY:
			continue
		var unit: Dictionary = unit_var
		if str(unit.get("role", "")) != "enemy":
			continue
		enemy_count += 1
		hp_values.append(int(unit.get("hp", 0)))
		if bool(board.call("_unit_is_preview_lethal", unit)):
			lethal_count += 1
			var lethal_preview: Dictionary = board.call("_unit_damage_preview", unit) as Dictionary
			_expect(
				int(board.call("_health_bar_fill_hp", unit, lethal_preview)) == 0
				and not bool(board.call("_damage_preview_shows_lost_hp", lethal_preview)),
				"%s lethal enemy should render a genuinely empty health bar" % label
			)
	hp_values.sort()
	var sorted_expected: Array = expected_hp.duplicate()
	sorted_expected.sort()
	_expect(
		enemy_count == expected_enemy_count,
		"%s preview should keep %d enemies visible, got %d" % [
			label,
			expected_enemy_count,
			enemy_count,
		]
	)
	_expect(
		lethal_count == expected_lethal_count,
		"%s preview should show %d lethal death marks, got %d" % [
			label,
			expected_lethal_count,
			lethal_count,
		]
	)
	_expect(
		hp_values == sorted_expected,
		"%s preview should retain committed HP baselines %s, got %s" % [
			label,
			sorted_expected,
			hp_values,
		]
	)


func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false


func _save_screenshot(
	viewport: SubViewport,
	path: String,
	expected_size: Vector2i
) -> void:
	await _settle()
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(
		image.get_size() == expected_size,
		"%s should be exactly %s, got %s" % [path, expected_size, image.get_size()]
	)
	_expect(
		_non_black_frame_coverage(image) >= 0.08,
		"%s should visibly render the combat scene" % path
	)
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)


func _non_black_frame_coverage(image: Image) -> float:
	var sampled: int = 0
	var non_black: int = 0
	for y: int in range(0, image.get_height(), 8):
		for x: int in range(0, image.get_width(), 8):
			sampled += 1
			var pixel: Color = image.get_pixel(x, y)
			if maxf(pixel.r, maxf(pixel.g, pixel.b)) > 0.015:
				non_black += 1
	return float(non_black) / float(maxi(1, sampled))


func _settle() -> void:
	for _frame: int in range(5):
		await process_frame
	RenderingServer.force_draw(true)
	await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
