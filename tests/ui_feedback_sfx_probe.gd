extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const SettingsStore = preload("res://scripts/settings_store.gd")

const OUTPUT_DIR: String = "user://ui_feedback_sfx_probe/1920x1080_ui100"

var _failed: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://ui_feedback_sfx_probe/progression.json")
	ProgressionStore.set_run_storage_path("user://ui_feedback_sfx_probe/current_run.save")
	SettingsStore.set_storage_path("user://ui_feedback_sfx_probe/settings.json")
	ProgressionStore.clear_saved_run()
	SettingsStore.clear_storage()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	_clear_probe_output(OUTPUT_DIR)
	if DisplayServer.get_name().to_lower() == "headless":
		_fail("UI feedback sound proof requires a real display renderer")
	else:
		await _configure_window()
		await _capture_feedback_surfaces()
	print(ProjectSettings.globalize_path(OUTPUT_DIR))
	print("TEST RESULT: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _configure_window() -> void:
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = Vector2i(1920, 1080)
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = Vector2i(1920, 1080)
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	await _settle()
	root.size = Vector2i(1920, 1080)
	await _settle()

func _capture_feedback_surfaces() -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_fail("Run scene should load for UI feedback sound proof")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var engine := RunEngine.new()

	var loadout_state: Dictionary = engine.create_new_run(6904, ProgressionStore.default_data())
	loadout_state["mode"] = "room"
	loadout_state["equipment_inventory"] = ["ward_kite"]
	loadout_state["magic_inventory"] = ["spark_dart"]
	loadout_state["attuned_magic_cards"] = ["pale_spark"]
	loadout_state["item_inventory"] = ["crimson_draught"]
	loadout_state["equipped_items"] = []
	instance.call("_load_run_state", loadout_state)
	await _settle()
	instance.call("_close_dialogue")
	instance.call("_open_character_overlay", "equipment")
	await _settle()
	await _save_root_screenshot("%s/equip_menu_before.png" % OUTPUT_DIR)
	var equip_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	await instance.call("_equip_equipment_from_overlay", "ward_kite")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == equip_before + 1, "Equipping Ward-Kite should play one feedback cue")
	_assert_sfx_entry(instance, 0.53, "Item equip")
	await _save_root_screenshot("%s/equip_menu_after.png" % OUTPUT_DIR)
	instance.call("_close_card_upgrade_overlay")
	await _settle()

	var reward_state: Dictionary = engine.create_new_run(31233, ProgressionStore.default_data())
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["spark_dart", "frostbolt", "threaded_path"],
		"heal_amount": RunEngine.REWARD_HEAL,
		"ember_amount": 0,
		"intro_pending": false
	}
	instance.call("_load_run_state", reward_state)
	await _settle()
	instance.call("_close_dialogue")
	await _save_root_screenshot("%s/card_reward_before.png" % OUTPUT_DIR)
	var reward_widget: Control = _reward_widget(instance, "spark_dart")
	_assert(reward_widget != null, "Spark Dart reward should be visible")
	if reward_widget != null:
		var reward_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
		create_timer(0.10).timeout.connect(_assert_sfx_entry.bind(instance, 1.30, "Reward collect"))
		create_timer(0.16).timeout.connect(_save_root_screenshot.bind("%s/card_reward_collect_mid.png" % OUTPUT_DIR))
		await instance.call("_on_reward_card_pressed", "spark_dart", reward_widget)
		_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == reward_before + 1, "Claiming Spark Dart should play one reward-collect cue")
	await _settle()

	var treasure_state: Dictionary = engine.create_new_run(44698, ProgressionStore.default_data())
	treasure_state["mode"] = "treasure"
	treasure_state["current_room"] = Vector2i(2, 1)
	treasure_state["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	var treasure_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_load_run_state", treasure_state)
	await _settle()
	instance.call("_close_dialogue")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == treasure_before + 1, "Showing relic choices should play one loot-open cue")
	_assert_sfx_entry(instance, 2.45, "Relic choices open")
	var refreshed_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	instance.call("_refresh_choice_bar")
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == refreshed_before, "Refreshing the same relic choices should stay silent")
	await _save_root_screenshot("%s/relic_choices_open.png" % OUTPUT_DIR)
	var source_rect: Rect2 = _first_relic_choice_rect(instance)
	var relic_before: int = _sfx_generation_total(instance.get("_sfx_players") as Array)
	create_timer(0.10).timeout.connect(_assert_sfx_entry.bind(instance, 1.30, "Relic reward collect"))
	create_timer(0.18).timeout.connect(_save_root_screenshot.bind("%s/relic_collect_mid.png" % OUTPUT_DIR))
	await instance.call("_on_relic_pressed", "iron_lung", source_rect)
	_assert(_sfx_generation_total(instance.get("_sfx_players") as Array) == relic_before + 1, "Claiming Iron Lung should play one reward-collect cue")
	await _settle()

	instance.queue_free()
	await process_frame

func _reward_widget(instance: Node, card_id: String) -> Control:
	var card_row: Node = instance.find_child("RewardCardRow", true, false)
	if card_row == null:
		return null
	for child: Node in card_row.get_children():
		if str(child.get_meta("reward_card_id", "")) != card_id:
			continue
		return child.find_child("CardWidget", true, false) as Control
	return null

func _first_relic_choice_rect(instance: Node) -> Rect2:
	var choice_bar: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	if choice_bar == null or choice_bar.get_child_count() == 0:
		_fail("Relic choice bar should contain a choice")
		return Rect2()
	var choice: Control = choice_bar.get_child(0) as Control
	return choice.get_global_rect() if choice != null else Rect2()

func _assert_sfx_entry(instance: Node, expected_length: float, label: String) -> void:
	for player_var: Variant in instance.get("_sfx_players") as Array:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player == null or player.stream == null:
			continue
		if absf(player.stream.get_length() - expected_length) > 0.02:
			continue
		_assert(player.bus == SettingsStore.UI_SFX_BUS, "%s should use the UI SFX bus" % label)
		return
	_fail("%s stream should be assigned to an SFX player" % label)

func _sfx_generation_total(players: Array) -> int:
	var total: int = 0
	for player_var: Variant in players:
		var player: AudioStreamPlayer = player_var as AudioStreamPlayer
		if player != null:
			total += int(player.get_meta("play_generation", 0))
	return total

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

func _save_root_screenshot(output_path: String) -> void:
	await RenderingServer.frame_post_draw
	var expected_size := Vector2i(1920, 1080)
	var image: Image = root.get_viewport().get_texture().get_image()
	if image == null:
		_fail("UI feedback sound proof should capture a renderer image")
		return
	var source_size: Vector2i = image.get_size()
	var scale_x: float = float(source_size.x) / float(expected_size.x)
	var scale_y: float = float(source_size.y) / float(expected_size.y)
	var valid_backing_size: bool = (
		is_equal_approx(scale_x, scale_y)
		and is_equal_approx(float(source_size.x) / float(source_size.y), float(expected_size.x) / float(expected_size.y))
	)
	if not valid_backing_size:
		_fail("UI feedback sound proof must preserve a 16:9 backing, got %s for %s" % [source_size, expected_size])
		return
	if source_size != expected_size:
		image.resize(expected_size.x, expected_size.y, Image.INTERPOLATE_LANCZOS)
	var error: Error = image.save_png(ProjectSettings.globalize_path(output_path))
	if error != OK:
		_fail("Could not save %s" % output_path)

func _clear_probe_output(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		dir.remove(file_name)

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _fail(message: String) -> void:
	_failed = true
	push_error(message)
