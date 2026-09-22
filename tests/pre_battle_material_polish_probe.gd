extends "res://tests/pre_battle_preview_probe.gd"

const Settings = preload("res://scripts/settings_store.gd")
const MATERIAL_OUTPUT: String = "user://probes/pre_battle_material_polish"
var _viewport: SubViewport
var _before: bool = false

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	_before = OS.get_environment("LABYRINTH_PRE_BATTLE_POLISH_PHASE") == "before"
	ProgressionStore.set_storage_path("user://pre_battle_material_progression.json")
	ProgressionStore.set_run_storage_path("user://pre_battle_material_run.save")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	_viewport = SubViewport.new()
	_viewport.size = PROBE_VIEWPORT
	_viewport.msaa_2d = Viewport.MSAA_4X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_viewport)
	await _run_material_proof(settings)
	print(ProjectSettings.globalize_path(MATERIAL_OUTPUT))
	print("PRE-BATTLE MATERIAL POLISH PROBE: %s" % ("FAIL" if _failed else "PASS"))
	quit(1 if _failed else 0)

func _run_material_proof(settings: Dictionary) -> void:
	var engine := RunEngine.new()
	var state: Dictionary = engine.create_new_run(7262026, ProgressionStore.default_data())
	var coord: Vector2i = _first_room_coord_with_min_enemies(engine, state, 5)
	_expect(coord != INVALID_COORD, "Generated five-foe room should exist")
	state = _pre_battle_state_for_room(engine, state, coord)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_viewport.add_child(instance)
	await _settle()
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	var preview: Dictionary = (instance.get("_pre_battle_preview_run_state") as Dictionary).duplicate(true)
	for count: int in range(1, 6):
		var sized: Dictionary = preview.duplicate(true)
		var enemies: Array = sized["combat_state"]["enemies"]
		enemies.resize(count)
		instance.set("_pre_battle_preview_run_state", sized)
		instance.call("_rebuild_pre_battle_overlay")
		await _settle()
		var panel := instance.get("_pre_battle_panel") as Control
		_assert_pre_battle_body_inside_panel(panel, "%d foes" % count)
		if not _before:
			await _assert_frame_backing(instance)
			var deck_scroll := panel.find_child("PreBattleDeckScroll", true, false) as ScrollContainer
			var deck_bar := deck_scroll.get_v_scroll_bar()
			_expect(not deck_bar.visible and deck_bar.max_value <= deck_bar.page + 1.0, "Default deck fits without scrolling with %d foes and full room header" % count)
		var flow := panel.find_child("PreBattleEnemyFlow", true, false) as Control
		_expect(flow.get_child_count() == count, "Count should remain exact")
		var scroll := panel.find_child("PreBattleEnemyScroll", true, false) as ScrollContainer
		_expect(scroll.vertical_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED, "Five or fewer foes should not scroll")
		for card: Node in flow.get_children():
			_expect((card as Control).get_theme_stylebox("panel") is StyleBoxEmpty, "Portraits should retain authored brush, without new card faces")
			if not _before:
				var hp := card.find_child("PreBattleEnemyHealth", true, false) as Control
				_expect(scroll.get_global_rect().encloses(hp.get_global_rect()), "Every foe HP badge should remain inside the visible scroll viewport")
		await _snap("0%d_foes" % count)
	var boss: Dictionary = engine.create_debug_boss_run(ProgressionStore.default_data())
	boss["mode"] = RunEngine.MODE_PRE_BATTLE
	boss["combat_state"] = {}
	boss["pre_battle_pending"] = true
	boss["pre_battle_travel_dir"] = _travel_dir_for_coord(boss.get("current_room", INVALID_COORD))
	instance.call("_load_run_state", boss)
	instance.call("_show_pre_battle_preview")
	instance.call("_close_dialogue")
	await _settle()
	var boss_preview: Dictionary = instance.get("_pre_battle_preview_run_state")
	var objective: Dictionary = boss_preview["combat_state"]["objective"]
	var exact_objective: String = load("res://scripts/combat_objective_rules.gd").title_for_objective(objective).to_upper()
	_expect(_labels_text(instance.get("_pre_battle_panel")).contains(exact_objective), "Boss objective must match the precise live leader title")
	await _snap("06_boss")

	state = _run_with_available_combat(engine)
	var progression: Dictionary = (state.get("progression", {}) as Dictionary).duplicate(true)
	progression["level"] = 5
	progression["skill_ids"] = ["ghost_stride", "sure_footed", "discerning_eye", "true_bearing"]
	state["progression"] = progression
	coord = _first_available_combat_coord(engine, state)
	state = _pre_battle_state_for_room(engine, state, coord)
	instance.set("_progression", progression)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	await _settle()
	var panel := instance.get("_pre_battle_panel") as Control
	_expect(panel.find_child("TrueBearingButton", true, false) != null, "Optional Position action should remain present")
	await _snap("07_true_bearing")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	var start := panel.find_child("PreBattleStartButton", true, false) as Button
	await _pointer(start.get_global_rect().get_center())
	_expect(_viewport.gui_get_hovered_control() == start, "Start hover should use actual pointer routing")
	await _snap("08_start_hover")
	await _pointer(Vector2(80, 80))
	router.call("set_forced_state_for_test", "controller", "xbox")
	start.grab_focus()
	await process_frame
	_expect(start.has_focus(), "Start must retain visible keyboard/controller focus")
	await _snap("09_start_focus")
	var equip := panel.find_child("PreBattleEquipButton", true, false) as Button
	await _joy(JOY_BUTTON_DPAD_LEFT)
	_expect(_viewport.gui_get_focus_owner() == equip, "Controller Left should traverse from Start to Equip")
	await _joy(JOY_BUTTON_A)
	await _settle()
	_expect((instance.get("_upgrade_scrim") as Control).visible, "Controller A should activate Equip")
	await _joy(JOY_BUTTON_B)
	await _settle()
	_expect(not (instance.get("_upgrade_scrim") as Control).visible, "Controller B should return to pre-battle")
	_expect((instance.get("_pre_battle_scrim") as Control).visible, "Equip return should retain committed pre-battle")
	_expect(_viewport.gui_get_focus_owner() != null and panel.is_ancestor_of(_viewport.gui_get_focus_owner()), "Controller return should recover focus inside pre-battle")
	await _snap("10_equip_return")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	panel = instance.get("_pre_battle_panel") as Control
	equip = panel.find_child("PreBattleEquipButton", true, false) as Button
	await _click(equip)
	await _settle()
	_expect((instance.get("_upgrade_scrim") as Control).visible, "Pointer handoff should activate Equip")
	await _key(KEY_ESCAPE)
	await _settle()
	_expect(not (instance.get("_upgrade_scrim") as Control).visible, "Escape should return from equipment")
	await _pointer(Vector2(80, 80))
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	await _settle()
	if not _before:
		_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Reduced Motion reopening must remain static")
	await _snap("11_reduced_motion")
	if not _before:
		await _motion_lifecycle(instance, settings)
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	_viewport.queue_free()
	await process_frame

func _motion_lifecycle(instance: Node, settings: Dictionary) -> void:
	settings["reduced_motion"] = false
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	# Pause on the same layout frame that creates the tween, before its first tick.
	await process_frame
	var tween := instance.get("_pre_battle_entry_tween") as Tween
	_expect(tween != null, "Opening should start a bounded entrance")
	if tween != null:
		tween.pause()
		tween.custom_step(0.04)
	var scrim := instance.get("_pre_battle_scrim") as Control
	_expect(scrim.modulate.a > 0.1 and scrim.modulate.a < 0.8, "Early capture must show an actual in-flight fade")
	await _snap("12_entry_early")
	_expect(scrim.modulate.a < 0.8, "Capture must preserve the paused entrance phase")
	var panel := instance.get("_pre_battle_panel") as Control
	var frame := instance.get("_pre_battle_frame") as Control
	_expect(panel.scale.is_equal_approx(frame.scale), "Raster frame and dossier must settle together")
	var positions: Dictionary = {}
	for badge: Node in panel.find_children("PreBattleDeckBadge", "PanelContainer", true, false):
		positions[badge.get_instance_id()] = (badge as Control).position
	if tween != null:
		tween.custom_step(0.08)
	_expect(scrim.modulate.a > 0.8 and scrim.modulate.a < 1.0, "Mid capture should advance the same entrance")
	await _snap("13_entry_mid")
	for badge: Node in panel.find_children("PreBattleDeckBadge", "PanelContainer", true, false):
		_expect(positions[badge.get_instance_id()] == (badge as Control).position, "Entrance must not animate Flow child positions")
	settings["reduced_motion"] = true
	instance.call("_on_settings_changed", settings)
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE and frame.scale == Vector2.ONE, "Live Reduced Motion must cancel and settle immediately")
	await _snap("14_live_reduced_motion")
	settings["reduced_motion"] = false
	instance.call("_on_settings_changed", settings)
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	instance.call("_close_pre_battle_preview")
	await process_frame
	await process_frame
	_expect(instance.get("_pre_battle_entry_tween") == null, "Close before deferred entry must prevent stale animation")
	instance.call("_show_pre_battle_preview")
	await _settle()
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Reopen must settle cleanly and stop animation")
	await _snap("15_reopened")
	instance.call("_animate_pre_battle_entry")
	await process_frame
	instance.call("_rebuild_pre_battle_overlay")
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Loadout rebuild must cancel active entrance before replacing children")
	instance.call("_animate_pre_battle_entry")
	await process_frame
	instance.call("_on_pre_battle_equip_pressed")
	_expect(instance.get("_pre_battle_entry_tween") == null and panel.scale == Vector2.ONE, "Equip handoff must cancel active entrance")
	await _key(KEY_ESCAPE)
	await _settle()
	# Start during the first deferred frame: input and combat must never wait for presentation.
	instance.call("_close_pre_battle_preview")
	instance.call("_show_pre_battle_preview")
	var start := panel.find_child("PreBattleStartButton", true, false) as Button
	start.grab_focus()
	await _key(KEY_ENTER)
	await _settle()
	_expect(str((instance.get("_run_state") as Dictionary).get("mode")) == "combat", "Enter should begin combat during entrance without delay")
	_expect(not (instance.get("_pre_battle_scrim") as Control).visible and instance.get("_pre_battle_entry_tween") == null, "Starting combat must clear entrance lifecycle")
	await _snap("16_start_interrupted_entry")

func _expect(condition: bool, message: String) -> void:
	if not condition:
		_fail(message)

func _settle() -> void:
	await create_timer(0.35).timeout
	await process_frame
	await process_frame

func _snap(label: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = _viewport.get_texture().get_image()
	_expect(image != null and image.get_size() == PROBE_VIEWPORT, "Capture must be native 1920x1080 without resizing")
	if image != null:
		_expect(image.save_png("%s/%s.png" % [MATERIAL_OUTPUT, label]) == OK, "Capture should save")

func _pointer(position: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = position
	event.global_position = position
	_viewport.push_input(event, true)
	await process_frame

func _click(control: Control) -> void:
	var position: Vector2 = control.get_global_rect().get_center()
	await _pointer(position)
	_expect(_viewport.gui_get_hovered_control() == control, "Pointer target should own the visible control")
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = position
		event.global_position = position
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _key(key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _joy(button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		_viewport.push_input(event, true)
		await process_frame

func _assert_frame_backing(instance: Node) -> void:
	var panel := instance.get("_pre_battle_panel") as PanelContainer
	var finish := panel.get_node("SurfaceFinish") as Node2D
	var geometry: Dictionary = finish.call("menu_face_geometry")
	var face: Rect2 = geometry["rect"]
	var frame := instance.get("_pre_battle_frame") as Control
	var texture: Texture2D = frame.get("texture")
	var source := Vector2(texture.get_width(), texture.get_height())
	var scale: float = minf(frame.size.x / source.x, frame.size.y / source.y)
	var rail_top: float = frame.global_position.y + 32.0 * scale
	var rail_bottom: float = frame.global_position.y + 991.0 * scale
	_expect(absf(panel.global_position.y + face.position.y - rail_top) < 1.0, "Backing top meets actual settled frame rail")
	_expect(absf(panel.global_position.y + face.end.y - rail_bottom) < 1.0, "Backing bottom meets actual settled frame rail")
	# This is the formerly bare band above the content panel, beneath the
	# decorative top rail. Test actual rendered paint there, not just sizing.
	_expect(face.position.y < -10.0, "Backing extends above content to the authored rail")
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var painted: Image = _viewport.get_texture().get_image()
	finish.hide()
	await process_frame
	await RenderingServer.frame_post_draw
	var unpainted: Image = _viewport.get_texture().get_image()
	finish.show()
	await process_frame
	await RenderingServer.frame_post_draw
	for x: float in [0.25, 0.75]:
		for outside_y: float in [rail_top - 4.0, rail_bottom + 4.0]:
			var outside := Vector2i(Vector2(panel.global_position.x + panel.size.x * x, outside_y))
			var delta: Color = painted.get_pixelv(outside) - unpainted.get_pixelv(outside)
			_expect(maxf(absf(delta.r), maxf(absf(delta.g), absf(delta.b))) < 0.005, "Native material stays inside the outer frame rails")
		var point := Vector2i(panel.get_global_rect().position + Vector2(panel.size.x * x, -10.0))
		var first: Color = painted.get_pixelv(point)
		var second: Color = unpainted.get_pixelv(point)
		_expect(maxf(absf(first.r - second.r), maxf(absf(first.g - second.g), absf(first.b - second.b))) > 0.01, "Native finish paints the previously bare top band")
