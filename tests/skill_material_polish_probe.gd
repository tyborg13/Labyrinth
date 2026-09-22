extends "res://tests/skill_tree_visual_probe.gd"

const Settings = preload("res://scripts/settings_store.gd")
const FINISH_OUTPUT: String = "user://probes/skill_material_polish"

func _initialize() -> void:
	ParallelRuntime.apply_from_environment()
	ProgressionStore.set_storage_path(STORAGE_PATH)
	ProgressionStore.set_run_storage_path(RUN_STORAGE_PATH)
	ProgressionStore.clear_saved_run()
	_active_screenshot_size = Vector2i(1920, 1080)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FINISH_OUTPUT))
	await _run_finish_proof()
	print(ProjectSettings.globalize_path(FINISH_OUTPUT))
	for failure: String in _failures:
		push_error(failure)
	print("SKILL MATERIAL POLISH PROBE: %s" % ("PASS" if _failures.is_empty() else "FAIL"))
	quit(0 if _failures.is_empty() else 1)

func _run_finish_proof() -> void:
	var settings: Dictionary = Settings.default_settings()
	settings["ui_scale"] = 1.0
	settings["reduced_motion"] = false
	Settings.save_settings(settings)
	Settings.apply_settings(settings, null, false)
	var profile: Dictionary = _populated_progression()
	profile["level"] = 20
	profile = ProgressionStore.normalized_data(profile)
	_expect(ProgressionStore.save_data(profile), "Fixture should save")
	var viewport := SubViewport.new()
	viewport.size = _active_screenshot_size
	viewport.msaa_2d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	viewport.add_child(instance)
	await _settle()
	instance.call("_close_dialogue")
	instance.set("_progression", profile)
	instance.call("_load_run_state", RunEngine.new().create_new_run(82439, profile))
	instance.call("_close_dialogue")
	instance.call("_close_large_map")
	instance.call("_open_character_overlay", "skills")
	await _settle()
	var tree := instance.get("_skill_tree_view") as SkillTreeView
	_expect(tree != null, "Skills should open")
	if tree == null:
		return
	_expect(not tree.is_processing(), "Opening an owned profile should have no animation")
	_expect(not tree.play_learned_confirmation("quick_wits"), "Existing ownership cannot replay a confirmation")
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	await _click_control(viewport, tree.node_for_skill("pain_remembers"), "Pain Remembers node")
	_expect(tree.focused_skill_id() == "pain_remembers" and not tree.is_processing(), "Pointer selection should update detail without acknowledgement")
	await _snap(viewport, "01_pointer_available")
	var rectangles: Dictionary = _node_rectangles(tree)
	var rebuilds: int = tree.link_geometry_rebuild_count()
	var points_before: int = tree.points_remaining()
	await _click_control(viewport, tree.get("_detail_action") as Button, "Learn action")
	_expect(tree.owned_skill_ids().has("pain_remembers"), "Pointer learning must commit immediately")
	_expect(ProgressionStore.selected_skill_ids(ProgressionStore.load_data()).has("pain_remembers"), "Confirmation must follow persisted ownership")
	_expect(tree.points_remaining() == points_before - 1, "Learning should spend exactly one point")
	_expect(str(tree.get("_confirmation_skill_id")) == "pain_remembers", "Successful pointer learn should start one acknowledgement")
	# Freeze only the existing clock for deterministic native phase captures.
	tree.set_process(false)
	tree.set("_confirmation_elapsed", 0.0)
	tree.call("_process", 0.12)
	await _snap(viewport, "02_pointer_learn_peak")
	_expect(not tree.play_learned_confirmation("pain_remembers"), "Duplicate delivery cannot replay the acknowledgement")
	_expect(_node_rectangles(tree) == rectangles, "Learning glow must not move any node or hit area")
	_expect(tree.link_geometry_rebuild_count() == rebuilds, "Learning glow must reuse connector geometry")
	tree.call("_process", 0.23)
	await _snap(viewport, "03_pointer_learn_tail")
	tree.call("_process", 0.30)
	_expect(not tree.is_processing() and str(tree.get("_confirmation_skill_id")).is_empty(), "Settled acknowledgement should stop processing")
	await _snap(viewport, "04_pointer_learn_settled")

	# Real key activation uses the same existing button as pointer activation.
	tree.focus_skill("afterimage")
	(tree.get("_detail_action") as Button).grab_focus()
	await _key(viewport, KEY_ENTER)
	_expect(tree.owned_skill_ids().has("afterimage"), "Enter should learn the focused actionable skill")
	_expect(str(tree.get("_confirmation_skill_id")) == "afterimage", "Keyboard learning should acknowledge success")
	await _snap(viewport, "05_keyboard_learn")
	await _key(viewport, KEY_ESCAPE)
	await _settle()
	_expect(not tree.is_visible_in_tree() and not tree.is_processing(), "Escape should dismiss and immediately stop the acknowledgement")
	instance.call("_open_character_overlay", "skills")
	await _settle()
	tree = instance.get("_skill_tree_view") as SkillTreeView
	_expect(not tree.is_processing(), "Reopening should retain ownership without replay")

	# Controller focus can leave and re-enter the graph before learning.
	router.call("set_forced_state_for_test", "controller", "xbox")
	tree.focus_skill("ghost_stride")
	tree.grab_tree_focus()
	await _joy(viewport, JOY_BUTTON_DPAD_UP)
	var tab := instance.find_child("CharacterSkillsTab", true, false) as Button
	_expect(viewport.gui_get_focus_owner() == tab, "Controller Up should reach the Skills tab")
	await _joy(viewport, JOY_BUTTON_DPAD_DOWN)
	_expect(viewport.gui_get_focus_owner() == tree.node_for_skill("ghost_stride"), "Controller Down should restore remembered node focus")
	tree.focus_skill("living_shadow")
	(tree.get("_detail_action") as Button).grab_focus()
	await _joy(viewport, JOY_BUTTON_A)
	_expect(tree.owned_skill_ids().has("living_shadow"), "Controller A should learn the focused actionable junction")
	_expect(str(tree.get("_confirmation_skill_id")) == "living_shadow", "Controller learning should acknowledge success")
	await _snap(viewport, "06_controller_junction_learn")
	# Shared settings are read only while the transient is active.
	settings["reduced_motion"] = true
	Settings.apply_settings(settings, null, false)
	instance.call("_on_settings_changed", settings)
	await process_frame
	await process_frame
	_expect(not tree.is_processing() and str(tree.get("_confirmation_skill_id")).is_empty(), "Live Reduced Motion must immediately cancel the active acknowledgement")
	await _snap(viewport, "07_live_reduced_motion")
	tree.focus_skill("long_dawn")
	(tree.get("_detail_action") as Button).grab_focus()
	await _joy(viewport, JOY_BUTTON_A)
	_expect(tree.owned_skill_ids().has("long_dawn") and not tree.is_processing(), "Reduced Motion learns immediately with a static final face")
	await _snap(viewport, "08_reduced_motion_learn")
	await _joy(viewport, JOY_BUTTON_B)
	await _settle()
	_expect(not tree.is_visible_in_tree(), "Controller B should dismiss Skills")
	router.call("set_forced_state_for_test", "pointer", "xbox")
	instance.call("_open_character_overlay", "skills")
	await _settle()
	tree = instance.get("_skill_tree_view") as SkillTreeView
	await _click_control(viewport, tree.node_for_skill("witchlight"), "Pointer handoff node")
	_expect(tree.focused_skill_id() == "witchlight" and not tree.is_processing(), "Pointer handoff should recover selection without stale glow")

	# A real save failure must neither spend the point nor celebrate. An isolated
	# directory at the temporary save path makes FileAccess.WRITE fail safely.
	settings["reduced_motion"] = false
	Settings.apply_settings(settings, null, false)
	instance.call("_on_settings_changed", settings)
	points_before = tree.points_remaining()
	var temp_save: String = ProjectSettings.globalize_path(STORAGE_PATH + ".tmp")
	DirAccess.make_dir_recursive_absolute(temp_save)
	await _click_control(viewport, tree.get("_detail_action") as Button, "Failed-save learn action")
	DirAccess.remove_absolute(temp_save)
	tree = instance.get("_skill_tree_view") as SkillTreeView
	_expect(not tree.owned_skill_ids().has("witchlight") and tree.points_remaining() == points_before, "Failed save should retain skill ownership and points")
	_expect(not tree.is_processing() and not tree.play_learned_confirmation("witchlight"), "Failed save cannot acknowledge success")
	await _snap(viewport, "09_save_failure_no_glow")
	await _click_control(viewport, tree.get("_detail_action") as Button, "Retry learn action")
	_expect(tree.owned_skill_ids().has("witchlight") and tree.is_processing(), "Successful retry should recover and acknowledge")
	instance.call("_open_skill_reset_confirmation")
	instance.call("_confirm_skill_reset")
	await _settle()
	tree = instance.get("_skill_tree_view") as SkillTreeView
	_expect(tree.owned_skill_ids().is_empty() and not tree.is_processing(), "Reset should cancel the transient and show the final empty tree")
	await _snap(viewport, "10_reset_cleanup")
	router.call("clear_forced_state_for_test")
	instance.queue_free()
	await process_frame
	viewport.queue_free()
	await process_frame

func _node_rectangles(tree: SkillTreeView) -> Dictionary:
	var result: Dictionary = {}
	for skill_id: String in SkillTreeLibrary.visible_ids():
		result[skill_id] = tree.node_for_skill(skill_id).get_global_rect()
	return result

func _key(viewport: Viewport, key: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = key
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func _joy(viewport: Viewport, button: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button
		event.pressed = pressed
		viewport.push_input(event, true)
		await process_frame

func _snap(viewport: SubViewport, label: String) -> void:
	await _save_screenshot(viewport, "%s/%s.png" % [ProjectSettings.globalize_path(FINISH_OUTPUT), label])
