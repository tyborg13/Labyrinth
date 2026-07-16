extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngineScript = preload("res://scripts/run_engine.gd")
const UiTypography = preload("res://scripts/ui_typography.gd")

const DEFAULT_SIZE := Vector2i(1280, 720)

var _viewport_size: Vector2i = DEFAULT_SIZE
var _phase: String = "after"
var _validate_layout: bool = true
var _character_only: bool = false
var _failures: Array[String] = []

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_parse_args()
	ProgressionStore.set_storage_path("user://labyrinth_progression_utility_ui_probe.json")
	ProgressionStore.set_run_storage_path("user://labyrinth_run_utility_ui_probe.save")
	ProgressionStore.clear_saved_run()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_size = _viewport_size
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.size = _viewport_size
	await process_frame
	await process_frame
	root.size = _viewport_size
	await process_frame
	print("Utility UI probe viewport=%s window=%s content_scale=%s" % [root.get_viewport().get_visible_rect().size, root.size, root.content_scale_size])
	var output_dir: String = "user://utility_ui_layout/%s_%dx%d" % [_phase, _viewport_size.x, _viewport_size.y]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	_clear_probe_output(output_dir)
	await _capture_targeted_surfaces(output_dir)
	if not _failures.is_empty():
		for failure: String in _failures:
			push_error(failure)
		print("TEST RESULT: FAIL (%d layout failures)" % _failures.size())
		quit(1)
		return
	print(ProjectSettings.globalize_path(output_dir))
	print("TEST RESULT: PASS")
	quit()

func _parse_args() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--width="):
			_viewport_size.x = maxi(640, int(arg.trim_prefix("--width=")))
		elif arg.begins_with("--height="):
			_viewport_size.y = maxi(480, int(arg.trim_prefix("--height=")))
		elif arg.begins_with("--phase="):
			_phase = arg.trim_prefix("--phase=").strip_edges()
		elif arg == "--no-validate":
			_validate_layout = false
		elif arg == "--character-only":
			_character_only = true

func _capture_targeted_surfaces(output_dir: String) -> void:
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	if packed == null:
		_failures.append("Run scene should load for utility UI layout coverage")
		return
	var instance: Node = packed.instantiate()
	root.add_child(instance)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	var run_engine = RunEngineScript.new()
	var base_state: Dictionary = run_engine.create_new_run(123, ProgressionStore.default_data())
	instance.call("_load_run_state", base_state)
	await process_frame
	await process_frame
	instance.call("_close_dialogue")
	await _settle()

	instance.call("_open_large_map")
	await _settle()
	await _capture(output_dir, "large_map")
	_check_inside_viewport(instance.get("_large_map_dialog") as Control, "Large map dialog", UiTypography.SAFE_MARGIN)
	instance.call("_close_large_map")

	instance.call("_open_character_stats_overlay")
	await _settle()
	await _capture(output_dir, "character_stats")
	var character_dialog: Control = instance.get("_upgrade_dialog") as Control
	var stats_dialog_rect: Rect2 = character_dialog.get_global_rect() if character_dialog != null else Rect2()
	_check_inside_viewport(character_dialog, "Character dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(character_dialog, "Character dialog")
	_print_dialog_metrics(instance, "stats")
	instance.call("_switch_character_overlay_mode", "equipment")
	await _settle()
	await _capture(output_dir, "character_gear")
	_check_inside_viewport(character_dialog, "Character gear dialog", UiTypography.SAFE_MARGIN)
	_check_same_rect(character_dialog, stats_dialog_rect, "Character gear dialog")
	_check_character_subpanels(character_dialog, ["EquipmentLoadoutPanel", "EquipmentInventoryPanel", "CurrentDeckPanel"], "Gear")
	_print_dialog_metrics(instance, "gear")
	instance.call("_switch_character_overlay_mode", "magic")
	await _settle()
	await _capture(output_dir, "character_magic")
	_check_inside_viewport(character_dialog, "Character magic dialog", UiTypography.SAFE_MARGIN)
	_check_same_rect(character_dialog, stats_dialog_rect, "Character magic dialog")
	_check_character_subpanels(character_dialog, ["MagicAttunedPanel", "MagicInventoryPanel", "CurrentDeckPanel"], "Magic")
	_print_dialog_metrics(instance, "magic")
	instance.call("_close_card_upgrade_overlay")
	if _character_only:
		instance.queue_free()
		await process_frame
		return

	instance.set("_progression_overlay_mode", "level_up")
	instance.call("_rebuild_progression_overlay")
	var progression_scrim: Control = instance.get("_upgrade_scrim") as Control
	if progression_scrim != null:
		progression_scrim.visible = true
	await _settle()
	await _capture(output_dir, "progression_level_up")
	_check_inside_viewport(instance.get("_upgrade_dialog") as Control, "Progression dialog", UiTypography.SAFE_MARGIN)
	instance.call("_close_card_upgrade_overlay")

	instance.call("_open_grimoire_overlay")
	await _settle()
	instance.call("_on_grimoire_entry_pressed", "magick:pale_spark")
	await _settle()
	await _capture(output_dir, "grimoire")
	_check_inside_viewport(instance.get("_grimoire_dialog") as Control, "Grimoire dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(instance.get("_grimoire_dialog") as Control, "Grimoire dialog")
	instance.call("_close_grimoire_overlay")

	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, base_state)
	if combat_coord == Vector2i(999, 999):
		_failures.append("Utility UI probe needs an available combat room")
	else:
		await instance.call("_on_map_view_room_selected", combat_coord)
		await _settle()
		await _capture(output_dir, "pre_battle")
		_check_inside_viewport(instance.get("_pre_battle_panel") as Control, "Pre-battle dialog", UiTypography.SPACE_LARGE)
		var pre_battle_scrim: Control = instance.get("_pre_battle_scrim") as Control
		if pre_battle_scrim != null:
			pre_battle_scrim.visible = false

	instance.call("_open_menu_overlay")
	await _settle()
	await _capture(output_dir, "pause")
	_check_inside_viewport(instance.get("_menu_dialog") as Control, "Pause dialog", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(instance.get("_menu_dialog") as Control, "Pause dialog")
	instance.call("_close_menu_overlay")

	var reward_state: Dictionary = base_state.duplicate(true)
	reward_state["mode"] = "reward"
	reward_state["pending_reward"] = {
		"cards": ["quick_stab", "bone_dart", "sidestep_slash", "patch_up"],
		"heal_amount": RunEngineScript.REWARD_HEAL,
		"ember_amount": 0
	}
	instance.call("_load_run_state", reward_state)
	await _settle()
	await _capture(output_dir, "reward")
	_check_reward_choices(instance)

	var victory_state: Dictionary = _state_for_room(run_engine, base_state, Vector2i(8, 0), "victory")
	victory_state["victory"] = true
	victory_state["held_embers"] = 42
	instance.call("_load_run_state", victory_state)
	await _settle()
	var run_end_recap: Control = instance.get("_run_end_recap") as Control
	if run_end_recap != null:
		run_end_recap.call("seek_presentation", 0.62)
	await _settle()
	await _capture(output_dir, "victory")
	var victory_panel: Control = run_end_recap.find_child("OutcomeRecap", true, false) as Control if run_end_recap != null else null
	_check_inside_viewport(victory_panel, "Victory recap", UiTypography.SAFE_MARGIN)
	_check_descendant_minimum_font(victory_panel, "Victory recap")

	var defeat_state: Dictionary = _state_for_room(run_engine, base_state, Vector2i(1, 0), "defeat")
	defeat_state["player_hp"] = 0
	defeat_state["held_embers"] = 23
	instance.call("_load_run_state", defeat_state)
	await _settle()
	run_end_recap = instance.get("_run_end_recap") as Control
	if run_end_recap != null:
		run_end_recap.call("seek_presentation", 0.62)
	await _settle()
	await _capture(output_dir, "defeat")
	var defeat_panel: Control = run_end_recap.find_child("OutcomeRecap", true, false) as Control if run_end_recap != null else null
	_check_inside_viewport(defeat_panel, "Defeat recap", UiTypography.SAFE_MARGIN)
	_check_inside_viewport(run_end_recap.find_child("NewRunButton", true, false) as Control if run_end_recap != null else null, "Defeat new-run action")
	_check_inside_viewport(run_end_recap.find_child("MainMenuButton", true, false) as Control if run_end_recap != null else null, "Defeat main-menu action")

	instance.queue_free()
	await process_frame

func _settle() -> void:
	await process_frame
	await process_frame
	await create_timer(0.08).timeout
	await process_frame

func _capture(output_dir: String, surface: String) -> void:
	var image: Image = root.get_viewport().get_texture().get_image()
	image.save_png("%s/%s.png" % [output_dir, surface])

func _first_available_combat_coord(run_engine, state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(state):
		var preview_state: Dictionary = run_engine.move_to_room(state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat":
			return coord
	return Vector2i(999, 999)

func _state_for_room(run_engine, source_state: Dictionary, coord: Vector2i, mode: String) -> Dictionary:
	var state: Dictionary = source_state.duplicate(true)
	var room: Dictionary = run_engine.room_metadata(state, coord).duplicate(true)
	room["revealed"] = true
	room["visited"] = true
	room["cleared"] = mode == "room"
	var rooms: Dictionary = (state.get("rooms", {}) as Dictionary).duplicate(true)
	rooms["%d,%d" % [coord.x, coord.y]] = room
	state["rooms"] = rooms
	state["current_room"] = coord
	state["current_room_layout"] = run_engine.call("_display_layout_for_room", int(state.get("seed", 0)), room, Vector2i(1, 0))
	state["mode"] = mode
	state["combat_state"] = {}
	state["pending_reward"] = {}
	state["pending_relics"] = []
	return state

func _check_inside_viewport(control: Control, label: String, safe_margin: float = 0.0) -> void:
	if not _validate_layout:
		return
	if control == null:
		_failures.append("%s should exist" % label)
		return
	var rect: Rect2 = control.get_global_rect()
	var viewport_size: Vector2 = root.get_viewport().get_visible_rect().size
	var viewport_rect := Rect2(Vector2.ONE * safe_margin, viewport_size - Vector2.ONE * safe_margin * 2.0)
	if rect.position.x < -1.0 or rect.position.y < -1.0 or rect.end.x > viewport_rect.end.x + 1.0 or rect.end.y > viewport_rect.end.y + 1.0:
		_failures.append("%s should fit viewport; rect=%s viewport=%s" % [label, rect, viewport_rect])

func _check_same_rect(control: Control, expected: Rect2, label: String) -> void:
	if not _validate_layout:
		return
	if control == null:
		_failures.append("%s should exist" % label)
		return
	var actual: Rect2 = control.get_global_rect()
	if not actual.position.is_equal_approx(expected.position) or not actual.size.is_equal_approx(expected.size):
		_failures.append("%s should keep the Stats bounds; actual=%s expected=%s" % [label, actual, expected])

func _check_character_subpanels(dialog: Control, panel_names: Array[String], label: String) -> void:
	if not _validate_layout or dialog == null:
		return
	var body_frame: Control = dialog.find_child("CharacterBodyFrame", true, false) as Control
	if body_frame == null:
		_failures.append("%s body frame should exist" % label)
		return
	var frame_rect: Rect2 = body_frame.get_global_rect()
	for panel_name: String in panel_names:
		var panel: Control = body_frame.find_child(panel_name, true, false) as Control
		if panel == null:
			_failures.append("%s subpanel %s should exist" % [label, panel_name])
			continue
		var panel_rect: Rect2 = panel.get_global_rect()
		if not frame_rect.encloses(panel_rect):
			_failures.append("%s subpanel %s should fit its body frame; panel=%s frame=%s" % [label, panel_name, panel_rect, frame_rect])

func _check_descendant_minimum_font(root_control: Control, label: String) -> void:
	if not _validate_layout or root_control == null:
		return
	for node: Node in root_control.find_children("*", "Label", true, false):
		var text_label := node as Label
		if text_label == null or text_label.text.strip_edges().is_empty():
			continue
		var font_size: int = text_label.get_theme_font_size("font_size")
		if font_size < 14:
			_failures.append("%s label '%s' should use at least the caption floor; got %d" % [label, text_label.text.left(28), font_size])

func _check_reward_choices(instance: Node) -> void:
	if not _validate_layout:
		return
	var reward_bar: Control = instance.get("_relic_choice_bar") as Control
	if reward_bar == null:
		_failures.append("Reward choices should exist")
		return
	for child: Node in reward_bar.get_children():
		if child is Control:
			_check_inside_viewport(child as Control, "Reward choice")

func _find_control_with_text(parent: Control, text: String) -> Control:
	if parent == null:
		return null
	for node: Node in parent.find_children("*", "Control", true, false):
		if node is Label and (node as Label).text == text:
			return node as Control
		if node is Button and (node as Button).text == text:
			return node as Control
	return null

func _print_dialog_metrics(instance: Node, mode: String) -> void:
	var dialog: Control = instance.get("_upgrade_dialog") as Control
	if dialog == null:
		return
	print("Character %s custom=%s actual=%s combined=%s" % [mode, dialog.custom_minimum_size, dialog.size, dialog.get_combined_minimum_size()])

func _clear_probe_output(output_dir: String) -> void:
	_clear_probe_output_absolute(ProjectSettings.globalize_path(output_dir))

func _clear_probe_output_absolute(absolute_dir: String) -> void:
	var dir := DirAccess.open(absolute_dir)
	if dir == null:
		return
	dir.list_dir_begin()
	while true:
		var entry: String = dir.get_next()
		if entry.is_empty():
			break
		if entry in [".", ".."]:
			continue
		var child_path: String = absolute_dir.path_join(entry)
		if dir.current_is_dir():
			_clear_probe_output_absolute(child_path)
			DirAccess.remove_absolute(child_path)
		else:
			DirAccess.remove_absolute(child_path)
	dir.list_dir_end()
