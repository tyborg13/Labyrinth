extends "res://tests/combat_interaction_probe.gd"

const InputRouterScript = preload("res://scripts/input_router.gd")

# Focused 1920x1080/100% proof reusing the combat HUD fixtures and hover sweeps.
func _capture_states() -> void:
	var instance: Node = load("res://scenes/run_scene.tscn").instantiate()
	root.add_child(instance)
	await _settle_ui()
	await _load_combat_fixture(instance, ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"], Vector2i(2, 4), [Vector2i(5, 4), Vector2i(5, 2)], 9801)
	var progression: Dictionary = (instance.get("_progression") as Dictionary).duplicate(true)
	for prompt_id: String in ContextualCombatTutorial.prompt_ids():
		progression = ContextualCombatTutorial.resolve_progression(progression, prompt_id)
	instance.set("_progression", progression)
	instance.call("_refresh_contextual_combat_tutorial")
	await _settle_ui()
	_assert_pass_meter_layout(instance, "normal")
	await _save_root_screenshot("%s/idle_hand.png" % OUTPUT_DIR)
	# The legacy tutorial fixture predates the guided tutorial. Keep this local
	# layout proof on ordinary combat; controller proof owns the current inputs.
	await _capture_pass_and_meter_states(instance, false)
	await _capture_hand_dock_resilience(instance)

	_install_pass_meter_fixture(instance, "safe")
	await _settle_hand_dock_transition()
	await instance.call("_on_card_pressed", 0)
	await _settle_hand_dock_transition()
	var pass_chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_chip != null and pass_chip.disabled and pass_chip.focus_mode == Control.FOCUS_NONE, "Selected card should retain a disabled Pass on the right")
	_assert_pass_meter_layout(instance, "selected card")
	await _save_root_screenshot("%s/pass_selected_disabled.png" % OUTPUT_DIR)
	instance.call("_on_cancel_requested")
	await _settle_hand_dock_transition()
	pass_chip = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_chip != null and not pass_chip.disabled and pass_chip.focus_mode != Control.FOCUS_NONE, "Cancel should restore the actionable Pass control")
	_assert_pass_meter_layout(instance, "cancel restored")
	await _save_root_screenshot("%s/pass_cancel_restored.png" % OUTPUT_DIR)
	await _capture_controller_flanks(instance)
	instance.queue_free()
	await process_frame
	print("TEST RESULT: PASS")

func _room_layout(player_pos: Vector2i, enemy_positions: Array) -> Dictionary:
	var layout: Dictionary = super._room_layout(player_pos, enemy_positions)
	layout["objective"] = {"type": "kill_all"}
	return layout

func _capture_controller_flanks(instance: Node) -> void:
	await _load_combat_fixture(instance, ["quick_stab", "sidestep_slash", "thunderline", "guarded_step", "patch_up"], Vector2i(2, 4), [Vector2i(3, 4), Vector2i(5, 2)], 9802)
	var router: Node = root.get_node("InputRouter")
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_CONTROLLER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_refresh_controller_interface")
	instance.call("_controller_cycle_hand", 1)
	instance.call("_controller_set_hand_index", 0)
	await _settle_hand_dock_transition()
	_assert_pass_meter_layout(instance, "controller first card")
	await _save_root_screenshot("%s/controller_first_card.png" % OUTPUT_DIR)
	await _press_controller_button(JOY_BUTTON_RIGHT_SHOULDER)
	_assert(int(instance.get("_controller_hand_index")) == 1, "Controller shoulder should advance hand focus")
	await _press_controller_button(JOY_BUTTON_LEFT_SHOULDER)
	_assert(int(instance.get("_controller_hand_index")) == 0, "Controller shoulder should restore first-card focus")
	await _press_controller_button(JOY_BUTTON_A)
	_assert(int(instance.get("_selected_card_index")) == 0, "Controller confirm should select the first card for targeting")
	var pass_chip: Button = instance.find_child("PassPreviewChip", true, false) as Button
	_assert(pass_chip != null and pass_chip.disabled, "Controller targeting should keep Pass unavailable")
	_assert_pass_meter_layout(instance, "controller targeting")
	await _save_root_screenshot("%s/controller_targeting.png" % OUTPUT_DIR)
	await _press_controller_button(JOY_BUTTON_B)
	_assert(int(instance.get("_selected_card_index")) < 0 and str(instance.get("_controller_region")) == "board", "Controller cancel should restore board navigation")
	await _press_controller_button(JOY_BUTTON_X)
	_assert(bool(instance.get("_controller_hand_focused")), "Controller hand toggle should restore hand focus after cancel")
	instance.call("_controller_set_hand_index", 4)
	await _settle_hand_dock_transition()
	_assert_pass_meter_layout(instance, "controller last card")
	await _save_root_screenshot("%s/controller_last_card.png" % OUTPUT_DIR)
	await _press_controller_button(JOY_BUTTON_X)
	_assert(not bool(instance.get("_controller_hand_focused")), "Controller hand toggle should restore unobstructed board navigation")
	_assert_pass_meter_layout(instance, "controller hand tucked")
	await _save_root_screenshot("%s/controller_hand_tucked.png" % OUTPUT_DIR)
	router.call("set_forced_state_for_test", InputRouterScript.MODALITY_POINTER, InputRouterScript.FAMILY_STEAM_DECK)
	instance.call("_refresh_controller_interface")
	await _settle_hand_dock_transition()
	_assert_pass_meter_layout(instance, "pointer handoff")
	await _save_root_screenshot("%s/pointer_handoff.png" % OUTPUT_DIR)
	router.call("clear_forced_state_for_test")

func _press_controller_button(button_index: int) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = true
	root.push_input(event)
	await process_frame
	event = InputEventJoypadButton.new()
	event.device = 0
	event.button_index = button_index
	event.pressed = false
	root.push_input(event)
	await _settle_hand_dock_transition()
