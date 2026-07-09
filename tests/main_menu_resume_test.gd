extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const AssetLoader = preload("res://scripts/asset_loader.gd")

const PROGRESSION_PATH: String = "user://main_menu_resume_test_progression.json"
const RUN_PATH: String = "user://main_menu_resume_test_run.save"

var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(PROGRESSION_PATH)
	ProgressionStore.set_run_storage_path(RUN_PATH)
	_cleanup_storage()
	await _test_valid_save_summary_and_replacement_gate()
	await _test_no_save_hides_summary()
	await _test_corrupt_save_is_hidden_and_recoverable()
	_cleanup_storage()
	await process_frame
	await process_frame
	var steam_service: Node = root.get_node_or_null("SteamService")
	if steam_service != null:
		root.remove_child(steam_service)
		steam_service.free()
	AssetLoader._audio_cache.clear()
	if _failures.is_empty():
		print("TEST RESULT: PASS — main menu resume safety")
		quit(0)
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL — %d main menu resume safety failure(s)" % _failures.size())
	quit(1)

func _test_valid_save_summary_and_replacement_gate() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 91
	_assert(ProgressionStore.save_data(progression), "Valid-save fixture should write progression")
	var run_state: Dictionary = _valid_combat_run(progression)
	_assert(ProgressionStore.save_run_state(run_state), "Valid-save fixture should write the run")
	var bytes_before: PackedByteArray = _run_file_bytes()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var replacement_location: Label = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementLocation")
	var replacement_stats: Label = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementStats")
	var replacement_cancel: Button = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementCancelButton")
	var replacement_confirm: Button = instance.get_node("ReplacementPanel/ReplacementMargin/ReplacementVBox/ReplacementActions/ReplacementConfirmButton")
	_assert(resume_panel.visible, "A valid save should show the resume card")
	_assert(resume_location.text == "DEPTH 4  ·  IN COMBAT", "Resume card should show the saved depth and mode")
	_assert(resume_stats.text == "HP 175 / 260  ·  HELD 74 EMBERS", "Resume card should show accurate saved HP and explicitly identify held embers")
	_assert(continue_button.text == "Continue Run" and not continue_button.disabled, "Continue should become the primary enabled action for a valid save")
	var continue_style: StyleBoxFlat = continue_button.get_theme_stylebox("normal") as StyleBoxFlat
	var start_style: StyleBoxFlat = start_button.get_theme_stylebox("normal") as StyleBoxFlat
	_assert(continue_style != null and start_style != null and continue_style.bg_color != start_style.bg_color, "Primary Continue should be visually distinct from New Game")
	_assert(_run_file_bytes() == bytes_before, "Rendering the valid-save summary must not rewrite the run file")

	start_button.pressed.emit()
	await process_frame
	_assert(replacement_panel.visible and not resume_panel.visible, "New Game should open replacement confirmation instead of replacing a valid save")
	_assert(continue_button.disabled and start_button.disabled, "Replacement confirmation should lock the background menu actions")
	_assert(replacement_location.text == resume_location.text and replacement_stats.text == resume_stats.text, "Replacement confirmation should repeat the exact saved-run summary")
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() == bytes_before, "Opening replacement confirmation must not mutate or clear the save")

	replacement_cancel.pressed.emit()
	await process_frame
	_assert(not replacement_panel.visible and resume_panel.visible, "Cancel should return to the resume card")
	_assert(ProgressionStore.has_saved_run() and _run_file_bytes() == bytes_before, "Cancel should leave the saved run byte-for-byte unchanged")

	start_button.pressed.emit()
	await process_frame
	_stop_menu_music(instance)
	root.remove_child(instance)
	replacement_confirm.pressed.emit()
	_assert(not ProgressionStore.has_saved_run(), "Explicit Replace Run confirmation should clear the saved run")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Confirmed replacement should preserve the existing New Game ember-reset semantic")
	instance.free()
	await process_frame

func _test_no_save_hides_summary() -> void:
	ProgressionStore.clear_saved_run()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	_assert(continue_button.disabled and continue_button.text == "Continue", "No-save state should keep Continue secondary and disabled")
	_assert(not resume_panel.visible and not replacement_panel.visible, "No-save state should hide all saved-run context panels")
	_assert(resume_location.text.is_empty() and resume_stats.text.is_empty(), "No-save state should clear summary text instead of retaining stale data")
	_stop_menu_music(instance)
	instance.queue_free()
	await process_frame

func _test_corrupt_save_is_hidden_and_recoverable() -> void:
	var progression: Dictionary = ProgressionStore.default_data()
	progression["embers"] = 33
	_assert(ProgressionStore.save_data(progression), "Corrupt-save fixture should write progression")
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.WRITE)
	_assert(file != null, "Corrupt-save fixture should open the run path")
	if file == null:
		return
	file.store_var(_dictionary_shaped_corrupt_run(), false)
	file.close()
	var bytes_before: PackedByteArray = _run_file_bytes()
	var instance: Node = await _instantiate_menu()
	if instance == null:
		return
	var continue_button: Button = instance.get_node("MenuColumn/ContinueButton")
	var start_button: Button = instance.get_node("MenuColumn/StartButton")
	var resume_panel: PanelContainer = instance.get_node("ResumePanel")
	var replacement_panel: PanelContainer = instance.get_node("ReplacementPanel")
	var resume_location: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeLocation")
	var resume_stats: Label = instance.get_node("ResumePanel/ResumeMargin/ResumeVBox/ResumeStats")
	_assert(continue_button.disabled and not resume_panel.visible and not replacement_panel.visible, "A dictionary-shaped corrupt save should not expose Continue or saved-run context")
	_assert(resume_location.text.is_empty() and resume_stats.text.is_empty(), "A corrupt save should not leak stale summary text")
	_assert(_run_file_bytes() == bytes_before, "Rendering a corrupt-save state must not rewrite or clear the bad file")
	_stop_menu_music(instance)
	root.remove_child(instance)
	start_button.pressed.emit()
	_assert(not ProgressionStore.has_saved_run(), "New Game should recover from a corrupt save by clearing it")
	_assert(int(ProgressionStore.load_data().get("embers", -1)) == 0, "Corrupt-save recovery should use the existing New Game replacement semantic")
	instance.free()
	await process_frame

func _valid_combat_run(progression: Dictionary) -> Dictionary:
	var run_state: Dictionary = RunEngine.new().create_debug_boss_run(progression)
	run_state["debug_boss_run"] = false
	run_state["player_hp"] = 175
	run_state["player_max_hp"] = 260
	run_state["held_embers"] = 74
	run_state["unbanked_embers"] = 74
	var combat_state: Dictionary = (run_state.get("combat_state", {}) as Dictionary).duplicate(true)
	var player: Dictionary = (combat_state.get("player", {}) as Dictionary).duplicate(true)
	player["hp"] = 175
	player["max_hp"] = 260
	combat_state["player"] = player
	run_state["combat_state"] = combat_state
	return run_state

func _dictionary_shaped_corrupt_run() -> Dictionary:
	return {
		"seed": 9081,
		"mode": "combat",
		"current_room": Vector2i.ZERO,
		"current_room_layout": {"width": 9, "height": 9},
		"rooms": {"0,0": {"coord": Vector2i.ZERO, "depth": 0, "type": "combat"}},
		"deck_cards": ["quick_stab"],
		"player_hp": 50,
		"player_max_hp": 100,
		"held_embers": 10,
		"unbanked_embers": 10,
		"combat_state": {}
	}

func _instantiate_menu() -> Node:
	var packed: PackedScene = load("res://scenes/main_menu.tscn")
	_assert(packed != null, "Main menu scene should load")
	if packed == null:
		return null
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	return instance

func _run_file_bytes() -> PackedByteArray:
	var file: FileAccess = FileAccess.open(RUN_PATH, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes: PackedByteArray = file.get_buffer(file.get_length())
	file.close()
	return bytes

func _cleanup_storage() -> void:
	ProgressionStore.clear_saved_run()
	var progression_path: String = ProjectSettings.globalize_path(PROGRESSION_PATH)
	if FileAccess.file_exists(PROGRESSION_PATH):
		DirAccess.remove_absolute(progression_path)

func _stop_menu_music(instance: Node) -> void:
	var music_player: AudioStreamPlayer = instance.get_node_or_null("MusicPlayer") as AudioStreamPlayer
	if music_player == null:
		return
	music_player.stop()
	music_player.stream = null

func _assert(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
