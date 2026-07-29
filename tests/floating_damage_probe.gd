extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const FloatingCombatText = preload("res://scripts/floating_combat_text.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/floating_damage_v1"
const PROGRESSION_PATH: String = "user://floating_damage_probe_progression.json"
const RUN_PATH: String = "user://floating_damage_probe_run.save"
const SETTINGS_PATH: String = "user://floating_damage_probe_settings.json"

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Floating damage proof should load the run scene")
	if packed != null:
		await _capture_config(packed, {"size": Vector2i(1920, 1080), "scale": 1.0})
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("FLOATING DAMAGE PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("FLOATING DAMAGE PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_config(packed: PackedScene, config: Dictionary) -> void:
	var screenshot_size: Vector2i = config.get("size", Vector2i(1920, 1080))
	var ui_scale: float = float(config.get("scale", 1.0))
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = ui_scale
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)

	var viewport := SubViewport.new()
	viewport.name = "FloatingDamage_%dx%d_ui%d" % [
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

	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	instance.set("_settings", settings.duplicate(true))
	var combat_state: Dictionary = _install_combat_fixture(instance)
	await _settle()
	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(logical_size),
		"%s @ %d%% should expose logical viewport %s" % [
			screenshot_size,
			roundi(ui_scale * 100.0),
			logical_size,
		]
	)
	_hide_log(instance)

	await _capture_damage_state(
		instance,
		viewport,
		combat_state,
		0.0,
		false,
		false,
		"%s/impact_peak.png" % output_dir,
		screenshot_size
	)
	await _capture_damage_state(
		instance,
		viewport,
		combat_state,
		0.32,
		false,
		true,
		"%s/settled_multi_hit.png" % output_dir,
		screenshot_size
	)
	await _capture_effect_state(
		instance,
		viewport,
		combat_state,
		"%s/effect_impact.png" % output_dir,
		screenshot_size
	)
	await _capture_damage_state(
		instance,
		viewport,
		combat_state,
		0.76,
		false,
		false,
		"%s/late_linger.png" % output_dir,
		screenshot_size
	)
	await _capture_damage_state(
		instance,
		viewport,
		combat_state,
		0.52,
		true,
		true,
		"%s/reduced_motion_hold.png" % output_dir,
		screenshot_size
	)

	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame


func _capture_damage_state(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	progress: float,
	reduced_motion: bool,
	multi_hit: bool,
	path: String,
	expected_size: Vector2i
) -> void:
	var settings: Dictionary = (instance.get("_settings") as Dictionary).duplicate(true)
	settings["reduced_motion"] = reduced_motion
	instance.set("_settings", settings)
	var base_entries: Array[Dictionary] = [
		FloatingCombatText.damage_entry(
			Vector2i(5, 3),
			"-13",
			Color("f39779")
		),
	]
	var impact_keys: Array[String] = ["enemy_2"]
	if multi_hit:
		base_entries.append(FloatingCombatText.damage_entry(
			Vector2i(4, 2),
			"-7",
			Color("f39779")
		))
		base_entries.append(FloatingCombatText.damage_entry(
			Vector2i(6, 4),
			"-21",
			Color("f39779")
		))
		base_entries.append({
			"tile": Vector2i(5, 3),
			"text": "-4 B",
			"color": Color("90d9ff"),
			"offset": 0.0,
			"x_offset": FloatingCombatText.COMPANION_X_OFFSET,
			"width": FloatingCombatText.COMPANION_WIDTH,
		})
		impact_keys = ["enemy_1", "enemy_2", "enemy_3"]
	var animated_entries: Array[Dictionary] = []
	for entry: Dictionary in base_entries:
		animated_entries.append(FloatingCombatText.animate_entry(entry, progress, reduced_motion))
	var lead_damage: Dictionary = animated_entries[0]
	if reduced_motion:
		var comparison: Dictionary = FloatingCombatText.animate_entry(base_entries[0], 0.82, true)
		_expect(
			int(lead_damage.get("font_size", 0)) == int(comparison.get("font_size", -1))
			and is_equal_approx(float(lead_damage.get("rise", -1.0)), float(comparison.get("rise", -2.0))),
			"Reduced-motion proof should hold one stable damage-number composition"
		)
	else:
		_expect(
			int(lead_damage.get("font_size", 0)) >= FloatingCombatText.DAMAGE_EXIT_FONT_SIZE,
			"Normal damage proof should retain a readable type floor"
		)
	instance.call("_render_board_state", combat_state, {
		"focus_actor_keys": impact_keys,
		"focus_actor_color": Color("f08c53"),
		"impact_actor_keys": impact_keys,
		"impact_progress": progress,
		"floating_texts": animated_entries,
	})
	await _settle()
	var board: Control = instance.get("board_view") as Control
	_expect(board != null, "%s should expose the live combat board" % path)
	if board != null:
		var rendered_entries: Array = (board.get("presentation") as Dictionary).get("floating_texts", []) as Array
		_expect(
			rendered_entries.size() == animated_entries.size(),
			"%s should render every requested damage and defense float" % path
		)
	await _save_screenshot(viewport, path, expected_size)


func _capture_effect_state(
	instance: Node,
	viewport: SubViewport,
	combat_state: Dictionary,
	path: String,
	expected_size: Vector2i
) -> void:
	var base_entries: Array[Dictionary] = [
		{
			"tile": Vector2i(3, 3),
			"text": "+8",
			"color": Color("90d9ff"),
			"offset": 8.0,
		},
		{
			"tile": Vector2i(4, 2),
			"text": "Bleed",
			"color": Color("ff9a7e"),
			"offset": -8.0,
		},
		{
			"tile": Vector2i(6, 4),
			"text": "+5",
			"color": Color("9ee27e"),
			"offset": 8.0,
		},
	]
	var animated_entries: Array[Dictionary] = []
	for entry: Dictionary in base_entries:
		animated_entries.append(FloatingCombatText.animate_entry(entry, 0.0, false))
	_expect(
		animated_entries.all(func(entry: Dictionary) -> bool: return FloatingCombatText.is_effect_entry(entry) and int(entry.get("font_size", 0)) >= FloatingCombatText.EFFECT_PEAK_FONT_SIZE),
		"Defense, status, and healing proof entries should all use the shared effect-popup impact"
	)
	instance.call("_render_board_state", combat_state, {
		"focus_actor_keys": ["player", "enemy_1", "enemy_3"],
		"focus_actor_color": Color("f08c53"),
		"impact_actor_keys": ["player", "enemy_1", "enemy_3"],
		"impact_progress": 0.0,
		"floating_texts": animated_entries,
	})
	await _settle()
	await _save_screenshot(viewport, path, expected_size)


func _install_combat_fixture(instance: Node) -> Dictionary:
	instance.call("_cancel_drag_play")
	instance.call("_reset_card_resolution")
	var layout: Dictionary = _combat_layout()
	var combat := CombatEngine.new()
	var combat_state: Dictionary = combat.create_combat(
		91370,
		layout,
		{
			"hp": 24,
			"max_hp": 24,
			"deck_cards": ["quick_stab", "brace", "whirlwind_slash"],
			"relics": [],
			"hand_size": 3,
			"heal_bonus": 0,
		}
	)
	var deck: Dictionary = (combat_state.get("deck", {}) as Dictionary).duplicate(true)
	deck["hand"] = ["quick_stab", "brace", "whirlwind_slash"]
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
	return combat_state


func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	return {
		"name": "Cinder Crossing",
		"coord": Vector2i(4, 3),
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": Vector2i(3, 3),
		"enemies": [
			_enemy(1, Vector2i(4, 2), 30),
			_enemy(2, Vector2i(5, 3), 40),
			_enemy(3, Vector2i(6, 4), 50),
		],
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


func _hide_log(instance: Node) -> void:
	var log_overlay: Control = instance.get("log_overlay") as Control
	if log_overlay != null:
		log_overlay.visible = false


func _save_screenshot(viewport: SubViewport, path: String, expected_size: Vector2i) -> void:
	await _settle()
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == expected_size, "%s should be exactly %s, got %s" % [path, expected_size, image.get_size()])
	_expect(_non_black_frame_coverage(image) >= 0.08, "%s should visibly render the combat scene" % path)
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
