extends SceneTree

const ParallelRuntime = preload("res://scripts/parallel_runtime.gd")
const ProgressionStore = preload("res://scripts/progression_store.gd")
const RunEngine = preload("res://scripts/run_engine.gd")
const UiSkin = preload("res://scripts/ui_skin.gd")

const OUTPUT_DIR: String = "user://probes/selective_ui_salvage"
const VIEWPORT_SIZES: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(1280, 720),
	Vector2i(1280, 800),
]
const INVALID_COORD := Vector2i(999, 999)

var _failures: Array[String] = []


func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path("user://selective_ui_salvage_progression.json")
	ProgressionStore.set_run_storage_path("user://selective_ui_salvage_run.save")
	ProgressionStore.clear_saved_run()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUTPUT_DIR))
	var packed: PackedScene = load("res://scenes/run_scene.tscn")
	_require(packed != null, "Selective UI salvage probe should load RunScene")
	if packed != null:
		for viewport_size: Vector2i in VIEWPORT_SIZES:
			await _capture_configuration(packed, viewport_size)
	if _failures.is_empty():
		print("SELECTIVE_UI_SALVAGE_PROOF_DIR=%s" % ProjectSettings.globalize_path(OUTPUT_DIR))
		print("TEST RESULT: PASS")
		quit()
		return
	for failure: String in _failures:
		push_error(failure)
	print("TEST RESULT: FAIL (%d failures)" % _failures.size())
	quit(1)


func _capture_configuration(packed: PackedScene, viewport_size: Vector2i) -> void:
	var suffix := "%dx%d" % [viewport_size.x, viewport_size.y]
	var output_dir := "%s/%s" % [OUTPUT_DIR, suffix]
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output_dir))
	var viewport := SubViewport.new()
	viewport.name = "SelectiveUiSalvage_%s" % suffix
	viewport.size = viewport_size
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = packed.instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	var run_engine := RunEngine.new()
	var run_state: Dictionary = run_engine.create_new_run(8173 + viewport_size.y, ProgressionStore.default_data())
	var combat_coord: Vector2i = _first_available_combat_coord(run_engine, run_state)
	_require(combat_coord != INVALID_COORD, "%s should expose a combat room" % suffix)
	if combat_coord == INVALID_COORD:
		await _dispose_configuration(viewport, instance)
		return
	run_state = run_engine.move_to_pre_battle(run_state, combat_coord)
	run_state = run_engine.begin_pre_battle_combat(run_state)
	instance.call("_load_run_state", run_state)
	instance.call("_close_dialogue")
	instance.call("_show_combat_log_message", RunEngine.MISSED_EQUIPMENT_NOTICE)
	await _settle(0.25)

	_assert_combat_surfaces(instance, viewport_size, suffix)
	await _save_viewport_screenshot(viewport, "%s/01_combat_surfaces.png" % output_dir)

	instance.call("_on_card_pressed", 0)
	await _settle()
	_assert_inset_surface(instance.get("_contextual_combat_prompt") as PanelContainer, "%s Combat Note" % suffix)
	await _save_viewport_screenshot(viewport, "%s/02_combat_note.png" % output_dir)
	instance.call("_reset_card_resolution")
	instance.call("_refresh_ui")
	await _settle()

	instance.call("_open_menu_overlay")
	await _settle()
	var menu_dialog: PanelContainer = instance.get("_menu_dialog") as PanelContainer
	_assert_outer_frame(menu_dialog, viewport_size, "%s Pause/Camp" % suffix)
	await _save_viewport_screenshot(viewport, "%s/03_pause_camp.png" % output_dir)

	instance.call("_open_settings_overlay")
	await _settle()
	var settings_panel: PanelContainer = instance.get("_settings_panel") as PanelContainer
	_assert_outer_frame(settings_panel, viewport_size, "%s Settings" % suffix)
	await _save_viewport_screenshot(viewport, "%s/04_settings.png" % output_dir)
	instance.call("_close_settings_overlay")
	instance.call("_close_menu_overlay")
	await _settle()

	instance.call("_open_grimoire_overlay")
	await _settle()
	var grimoire_dialog: PanelContainer = instance.get("_grimoire_dialog") as PanelContainer
	_assert_outer_frame(grimoire_dialog, viewport_size, "%s Grimoire" % suffix)
	await _save_viewport_screenshot(viewport, "%s/05_grimoire.png" % output_dir)
	instance.call("_close_grimoire_overlay")
	await _settle()

	instance.call("_open_character_overlay", "equipment")
	await _settle()
	var character_dialog: PanelContainer = instance.get("_upgrade_dialog") as PanelContainer
	_assert_outer_frame(character_dialog, viewport_size, "%s Character" % suffix)
	await _save_viewport_screenshot(viewport, "%s/06_character.png" % output_dir)
	instance.call("_close_card_upgrade_overlay")
	await _settle()
	await _dispose_configuration(viewport, instance)


func _assert_combat_surfaces(instance: Node, viewport_size: Vector2i, context: String) -> void:
	var turn_order_panel: PanelContainer = instance.get("_turn_order_panel") as PanelContainer
	var turn_order_bar: Control = instance.get("_turn_order_bar") as Control
	var combat_engine = instance.get("_combat_engine")
	var combat_state: Dictionary = instance.get("_combat_state") as Dictionary
	var expected_turn_order: Array = combat_engine.current_turn_order(combat_state, 10)
	_require(not expected_turn_order.is_empty(), "%s should have a non-empty turn order" % context)
	_require(
		turn_order_bar != null and turn_order_bar.get_child_count() == expected_turn_order.size(),
		"%s Turn Clock should show all %d entries immediately, found %d"
		% [
			context,
			expected_turn_order.size(),
			turn_order_bar.get_child_count() if turn_order_bar != null else -1,
		]
	)
	_assert_panel_frame(turn_order_panel, "%s Turn Clock" % context)
	var turn_clock_label: Label = instance.get("_turn_order_label") as Label
	_require(
		turn_clock_label != null
		and turn_clock_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_LEFT
		and turn_clock_label.vertical_alignment == VERTICAL_ALIGNMENT_CENTER
		and turn_clock_label.offset_left >= 19.5,
		"%s Turn Clock title should occupy the centered left legend rail" % context
	)
	var minimap: PanelContainer = instance.get("mini_map_overlay") as PanelContainer
	var combat_log: PanelContainer = instance.get("log_overlay") as PanelContainer
	_assert_panel_frame(minimap, "%s minimap" % context)
	_assert_panel_frame(combat_log, "%s combat log" % context)
	_assert_inset_surface(instance.get("_play_meter") as PanelContainer, "%s Turn Plays" % context)
	var pass_preview: PanelContainer = instance.find_child("PassPreviewChip", true, false) as PanelContainer
	_assert_inset_surface(pass_preview, "%s On Turn End" % context)
	_require(
		pass_preview != null
		and pass_preview.find_child("PassPreviewTitle", true, false) is Label
		and (pass_preview.find_child("PassPreviewTitle", true, false) as Label).text == "On Turn End:",
		"%s should preserve the exact On Turn End label" % context
	)
	for panel: PanelContainer in [turn_order_panel, minimap, combat_log, pass_preview]:
		_assert_inside_viewport(panel, viewport_size, "%s combat surface" % context)


func _assert_panel_frame(panel: PanelContainer, context: String) -> void:
	_require(panel != null, "%s should exist" % context)
	if panel == null:
		return
	_require(panel.get_node_or_null(UiSkin.PANEL_ORNAMENT_NAME) != null, "%s should use the authored raster frame" % context)


func _assert_inset_surface(panel: PanelContainer, context: String) -> void:
	_require(panel != null, "%s should exist" % context)
	if panel == null:
		return
	_require(panel.get_node_or_null(UiSkin.PANEL_INSET_ORNAMENT_NAME) != null, "%s should use the shared asymmetric shape" % context)


func _assert_outer_frame(panel: PanelContainer, viewport_size: Vector2i, context: String) -> void:
	_assert_panel_frame(panel, context)
	if panel == null:
		return
	_require(bool(panel.get_meta("panel_outer_frame_only", false)), "%s should apply only the outer raster frame" % context)
	_assert_inside_viewport(panel, viewport_size, context)


func _assert_inside_viewport(control: Control, viewport_size: Vector2i, context: String) -> void:
	if control == null or not control.visible:
		return
	var viewport_rect := Rect2(Vector2.ZERO, Vector2(viewport_size))
	_require(
		viewport_rect.grow(1.0).encloses(control.get_global_rect()),
		"%s should remain inside %s, got %s" % [context, viewport_rect, control.get_global_rect()]
	)


func _first_available_combat_coord(run_engine, run_state: Dictionary) -> Vector2i:
	for coord: Vector2i in run_engine.available_moves(run_state):
		var preview_state: Dictionary = run_engine.move_to_room(run_state.duplicate(true), coord)
		if str(preview_state.get("mode", "")) == "combat":
			return coord
	return INVALID_COORD


func _save_viewport_screenshot(viewport: SubViewport, path: String) -> void:
	await process_frame
	await process_frame
	RenderingServer.force_draw(true)
	var image: Image = null
	if DisplayServer.get_name() != "headless":
		var texture: Texture2D = viewport.get_texture()
		if texture != null:
			image = texture.get_image()
	if image == null:
		image = Image.create(viewport.size.x, viewport.size.y, false, Image.FORMAT_RGBA8)
		image.fill(Color("17110e"))
	_require(image.get_size() == viewport.size, "%s should render at exact size %s" % [path, viewport.size])
	var error: Error = image.save_png(path)
	_require(error == OK, "Selective UI proof should save %s" % path)


func _dispose_configuration(viewport: SubViewport, instance: Node) -> void:
	viewport.remove_child(instance)
	instance.queue_free()
	root.remove_child(viewport)
	viewport.queue_free()
	await process_frame
	await process_frame


func _settle(seconds: float = 0.08) -> void:
	await process_frame
	await process_frame
	if seconds > 0.0:
		await create_timer(seconds).timeout
	await process_frame


func _require(condition: bool, message: String) -> void:
	if not condition:
		_failures.append(message)
