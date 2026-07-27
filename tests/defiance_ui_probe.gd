extends SceneTree

const CombatEngine = preload("res://scripts/combat_engine.gd")
const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://probes/defiance_balance_ui_v1"
const PROGRESSION_PATH: String = "user://defiance_ui_progression.json"
const RUN_PATH: String = "user://defiance_ui_run.save"
const SETTINGS_PATH: String = "user://defiance_ui_settings.json"
const PROGRESSION_LEVEL: int = 13

var _failures: Array[String]
var _screenshot_size: Vector2i


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	SettingsStore.set_storage_path(SETTINGS_PATH)
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["reduced_motion"] = true
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))

	var config: Dictionary = _requested_config()
	await _capture(config.get("size", Vector2i(1920, 1080)), float(config.get("scale", 1.0)), settings)
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	if _failures.is_empty():
		print("DEFIANCE UI PROBE: PASS")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("DEFIANCE UI PROBE: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture(screenshot_size: Vector2i, ui_scale: float, settings: Dictionary) -> void:
	_screenshot_size = screenshot_size
	var logical_size := Vector2i(
		maxi(1, roundi(float(screenshot_size.x) / ui_scale)),
		maxi(1, roundi(float(screenshot_size.y) / ui_scale))
	)
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_expect(packed != null, "Defiance UI proof should load the run scene")
	if packed == null:
		return
	var viewport := SubViewport.new()
	viewport.name = "DefianceProof_%dx%d_ui%d" % [screenshot_size.x, screenshot_size.y, roundi(ui_scale * 100.0)]
	viewport.size = screenshot_size
	if not is_equal_approx(ui_scale, 1.0):
		viewport.size_2d_override = logical_size
		viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)

	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.set("_settings", settings.duplicate(true))
	instance.call("_close_dialogue")
	var progression: Dictionary = ProgressionStore.default_data()
	progression["level"] = PROGRESSION_LEVEL
	progression = ProgressionStore.normalized_data(progression)
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(7272713 + screenshot_size.x, progression)
	instance.set("_progression", progression)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	await _settle()
	_expect(
		instance.get_viewport().get_visible_rect().size == Vector2(logical_size),
		"%s @ %d%% should expose logical viewport %s" % [screenshot_size, roundi(ui_scale * 100.0), logical_size]
	)
	var output_dir: String = "%s/%dx%d_ui%d" % [
		OUTPUT_DIR,
		screenshot_size.x,
		screenshot_size.y,
		roundi(ui_scale * 100.0),
	]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))

	instance.call("_open_character_overlay", "skills")
	await _settle()
	var dialog := instance.get("_upgrade_dialog") as Control
	var defiance_summary := dialog.find_child("ProgressionDefianceLabel", true, false) as Label if dialog != null else null
	_expect(dialog != null and dialog.is_visible_in_tree(), "Skills overlay should be visible for Defiance progression proof")
	_expect(
		defiance_summary != null
		and defiance_summary.text.contains("DEFIANCE")
		and defiance_summary.text.contains("3/3")
		and (defiance_summary.text.contains("NEXT 16") or defiance_summary.text.contains("L16")),
		"Skills summary should show three charges and the level-16 milestone"
	)
	_expect_inside(dialog, logical_size, "Skills overlay")
	await _save_screenshot(viewport, "%s/01_skills_defiance_summary.png" % output_dir)
	instance.call("_close_card_upgrade_overlay")
	await _settle()

	var combat := CombatEngine.new()
	var layout: Dictionary = _combat_layout()
	var combat_state: Dictionary = combat.create_combat(7272813 + screenshot_size.y, layout, {
		"hp": 5,
		"max_hp": 24,
		"deck_cards": ["quick_stab", "brace"],
		"hand_size": 2,
		"defiance_capacity": 3,
		"defiance_remaining": 3,
	})
	var combat_run: Dictionary = run_state.duplicate(true)
	combat_run["mode"] = "combat"
	combat_run["current_room"] = layout.get("coord", Vector2i(1, 0))
	combat_run["current_room_layout"] = layout.duplicate(true)
	combat_run["combat_state"] = combat_state.duplicate(true)
	combat_run["progression"] = progression.duplicate(true)
	instance.set("_progression", progression)
	instance.call("_load_run_state", combat_run)
	instance.call("_close_dialogue")
	await _settle()
	_assert_defiance_badge(instance, logical_size, 3, 3, "ready")
	await _save_screenshot(viewport, "%s/02_combat_defiance_ready.png" % output_dir)

	var triggered_combat: Dictionary = combat_state.duplicate(true)
	triggered_combat[RunEngine.DEFIANCE_REMAINING_KEY] = 2
	triggered_combat["defiance_event_revision"] = 1
	triggered_combat["defiance_events"] = [{
		"revision": 1,
		"turn": int(triggered_combat.get("turn", 1)),
		"cause": "enemy_attack",
		"lethal_hp_loss": 5,
		"restored_hp": 6,
		"charges_before": 3,
		"charges_after": 2,
	}]
	var triggered_player: Dictionary = (triggered_combat.get("player", {}) as Dictionary).duplicate(true)
	triggered_player["hp"] = 6
	triggered_combat["player"] = triggered_player
	var triggered_run: Dictionary = run_engine.set_combat_state(combat_run, triggered_combat)
	instance.set("_combat_state", triggered_combat)
	instance.set("_run_state", triggered_run)
	instance.call("_refresh_ui")
	await process_frame
	await process_frame
	_assert_defiance_badge(instance, logical_size, 2, 3, "post-trigger")
	await _save_screenshot(viewport, "%s/03_combat_defiance_post_trigger.png" % output_dir)

	var depleted_combat: Dictionary = triggered_combat.duplicate(true)
	depleted_combat[RunEngine.DEFIANCE_REMAINING_KEY] = 0
	var depleted_run: Dictionary = run_engine.set_combat_state(combat_run, depleted_combat)
	instance.set("_combat_state", depleted_combat)
	instance.set("_run_state", depleted_run)
	instance.call("_refresh_ui")
	await _settle()
	_assert_defiance_badge(instance, logical_size, 0, 3, "depleted")
	await _save_screenshot(viewport, "%s/04_combat_defiance_depleted.png" % output_dir)

	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame


func _assert_defiance_badge(
	instance: Node,
	logical_size: Vector2i,
	remaining: int,
	capacity: int,
	state_label: String
) -> void:
	var badge := instance.get("_defiance_badge") as Control
	var count := badge.find_child("DefianceCount", true, false) as Label if badge != null else null
	_expect(badge != null and badge.is_visible_in_tree(), "%s Defiance badge should remain visible" % state_label)
	_expect(
		badge != null
		and int(badge.get_meta("defiance_remaining", -1)) == remaining
		and int(badge.get_meta("defiance_capacity", -1)) == capacity
		and count != null
		and count.text == "%d/%d" % [remaining, capacity],
		"%s Defiance badge should show %d/%d as icon plus count" % [state_label, remaining, capacity]
	)
	_expect(
		badge != null
		and badge.tooltip_text.contains("restore 25% max health")
		and badge.tooltip_text.contains("does not refill"),
		"%s Defiance badge should retain its exact recovery and no-refill rules" % state_label
	)
	_expect_inside(badge, logical_size, "%s Defiance badge" % state_label, 0.0)


func _combat_layout() -> Dictionary:
	var grid: Array = []
	for y: int in range(7):
		var row: Array = []
		for x: int in range(9):
			row.append("wall" if x == 0 or x == 8 or y == 0 or y == 6 else "stone")
		grid.append(row)
	return {
		"name": "Last Stand",
		"coord": Vector2i(1, 0),
		"depth": 4,
		"type": "combat",
		"element": "fire",
		"grid": grid,
		"player_start": Vector2i(2, 3),
		"enemies": [{
			"id": "defiance_probe_enemy",
			"type": "crawler",
			"name": "Tunnel Crawler",
			"pos": Vector2i(6, 3),
			"hp": 14,
			"max_hp": 14,
			"base_initiative": 9,
		}],
		"traps": [],
		"loot": [],
		"terrain": [],
	}


func _requested_config() -> Dictionary:
	var specification: String = OS.get_environment("LABYRINTH_DEFIANCE_PROBE_CONFIG").strip_edges().to_lower()
	var arguments: PackedStringArray = OS.get_cmdline_user_args()
	var config_index: int = arguments.find("--config")
	if specification.is_empty() and config_index >= 0 and config_index + 1 < arguments.size():
		specification = arguments[config_index + 1].strip_edges().to_lower()
	if specification.is_empty():
		specification = "1920x1080@100"
	var scale_parts: PackedStringArray = specification.split("@", false, 1)
	var size_parts: PackedStringArray = scale_parts[0].split("x", false, 1)
	if size_parts.size() != 2:
		_failures.append("Invalid --config size: %s" % specification)
		return {}
	var width: int = int(size_parts[0])
	var height: int = int(size_parts[1])
	var scale_percent: int = int(scale_parts[1]) if scale_parts.size() == 2 else 100
	if width <= 0 or height <= 0 or scale_percent <= 0:
		_failures.append("Invalid --config value: %s" % specification)
		return {}
	return {"size": Vector2i(width, height), "scale": float(scale_percent) / 100.0}


func _save_screenshot(viewport: SubViewport, path: String) -> void:
	await process_frame
	RenderingServer.force_draw(true)
	await process_frame
	var image: Image = viewport.get_texture().get_image()
	_expect(image != null and not image.is_empty(), "%s should render a non-empty frame" % path)
	if image == null or image.is_empty():
		return
	_expect(image.get_size() == _screenshot_size, "%s should be exactly %s, got %s" % [path, _screenshot_size, image.get_size()])
	_expect(image.save_png(path) == OK, "%s should save successfully" % path)


func _expect_inside(control: Control, logical_size: Vector2i, label: String, margin: float = 8.0) -> void:
	if control == null:
		return
	var safe_rect := Rect2(Vector2.ONE * margin, Vector2(logical_size) - Vector2.ONE * margin * 2.0)
	_expect(safe_rect.encloses(control.get_global_rect()), "%s should fit inside %s: %s" % [label, logical_size, control.get_global_rect()])


func _settle() -> void:
	for _frame: int in range(5):
		await process_frame


func _expect(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
