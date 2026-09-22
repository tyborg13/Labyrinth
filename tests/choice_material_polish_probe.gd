extends "res://tests/ui_probe.gd"

const CHOICE_OUTPUT: String = "user://probes/choice_material_v2"
var _choice_failures: Array[String]

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	SettingsStore.set_storage_path("user://choice_material_settings.json")
	ProgressionStore.set_storage_path("user://choice_material_progression.json")
	ProgressionStore.set_run_storage_path("user://choice_material_run.save")
	ProgressionStore.clear_saved_run()
	var settings: Dictionary = SettingsStore.default_settings()
	settings["ui_scale"] = 1.0
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	root.get_node("InputRouter").call("set_forced_state_for_test", "pointer", "xbox")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(CHOICE_OUTPUT))
	_proof_viewport = SubViewport.new()
	_proof_viewport.size = Vector2i(1920, 1080)
	_proof_viewport.msaa_2d = Viewport.MSAA_4X
	_proof_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(_proof_viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	_proof_viewport.add_child(instance)
	await create_timer(0.2).timeout
	var engine := RunEngine.new()
	var progression: Dictionary = preload("res://scripts/contextual_combat_tutorial.gd").complete_tutorial(ProgressionStore.default_data())
	var base: Dictionary = engine.create_new_run(7321, progression)
	var treasure: Dictionary = _run_state_for_room(engine, base, _first_room_coord_of_type(engine, base, "treasure"), "treasure", Vector2i(1, 0))
	treasure["pending_relics"] = ["iron_lung", "ember_lens", "pilgrim_boots"]
	instance.call("_load_run_state", treasure)
	instance.call("_close_dialogue")
	instance.call("_close_large_map")
	for _frame: int in range(90):
		if not bool(instance.get("_treasure_reveal_active")):
			break
		await create_timer(0.025).timeout
	_expect_choice(not bool(instance.get("_treasure_reveal_active")), "Treasure reveal must complete before inspecting choices")
	await _choice_settle()
	await _choice_capture("01_relic_idle.png")
	var choices: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	var initial_focus: Control = _proof_viewport.gui_get_focus_owner()
	_expect_choice(initial_focus == null or not choices.is_ancestor_of(initial_focus), "Pointer-only reveal must leave relic choices idle")
	var relic: PanelContainer = choices.get_child(1) as PanelContainer
	var original_rect: Rect2 = relic.get_global_rect()
	relic.grab_focus()
	await _choice_settle()
	_expect_choice(relic.has_focus(), "Relic choice must retain native keyboard focus")
	await _choice_capture("02_relic_focus.png")
	_assert_retained_finish(relic)
	relic.release_focus()
	await _choice_point(relic.get_global_rect().get_center())
	_expect_choice(bool(relic.get_meta("relic_pointer_hovered", false)), "Relic choice must respond to real pointer hover")
	_expect_choice(relic.get_global_rect() == original_rect, "Relic material states must preserve its hit rectangle")
	await _choice_capture("03_relic_hover.png")
	await _choice_point(Vector2(40, 40))

	await _load_campfire(instance, engine, base, 0)
	_assert_campfire_single_perimeter(instance)
	await _choice_capture("04_campfire_locked.png")
	choices = instance.get("_relic_choice_bar") as HBoxContainer
	_expect_choice((choices.get_child(2) as Control).focus_mode == Control.FOCUS_NONE, "Unaffordable campfire choice must remain outside navigation")
	await _load_campfire(instance, engine, base, 180)
	_assert_campfire_single_perimeter(instance)
	await _choice_capture("05_campfire_idle.png")
	choices = instance.get("_relic_choice_bar") as HBoxContainer
	var campfire: PanelContainer = choices.get_child(0) as PanelContainer
	original_rect = campfire.get_global_rect()
	campfire.grab_focus()
	await _choice_settle()
	_expect_choice(campfire.has_focus(), "Campfire choice must retain keyboard focus")
	await _choice_point(campfire.get_global_rect().get_center())
	await _choice_point(Vector2(40, 40))
	_expect_choice(campfire.has_focus() and campfire.z_index == 40, "Pointer departure must not remove a campfire choice's keyboard focus emphasis")
	_assert_retained_finish(campfire)
	await _choice_capture("06_campfire_focus.png")
	campfire.release_focus()
	await _choice_point(campfire.get_global_rect().get_center())
	_expect_choice(campfire.get_global_rect() == original_rect, "Campfire material states must preserve its hit rectangle")
	await _choice_capture("07_campfire_hover.png")
	settings["reduced_motion"] = true
	SettingsStore.save_settings(settings)
	SettingsStore.apply_settings(settings, root, false)
	instance.set("_settings", settings)
	await _choice_point(Vector2(40, 40))
	await _choice_capture("08_campfire_reduced.png")
	campfire.grab_focus()
	var hp_before: int = int((instance.get("_run_state") as Dictionary).get("player_hp", 0))
	for pressed: bool in [true, false]:
		var accept := InputEventAction.new()
		accept.action = "ui_accept"
		accept.pressed = pressed
		_proof_viewport.push_input(accept, true)
		await process_frame
	await _choice_settle()
	var after: Dictionary = instance.get("_run_state") as Dictionary
	_expect_choice(str(after.get("mode", "")) == "room", "Native keyboard activation must resolve the campfire choice")
	_expect_choice(int(after.get("player_hp", 0)) > hp_before, "Linger must retain its healing result")
	await _choice_capture("09_campfire_resolved.png")
	instance.queue_free()
	await process_frame
	for failure: String in _choice_failures:
		push_error(failure)
	print("CHOICE MATERIAL PROBE: %s" % ("PASS" if _choice_failures.is_empty() else "FAIL"))
	print(ProjectSettings.globalize_path(CHOICE_OUTPUT))
	quit(0 if _choice_failures.is_empty() else 1)

func _load_campfire(instance: Node, engine: RunEngine, base: Dictionary, embers: int) -> void:
	var state: Dictionary = _run_state_for_room(engine, base, _first_room_coord_of_type(engine, base, "campfire"), "campfire", Vector2i(1, 0))
	state["player_hp"] = 12
	state["player_max_hp"] = 24
	state["held_embers"] = embers
	state["unbanked_embers"] = embers
	state["progression"] = ProgressionStore.set_embers(state.get("progression", {}), embers)
	instance.call("_load_run_state", state)
	instance.call("_close_dialogue")
	instance.call("_close_large_map")
	await _choice_settle()

func _choice_point(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	event.relative = Vector2(10, 10)
	_proof_viewport.push_input(event, true)
	await _choice_settle()

func _choice_settle() -> void:
	await create_timer(0.25).timeout
	await process_frame
	await process_frame

func _assert_retained_finish(panel: PanelContainer) -> void:
	var finish: Node2D = panel.get_node_or_null("ChoiceSurfaceFinish") as Node2D
	_expect_choice(finish != null and not finish.is_processing(), "Choice finish must be retained without frame processing")
	if finish == null:
		return
	var bounds: Rect2 = panel.get_global_rect()
	var minimum: Vector2 = panel.get_combined_minimum_size()
	finish.visible = false
	_expect_choice(panel.get_global_rect() == bounds and panel.get_combined_minimum_size() == minimum, "Choice finish visibility cannot affect layout or hit bounds")
	finish.visible = true

func _choice_capture(filename: String) -> void:
	if DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var pixels: Image = _proof_viewport.get_texture().get_image()
	_expect_choice(pixels.get_size() == Vector2i(1920, 1080), "Choice proof must use native1080 at UI100")
	_expect_choice(pixels.save_png(CHOICE_OUTPUT.path_join(filename)) == OK, "Choice screenshot must save")

func _expect_choice(ok: bool, message: String) -> void:
	if not ok:
		_choice_failures.append(message)

func _assert_campfire_single_perimeter(instance: Node) -> void:
	var choices: HBoxContainer = instance.get("_relic_choice_bar") as HBoxContainer
	for child: Node in choices.get_children():
		var panel: PanelContainer = child as PanelContainer
		if panel == null:
			continue
		var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
		_expect_choice(style != null, "Campfire uses the authored frame")
		if style != null:
			for side: Side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				_expect_choice(is_zero_approx(style.get_expand_margin(side)), "Campfire frame has no duplicate expanded outer panel")
		var art: TextureRect = panel.get_node("CampfireChoiceBackgroundClip/CampfireChoiceBackground") as TextureRect
		_expect_choice(art.texture != null and art.get_rect() == Rect2(Vector2.ZERO, panel.size), "Campfire backing art fits the single frame")
